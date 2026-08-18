// Renders the launcher icons for both stores, plus the web and Play listing
// art, from the Prayan mark.
//
//   dart run tool/generate_launcher_icons.dart
//
// Plain Dart on purpose: no Flutter, no widget test, no engine. Rendering the
// real `PrayanMark` widget would keep a single source of truth, but that widget
// reads its colours from a theme extension and hangs a headless test binding,
// and an icon generator is not worth carrying that risk. The geometry below
// mirrors `_MarkPainter` in lib/features/splash/splash_screen.dart, and
// `test/brand_mark_test.dart` fails if the two drift apart.

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

// A launcher icon cannot follow the device's light/dark setting, so it commits
// to the Daylight palette's accent roles.
const int accentArgb = 0xFF1E6B54;
const int plateArgb = 0xFFE3F0EA;
const int transparentArgb = 0x00000000;

/// Proportions copied from `_MarkPainter`. All are fractions of the side.
const double kPlateRadius = 0.26;
const double kStrokeWidth = 0.085;
const double kLeft = 0.24;
const double kRight = 0.76;
const double kBottom = 0.72;
const double kTop = 0.30;
const double kDotScale = 0.85;

/// Anti-aliasing quality: 4 means 16 samples per pixel.
const int kSupersample = 4;

class Rgba {
  final int a, r, g, b;
  const Rgba(this.a, this.r, this.g, this.b);

  factory Rgba.fromArgb(int argb) => Rgba(
        (argb >> 24) & 0xFF,
        (argb >> 16) & 0xFF,
        (argb >> 8) & 0xFF,
        argb & 0xFF,
      );
}

/// Distance from a point to a line segment.
double _distanceToSegment(
  double px,
  double py,
  double ax,
  double ay,
  double bx,
  double by,
) {
  final dx = bx - ax;
  final dy = by - ay;
  final lengthSquared = dx * dx + dy * dy;
  var t = lengthSquared == 0
      ? 0.0
      : ((px - ax) * dx + (py - ay) * dy) / lengthSquared;
  if (t < 0) t = 0;
  if (t > 1) t = 1;
  final cx = ax + t * dx;
  final cy = ay + t * dy;
  return math.sqrt((px - cx) * (px - cx) + (py - cy) * (py - cy));
}

/// True when a point lies inside a rounded square covering `[0, side]`.
bool insideRoundedSquare(double x, double y, double side, double radius) {
  if (x < 0 || y < 0 || x > side || y > side) return false;
  if (radius <= 0) return true;
  final low = radius;
  final high = side - radius;
  // The cross-shaped core is always inside; only the four corners need a
  // radius test.
  if (x >= low && x <= high) return true;
  if (y >= low && y <= high) return true;
  final cx = x < low ? low : high;
  final cy = y < low ? low : high;
  final dx = x - cx;
  final dy = y - cy;
  return dx * dx + dy * dy <= radius * radius;
}

/// The three rising steps, as segments in a box of `side`.
List<List<double>> stepSegments(double side) {
  final left = kLeft * side;
  final right = kRight * side;
  final bottom = kBottom * side;
  final top = kTop * side;
  final stepWidth = (right - left) / 3;
  final stepHeight = (bottom - top) / 3;

  final points = <List<double>>[
    [left, bottom],
  ];
  for (var i = 0; i < 3; i++) {
    final x = left + stepWidth * i;
    final y = bottom - stepHeight * i;
    points.add([x + stepWidth, y]);
    points.add([x + stepWidth, y - stepHeight]);
  }

  return [
    for (var i = 0; i < points.length - 1; i++)
      [points[i][0], points[i][1], points[i + 1][0], points[i + 1][1]],
  ];
}

/// Rasterises one square icon as RGBA bytes.
///
/// [plate] paints the backing; pass [transparentArgb] for an adaptive-icon
/// foreground layer. [square] fills the whole canvas rather than rounding it,
/// which is what iOS wants — it applies its own corner mask, and a pre-rounded
/// icon shows a dark fringe outside it. [inset] shrinks the mark within the
/// canvas for layers that get cropped.
Uint8List renderIcon(
  int size, {
  required int plate,
  bool square = false,
  double inset = 1.0,
}) {
  final pixels = Uint8List(size * size * 4);
  final plateColor = Rgba.fromArgb(plate);
  final markColor = Rgba.fromArgb(accentArgb);

  final markSide = size * inset;
  final origin = (size - markSide) / 2;

  final segments = stepSegments(markSide);
  final halfStroke = kStrokeWidth * markSide / 2;
  final dotRadius = kStrokeWidth * markSide * kDotScale;
  final dotX = kLeft * markSide;
  final dotY = kBottom * markSide;
  final plateRadius = square ? 0.0 : kPlateRadius * size;

  const step = 1.0 / kSupersample;
  const samplesPerPixel = kSupersample * kSupersample;

  for (var py = 0; py < size; py++) {
    for (var px = 0; px < size; px++) {
      var plateHits = 0;
      var markHits = 0;

      for (var sy = 0; sy < kSupersample; sy++) {
        for (var sx = 0; sx < kSupersample; sx++) {
          final x = px + (sx + 0.5) * step;
          final y = py + (sy + 0.5) * step;

          if (insideRoundedSquare(x, y, size.toDouble(), plateRadius)) {
            plateHits++;
          }

          final mx = x - origin;
          final my = y - origin;
          final ddx = mx - dotX;
          final ddy = my - dotY;
          var onMark = ddx * ddx + ddy * ddy <= dotRadius * dotRadius;
          if (!onMark) {
            for (final s in segments) {
              if (_distanceToSegment(mx, my, s[0], s[1], s[2], s[3]) <=
                  halfStroke) {
                onMark = true;
                break;
              }
            }
          }
          if (onMark) markHits++;
        }
      }

      final plateAlpha = plateColor.a * plateHits / samplesPerPixel;
      final markAlpha = markColor.a * markHits / samplesPerPixel;

      // Mark over plate, both over transparency.
      final outAlpha = markAlpha + plateAlpha * (1 - markAlpha / 255);
      int channel(int mark, int under) {
        if (outAlpha <= 0) return 0;
        final top = mark * markAlpha;
        final bottom = under * plateAlpha * (1 - markAlpha / 255);
        return ((top + bottom) / outAlpha).round().clamp(0, 255);
      }

      final i = (py * size + px) * 4;
      pixels[i] = channel(markColor.r, plateColor.r);
      pixels[i + 1] = channel(markColor.g, plateColor.g);
      pixels[i + 2] = channel(markColor.b, plateColor.b);
      pixels[i + 3] = outAlpha.round().clamp(0, 255);
    }
  }
  return pixels;
}

// ---- PNG encoding --------------------------------------------------------

final List<int> _crcTable = List<int>.generate(256, (n) {
  var c = n;
  for (var k = 0; k < 8; k++) {
    c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
  }
  return c;
});

int _crc32(List<int> bytes) {
  var c = 0xFFFFFFFF;
  for (final byte in bytes) {
    c = _crcTable[(c ^ byte) & 0xFF] ^ (c >> 8);
  }
  return (c ^ 0xFFFFFFFF) & 0xFFFFFFFF;
}

List<int> _be32(int value) => [
      (value >> 24) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 8) & 0xFF,
      value & 0xFF,
    ];

List<int> _chunk(String type, List<int> data) {
  final typeBytes = type.codeUnits;
  return [
    ..._be32(data.length),
    ...typeBytes,
    ...data,
    ..._be32(_crc32([...typeBytes, ...data])),
  ];
}

/// Encodes RGBA pixels as PNG. [opaque] drops the alpha channel, which App
/// Store Connect requires of the 1024 marketing icon.
Uint8List encodePng(Uint8List rgba, int size, {bool opaque = false}) {
  final raw = <int>[];
  for (var y = 0; y < size; y++) {
    raw.add(0); // filter: none
    for (var x = 0; x < size; x++) {
      final i = (y * size + x) * 4;
      raw
        ..add(rgba[i])
        ..add(rgba[i + 1])
        ..add(rgba[i + 2]);
      if (!opaque) raw.add(rgba[i + 3]);
    }
  }

  final ihdr = <int>[
    ..._be32(size),
    ..._be32(size),
    8, // bit depth
    opaque ? 2 : 6, // colour type: RGB or RGBA
    0, 0, 0, // deflate, adaptive filtering, no interlace
  ];

  return Uint8List.fromList([
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
    ..._chunk('IHDR', ihdr),
    ..._chunk('IDAT', ZLibCodec(level: 9).encode(raw)),
    ..._chunk('IEND', const <int>[]),
  ]);
}


/// The Play feature graphic: 1024x500, no text.
///
/// Play overlays the app name and icon on this in several places and crops it
/// differently on each, so it carries no words of its own and keeps the mark
/// well inside the safe area.
Uint8List renderFeatureGraphic(int width, int height) {
  final pixels = Uint8List(width * height * 4);
  final plate = Rgba.fromArgb(plateArgb);
  final mark = Rgba.fromArgb(accentArgb);

  // The mark's drawn content occupies only the middle ~45% of its own box, so
  // the box is set larger than the banner to make the steps read at a glance.
  // It is placed left of centre: Play draws the app name and icon over this
  // graphic in several placements, and the right side has to stay clear.
  final side = height * 1.07;
  final originY = (height - side) / 2;
  // Put the visible centre of the mark at 30% of the width.
  final originX = width * 0.30 - side / 2;

  final segments = stepSegments(side);
  final halfStroke = kStrokeWidth * side / 2;
  final dotRadius = kStrokeWidth * side * kDotScale;
  final dotX = kLeft * side;
  final dotY = kBottom * side;

  const step = 1.0 / kSupersample;
  const samplesPerPixel = kSupersample * kSupersample;

  // A hairline of the accent along the bottom, the same device the app uses to
  // separate a section from its ground.
  final ruleTop = height - height * 0.035;

  for (var py = 0; py < height; py++) {
    for (var px = 0; px < width; px++) {
      var markHits = 0;
      for (var sy = 0; sy < kSupersample; sy++) {
        for (var sx = 0; sx < kSupersample; sx++) {
          final x = px + (sx + 0.5) * step - originX;
          final y = py + (sy + 0.5) * step - originY;
          final ddx = x - dotX;
          final ddy = y - dotY;
          var on = ddx * ddx + ddy * ddy <= dotRadius * dotRadius;
          if (!on) {
            for (final s in segments) {
              if (_distanceToSegment(x, y, s[0], s[1], s[2], s[3]) <=
                  halfStroke) {
                on = true;
                break;
              }
            }
          }
          if (on) markHits++;
        }
      }

      final coverage = markHits / samplesPerPixel;
      final onRule = py >= ruleTop;
      final alpha = onRule ? 1.0 : coverage;

      final i = (py * width + px) * 4;
      int blend(int top, int bottom) =>
          (top * alpha + bottom * (1 - alpha)).round().clamp(0, 255);
      pixels[i] = blend(mark.r, plate.r);
      pixels[i + 1] = blend(mark.g, plate.g);
      pixels[i + 2] = blend(mark.b, plate.b);
      pixels[i + 3] = 255;
    }
  }
  return pixels;
}

/// Like [encodePng] but for a non-square image.
Uint8List encodePng2(Uint8List rgba, int width, int height,
    {bool opaque = false}) {
  final raw = <int>[];
  for (var y = 0; y < height; y++) {
    raw.add(0);
    for (var x = 0; x < width; x++) {
      final i = (y * width + x) * 4;
      raw..add(rgba[i])..add(rgba[i + 1])..add(rgba[i + 2]);
      if (!opaque) raw.add(rgba[i + 3]);
    }
  }
  final ihdr = <int>[
    ..._be32(width),
    ..._be32(height),
    8,
    opaque ? 2 : 6,
    0, 0, 0,
  ];
  return Uint8List.fromList([
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
    ..._chunk('IHDR', ihdr),
    ..._chunk('IDAT', ZLibCodec(level: 9).encode(raw)),
    ..._chunk('IEND', const <int>[]),
  ]);
}

void write(String path, Uint8List bytes) {
  final file = File(path);
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(bytes);
  final kb = (bytes.length / 1024).toStringAsFixed(1).padLeft(7);
  stdout.writeln('  ${kb}K  $path');
}

void main() {
  const androidDensities = <String, int>{
    'mipmap-mdpi': 48,
    'mipmap-hdpi': 72,
    'mipmap-xhdpi': 96,
    'mipmap-xxhdpi': 144,
    'mipmap-xxxhdpi': 192,
  };

  stdout.writeln('Android legacy:');
  for (final entry in androidDensities.entries) {
    write(
      'android/app/src/main/res/${entry.key}/ic_launcher.png',
      encodePng(renderIcon(entry.value, plate: plateArgb), entry.value),
    );
  }

  // Android masks adaptive icons to the launcher's shape and can crop 18% from
  // each edge, so the mark sits at 62% of the layer and the plate colour moves
  // to a separate background resource.
  stdout.writeln('Android adaptive foreground:');
  for (final entry in androidDensities.entries) {
    final size = (entry.value * 1.5).round(); // adaptive layers are 108dp
    write(
      'android/app/src/main/res/${entry.key}/ic_launcher_foreground.png',
      encodePng(
        renderIcon(size, plate: transparentArgb, square: true, inset: 0.62),
        size,
      ),
    );
  }

  const iosSizes = <String, int>{
    'Icon-App-20x20@1x.png': 20,
    'Icon-App-20x20@2x.png': 40,
    'Icon-App-20x20@3x.png': 60,
    'Icon-App-29x29@1x.png': 29,
    'Icon-App-29x29@2x.png': 58,
    'Icon-App-29x29@3x.png': 87,
    'Icon-App-40x40@1x.png': 40,
    'Icon-App-40x40@2x.png': 80,
    'Icon-App-40x40@3x.png': 120,
    'Icon-App-60x60@2x.png': 120,
    'Icon-App-60x60@3x.png': 180,
    'Icon-App-76x76@1x.png': 76,
    'Icon-App-76x76@2x.png': 152,
    'Icon-App-83.5x83.5@2x.png': 167,
    'Icon-App-1024x1024@1x.png': 1024,
  };
  stdout.writeln('iOS:');
  for (final entry in iosSizes.entries) {
    write(
      'ios/Runner/Assets.xcassets/AppIcon.appiconset/${entry.key}',
      encodePng(
        renderIcon(entry.value, plate: plateArgb, square: true),
        entry.value,
        opaque: true,
      ),
    );
  }

  stdout.writeln('Play listing:');
  write(
    'store/play/icon-512.png',
    encodePng(renderIcon(512, plate: plateArgb, square: true), 512),
  );
  write('store/play/feature-graphic-1024x500.png', encodePng2(
    renderFeatureGraphic(1024, 500), 1024, 500, opaque: true));

  stdout.writeln('Web:');
  for (final entry in <String, int>{
    'web/favicon.png': 32,
    'web/icons/Icon-192.png': 192,
    'web/icons/Icon-512.png': 512,
  }.entries) {
    write(
      entry.key,
      encodePng(renderIcon(entry.value, plate: plateArgb), entry.value),
    );
  }
  for (final entry in <String, int>{
    'web/icons/Icon-maskable-192.png': 192,
    'web/icons/Icon-maskable-512.png': 512,
  }.entries) {
    write(
      entry.key,
      encodePng(
        renderIcon(entry.value, plate: plateArgb, square: true, inset: 0.62),
        entry.value,
      ),
    );
  }

  stdout.writeln('\nDone.');
}

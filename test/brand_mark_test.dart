import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Keeps the launcher-icon generator honest.
///
/// `tool/generate_launcher_icons.dart` is plain Dart — it cannot import the
/// Flutter widget, so it re-states the mark's proportions as its own constants.
/// That is a duplication, and duplications drift: someone tweaks the painter in
/// `splash_screen.dart`, the app changes, and the icon on the home screen
/// quietly stops matching the app it launches.
///
/// So this reads both files and asserts the numbers still agree. It compares
/// source text rather than behaviour because the painter's values live inside
/// a `CustomPainter.paint` body, and reaching them any other way would mean
/// building the widget — which is exactly what the generator avoids.
void main() {
  final painter =
      File('lib/features/splash/splash_screen.dart').readAsStringSync();
  final generator =
      File('tool/generate_launcher_icons.dart').readAsStringSync();

  /// Reads `<name> = <number>` out of a source file.
  ///
  /// Both sides now declare the geometry as named constants — `MarkGeometry`
  /// in the widget, `k…` in the generator — so this compares declarations
  /// rather than digging factors out of a paint body. When the shape changes,
  /// exactly two numbers have to change together, and this says so by name.
  String constantIn(String source, String name, String where) {
    final match = RegExp('\\b$name\\s*=\\s*(\\d+\\.?\\d*)').firstMatch(source);
    expect(match, isNotNull, reason: 'no `$name` found in $where');
    return match!.group(1)!;
  }

  test('the icon generator draws the same letter as the app mark', () {
    // Painter name -> generator name. Every proportion of the P is here; miss
    // one and the icon is a subtly different letter from the logo.
    const pairs = <String, String>{
      'stroke': 'kStrokeWidth',
      'stemX': 'kStemX',
      'stemTop': 'kStemTop',
      'stemBottom': 'kStemBottom',
      'bowlBottom': 'kBowlBottom',
      'bowlX': 'kBowlX',
      'plateRadius': 'kPlateRadius',
    };

    pairs.forEach((inWidget, inGenerator) {
      expect(
        constantIn(generator, inGenerator, 'the generator'),
        constantIn(painter, inWidget, 'MarkGeometry'),
        reason: '$inGenerator has drifted from MarkGeometry.$inWidget',
      );
    });
  });

  test('the bowl is a half circle in both, or the arc radius disagrees', () {
    // The widget draws a real arc and the generator approximates one with a
    // polyline. Both derive the radius the same way — (bowlBottom - stemTop)/2
    // — so the only way they can disagree is if one of them stops doing that.
    expect(painter.contains('(bowlBottom - stemTop) / 2'), isTrue,
        reason: 'MarkGeometry no longer derives the arc radius from the bowl');
    expect(generator.contains('(kBowlBottom - kStemTop) / 2'), isTrue,
        reason: 'the generator no longer derives the arc radius from the bowl');
  });

  test('the letter fits inside its plate', () {
    // Half the stroke sticks out past the path on every side. If that reaches
    // the edge the icon is clipped by the launcher's mask, which only shows up
    // on a device.
    double value(String name) =>
        double.parse(constantIn(painter, name, 'MarkGeometry'));

    final half = value('stroke') / 2;
    final radius = (value('bowlBottom') - value('stemTop')) / 2;

    expect(value('stemX') - half, greaterThan(0.12),
        reason: 'the stem is too close to the left edge');
    expect(value('bowlX') + radius + half, lessThan(0.88),
        reason: 'the bowl is too close to the right edge');
    expect(value('stemTop') - half, greaterThan(0.12),
        reason: 'the letter is too close to the top edge');
    expect(value('stemBottom') + half, lessThan(0.88),
        reason: 'the letter is too close to the bottom edge');
  });

  test('every icon the stores ask for exists', () {
    // A missing density is not a build failure — it is a blurry icon, or on
    // iOS an upload rejection, discovered at submission time.
    const required = <String>[
      'android/app/src/main/res/mipmap-mdpi/ic_launcher.png',
      'android/app/src/main/res/mipmap-hdpi/ic_launcher.png',
      'android/app/src/main/res/mipmap-xhdpi/ic_launcher.png',
      'android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png',
      'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png',
      'android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml',
      'android/app/src/main/res/values/ic_launcher_background.xml',
      'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png',
      'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@3x.png',
      'store/play/icon-512.png',
    ];
    for (final path in required) {
      expect(File(path).existsSync(), isTrue, reason: 'missing $path');
    }
  });

  test('the iOS marketing icon has no alpha channel', () {
    // App Store Connect rejects a 1024 icon with transparency. PNG colour type
    // lives at byte 25: 2 is RGB, 6 is RGBA.
    final bytes = File(
      'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png',
    ).readAsBytesSync();
    expect(bytes[25], 2,
        reason: 'the 1024 icon still carries an alpha channel');
  });
}

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
  /// Every `<name> * size.<axis>` or `* markSide` factor, keyed by what it
  /// multiplies.
  Map<String, String> factorsIn(String source, List<String> names) {
    final found = <String, String>{};
    for (final name in names) {
      final capitalised = '${name[0].toUpperCase()}${name.substring(1)}';
      // Matches either the painter's "final left = size.width * 0.24;" or the
      // generator's "const kLeft = 0.24;".
      // Not a raw string: it interpolates the name being looked for, so the
      // backslashes are doubled.
      final match = RegExp(
        '(?:final\\s+$name\\s*=\\s*[\\w.]+\\s*\\*\\s*'
        '|k$capitalised\\s*=\\s*)'
        '(\\d+\\.?\\d*)',
      ).firstMatch(source);
      if (match != null) found[name] = match.group(1)!;
    }
    return found;
  }

  test('the icon generator uses the same proportions as the app mark', () {
    final painter =
        File('lib/features/splash/splash_screen.dart').readAsStringSync();
    final generator =
        File('tool/generate_launcher_icons.dart').readAsStringSync();

    const names = ['left', 'right', 'bottom', 'top'];
    final fromPainter = factorsIn(painter, names);
    final fromGenerator = factorsIn(generator, names);

    expect(fromPainter.length, names.length,
        reason:
            'could not read the mark proportions out of splash_screen.dart');
    expect(fromGenerator, fromPainter,
        reason:
            'tool/generate_launcher_icons.dart has drifted from _MarkPainter');
  });

  test('stroke, plate radius and dot scale agree', () {
    final painter =
        File('lib/features/splash/splash_screen.dart').readAsStringSync();
    final generator =
        File('tool/generate_launcher_icons.dart').readAsStringSync();

    String painterValue(RegExp pattern, String label) {
      final match = pattern.firstMatch(painter);
      expect(match, isNotNull, reason: 'no $label found in the painter');
      return match!.group(1)!;
    }

    String generatorValue(String constant) {
      final match =
          RegExp('$constant\\s*=\\s*(\\d+\\.?\\d*)').firstMatch(generator);
      expect(match, isNotNull, reason: 'no $constant in the generator');
      return match!.group(1)!;
    }

    expect(
      generatorValue('kStrokeWidth'),
      painterValue(
          RegExp(r'final stroke = size\.width \* (\d+\.?\d*)'), 'stroke'),
    );
    expect(
      generatorValue('kPlateRadius'),
      painterValue(
          RegExp(r'final radius = size\.width \* (\d+\.?\d*)'), 'plate radius'),
    );
    expect(
      generatorValue('kDotScale'),
      painterValue(RegExp(r'stroke \* (\d+\.?\d*)'), 'dot scale'),
    );
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

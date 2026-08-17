import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prayan_trading_journal/design/palette.dart';

/// Guards the accessibility promise made in `palette.dart`.
///
/// The brief requires sufficient contrast (§2) and forbids relying on colour
/// alone (§11, §36). A colour tweak that quietly drops a text role below WCAG
/// AA is exactly the kind of regression nobody notices in review, so it is
/// asserted here instead.
void main() {
  /// Relative luminance per WCAG 2.1.
  double luminance(Color color) {
    double channel(double value) {
      final v = value;
      return v <= 0.03928
          ? v / 12.92
          : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
    }

    return 0.2126 * channel(color.r) +
        0.7152 * channel(color.g) +
        0.0722 * channel(color.b);
  }

  /// Contrast ratio between two opaque colours, 1.0 to 21.0.
  double contrast(Color foreground, Color background) {
    final a = luminance(foreground);
    final b = luminance(background);
    final lighter = math.max(a, b);
    final darker = math.min(a, b);
    return (lighter + 0.05) / (darker + 0.05);
  }

  /// WCAG AA: 4.5:1 for body text.
  const bodyMinimum = 4.5;

  /// WCAG AA: 3:1 for large text and non-text indicators such as the score
  /// arc, chart lines and status icons.
  const largeMinimum = 3.0;

  for (final theme in PrayanTheme.values) {
    group('${theme.label} palette', () {
      final colors = theme.colors;

      test('primary text on every surface meets AA for body text', () {
        for (final (surface, name) in [
          (colors.canvas, 'canvas'),
          (colors.surface, 'surface'),
          (colors.surfaceRaised, 'surfaceRaised'),
          (colors.surfaceSunken, 'surfaceSunken'),
        ]) {
          expect(
            contrast(colors.textPrimary, surface),
            greaterThanOrEqualTo(bodyMinimum),
            reason: '${theme.label}: textPrimary on $name',
          );
        }
      });

      test('secondary text meets AA on canvas and surface', () {
        for (final (surface, name) in [
          (colors.canvas, 'canvas'),
          (colors.surface, 'surface'),
        ]) {
          expect(
            contrast(colors.textSecondary, surface),
            greaterThanOrEqualTo(bodyMinimum),
            reason: '${theme.label}: textSecondary on $name',
          );
        }
      });

      test('tertiary text meets the large-text threshold', () {
        // Tertiary is used only for uppercase metric labels and captions,
        // which are rendered semibold — the large-text threshold applies.
        expect(
          contrast(colors.textTertiary, colors.surface),
          greaterThanOrEqualTo(largeMinimum),
          reason: '${theme.label}: textTertiary on surface',
        );
      });

      test('result colours are distinguishable from their surface', () {
        for (final (color, name) in [
          (colors.positive, 'positive'),
          (colors.negative, 'negative'),
          (colors.neutral, 'neutral'),
          (colors.accent, 'accent'),
          (colors.warning, 'warning'),
          (colors.violation, 'violation'),
          (colors.compliant, 'compliant'),
        ]) {
          expect(
            contrast(color, colors.surface),
            greaterThanOrEqualTo(largeMinimum),
            reason: '${theme.label}: $name on surface',
          );
        }
      });

      test('text on the accent fill is legible', () {
        expect(
          contrast(colors.onAccent, colors.accent),
          greaterThanOrEqualTo(largeMinimum),
          reason: '${theme.label}: onAccent on accent',
        );
      });

      test('positive and negative are separated by hue, not luminance', () {
        // Deliberately NOT a luminance-contrast assertion. The palette keeps
        // the two results at similar luminance on purpose — that is what makes
        // it read as calm rather than as a trading terminal, and the brief
        // rejects "flashing P&L" and "excessive red/green dependence" (§36).
        //
        // Similar luminance means a red/green colour-blind user cannot tell
        // them apart by colour, so the product never asks them to: every P&L
        // surface also carries an explicit +/- sign, and result markers differ
        // in shape (filled vs hollow). Those redundancies are asserted in
        // `result_semantics_test.dart`.
        //
        // What is checked here is that users who *can* see hue get a clear
        // separation, which is a genuine palette property.
        final positiveHue = HSLColor.fromColor(colors.positive).hue;
        final negativeHue = HSLColor.fromColor(colors.negative).hue;
        final delta = (positiveHue - negativeHue).abs();
        final separation = delta > 180 ? 360 - delta : delta;
        expect(
          separation,
          greaterThan(60),
          reason: '${theme.label}: positive and negative hues are too close',
        );
      });

      test('borders are visible against their surfaces', () {
        expect(
          contrast(colors.border, colors.surface),
          greaterThan(1.05),
          reason: '${theme.label}: border on surface',
        );
      });
    });
  }

  test('every theme resolves to a palette and a stable wire name', () {
    for (final theme in PrayanTheme.values) {
      expect(PrayanTheme.fromWire(theme.wireName), theme);
    }
    expect(PrayanTheme.fromWire('something-new'), PrayanTheme.daylight);
    expect(PrayanTheme.fromWire(null), PrayanTheme.daylight);
  });

  test('two light themes and two dark themes are offered', () {
    final light = PrayanTheme.values
        .where((t) => t.brightness == Brightness.light)
        .length;
    final dark =
        PrayanTheme.values.where((t) => t.brightness == Brightness.dark).length;
    // The brief asks for light, dark and at least two more selectable themes.
    expect(light, greaterThanOrEqualTo(2));
    expect(dark, greaterThanOrEqualTo(2));
  });
}

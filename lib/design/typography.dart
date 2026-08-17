import 'package:flutter/material.dart';

/// The type scale.
///
/// Two families, used consistently:
///  * a platform UI sans for all prose, which renders natively and ships no
///    font payload;
///  * a tabular/monospaced face for every number the user compares — P&L
///    columns, R-multiples, prices. Proportional digits make a trade list
///    impossible to scan because the decimal points do not line up.
///
/// Numbers additionally use [FontFeature.tabularFigures] so digit widths are
/// fixed even within the sans family.
class PrayanType {
  const PrayanType._();

  /// Explicit `null` means "the platform's own UI font" — San Francisco on
  /// iOS, Roboto on Android. Deliberate: a bundled sans would look foreign on
  /// one of the two platforms, and the brief wants native-feeling polish.
  static const String? uiFamily = null;

  /// Fallback stack for numerals. The first entry that exists on the device
  /// wins; all are metrics-compatible enough for column alignment.
  static const List<String> numericFallback = <String>[
    'SF Mono',
    'Roboto Mono',
    'DejaVu Sans Mono',
    'monospace',
  ];

  static const FontFeature _tabular = FontFeature.tabularFigures();

  /// Body and UI text.
  static TextTheme textTheme(Color primary, Color secondary) => TextTheme(
        // Display — reserved for the discipline score itself.
        displayLarge: TextStyle(
          fontSize: 48,
          height: 1.05,
          fontWeight: FontWeight.w600,
          letterSpacing: -1.2,
          color: primary,
          fontFeatures: const [_tabular],
        ),
        displayMedium: TextStyle(
          fontSize: 36,
          height: 1.1,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.8,
          color: primary,
          fontFeatures: const [_tabular],
        ),

        // Headlines — screen titles.
        headlineLarge: TextStyle(
          fontSize: 28,
          height: 1.2,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.5,
          color: primary,
        ),
        headlineMedium: TextStyle(
          fontSize: 22,
          height: 1.25,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
          color: primary,
        ),
        headlineSmall: TextStyle(
          fontSize: 18,
          height: 1.3,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
          color: primary,
        ),

        // Titles — card headers, list leading text.
        titleLarge: TextStyle(
          fontSize: 17,
          height: 1.35,
          fontWeight: FontWeight.w600,
          color: primary,
        ),
        titleMedium: TextStyle(
          fontSize: 15,
          height: 1.4,
          fontWeight: FontWeight.w600,
          color: primary,
        ),
        titleSmall: TextStyle(
          fontSize: 13,
          height: 1.4,
          fontWeight: FontWeight.w600,
          color: secondary,
        ),

        // Body.
        bodyLarge: TextStyle(
          fontSize: 16,
          height: 1.5,
          fontWeight: FontWeight.w400,
          color: primary,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          height: 1.5,
          fontWeight: FontWeight.w400,
          color: primary,
        ),
        bodySmall: TextStyle(
          fontSize: 13,
          height: 1.45,
          fontWeight: FontWeight.w400,
          color: secondary,
        ),

        // Labels — buttons, chips, overlines.
        labelLarge: TextStyle(
          fontSize: 15,
          height: 1.2,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
          color: primary,
        ),
        labelMedium: TextStyle(
          fontSize: 13,
          height: 1.2,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
          color: secondary,
        ),
        labelSmall: TextStyle(
          fontSize: 11,
          height: 1.2,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
          color: secondary,
        ),
      );

  /// A large figure: today's P&L, the R-multiple on a trade detail.
  static TextStyle metric(Color color, {double size = 26}) => TextStyle(
        fontFamilyFallback: numericFallback,
        fontSize: size,
        height: 1.15,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.4,
        color: color,
        fontFeatures: const [_tabular],
      );

  /// A figure inside a dense list or table.
  static TextStyle figure(Color color, {double size = 14}) => TextStyle(
        fontFamilyFallback: numericFallback,
        fontSize: size,
        height: 1.3,
        fontWeight: FontWeight.w500,
        color: color,
        fontFeatures: const [_tabular],
      );

  /// The caption above a metric ("Today's P&L").
  static TextStyle metricLabel(Color color) => TextStyle(
        fontSize: 11,
        height: 1.2,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.7,
        color: color,
      );
}

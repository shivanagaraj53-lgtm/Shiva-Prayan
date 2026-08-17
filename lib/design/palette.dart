import 'package:flutter/material.dart';

/// The semantic colour contract every Prayan surface paints against.
///
/// Widgets never reference a raw hex value or a Material swatch — they read
/// these roles. That is what lets four themes coexist without a single
/// conditional in feature code, and it is what keeps the brief's "avoid
/// excessive red/green dependence" (§36) enforceable in one place.
@immutable
class PrayanColors extends ThemeExtension<PrayanColors> {
  // --- Surfaces ---------------------------------------------------------
  /// The page behind everything.
  final Color canvas;

  /// Cards and raised containers.
  final Color surface;

  /// A surface one step above [surface]: nested cards, selected rows.
  final Color surfaceRaised;

  /// Sunken wells: input fields, progress tracks.
  final Color surfaceSunken;

  /// Hairlines and dividers.
  final Color border;

  /// A stronger border for focused or selected elements.
  final Color borderStrong;

  // --- Content ----------------------------------------------------------
  /// Primary reading colour.
  final Color textPrimary;

  /// Supporting copy and labels.
  final Color textSecondary;

  /// De-emphasised metadata, placeholder text.
  final Color textTertiary;

  /// Text drawn on top of [accent].
  final Color onAccent;

  // --- Brand ------------------------------------------------------------
  /// The single brand accent. Used for the discipline ring, primary actions
  /// and selected states — and deliberately nothing else, so it keeps meaning.
  final Color accent;

  /// A muted wash of [accent] for backgrounds behind accent content.
  final Color accentMuted;

  // --- Result semantics -------------------------------------------------
  /// Positive result. A desaturated teal-green rather than a trading-terminal
  /// green: the brief explicitly rejects flashing P&L and gambling aesthetics.
  final Color positive;
  final Color positiveMuted;

  /// Negative result. A muted terracotta, not an alarm red — a loss inside the
  /// rules is a normal business outcome, and the palette should not shout.
  final Color negative;
  final Color negativeMuted;

  /// Breakeven / no-result.
  final Color neutral;
  final Color neutralMuted;

  // --- Rule semantics ---------------------------------------------------
  /// A followed rule.
  final Color compliant;

  /// A warning-severity breach.
  final Color warning;
  final Color warningMuted;

  /// A major breach. The one place a genuinely urgent colour is warranted.
  final Color violation;
  final Color violationMuted;

  /// Overlay behind modal sheets.
  final Color scrim;

  const PrayanColors({
    required this.canvas,
    required this.surface,
    required this.surfaceRaised,
    required this.surfaceSunken,
    required this.border,
    required this.borderStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.onAccent,
    required this.accent,
    required this.accentMuted,
    required this.positive,
    required this.positiveMuted,
    required this.negative,
    required this.negativeMuted,
    required this.neutral,
    required this.neutralMuted,
    required this.compliant,
    required this.warning,
    required this.warningMuted,
    required this.violation,
    required this.violationMuted,
    required this.scrim,
  });

  /// Colour for a signed result. Returns [neutral] at exactly zero rather than
  /// defaulting to positive, so a scratch trade is never dressed up as a win.
  Color forSign(int signum) => switch (signum) {
        > 0 => positive,
        < 0 => negative,
        _ => neutral,
      };

  Color mutedForSign(int signum) => switch (signum) {
        > 0 => positiveMuted,
        < 0 => negativeMuted,
        _ => neutralMuted,
      };

  @override
  PrayanColors copyWith({
    Color? canvas,
    Color? surface,
    Color? surfaceRaised,
    Color? surfaceSunken,
    Color? border,
    Color? borderStrong,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? onAccent,
    Color? accent,
    Color? accentMuted,
    Color? positive,
    Color? positiveMuted,
    Color? negative,
    Color? negativeMuted,
    Color? neutral,
    Color? neutralMuted,
    Color? compliant,
    Color? warning,
    Color? warningMuted,
    Color? violation,
    Color? violationMuted,
    Color? scrim,
  }) =>
      PrayanColors(
        canvas: canvas ?? this.canvas,
        surface: surface ?? this.surface,
        surfaceRaised: surfaceRaised ?? this.surfaceRaised,
        surfaceSunken: surfaceSunken ?? this.surfaceSunken,
        border: border ?? this.border,
        borderStrong: borderStrong ?? this.borderStrong,
        textPrimary: textPrimary ?? this.textPrimary,
        textSecondary: textSecondary ?? this.textSecondary,
        textTertiary: textTertiary ?? this.textTertiary,
        onAccent: onAccent ?? this.onAccent,
        accent: accent ?? this.accent,
        accentMuted: accentMuted ?? this.accentMuted,
        positive: positive ?? this.positive,
        positiveMuted: positiveMuted ?? this.positiveMuted,
        negative: negative ?? this.negative,
        negativeMuted: negativeMuted ?? this.negativeMuted,
        neutral: neutral ?? this.neutral,
        neutralMuted: neutralMuted ?? this.neutralMuted,
        compliant: compliant ?? this.compliant,
        warning: warning ?? this.warning,
        warningMuted: warningMuted ?? this.warningMuted,
        violation: violation ?? this.violation,
        violationMuted: violationMuted ?? this.violationMuted,
        scrim: scrim ?? this.scrim,
      );

  @override
  PrayanColors lerp(ThemeExtension<PrayanColors>? other, double t) {
    if (other is! PrayanColors) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t) ?? a;
    return PrayanColors(
      canvas: mix(canvas, other.canvas),
      surface: mix(surface, other.surface),
      surfaceRaised: mix(surfaceRaised, other.surfaceRaised),
      surfaceSunken: mix(surfaceSunken, other.surfaceSunken),
      border: mix(border, other.border),
      borderStrong: mix(borderStrong, other.borderStrong),
      textPrimary: mix(textPrimary, other.textPrimary),
      textSecondary: mix(textSecondary, other.textSecondary),
      textTertiary: mix(textTertiary, other.textTertiary),
      onAccent: mix(onAccent, other.onAccent),
      accent: mix(accent, other.accent),
      accentMuted: mix(accentMuted, other.accentMuted),
      positive: mix(positive, other.positive),
      positiveMuted: mix(positiveMuted, other.positiveMuted),
      negative: mix(negative, other.negative),
      negativeMuted: mix(negativeMuted, other.negativeMuted),
      neutral: mix(neutral, other.neutral),
      neutralMuted: mix(neutralMuted, other.neutralMuted),
      compliant: mix(compliant, other.compliant),
      warning: mix(warning, other.warning),
      warningMuted: mix(warningMuted, other.warningMuted),
      violation: mix(violation, other.violation),
      violationMuted: mix(violationMuted, other.violationMuted),
      scrim: mix(scrim, other.scrim),
    );
  }
}

/// The selectable themes (§2 asks for light, dark and at least two more).
enum PrayanTheme {
  /// Default light. Cool paper, ink text.
  daylight('daylight', 'Daylight', Brightness.light),

  /// Default dark. Deep navy-slate, not pure black, so OLED smear and harsh
  /// contrast are both avoided.
  midnight('midnight', 'Midnight', Brightness.dark),

  /// Warm light. Lower blue content for long evening review sessions.
  parchment('parchment', 'Parchment', Brightness.light),

  /// Neutral high-contrast dark, for bright environments and users who want
  /// maximum legibility.
  graphite('graphite', 'Graphite', Brightness.dark);

  const PrayanTheme(this.wireName, this.label, this.brightness);
  final String wireName;
  final String label;
  final Brightness brightness;

  static PrayanTheme fromWire(String? name) {
    for (final theme in values) {
      if (theme.wireName == name) return theme;
    }
    return PrayanTheme.daylight;
  }

  PrayanColors get colors => switch (this) {
        PrayanTheme.daylight => Palettes.daylight,
        PrayanTheme.midnight => Palettes.midnight,
        PrayanTheme.parchment => Palettes.parchment,
        PrayanTheme.graphite => Palettes.graphite,
      };
}

/// The concrete palettes.
///
/// Contrast: every text role against its intended background meets WCAG AA
/// (4.5:1 for body, 3:1 for large text and non-text indicators). The
/// `theme_contrast_test.dart` suite asserts this so a future colour tweak
/// cannot quietly regress accessibility.
class Palettes {
  const Palettes._();

  static const daylight = PrayanColors(
    canvas: Color(0xFFF6F7F9),
    surface: Color(0xFFFFFFFF),
    surfaceRaised: Color(0xFFFFFFFF),
    surfaceSunken: Color(0xFFEDEFF3),
    border: Color(0xFFE1E5EB),
    borderStrong: Color(0xFFC7CED8),
    textPrimary: Color(0xFF12161C),
    textSecondary: Color(0xFF525C6B),
    textTertiary: Color(0xFF77818F),
    onAccent: Color(0xFFFFFFFF),
    accent: Color(0xFF1F6F5C),
    accentMuted: Color(0xFFE4F0EC),
    positive: Color(0xFF1B6B54),
    positiveMuted: Color(0xFFE2F0EB),
    negative: Color(0xFF9C4221),
    negativeMuted: Color(0xFFF8E9E2),
    neutral: Color(0xFF5B6472),
    neutralMuted: Color(0xFFEDEFF3),
    compliant: Color(0xFF1B6B54),
    warning: Color(0xFF8A5A12),
    warningMuted: Color(0xFFFAEEDC),
    violation: Color(0xFF9B2C2C),
    violationMuted: Color(0xFFF9E5E5),
    scrim: Color(0x66000000),
  );

  static const midnight = PrayanColors(
    canvas: Color(0xFF0D1117),
    surface: Color(0xFF161B23),
    surfaceRaised: Color(0xFF1D242E),
    surfaceSunken: Color(0xFF0A0E13),
    border: Color(0xFF262E3A),
    borderStrong: Color(0xFF3A4553),
    textPrimary: Color(0xFFE9EDF2),
    textSecondary: Color(0xFFA4AFBD),
    textTertiary: Color(0xFF78838F),
    onAccent: Color(0xFF06120E),
    accent: Color(0xFF4FBFA0),
    accentMuted: Color(0xFF16302A),
    positive: Color(0xFF4FBFA0),
    positiveMuted: Color(0xFF14302A),
    negative: Color(0xFFD98A66),
    negativeMuted: Color(0xFF33211A),
    neutral: Color(0xFF8B95A3),
    neutralMuted: Color(0xFF1D242E),
    compliant: Color(0xFF4FBFA0),
    warning: Color(0xFFDFA95C),
    warningMuted: Color(0xFF332920),
    violation: Color(0xFFE0736B),
    violationMuted: Color(0xFF3A1F1F),
    scrim: Color(0x99000000),
  );

  static const parchment = PrayanColors(
    canvas: Color(0xFFF7F4EE),
    surface: Color(0xFFFFFDF8),
    surfaceRaised: Color(0xFFFFFFFF),
    surfaceSunken: Color(0xFFEFEAE0),
    border: Color(0xFFE3DCCE),
    borderStrong: Color(0xFFC9BFAC),
    textPrimary: Color(0xFF1E1A14),
    textSecondary: Color(0xFF5A5245),
    textTertiary: Color(0xFF817866),
    onAccent: Color(0xFFFFFDF8),
    accent: Color(0xFF2F6D51),
    accentMuted: Color(0xFFE6EFE7),
    positive: Color(0xFF2F6D51),
    positiveMuted: Color(0xFFE6EFE7),
    negative: Color(0xFF97431F),
    negativeMuted: Color(0xFFF6E7DD),
    neutral: Color(0xFF6A6255),
    neutralMuted: Color(0xFFEFEAE0),
    compliant: Color(0xFF2F6D51),
    warning: Color(0xFF8A5A12),
    warningMuted: Color(0xFFF7EBD8),
    violation: Color(0xFF97302E),
    violationMuted: Color(0xFFF7E3E1),
    scrim: Color(0x59000000),
  );

  static const graphite = PrayanColors(
    canvas: Color(0xFF121212),
    surface: Color(0xFF1C1C1E),
    surfaceRaised: Color(0xFF262629),
    surfaceSunken: Color(0xFF0C0C0D),
    border: Color(0xFF303034),
    borderStrong: Color(0xFF48484E),
    textPrimary: Color(0xFFF2F2F4),
    textSecondary: Color(0xFFB4B4BA),
    textTertiary: Color(0xFF86868C),
    onAccent: Color(0xFF0C0C0D),
    accent: Color(0xFF6FC8B0),
    accentMuted: Color(0xFF1B2E2A),
    positive: Color(0xFF6FC8B0),
    positiveMuted: Color(0xFF1B2E2A),
    negative: Color(0xFFE09A79),
    negativeMuted: Color(0xFF33241C),
    neutral: Color(0xFF9A9AA2),
    neutralMuted: Color(0xFF262629),
    compliant: Color(0xFF6FC8B0),
    warning: Color(0xFFE6B76A),
    warningMuted: Color(0xFF332B1D),
    violation: Color(0xFFE88A82),
    violationMuted: Color(0xFF3A2320),
    scrim: Color(0x99000000),
  );
}

/// Reads the palette from the ambient theme.
extension PrayanColorsContext on BuildContext {
  PrayanColors get colors =>
      Theme.of(this).extension<PrayanColors>() ?? Palettes.daylight;
}

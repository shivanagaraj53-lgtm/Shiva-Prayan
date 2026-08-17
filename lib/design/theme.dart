import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'palette.dart';
import 'tokens.dart';
import 'typography.dart';

/// Builds the [ThemeData] for a [PrayanTheme].
///
/// Material is used as a substrate, not as a look. Every component theme below
/// exists to strip Material's defaults — the tinted surfaces, the pill buttons,
/// the drop shadows — because the brief names "generic Material defaults" as a
/// thing to avoid (§36). Depth comes from hairline borders and a single soft
/// shadow, never from stacked elevations.
class PrayanThemeBuilder {
  const PrayanThemeBuilder._();

  static ThemeData build(PrayanTheme theme) {
    final colors = theme.colors;
    final isDark = theme.brightness == Brightness.dark;

    final scheme = ColorScheme(
      brightness: theme.brightness,
      primary: colors.accent,
      onPrimary: colors.onAccent,
      secondary: colors.accent,
      onSecondary: colors.onAccent,
      error: colors.violation,
      onError: colors.onAccent,
      surface: colors.surface,
      onSurface: colors.textPrimary,
      surfaceContainerHighest: colors.surfaceRaised,
      outline: colors.border,
      outlineVariant: colors.border,
      shadow: const Color(0xFF000000),
      scrim: colors.scrim,
    );

    final textTheme =
        PrayanType.textTheme(colors.textPrimary, colors.textSecondary);

    return ThemeData(
      useMaterial3: true,
      brightness: theme.brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: colors.canvas,
      canvasColor: colors.canvas,
      fontFamily: PrayanType.uiFamily,
      textTheme: textTheme,
      splashFactory: InkSparkle.splashFactory,

      // A single, barely-there shadow. Cards read as separated by their
      // border first and their shadow second.
      cardTheme: CardThemeData(
        color: colors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: Radii.card,
          side: BorderSide(color: colors.border),
        ),
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: colors.canvas,
        foregroundColor: colors.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.headlineSmall,
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light.copyWith(
                statusBarColor: Colors.transparent,
                systemNavigationBarColor: colors.canvas,
              )
            : SystemUiOverlayStyle.dark.copyWith(
                statusBarColor: Colors.transparent,
                systemNavigationBarColor: colors.canvas,
              ),
      ),

      dividerTheme: DividerThemeData(
        color: colors.border,
        thickness: 1,
        space: 1,
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colors.accent,
          foregroundColor: colors.onAccent,
          disabledBackgroundColor: colors.surfaceSunken,
          disabledForegroundColor: colors.textTertiary,
          minimumSize: const Size.fromHeight(Sizes.minTouchTarget + 4),
          shape: const RoundedRectangleBorder(borderRadius: Radii.field),
          textStyle: textTheme.labelLarge,
          elevation: 0,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.textPrimary,
          minimumSize: const Size.fromHeight(Sizes.minTouchTarget + 4),
          side: BorderSide(color: colors.borderStrong),
          shape: const RoundedRectangleBorder(borderRadius: Radii.field),
          textStyle: textTheme.labelLarge,
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colors.accent,
          textStyle: textTheme.labelLarge,
          minimumSize: const Size(Sizes.minTouchTarget, Sizes.minTouchTarget),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceSunken,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Spacing.lg,
          vertical: Spacing.md + 2,
        ),
        border: OutlineInputBorder(
          borderRadius: Radii.field,
          borderSide: BorderSide(color: colors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: Radii.field,
          borderSide: BorderSide(color: colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: Radii.field,
          borderSide: BorderSide(color: colors.accent, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: Radii.field,
          borderSide: BorderSide(color: colors.violation),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: Radii.field,
          borderSide: BorderSide(color: colors.violation, width: 1.6),
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
        hintStyle: textTheme.bodyMedium?.copyWith(color: colors.textTertiary),
        errorStyle: textTheme.bodySmall?.copyWith(color: colors.violation),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: colors.surface,
        shape: const RoundedRectangleBorder(borderRadius: Radii.sheet),
        showDragHandle: true,
        dragHandleColor: colors.borderStrong,
        elevation: 0,
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.xl),
          side: BorderSide(color: colors.border),
        ),
        titleTextStyle: textTheme.headlineSmall,
        contentTextStyle: textTheme.bodyMedium,
      ),

      chipTheme: ChipThemeData(
        backgroundColor: colors.surfaceSunken,
        selectedColor: colors.accentMuted,
        side: BorderSide(color: colors.border),
        labelStyle: textTheme.labelMedium!,
        shape: const RoundedRectangleBorder(borderRadius: Radii.chip),
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.md,
          vertical: Spacing.sm,
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: colors.accentMuted,
        elevation: 0,
        height: Sizes.navBarHeight,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? textTheme.labelSmall!.copyWith(color: colors.accent)
              : textTheme.labelSmall!.copyWith(color: colors.textTertiary),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: Sizes.iconLg,
            color: states.contains(WidgetState.selected)
                ? colors.accent
                : colors.textTertiary,
          ),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: colors.textPrimary,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: colors.canvas),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.md),
        ),
        elevation: 0,
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? colors.onAccent
                : colors.surface),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? colors.accent
                : colors.surfaceSunken),
        trackOutlineColor:
            WidgetStateProperty.resolveWith((_) => colors.borderStrong),
      ),

      sliderTheme: SliderThemeData(
        activeTrackColor: colors.accent,
        inactiveTrackColor: colors.surfaceSunken,
        thumbColor: colors.accent,
        overlayColor: colors.accentMuted,
        trackHeight: 4,
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colors.accent,
        linearTrackColor: colors.surfaceSunken,
        circularTrackColor: colors.surfaceSunken,
      ),

      listTileTheme: ListTileThemeData(
        iconColor: colors.textSecondary,
        textColor: colors.textPrimary,
        contentPadding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
        minVerticalPadding: Spacing.md,
        shape: const RoundedRectangleBorder(borderRadius: Radii.field),
      ),

      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: colors.textPrimary,
          borderRadius: BorderRadius.circular(Radii.sm),
        ),
        textStyle: textTheme.bodySmall?.copyWith(color: colors.canvas),
      ),

      // Android gets the predictive-back transition so the system back
      // gesture previews the destination; iOS keeps its native slide.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),

      extensions: <ThemeExtension<dynamic>>[colors],
    );
  }

  /// The one shadow used across the app.
  ///
  /// Applied only to the quick-log action and modal surfaces, so shadow keeps
  /// meaning "this floats above the page" instead of being decoration.
  static List<BoxShadow> floatShadow(PrayanTheme theme) => [
        BoxShadow(
          color: theme.brightness == Brightness.dark
              ? const Color(0x66000000)
              : const Color(0x14101828),
          blurRadius: 24,
          offset: const Offset(0, 8),
          spreadRadius: -4,
        ),
      ];
}

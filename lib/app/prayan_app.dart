import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/palette.dart';
import '../design/theme.dart';
import '../state/providers.dart';
import 'router.dart';

/// The application root.
class PrayanApp extends ConsumerWidget {
  const PrayanApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(preferencesProvider);
    final router = ref.watch(routerProvider);

    final platformBrightness = MediaQuery.platformBrightnessOf(context);
    final theme = _resolveTheme(
      preferences.theme,
      preferences.followSystemBrightness,
      platformBrightness,
    );

    return MaterialApp.router(
      title: 'Prayan Trading Journal',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: PrayanThemeBuilder.build(theme),
      // A single theme is supplied for both slots: brightness is resolved
      // above so the user's explicit choice always wins over the OS.
      darkTheme: PrayanThemeBuilder.build(theme),
      themeMode: theme.brightness == Brightness.dark
          ? ThemeMode.dark
          : ThemeMode.light,
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            // The user's in-app scale multiplies the OS setting rather than
            // replacing it, so accessibility settings are never overridden.
            textScaler: media.textScaler.clamp(
              minScaleFactor: 0.85,
              maxScaleFactor: 1.6 * preferences.textScale,
            ),
            disableAnimations:
                media.disableAnimations || preferences.reduceMotion,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }

  /// Picks the theme actually rendered.
  ///
  /// When "follow system" is on, a light theme swaps to its dark counterpart
  /// and vice versa, so a user who chose Parchment gets Graphite at night
  /// rather than being thrown back to the default dark.
  static PrayanTheme _resolveTheme(
    PrayanTheme chosen,
    bool followSystem,
    Brightness platform,
  ) {
    if (!followSystem) return chosen;
    final wantsDark = platform == Brightness.dark;
    if (chosen.brightness == Brightness.dark && wantsDark) return chosen;
    if (chosen.brightness == Brightness.light && !wantsDark) return chosen;

    return switch (chosen) {
      PrayanTheme.daylight => PrayanTheme.midnight,
      PrayanTheme.midnight => PrayanTheme.daylight,
      PrayanTheme.parchment => PrayanTheme.graphite,
      PrayanTheme.graphite => PrayanTheme.parchment,
    };
  }
}

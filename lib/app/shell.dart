import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../design/palette.dart';
import '../design/theme.dart';
import '../design/tokens.dart';
import 'router.dart';

/// The persistent frame around the five primary destinations.
///
/// Five is the ceiling the brief implies ("no more than the necessary primary
/// destinations", §24). Quick Log Trade is a floating action rather than a
/// sixth tab, because it is the one thing that must be reachable in one thumb
/// movement from anywhere.
class AppShell extends StatelessWidget {
  final GoRouterState state;
  final Widget child;

  const AppShell({super.key, required this.state, required this.child});

  static const _destinations = <_Destination>[
    _Destination(Routes.dashboard, Icons.dashboard_outlined,
        Icons.dashboard_rounded, 'Home'),
    _Destination(Routes.journal, Icons.receipt_long_outlined,
        Icons.receipt_long_rounded, 'Journal'),
    _Destination(Routes.calendar, Icons.calendar_month_outlined,
        Icons.calendar_month_rounded, 'Calendar'),
    _Destination(Routes.analytics, Icons.query_stats_outlined,
        Icons.query_stats_rounded, 'Analytics'),
    _Destination(Routes.profile, Icons.person_outline_rounded,
        Icons.person_rounded, 'Profile'),
  ];

  int get _currentIndex {
    final location = state.matchedLocation;
    final index = _destinations.indexWhere((d) => d.path == location);
    return index < 0 ? 0 : index;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      body: child,
      floatingActionButton: _QuickLogButton(
        onPressed: () => context.push(Routes.logTrade),
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: colors.border)),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) {
            HapticFeedback.selectionClick();
            context.go(_destinations[index].path);
          },
          destinations: [
            for (final destination in _destinations)
              NavigationDestination(
                icon: Icon(destination.icon),
                selectedIcon: Icon(destination.selectedIcon),
                label: destination.label,
                tooltip: destination.label,
              ),
          ],
        ),
      ),
    );
  }
}

class _Destination {
  final String path;
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const _Destination(this.path, this.icon, this.selectedIcon, this.label);
}

/// The one floating action in the app.
///
/// Carries the app's only shadow, which is how it reads as "above" the page
/// without a gradient or a glow.
class _QuickLogButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _QuickLogButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context).brightness == Brightness.dark
        ? PrayanTheme.midnight
        : PrayanTheme.daylight;

    return Semantics(
      button: true,
      label: 'Log a trade',
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Radii.lg),
          boxShadow: PrayanThemeBuilder.floatShadow(theme),
        ),
        child: FloatingActionButton.extended(
          onPressed: () {
            HapticFeedback.mediumImpact();
            onPressed();
          },
          backgroundColor: colors.accent,
          foregroundColor: colors.onAccent,
          elevation: 0,
          highlightElevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.lg),
          ),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Log trade'),
        ),
      ),
    );
  }
}

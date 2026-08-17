import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/analytics/analytics_screen.dart';
import '../features/auth/sign_in_screen.dart';
import '../features/calendar/calendar_screen.dart';
import '../features/calendar/daily_review_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/discipline/discipline_detail_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/psychology/psychology_screen.dart';
import '../features/reviews/period_review_screen.dart';
import '../features/rules/rule_builder_screen.dart';
import '../features/rules/rules_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/splash/splash_screen.dart';
import '../features/trade/trade_detail_screen.dart';
import '../features/trade/trade_history_screen.dart';
import '../features/trade/trade_log_screen.dart';
import '../state/providers.dart';
import 'shell.dart';

/// Route paths, referenced by name everywhere so a rename is one edit.
class Routes {
  const Routes._();

  static const splash = '/splash';
  static const onboarding = '/onboarding';
  static const signIn = '/sign-in';

  static const dashboard = '/';
  static const journal = '/journal';
  static const calendar = '/calendar';
  static const analytics = '/analytics';
  static const profile = '/profile';

  static const logTrade = '/trade/new';
  static String tradeDetail(String id) => '/trade/$id';
  static String editTrade(String id) => '/trade/$id/edit';

  static const rules = '/rules';
  static const newRule = '/rules/new';
  static String editRule(String id) => '/rules/$id';

  static const discipline = '/discipline';
  static String dailyReview(String dayKey) => '/day/$dayKey';
  static const weeklyReview = '/reviews/weekly';
  static const monthlyReview = '/reviews/monthly';
  static const psychology = '/psychology';
  static const settings = '/settings';
}

final routerProvider = Provider<GoRouter>((ref) {
  // Redirects re-run whenever auth or the profile changes, so completing
  // onboarding moves the user forward without any imperative navigation.
  final refreshListenable = _ProviderRefresh(ref);

  return GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: refreshListenable,
    redirect: (context, state) {
      final auth = ref.read(authStateProvider);
      final path = state.matchedLocation;

      // Hold on the splash while the first auth event is still in flight.
      if (auth.isLoading) {
        return path == Routes.splash ? null : Routes.splash;
      }

      final user = auth.value;
      final isAuthRoute = path == Routes.signIn || path == Routes.onboarding;

      if (user == null) {
        return isAuthRoute ? null : Routes.signIn;
      }

      final profile = ref.read(profileProvider).value;
      // A signed-in user with no completed profile always lands in onboarding.
      if (profile == null || !profile.onboardingComplete) {
        return path == Routes.onboarding ? null : Routes.onboarding;
      }

      // A completed user has no reason to sit on splash or sign-in.
      if (path == Routes.splash ||
          path == Routes.signIn ||
          path == Routes.onboarding) {
        return Routes.dashboard;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: Routes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: Routes.signIn,
        builder: (context, state) => const SignInScreen(),
      ),
      GoRoute(
        path: Routes.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),

      // The five primary destinations live inside a persistent shell so the
      // navigation bar never rebuilds and tab state survives switching.
      ShellRoute(
        builder: (context, state, child) =>
            AppShell(state: state, child: child),
        routes: [
          GoRoute(
            path: Routes.dashboard,
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: Routes.journal,
            builder: (context, state) => const TradeHistoryScreen(),
          ),
          GoRoute(
            path: Routes.calendar,
            builder: (context, state) => const CalendarScreen(),
          ),
          GoRoute(
            path: Routes.analytics,
            builder: (context, state) => const AnalyticsScreen(),
          ),
          GoRoute(
            path: Routes.profile,
            builder: (context, state) => const SettingsScreen(),
          ),
        ],
      ),

      GoRoute(
        path: Routes.logTrade,
        builder: (context, state) => const TradeLogScreen(),
      ),
      GoRoute(
        path: '/trade/:id',
        builder: (context, state) =>
            TradeDetailScreen(tradeId: state.pathParameters['id']!),
        routes: [
          GoRoute(
            path: 'edit',
            builder: (context, state) =>
                TradeLogScreen(editTradeId: state.pathParameters['id']),
          ),
        ],
      ),
      GoRoute(
        path: Routes.rules,
        builder: (context, state) => const RulesScreen(),
      ),
      GoRoute(
        path: Routes.newRule,
        builder: (context, state) => const RuleBuilderScreen(),
      ),
      GoRoute(
        path: '/rules/:id',
        builder: (context, state) =>
            RuleBuilderScreen(ruleId: state.pathParameters['id']),
      ),
      GoRoute(
        path: Routes.discipline,
        builder: (context, state) => const DisciplineDetailScreen(),
      ),
      GoRoute(
        path: '/day/:dayKey',
        builder: (context, state) =>
            DailyReviewScreen(dayKey: state.pathParameters['dayKey']!),
      ),
      GoRoute(
        path: Routes.weeklyReview,
        builder: (context, state) =>
            const PeriodReviewScreen(period: ReviewPeriod.weekly),
      ),
      GoRoute(
        path: Routes.monthlyReview,
        builder: (context, state) =>
            const PeriodReviewScreen(period: ReviewPeriod.monthly),
      ),
      GoRoute(
        path: Routes.psychology,
        builder: (context, state) => const PsychologyScreen(),
      ),
      GoRoute(
        path: Routes.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
    errorBuilder: (context, state) => _RouteNotFound(location: state.uri.path),
  );
});

/// Bridges Riverpod changes to GoRouter's [Listenable]-based refresh.
class _ProviderRefresh extends ChangeNotifier {
  _ProviderRefresh(Ref ref) {
    ref.listen(authStateProvider, (_, __) => notifyListeners());
    ref.listen(profileProvider, (_, __) => notifyListeners());
  }
}

class _RouteNotFound extends StatelessWidget {
  final String location;
  const _RouteNotFound({required this.location});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Not found')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('That screen does not exist.'),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => context.go(Routes.dashboard),
                  child: const Text('Back to the dashboard'),
                ),
              ],
            ),
          ),
        ),
      );
}

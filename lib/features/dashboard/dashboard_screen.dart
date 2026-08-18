import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:prayan_core/prayan_core.dart';

import '../../app/router.dart';
import '../../design/components/coaching_card.dart';
import '../../design/components/feedback.dart';
import '../../design/components/metric_card.dart';
import '../../design/components/score_ring.dart';
import '../../design/components/surfaces.dart';
import '../../design/components/trade_row.dart';
import '../../design/format.dart';
import '../../design/palette.dart';
import '../../design/tokens.dart';
import '../../domain/day_snapshot.dart';
import '../../state/providers.dart';

/// The home dashboard (§6).
///
/// Ordered to answer the brief's six questions in the order a trader asks
/// them: how disciplined was I, am I inside my limits, what is my streak, how
/// did I do, what behaviour is helping, what should I review. Process metrics
/// come before money metrics on the page, deliberately.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final dayKey = ref.watch(todayKeyProvider);
    final snapshotAsync = ref.watch(daySnapshotProvider(dayKey));
    final profile = ref.watch(profileProvider).value;
    final pending = ref.watch(pendingWritesProvider).value ?? 0;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(daySnapshotProvider(dayKey)),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Spacing.page,
                    Spacing.lg,
                    Spacing.page,
                    Spacing.md,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _greeting(profile?.displayName),
                              style: text.headlineLarge,
                            ),
                            const SizedBox(height: Spacing.xxs),
                            Text(
                              Fmt.dayKey(dayKey, long: true),
                              style: text.bodySmall
                                  ?.copyWith(color: colors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => context.push(Routes.settings),
                        icon: const Icon(Icons.tune_rounded),
                        tooltip: 'Settings',
                      ),
                    ],
                  ),
                ),
              ),
              if (pending > 0)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Spacing.page,
                      vertical: Spacing.sm,
                    ),
                    child: SyncBanner(pendingCount: pending, isOffline: false),
                  ),
                ),
              switch (snapshotAsync) {
                AsyncData(:final value) => _DashboardBody(snapshot: value),
                AsyncError(:final error) => SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(Spacing.page),
                      child: ErrorState(
                        title: 'Could not load today',
                        message: error is Exception
                            ? 'Your journal could not be read just now. It is '
                                'safe — try again in a moment.'
                            : '$error',
                        onRetry: () =>
                            ref.invalidate(daySnapshotProvider(dayKey)),
                      ),
                    ),
                  ),
                _ => const _DashboardSkeleton(),
              },
              const SliverToBoxAdapter(
                child: SizedBox(height: Spacing.scrollBottom),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _greeting(String? name) {
    final hour = DateTime.now().hour;
    final greeting = switch (hour) {
      < 12 => 'Good morning',
      < 17 => 'Good afternoon',
      _ => 'Good evening',
    };
    return name == null || name.isEmpty ? greeting : '$greeting, $name';
  }
}

class _DashboardBody extends ConsumerWidget {
  final DaySnapshot snapshot;
  const _DashboardBody({required this.snapshot});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final currency = snapshot.currency;
    final headline = snapshot.insights.isEmpty ? null : snapshot.insights.first;

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.page),
      sliver: SliverList.list(
        children: [
          // 1. How disciplined was I today?
          PrayanCard(
            onTap: () => context.push(Routes.discipline),
            child: Row(
              children: [
                ScoreRing(
                  score: snapshot.score.hasScore ? snapshot.score.value : null,
                  caption: 'Today',
                  wasCapped: snapshot.score.wasCappedByMajorViolation,
                ),
                const SizedBox(width: Spacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Discipline',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: Spacing.xs),
                      Text(
                        snapshot.score.summary,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: colors.textSecondary),
                      ),
                      const SizedBox(height: Spacing.md),
                      Row(
                        children: [
                          Icon(Icons.local_fire_department_outlined,
                              size: Sizes.iconSm, color: colors.accent),
                          const SizedBox(width: Spacing.xs),
                          Text(
                            '${snapshot.history.currentCleanStreak}-day clean '
                            'streak',
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Spacing.md),

          // 2. Am I inside my limits?
          _LimitsSection(snapshot: snapshot),

          const SizedBox(height: Spacing.section),

          // 3. What should I review before my next trade?
          if (headline != null) ...[
            const SectionHeader(title: 'Worth noticing'),
            CoachingStrip(
              insight: headline,
              onTap: () => context.push(Routes.dailyReview(snapshot.dayKey)),
            ),
            const SizedBox(height: Spacing.section),
          ],

          // 4. How did I perform today?
          SectionHeader(
            title: 'Today',
            action: TextButton(
              onPressed: () =>
                  context.push(Routes.dailyReview(snapshot.dayKey)),
              child: const Text('Daily review'),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: MetricCard(
                  label: 'Net P&L',
                  value: Fmt.money(snapshot.netPnl, currency,
                      showSign: true, compact: true),
                  valueColor: snapshot.hasTrades
                      ? colors.forSign(snapshot.netPnl.signum)
                      : null,
                  support: snapshot.hasTrades
                      ? Fmt.count(snapshot.tradeCount, 'trade')
                      : 'No trades yet',
                ),
              ),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: MetricCard(
                  label: 'R multiple',
                  value: snapshot.performance.rSampleCount == 0
                      ? Fmt.emptyValue
                      : Fmt.r(snapshot.totalR),
                  valueColor: snapshot.performance.rSampleCount == 0
                      ? null
                      : colors.forSign(snapshot.totalR.signum),
                  support: snapshot.performance.rSampleCount == 0
                      ? 'Needs a stop to measure'
                      : 'Across the day',
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.md),
          PrayanCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'RESULT SPLIT',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colors.textTertiary,
                      ),
                ),
                const SizedBox(height: Spacing.md),
                OutcomeSplitBar(
                  wins: snapshot.performance.winCount,
                  losses: snapshot.performance.lossCount,
                  breakevens: snapshot.performance.breakevenCount,
                ),
              ],
            ),
          ),

          const SizedBox(height: Spacing.section),

          // 5. What did I actually do?
          SectionHeader(
            title: 'Today\'s trades',
            action: TextButton(
              onPressed: () => context.go(Routes.journal),
              child: const Text('All trades'),
            ),
          ),
          if (snapshot.trades.isEmpty)
            _NothingToday(dayKey: snapshot.dayKey)
          else
            PrayanCard(
              padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
              child: Column(
                children: [
                  for (final trade in snapshot.trades)
                    TradeRow(
                      trade: trade,
                      metrics: snapshot.metricsFor(trade.id) ??
                          TradeCalculator.compute(trade),
                      currency: currency,
                      violationCount: snapshot.violationCountFor(trade.id),
                      hasMajorViolation:
                          snapshot.hasMajorViolationFor(trade.id),
                      onTap: () => context.push(Routes.tradeDetail(trade.id)),
                    ),
                ],
              ),
            ),

          const SizedBox(height: Spacing.lg),
          const DisclaimerNote(),
        ],
      ),
    );
  }
}

/// The dashboard when today is empty.
///
/// "Nothing logged today" on its own is a dead end, and it is the first screen
/// a new user reaches: onboarding dates the worked example to the last
/// *finished* session, so anyone who sets the app up before the bell — or over
/// a weekend — asks for an example and is shown a blank page. The same dead end
/// catches a real user on any quiet morning.
///
/// So when there is nothing today but something recent, the card says when the
/// last session was and opens it. The score is deliberately not shown here:
/// this screen is today's score, and a second number beside it would read as
/// today's.
class _NothingToday extends ConsumerWidget {
  final String dayKey;
  const _NothingToday({required this.dayKey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lastActive = ref.watch(lastActiveDayBeforeProvider(dayKey));

    if (lastActive == null) {
      return PrayanCard(
        padding: EdgeInsets.zero,
        child: EmptyState(
          compact: true,
          icon: Icons.event_available_outlined,
          title: 'Nothing logged today',
          message: 'A day with no valid setup is a good day. If you did '
              'trade, log it while the reasoning is fresh.',
          actionLabel: 'Log a trade',
          onAction: () => context.push(Routes.logTrade),
        ),
      );
    }

    final date = TradingDay.parseKey(lastActive);
    return PrayanCard(
      padding: EdgeInsets.zero,
      child: EmptyState(
        compact: true,
        icon: Icons.history_toggle_off_outlined,
        title: 'Nothing logged today',
        message: 'A day with no valid setup is a good day. Your last session '
            'was ${Fmt.dayKey(lastActive, long: true)}.',
        actionLabel:
            'Open ${date == null ? lastActive : Fmt.dayShort(date)}',
        onAction: () => context.push(Routes.dailyReview(lastActive)),
      ),
    );
  }
}

/// Risk used vs limit, and trades taken vs allowed (§6).
class _LimitsSection extends ConsumerWidget {
  final DaySnapshot snapshot;
  const _LimitsSection({required this.snapshot});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rules = ref.watch(rulesProvider).value ?? const [];
    final currency = snapshot.currency;

    // Read the live thresholds straight off the rules, so the meters and the
    // score can never disagree about what the limit is.
    Dec? thresholdFor(RuleMeasure measure) {
      for (final rule in rules) {
        if (rule.isActive && rule.current.measure == measure) {
          return rule.current.threshold;
        }
      }
      return null;
    }

    final maxTrades = thresholdFor(RuleMeasure.maxTradesPerDay);
    final maxDailyLossR = thresholdFor(RuleMeasure.maxDailyLossR);

    final lossR = snapshot.totalR.isNegative ? snapshot.totalR.abs : Dec.zero;

    return Column(
      children: [
        if (maxDailyLossR != null && !maxDailyLossR.isZero)
          Padding(
            padding: const EdgeInsets.only(bottom: Spacing.md),
            child: LimitMeter(
              label: 'Daily loss limit',
              icon: Icons.shield_outlined,
              fraction: lossR.divide(maxDailyLossR, scale: 4).toDouble(),
              usedLabel: '${lossR.roundTo(2).normalized}R',
              limitLabel: '${maxDailyLossR.normalized}R',
            ),
          ),
        if (maxTrades != null && !maxTrades.isZero)
          LimitMeter(
            label: 'Trades today',
            icon: Icons.numbers_rounded,
            fraction: Dec.fromInt(snapshot.tradeCount)
                .divide(maxTrades, scale: 4)
                .toDouble(),
            usedLabel: '${snapshot.tradeCount}',
            limitLabel: maxTrades.normalized.toString(),
          ),
        if (snapshot.reachedDailyStop) ...[
          const SizedBox(height: Spacing.md),
          PrayanCard(
            borderColor: snapshot.tradedAfterDailyStop
                ? context.colors.violation
                : context.colors.accent,
            child: Row(
              children: [
                Icon(
                  snapshot.tradedAfterDailyStop
                      ? Icons.error_outline_rounded
                      : Icons.check_circle_outline_rounded,
                  color: snapshot.tradedAfterDailyStop
                      ? context.colors.violation
                      : context.colors.accent,
                ),
                const SizedBox(width: Spacing.md),
                Expanded(
                  child: Text(
                    snapshot.tradedAfterDailyStop
                        ? 'You kept trading after reaching your daily stop.'
                        : 'You reached your daily stop. Your plan says today '
                            'is finished.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        ],
        // Money-denominated risk is shown only when an equity figure exists;
        // otherwise the meter would be measuring against nothing.
        if (snapshot.account.riskBaseEquity.isZero)
          Padding(
            padding: const EdgeInsets.only(top: Spacing.md),
            child: PrayanCard(
              onTap: () => context.push(Routes.settings),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: Sizes.iconMd, color: context.colors.textSecondary),
                  const SizedBox(width: Spacing.md),
                  Expanded(
                    child: Text(
                      'Add your account equity to measure risk as a '
                      'percentage.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  Text(
                    currency.code,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) => SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: Spacing.page),
        sliver: SliverList.list(
          children: const [
            Skeleton(height: 148, borderRadius: Radii.card),
            SizedBox(height: Spacing.md),
            Skeleton(height: 104, borderRadius: Radii.card),
            SizedBox(height: Spacing.md),
            Skeleton(height: 104, borderRadius: Radii.card),
            SizedBox(height: Spacing.section),
            Skeleton(width: 140, height: 22),
            SizedBox(height: Spacing.md),
            Skeleton(height: 120, borderRadius: Radii.card),
          ],
        ),
      );
}

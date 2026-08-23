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
                            // The date leads and the greeting supports it.
                            // A greeting set larger than everything under it
                            // makes "Good evening" the most important thing on
                            // a screen about today's trading, and costs the
                            // score a hundred pixels of the fold.
                            Text(
                              Fmt.dayKey(dayKey, long: true),
                              style: text.titleLarge,
                            ),
                            const SizedBox(height: Spacing.xxs),
                            Text(
                              _greeting(profile?.displayName),
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
          Entrance(child: _DisciplineHero(snapshot: snapshot)),
          const SizedBox(height: Spacing.md),

          // 2. Am I inside my limits?
          Entrance(index: 1, child: _LimitsSection(snapshot: snapshot)),

          const SizedBox(height: Spacing.section),

          // 3. What should I review before my next trade?
          if (headline != null) ...[
            const SectionHeader(title: 'Worth noticing'),
            Entrance(
              index: 2,
              child: CoachingStrip(
                insight: headline,
                onTap: () => context.push(Routes.dailyReview(snapshot.dayKey)),
              ),
            ),
            const SizedBox(height: Spacing.section),
          ],

          // 4. How did I perform today?
          //
          // Only once there is a "how". On an empty day this block was three
          // more ways of saying nothing has happened — ₹0.00, an em dash and
          // "No closed trades yet" — stacked under a card that had already
          // said it. The day's guardrails and one clear next step is the whole
          // of what an empty morning needs.
          if (snapshot.trades.isNotEmpty) ...[
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
                    // Two different absences, and telling someone they need
                    // a stop when they typed one is how a hint becomes noise
                    // they stop reading. R is unmeasurable while a trade is
                    // open no matter how carefully it was planned.
                    support: snapshot.performance.tradeCount == 0
                        ? 'Nothing closed yet'
                        : snapshot.performance.rSampleCount == 0
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
          ],

          // 5. What did I actually do?
          SectionHeader(
            title: snapshot.trades.isEmpty ? 'Today' : 'Today\'s trades',
            action: TextButton(
              onPressed: () => snapshot.trades.isEmpty
                  ? context.push(Routes.dailyReview(snapshot.dayKey))
                  : context.go(Routes.journal),
              child:
                  Text(snapshot.trades.isEmpty ? 'Daily review' : 'All trades'),
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

/// The one card on this screen that leads.
///
/// It used to show a green 100 on a day with no trades — a perfect score for
/// having done nothing, presented as the first thing anyone sees. Every part
/// of that is wrong: the number is arithmetic on an empty set, the ring reads
/// as an achievement, and a streak counter sitting at "0-day" beside it turns
/// the first morning into a scoreboard the user is already losing on.
///
/// So it says what is true. With nothing logged, the day is *open*, and what
/// matters is the plan, not a score. Once there is something to measure, the
/// score is the hero and gets the lift.
class _DisciplineHero extends StatelessWidget {
  final DaySnapshot snapshot;
  const _DisciplineHero({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final streak = snapshot.history.currentCleanStreak;

    // Not `!score.hasScore`: with no trades the day-scoped rules all pass, so
    // the engine happily reports 100 — a perfect score for an empty day. What
    // makes the score meaningful is that something was measured.
    if (snapshot.trades.isEmpty) {
      return PrayanCard(
        lift: CardLift.lifted,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(colors.accentDeep, colors.accent, 0.35)!,
            colors.accentDeep,
          ],
        ),
        child: Row(
          children: [
            Container(
              width: Sizes.scoreRingCompact,
              height: Sizes.scoreRingCompact,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.22),
                ),
              ),
              child: Icon(Icons.play_arrow_rounded,
                  size: 34, color: colors.accentBright),
            ),
            const SizedBox(width: Spacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Today is open',
                    style: text.titleMedium?.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: Spacing.xs),
                  Text(
                    'Nothing logged yet. Your score appears once there is a '
                    'trade to measure it against.',
                    style: text.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.78),
                      height: 1.45,
                    ),
                  ),
                  if (streak > 0) ...[
                    const SizedBox(height: Spacing.md),
                    _Streak(days: streak, onDark: true),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    }

    // The one panel in the product that is allowed to look like a poster.
    // Everything else on the screen is a flat card on a light ground; this is
    // the number the app exists to produce, so it gets the depth, the light
    // and the only gradient on the page.
    return PrayanCard(
      lift: CardLift.lifted,
      onTap: () => context.push(Routes.discipline),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color.lerp(colors.accentDeep, colors.accent, 0.35)!,
          colors.accentDeep,
        ],
      ),
      child: Row(
        children: [
          ScoreRing(
            score: snapshot.score.hasScore ? snapshot.score.value : null,
            caption: 'Today',
            wasCapped: snapshot.score.wasCappedByMajorViolation,
            onDark: true,
          ),
          const SizedBox(width: Spacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Discipline',
                  style: text.titleMedium?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: Spacing.xs),
                Text(
                  snapshot.score.summary,
                  style: text.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.78),
                    height: 1.45,
                  ),
                ),
                // A streak is worth showing when it is one. "0-day clean
                // streak" is not an encouragement, it is a zero with a label.
                if (streak > 0) ...[
                  const SizedBox(height: Spacing.md),
                  _Streak(days: streak, onDark: true),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Streak extends StatelessWidget {
  final int days;
  final bool onDark;
  const _Streak({required this.days, this.onDark = false});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tint = onDark ? colors.accentBright : colors.accent;
    return Row(
      children: [
        Icon(Icons.local_fire_department_rounded,
            size: Sizes.iconSm, color: tint),
        const SizedBox(width: Spacing.xs),
        Text(
          '$days-day clean streak',
          style: Theme.of(context)
              .textTheme
              .labelMedium
              ?.copyWith(color: onDark ? Colors.white : null),
        ),
      ],
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
      return const PrayanCard(
        padding: EdgeInsets.zero,
        child: EmptyState(
          compact: true,
          icon: Icons.event_available_outlined,
          title: 'Nothing logged today',
          message: 'A day with no valid setup is a good day. If you did '
              'trade, log it while the reasoning is fresh.',
          // No button. "Log trade" is already the floating action on every
          // screen, and the two rendered on top of each other — two identical
          // green buttons, one obscuring the other. A screen gets one primary
          // action, and this one already had it.
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
        actionLabel: 'Open ${date == null ? lastActive : Fmt.dayShort(date)}',
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

    // The day's two guardrails belong beside each other: they are read
    // together, they are one glance, and stacking them full-width pushed
    // everything that matters below the fold.
    final meters = <LimitMeter>[
      if (maxDailyLossR != null && !maxDailyLossR.isZero)
        LimitMeter(
          label: 'Loss limit',
          semanticLabel: 'Daily loss limit',
          icon: Icons.shield_outlined,
          dense: true,
          fraction: lossR.divide(maxDailyLossR, scale: 4).toDouble(),
          usedLabel: '${lossR.roundTo(2).normalized}R',
          limitLabel: '${maxDailyLossR.normalized}R',
        ),
      if (maxTrades != null && !maxTrades.isZero)
        LimitMeter(
          label: 'Trades',
          semanticLabel: 'Trades today',
          icon: Icons.numbers_rounded,
          dense: true,
          fraction: Dec.fromInt(snapshot.tradeCount)
              .divide(maxTrades, scale: 4)
              .toDouble(),
          usedLabel: '${snapshot.tradeCount}',
          limitLabel: maxTrades.normalized.toString(),
        ),
    ];

    return Column(
      children: [
        LimitMeterPair(meters: meters),
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

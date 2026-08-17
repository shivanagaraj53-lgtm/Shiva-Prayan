import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prayan_core/prayan_core.dart';

import '../../design/components/coaching_card.dart';
import '../../design/components/feedback.dart';
import '../../design/components/metric_card.dart';
import '../../design/components/score_ring.dart';
import '../../design/components/surfaces.dart';
import '../../design/format.dart';
import '../../design/palette.dart';
import '../../design/tokens.dart';
import '../../design/typography.dart';
import '../../state/providers.dart';

enum ReviewPeriod {
  weekly('This week', 7),
  monthly('This month', 30);

  const ReviewPeriod(this.label, this.days);
  final String label;
  final int days;
}

/// The weekly and monthly guided reviews (§14).
///
/// Structured around process first: discipline trend, weakest rule, repeated
/// mistake — and only then the money. That ordering is the whole point of the
/// screen.
class PeriodReviewScreen extends ConsumerWidget {
  final ReviewPeriod period;
  const PeriodReviewScreen({super.key, required this.period});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;

    final today = ref.watch(todayKeyProvider);
    final from = _shift(today, -period.days);
    final range = DayRange(from, today);

    final trades = ref.watch(tradesInRangeProvider(range)).value ?? const [];
    final history =
        ref.watch(disciplineHistoryProvider(range)).value ?? const [];
    final account = ref.watch(activeAccountProvider);
    final strategies = ref.watch(strategiesProvider).value ?? const [];
    final preferences = ref.watch(preferencesProvider);

    final currency = account?.currency ?? Currency.usd;
    final metrics = PerformanceCalculator.compute(trades);
    final discipline = StreakCalculator.compute(
      history,
      countNoTradeDaysInStreak: preferences.countNoTradeDaysInStreak,
    );

    final byStrategy = PerformanceCalculator.groupBy<String>(
      trades,
      (trade) =>
          strategies
              .where((s) => s.id == trade.strategyId)
              .map((s) => s.name)
              .firstOrNull ??
          'No setup recorded',
    );
    final byMistake = PerformanceCalculator.groupBy<MistakeCategory>(
      trades.where((t) => t.mistake != MistakeCategory.none),
      (trade) => trade.mistake,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
            period == ReviewPeriod.weekly ? 'Weekly review' : 'Monthly review'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          Spacing.page,
          Spacing.md,
          Spacing.page,
          Spacing.xxxl,
        ),
        children: [
          Text(
            '${Fmt.dayKey(from)} — ${Fmt.dayKey(today)}',
            style: text.bodySmall?.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: Spacing.lg),

          // --- Process first ------------------------------------------
          PrayanCard(
            child: Row(
              children: [
                ScoreRing(
                  score: period == ReviewPeriod.weekly
                      ? discipline.rolling7DayScore
                      : discipline.rolling30DayScore,
                  size: Sizes.scoreRingCompact,
                  caption: 'Average',
                ),
                const SizedBox(width: Spacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Discipline trend', style: text.titleMedium),
                      const SizedBox(height: Spacing.xs),
                      Text(
                        '${discipline.scoredDays} scored days · '
                        '${discipline.currentCleanStreak}-day clean streak · '
                        '${discipline.majorViolationDays} days with a major '
                        'break.',
                        style: text.bodySmall
                            ?.copyWith(color: colors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: Spacing.section),
          const SectionHeader(title: 'Process'),
          if (discipline.weakestRule != null)
            Padding(
              padding: const EdgeInsets.only(bottom: Spacing.md),
              child: PrayanCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Weakest rule', style: text.titleSmall),
                    const SizedBox(height: Spacing.xs),
                    Text(
                      discipline.weakestRule!.ruleName,
                      style: text.bodyLarge,
                    ),
                    const SizedBox(height: Spacing.sm),
                    ScoreBar(
                      score: discipline.weakestRule!.compliancePercent,
                      height: 5,
                    ),
                    const SizedBox(height: Spacing.xs),
                    Text(
                      'Followed on '
                      '${discipline.weakestRule!.compliancePercent?.roundTo(0) ?? '—'}% '
                      'of the occasions it applied. Worth making it the one '
                      'thing you focus on.',
                      style:
                          text.bodySmall?.copyWith(color: colors.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
          if (discipline.strongestRule != null)
            PrayanCard(
              child: Row(
                children: [
                  Icon(Icons.verified_outlined, color: colors.compliant),
                  const SizedBox(width: Spacing.md),
                  Expanded(
                    child: Text(
                      'Your most reliable habit is '
                      '"${discipline.strongestRule!.ruleName}".',
                      style: text.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),

          if (byMistake.isNotEmpty) ...[
            const SizedBox(height: Spacing.md),
            PrayanCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Repeated mistakes', style: text.titleSmall),
                  const SizedBox(height: Spacing.sm),
                  for (final entry in (byMistake.entries.toList()
                    ..sort((a, b) =>
                        b.value.tradeCount.compareTo(a.value.tradeCount))))
                    Padding(
                      padding: const EdgeInsets.only(bottom: Spacing.xs),
                      child: Row(
                        children: [
                          Expanded(child: Text(entry.key.label)),
                          Text(
                            '${entry.value.tradeCount}x',
                            style: PrayanType.figure(colors.warning),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],

          // --- Then the money ------------------------------------------
          const SizedBox(height: Spacing.section),
          const SectionHeader(title: 'Result'),
          if (!metrics.hasData)
            const EmptyState(
              compact: true,
              icon: Icons.insights_outlined,
              title: 'No closed trades in this period',
              message: 'Nothing to summarise yet.',
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: MetricCard(
                    compact: true,
                    label: 'Net P&L',
                    value: Fmt.money(metrics.netPnl, currency,
                        showSign: true, compact: true),
                    valueColor: colors.forSign(metrics.netPnl.signum),
                  ),
                ),
                const SizedBox(width: Spacing.sm),
                Expanded(
                  child: MetricCard(
                    compact: true,
                    label: 'Total R',
                    value: Fmt.r(metrics.totalR),
                  ),
                ),
                const SizedBox(width: Spacing.sm),
                Expanded(
                  child: MetricCard(
                    compact: true,
                    label: 'Drawdown',
                    value: '${metrics.maxDrawdownR.roundTo(1)}R',
                  ),
                ),
              ],
            ),
            const SizedBox(height: Spacing.md),
            PrayanCard(
              child: OutcomeSplitBar(
                wins: metrics.winCount,
                losses: metrics.lossCount,
                breakevens: metrics.breakevenCount,
              ),
            ),
            const SizedBox(height: Spacing.md),
            PrayanCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('By setup', style: text.titleSmall),
                  const SizedBox(height: Spacing.sm),
                  for (final entry
                      in (byStrategy.entries
                          .where((e) => e.value.hasData)
                          .toList()
                        ..sort((a, b) =>
                            b.value.totalR.compareTo(a.value.totalR))))
                    Padding(
                      padding: const EdgeInsets.only(bottom: Spacing.sm),
                      child: Row(
                        children: [
                          Expanded(child: Text(entry.key)),
                          Text(
                            Fmt.r(entry.value.totalR),
                            style: PrayanType.figure(
                              colors.forSign(entry.value.netPnl.signum),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],

          const SizedBox(height: Spacing.section),
          const SectionHeader(
            title: 'One focus for next period',
            subtitle:
                'Pick a single rule. Changing one habit at a time is the only '
                'approach that reliably sticks.',
          ),
          const TextField(
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: 'Next week I will…',
            ),
          ),

          const SizedBox(height: Spacing.lg),
          const DisclaimerNote(),
        ],
      ),
    );
  }

  static String _shift(String dayKey, int days) {
    final date = TradingDay.parseKey(dayKey);
    if (date == null) return dayKey;
    return TradingDay.format(date.add(Duration(days: days)));
  }
}

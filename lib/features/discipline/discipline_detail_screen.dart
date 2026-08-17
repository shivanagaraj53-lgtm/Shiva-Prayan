import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:prayan_core/prayan_core.dart';

import '../../app/router.dart';
import '../../design/components/coaching_card.dart';
import '../../design/components/metric_card.dart';
import '../../design/components/rule_status_tile.dart';
import '../../design/components/score_ring.dart';
import '../../design/components/surfaces.dart';
import '../../design/format.dart';
import '../../design/palette.dart';
import '../../design/tokens.dart';
import '../../design/typography.dart';
import '../../domain/day_snapshot.dart';
import '../../state/providers.dart';

/// The Discipline Score explained, plus the Consistency Meter (§10).
///
/// Every number here traces back to a specific rule on a specific trade. The
/// brief is emphatic that the score must never be a black box, so the
/// component breakdown and the full evaluation list are both on this screen
/// rather than hidden behind a tap.
class DisciplineDetailScreen extends ConsumerWidget {
  const DisciplineDetailScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshotAsync = ref.watch(activeDaySnapshotProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Discipline')),
      body: switch (snapshotAsync) {
        AsyncData(:final value) => _Body(snapshot: value),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _Body extends ConsumerWidget {
  final DaySnapshot snapshot;
  const _Body({required this.snapshot});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final score = snapshot.score;
    final history = snapshot.history;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        Spacing.page,
        Spacing.md,
        Spacing.page,
        Spacing.xxxl,
      ),
      children: [
        Center(
          child: ScoreRing(
            score: score.hasScore ? score.value : null,
            caption: Fmt.dayKey(snapshot.dayKey),
            size: 160,
            wasCapped: score.wasCappedByMajorViolation,
          ),
        ),
        const SizedBox(height: Spacing.lg),
        Text(
          score.summary,
          textAlign: TextAlign.center,
          style: text.bodyMedium?.copyWith(color: colors.textSecondary),
        ),

        if (score.wasCappedByMajorViolation) ...[
          const SizedBox(height: Spacing.lg),
          PrayanCard(
            borderColor: colors.violation,
            child: Row(
              children: [
                Icon(Icons.error_outline_rounded, color: colors.violation),
                const SizedBox(width: Spacing.md),
                Expanded(
                  child: Text(
                    'A major rule was broken, so today is capped at '
                    '${score.rounded}. Without the cap it would have been '
                    '${score.uncappedValue.roundTo(0)}.',
                    style: text.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: Spacing.section),

        // --- The Consistency Meter (§10) ------------------------------
        const SectionHeader(
          title: 'Consistency',
          subtitle: 'How the process is trending, not the money.',
        ),
        Row(
          children: [
            Expanded(
              child: MetricCard(
                compact: true,
                label: '7 day',
                value: Fmt.score(history.rolling7DayScore),
              ),
            ),
            const SizedBox(width: Spacing.sm),
            Expanded(
              child: MetricCard(
                compact: true,
                label: '30 day',
                value: Fmt.score(history.rolling30DayScore),
              ),
            ),
            const SizedBox(width: Spacing.sm),
            Expanded(
              child: MetricCard(
                compact: true,
                label: '90 day',
                value: Fmt.score(history.rolling90DayScore),
              ),
            ),
          ],
        ),
        const SizedBox(height: Spacing.md),
        Row(
          children: [
            Expanded(
              child: MetricCard(
                compact: true,
                label: 'Clean streak',
                value: '${history.currentCleanStreak}',
                support: history.streakStartedOn == null
                    ? 'Starts with your next clean day'
                    : 'Since ${Fmt.dayKey(history.streakStartedOn!)}',
                icon: Icons.local_fire_department_outlined,
              ),
            ),
            const SizedBox(width: Spacing.sm),
            Expanded(
              child: MetricCard(
                compact: true,
                label: 'Best streak',
                value: '${history.bestCleanStreak}',
                support: 'Never reset',
                icon: Icons.emoji_events_outlined,
              ),
            ),
            const SizedBox(width: Spacing.sm),
            Expanded(
              child: MetricCard(
                compact: true,
                label: 'Major breaks',
                value: '${history.majorViolationDays}',
                support: 'Days, lifetime',
                icon: Icons.report_gmailerrorred_outlined,
              ),
            ),
          ],
        ),

        const SizedBox(height: Spacing.section),

        // --- Where the points came from -------------------------------
        if (score.components.isNotEmpty) ...[
          const SectionHeader(
            title: 'Where the points came from',
            subtitle: 'Only the categories that applied today are counted, and '
                'their weights are normalised across them.',
          ),
          PrayanCard(
            child: Column(
              children: [
                for (final component in score.components)
                  _ComponentRow(component: component),
              ],
            ),
          ),
          const SizedBox(height: Spacing.section),
        ],

        // --- The audit trail ------------------------------------------
        const SectionHeader(
          title: 'Every rule, today',
          subtitle: 'The full record behind the number.',
        ),
        PrayanCard(
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.md,
            vertical: Spacing.sm,
          ),
          child: Column(
            children: [
              for (final evaluation in snapshot.ruleReport.all
                  .where((e) => e.status != RuleStatus.notApplicable))
                RuleStatusTile(
                  evaluation: evaluation,
                  onTap: evaluation.tradeId == null
                      ? null
                      : () =>
                          context.push(Routes.tradeDetail(evaluation.tradeId!)),
                ),
              if (snapshot.ruleReport.all
                  .where((e) => e.status != RuleStatus.notApplicable)
                  .isEmpty)
                Padding(
                  padding: const EdgeInsets.all(Spacing.lg),
                  child: Text(
                    'No rule applied today. A day with no trades breaks '
                    'nothing.',
                    style:
                        text.bodySmall?.copyWith(color: colors.textSecondary),
                  ),
                ),
            ],
          ),
        ),

        if (score.unresolved.isNotEmpty) ...[
          const SizedBox(height: Spacing.section),
          const SectionHeader(
            title: 'Needs a little more data',
            subtitle:
                'These rules applied but could not be judged. They are left '
                'out of the score rather than counted as passed.',
          ),
          PrayanCard(
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.md,
              vertical: Spacing.sm,
            ),
            child: Column(
              children: [
                for (final evaluation in score.unresolved)
                  RuleStatusTile(evaluation: evaluation),
              ],
            ),
          ),
        ],

        if (history.ruleCompliance.isNotEmpty) ...[
          const SizedBox(height: Spacing.section),
          const SectionHeader(
            title: 'Rule compliance over time',
            subtitle: 'Weakest first — one habit at a time is usually enough.',
          ),
          PrayanCard(
            child: Column(
              children: [
                for (final stat in history.ruleCompliance.take(8))
                  Padding(
                    padding: const EdgeInsets.only(bottom: Spacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child:
                                  Text(stat.ruleName, style: text.bodyMedium),
                            ),
                            Text(
                              stat.compliancePercent == null
                                  ? Fmt.emptyValue
                                  : '${stat.compliancePercent!.roundTo(0)}%',
                              style: PrayanType.figure(colors.textSecondary),
                            ),
                          ],
                        ),
                        const SizedBox(height: Spacing.xs),
                        ScoreBar(score: stat.compliancePercent, height: 4),
                        const SizedBox(height: Spacing.xxs),
                        Text(
                          '${stat.passedCount} followed · '
                          '${stat.violatedCount} broken',
                          style: text.labelSmall
                              ?.copyWith(color: colors.textTertiary),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],

        const SizedBox(height: Spacing.lg),
        const DisclaimerNote(
          text: 'The discipline score measures adherence to rules you set. It '
              'is not a measure of skill, and it does not predict results.',
        ),
      ],
    );
  }
}

class _ComponentRow extends StatelessWidget {
  final ScoreComponent component;
  const _ComponentRow({required this.component});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(component.category.label, style: text.titleSmall),
              ),
              Text(
                '${component.contribution.normalized} pts',
                style: PrayanType.figure(
                  component.isFullyCompliant
                      ? colors.compliant
                      : colors.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.xs),
          ScoreBar(score: component.categoryScore, height: 5),
          const SizedBox(height: Spacing.xs),
          Text(
            '${component.passedCount} of ${component.applicableCount} '
            'followed · weighted '
            '${component.normalizedWeight.roundTo(0)}% of today',
            style: text.labelSmall?.copyWith(
              color: colors.textTertiary,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

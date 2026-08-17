import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:prayan_core/prayan_core.dart';

import '../../app/router.dart';
import '../../design/components/coaching_card.dart';
import '../../design/components/metric_card.dart';
import '../../design/components/score_ring.dart';
import '../../design/components/surfaces.dart';
import '../../design/components/trade_row.dart';
import '../../design/format.dart';
import '../../design/palette.dart';
import '../../design/tokens.dart';
import '../../domain/day_snapshot.dart';
import '../../domain/models.dart';
import '../../state/providers.dart';

/// The Daily Review (§11, §14).
///
/// Combines the day's numbers, its rule verdicts and the guided reflection
/// prompts. The "good loss vs bad loss" distinction is stated explicitly at
/// the top, because it is the single idea the product is trying to teach.
class DailyReviewScreen extends ConsumerStatefulWidget {
  final String dayKey;
  const DailyReviewScreen({super.key, required this.dayKey});

  @override
  ConsumerState<DailyReviewScreen> createState() => _DailyReviewScreenState();
}

class _DailyReviewScreenState extends ConsumerState<DailyReviewScreen> {
  DailyReview? _draft;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final snapshotAsync = ref.watch(daySnapshotProvider(widget.dayKey));
    final reviewAsync = ref.watch(dailyReviewProvider(widget.dayKey));

    return Scaffold(
      appBar: AppBar(title: Text(Fmt.dayKey(widget.dayKey))),
      body: switch (snapshotAsync) {
        AsyncData(:final value) => _Body(
            snapshot: value,
            review: _draft ?? reviewAsync.value,
            onReviewChanged: (review) => setState(() => _draft = review),
            onSave: _save,
            saving: _saving,
          ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  Future<void> _save() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    setState(() => _saving = true);
    try {
      final now = ref.read(nowProvider)();
      final base = _draft ??
          DailyReview(
            id: '${userId}_${widget.dayKey}',
            userId: userId,
            dayKey: widget.dayKey,
            updatedAtUtc: now,
          );
      await ref.read(reviewRepositoryProvider).saveDailyReview(
            base.copyWith(isComplete: true, updatedAtUtc: now),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Day closed. Well done.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _Body extends ConsumerWidget {
  final DaySnapshot snapshot;
  final DailyReview? review;
  final ValueChanged<DailyReview> onReviewChanged;
  final VoidCallback onSave;
  final bool saving;

  const _Body({
    required this.snapshot,
    required this.review,
    required this.onReviewChanged,
    required this.onSave,
    required this.saving,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final currency = snapshot.currency;
    final userId = ref.watch(currentUserIdProvider) ?? '';
    final strategies = ref.watch(strategiesProvider).value ?? const [];
    final strategyNames = {for (final s in strategies) s.id: s.name};

    final current = review ??
        DailyReview(
          id: '${userId}_${snapshot.dayKey}',
          userId: userId,
          dayKey: snapshot.dayKey,
          updatedAtUtc: DateTime.now().toUtc(),
        );

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        Spacing.page,
        Spacing.md,
        Spacing.page,
        Spacing.xxxl,
      ),
      children: [
        // The headline verdict for the day.
        PrayanCard(
          emphasised: snapshot.isDisciplinedLoss,
          child: Row(
            children: [
              ScoreRing(
                score: snapshot.score.hasScore ? snapshot.score.value : null,
                size: Sizes.scoreRingCompact,
                wasCapped: snapshot.score.wasCappedByMajorViolation,
              ),
              const SizedBox(width: Spacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_verdict(snapshot), style: text.titleMedium),
                    const SizedBox(height: Spacing.xs),
                    Text(
                      snapshot.score.summary,
                      style:
                          text.bodySmall?.copyWith(color: colors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: Spacing.section),
        const SectionHeader(title: 'The numbers'),
        Row(
          children: [
            Expanded(
              child: MetricCard(
                compact: true,
                label: 'Net P&L',
                value: Fmt.money(snapshot.netPnl, currency,
                    showSign: true, compact: true),
                valueColor: snapshot.hasTrades
                    ? colors.forSign(snapshot.netPnl.signum)
                    : null,
              ),
            ),
            const SizedBox(width: Spacing.sm),
            Expanded(
              child: MetricCard(
                compact: true,
                label: 'R result',
                value: snapshot.performance.rSampleCount == 0
                    ? Fmt.emptyValue
                    : Fmt.r(snapshot.totalR),
              ),
            ),
            const SizedBox(width: Spacing.sm),
            Expanded(
              child: MetricCard(
                compact: true,
                label: 'Win rate',
                value: Fmt.percent(snapshot.performance.winRate, decimals: 0),
              ),
            ),
          ],
        ),
        const SizedBox(height: Spacing.md),
        PrayanCard(
          child: OutcomeSplitBar(
            wins: snapshot.performance.winCount,
            losses: snapshot.performance.lossCount,
            breakevens: snapshot.performance.breakevenCount,
          ),
        ),

        if (snapshot.insights.isNotEmpty) ...[
          const SizedBox(height: Spacing.section),
          const SectionHeader(title: 'Coaching'),
          for (final insight in snapshot.insights.take(4))
            Padding(
              padding: const EdgeInsets.only(bottom: Spacing.md),
              child: CoachingCard(insight: insight),
            ),
        ],

        if (snapshot.trades.isNotEmpty) ...[
          const SizedBox(height: Spacing.section),
          const SectionHeader(title: 'Trades'),
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
                    strategyName: strategyNames[trade.strategyId],
                    violationCount: snapshot.violationCountFor(trade.id),
                    hasMajorViolation: snapshot.hasMajorViolationFor(trade.id),
                    onTap: () => context.push(Routes.tradeDetail(trade.id)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: Spacing.md),
          TextButton.icon(
            onPressed: () => context.push(Routes.discipline),
            icon: const Icon(Icons.rule_rounded),
            label: const Text('See every rule for this day'),
          ),
        ],

        const SizedBox(height: Spacing.section),
        SectionHeader(
          title: 'Close the day',
          subtitle: current.isComplete
              ? 'Completed. You can still edit your answers.'
              : 'Six questions. Two minutes.',
        ),
        _ReviewField(
          label: 'What went well?',
          value: current.whatWentWell,
          onChanged: (v) => onReviewChanged(current.copyWith(whatWentWell: v)),
        ),
        _ReviewField(
          label: 'Which rule did you break, if any?',
          value: current.ruleBroken,
          hint: snapshot.score.violations.isEmpty
              ? 'None broken today.'
              : snapshot.score.violations.map((v) => v.ruleName).join(', '),
          onChanged: (v) => onReviewChanged(current.copyWith(ruleBroken: v)),
        ),
        _ReviewField(
          label: 'Was your risk correct?',
          value: current.riskAssessment,
          onChanged: (v) =>
              onReviewChanged(current.copyWith(riskAssessment: v)),
        ),
        _ReviewField(
          label: 'Worst process decision',
          value: current.worstProcessDecision,
          onChanged: (v) =>
              onReviewChanged(current.copyWith(worstProcessDecision: v)),
        ),
        _ReviewField(
          label: 'One improvement for tomorrow',
          value: current.oneImprovement,
          onChanged: (v) =>
              onReviewChanged(current.copyWith(oneImprovement: v)),
        ),

        const SizedBox(height: Spacing.lg),
        Text('How do you feel now?', style: text.titleSmall),
        const SizedBox(height: Spacing.sm),
        Wrap(
          spacing: Spacing.sm,
          runSpacing: Spacing.sm,
          children: [
            for (final emotion in const [
              EmotionTag.calm,
              EmotionTag.focused,
              EmotionTag.neutral,
              EmotionTag.frustrated,
              EmotionTag.tired,
            ])
              ChoiceChip(
                label: Text(emotion.label),
                selected: current.closingEmotion == emotion,
                onSelected: (_) =>
                    onReviewChanged(current.copyWith(closingEmotion: emotion)),
              ),
          ],
        ),

        const SizedBox(height: Spacing.xl),
        FilledButton(
          onPressed: saving ? null : onSave,
          child: Text(current.isComplete ? 'Save changes' : 'Close the day'),
        ),
      ],
    );
  }

  /// The one-line verdict, stating the good-loss / bad-loss distinction.
  static String _verdict(DaySnapshot snapshot) {
    if (!snapshot.hasTrades) return 'No trades today';
    if (snapshot.isUndisciplinedWin) return 'Profitable, outside the plan';
    if (snapshot.isDisciplinedLoss) return 'A disciplined loss';
    if (snapshot.score.majorViolations.isNotEmpty) {
      return 'A major rule was broken';
    }
    if (snapshot.isProfitable) return 'A clean, profitable day';
    return 'A day inside the plan';
  }
}

class _ReviewField extends StatelessWidget {
  final String label;
  final String? value;
  final String? hint;
  final ValueChanged<String> onChanged;

  const _ReviewField({
    required this.label,
    required this.value,
    required this.onChanged,
    this.hint,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: Spacing.lg),
        child: TextFormField(
          initialValue: value,
          maxLines: 2,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(labelText: label, hintText: hint),
          onChanged: onChanged,
        ),
      );
}

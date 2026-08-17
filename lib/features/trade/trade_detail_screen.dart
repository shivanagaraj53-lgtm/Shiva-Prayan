import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:prayan_core/prayan_core.dart';

import '../../app/router.dart';
import '../../design/components/feedback.dart';
import '../../design/components/rule_status_tile.dart';
import '../../design/components/score_ring.dart';
import '../../design/components/surfaces.dart';
import '../../design/format.dart';
import '../../design/palette.dart';
import '../../design/tokens.dart';
import '../../design/typography.dart';
import '../../state/providers.dart';

/// A single trade: the plan, what happened, and how it was judged.
class TradeDetailScreen extends ConsumerWidget {
  final String tradeId;
  const TradeDetailScreen({super.key, required this.tradeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tradeFuture = ref.watch(_tradeProvider(tradeId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trade'),
        actions: [
          IconButton(
            onPressed: () => context.push(Routes.editTrade(tradeId)),
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit',
          ),
          IconButton(
            onPressed: () => _confirmDelete(context, ref),
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: 'Delete',
          ),
        ],
      ),
      body: switch (tradeFuture) {
        AsyncData(:final value) => value == null
            ? const EmptyState(
                icon: Icons.search_off_rounded,
                title: 'Trade not found',
                message: 'It may have been deleted from another device.',
              )
            : _TradeBody(trade: value),
        AsyncError() => const Padding(
            padding: EdgeInsets.all(Spacing.page),
            child: ErrorState(
              title: 'Could not open this trade',
              message: 'Try again in a moment.',
            ),
          ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await confirmAction(
      context,
      title: 'Delete this trade?',
      message:
          'Your discipline history for that day will be recalculated without '
          'it. This cannot be undone.',
      confirmLabel: 'Delete trade',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
    await ref.read(tradeRepositoryProvider).deleteTrade(tradeId);
    if (context.mounted) context.pop();
  }
}

final _tradeProvider =
    FutureProvider.autoDispose.family<Trade?, String>((ref, id) async {
  // Rebuilds when the collection changes so an edit made elsewhere shows here.
  ref.watch(tradesForDayProvider(ref.watch(todayKeyProvider)));
  return ref.watch(tradeRepositoryProvider).getTrade(id);
});

class _TradeBody extends ConsumerWidget {
  final Trade trade;
  const _TradeBody({required this.trade});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final account = ref.watch(activeAccountProvider);
    final strategies = ref.watch(strategiesProvider).value ?? const [];
    final rules = ref.watch(rulesProvider).value ?? const [];

    final currency = account?.currency ?? Currency.usd;
    final metrics = TradeCalculator.compute(trade);

    final evaluations = account == null
        ? const <RuleEvaluation>[]
        : RulesEngine.evaluateTrade(
            trade: trade,
            rules: rules,
            context: DayContext(
              tradingDayKey: trade.tradingDayKey,
              account: account,
              strategiesById: {for (final s in strategies) s.id: s},
            ),
          );
    final score = DisciplineScorer.score(
      evaluations,
      config: ref.watch(preferencesProvider).scoring,
    );

    final strategyName = strategies
        .where((s) => s.id == trade.strategyId)
        .map((s) => s.name)
        .firstOrNull;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        Spacing.page,
        Spacing.md,
        Spacing.page,
        Spacing.xxxl,
      ),
      children: [
        // Headline: symbol, direction, result.
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(trade.symbol, style: text.headlineLarge),
                  const SizedBox(height: Spacing.xxs),
                  Text(
                    '${trade.direction.label} · ${strategyName ?? 'No setup'} '
                    '· ${Fmt.dayKey(trade.tradingDayKey)}',
                    style:
                        text.bodySmall?.copyWith(color: colors.textSecondary),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  Fmt.r(metrics.realizedR),
                  style: PrayanType.metric(
                    metrics.netPnl == null
                        ? colors.textTertiary
                        : colors.forSign(metrics.netPnl!.signum),
                    size: 28,
                  ),
                ),
                Text(
                  Fmt.money(metrics.netPnl, currency, showSign: true),
                  style: PrayanType.figure(colors.textSecondary),
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: Spacing.xl),

        // Discipline for this trade specifically.
        if (score.hasScore)
          PrayanCard(
            child: Row(
              children: [
                ScoreRing(
                  score: score.value,
                  size: Sizes.scoreRingCompact,
                  wasCapped: score.wasCappedByMajorViolation,
                ),
                const SizedBox(width: Spacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Trade discipline', style: text.titleMedium),
                      const SizedBox(height: Spacing.xs),
                      Text(
                        score.summary,
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
        const SectionHeader(title: 'The plan'),
        PrayanCard(
          child: Column(
            children: [
              DetailRow(
                label: 'Planned entry',
                value: Fmt.number(trade.plannedEntryPrice),
              ),
              DetailRow(
                label: 'Stop loss',
                value: Fmt.number(trade.stopLossPrice),
                valueColor: trade.hasStop ? null : colors.warning,
              ),
              DetailRow(label: 'Target', value: Fmt.number(trade.targetPrice)),
              DetailRow(
                label: 'Planned risk',
                value: Fmt.money(metrics.plannedRisk, currency),
              ),
              DetailRow(
                label: 'Risk of equity',
                value: Fmt.percent(metrics.plannedRiskPercent),
              ),
              DetailRow(
                label: 'Planned reward:risk',
                value: Fmt.rewardRisk(metrics.plannedRewardRisk),
              ),
            ],
          ),
        ),

        const SizedBox(height: Spacing.section),
        const SectionHeader(title: 'What happened'),
        PrayanCard(
          child: Column(
            children: [
              DetailRow(
                label: 'Average entry',
                value: Fmt.number(metrics.averageEntryPrice),
              ),
              DetailRow(
                label: 'Average exit',
                value: Fmt.number(metrics.averageExitPrice),
              ),
              DetailRow(
                label: 'Quantity',
                value: Fmt.number(metrics.entryQuantity),
              ),
              if (!metrics.openQuantity.isZero)
                DetailRow(
                  label: 'Still open',
                  value: Fmt.number(metrics.openQuantity),
                ),
              DetailRow(
                label: 'Gross P&L',
                value: Fmt.money(metrics.grossPnl, currency, showSign: true),
              ),
              DetailRow(
                label: 'Fees',
                value: Fmt.money(metrics.fees, currency),
              ),
              DetailRow(
                label: 'Net P&L',
                value: Fmt.money(metrics.netPnl, currency, showSign: true),
                valueColor: metrics.netPnl == null
                    ? null
                    : colors.forSign(metrics.netPnl!.signum),
              ),
              DetailRow(
                label: 'Held for',
                value: Fmt.duration(metrics.holdingTime),
              ),
            ],
          ),
        ),

        if (evaluations.isNotEmpty) ...[
          const SizedBox(height: Spacing.section),
          const SectionHeader(
            title: 'Rules',
            subtitle: 'Judged against the rules live when the trade was taken.',
          ),
          PrayanCard(
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.md,
              vertical: Spacing.sm,
            ),
            child: Column(
              children: [
                for (final evaluation in evaluations
                    .where((e) => e.status != RuleStatus.notApplicable))
                  RuleStatusTile(evaluation: evaluation),
              ],
            ),
          ),
        ],

        const SizedBox(height: Spacing.section),
        const SectionHeader(title: 'Your notes'),
        PrayanCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Note(label: 'Why this trade', body: trade.entryReason),
              _Note(label: 'Why you exited', body: trade.exitReason),
              _Note(label: 'Management', body: trade.managementNotes),
              const SizedBox(height: Spacing.sm),
              DetailRow(
                label: 'Emotion before',
                value: trade.emotionBefore.label,
              ),
              if (trade.emotionAfter != null)
                DetailRow(
                  label: 'Emotion after',
                  value: trade.emotionAfter!.label,
                ),
              DetailRow(
                label: 'Confidence',
                value: trade.confidence == null
                    ? Fmt.emptyValue
                    : '${trade.confidence}/10',
              ),
              if (trade.mistake != MistakeCategory.none)
                DetailRow(
                  label: 'Process mistake',
                  value: trade.mistake.label,
                  valueColor: colors.warning,
                ),
              if (trade.wouldRepeat != null)
                DetailRow(
                  label: 'Would take again',
                  value: trade.wouldRepeat! ? 'Yes' : 'No',
                ),
              if (trade.tags.isNotEmpty) ...[
                const SizedBox(height: Spacing.md),
                Wrap(
                  spacing: Spacing.sm,
                  runSpacing: Spacing.xs,
                  children: [
                    for (final tag in trade.tags)
                      Chip(
                          label: Text(tag),
                          visualDensity: VisualDensity.compact),
                  ],
                ),
              ],
            ],
          ),
        ),

        if (trade.importSource != null) ...[
          const SizedBox(height: Spacing.lg),
          PrayanCard(
            child: Row(
              children: [
                Icon(Icons.science_outlined,
                    size: Sizes.iconMd, color: colors.textSecondary),
                const SizedBox(width: Spacing.md),
                Expanded(
                  child: Text(
                    'This is a sample trade, not one you logged. Remove the '
                    'samples from Settings whenever you like.',
                    style:
                        text.bodySmall?.copyWith(color: colors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _Note extends StatelessWidget {
  final String label;
  final String? body;

  const _Note({required this.label, required this.body});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: text.labelSmall?.copyWith(color: colors.textTertiary),
          ),
          const SizedBox(height: Spacing.xs),
          Text(
            body == null || body!.trim().isEmpty ? 'Not recorded' : body!,
            style: text.bodyMedium?.copyWith(
              color: body == null || body!.trim().isEmpty
                  ? colors.textTertiary
                  : colors.textPrimary,
              fontStyle: body == null || body!.trim().isEmpty
                  ? FontStyle.italic
                  : FontStyle.normal,
            ),
          ),
        ],
      ),
    );
  }
}

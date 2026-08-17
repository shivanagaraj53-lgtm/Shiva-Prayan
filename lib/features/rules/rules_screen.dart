import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:prayan_core/prayan_core.dart';

import '../../app/router.dart';
import '../../design/components/feedback.dart';
import '../../design/components/rule_status_tile.dart';
import '../../design/components/surfaces.dart';
import '../../design/palette.dart';
import '../../design/tokens.dart';
import '../../state/providers.dart';

/// The rule list (§9).
///
/// Rules can be reordered, paused and edited. Editing publishes a new version
/// rather than mutating the old one, so the list is a view of *today's* rules
/// while history keeps being judged by the rules that were live at the time.
class RulesScreen extends ConsumerWidget {
  const RulesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final rulesAsync = ref.watch(rulesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rules'),
        actions: [
          IconButton(
            onPressed: () => context.push(Routes.newRule),
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Add a rule',
          ),
        ],
      ),
      body: switch (rulesAsync) {
        AsyncData(:final value) => value.isEmpty
            ? EmptyState(
                icon: Icons.rule_rounded,
                title: 'No rules yet',
                message:
                    'Rules are what make the journal measurable. Start with '
                    'one — a stop on every trade is the usual first.',
                actionLabel: 'Add a rule',
                onAction: () => context.push(Routes.newRule),
              )
            : _RuleList(rules: value),
        AsyncError() => const Padding(
            padding: EdgeInsets.all(Spacing.page),
            child: ErrorState(
              title: 'Could not load your rules',
              message: 'Try again in a moment.',
            ),
          ),
        _ => const Center(child: CircularProgressIndicator()),
      },
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.page),
          child: Text(
            'Changing a rule takes effect from now on. Trades already logged '
            'keep being judged by the version that was live when you took '
            'them.',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: colors.textTertiary, letterSpacing: 0),
          ),
        ),
      ),
    );
  }
}

class _RuleList extends ConsumerWidget {
  final List<Rule> rules;
  const _RuleList({required this.rules});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Group by scoring category so related rules sit together and the weight
    // model is visible rather than implied.
    final byCategory = <RuleCategory, List<Rule>>{};
    for (final rule in rules) {
      byCategory.putIfAbsent(rule.current.category, () => []).add(rule);
    }
    final categories = byCategory.keys.toList()
      ..sort((a, b) => a.index.compareTo(b.index));

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        Spacing.page,
        Spacing.md,
        Spacing.page,
        Spacing.xxxl,
      ),
      children: [
        for (final category in categories) ...[
          SectionHeader(
            title: category.label,
            subtitle: 'Weight ${category.defaultWeight}% of the score',
          ),
          PrayanCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final rule in byCategory[category]!) _RuleTile(rule: rule),
              ],
            ),
          ),
          const SizedBox(height: Spacing.section),
        ],
      ],
    );
  }
}

class _RuleTile extends ConsumerWidget {
  final Rule rule;
  const _RuleTile({required this.rule});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final version = rule.current;

    return InkWell(
      onTap: () => context.push(Routes.editRule(rule.id)),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.lg,
          vertical: Spacing.md,
        ),
        child: Row(
          children: [
            Expanded(
              child: Opacity(
                opacity: rule.isActive ? 1 : 0.5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(version.name, style: text.titleMedium),
                        ),
                        const SizedBox(width: Spacing.sm),
                        SeverityChip(severity: version.severity),
                      ],
                    ),
                    const SizedBox(height: Spacing.xxs),
                    Text(
                      _thresholdLabel(version),
                      style:
                          text.bodySmall?.copyWith(color: colors.textSecondary),
                    ),
                    if (version.version > 1) ...[
                      const SizedBox(height: Spacing.xxs),
                      Text(
                        'Version ${version.version}',
                        style: text.labelSmall
                            ?.copyWith(color: colors.textTertiary),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Switch(
              value: rule.isActive,
              onChanged: (value) => ref
                  .read(ruleRepositoryProvider)
                  .setRuleActive(rule.id, value),
            ),
          ],
        ),
      ),
    );
  }

  /// Renders the threshold in the unit the measure implies.
  static String _thresholdLabel(RuleVersion version) {
    final threshold = version.threshold;
    return switch (version.measure) {
      RuleMeasure.maxRiskPercentPerTrade =>
        'At most ${threshold?.normalized ?? '—'}% of equity per trade',
      RuleMeasure.maxRiskMoneyPerTrade =>
        'At most ${threshold?.normalized ?? '—'} per trade',
      RuleMeasure.minPlannedRewardRisk =>
        'Planned 1:${threshold?.normalized ?? '—'} or better',
      RuleMeasure.maxTradesPerDay =>
        'At most ${threshold?.normalized ?? '—'} trades a day',
      RuleMeasure.maxDailyLossR =>
        'Stop for the day at ${threshold?.normalized ?? '—'}R',
      RuleMeasure.maxDailyLossMoney =>
        'Stop for the day at ${threshold?.normalized ?? '—'}',
      RuleMeasure.maxDailyLossPercent =>
        'Stop for the day at ${threshold?.normalized ?? '—'}% of equity',
      RuleMeasure.maxWeeklyLossR =>
        'Stop for the week at ${threshold?.normalized ?? '—'}R',
      RuleMeasure.maxWeeklyLossMoney =>
        'Stop for the week at ${threshold?.normalized ?? '—'}',
      RuleMeasure.maxConsecutiveLosses =>
        'Stop after ${threshold?.normalized ?? '—'} losses in a row',
      RuleMeasure.stopLossRequired => 'A stop is defined before entry',
      RuleMeasure.approvedStrategyOnly => 'Only approved setups',
      RuleMeasure.checklistCompletion => 'The checklist is completed',
      RuleMeasure.notesRequired => 'Every trade carries a note',
      RuleMeasure.screenshotRequired => 'Every trade carries a screenshot',
      RuleMeasure.noAddingToLosers => 'Never add to a losing position',
      RuleMeasure.noTradingAfterDailyStop =>
        'No trading once the daily stop is reached',
      RuleMeasure.sessionRestriction =>
        'Only in ${version.sessions.map((s) => s.label).join(', ')}',
      RuleMeasure.dailyReviewCompleted => 'The daily review is completed',
      RuleMeasure.manualCustom => version.description,
    };
  }
}

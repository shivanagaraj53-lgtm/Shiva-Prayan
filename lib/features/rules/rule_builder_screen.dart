import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:prayan_core/prayan_core.dart';

import '../../design/components/feedback.dart';
import '../../design/components/rule_status_tile.dart';
import '../../design/components/surfaces.dart';
import '../../design/palette.dart';
import '../../design/tokens.dart';
import '../../state/providers.dart';

/// Create or edit a rule.
///
/// Editing an existing rule publishes a *new version* rather than overwriting
/// the current one. The screen says so explicitly, because a user who does not
/// realise that would expect their history to change too.
class RuleBuilderScreen extends ConsumerStatefulWidget {
  final String? ruleId;
  const RuleBuilderScreen({super.key, this.ruleId});

  @override
  ConsumerState<RuleBuilderScreen> createState() => _RuleBuilderScreenState();
}

class _RuleBuilderScreenState extends ConsumerState<RuleBuilderScreen> {
  String _name = '';
  String _description = '';
  RuleMeasure _measure = RuleMeasure.maxRiskPercentPerTrade;
  RuleSeverity _severity = RuleSeverity.warning;
  RuleCategory _category = RuleCategory.riskLimit;
  String _threshold = '';
  List<MarketSession> _sessions = const [];
  List<int> _weekdays = const [];
  bool _loaded = false;
  bool _saving = false;

  bool get _isEditing => widget.ruleId != null;

  /// Measures that compare against a number.
  static const _needsThreshold = {
    RuleMeasure.maxRiskPercentPerTrade,
    RuleMeasure.maxRiskMoneyPerTrade,
    RuleMeasure.minPlannedRewardRisk,
    RuleMeasure.maxTradesPerDay,
    RuleMeasure.maxDailyLossMoney,
    RuleMeasure.maxDailyLossPercent,
    RuleMeasure.maxDailyLossR,
    RuleMeasure.maxWeeklyLossMoney,
    RuleMeasure.maxWeeklyLossR,
    RuleMeasure.maxConsecutiveLosses,
    RuleMeasure.checklistCompletion,
  };

  void _loadExisting(List<Rule> rules) {
    if (_loaded || !_isEditing) return;
    final rule = rules.where((r) => r.id == widget.ruleId).firstOrNull;
    if (rule == null) return;
    _loaded = true;
    final version = rule.current;
    setState(() {
      _name = version.name;
      _description = version.description;
      _measure = version.measure;
      _severity = version.severity;
      _category = version.category;
      _threshold = version.threshold?.normalized.toString() ?? '';
      _sessions = version.sessions;
      _weekdays = version.weekdays;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final rules = ref.watch(rulesProvider).value ?? const [];
    _loadExisting(rules);

    final needsThreshold = _needsThreshold.contains(_measure);
    final canSave = _name.trim().isNotEmpty &&
        (!needsThreshold || Dec.tryParse(_threshold) != null);

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit rule' : 'New rule')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          Spacing.page,
          Spacing.md,
          Spacing.page,
          Spacing.xxxl,
        ),
        children: [
          TextFormField(
            initialValue: _name,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Rule name',
              hintText: 'Maximum risk per trade',
            ),
            onChanged: (value) => setState(() => _name = value),
          ),
          const SizedBox(height: Spacing.lg),
          TextFormField(
            initialValue: _description,
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'What does it mean?',
              helperText: 'Shown in the audit trail when the rule applies.',
            ),
            onChanged: (value) => setState(() => _description = value),
          ),
          const SizedBox(height: Spacing.section),
          const SectionHeader(
            title: 'What does it measure?',
            subtitle: 'Determines how Prayan evaluates it automatically.',
          ),
          DropdownButtonFormField<RuleMeasure>(
            initialValue: _measure,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Measure'),
            items: [
              for (final measure in RuleMeasure.values)
                DropdownMenuItem(
                  value: measure,
                  child: Text(
                    _measureLabel(measure),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                _measure = value;
                _category = _suggestedCategory(value);
              });
            },
          ),
          if (needsThreshold) ...[
            const SizedBox(height: Spacing.lg),
            TextFormField(
              initialValue: _threshold,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Threshold',
                suffixText: _unitFor(_measure),
                helperText: _helperFor(_measure),
              ),
              onChanged: (value) => setState(() => _threshold = value),
            ),
          ],
          if (_measure == RuleMeasure.sessionRestriction) ...[
            const SizedBox(height: Spacing.lg),
            Text('Sessions you allow',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: Spacing.sm),
            Wrap(
              spacing: Spacing.sm,
              runSpacing: Spacing.sm,
              children: [
                for (final session in MarketSession.values)
                  FilterChip(
                    label: Text(session.label),
                    selected: _sessions.contains(session),
                    onSelected: (selected) => setState(() {
                      final next = [..._sessions];
                      if (selected) {
                        next.add(session);
                      } else {
                        next.remove(session);
                      }
                      _sessions = next;
                    }),
                  ),
              ],
            ),
          ],
          const SizedBox(height: Spacing.section),
          const SectionHeader(
            title: 'How serious is breaking it?',
            subtitle:
                'A major breach caps the day and resets the clean streak. '
                'Historical scores are never erased.',
          ),
          // Selection state lives on the RadioGroup ancestor; the per-tile
          // `groupValue`/`onChanged` pair was deprecated in Flutter 3.32.
          RadioGroup<RuleSeverity>(
            groupValue: _severity,
            onChanged: (value) =>
                setState(() => _severity = value ?? _severity),
            child: Column(
              children: [
                for (final severity in RuleSeverity.values)
                  RadioListTile<RuleSeverity>(
                    value: severity,
                    title: Row(
                      children: [
                        Text(severity.label),
                        const SizedBox(width: Spacing.sm),
                        SeverityChip(severity: severity),
                      ],
                    ),
                    subtitle: Text(
                      switch (severity) {
                        RuleSeverity.info =>
                          'Recorded and explained, but never changes the '
                              'score.',
                        RuleSeverity.warning =>
                          'Reduces the score in proportion to its category '
                              'weight.',
                        RuleSeverity.major =>
                          'Caps the day and resets your clean streak.',
                      },
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: colors.textSecondary),
                    ),
                    contentPadding: EdgeInsets.zero,
                  ),
              ],
            ),
          ),
          const SizedBox(height: Spacing.section),
          const SectionHeader(
            title: 'Which part of the score?',
            subtitle: 'Rules in the same category share that category weight.',
          ),
          DropdownButtonFormField<RuleCategory>(
            initialValue: _category,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Category'),
            items: [
              for (final category in RuleCategory.values)
                DropdownMenuItem(
                  value: category,
                  child: Text(
                    '${category.label} · ${category.defaultWeight}%',
                  ),
                ),
            ],
            onChanged: (value) =>
                setState(() => _category = value ?? _category),
          ),
          const SizedBox(height: Spacing.section),
          const SectionHeader(
            title: 'When does it apply?',
            subtitle: 'Leave empty to apply on every trading day.',
          ),
          Wrap(
            spacing: Spacing.sm,
            runSpacing: Spacing.sm,
            children: [
              for (var weekday = 1; weekday <= 7; weekday++)
                FilterChip(
                  label: Text(_weekdayLabel(weekday)),
                  selected: _weekdays.contains(weekday),
                  onSelected: (selected) => setState(() {
                    final next = [..._weekdays];
                    if (selected) {
                      next.add(weekday);
                    } else {
                      next.remove(weekday);
                    }
                    _weekdays = next;
                  }),
                ),
            ],
          ),
          if (_isEditing) ...[
            const SizedBox(height: Spacing.section),
            PrayanCard(
              child: Row(
                children: [
                  Icon(Icons.history_rounded,
                      size: Sizes.iconMd, color: colors.textSecondary),
                  const SizedBox(width: Spacing.md),
                  Expanded(
                    child: Text(
                      'Saving publishes a new version of this rule. Trades '
                      'already logged keep being judged by the version that '
                      'was live when you took them.',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: colors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: Spacing.xl),
          FilledButton(
            onPressed: canSave && !_saving ? () => _save(rules) : null,
            child: Text(_isEditing ? 'Publish new version' : 'Create rule'),
          ),
          if (_isEditing) ...[
            const SizedBox(height: Spacing.sm),
            TextButton(
              onPressed: _saving ? null : _delete,
              style: TextButton.styleFrom(foregroundColor: colors.violation),
              child: const Text('Delete this rule'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _save(List<Rule> rules) async {
    setState(() => _saving = true);
    try {
      final userId = ref.read(currentUserIdProvider);
      if (userId == null) return;
      final now = ref.read(nowProvider)();
      final threshold = Dec.tryParse(_threshold);
      final repository = ref.read(ruleRepositoryProvider);

      if (_isEditing) {
        final existing = rules.where((r) => r.id == widget.ruleId).firstOrNull;
        if (existing == null) return;
        await repository.publishRuleVersion(
          existing.id,
          RuleVersion(
            id: '${existing.id}_v${existing.current.version + 1}',
            ruleId: existing.id,
            version: existing.current.version + 1,
            name: _name.trim(),
            description: _description.trim(),
            category: _category,
            severity: _severity,
            measure: _measure,
            threshold: threshold,
            sessions: _sessions,
            weekdays: _weekdays,
            effectiveFromUtc: now,
          ),
          now,
        );
      } else {
        final id = 'rule_${now.microsecondsSinceEpoch}';
        await repository.createRule(
          Rule(
            id: id,
            userId: userId,
            position: rules.length,
            current: RuleVersion(
              id: '${id}_v1',
              ruleId: id,
              version: 1,
              name: _name.trim(),
              description: _description.trim(),
              category: _category,
              severity: _severity,
              measure: _measure,
              threshold: threshold,
              sessions: _sessions,
              weekdays: _weekdays,
              effectiveFromUtc: now,
            ),
          ),
        );
      }
      if (mounted) context.pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await confirmAction(
      context,
      title: 'Delete this rule?',
      message:
          'Past trades keep the evaluations they already have, but this rule '
          'will stop applying from now on. Pausing it instead keeps the '
          'option to bring it back.',
      confirmLabel: 'Delete rule',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    await ref.read(ruleRepositoryProvider).deleteRule(widget.ruleId!);
    if (mounted) context.pop();
  }

  static RuleCategory _suggestedCategory(RuleMeasure measure) =>
      switch (measure) {
        RuleMeasure.maxRiskPercentPerTrade ||
        RuleMeasure.maxRiskMoneyPerTrade ||
        RuleMeasure.noAddingToLosers =>
          RuleCategory.riskLimit,
        RuleMeasure.stopLossRequired => RuleCategory.stopLoss,
        RuleMeasure.minPlannedRewardRisk => RuleCategory.rewardRisk,
        RuleMeasure.approvedStrategyOnly => RuleCategory.approvedSetup,
        RuleMeasure.maxTradesPerDay ||
        RuleMeasure.maxDailyLossMoney ||
        RuleMeasure.maxDailyLossPercent ||
        RuleMeasure.maxDailyLossR ||
        RuleMeasure.maxWeeklyLossMoney ||
        RuleMeasure.maxWeeklyLossR ||
        RuleMeasure.maxConsecutiveLosses ||
        RuleMeasure.noTradingAfterDailyStop =>
          RuleCategory.dailyLimits,
        RuleMeasure.checklistCompletion => RuleCategory.checklist,
        RuleMeasure.notesRequired ||
        RuleMeasure.screenshotRequired ||
        RuleMeasure.dailyReviewCompleted =>
          RuleCategory.journalQuality,
        RuleMeasure.sessionRestriction ||
        RuleMeasure.manualCustom =>
          RuleCategory.custom,
      };

  static String _measureLabel(RuleMeasure measure) => switch (measure) {
        RuleMeasure.maxRiskPercentPerTrade => 'Maximum risk per trade (%)',
        RuleMeasure.maxRiskMoneyPerTrade => 'Maximum risk per trade (money)',
        RuleMeasure.minPlannedRewardRisk => 'Minimum planned reward:risk',
        RuleMeasure.stopLossRequired => 'A stop is defined before entry',
        RuleMeasure.approvedStrategyOnly => 'Only approved setups',
        RuleMeasure.sessionRestriction => 'Only in certain sessions',
        RuleMeasure.checklistCompletion => 'Pre-trade checklist completed',
        RuleMeasure.notesRequired => 'Every trade carries a note',
        RuleMeasure.screenshotRequired => 'Every trade carries a screenshot',
        RuleMeasure.noAddingToLosers => 'Never add to a losing position',
        RuleMeasure.maxTradesPerDay => 'Maximum trades per day',
        RuleMeasure.maxDailyLossMoney => 'Daily loss limit (money)',
        RuleMeasure.maxDailyLossPercent => 'Daily loss limit (%)',
        RuleMeasure.maxDailyLossR => 'Daily loss limit (R)',
        RuleMeasure.maxConsecutiveLosses => 'Maximum consecutive losses',
        RuleMeasure.noTradingAfterDailyStop =>
          'No trading after the daily stop',
        RuleMeasure.maxWeeklyLossMoney => 'Weekly loss limit (money)',
        RuleMeasure.maxWeeklyLossR => 'Weekly loss limit (R)',
        RuleMeasure.dailyReviewCompleted => 'Daily review completed',
        RuleMeasure.manualCustom => 'Custom — I mark it myself',
      };

  static String? _unitFor(RuleMeasure measure) => switch (measure) {
        RuleMeasure.maxRiskPercentPerTrade ||
        RuleMeasure.maxDailyLossPercent =>
          '%',
        RuleMeasure.maxDailyLossR || RuleMeasure.maxWeeklyLossR => 'R',
        RuleMeasure.maxTradesPerDay => 'trades',
        RuleMeasure.maxConsecutiveLosses => 'losses',
        _ => null,
      };

  static String? _helperFor(RuleMeasure measure) => switch (measure) {
        RuleMeasure.minPlannedRewardRisk =>
          'Enter 2 for a 1:2 minimum reward:risk.',
        RuleMeasure.checklistCompletion =>
          'Enter 1 for the whole checklist, 0.8 for 80%.',
        _ => null,
      };

  static String _weekdayLabel(int weekday) => switch (weekday) {
        DateTime.monday => 'Mon',
        DateTime.tuesday => 'Tue',
        DateTime.wednesday => 'Wed',
        DateTime.thursday => 'Thu',
        DateTime.friday => 'Fri',
        DateTime.saturday => 'Sat',
        _ => 'Sun',
      };
}

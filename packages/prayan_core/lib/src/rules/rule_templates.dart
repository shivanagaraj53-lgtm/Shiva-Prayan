import '../models/enums.dart';
import '../models/rule.dart';
import '../money/dec.dart';

/// A named starter set of rules offered during onboarding (brief §23).
///
/// These are *organisational templates, not financial recommendations*. The
/// onboarding copy says so explicitly, and nothing in the product treats a
/// template as advice or as a target to beat.
class RuleTemplate {
  final String id;
  final String name;
  final String description;

  /// Short caveat rendered under the template name in onboarding.
  final String disclaimer;

  final List<RuleTemplateEntry> entries;

  const RuleTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.entries,
    this.disclaimer =
        'A starting structure you can change at any time, not financial advice.',
  });

  /// Materialises the template into concrete [Rule]s for [userId].
  ///
  /// [now] becomes the effective-from instant of version 1, so trades logged
  /// before setup are simply not judged by these rules.
  List<Rule> instantiate({
    required String userId,
    required DateTime now,
    String idPrefix = 'rule',
  }) {
    final rules = <Rule>[];
    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      final ruleId = '${idPrefix}_${entry.measure.wireName}_$i';
      rules.add(Rule(
        id: ruleId,
        userId: userId,
        position: i,
        current: RuleVersion(
          id: '${ruleId}_v1',
          ruleId: ruleId,
          version: 1,
          name: entry.name,
          description: entry.description,
          category: entry.category,
          severity: entry.severity,
          measure: entry.measure,
          threshold: entry.threshold,
          sessions: entry.sessions,
          weight: entry.weight,
          effectiveFromUtc: now.toUtc(),
        ),
      ));
    }
    return rules;
  }
}

/// One rule inside a template.
class RuleTemplateEntry {
  final String name;
  final String description;
  final RuleCategory category;
  final RuleSeverity severity;
  final RuleMeasure measure;
  final Dec? threshold;
  final List<MarketSession> sessions;
  final int weight;

  const RuleTemplateEntry({
    required this.name,
    required this.description,
    required this.category,
    required this.severity,
    required this.measure,
    this.threshold,
    this.sessions = const [],
    this.weight = 1,
  });
}

/// The templates offered at onboarding.
class RuleTemplates {
  const RuleTemplates._();

  /// Rules every template includes, because they are what makes the journal
  /// measurable at all rather than being opinions about risk appetite.
  static List<RuleTemplateEntry> _foundation({
    required String riskPercent,
    required String minRewardRisk,
    required int maxTrades,
    required String dailyLossR,
    required RuleSeverity riskSeverity,
  }) =>
      [
        RuleTemplateEntry(
          name: 'Maximum risk per trade',
          description:
              'Never risk more than $riskPercent% of account equity on a '
              'single trade.',
          category: RuleCategory.riskLimit,
          severity: riskSeverity,
          measure: RuleMeasure.maxRiskPercentPerTrade,
          threshold: Dec.parse(riskPercent),
        ),
        const RuleTemplateEntry(
          name: 'Stop defined before entry',
          description:
              'Every trade has a stop-loss recorded before the position is '
              'opened.',
          category: RuleCategory.stopLoss,
          severity: RuleSeverity.major,
          measure: RuleMeasure.stopLossRequired,
        ),
        RuleTemplateEntry(
          name: 'Minimum planned reward:risk',
          description:
              'Only take setups planned at 1:$minRewardRisk or better.',
          category: RuleCategory.rewardRisk,
          severity: RuleSeverity.warning,
          measure: RuleMeasure.minPlannedRewardRisk,
          threshold: Dec.parse(minRewardRisk),
        ),
        const RuleTemplateEntry(
          name: 'Approved setups only',
          description: 'Trade only the setups on your approved list.',
          category: RuleCategory.approvedSetup,
          severity: RuleSeverity.warning,
          measure: RuleMeasure.approvedStrategyOnly,
        ),
        RuleTemplateEntry(
          name: 'Maximum trades per day',
          description: 'Take at most $maxTrades trades in a single session.',
          category: RuleCategory.dailyLimits,
          severity: RuleSeverity.warning,
          measure: RuleMeasure.maxTradesPerDay,
          threshold: Dec.fromInt(maxTrades),
        ),
        RuleTemplateEntry(
          name: 'Daily loss stop',
          description:
              'Finish trading for the day after losing ${dailyLossR}R.',
          category: RuleCategory.dailyLimits,
          severity: RuleSeverity.major,
          measure: RuleMeasure.maxDailyLossR,
          threshold: Dec.parse(dailyLossR),
        ),
        const RuleTemplateEntry(
          name: 'No trading after the daily stop',
          description:
              'Once the daily loss limit is reached, the session is over.',
          category: RuleCategory.dailyLimits,
          severity: RuleSeverity.major,
          measure: RuleMeasure.noTradingAfterDailyStop,
        ),
        const RuleTemplateEntry(
          name: 'Complete the pre-trade checklist',
          description: 'Work through your checklist before every entry.',
          category: RuleCategory.checklist,
          severity: RuleSeverity.warning,
          measure: RuleMeasure.checklistCompletion,
        ),
        const RuleTemplateEntry(
          name: 'Record your reasoning',
          description: 'Every trade carries an entry reason or a note.',
          category: RuleCategory.journalQuality,
          severity: RuleSeverity.warning,
          measure: RuleMeasure.notesRequired,
        ),
      ];

  /// Tight limits, more rules treated as major.
  static final conservative = RuleTemplate(
    id: 'conservative',
    name: 'Conservative',
    description:
        'Tight per-trade risk, a small trade budget and an early daily stop. '
        'A structure often used by traders prioritising capital preservation.',
    entries: [
      ..._foundation(
        riskPercent: '0.5',
        minRewardRisk: '2',
        maxTrades: 2,
        dailyLossR: '1',
        riskSeverity: RuleSeverity.major,
      ),
      const RuleTemplateEntry(
        name: 'Never add to a losing position',
        description: 'Do not average down into a trade that is against you.',
        category: RuleCategory.riskLimit,
        severity: RuleSeverity.major,
        measure: RuleMeasure.noAddingToLosers,
      ),
      const RuleTemplateEntry(
        name: 'Complete the daily review',
        description: 'Close the day by reviewing it.',
        category: RuleCategory.journalQuality,
        severity: RuleSeverity.warning,
        measure: RuleMeasure.dailyReviewCompleted,
      ),
    ],
  );

  /// The default suggestion, matching the brief's worked example (§39).
  static final balanced = RuleTemplate(
    id: 'balanced',
    name: 'Balanced',
    description:
        '1% risk per trade, a 1:2 minimum reward:risk, three trades a day and '
        'a 2R daily stop.',
    entries: [
      ..._foundation(
        riskPercent: '1',
        minRewardRisk: '2',
        maxTrades: 3,
        dailyLossR: '2',
        riskSeverity: RuleSeverity.warning,
      ),
      const RuleTemplateEntry(
        name: 'Never add to a losing position',
        description: 'Do not average down into a trade that is against you.',
        category: RuleCategory.riskLimit,
        severity: RuleSeverity.warning,
        measure: RuleMeasure.noAddingToLosers,
      ),
    ],
  );

  /// The minimum viable set for a user who wants to define their own.
  static final custom = RuleTemplate(
    id: 'custom',
    name: 'Custom',
    description:
        'Start with only the two rules that make a journal measurable, then '
        'add your own.',
    entries: const [
      RuleTemplateEntry(
        name: 'Stop defined before entry',
        description:
            'Every trade has a stop-loss recorded before the position is '
            'opened.',
        category: RuleCategory.stopLoss,
        severity: RuleSeverity.major,
        measure: RuleMeasure.stopLossRequired,
      ),
      RuleTemplateEntry(
        name: 'Record your reasoning',
        description: 'Every trade carries an entry reason or a note.',
        category: RuleCategory.journalQuality,
        severity: RuleSeverity.warning,
        measure: RuleMeasure.notesRequired,
      ),
    ],
  );

  static List<RuleTemplate> get all => [conservative, balanced, custom];

  static RuleTemplate? byId(String id) {
    for (final template in all) {
      if (template.id == id) return template;
    }
    return null;
  }
}

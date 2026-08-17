import 'package:prayan_core/prayan_core.dart';
import 'package:test/test.dart';

RuleEvaluation evaluation({
  required String ruleId,
  required RuleCategory category,
  required RuleStatus status,
  RuleSeverity severity = RuleSeverity.warning,
  String name = 'Rule',
  int weight = 1,
}) =>
    RuleEvaluation(
      ruleId: ruleId,
      ruleVersionId: '${ruleId}_v1',
      ruleName: name,
      category: category,
      severity: severity,
      measure: RuleMeasure.manualCustom,
      scope: RuleScope.trade,
      status: status,
      message: '',
      weight: weight,
    );

void main() {
  group('Weighting and normalisation', () {
    test('all rules followed scores 100', () {
      final score = DisciplineScorer.score([
        evaluation(
            ruleId: 'a',
            category: RuleCategory.riskLimit,
            status: RuleStatus.passed),
        evaluation(
            ruleId: 'b',
            category: RuleCategory.stopLoss,
            status: RuleStatus.passed),
      ]);
      expect(score.value, Dec.hundred);
      expect(score.isClean, isTrue);
      expect(score.rulesFollowed, 2);
      expect(score.rulesApplicable, 2);
    });

    test('all rules broken scores 0', () {
      final score = DisciplineScorer.score([
        evaluation(
            ruleId: 'a',
            category: RuleCategory.riskLimit,
            status: RuleStatus.violated),
      ]);
      expect(score.value, Dec.zero);
      expect(score.isClean, isFalse);
    });

    test('weights normalise over only the categories that applied', () {
      // Risk (25) passed, checklist (10) broken. Nothing else applies.
      // Expected = 25/(25+10) x 100 = 71.4
      final score = DisciplineScorer.score([
        evaluation(
            ruleId: 'a',
            category: RuleCategory.riskLimit,
            status: RuleStatus.passed),
        evaluation(
            ruleId: 'b',
            category: RuleCategory.checklist,
            status: RuleStatus.violated),
      ]);
      expect(score.value, Dec.parse('71.4'));

      final riskComponent =
          score.components.firstWhere((c) => c.category == RuleCategory.riskLimit);
      expect(riskComponent.normalizedWeight.roundTo(1), Dec.parse('71.4'));
      expect(riskComponent.categoryScore, Dec.hundred);
    });

    test('a category with several rules splits by rule weight', () {
      // Two risk rules, one passed (weight 3), one broken (weight 1).
      final score = DisciplineScorer.score([
        evaluation(
            ruleId: 'a',
            category: RuleCategory.riskLimit,
            status: RuleStatus.passed,
            weight: 3),
        evaluation(
            ruleId: 'b',
            category: RuleCategory.riskLimit,
            status: RuleStatus.violated,
            weight: 1),
      ]);
      // Only one category applies, so the day is that category's score: 75.
      expect(score.value, Dec.parse('75'));
    });

    test('informational rules never move the score', () {
      final score = DisciplineScorer.score([
        evaluation(
            ruleId: 'a',
            category: RuleCategory.riskLimit,
            status: RuleStatus.passed),
        evaluation(
            ruleId: 'b',
            category: RuleCategory.checklist,
            status: RuleStatus.violated,
            severity: RuleSeverity.info),
      ]);
      expect(score.value, Dec.hundred);
      expect(score.rulesApplicable, 1);
    });

    test('not-applicable rules leave the denominator untouched', () {
      final score = DisciplineScorer.score([
        evaluation(
            ruleId: 'a',
            category: RuleCategory.riskLimit,
            status: RuleStatus.passed),
        evaluation(
            ruleId: 'b',
            category: RuleCategory.checklist,
            status: RuleStatus.notApplicable),
      ]);
      expect(score.value, Dec.hundred);
      expect(score.rulesApplicable, 1);
    });

    test('indeterminate rules are surfaced, never counted as a pass', () {
      final score = DisciplineScorer.score([
        evaluation(
            ruleId: 'a',
            category: RuleCategory.riskLimit,
            status: RuleStatus.passed),
        evaluation(
            ruleId: 'b',
            category: RuleCategory.checklist,
            status: RuleStatus.indeterminate),
      ]);
      expect(score.rulesApplicable, 1);
      expect(score.unresolved, hasLength(1));
      expect(score.unresolved.single.ruleId, 'b');
    });

    test('no applicable rules yields no score rather than zero', () {
      final score = DisciplineScorer.score([
        evaluation(
            ruleId: 'a',
            category: RuleCategory.riskLimit,
            status: RuleStatus.notApplicable),
      ]);
      expect(score.hasScore, isFalse);
      expect(score.summary, contains('no score to report'));
    });
  });

  group('Major violations', () {
    test('cap the day even when everything else was followed', () {
      final evaluations = [
        for (final category in [
          RuleCategory.riskLimit,
          RuleCategory.rewardRisk,
          RuleCategory.approvedSetup,
          RuleCategory.dailyLimits,
          RuleCategory.checklist,
          RuleCategory.journalQuality,
        ])
          evaluation(
              ruleId: category.wireName,
              category: category,
              status: RuleStatus.passed),
        evaluation(
          ruleId: 'stop',
          name: 'Stop defined before entry',
          category: RuleCategory.stopLoss,
          status: RuleStatus.violated,
          severity: RuleSeverity.major,
        ),
      ];
      final score = DisciplineScorer.score(evaluations);
      expect(score.wasCappedByMajorViolation, isTrue);
      expect(score.value, Dec.fromInt(60));
      // The uncapped figure is retained for the audit trail.
      expect(score.uncappedValue > Dec.fromInt(60), isTrue);
      expect(score.majorViolations, hasLength(1));
    });

    test('do not raise a score that was already below the cap', () {
      final score = DisciplineScorer.score([
        evaluation(
          ruleId: 'stop',
          category: RuleCategory.stopLoss,
          status: RuleStatus.violated,
          severity: RuleSeverity.major,
        ),
        evaluation(
            ruleId: 'risk',
            category: RuleCategory.riskLimit,
            status: RuleStatus.violated),
      ]);
      expect(score.value, Dec.zero);
      expect(score.wasCappedByMajorViolation, isFalse);
    });

    test('the cap is configurable', () {
      final evaluations = [
        evaluation(
            ruleId: 'a',
            category: RuleCategory.riskLimit,
            status: RuleStatus.passed),
        evaluation(
          ruleId: 'b',
          category: RuleCategory.stopLoss,
          status: RuleStatus.violated,
          severity: RuleSeverity.major,
        ),
      ];
      final strict = DisciplineScorer.score(evaluations,
          config: const ScoringConfig(majorViolationCap: 25));
      expect(strict.value, Dec.fromInt(25));
    });
  });

  group('Process outranks profit', () {
    test('a rule-following loser outscores a rule-breaking winner', () {
      final disciplinedLoss = DisciplineScorer.score([
        evaluation(
            ruleId: 'risk',
            category: RuleCategory.riskLimit,
            status: RuleStatus.passed),
        evaluation(
            ruleId: 'stop',
            category: RuleCategory.stopLoss,
            status: RuleStatus.passed,
            severity: RuleSeverity.major),
        evaluation(
            ruleId: 'rr',
            category: RuleCategory.rewardRisk,
            status: RuleStatus.passed),
      ]);

      final recklessWin = DisciplineScorer.score([
        evaluation(
            ruleId: 'risk',
            category: RuleCategory.riskLimit,
            status: RuleStatus.violated),
        evaluation(
            ruleId: 'stop',
            category: RuleCategory.stopLoss,
            status: RuleStatus.violated,
            severity: RuleSeverity.major),
        evaluation(
            ruleId: 'rr',
            category: RuleCategory.rewardRisk,
            status: RuleStatus.passed),
      ]);

      // The scorer never sees P&L at all — this is structural, not a heuristic.
      expect(disciplinedLoss.value > recklessWin.value, isTrue);
      expect(disciplinedLoss.value, Dec.hundred);
    });
  });

  group('Explainability', () {
    test('summary names the count and the broken rules', () {
      final score = DisciplineScorer.score([
        for (var i = 0; i < 8; i++)
          evaluation(
              ruleId: 'ok$i',
              category: RuleCategory.values[i % RuleCategory.values.length],
              status: RuleStatus.passed),
        evaluation(
          ruleId: 'rr',
          name: 'Minimum planned reward:risk',
          category: RuleCategory.rewardRisk,
          status: RuleStatus.violated,
        ),
      ]);
      expect(score.summary, contains('applicable rules were followed'));
      expect(score.summary, contains('Minimum planned reward:risk'));
      expect(score.rulesApplicable, 9);
    });

    test('components sum to the uncapped score', () {
      final score = DisciplineScorer.score([
        evaluation(
            ruleId: 'a',
            category: RuleCategory.riskLimit,
            status: RuleStatus.passed),
        evaluation(
            ruleId: 'b',
            category: RuleCategory.checklist,
            status: RuleStatus.violated),
        evaluation(
            ruleId: 'c',
            category: RuleCategory.stopLoss,
            status: RuleStatus.passed),
      ]);
      var total = Dec.zero;
      for (final component in score.components) {
        total += component.contribution;
      }
      expect(total.roundTo(1), score.uncappedValue);
    });

    test('serialises the full audit trail', () {
      final score = DisciplineScorer.score([
        evaluation(
            ruleId: 'a',
            category: RuleCategory.riskLimit,
            status: RuleStatus.violated),
      ]);
      final map = score.toMap();
      expect(map['value'], isNotNull);
      expect(map['violations'] as List, hasLength(1));
      expect(map['components'] as List, hasLength(1));
    });
  });

  group('Custom weights', () {
    test('user weighting shifts the result but stays within 0-100', () {
      final evaluations = [
        evaluation(
            ruleId: 'a',
            category: RuleCategory.riskLimit,
            status: RuleStatus.passed),
        evaluation(
            ruleId: 'b',
            category: RuleCategory.checklist,
            status: RuleStatus.violated),
      ];
      final checklistHeavy = DisciplineScorer.score(
        evaluations,
        config: const ScoringConfig(categoryWeights: {
          RuleCategory.riskLimit: 10,
          RuleCategory.checklist: 90,
        }),
      );
      expect(checklistHeavy.value, Dec.fromInt(10));
      expect(checklistHeavy.value >= Dec.zero, isTrue);
      expect(checklistHeavy.value <= Dec.hundred, isTrue);
    });

    test('config survives a serialisation round-trip', () {
      const config = ScoringConfig(
        categoryWeights: {RuleCategory.riskLimit: 40},
        majorViolationCap: 35,
      );
      final restored = ScoringConfig.fromMap(config.toMap());
      expect(restored.weightFor(RuleCategory.riskLimit), 40);
      expect(restored.majorViolationCap, 35);
      // Unset categories fall back to the documented defaults.
      expect(restored.weightFor(RuleCategory.checklist),
          RuleCategory.checklist.defaultWeight);
    });
  });
}

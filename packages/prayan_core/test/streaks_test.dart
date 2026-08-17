import 'package:prayan_core/prayan_core.dart';
import 'package:test/test.dart';

DailyDisciplineRecord day(
  String key, {
  String? score,
  bool major = false,
  int violations = 0,
  int trades = 2,
  List<RuleEvaluation> evaluations = const [],
}) =>
    DailyDisciplineRecord(
      dayKey: key,
      score: score == null ? null : Dec.parse(score),
      hadMajorViolation: major,
      violationCount: violations,
      tradeCount: trades,
      evaluations: evaluations,
    );

RuleEvaluation ruleResult(String ruleId, RuleStatus status, {String? name}) =>
    RuleEvaluation(
      ruleId: ruleId,
      ruleVersionId: '${ruleId}_v1',
      ruleName: name ?? ruleId,
      category: RuleCategory.riskLimit,
      severity: RuleSeverity.warning,
      measure: RuleMeasure.maxRiskPercentPerTrade,
      scope: RuleScope.trade,
      status: status,
      message: '',
    );

void main() {
  group('Clean streak', () {
    test('counts consecutive traded days without a major violation', () {
      final history = StreakCalculator.compute([
        day('2026-03-02', score: '90'),
        day('2026-03-03', score: '95'),
        day('2026-03-04', score: '88'),
      ]);
      expect(history.currentCleanStreak, 3);
      expect(history.bestCleanStreak, 3);
      expect(history.streakStartedOn, '2026-03-02');
    });

    test('a major violation resets the current streak to zero', () {
      final history = StreakCalculator.compute([
        day('2026-03-02', score: '90'),
        day('2026-03-03', score: '95'),
        day('2026-03-04', score: '40', major: true, violations: 2),
      ]);
      expect(history.currentCleanStreak, 0);
      expect(history.streakStartedOn, isNull);
    });

    test('but history and the best streak survive the reset', () {
      final history = StreakCalculator.compute([
        day('2026-03-02', score: '90'),
        day('2026-03-03', score: '95'),
        day('2026-03-04', score: '100'),
        day('2026-03-05', score: '40', major: true, violations: 2),
        day('2026-03-06', score: '85'),
      ]);
      // Streak restarted the day after the violation.
      expect(history.currentCleanStreak, 1);
      // The three-day run before it is not erased.
      expect(history.bestCleanStreak, 3);
      // Neither is the scoring history: (90+95+100+40+85)/5 = 82
      expect(history.lifetimeAverageScore, Dec.parse('82'));
      expect(history.scoredDays, 5);
      expect(history.majorViolationDays, 1);
    });

    test('a minor violation reduces the score but keeps the streak', () {
      final history = StreakCalculator.compute([
        day('2026-03-02', score: '90'),
        day('2026-03-03', score: '62', violations: 1),
        day('2026-03-04', score: '88'),
      ]);
      expect(history.currentCleanStreak, 3);
    });

    test('a no-trade day preserves the streak without inflating it', () {
      final history = StreakCalculator.compute([
        day('2026-03-02', score: '90'),
        day('2026-03-03', score: null, trades: 0),
        day('2026-03-04', score: '95'),
      ]);
      expect(history.currentCleanStreak, 2);
      expect(history.tradingDays, 2);
    });

    test('no-trade days can be counted when the user prefers', () {
      final history = StreakCalculator.compute(
        [
          day('2026-03-02', score: '90'),
          day('2026-03-03', score: null, trades: 0),
          day('2026-03-04', score: '95'),
        ],
        countNoTradeDaysInStreak: true,
      );
      expect(history.currentCleanStreak, 3);
    });

    test('records are sorted before evaluation', () {
      final history = StreakCalculator.compute([
        day('2026-03-04', score: '88'),
        day('2026-03-02', score: '90'),
        day('2026-03-03', score: '40', major: true),
      ]);
      // Chronologically the violation is in the middle, so the live streak is 1.
      expect(history.currentCleanStreak, 1);
    });

    test('an empty history is well defined', () {
      final history = StreakCalculator.compute(const []);
      expect(history.currentCleanStreak, 0);
      expect(history.lifetimeAverageScore, isNull);
      expect(history.weakestRule, isNull);
    });
  });

  group('Rolling scores', () {
    test('average over the most recent scored days', () {
      final records = [
        for (var i = 1; i <= 40; i++)
          day('2026-03-${i.toString().padLeft(2, '0')}',
              score: i <= 10 ? '50' : '90'),
      ];
      final history = StreakCalculator.compute(records);
      // The last 7 records are all 90.
      expect(history.rolling7DayScore, Dec.parse('90'));
      // The last 30 are all 90 too (the 50s are the oldest 10 of 40).
      expect(history.rolling30DayScore, Dec.parse('90'));
      // Over all 40: (10 x 50 + 30 x 90) / 40 = 80
      expect(history.rolling90DayScore, Dec.parse('80'));
      expect(history.lifetimeAverageScore, Dec.parse('80'));
    });

    test('unscored days are skipped rather than counted as zero', () {
      final history = StreakCalculator.compute([
        day('2026-03-02', score: '80'),
        day('2026-03-03', score: null, trades: 0),
        day('2026-03-04', score: '100'),
      ]);
      expect(history.rolling7DayScore, Dec.parse('90'));
    });
  });

  group('Per-rule compliance', () {
    test('accumulates passes and violations across days', () {
      final history = StreakCalculator.compute([
        day('2026-03-02', score: '90', evaluations: [
          ruleResult('r_risk', RuleStatus.passed, name: 'Max risk'),
          ruleResult('r_rr', RuleStatus.violated, name: 'Min R:R'),
        ]),
        day('2026-03-03', score: '90', evaluations: [
          ruleResult('r_risk', RuleStatus.passed, name: 'Max risk'),
          ruleResult('r_rr', RuleStatus.violated, name: 'Min R:R'),
        ]),
        day('2026-03-04', score: '90', evaluations: [
          ruleResult('r_risk', RuleStatus.passed, name: 'Max risk'),
          ruleResult('r_rr', RuleStatus.passed, name: 'Min R:R'),
        ]),
      ]);

      final weakest = history.weakestRule;
      expect(weakest, isNotNull);
      expect(weakest!.ruleName, 'Min R:R');
      expect(weakest.violatedCount, 2);
      expect(weakest.compliancePercent, Dec.parse('33.33'));

      final strongest = history.strongestRule;
      expect(strongest!.ruleName, 'Max risk');
      expect(strongest.compliancePercent, Dec.hundred);
    });

    test('not-applicable outcomes do not enter the denominator', () {
      final history = StreakCalculator.compute([
        day('2026-03-02', score: '90', evaluations: [
          ruleResult('r_a', RuleStatus.passed),
          ruleResult('r_a', RuleStatus.notApplicable),
          ruleResult('r_a', RuleStatus.indeterminate),
        ]),
      ]);
      final stat = history.ruleCompliance.single;
      expect(stat.applicableCount, 1);
      expect(stat.compliancePercent, Dec.hundred);
    });
  });

  group('recordFor', () {
    test('builds a record carrying the full evaluation list', () {
      final evaluations = [
        ruleResult('r_a', RuleStatus.passed),
        ruleResult('r_b', RuleStatus.violated),
      ];
      final score = DisciplineScorer.score(evaluations);
      final record = StreakCalculator.recordFor(
        dayKey: '2026-03-16',
        score: score,
        tradeCount: 2,
        evaluations: evaluations,
      );
      expect(record.evaluations, hasLength(2));
      expect(record.violationCount, 1);
      expect(record.hadMajorViolation, isFalse);
      expect(record.score, score.value);
    });
  });
}

import 'package:prayan_core/prayan_core.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';

/// Finds the evaluation for a given rule id, failing loudly if absent.
RuleEvaluation evaluationFor(List<RuleEvaluation> all, String ruleId) =>
    all.firstWhere((e) => e.ruleId == ruleId,
        orElse: () => throw StateError('no evaluation for $ruleId'));

void main() {
  group('Trade-scoped rules', () {
    test('max risk percent passes inside the limit and fails outside it', () {
      final rule = Fixtures.rule(
        id: 'r_risk',
        name: 'Maximum risk per trade',
        category: RuleCategory.riskLimit,
        measure: RuleMeasure.maxRiskPercentPerTrade,
        threshold: '1',
      );

      // 2 points of risk on 1000 units against 500,000 equity = 0.4%.
      final compliant = RulesEngine.evaluateTrade(
        trade: Fixtures.trade(entry: '100', stop: '98', quantity: '1000'),
        rules: [rule],
        context: Fixtures.dayContext(),
      );
      expect(evaluationFor(compliant, 'r_risk').status, RuleStatus.passed);

      // 10 points of risk on 1000 units = 2%.
      final breach = RulesEngine.evaluateTrade(
        trade: Fixtures.trade(
            entry: '100', stop: '90', target: '130', quantity: '1000'),
        rules: [rule],
        context: Fixtures.dayContext(),
      );
      final result = evaluationFor(breach, 'r_risk');
      expect(result.status, RuleStatus.violated);
      expect(result.observed, '2%');
      expect(result.message, contains('above your 1% limit'));
    });

    test('risk percent is indeterminate without equity, never a free pass', () {
      final trade = Fixtures.trade().copyWith(accountEquityAtOpen: null);
      final results = RulesEngine.evaluateTrade(
        trade: trade,
        rules: [
          Fixtures.rule(
            id: 'r_risk',
            name: 'Maximum risk per trade',
            category: RuleCategory.riskLimit,
            measure: RuleMeasure.maxRiskPercentPerTrade,
            threshold: '1',
          )
        ],
        context: Fixtures.dayContext(),
      );
      expect(evaluationFor(results, 'r_risk').status, RuleStatus.indeterminate);
    });

    test('minimum reward:risk compares planned R:R', () {
      final rule = Fixtures.rule(
        id: 'r_rr',
        name: 'Minimum planned reward:risk',
        category: RuleCategory.rewardRisk,
        measure: RuleMeasure.minPlannedRewardRisk,
        threshold: '2',
      );
      final good = RulesEngine.evaluateTrade(
        trade: Fixtures.trade(entry: '100', stop: '98', target: '105'),
        rules: [rule],
        context: Fixtures.dayContext(),
      );
      expect(evaluationFor(good, 'r_rr').status, RuleStatus.passed);
      expect(evaluationFor(good, 'r_rr').observed, '1:2.5');

      final bad = RulesEngine.evaluateTrade(
        trade: Fixtures.trade(entry: '100', stop: '98', target: '103'),
        rules: [rule],
        context: Fixtures.dayContext(),
      );
      expect(evaluationFor(bad, 'r_rr').status, RuleStatus.violated);
      expect(evaluationFor(bad, 'r_rr').message, contains('below your 1:2'));
    });

    test('stop-loss required catches a missing stop', () {
      final rule = Fixtures.rule(
        id: 'r_stop',
        name: 'Stop defined before entry',
        category: RuleCategory.stopLoss,
        severity: RuleSeverity.major,
        measure: RuleMeasure.stopLossRequired,
      );
      final results = RulesEngine.evaluateTrade(
        trade: Fixtures.trade(stop: null),
        rules: [rule],
        context: Fixtures.dayContext(),
      );
      final evaluation = evaluationFor(results, 'r_stop');
      expect(evaluation.status, RuleStatus.violated);
      expect(evaluation.isMajorViolation, isTrue);
    });

    test('approved setup checks the strategy list', () {
      final rule = Fixtures.rule(
        id: 'r_setup',
        name: 'Approved setups only',
        category: RuleCategory.approvedSetup,
        measure: RuleMeasure.approvedStrategyOnly,
      );
      final approved = Fixtures.strategy(id: 's_ok', name: 'Pullback');
      final banned =
          Fixtures.strategy(id: 's_no', name: 'Impulse', approved: false);
      final context = Fixtures.dayContext(strategies: [approved, banned]);

      final ok = RulesEngine.evaluateTrade(
        trade: Fixtures.trade(strategyId: 's_ok'),
        rules: [rule],
        context: context,
      );
      expect(evaluationFor(ok, 'r_setup').status, RuleStatus.passed);

      final notOk = RulesEngine.evaluateTrade(
        trade: Fixtures.trade(strategyId: 's_no'),
        rules: [rule],
        context: context,
      );
      expect(evaluationFor(notOk, 'r_setup').status, RuleStatus.violated);
      expect(evaluationFor(notOk, 'r_setup').message,
          contains('not on your approved list'));
    });

    test('checklist completion is not applicable when none was presented', () {
      final rule = Fixtures.rule(
        id: 'r_check',
        name: 'Complete the pre-trade checklist',
        category: RuleCategory.checklist,
        measure: RuleMeasure.checklistCompletion,
      );
      final results = RulesEngine.evaluateTrade(
        trade: Fixtures.trade(
            checklistPresented: const [], checklistCompleted: const []),
        rules: [rule],
        context: Fixtures.dayContext(),
      );
      expect(
          evaluationFor(results, 'r_check').status, RuleStatus.notApplicable);
    });

    test('partial checklist completion is a violation', () {
      final results = RulesEngine.evaluateTrade(
        trade: Fixtures.trade(
          checklistPresented: const ['a', 'b', 'c', 'd'],
          checklistCompleted: const ['a', 'b'],
        ),
        rules: [
          Fixtures.rule(
            id: 'r_check',
            name: 'Complete the pre-trade checklist',
            category: RuleCategory.checklist,
            measure: RuleMeasure.checklistCompletion,
          )
        ],
        context: Fixtures.dayContext(),
      );
      final evaluation = evaluationFor(results, 'r_check');
      expect(evaluation.status, RuleStatus.violated);
      expect(evaluation.observed, '50%');
    });

    test('notes and screenshot requirements', () {
      final rules = [
        Fixtures.rule(
          id: 'r_notes',
          name: 'Record your reasoning',
          category: RuleCategory.journalQuality,
          measure: RuleMeasure.notesRequired,
        ),
        Fixtures.rule(
          id: 'r_shot',
          name: 'Attach a screenshot',
          category: RuleCategory.journalQuality,
          measure: RuleMeasure.screenshotRequired,
        ),
      ];
      final results = RulesEngine.evaluateTrade(
        trade: Fixtures.trade(entryReason: null, attachmentIds: const []),
        rules: rules,
        context: Fixtures.dayContext(),
      );
      expect(evaluationFor(results, 'r_notes').status, RuleStatus.violated);
      expect(evaluationFor(results, 'r_shot').status, RuleStatus.violated);
    });

    test('adding to a losing long position is detected', () {
      final opened = Fixtures.baseTime;
      final rule = Fixtures.rule(
        id: 'r_add',
        name: 'Never add to a losing position',
        category: RuleCategory.riskLimit,
        measure: RuleMeasure.noAddingToLosers,
      );

      final averagedDown = Fixtures.trade(executions: [
        TradeExecution(
          id: 'e1',
          kind: ExecutionKind.entry,
          price: Dec.parse('100'),
          quantity: Dec.parse('50'),
          timestampUtc: opened,
        ),
        TradeExecution(
          id: 'e2',
          kind: ExecutionKind.entry,
          price: Dec.parse('95'),
          quantity: Dec.parse('50'),
          timestampUtc: opened.add(const Duration(minutes: 5)),
        ),
      ]);
      expect(
          evaluationFor(
                  RulesEngine.evaluateTrade(
                    trade: averagedDown,
                    rules: [rule],
                    context: Fixtures.dayContext(),
                  ),
                  'r_add')
              .status,
          RuleStatus.violated);

      // Scaling into strength is not adding to a loser.
      final scaledUp = Fixtures.trade(executions: [
        TradeExecution(
          id: 'e1',
          kind: ExecutionKind.entry,
          price: Dec.parse('100'),
          quantity: Dec.parse('50'),
          timestampUtc: opened,
        ),
        TradeExecution(
          id: 'e2',
          kind: ExecutionKind.entry,
          price: Dec.parse('103'),
          quantity: Dec.parse('50'),
          timestampUtc: opened.add(const Duration(minutes: 5)),
        ),
      ]);
      expect(
          evaluationFor(
                  RulesEngine.evaluateTrade(
                    trade: scaledUp,
                    rules: [rule],
                    context: Fixtures.dayContext(),
                  ),
                  'r_add')
              .status,
          RuleStatus.passed);
    });

    test('a planned-but-not-taken trade cannot break execution rules', () {
      final results = RulesEngine.evaluateTrade(
        trade: Fixtures.trade(
            status: TradeStatus.cancelled, stop: null, exit: null),
        rules: [
          Fixtures.rule(
            id: 'r_stop',
            name: 'Stop defined before entry',
            category: RuleCategory.stopLoss,
            severity: RuleSeverity.major,
            measure: RuleMeasure.stopLossRequired,
          )
        ],
        context: Fixtures.dayContext(),
      );
      expect(evaluationFor(results, 'r_stop').status, RuleStatus.notApplicable);
    });

    test('a paused rule is not applicable', () {
      final results = RulesEngine.evaluateTrade(
        trade: Fixtures.trade(stop: null),
        rules: [
          Fixtures.rule(
            id: 'r_stop',
            name: 'Stop defined before entry',
            category: RuleCategory.stopLoss,
            measure: RuleMeasure.stopLossRequired,
            isActive: false,
          )
        ],
        context: Fixtures.dayContext(),
      );
      expect(evaluationFor(results, 'r_stop').status, RuleStatus.notApplicable);
    });

    test('session restriction treats its session list as the allowed set', () {
      final rule = Fixtures.rule(
        id: 'r_session',
        name: 'Trade the open only',
        category: RuleCategory.custom,
        measure: RuleMeasure.sessionRestriction,
        sessions: [MarketSession.open],
      );
      final inSession = Fixtures.trade().copyWith(session: MarketSession.open);
      final outOfSession =
          Fixtures.trade().copyWith(session: MarketSession.midday);

      expect(
          evaluationFor(
                  RulesEngine.evaluateTrade(
                      trade: inSession,
                      rules: [rule],
                      context: Fixtures.dayContext()),
                  'r_session')
              .status,
          RuleStatus.passed);
      expect(
          evaluationFor(
                  RulesEngine.evaluateTrade(
                      trade: outOfSession,
                      rules: [rule],
                      context: Fixtures.dayContext()),
                  'r_session')
              .status,
          RuleStatus.violated);
    });
  });

  group('Rule versioning', () {
    test('a historical trade is judged by the version live at the time', () {
      final marchTrade = Fixtures.trade(
        openedAt: DateTime.utc(2026, 3, 2, 10),
        dayKey: '2026-03-02',
        entry: '100',
        stop: '98',
        quantity: '1000', // 0.4% of 500,000
      );

      // v1 allowed 0.25%; v2, effective from April, allows 1%.
      final v1 = RuleVersion(
        id: 'r_risk_v1',
        ruleId: 'r_risk',
        version: 1,
        name: 'Maximum risk per trade',
        description: 'v1',
        category: RuleCategory.riskLimit,
        severity: RuleSeverity.warning,
        measure: RuleMeasure.maxRiskPercentPerTrade,
        threshold: Dec.parse('0.25'),
        effectiveFromUtc: DateTime.utc(2026, 1, 1),
        effectiveToUtc: DateTime.utc(2026, 4, 1),
      );
      final rule = Rule(
        id: 'r_risk',
        userId: 'user_1',
        history: [v1],
        current: RuleVersion(
          id: 'r_risk_v2',
          ruleId: 'r_risk',
          version: 2,
          name: 'Maximum risk per trade',
          description: 'v2',
          category: RuleCategory.riskLimit,
          severity: RuleSeverity.warning,
          measure: RuleMeasure.maxRiskPercentPerTrade,
          threshold: Dec.one,
          effectiveFromUtc: DateTime.utc(2026, 4, 1),
        ),
      );

      final marchResult = evaluationFor(
        RulesEngine.evaluateTrade(
            trade: marchTrade,
            rules: [rule],
            context: Fixtures.dayContext(dayKey: '2026-03-02')),
        'r_risk',
      );
      // Judged against the 0.25% limit that was live in March.
      expect(marchResult.status, RuleStatus.violated);
      expect(marchResult.ruleVersionId, 'r_risk_v1');

      final aprilResult = evaluationFor(
        RulesEngine.evaluateTrade(
            trade: Fixtures.trade(
              openedAt: DateTime.utc(2026, 4, 15, 10),
              dayKey: '2026-04-15',
              entry: '100',
              stop: '98',
              quantity: '1000',
            ),
            rules: [rule],
            context: Fixtures.dayContext(dayKey: '2026-04-15')),
        'r_risk',
      );
      expect(aprilResult.status, RuleStatus.passed);
      expect(aprilResult.ruleVersionId, 'r_risk_v2');
    });

    test('a rule created after a trade never judges it', () {
      final rule = Fixtures.rule(
        id: 'r_new',
        name: 'New rule',
        category: RuleCategory.custom,
        measure: RuleMeasure.notesRequired,
        effectiveFrom: DateTime.utc(2026, 6, 1),
      );
      final results = RulesEngine.evaluateTrade(
        trade: Fixtures.trade(
            openedAt: DateTime.utc(2026, 3, 16), entryReason: null),
        rules: [rule],
        context: Fixtures.dayContext(),
      );
      expect(results.where((e) => e.ruleId == 'r_new'), isEmpty);
    });
  });

  group('Day-scoped rules', () {
    List<Rule> dayRules() => [
          Fixtures.rule(
            id: 'r_count',
            name: 'Maximum trades per day',
            category: RuleCategory.dailyLimits,
            measure: RuleMeasure.maxTradesPerDay,
            threshold: '3',
          ),
          Fixtures.rule(
            id: 'r_dayloss',
            name: 'Daily loss stop',
            category: RuleCategory.dailyLimits,
            severity: RuleSeverity.major,
            measure: RuleMeasure.maxDailyLossR,
            threshold: '2',
          ),
        ];

    test('trade count limit', () {
      final trades = [
        for (var i = 0; i < 4; i++)
          Fixtures.trade(
            id: 't$i',
            openedAt: Fixtures.baseTime.add(Duration(minutes: i * 10)),
          ),
      ];
      final report = RulesEngine.evaluateDay(
        trades: trades,
        rules: dayRules(),
        context: Fixtures.dayContext(),
      );
      final count = evaluationFor(report.dayLevel, 'r_count');
      expect(count.status, RuleStatus.violated);
      expect(count.observed, '4');
    });

    test('daily loss stop in R', () {
      // Two full -1R losses reaches the 2R stop exactly.
      final trades = [
        for (var i = 0; i < 2; i++)
          Fixtures.trade(
            id: 't$i',
            entry: '100',
            stop: '98',
            target: '104',
            exit: '98',
            quantity: '100',
            openedAt: Fixtures.baseTime.add(Duration(minutes: i * 10)),
          ),
      ];
      final report = RulesEngine.evaluateDay(
        trades: trades,
        rules: dayRules(),
        context: Fixtures.dayContext(),
      );
      // Exactly at the limit is not yet over it.
      expect(evaluationFor(report.dayLevel, 'r_dayloss').status,
          RuleStatus.passed);

      final worse = [
        ...trades,
        Fixtures.trade(
          id: 't2',
          entry: '100',
          stop: '98',
          target: '104',
          exit: '98',
          quantity: '100',
          openedAt: Fixtures.baseTime.add(const Duration(minutes: 30)),
        ),
      ];
      final worseReport = RulesEngine.evaluateDay(
        trades: worse,
        rules: dayRules(),
        context: Fixtures.dayContext(),
      );
      final breach = evaluationFor(worseReport.dayLevel, 'r_dayloss');
      expect(breach.status, RuleStatus.violated);
      expect(breach.isMajorViolation, isTrue);
    });

    test('no trading after the daily stop is reached', () {
      final rules = [
        ...dayRules(),
        Fixtures.rule(
          id: 'r_after',
          name: 'No trading after the daily stop',
          category: RuleCategory.dailyLimits,
          severity: RuleSeverity.major,
          measure: RuleMeasure.noTradingAfterDailyStop,
        ),
      ];

      Trade losing(int i) => Fixtures.trade(
            id: 't$i',
            entry: '100',
            stop: '98',
            target: '104',
            exit: '98',
            quantity: '100',
            openedAt: Fixtures.baseTime.add(Duration(minutes: i * 10)),
          );

      // Two losses reach the 2R stop; the third is taken after it.
      final report = RulesEngine.evaluateDay(
        trades: [losing(0), losing(1), losing(2)],
        rules: rules,
        context: Fixtures.dayContext(),
      );
      final after = evaluationFor(report.dayLevel, 'r_after');
      expect(after.status, RuleStatus.violated);
      expect(after.message, contains('after reaching your daily stop'));

      // Stopping at the limit passes.
      final disciplined = RulesEngine.evaluateDay(
        trades: [losing(0), losing(1)],
        rules: rules,
        context: Fixtures.dayContext(),
      );
      expect(evaluationFor(disciplined.dayLevel, 'r_after').status,
          RuleStatus.passed);
    });

    test('daily review completion', () {
      final rule = Fixtures.rule(
        id: 'r_review',
        name: 'Complete the daily review',
        category: RuleCategory.journalQuality,
        measure: RuleMeasure.dailyReviewCompleted,
      );
      expect(
        evaluationFor(
                RulesEngine.evaluateDay(
                  trades: [Fixtures.trade()],
                  rules: [rule],
                  context: Fixtures.dayContext(dailyReviewCompleted: true),
                ).dayLevel,
                'r_review')
            .status,
        RuleStatus.passed,
      );
      expect(
        evaluationFor(
                RulesEngine.evaluateDay(
                  trades: [Fixtures.trade()],
                  rules: [rule],
                  context: Fixtures.dayContext(),
                ).dayLevel,
                'r_review')
            .status,
        RuleStatus.violated,
      );
    });

    test('a manual custom rule is indeterminate until self-reported', () {
      final rule = Fixtures.rule(
        id: 'r_manual',
        name: 'No trading on news days',
        category: RuleCategory.custom,
        measure: RuleMeasure.manualCustom,
      );
      expect(
        evaluationFor(
                RulesEngine.evaluateDay(
                  trades: [Fixtures.trade()],
                  rules: [rule],
                  context: Fixtures.dayContext(),
                ).dayLevel,
                'r_manual')
            .status,
        RuleStatus.indeterminate,
      );
      expect(
        evaluationFor(
                RulesEngine.evaluateDay(
                  trades: [Fixtures.trade()],
                  rules: [rule],
                  context: Fixtures.dayContext(
                      manualCompliance: {'r_manual': false}),
                ).dayLevel,
                'r_manual')
            .status,
        RuleStatus.violated,
      );
    });

    test('week-scoped rules need week context', () {
      final rule = Fixtures.rule(
        id: 'r_week',
        name: 'Maximum weekly loss',
        category: RuleCategory.dailyLimits,
        severity: RuleSeverity.major,
        measure: RuleMeasure.maxWeeklyLossR,
        threshold: '5',
      );
      expect(
        evaluationFor(
                RulesEngine.evaluateDay(
                  trades: [Fixtures.trade()],
                  rules: [rule],
                  context: Fixtures.dayContext(),
                ).dayLevel,
                'r_week')
            .status,
        RuleStatus.indeterminate,
      );
      expect(
        evaluationFor(
                RulesEngine.evaluateDay(
                  trades: [Fixtures.trade()],
                  rules: [rule],
                  context: Fixtures.dayContext(weekTotalR: '-6'),
                ).dayLevel,
                'r_week')
            .status,
        RuleStatus.violated,
      );
    });

    test('a weekday-restricted rule does not apply on other days', () {
      // 2026-03-16 is a Monday.
      final rule = Fixtures.rule(
        id: 'r_friday',
        name: 'No Friday trading',
        category: RuleCategory.custom,
        measure: RuleMeasure.maxTradesPerDay,
        threshold: '0',
        weekdays: [DateTime.friday],
      );
      final report = RulesEngine.evaluateDay(
        trades: [Fixtures.trade()],
        rules: [rule],
        context: Fixtures.dayContext(dayKey: '2026-03-16'),
      );
      expect(evaluationFor(report.dayLevel, 'r_friday').status,
          RuleStatus.notApplicable);
    });
  });
}

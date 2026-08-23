import 'package:prayan_core/prayan_core.dart';
import 'package:test/test.dart';

/// End-to-end verification of the worked example in the product brief, §39.
///
/// > User sets ₹5,00,000 account equity, max risk 1% per trade, minimum R:R
/// > 1:2, maximum 3 trades/day, daily loss stop 2R and approved strategies
/// > "Breakout" and "Pullback".
/// >
/// > Trade 1: Pullback, 0.8% planned risk, 1:2.4 planned R:R, checklist
/// > completed, loses -1R. This should still receive a high discipline score.
/// > Trade 2: Breakout, 1% risk, 1:2.1 R:R, wins +2R, rules followed. High
/// > discipline score.
/// > Trade 3: user enters an unapproved impulse setup at 1.8% risk. Even if it
/// > wins, the app should flag the process violations and reduce the discipline
/// > score. If "risk >1.5%" is configured as a major violation, reset the
/// > clean-discipline streak while preserving historical data.
void main() {
  final openedAt = DateTime.utc(2026, 3, 16, 4, 0); // 09:30 IST
  const dayKey = '2026-03-16';

  final account = TradingAccount(
    id: 'acct_1',
    userId: 'user_1',
    name: 'Primary',
    currency: Currency.inr,
    startingEquity: Dec.parse('500000'),
    currentEquity: Dec.parse('500000'),
    createdAtUtc: openedAt.subtract(const Duration(days: 60)),
  );

  const pullback = Strategy(
      id: 's_pullback', userId: 'user_1', name: 'Pullback', isApproved: true);
  const breakout = Strategy(
      id: 's_breakout', userId: 'user_1', name: 'Breakout', isApproved: true);
  const impulse = Strategy(
      id: 's_impulse', userId: 'user_1', name: 'Impulse', isApproved: false);

  final checklist = ['c1', 'c2', 'c3', 'c4', 'c5'];

  Rule rule({
    required String id,
    required String name,
    required RuleCategory category,
    required RuleMeasure measure,
    RuleSeverity severity = RuleSeverity.warning,
    String? threshold,
  }) =>
      Rule(
        id: id,
        userId: 'user_1',
        current: RuleVersion(
          id: '${id}_v1',
          ruleId: id,
          version: 1,
          name: name,
          description: name,
          category: category,
          severity: severity,
          measure: measure,
          threshold: threshold == null ? null : Dec.parse(threshold),
          effectiveFromUtc: openedAt.subtract(const Duration(days: 60)),
        ),
      );

  final rules = <Rule>[
    rule(
      id: 'r_risk_1pct',
      name: 'Maximum risk per trade',
      category: RuleCategory.riskLimit,
      measure: RuleMeasure.maxRiskPercentPerTrade,
      threshold: '1',
    ),
    // The brief's "if risk >1.5% is configured as a major violation".
    rule(
      id: 'r_risk_major',
      name: 'Hard risk ceiling',
      category: RuleCategory.riskLimit,
      severity: RuleSeverity.major,
      measure: RuleMeasure.maxRiskPercentPerTrade,
      threshold: '1.5',
    ),
    rule(
      id: 'r_stop',
      name: 'Stop defined before entry',
      category: RuleCategory.stopLoss,
      severity: RuleSeverity.major,
      measure: RuleMeasure.stopLossRequired,
    ),
    rule(
      id: 'r_rr',
      name: 'Minimum planned reward:risk',
      category: RuleCategory.rewardRisk,
      measure: RuleMeasure.minPlannedRewardRisk,
      threshold: '2',
    ),
    rule(
      id: 'r_setup',
      name: 'Approved setups only',
      category: RuleCategory.approvedSetup,
      measure: RuleMeasure.approvedStrategyOnly,
    ),
    rule(
      id: 'r_checklist',
      name: 'Complete the pre-trade checklist',
      category: RuleCategory.checklist,
      measure: RuleMeasure.checklistCompletion,
    ),
    rule(
      id: 'r_count',
      name: 'Maximum trades per day',
      category: RuleCategory.dailyLimits,
      measure: RuleMeasure.maxTradesPerDay,
      threshold: '3',
    ),
    rule(
      id: 'r_dayloss',
      name: 'Daily loss stop',
      category: RuleCategory.dailyLimits,
      severity: RuleSeverity.major,
      measure: RuleMeasure.maxDailyLossR,
      threshold: '2',
    ),
  ];

  /// Builds one of the scenario's trades.
  Trade buildTrade({
    required String id,
    required String strategyId,
    required String entry,
    required String stop,
    required String target,
    required String exit,
    required String quantity,
    required int minuteOffset,
    List<String> completedChecklist = const ['c1', 'c2', 'c3', 'c4', 'c5'],
  }) {
    final opened = openedAt.add(Duration(minutes: minuteOffset));
    return Trade(
      id: id,
      userId: 'user_1',
      accountId: 'acct_1',
      symbol: 'RELIANCE',
      assetClass: AssetClass.equity,
      direction: TradeDirection.long,
      strategyId: strategyId,
      status: TradeStatus.closed,
      openedAtUtc: opened,
      closedAtUtc: opened.add(const Duration(minutes: 30)),
      tradingDayKey: dayKey,
      plannedEntryPrice: Dec.parse(entry),
      stopLossPrice: Dec.parse(stop),
      targetPrice: Dec.parse(target),
      multiplier: Dec.one,
      plannedQuantity: Dec.parse(quantity),
      accountEquityAtOpen: Dec.parse('500000'),
      entryReason: 'Setup taken per plan.',
      presentedChecklistItemIds: checklist,
      completedChecklistItemIds: completedChecklist,
      attachmentIds: const ['shot'],
      executions: [
        TradeExecution(
          id: '${id}_e',
          kind: ExecutionKind.entry,
          price: Dec.parse(entry),
          quantity: Dec.parse(quantity),
          timestampUtc: opened,
        ),
        TradeExecution(
          id: '${id}_x',
          kind: ExecutionKind.exit,
          price: Dec.parse(exit),
          quantity: Dec.parse(quantity),
          timestampUtc: opened.add(const Duration(minutes: 30)),
        ),
      ],
      createdAtUtc: opened,
      updatedAtUtc: opened,
    );
  }

  // Trade 1: Pullback. Risk 4/unit x 1000 = ₹4,000 = 0.8% of 5,00,000.
  // Reward 9.6/unit -> planned 1:2.4. Exits at the stop for -1R.
  final trade1 = buildTrade(
    id: 'trade_1',
    strategyId: 's_pullback',
    entry: '100',
    stop: '96',
    target: '109.6',
    exit: '96',
    quantity: '1000',
    minuteOffset: 0,
  );

  // Trade 2: Breakout. Risk 5/unit x 1000 = ₹5,000 = 1.0%.
  // Reward 10.5/unit -> planned 1:2.1. Exits at +2R.
  final trade2 = buildTrade(
    id: 'trade_2',
    strategyId: 's_breakout',
    entry: '200',
    stop: '195',
    target: '210.5',
    exit: '210',
    quantity: '1000',
    minuteOffset: 60,
  );

  // Trade 3: unapproved impulse setup. Risk 9/unit x 1000 = ₹9,000 = 1.8%.
  // Planned 1:2 so the R:R rule still passes; it wins anyway.
  final trade3 = buildTrade(
    id: 'trade_3',
    strategyId: 's_impulse',
    entry: '300',
    stop: '291',
    target: '318',
    exit: '320',
    quantity: '1000',
    minuteOffset: 120,
  );

  final context = DayContext(
    tradingDayKey: dayKey,
    account: account,
    strategiesById: {
      pullback.id: pullback,
      breakout.id: breakout,
      impulse.id: impulse,
    },
    dailyReviewCompleted: true,
  );

  DisciplineScore scoreForTrade(Trade trade) => DisciplineScorer.score(
        RulesEngine.evaluateTrade(trade: trade, rules: rules, context: context),
      );

  group('Trade arithmetic matches the brief', () {
    test('trade 1 risks 0.8% at a planned 1:2.4 and loses exactly 1R', () {
      final metrics = TradeCalculator.compute(trade1);
      expect(metrics.plannedRisk, Dec.parse('4000'));
      expect(metrics.plannedRiskPercent, Dec.parse('0.8'));
      expect(metrics.plannedRewardRisk, Dec.parse('2.4'));
      expect(metrics.realizedR, Dec.parse('-1'));
      expect(metrics.outcome, TradeOutcome.loss);
    });

    test('trade 2 risks 1.0% at a planned 1:2.1 and wins 2R', () {
      final metrics = TradeCalculator.compute(trade2);
      expect(metrics.plannedRisk, Dec.parse('5000'));
      expect(metrics.plannedRiskPercent, Dec.one);
      expect(metrics.plannedRewardRisk, Dec.parse('2.1'));
      expect(metrics.realizedR, Dec.parse('2'));
      expect(metrics.outcome, TradeOutcome.win);
    });

    test('trade 3 risks 1.8% and wins despite the process breach', () {
      final metrics = TradeCalculator.compute(trade3);
      expect(metrics.plannedRiskPercent, Dec.parse('1.8'));
      expect(metrics.outcome, TradeOutcome.win);
      expect(metrics.realizedR! > Dec.fromInt(2), isTrue);
    });
  });

  group('Discipline scores match the brief\'s expectations', () {
    test('trade 1 scores highly despite losing money', () {
      final score = scoreForTrade(trade1);
      expect(score.value, Dec.hundred);
      expect(score.violations, isEmpty);
    });

    test('trade 2 scores highly', () {
      final score = scoreForTrade(trade2);
      expect(score.value, Dec.hundred);
    });

    test('the losing trade scores at least as well as the winning one', () {
      // The brief's central claim: process, not profit.
      expect(
          scoreForTrade(trade1).value >= scoreForTrade(trade2).value, isTrue);
    });

    test('trade 3 is flagged and scored down even though it won', () {
      final score = scoreForTrade(trade3);

      expect(score.value < scoreForTrade(trade2).value, isTrue,
          reason: 'a rule-breaking winner must not outscore a clean trade');

      final violatedRules = score.violations.map((v) => v.ruleId).toSet();
      expect(violatedRules, contains('r_risk_1pct'));
      expect(violatedRules, contains('r_risk_major'));
      expect(violatedRules, contains('r_setup'));

      // "risk >1.5% configured as a major violation"
      expect(
          score.majorViolations.map((v) => v.ruleId), contains('r_risk_major'));
      expect(score.wasCappedByMajorViolation || score.value <= Dec.fromInt(60),
          isTrue);
    });

    test('the audit trail explains exactly why trade 3 lost points', () {
      final score = scoreForTrade(trade3);
      final riskViolation =
          score.violations.firstWhere((v) => v.ruleId == 'r_risk_1pct');
      expect(riskViolation.observed, '1.8%');
      expect(riskViolation.threshold, '1%');
      expect(riskViolation.message, contains('above your 1% limit'));

      final setupViolation =
          score.violations.firstWhere((v) => v.ruleId == 'r_setup');
      expect(setupViolation.message, contains('Impulse'));
      expect(setupViolation.message, contains('not on your approved list'));

      expect(score.summary, contains('Your score is'));
    });
  });

  group('Day-level outcome', () {
    test('the day is scored, capped and fully explained', () {
      final report = RulesEngine.evaluateDay(
        trades: [trade1, trade2, trade3],
        rules: rules,
        context: context,
      );
      final score = DisciplineScorer.score(report.all);

      expect(report.hasMajorViolation, isTrue);
      // Three trades against a limit of three is compliant.
      expect(report.dayLevel.firstWhere((e) => e.ruleId == 'r_count').status,
          RuleStatus.passed);
      // The day finished profitable, so the loss stop was never hit.
      expect(report.dayLevel.firstWhere((e) => e.ruleId == 'r_dayloss').status,
          RuleStatus.passed);

      expect(score.value <= Dec.fromInt(60), isTrue,
          reason: 'a major violation caps the day');
      expect(score.rulesApplicable, greaterThan(0));
    });

    test('the day is profitable yet the score is capped: process over P&L', () {
      final metrics = PerformanceCalculator.compute([trade1, trade2, trade3]);
      expect(metrics.netPnl.isPositive, isTrue);

      final report = RulesEngine.evaluateDay(
        trades: [trade1, trade2, trade3],
        rules: rules,
        context: context,
      );
      final score = DisciplineScorer.score(report.all);
      expect(score.value <= Dec.fromInt(60), isTrue);
    });
  });

  group('Streak reset preserves history', () {
    test('the major violation zeroes the streak but keeps prior scores', () {
      final report = RulesEngine.evaluateDay(
        trades: [trade1, trade2, trade3],
        rules: rules,
        context: context,
      );
      final todayScore = DisciplineScorer.score(report.all);

      final history = StreakCalculator.compute([
        DailyDisciplineRecord(
            dayKey: '2026-03-11',
            score: Dec.parse('95'),
            hadMajorViolation: false,
            violationCount: 0,
            tradeCount: 2),
        DailyDisciplineRecord(
            dayKey: '2026-03-12',
            score: Dec.parse('100'),
            hadMajorViolation: false,
            violationCount: 0,
            tradeCount: 3),
        DailyDisciplineRecord(
            dayKey: '2026-03-13',
            score: Dec.parse('90'),
            hadMajorViolation: false,
            violationCount: 1,
            tradeCount: 2),
        StreakCalculator.recordFor(
          dayKey: dayKey,
          score: todayScore,
          tradeCount: 3,
          evaluations: report.all,
        ),
      ]);

      // Reset to zero...
      expect(history.currentCleanStreak, 0);
      // ...but nothing historical was erased.
      expect(history.bestCleanStreak, 3);
      expect(history.scoredDays, 4);
      expect(history.majorViolationDays, 1);
      expect(history.lifetimeAverageScore, isNotNull);
      expect(history.tradingDays, 4);
    });
  });

  group('Coaching stays factual and kind', () {
    test('the day produces coaching grounded only in computed facts', () {
      final report = RulesEngine.evaluateDay(
        trades: [trade1, trade2, trade3],
        rules: rules,
        context: context,
      );
      final score = DisciplineScorer.score(report.all);
      final metrics = PerformanceCalculator.compute([trade1, trade2, trade3]);

      final facts = CoachingFacts.build(
        dayKey: dayKey,
        netPnlFormatted:
            Money(metrics.netPnl, Currency.inr).format(showSign: true),
        totalR: metrics.totalR,
        tradesTaken: 3,
        winCount: metrics.winCount,
        lossCount: metrics.lossCount,
        breakevenCount: metrics.breakevenCount,
        score: score,
        history: StreakCalculator.compute(const []),
        emotionsToday: const [EmotionTag.calm],
        reachedDailyStop: false,
        tradedAfterDailyStop: false,
        dayWasProfitable: metrics.netPnl.isPositive,
      );

      expect(facts.isUndisciplinedWin, isTrue);
      expect(facts.majorViolationNames, isNotEmpty);
      // Data minimisation: no symbol, price or size leaves the device.
      final payload = facts.toMap().toString();
      expect(payload.contains('RELIANCE'), isFalse);
      expect(payload.contains('500000'), isFalse);

      final insights = InsightEngine.forDay(facts);
      expect(insights, isNotEmpty);
      final headline = InsightEngine.headline(facts)!;
      expect(headline.title, isNotEmpty);

      // Tone check: never shaming, never pushing more trading.
      for (final insight in insights) {
        final text = '${insight.title} ${insight.body}'.toLowerCase();
        for (final banned in const [
          'stupid',
          'idiot',
          'failure',
          'loser',
          'shame',
          'trade more',
          'make it back',
          'recover your loss',
        ]) {
          expect(text.contains(banned), isFalse,
              reason: '"$banned" must never appear in coaching copy');
        }
      }
    });

    test('a clean losing day is praised, not scolded', () {
      final report = RulesEngine.evaluateDay(
        trades: [trade1],
        rules: rules,
        context: context,
      );
      final score = DisciplineScorer.score(report.all);
      final metrics = PerformanceCalculator.compute([trade1]);

      final facts = CoachingFacts.build(
        dayKey: dayKey,
        netPnlFormatted:
            Money(metrics.netPnl, Currency.inr).format(showSign: true),
        totalR: metrics.totalR,
        tradesTaken: 1,
        winCount: 0,
        lossCount: 1,
        breakevenCount: 0,
        score: score,
        history: StreakCalculator.compute(const []),
        emotionsToday: const [EmotionTag.calm],
        reachedDailyStop: false,
        tradedAfterDailyStop: false,
        dayWasProfitable: false,
      );

      expect(facts.isDisciplinedLoss, isTrue);
      final insights = InsightEngine.forDay(facts);
      final disciplined =
          insights.firstWhere((i) => i.id == 'disciplined_loss');
      expect(disciplined.tone, InsightTone.affirming);
      expect(disciplined.body, contains('broke none of your rules'));
    });
  });
}

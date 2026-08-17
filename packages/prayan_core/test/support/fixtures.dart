import 'package:prayan_core/prayan_core.dart';

/// Shared builders so tests describe only what they are actually asserting.
class Fixtures {
  static final DateTime baseTime = DateTime.utc(2026, 3, 16, 9, 30);

  static TradingAccount account({
    String equity = '500000',
    Currency currency = Currency.inr,
  }) =>
      TradingAccount(
        id: 'acct_1',
        userId: 'user_1',
        name: 'Primary',
        currency: currency,
        startingEquity: Dec.parse(equity),
        currentEquity: Dec.parse(equity),
        createdAtUtc: baseTime.subtract(const Duration(days: 30)),
      );

  static Strategy strategy({
    String id = 'strat_pullback',
    String name = 'Pullback',
    bool approved = true,
  }) =>
      Strategy(id: id, userId: 'user_1', name: name, isApproved: approved);

  /// A closed trade described in plain terms.
  ///
  /// [entry], [stop], [target] and [exit] are decimal strings so tests never
  /// introduce the floating-point error the domain exists to avoid.
  static Trade trade({
    String id = 'trade_1',
    TradeDirection direction = TradeDirection.long,
    String entry = '100',
    String? stop = '98',
    String? target = '104',
    String? exit = '104',
    String quantity = '100',
    String fees = '0',
    String? strategyId = 'strat_pullback',
    String equity = '500000',
    String multiplier = '1',
    TradeStatus status = TradeStatus.closed,
    DateTime? openedAt,
    Duration held = const Duration(minutes: 45),
    List<String> checklistPresented = const ['c1', 'c2', 'c3', 'c4'],
    List<String> checklistCompleted = const ['c1', 'c2', 'c3', 'c4'],
    String? entryReason = 'Pullback into the 20 EMA with trend intact.',
    List<String> attachmentIds = const ['shot_1'],
    EmotionTag emotionBefore = EmotionTag.calm,
    List<TradeExecution>? executions,
    String dayKey = '2026-03-16',
  }) {
    final opened = openedAt ?? baseTime;
    final fills = executions ??
        <TradeExecution>[
          TradeExecution(
            id: '${id}_e1',
            kind: ExecutionKind.entry,
            price: Dec.parse(entry),
            quantity: Dec.parse(quantity),
            timestampUtc: opened,
            fees: Dec.parse(fees),
          ),
          if (exit != null)
            TradeExecution(
              id: '${id}_x1',
              kind: ExecutionKind.exit,
              price: Dec.parse(exit),
              quantity: Dec.parse(quantity),
              timestampUtc: opened.add(held),
            ),
        ];

    return Trade(
      id: id,
      userId: 'user_1',
      accountId: 'acct_1',
      symbol: 'RELIANCE',
      assetClass: AssetClass.equity,
      direction: direction,
      strategyId: strategyId,
      status: status,
      openedAtUtc: opened,
      closedAtUtc: status == TradeStatus.closed ? opened.add(held) : null,
      tradingDayKey: dayKey,
      plannedEntryPrice: Dec.parse(entry),
      stopLossPrice: stop == null ? null : Dec.parse(stop),
      targetPrice: target == null ? null : Dec.parse(target),
      multiplier: Dec.parse(multiplier),
      plannedQuantity: Dec.parse(quantity),
      accountEquityAtOpen: Dec.parse(equity),
      executions: fills,
      entryReason: entryReason,
      attachmentIds: attachmentIds,
      emotionBefore: emotionBefore,
      presentedChecklistItemIds: checklistPresented,
      completedChecklistItemIds: checklistCompleted,
      createdAtUtc: opened,
      updatedAtUtc: opened,
    );
  }

  /// A single rule, live from [effectiveFrom] (defaults to well before any
  /// fixture trade so it applies by default).
  static Rule rule({
    required String id,
    required String name,
    required RuleCategory category,
    required RuleMeasure measure,
    RuleSeverity severity = RuleSeverity.warning,
    String? threshold,
    DateTime? effectiveFrom,
    bool isActive = true,
    int weight = 1,
    List<MarketSession> sessions = const [],
    List<int> weekdays = const [],
    List<RuleVersion> history = const [],
  }) =>
      Rule(
        id: id,
        userId: 'user_1',
        isActive: isActive,
        current: RuleVersion(
          id: '${id}_v${history.length + 1}',
          ruleId: id,
          version: history.length + 1,
          name: name,
          description: name,
          category: category,
          severity: severity,
          measure: measure,
          threshold: threshold == null ? null : Dec.parse(threshold),
          weight: weight,
          sessions: sessions,
          weekdays: weekdays,
          effectiveFromUtc:
              effectiveFrom ?? baseTime.subtract(const Duration(days: 365)),
        ),
        history: history,
      );

  static DayContext dayContext({
    String dayKey = '2026-03-16',
    TradingAccount? account,
    List<Strategy> strategies = const [],
    bool dailyReviewCompleted = false,
    Map<String, bool> manualCompliance = const {},
    String? weekNetPnl,
    String? weekTotalR,
  }) =>
      DayContext(
        tradingDayKey: dayKey,
        account: account ?? Fixtures.account(),
        strategiesById: {
          for (final strategy in
              strategies.isEmpty ? [Fixtures.strategy()] : strategies)
            strategy.id: strategy,
        },
        dailyReviewCompleted: dailyReviewCompleted,
        manualCompliance: manualCompliance,
        weekNetPnl: weekNetPnl == null ? null : Dec.parse(weekNetPnl),
        weekTotalR: weekTotalR == null ? null : Dec.parse(weekTotalR),
      );
}

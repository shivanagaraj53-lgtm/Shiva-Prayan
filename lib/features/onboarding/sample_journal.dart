import 'package:prayan_core/prayan_core.dart';

import '../../domain/repositories.dart';

/// The optional worked example offered at the end of onboarding.
///
/// It reproduces the three trades from the product brief's §39 scenario, which
/// between them demonstrate the whole philosophy: a disciplined loss scores
/// high, a clean winner scores high, and a profitable trade that broke a major
/// rule is capped and resets the streak.
///
/// Every sample trade is tagged `sample` and carries `importSource: 'sample'`,
/// so it is visibly not the user's own record and can be removed wholesale.
class SampleJournal {
  const SampleJournal._();

  static const importSource = 'sample';

  /// Writes the sample trades, dated to the most recent weekday.
  static Future<void> install({
    required TradeRepository trades,
    required List<Strategy> strategies,
    required TradingDayConfig config,
    required String userId,
    required TradingAccount account,
    required DateTime now,
  }) async {
    final sessionStart = _lastWeekdayMorning(now);
    final dayKey = TradingDay.keyFor(sessionStart, config);

    // Sample equity is used only if the user skipped entering their own, so
    // the percentages in the example still mean something.
    final equity = account.startingEquity.isZero
        ? Dec.parse('500000')
        : account.startingEquity;

    final ids = _sampleStrategyIds(strategies);

    final samples = <Trade>[
      // 1. Pullback, 0.8% risk, planned 1:2.4, stopped out for -1R.
      //    Every rule followed — the disciplined loss.
      _build(
        id: '${userId}_sample_1',
        userId: userId,
        account: account,
        dayKey: dayKey,
        openedAt: sessionStart,
        symbol: 'RELIANCE',
        strategyId: ids.pullback,
        entry: '100',
        stop: '96',
        target: '109.6',
        exit: '96',
        quantity: '1000',
        equity: equity,
        emotion: EmotionTag.calm,
        entryReason:
            'Pullback into the rising 20 EMA with the trend intact. Stop below '
            'the swing low, target at the prior high.',
        exitReason: 'Stop hit as planned. No adjustment made.',
        wouldRepeat: true,
      ),
      // 2. Breakout, 1.0% risk, planned 1:2.1, closed at +2R.
      _build(
        id: '${userId}_sample_2',
        userId: userId,
        account: account,
        dayKey: dayKey,
        openedAt: sessionStart.add(const Duration(hours: 1)),
        symbol: 'HDFCBANK',
        strategyId: ids.breakout,
        entry: '200',
        stop: '195',
        target: '210.5',
        exit: '210',
        quantity: '1000',
        equity: equity,
        emotion: EmotionTag.focused,
        entryReason:
            'Break of the three-day range on expanding volume. Stop under the '
            'breakout level.',
        exitReason: 'Target area reached; closed into strength.',
        wouldRepeat: true,
      ),
      // 3. An unapproved impulse setup at 1.8% risk. It won — and it is still
      //    the worst-scoring trade of the three. This is the example that
      //    teaches the product's whole point.
      _build(
        id: '${userId}_sample_3',
        userId: userId,
        account: account,
        dayKey: dayKey,
        openedAt: sessionStart.add(const Duration(hours: 2)),
        symbol: 'TATAMOTORS',
        strategyId: null,
        entry: '300',
        stop: '291',
        target: '318',
        exit: '320',
        quantity: '1000',
        equity: equity,
        emotion: EmotionTag.fomo,
        entryReason: 'Saw it running and did not want to miss it.',
        exitReason: 'Closed for a gain.',
        mistake: MistakeCategory.unapprovedSetup,
        isImpulsive: true,
        wouldRepeat: false,
      ),
    ];

    for (final trade in samples) {
      await trades.saveTrade(trade);
    }
  }

  /// Removes every sample trade, leaving real entries untouched.
  static Future<void> remove({
    required TradeRepository trades,
    required String userId,
    required String todayKey,
  }) async {
    final from = TradingDay.format(
      (TradingDay.parseKey(todayKey) ?? DateTime.now().toUtc())
          .subtract(const Duration(days: 30)),
    );

    final existing = await trades
        .watchTradesInRange(userId, fromDayKey: from, toDayKey: todayKey)
        .first;
    for (final trade in existing) {
      if (trade.importSource == importSource) {
        await trades.deleteTrade(trade.id);
      }
    }
  }

  static Trade _build({
    required String id,
    required String userId,
    required TradingAccount account,
    required String dayKey,
    required DateTime openedAt,
    required String symbol,
    required String? strategyId,
    required String entry,
    required String stop,
    required String target,
    required String exit,
    required String quantity,
    required Dec equity,
    required EmotionTag emotion,
    required String entryReason,
    required String exitReason,
    MistakeCategory mistake = MistakeCategory.none,
    bool isImpulsive = false,
    bool wouldRepeat = true,
  }) {
    final closedAt = openedAt.add(const Duration(minutes: 40));
    final checklist = ['s1', 's2', 's3', 's4', 's5'];

    return Trade(
      id: id,
      userId: userId,
      accountId: account.id,
      symbol: symbol,
      assetClass: AssetClass.equity,
      direction: TradeDirection.long,
      strategyId: strategyId,
      status: TradeStatus.closed,
      openedAtUtc: openedAt,
      closedAtUtc: closedAt,
      tradingDayKey: dayKey,
      session: MarketSession.open,
      plannedEntryPrice: Dec.parse(entry),
      stopLossPrice: Dec.parse(stop),
      targetPrice: Dec.parse(target),
      multiplier: Dec.one,
      plannedQuantity: Dec.parse(quantity),
      accountEquityAtOpen: equity,
      executions: [
        TradeExecution(
          id: '${id}_entry',
          kind: ExecutionKind.entry,
          price: Dec.parse(entry),
          quantity: Dec.parse(quantity),
          timestampUtc: openedAt,
        ),
        TradeExecution(
          id: '${id}_exit',
          kind: ExecutionKind.exit,
          price: Dec.parse(exit),
          quantity: Dec.parse(quantity),
          timestampUtc: closedAt,
        ),
      ],
      entryReason: entryReason,
      exitReason: exitReason,
      emotionBefore: emotion,
      emotionAfter: emotion == EmotionTag.fomo
          ? EmotionTag.overconfident
          : EmotionTag.calm,
      confidence: emotion == EmotionTag.fomo ? 8 : 6,
      mistake: mistake,
      tags: const ['sample'],
      // The impulse trade skipped the checklist, which is exactly why its
      // score suffers.
      presentedChecklistItemIds: checklist,
      completedChecklistItemIds: isImpulsive ? const ['s1'] : checklist,
      wouldRepeat: wouldRepeat,
      isImpulsive: isImpulsive,
      importSource: importSource,
      createdAtUtc: openedAt,
      updatedAtUtc: closedAt,
    );
  }

  static ({String? breakout, String? pullback}) _sampleStrategyIds(
    List<Strategy> strategies,
  ) {
    String? find(String name) {
      for (final strategy in strategies) {
        if (strategy.name.toLowerCase() == name) return strategy.id;
      }
      return null;
    }

    return (breakout: find('breakout'), pullback: find('pullback'));
  }

  /// 09:15 local on the most recent weekday, expressed in UTC.
  static DateTime _lastWeekdayMorning(DateTime now) {
    var day = DateTime.utc(now.year, now.month, now.day, 4, 0);
    while (day.weekday == DateTime.saturday || day.weekday == DateTime.sunday) {
      day = day.subtract(const Duration(days: 1));
    }
    return day;
  }
}

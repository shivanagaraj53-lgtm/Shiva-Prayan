import '../models/enums.dart';
import '../models/trade.dart';
import '../money/dec.dart';
import 'trade_calculator.dart';

/// A point on the cumulative equity curve, in money and in R.
class EquityPoint {
  final DateTime atUtc;
  final String tradeId;

  /// Cumulative net P&L up to and including this trade.
  final Dec cumulativePnl;

  /// Cumulative R up to and including this trade, counting only trades whose
  /// R could be determined.
  final Dec cumulativeR;

  const EquityPoint({
    required this.atUtc,
    required this.tradeId,
    required this.cumulativePnl,
    required this.cumulativeR,
  });
}

/// Aggregate performance over a set of closed trades (brief §12, §22).
///
/// Ratios that are undefined for the given sample are `null`, never a
/// placeholder. A profit factor with no losing trades is genuinely undefined,
/// and showing "∞" or "0" would both mislead.
class PerformanceMetrics {
  final int tradeCount;
  final int winCount;
  final int lossCount;
  final int breakevenCount;

  final Dec grossProfit;
  final Dec grossLoss;
  final Dec totalFees;
  final Dec netPnl;

  /// Sum of realised R across trades where R is determinable.
  final Dec totalR;

  /// How many trades contributed to [totalR].
  final int rSampleCount;

  final Dec? winRate;
  final Dec? averageWin;
  final Dec? averageLoss;

  /// Average money result per trade, weighted by outcome frequency.
  final Dec? expectancy;

  /// Average R per trade — the size-independent version of [expectancy], and
  /// the one the app leads with.
  final Dec? expectancyR;

  final Dec? profitFactor;

  /// Largest peak-to-trough decline of the cumulative net P&L curve.
  final Dec maxDrawdown;

  /// [maxDrawdown] as a percentage of the running peak when it occurred.
  final Dec? maxDrawdownPercent;

  /// Largest peak-to-trough decline measured in R.
  final Dec maxDrawdownR;

  final Dec? averagePlannedRewardRisk;
  final Dec? averageRealizedRewardRisk;
  final Duration? averageHoldingTime;

  final List<EquityPoint> equityCurve;

  const PerformanceMetrics({
    required this.tradeCount,
    required this.winCount,
    required this.lossCount,
    required this.breakevenCount,
    required this.grossProfit,
    required this.grossLoss,
    required this.totalFees,
    required this.netPnl,
    required this.totalR,
    required this.rSampleCount,
    required this.maxDrawdown,
    required this.maxDrawdownR,
    required this.equityCurve,
    this.winRate,
    this.averageWin,
    this.averageLoss,
    this.expectancy,
    this.expectancyR,
    this.profitFactor,
    this.maxDrawdownPercent,
    this.averagePlannedRewardRisk,
    this.averageRealizedRewardRisk,
    this.averageHoldingTime,
  });

  /// An empty sample — what every analytics screen renders before the first
  /// closed trade exists.
  static PerformanceMetrics get empty => PerformanceMetrics(
        tradeCount: 0,
        winCount: 0,
        lossCount: 0,
        breakevenCount: 0,
        grossProfit: Dec.zero,
        grossLoss: Dec.zero,
        totalFees: Dec.zero,
        netPnl: Dec.zero,
        totalR: Dec.zero,
        rSampleCount: 0,
        maxDrawdown: Dec.zero,
        maxDrawdownR: Dec.zero,
        equityCurve: const [],
      );

  bool get hasData => tradeCount > 0;

  /// Statistical caution threshold. Below this the UI labels metrics as an
  /// early sample rather than presenting them as an established edge —
  /// the brief forbids implying past results predict future ones (§12).
  bool get isSmallSample => tradeCount < 20;
}

/// Computes aggregates from journalled trades.
class PerformanceCalculator {
  const PerformanceCalculator._();

  static const int _scale = 4;

  /// Aggregates the closed trades in [trades].
  ///
  /// Open and planned trades are ignored: an unrealised position has no
  /// result to average, and including it would let a user's floating P&L
  /// flatter their statistics.
  static PerformanceMetrics compute(Iterable<Trade> trades) {
    final closed = trades
        .where((t) => t.status == TradeStatus.closed)
        .toList(growable: false)
      ..sort((a, b) => (a.closedAtUtc ?? a.openedAtUtc)
          .compareTo(b.closedAtUtc ?? b.openedAtUtc));

    if (closed.isEmpty) return PerformanceMetrics.empty;

    var winCount = 0;
    var lossCount = 0;
    var breakevenCount = 0;
    var grossProfit = Dec.zero;
    var grossLoss = Dec.zero;
    var totalFees = Dec.zero;
    var netPnl = Dec.zero;
    var totalR = Dec.zero;
    var rSampleCount = 0;
    var sumWins = Dec.zero;
    var sumLosses = Dec.zero;
    var plannedRrTotal = Dec.zero;
    var plannedRrCount = 0;
    var realizedRrTotal = Dec.zero;
    var realizedRrCount = 0;
    var holdingMicroseconds = 0;
    var holdingCount = 0;

    final equityCurve = <EquityPoint>[];
    var runningPnl = Dec.zero;
    var runningR = Dec.zero;
    var peakPnl = Dec.zero;
    var peakR = Dec.zero;
    var maxDrawdown = Dec.zero;
    var maxDrawdownR = Dec.zero;
    Dec? maxDrawdownPercent;
    var counted = 0;

    for (final trade in closed) {
      final metrics = TradeCalculator.compute(trade);
      final result = metrics.netPnl;
      if (result == null) continue;
      counted++;

      netPnl += result;
      totalFees += metrics.fees;

      switch (metrics.outcome) {
        case TradeOutcome.win:
          winCount++;
          sumWins += result;
          grossProfit += result;
        case TradeOutcome.loss:
          lossCount++;
          sumLosses += result.abs;
          grossLoss += result.abs;
        case TradeOutcome.breakeven:
        case null:
          breakevenCount++;
          // A "breakeven" can still carry a small signed result from fees;
          // it belongs in gross profit/loss so those reconcile to net P&L.
          if (result.isPositive) {
            grossProfit += result;
          } else if (result.isNegative) {
            grossLoss += result.abs;
          }
      }

      final r = metrics.realizedR;
      if (r != null) {
        totalR += r;
        rSampleCount++;
        runningR += r;
      }

      final plannedRr = metrics.plannedRewardRisk;
      if (plannedRr != null) {
        plannedRrTotal += plannedRr;
        plannedRrCount++;
      }
      final realizedRr = metrics.realizedRewardRisk;
      if (realizedRr != null) {
        realizedRrTotal += realizedRr;
        realizedRrCount++;
      }

      final holding = metrics.holdingTime;
      if (holding != null) {
        holdingMicroseconds += holding.inMicroseconds;
        holdingCount++;
      }

      runningPnl += result;
      equityCurve.add(EquityPoint(
        atUtc: trade.closedAtUtc ?? trade.openedAtUtc,
        tradeId: trade.id,
        cumulativePnl: runningPnl,
        cumulativeR: runningR,
      ));

      // Drawdown is measured from the running high-water mark, so a decline
      // that never exceeds a previous peak does not double count.
      if (runningPnl > peakPnl) peakPnl = runningPnl;
      final drawdown = peakPnl - runningPnl;
      if (drawdown > maxDrawdown) {
        maxDrawdown = drawdown;
        maxDrawdownPercent =
            peakPnl.isZero ? null : drawdown.percentOf(peakPnl, scale: _scale);
      }

      if (runningR > peakR) peakR = runningR;
      final drawdownR = peakR - runningR;
      if (drawdownR > maxDrawdownR) maxDrawdownR = drawdownR;
    }

    if (counted == 0) return PerformanceMetrics.empty;

    final tradeCount = counted;
    final countDec = Dec.fromInt(tradeCount);

    final winRate = Dec.fromInt(winCount).percentOf(countDec, scale: _scale);
    final averageWin = winCount == 0
        ? null
        : sumWins.divide(Dec.fromInt(winCount), scale: _scale);
    final averageLoss = lossCount == 0
        ? null
        : sumLosses.divide(Dec.fromInt(lossCount), scale: _scale);

    // Expectancy = (P(win) x average win) - (P(loss) x average loss).
    // Breakeven trades sit in the denominator but contribute nothing, which
    // correctly dilutes expectancy for a user who scratches many trades.
    Dec? expectancy;
    if (averageWin != null || averageLoss != null) {
      final winProbability = Dec.fromInt(winCount).divide(countDec, scale: 8);
      final lossProbability = Dec.fromInt(lossCount).divide(countDec, scale: 8);
      final winSide = (averageWin ?? Dec.zero) * winProbability;
      final lossSide = (averageLoss ?? Dec.zero) * lossProbability;
      expectancy = (winSide - lossSide).roundTo(_scale);
    }

    final expectancyR = rSampleCount == 0
        ? null
        : totalR.divide(Dec.fromInt(rSampleCount), scale: _scale);

    final profitFactor = grossLoss.isZero
        ? null // undefined without a losing trade
        : grossProfit.divide(grossLoss, scale: _scale);

    return PerformanceMetrics(
      tradeCount: tradeCount,
      winCount: winCount,
      lossCount: lossCount,
      breakevenCount: breakevenCount,
      grossProfit: grossProfit,
      grossLoss: grossLoss,
      totalFees: totalFees,
      netPnl: netPnl,
      totalR: totalR,
      rSampleCount: rSampleCount,
      winRate: winRate,
      averageWin: averageWin,
      averageLoss: averageLoss,
      expectancy: expectancy,
      expectancyR: expectancyR,
      profitFactor: profitFactor,
      maxDrawdown: maxDrawdown,
      maxDrawdownPercent: maxDrawdownPercent,
      maxDrawdownR: maxDrawdownR,
      averagePlannedRewardRisk: plannedRrCount == 0
          ? null
          : plannedRrTotal.divide(Dec.fromInt(plannedRrCount), scale: _scale),
      averageRealizedRewardRisk: realizedRrCount == 0
          ? null
          : realizedRrTotal.divide(Dec.fromInt(realizedRrCount), scale: _scale),
      averageHoldingTime: holdingCount == 0
          ? null
          : Duration(microseconds: holdingMicroseconds ~/ holdingCount),
      equityCurve: List.unmodifiable(equityCurve),
    );
  }

  /// Splits [trades] by an arbitrary key and computes metrics per bucket.
  ///
  /// Powers every breakdown on the analytics screen: by strategy, by asset
  /// class, by weekday, by session, by emotion, by mistake (brief §12).
  static Map<K, PerformanceMetrics> groupBy<K>(
    Iterable<Trade> trades,
    K Function(Trade) keyOf,
  ) {
    final buckets = <K, List<Trade>>{};
    for (final trade in trades) {
      buckets.putIfAbsent(keyOf(trade), () => <Trade>[]).add(trade);
    }
    return {
      for (final entry in buckets.entries) entry.key: compute(entry.value),
    };
  }
}

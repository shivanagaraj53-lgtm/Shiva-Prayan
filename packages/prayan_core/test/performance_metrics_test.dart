import 'package:prayan_core/prayan_core.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';

/// A closed trade with a chosen net result, keeping risk fixed at 200 so R is
/// simply `result / 200`.
Trade result(String id, String exitPrice, {int minuteOffset = 0}) =>
    Fixtures.trade(
      id: id,
      entry: '100',
      stop: '98',
      target: '106',
      exit: exitPrice,
      quantity: '100',
      openedAt: Fixtures.baseTime.add(Duration(minutes: minuteOffset)),
    );

void main() {
  group('Aggregates', () {
    test('an empty sample reports no data instead of zeros everywhere', () {
      final metrics = PerformanceCalculator.compute(const []);
      expect(metrics.hasData, isFalse);
      expect(metrics.winRate, isNull);
      expect(metrics.profitFactor, isNull);
      expect(metrics.expectancy, isNull);
    });

    test('counts wins, losses and net result', () {
      final metrics = PerformanceCalculator.compute([
        result('t1', '104'), // +400
        result('t2', '98', minuteOffset: 10), // -200
        result('t3', '106', minuteOffset: 20), // +600
      ]);
      expect(metrics.tradeCount, 3);
      expect(metrics.winCount, 2);
      expect(metrics.lossCount, 1);
      expect(metrics.netPnl, Dec.parse('800'));
      expect(metrics.grossProfit, Dec.parse('1000'));
      expect(metrics.grossLoss, Dec.parse('200'));
    });

    test('win rate is a percentage of all closed trades', () {
      final metrics = PerformanceCalculator.compute([
        result('t1', '104'),
        result('t2', '98', minuteOffset: 10),
        result('t3', '104', minuteOffset: 20),
        result('t4', '98', minuteOffset: 30),
      ]);
      expect(metrics.winRate, Dec.parse('50'));
    });

    test('average win and average loss', () {
      final metrics = PerformanceCalculator.compute([
        result('t1', '104'), // +400
        result('t2', '106', minuteOffset: 10), // +600
        result('t3', '98', minuteOffset: 20), // -200
      ]);
      expect(metrics.averageWin, Dec.parse('500'));
      expect(metrics.averageLoss, Dec.parse('200'));
    });

    test('expectancy is probability-weighted', () {
      // 2 wins of +400, 2 losses of -200 over 4 trades.
      // (0.5 x 400) - (0.5 x 200) = 100
      final metrics = PerformanceCalculator.compute([
        result('t1', '104'),
        result('t2', '104', minuteOffset: 10),
        result('t3', '98', minuteOffset: 20),
        result('t4', '98', minuteOffset: 30),
      ]);
      expect(metrics.expectancy, Dec.parse('100'));
      // In R: (+2, +2, -1, -1) / 4 = 0.5
      expect(metrics.expectancyR, Dec.parse('0.5'));
    });

    test('profit factor is gross profit over gross loss', () {
      final metrics = PerformanceCalculator.compute([
        result('t1', '104'), // +400
        result('t2', '98', minuteOffset: 10), // -200
      ]);
      expect(metrics.profitFactor, Dec.parse('2'));
    });

    test('profit factor is undefined without a losing trade', () {
      final metrics = PerformanceCalculator.compute([
        result('t1', '104'),
        result('t2', '106', minuteOffset: 10),
      ]);
      expect(metrics.profitFactor, isNull);
      expect(metrics.grossLoss, Dec.zero);
    });

    test('cumulative R sums only trades where R is determinable', () {
      final metrics = PerformanceCalculator.compute([
        result('t1', '104'), // +2R
        Fixtures.trade(
          id: 't2',
          stop: null, // no R available
          entry: '100',
          exit: '110',
          openedAt: Fixtures.baseTime.add(const Duration(minutes: 10)),
        ),
      ]);
      expect(metrics.rSampleCount, 1);
      expect(metrics.totalR, Dec.parse('2'));
      // Money still counts both.
      expect(metrics.tradeCount, 2);
    });

    test('open and planned trades are excluded', () {
      final metrics = PerformanceCalculator.compute([
        result('t1', '104'),
        Fixtures.trade(id: 't2', status: TradeStatus.open, exit: null),
        Fixtures.trade(id: 't3', status: TradeStatus.planned, exit: null),
      ]);
      expect(metrics.tradeCount, 1);
    });

    test('fees reduce net P&L and are reported separately', () {
      final metrics = PerformanceCalculator.compute([
        Fixtures.trade(
            id: 't1', entry: '100', stop: '98', exit: '104',
            quantity: '100', fees: '50'),
      ]);
      expect(metrics.totalFees, Dec.parse('50'));
      expect(metrics.netPnl, Dec.parse('350'));
    });
  });

  group('Drawdown', () {
    test('measures the largest peak-to-trough decline', () {
      // Curve: +400, +1000, +600, +200, +800
      final metrics = PerformanceCalculator.compute([
        result('t1', '104'), // +400  -> 400
        result('t2', '106', minuteOffset: 10), // +600  -> 1000 (peak)
        result('t3', '96', minuteOffset: 20), // -400  -> 600
        result('t4', '96', minuteOffset: 30), // -400  -> 200 (trough)
        result('t5', '106', minuteOffset: 40), // +600  -> 800
      ]);
      expect(metrics.maxDrawdown, Dec.parse('800'));
      expect(metrics.maxDrawdownPercent, Dec.parse('80'));
      expect(metrics.equityCurve, hasLength(5));
      expect(metrics.equityCurve.last.cumulativePnl, Dec.parse('800'));
    });

    test('a monotonically rising curve has no drawdown', () {
      final metrics = PerformanceCalculator.compute([
        result('t1', '104'),
        result('t2', '106', minuteOffset: 10),
      ]);
      expect(metrics.maxDrawdown, Dec.zero);
    });

    test('drawdown in R is tracked alongside money', () {
      final metrics = PerformanceCalculator.compute([
        result('t1', '104'), // +2R
        result('t2', '98', minuteOffset: 10), // -1R
        result('t3', '98', minuteOffset: 20), // -1R
      ]);
      expect(metrics.maxDrawdownR, Dec.parse('2'));
    });

    test('the curve is ordered by close time, not input order', () {
      final metrics = PerformanceCalculator.compute([
        result('t3', '106', minuteOffset: 40),
        result('t1', '104', minuteOffset: 0),
        result('t2', '98', minuteOffset: 20),
      ]);
      expect(metrics.equityCurve.map((p) => p.tradeId).toList(),
          ['t1', 't2', 't3']);
    });
  });

  group('Grouping', () {
    test('splits metrics by an arbitrary key', () {
      final trades = [
        result('t1', '104'),
        result('t2', '98', minuteOffset: 10),
        Fixtures.trade(
          id: 't3',
          direction: TradeDirection.short,
          entry: '100', stop: '102', target: '94', exit: '94',
          quantity: '100',
          openedAt: Fixtures.baseTime.add(const Duration(minutes: 20)),
        ),
      ];
      final byDirection =
          PerformanceCalculator.groupBy(trades, (t) => t.direction);
      expect(byDirection[TradeDirection.long]!.tradeCount, 2);
      expect(byDirection[TradeDirection.short]!.tradeCount, 1);
      expect(byDirection[TradeDirection.short]!.netPnl, Dec.parse('600'));
    });

    test('small samples are flagged so the UI can caveat them', () {
      final metrics = PerformanceCalculator.compute([result('t1', '104')]);
      expect(metrics.isSmallSample, isTrue);
    });
  });
}

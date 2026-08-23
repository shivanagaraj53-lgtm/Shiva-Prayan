import 'package:prayan_core/prayan_core.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';

void main() {
  group('P&L', () {
    test('long winner: (exit - entry) x quantity', () {
      final metrics = TradeCalculator.compute(
          Fixtures.trade(entry: '100', exit: '104', quantity: '100'));
      expect(metrics.grossPnl, Dec.parse('400'));
      expect(metrics.netPnl, Dec.parse('400'));
      expect(metrics.outcome, TradeOutcome.win);
    });

    test('short winner: price falling produces a profit', () {
      final metrics = TradeCalculator.compute(Fixtures.trade(
        direction: TradeDirection.short,
        entry: '100',
        stop: '102',
        target: '96',
        exit: '96',
        quantity: '100',
      ));
      expect(metrics.grossPnl, Dec.parse('400'));
      expect(metrics.outcome, TradeOutcome.win);
    });

    test('short loser: price rising produces a loss', () {
      final metrics = TradeCalculator.compute(Fixtures.trade(
        direction: TradeDirection.short,
        entry: '100',
        stop: '102',
        target: '96',
        exit: '102',
        quantity: '100',
      ));
      expect(metrics.grossPnl, Dec.parse('-200'));
      expect(metrics.realizedR, Dec.parse('-1'));
      expect(metrics.outcome, TradeOutcome.loss);
    });

    test('fees are subtracted from gross to give net', () {
      final metrics = TradeCalculator.compute(Fixtures.trade(
        entry: '100',
        exit: '104',
        quantity: '100',
        fees: '35.50',
      ));
      expect(metrics.grossPnl, Dec.parse('400'));
      expect(metrics.fees, Dec.parse('35.50'));
      expect(metrics.netPnl, Dec.parse('364.50'));
    });

    test('applies a contract multiplier for futures', () {
      final metrics = TradeCalculator.compute(Fixtures.trade(
        entry: '22000',
        stop: '21900',
        target: '22200',
        exit: '22200',
        quantity: '2',
        multiplier: '50',
      ));
      // 200 points x 2 lots x 50 per point
      expect(metrics.grossPnl, Dec.parse('20000'));
      expect(metrics.plannedRisk, Dec.parse('10000'));
      expect(metrics.realizedR, Dec.parse('2'));
    });

    test('fractional crypto quantities stay exact', () {
      final metrics = TradeCalculator.compute(Fixtures.trade(
        entry: '64000.55',
        stop: '63000.55',
        target: '66000.55',
        exit: '66000.55',
        quantity: '0.13750000',
      ));
      expect(metrics.grossPnl, Dec.parse('275'));
      expect(metrics.plannedRisk, Dec.parse('137.5'));
    });
  });

  group('Risk and R', () {
    test('planned risk, risk percent and reward:risk', () {
      final metrics = TradeCalculator.compute(Fixtures.trade(
        entry: '100',
        stop: '98',
        target: '104.8',
        quantity: '100',
        equity: '500000',
      ));
      expect(metrics.riskPerUnit, Dec.parse('2'));
      expect(metrics.plannedRisk, Dec.parse('200'));
      expect(metrics.plannedRiskPercent, Dec.parse('0.04'));
      expect(metrics.plannedRewardRisk, Dec.parse('2.4'));
    });

    test('realized R is net P&L divided by planned risk', () {
      final metrics = TradeCalculator.compute(Fixtures.trade(
          entry: '100',
          stop: '98',
          target: '104',
          exit: '104',
          quantity: '100'));
      expect(metrics.plannedRisk, Dec.parse('200'));
      expect(metrics.realizedR, Dec.parse('2'));
    });

    test('a trade with no stop has undefined risk and R, not zero', () {
      final metrics = TradeCalculator.compute(
          Fixtures.trade(stop: null, entry: '100', exit: '104'));
      expect(metrics.plannedRisk, isNull);
      expect(metrics.plannedRiskPercent, isNull);
      expect(metrics.realizedR, isNull);
      expect(metrics.plannedRewardRisk, isNull);
      // The money result is still known.
      expect(metrics.netPnl, Dec.parse('400'));
    });

    test('a stop equal to entry yields no risk rather than infinite R', () {
      final metrics = TradeCalculator.compute(
          Fixtures.trade(entry: '100', stop: '100', exit: '104'));
      expect(metrics.plannedRisk, isNull);
      expect(metrics.realizedR, isNull);
    });

    test('risk percent uses the equity frozen at plan time', () {
      final metrics = TradeCalculator.compute(Fixtures.trade(
          entry: '100', stop: '90', quantity: '100', equity: '100000'));
      expect(metrics.plannedRisk, Dec.parse('1000'));
      expect(metrics.plannedRiskPercent, Dec.parse('1'));
    });
  });

  group('Partial exits and scale-ins', () {
    test('weighted average entry across two scale-in fills', () {
      final opened = Fixtures.baseTime;
      final metrics = TradeCalculator.compute(Fixtures.trade(
        entry: '100',
        stop: '96',
        quantity: '100',
        executions: [
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
            price: Dec.parse('102'),
            quantity: Dec.parse('50'),
            timestampUtc: opened.add(const Duration(minutes: 5)),
          ),
          TradeExecution(
            id: 'x1',
            kind: ExecutionKind.exit,
            price: Dec.parse('106'),
            quantity: Dec.parse('100'),
            timestampUtc: opened.add(const Duration(minutes: 30)),
          ),
        ],
      ));
      expect(metrics.averageEntryPrice, Dec.parse('101'));
      expect(metrics.entryQuantity, Dec.parse('100'));
      expect(metrics.grossPnl, Dec.parse('500'));
    });

    test('a partially closed position reports open quantity', () {
      final opened = Fixtures.baseTime;
      final metrics = TradeCalculator.compute(Fixtures.trade(
        status: TradeStatus.open,
        executions: [
          TradeExecution(
            id: 'e1',
            kind: ExecutionKind.entry,
            price: Dec.parse('100'),
            quantity: Dec.parse('100'),
            timestampUtc: opened,
          ),
          TradeExecution(
            id: 'x1',
            kind: ExecutionKind.exit,
            price: Dec.parse('104'),
            quantity: Dec.parse('40'),
            timestampUtc: opened.add(const Duration(minutes: 10)),
          ),
        ],
      ));
      expect(metrics.entryQuantity, Dec.parse('100'));
      expect(metrics.exitQuantity, Dec.parse('40'));
      expect(metrics.closedQuantity, Dec.parse('40'));
      expect(metrics.openQuantity, Dec.parse('60'));
      // P&L is booked on the closed portion only.
      expect(metrics.grossPnl, Dec.parse('160'));
      expect(metrics.isPartiallyExited, isTrue);
    });
  });

  group('Outcome classification', () {
    test('a result inside the breakeven band is not called a win', () {
      // Planned risk 200; 2% band is +/- 4.
      final metrics = TradeCalculator.compute(Fixtures.trade(
          entry: '100', stop: '98', exit: '100.03', quantity: '100'));
      expect(metrics.netPnl, Dec.parse('3'));
      expect(metrics.outcome, TradeOutcome.breakeven);
    });

    test('an exactly flat trade with no risk data is breakeven', () {
      final metrics = TradeCalculator.compute(
          Fixtures.trade(stop: null, entry: '100', exit: '100'));
      expect(metrics.netPnl, Dec.zero);
      expect(metrics.outcome, TradeOutcome.breakeven);
    });

    test('an open trade has no outcome yet', () {
      final metrics = TradeCalculator.compute(
          Fixtures.trade(status: TradeStatus.open, exit: null));
      expect(metrics.outcome, isNull);
      expect(metrics.netPnl, isNull);
      expect(metrics.hasRealizedResult, isFalse);
    });
  });

  group('Validation', () {
    test('a well-formed trade produces no issues', () {
      expect(TradeCalculator.validate(Fixtures.trade()), isEmpty);
    });

    test('rejects a long stop placed above entry', () {
      final issues = TradeCalculator.validate(
          Fixtures.trade(entry: '100', stop: '105', target: '110'));
      expect(issues.map((i) => i.field), contains('stopLossPrice'));
      expect(issues.first.message, contains('below your entry'));
    });

    test('rejects a short stop placed below entry', () {
      final issues = TradeCalculator.validate(Fixtures.trade(
        direction: TradeDirection.short,
        entry: '100',
        stop: '95',
        target: '90',
      ));
      expect(issues.map((i) => i.field), contains('stopLossPrice'));
    });

    test('rejects a long target below entry', () {
      final issues = TradeCalculator.validate(
          Fixtures.trade(entry: '100', stop: '98', target: '99'));
      expect(issues.map((i) => i.field), contains('targetPrice'));
    });

    test('rejects exiting more quantity than was entered', () {
      final opened = Fixtures.baseTime;
      final issues = TradeCalculator.validate(Fixtures.trade(executions: [
        TradeExecution(
          id: 'e1',
          kind: ExecutionKind.entry,
          price: Dec.parse('100'),
          quantity: Dec.parse('50'),
          timestampUtc: opened,
        ),
        TradeExecution(
          id: 'x1',
          kind: ExecutionKind.exit,
          price: Dec.parse('104'),
          quantity: Dec.parse('80'),
          timestampUtc: opened.add(const Duration(minutes: 1)),
        ),
      ]));
      expect(issues.map((i) => i.message).join(),
          contains('exited more quantity'));
    });

    test('flags a missing stop as a caution rather than a hard error', () {
      final issues = TradeCalculator.validate(Fixtures.trade(stop: null));
      final stopIssue = issues.firstWhere((i) => i.field == 'stopLossPrice');
      expect(stopIssue.isBlocking, isFalse);
    });

    test('rejects an out-of-range confidence rating', () {
      final trade = Fixtures.trade().copyWith(confidence: 11);
      expect(TradeCalculator.validate(trade).map((i) => i.field),
          contains('confidence'));
    });

    test('rejects an exit timestamped before the entry', () {
      final trade = Fixtures.trade().copyWith(
          closedAtUtc: Fixtures.baseTime.subtract(const Duration(hours: 1)));
      expect(TradeCalculator.validate(trade).map((i) => i.field),
          contains('closedAtUtc'));
    });
  });

  group('Checklist ratio', () {
    test('is the completed share of what was presented', () {
      final trade = Fixtures.trade(
        checklistPresented: ['a', 'b', 'c', 'd'],
        checklistCompleted: ['a', 'b', 'c'],
      );
      expect(trade.checklistCompletionRatio, Dec.parse('0.75'));
    });

    test('is null when no checklist was presented', () {
      final trade = Fixtures.trade(
          checklistPresented: const [], checklistCompleted: const []);
      expect(trade.checklistCompletionRatio, isNull);
    });

    test('ignores ticks for items that were not presented', () {
      final trade = Fixtures.trade(
        checklistPresented: ['a', 'b'],
        checklistCompleted: ['a', 'b', 'zzz'],
      );
      expect(trade.checklistCompletionRatio, Dec.one);
    });
  });

  group('Serialisation round-trip', () {
    test('a trade survives toMap/fromMap unchanged', () {
      final original = Fixtures.trade(fees: '12.34');
      final restored = Trade.fromMap(original.toMap());
      expect(restored.id, original.id);
      expect(restored.symbol, original.symbol);
      expect(restored.direction, original.direction);
      expect(restored.stopLossPrice, original.stopLossPrice);
      expect(restored.executions.length, original.executions.length);
      expect(TradeCalculator.compute(restored).netPnl,
          TradeCalculator.compute(original).netPnl);
    });

    test('an unknown enum value falls back instead of throwing', () {
      final map = Fixtures.trade().toMap();
      map['assetClass'] = 'quantum_widgets';
      expect(Trade.fromMap(map).assetClass, AssetClass.equity);
    });
  });
}

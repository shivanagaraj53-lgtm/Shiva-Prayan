import 'package:prayan_core/prayan_core.dart';
import 'package:test/test.dart';

/// The three-part method: entered, exited, fully executed.
///
/// [TradeStatus] records what the position is doing. [TradeStage] records what
/// the journal entry has become, which is a different question. A closed
/// position with nothing said about it is a receipt; the difference is
/// invisible when the only thing tracked is open versus closed, and it is
/// exactly the difference this product is about.
Trade base({
  TradeStatus status = TradeStatus.open,
  String? entryReason,
  String? exitReason,
  bool? wouldRepeat,
}) =>
    Trade(
      id: 't1',
      userId: 'user',
      accountId: 'acct',
      symbol: 'INFY',
      assetClass: AssetClass.equity,
      direction: TradeDirection.long,
      status: status,
      openedAtUtc: DateTime.utc(2026, 8, 23, 4),
      closedAtUtc:
          status == TradeStatus.closed ? DateTime.utc(2026, 8, 23, 6) : null,
      tradingDayKey: '2026-08-23',
      session: MarketSession.open,
      multiplier: Dec.one,
      executions: const [],
      entryReason: entryReason,
      exitReason: exitReason,
      wouldRepeat: wouldRepeat,
      emotionBefore: EmotionTag.calm,
      mistake: MistakeCategory.none,
      createdAtUtc: DateTime.utc(2026, 8, 23, 4),
      updatedAtUtc: DateTime.utc(2026, 8, 23, 6),
    );

void main() {
  group('stages', () {
    test('a plan is planned', () {
      expect(base(status: TradeStatus.planned).stage, TradeStage.planned);
    });

    test('an open position is entered', () {
      expect(base().stage, TradeStage.entered);
    });

    test('a closed position with no reflection is exited, not finished', () {
      expect(base(status: TradeStatus.closed).stage, TradeStage.exited);
    });

    test('a closed position with the full reflection is executed', () {
      final trade = base(
        status: TradeStatus.closed,
        entryReason: 'Range break with volume',
        exitReason: 'Target hit',
        wouldRepeat: true,
      );
      expect(trade.stage, TradeStage.executed);
    });

    test('a setup declined is cancelled, not part of the method', () {
      expect(base(status: TradeStatus.cancelled).stage, TradeStage.cancelled);
      expect(TradeStage.cancelled.step, isNull);
    });
  });

  group('what counts as reviewed', () {
    test('all three answers are needed', () {
      // Each is a different question, and two out of three is a half-written
      // entry — which is the state this stage exists to make visible.
      expect(
        base(status: TradeStatus.closed, entryReason: 'a', exitReason: 'b')
            .isReviewed,
        isFalse,
        reason: 'no verdict recorded',
      );
      expect(
        base(status: TradeStatus.closed, entryReason: 'a', wouldRepeat: false)
            .isReviewed,
        isFalse,
        reason: 'no exit reasoning recorded',
      );
      expect(
        base(status: TradeStatus.closed, exitReason: 'b', wouldRepeat: false)
            .isReviewed,
        isFalse,
        reason: 'no entry reasoning recorded',
      );
    });

    test('whitespace is not an answer', () {
      expect(
        base(
          status: TradeStatus.closed,
          entryReason: '   ',
          exitReason: 'Target hit',
          wouldRepeat: true,
        ).isReviewed,
        isFalse,
      );
    });

    test('"I would not repeat this" is still an answer', () {
      // The verdict that matters most must not read as a missing one.
      final trade = base(
        status: TradeStatus.closed,
        entryReason: 'Chased it',
        exitReason: 'Stopped out',
        wouldRepeat: false,
      );
      expect(trade.isReviewed, isTrue);
      expect(trade.stage, TradeStage.executed);
    });
  });

  test('the method runs one, two, three', () {
    expect(TradeStage.entered.step, 1);
    expect(TradeStage.exited.step, 2);
    expect(TradeStage.executed.step, 3);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:prayan_core/prayan_core.dart';
import 'package:prayan_trading_journal/features/trade/trade_form_controller.dart';

/// Status is now something you have done, not something you pick.
///
/// It used to be a three-way control the user set by hand, which let the
/// journal disagree with itself: a trade marked Closed with no exit price, or
/// an exit typed under one still marked Open. Neither is a state a trade can
/// actually be in, and both were reachable in two taps.
void main() {
  final blank = TradeFormState(openedAtUtc: DateTime.utc(2026, 8, 23, 4));
  final entered =
      blank.copyWith(symbol: 'INFY', entryPrice: '1580', quantity: '200');

  group('derived status', () {
    test('an entry with no exit is open', () {
      expect(entered.derivedStatus, TradeStatus.open);
    });

    test('an exit price closes it, with no extra step', () {
      expect(entered.copyWith(exitPrice: '1642').derivedStatus,
          TradeStatus.closed);
    });

    test('the plan switch is the one thing that cannot be inferred', () {
      // An empty entry price is equally "a plan" and "not typed yet".
      expect(
          blank.copyWith(isPlanOnly: true).derivedStatus, TradeStatus.planned);
      expect(entered.copyWith(isPlanOnly: true).derivedStatus,
          TradeStatus.planned);
    });

    test('the saved trade carries the derived status, not the stored one', () {
      final trade = entered.copyWith(exitPrice: '1642').toTrade(
            userId: 'user',
            accountId: 'acct',
            dayKey: '2026-08-23',
            accountEquity: Dec.parse('500000'),
            presentedChecklistIds: const [],
            now: DateTime.utc(2026, 8, 23, 10),
          );
      expect(trade.status, TradeStatus.closed);
      expect(trade.closedAtUtc, isNotNull,
          reason: 'a closed trade needs a close time for the day bucketing');
    });
  });

  group('the three parts', () {
    test('a plan sits outside the method', () {
      expect(blank.copyWith(isPlanOnly: true).stage, TradeStage.planned);
    });

    test('one: entered', () {
      expect(entered.stage, TradeStage.entered);
      expect(entered.stage.step, 1);
    });

    test('two: exited, and not finished by having a price', () {
      final exited = entered.copyWith(exitPrice: '1642');
      expect(exited.stage, TradeStage.exited);
      expect(exited.stage.step, 2);
    });

    test('three: executed, once both reasons and the verdict are in', () {
      final done = entered.copyWith(
        exitPrice: '1642',
        entryReason: 'Range break on volume',
        exitReason: 'Target hit',
        wouldRepeat: true,
      );
      expect(done.stage, TradeStage.executed);
      expect(done.stage.step, 3);
    });

    test('two of the three answers is still part two', () {
      // The point of showing a third step is that it is reachable and not yet
      // reached; a stage that rounds up would defeat it.
      final almost = entered.copyWith(
        exitPrice: '1642',
        entryReason: 'Range break on volume',
        wouldRepeat: true,
      );
      expect(almost.stage, TradeStage.exited);
    });

    test('the form and the saved trade agree about the stage', () {
      // Two implementations — one on the form, one on `Trade` — and a journal
      // that showed step 3 while the saved entry reported step 2 would be
      // worse than either being wrong on its own.
      final form = entered.copyWith(
        exitPrice: '1642',
        entryReason: 'Range break on volume',
        exitReason: 'Target hit',
        wouldRepeat: false,
      );
      final trade = form.toTrade(
        userId: 'user',
        accountId: 'acct',
        dayKey: '2026-08-23',
        accountEquity: Dec.parse('500000'),
        presentedChecklistIds: const [],
        now: DateTime.utc(2026, 8, 23, 10),
      );
      expect(trade.stage, form.stage);
    });
  });

  group('screenshots', () {
    test('ids are added, deduped and removed', () {
      final c = TradeFormController(DateTime.utc(2026, 8, 23, 4));
      c.addAttachment('att_1');
      c.addAttachment('att_1');
      expect(c.state.attachmentIds, ['att_1']);
      c.addAttachment('att_2');
      c.removeAttachment('att_1');
      expect(c.state.attachmentIds, ['att_2']);
    });

    test('they reach the saved trade', () {
      final c = TradeFormController(DateTime.utc(2026, 8, 23, 4));
      c.addAttachment('att_1');
      final trade =
          c.state.copyWith(symbol: 'INFY', entryPrice: '1580').toTrade(
                userId: 'user',
                accountId: 'acct',
                dayKey: '2026-08-23',
                accountEquity: Dec.parse('500000'),
                presentedChecklistIds: const [],
                now: DateTime.utc(2026, 8, 23, 10),
              );
      expect(trade.attachmentIds, ['att_1']);
    });
  });
}

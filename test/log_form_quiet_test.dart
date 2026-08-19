import 'package:flutter_test/flutter_test.dart';
import 'package:prayan_core/prayan_core.dart';
import 'package:prayan_trading_journal/features/trade/trade_form_controller.dart';

/// An empty form is not a rule breach.
///
/// Opening "Log trade" ran the rules engine over a blank form and rendered
/// everything it found: no stop, no approved setup, no checklist, no
/// reasoning — four red rows, before a single character was typed. The screen
/// accused you of things you had not had the chance to do yet, which is the
/// fastest way to teach someone to stop reading the warnings.
///
/// The gate is [TradeFormState.isJudgeable]. This asserts where it opens,
/// because the failure it prevents is invisible in code review and obvious the
/// second a user sees it.
void main() {
  final empty = TradeFormState(openedAtUtc: DateTime.utc(2026, 1, 2, 10));

  test('a form nobody has touched is not judged', () {
    expect(empty.isJudgeable, isFalse);
  });

  test('a symbol alone is still not a trade', () {
    // Typing three letters of an instrument says nothing about risk, and
    // judging it there would fire the moment someone starts typing.
    expect(empty.copyWith(symbol: 'RELIANCE').isJudgeable, isFalse);
  });

  test('an entry price with no instrument is not a trade either', () {
    expect(empty.copyWith(entryPrice: '2450').isJudgeable, isFalse);
  });

  test('an instrument and an entry is the point it starts to mean something',
      () {
    final form = empty.copyWith(symbol: 'RELIANCE', entryPrice: '2450');
    expect(form.isJudgeable, isTrue,
        reason: 'past this point the rules depend on what the user did, not '
            'on the form being new');
  });

  test('a blank entry price does not count as an entry', () {
    // '' and '  ' parse to null, and a rule set that fires on whitespace is
    // the original bug with extra steps.
    for (final value in ['', '   ', 'abc']) {
      expect(empty.copyWith(symbol: 'RELIANCE', entryPrice: value).isJudgeable,
          isFalse,
          reason: 'entry "$value" was treated as a price');
    }
  });

  test('judgeable is reached before saveable', () {
    // Feedback has to arrive while the trade is still being described — after
    // it is complete enough to save is a post-mortem, which is the thing this
    // product exists not to be.
    final form = empty.copyWith(symbol: 'RELIANCE', entryPrice: '2450');
    expect(form.isJudgeable, isTrue);
    expect(form.canSave, isFalse, reason: 'quantity is still missing');

    final complete = form.copyWith(quantity: '100');
    expect(complete.canSave, isTrue);
    expect(complete.isJudgeable, isTrue);
  });

  test('the rules engine really does light up an empty form', () {
    // The guard only earns its place if the thing it guards against is real.
    final rules = RuleTemplates.balanced.instantiate(
      userId: 'user',
      now: DateTime.utc(2026, 1, 1),
      idPrefix: 'rule',
    );
    final account = TradingAccount(
      id: 'acct',
      userId: 'user',
      name: 'Primary',
      currency: Currency.inr,
      startingEquity: Dec.parse('500000'),
      currentEquity: Dec.parse('500000'),
      createdAtUtc: DateTime.utc(2026, 1, 1),
    );
    final blank = empty.toTrade(
      userId: 'user',
      accountId: 'acct',
      dayKey: '2026-01-02',
      accountEquity: account.riskBaseEquity,
      presentedChecklistIds: const [],
      now: DateTime.utc(2026, 1, 2, 10),
    );
    final evaluations = RulesEngine.evaluateTrade(
      trade: blank,
      rules: rules,
      context: DayContext(
        tradingDayKey: '2026-01-02',
        account: account,
        strategiesById: const {},
      ),
    );

    expect(evaluations.where((e) => e.isViolation), isNotEmpty,
        reason: 'if an empty form no longer breaks any rule, the gate is '
            'unnecessary — delete it rather than leaving it as decoration');
  });
}

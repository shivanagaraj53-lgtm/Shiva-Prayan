import 'package:flutter_test/flutter_test.dart';
import 'package:prayan_core/prayan_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:prayan_trading_journal/data/local/local_repositories.dart';
import 'package:prayan_trading_journal/data/local/local_store.dart';
import 'package:prayan_trading_journal/features/onboarding/sample_journal.dart';

/// The sample journal has to be *judged* by the rules created alongside it.
///
/// It exists to show a new user the product's whole argument: a losing trade
/// that followed every rule scores 100, a profitable one that broke rules is
/// capped. If no rule applies to those trades, the screens render "3 of 3 rules
/// followed, score 100" and the demonstration says the opposite of what it is
/// for.
///
/// That is what happened. Rules were created effective at the instant
/// onboarding finished, while the sample session is dated to that morning, so
/// every trade-scoped rule was skipped for anyone who set the app up after
/// roughly 09:30 IST — most of the day, in the market this was built around.
/// Initial rules are now effective from the start of the user's trading day.
///
/// The clocks below sweep a whole day on purpose: the bug was invisible before
/// the session start and certain after it, so any single fixed clock could
/// have missed it entirely.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const config = TradingDayConfig(utcOffsetMinutes: 330); // IST

  final account = TradingAccount(
    id: 'acct',
    userId: 'user',
    name: 'Primary',
    currency: Currency.inr,
    startingEquity: Dec.parse('500000'),
    currentEquity: Dec.parse('500000'),
    createdAtUtc: DateTime.utc(2026, 3, 1),
  );

  const strategies = <Strategy>[
    Strategy(id: 'user_strategy_0', userId: 'user', name: 'Breakout'),
    Strategy(id: 'user_strategy_1', userId: 'user', name: 'Pullback'),
  ];

  /// The instant onboarding makes the starter rules effective from.
  ///
  /// This mirrors `OnboardingController` exactly, and it has to: the sample
  /// session can be dated to an *earlier* trading day than the one onboarding
  /// finishes in — before the bell, or over a weekend — and rules anchored to
  /// today would then not reach it. Onboarding backdates to whichever comes
  /// first. A helper that only used today's day start would pass here while
  /// production failed, which is the wrong way round for a regression test.
  DateTime ruleStartFor(DateTime now) {
    final (dayStart, _) = TradingDay.utcRangeFor(
      TradingDay.keyFor(now, config),
      config,
    );
    final sampleStart = SampleJournal.sessionStartFor(now, config);
    return sampleStart.isBefore(dayStart) ? sampleStart : dayStart;
  }

  /// Installs the sample journal through the real local repository — the same
  /// path onboarding takes — and returns what it wrote.
  Future<List<Trade>> installSample(DateTime now) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final store = LocalStore(await SharedPreferences.getInstance());
    final trades = LocalTradeRepository(store);
    await SampleJournal.install(
      trades: trades,
      strategies: strategies,
      config: config,
      userId: 'user',
      account: account,
      now: now,
    );

    // The sample session can be dated to an earlier weekday than `now`, so the
    // window reaches back a week rather than assuming today.
    final today = TradingDay.keyFor(now, config);
    final from = TradingDay.format(
      (TradingDay.parseKey(today) ?? DateTime.utc(2026))
          .subtract(const Duration(days: 7)),
    );
    return trades
        .watchTradesInRange('user', fromDayKey: from, toDayKey: today)
        .first;
  }

  DisciplineScore scoreDay(List<Trade> saved, DateTime now) {
    final rules = RuleTemplates.balanced.instantiate(
      userId: 'user',
      now: ruleStartFor(now),
      idPrefix: 'user_rule',
    );
    final context = DayContext(
      tradingDayKey: saved.first.tradingDayKey,
      account: account,
      strategiesById: {for (final s in strategies) s.id: s},
    );
    return DisciplineScorer.score(
      RulesEngine.evaluateDay(trades: saved, rules: rules, context: context)
          .all,
    );
  }

  for (final hourUtc in [0, 4, 6, 10, 14, 18, 23]) {
    test('sample trades are judged when onboarding ends at $hourUtc:00 UTC',
        () async {
      final now = DateTime.utc(2026, 3, 16, hourUtc);
      final saved = await installSample(now);
      expect(saved, isNotEmpty, reason: 'no sample trades were written');

      final score = scoreDay(saved, now);

      // The whole point: the starter rules actually reach these trades.
      expect(score.rulesApplicable, greaterThan(3),
          reason: 'only ${score.rulesApplicable} rules applied — the starter '
              'rules do not cover the sample session');
      expect(score.violations, isNotEmpty,
          reason: 'the deliberately rule-breaking sample trade was not caught');
      expect(score.value < Dec.hundred, isTrue,
          reason: 'a day containing a rule-breaking trade scored full marks');
    });
  }

  test('the example session is always already finished', () async {
    // Three *closed* trades dated to a session that has not happened yet is a
    // journal full of trades from the future. It shows up for anyone opening
    // the app before the market opens — which the clock sweep above misses,
    // because those all run after 09:15 IST on a weekday.
    //
    // 00:00 and 02:00 UTC are 05:30 and 07:30 IST: same trading day, before
    // the bell. Saturday and Sunday are here because the walk back has to
    // clear a weekend as well.
    final clocks = <DateTime>[
      DateTime.utc(2026, 3, 16, 0), // Mon 05:30 IST, before the open
      DateTime.utc(2026, 3, 16, 2), // Mon 07:30 IST, before the open
      DateTime.utc(2026, 3, 16, 3, 44), // Mon, one minute before the bell
      DateTime.utc(2026, 3, 14, 12), // Saturday
      DateTime.utc(2026, 3, 15, 12), // Sunday
      DateTime.utc(2026, 8, 18, 21, 30), // 03:00 IST the next day
    ];

    for (final now in clocks) {
      final saved = await installSample(now);
      expect(saved, isNotEmpty, reason: 'no sample trades written at $now');

      for (final trade in saved) {
        expect(trade.openedAtUtc.isBefore(now), isTrue,
            reason: 'a sample trade opens in the future: '
                '${trade.symbol} at ${trade.openedAtUtc} with now = $now');
        final closed = trade.closedAtUtc;
        expect(closed != null && closed.isBefore(now), isTrue,
            reason: 'a sample trade closes in the future: '
                '${trade.symbol} at $closed with now = $now');
      }

      // And it still has to be scored, by the rules onboarding would create.
      expect(scoreDay(saved, now).rulesApplicable, greaterThan(3),
          reason: 'rules do not reach the sample session at $now');
    }
  });

  test('the disciplined loss outscores the profitable rule-break', () async {
    // The demonstration only works if this inversion holds. Checked at an
    // afternoon clock, which is the case that used to be broken.
    final now = DateTime.utc(2026, 3, 16, 14);
    final saved = await installSample(now);

    final rules = RuleTemplates.balanced.instantiate(
      userId: 'user',
      now: ruleStartFor(now),
      idPrefix: 'user_rule',
    );
    final context = DayContext(
      tradingDayKey: saved.first.tradingDayKey,
      account: account,
      strategiesById: {for (final s in strategies) s.id: s},
    );

    Dec scoreOf(Trade trade) => DisciplineScorer.score(
          RulesEngine.evaluateTrade(
            trade: trade,
            rules: rules,
            context: context,
          ),
        ).value;

    // The sample has two winners: a clean one and the deliberate rule-break.
    // Picking "the first profitable trade" grabs the clean one and compares
    // two spotless trades, which proves nothing.
    int violationsOn(Trade trade) => DisciplineScorer.score(
          RulesEngine.evaluateTrade(
            trade: trade,
            rules: rules,
            context: context,
          ),
        ).violations.length;

    final withMetrics =
        saved.map((t) => (t, TradeCalculator.compute(t))).toList();
    final ruleBreakingWinner = withMetrics
        .where((e) => e.$2.netPnl != null && e.$2.netPnl!.isPositive)
        .map((e) => e.$1)
        .reduce((a, b) => violationsOn(a) >= violationsOn(b) ? a : b);
    final disciplinedLoser = withMetrics
        .firstWhere((e) => e.$2.netPnl != null && e.$2.netPnl!.isNegative)
        .$1;

    expect(violationsOn(ruleBreakingWinner), greaterThan(0),
        reason: 'the sample no longer contains a rule-breaking winner');
    expect(violationsOn(disciplinedLoser), 0,
        reason: 'the sample losing trade is meant to be spotless');

    expect(scoreOf(disciplinedLoser) > scoreOf(ruleBreakingWinner), isTrue,
        reason: 'a losing trade that followed the rules must outscore a '
            'profitable one that broke them — the product depends on it');
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prayan_core/prayan_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:prayan_trading_journal/data/local/local_repositories.dart';
import 'package:prayan_trading_journal/data/local/local_store.dart';
import 'package:prayan_trading_journal/features/onboarding/sample_journal.dart';
import 'package:prayan_trading_journal/state/providers.dart';

/// The worked example must never be invisible.
///
/// The dashboard is a today-only screen. The sample journal is dated to the
/// last *finished* session, because three closed trades in the future is
/// nonsense — which means it lands on an earlier day than "today" whenever
/// someone onboards before the session, or at a moment when UTC and the
/// trading day disagree about the date.
///
/// Both of those are correct on their own and broken together: the user
/// switches on "load the sample journal" and the first screen says nothing was
/// logged. The dashboard closes that by pointing at the last day with trades,
/// and this asserts the two halves still meet.
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
  ];

  /// Onboarding, then the dashboard's own question: where is the example?
  Future<({String today, String sampleDay, String? pointer})> onboardAt(
    DateTime now,
  ) async {
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

    final container = ProviderContainer(
      overrides: [
        tradeRepositoryProvider.overrideWithValue(trades),
        currentUserIdProvider.overrideWithValue('user'),
        tradingDayConfigProvider.overrideWithValue(config),
        nowProvider.overrideWithValue(() => now),
      ],
    );
    addTearDown(container.dispose);

    final today = container.read(todayKeyProvider);

    // The range providers are streams; give them a microtask to deliver.
    container.listen(lastActiveDayBeforeProvider(today), (_, __) {});
    await Future<void>.delayed(Duration.zero);

    return (
      today: today,
      sampleDay: TradingDay.keyFor(
        SampleJournal.sessionStartFor(now, config),
        config,
      ),
      pointer: container.read(lastActiveDayBeforeProvider(today)),
    );
  }

  // Deliberately the awkward clocks: before the bell, mid-session, both
  // weekend days, and one where UTC has not yet rolled over but IST has.
  final clocks = <DateTime>[
    DateTime.utc(2026, 3, 16, 0), // Mon 05:30 IST, before the open
    DateTime.utc(2026, 3, 16, 4), // Mon 09:30 IST, session under way
    DateTime.utc(2026, 3, 16, 14), // Mon 19:30 IST, session over
    DateTime.utc(2026, 3, 14, 12), // Saturday
    DateTime.utc(2026, 3, 15, 12), // Sunday
    DateTime.utc(2026, 8, 18, 21, 30), // 03:00 IST the following day
  ];

  for (final now in clocks) {
    test('the worked example is reachable when onboarding at $now', () async {
      final r = await onboardAt(now);

      if (r.sampleDay == r.today) return; // On the dashboard already.

      expect(r.pointer, isNotNull,
          reason: 'the sample landed on ${r.sampleDay} but the dashboard for '
              '${r.today} has nothing to point at — the worked example is '
              'invisible to a user who just asked for it');
      expect(r.pointer, r.sampleDay,
          reason: 'the dashboard points at ${r.pointer}, not the sample day');
    });
  }

  test('the awkward clocks really do put the example on an earlier day',
      () async {
    // Without this the tests above can pass by doing nothing: if the sample
    // ever moves back onto today, every one of them takes the early return and
    // asserts precisely nothing. These three are the cases that must exercise
    // the pointer.
    for (final now in [
      DateTime.utc(2026, 3, 16, 0), // before the bell
      DateTime.utc(2026, 3, 15, 12), // Sunday
      DateTime.utc(2026, 8, 18, 21, 30), // UTC and IST disagree on the date
    ]) {
      final today = TradingDay.keyFor(now, config);
      final sampleDay =
          TradingDay.keyFor(SampleJournal.sessionStartFor(now, config), config);
      expect(sampleDay.compareTo(today) < 0, isTrue,
          reason: 'at $now the sample is on $sampleDay and today is $today, '
              'so the reachability test above proves nothing');
    }
  });

  test('a genuinely empty journal points nowhere', () async {
    // The pointer must not invent a day. An empty journal keeps the plain
    // "nothing logged today" empty state, which is the right thing to show.
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final store = LocalStore(await SharedPreferences.getInstance());
    final container = ProviderContainer(
      overrides: [
        tradeRepositoryProvider.overrideWithValue(LocalTradeRepository(store)),
        currentUserIdProvider.overrideWithValue('user'),
        tradingDayConfigProvider.overrideWithValue(config),
        nowProvider.overrideWithValue(() => DateTime.utc(2026, 3, 16, 14)),
      ],
    );
    addTearDown(container.dispose);

    final today = container.read(todayKeyProvider);
    container.listen(lastActiveDayBeforeProvider(today), (_, __) {});
    await Future<void>.delayed(Duration.zero);

    expect(container.read(lastActiveDayBeforeProvider(today)), isNull);
  });
}

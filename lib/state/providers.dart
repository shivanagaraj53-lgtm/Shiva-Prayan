/// Riverpod wiring.
///
/// Repository providers all `throw UnimplementedError` by default and are
/// overridden once in `lib/app/bootstrap.dart`. That is deliberate: it makes
/// the dependency graph explicit, it means a test can override exactly the one
/// repository it cares about, and it makes it impossible to accidentally ship
/// a screen that reaches for a repository nobody wired up.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prayan_core/prayan_core.dart';
import 'package:timezone/timezone.dart' as tz;

import '../domain/day_snapshot.dart';
import '../domain/models.dart';
import '../domain/repositories.dart';

const _needsOverride = 'Override this provider in bootstrap.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => throw UnimplementedError(_needsOverride),
);
final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => throw UnimplementedError(_needsOverride),
);
final accountRepositoryProvider = Provider<AccountRepository>(
  (ref) => throw UnimplementedError(_needsOverride),
);
final strategyRepositoryProvider = Provider<StrategyRepository>(
  (ref) => throw UnimplementedError(_needsOverride),
);
final checklistRepositoryProvider = Provider<ChecklistRepository>(
  (ref) => throw UnimplementedError(_needsOverride),
);
final ruleRepositoryProvider = Provider<RuleRepository>(
  (ref) => throw UnimplementedError(_needsOverride),
);
final tradeRepositoryProvider = Provider<TradeRepository>(
  (ref) => throw UnimplementedError(_needsOverride),
);
final reviewRepositoryProvider = Provider<ReviewRepository>(
  (ref) => throw UnimplementedError(_needsOverride),
);
final psychologyRepositoryProvider = Provider<PsychologyRepository>(
  (ref) => throw UnimplementedError(_needsOverride),
);
final disciplineRepositoryProvider = Provider<DisciplineRepository>(
  (ref) => throw UnimplementedError(_needsOverride),
);
final attachmentRepositoryProvider = Provider<AttachmentRepository>(
  (ref) => throw UnimplementedError(_needsOverride),
);
final coachingRepositoryProvider = Provider<CoachingRepository>(
  (ref) => throw UnimplementedError(_needsOverride),
);

/// The clock, injectable so tests can pin "today".
final nowProvider = Provider<DateTime Function()>(
  (ref) => () => DateTime.now().toUtc(),
);

// --- Session ---------------------------------------------------------------

final authStateProvider = StreamProvider<AuthUser?>(
  (ref) => ref.watch(authRepositoryProvider).authStateChanges(),
);

final currentUserIdProvider = Provider<String?>(
  (ref) => ref.watch(authStateProvider).value?.id,
);

final profileProvider = StreamProvider<UserProfile?>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Stream.value(null);
  return ref.watch(profileRepositoryProvider).watchProfile(userId);
});

/// App preferences, held in a notifier so a theme change is instant.
class PreferencesNotifier extends StateNotifier<AppPreferences> {
  final ProfileRepository _repository;
  final String? _userId;

  PreferencesNotifier(this._repository, this._userId)
      : super(const AppPreferences()) {
    _load();
  }

  Future<void> _load() async {
    final userId = _userId;
    if (userId == null) return;
    state = await _repository.getPreferences(userId);
  }

  Future<void> update(AppPreferences preferences) async {
    // Optimistic: the UI must not wait on disk to repaint a theme change.
    state = preferences;
    final userId = _userId;
    if (userId != null) {
      await _repository.savePreferences(userId, preferences);
    }
  }
}

final preferencesProvider =
    StateNotifierProvider<PreferencesNotifier, AppPreferences>((ref) {
  return PreferencesNotifier(
    ref.watch(profileRepositoryProvider),
    ref.watch(currentUserIdProvider),
  );
});

final notificationPreferencesProvider =
    FutureProvider<NotificationPreferences>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const NotificationPreferences();
  return ref
      .watch(profileRepositoryProvider)
      .getNotificationPreferences(userId);
});

// --- Timezone and the trading day -----------------------------------------

/// Resolves the user's IANA zone to the UTC offset in effect *right now*.
///
/// Recomputed rather than cached because the offset changes across a
/// daylight-saving boundary; caching it is how journals end up bucketing an
/// October trade into the wrong day.
final tradingDayConfigProvider = Provider<TradingDayConfig>((ref) {
  final profile = ref.watch(profileProvider).value;
  final name = profile?.timezoneName ?? 'UTC';
  return tradingDayConfigFor(name, ref.watch(nowProvider)());
});

/// Offset of [zoneName] at [instant], falling back to UTC for an unknown zone.
TradingDayConfig tradingDayConfigFor(String zoneName, DateTime instant) {
  try {
    final location = tz.getLocation(zoneName);
    // `TimeZone.offset` is a Duration in timezone >= 0.10.
    final offset = location.timeZone(instant.millisecondsSinceEpoch).offset;
    return TradingDayConfig(utcOffsetMinutes: offset.inMinutes);
  } on Object {
    // An unrecognised zone must not crash the app; UTC is a safe, obvious
    // fallback and the settings screen surfaces the zone the user picked.
    return TradingDayConfig.utc;
  }
}

/// Today's trading-day key in the user's timezone.
final todayKeyProvider = Provider<String>((ref) {
  final now = ref.watch(nowProvider)();
  return TradingDay.keyFor(now, ref.watch(tradingDayConfigProvider));
});

/// The day the app is currently focused on. Changed by the calendar.
final selectedDayKeyProvider = StateProvider<String?>((ref) => null);

/// The day actually being viewed: the selection, or today.
final activeDayKeyProvider = Provider<String>(
  (ref) => ref.watch(selectedDayKeyProvider) ?? ref.watch(todayKeyProvider),
);

// --- Reference data --------------------------------------------------------

final accountsProvider = StreamProvider<List<TradingAccount>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Stream.value(const []);
  return ref.watch(accountRepositoryProvider).watchAccounts(userId);
});

final selectedAccountIdProvider = StateProvider<String?>((ref) => null);

/// The account in context: the explicit selection, else the default, else the
/// first available.
final activeAccountProvider = Provider<TradingAccount?>((ref) {
  final accounts = ref.watch(accountsProvider).value ?? const [];
  if (accounts.isEmpty) return null;
  final selectedId = ref.watch(selectedAccountIdProvider);
  if (selectedId != null) {
    for (final account in accounts) {
      if (account.id == selectedId) return account;
    }
  }
  for (final account in accounts) {
    if (account.isDefault) return account;
  }
  return accounts.first;
});

final strategiesProvider = StreamProvider<List<Strategy>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Stream.value(const []);
  return ref.watch(strategyRepositoryProvider).watchStrategies(userId);
});

final checklistProvider = StreamProvider<List<ChecklistItem>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Stream.value(const []);
  return ref.watch(checklistRepositoryProvider).watchChecklist(userId);
});

final rulesProvider = StreamProvider<List<Rule>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Stream.value(const []);
  return ref.watch(ruleRepositoryProvider).watchRules(userId);
});

// --- Trades ----------------------------------------------------------------

final tradesForDayProvider =
    StreamProvider.family<List<Trade>, String>((ref, dayKey) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Stream.value(const []);
  return ref.watch(tradeRepositoryProvider).watchTradesForDay(userId, dayKey);
});

/// An inclusive day-key range.
class DayRange {
  final String from;
  final String to;
  const DayRange(this.from, this.to);

  @override
  bool operator ==(Object other) =>
      other is DayRange && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(from, to);
}

final tradesInRangeProvider =
    StreamProvider.family<List<Trade>, DayRange>((ref, range) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Stream.value(const []);
  return ref.watch(tradeRepositoryProvider).watchTradesInRange(
        userId,
        fromDayKey: range.from,
        toDayKey: range.to,
      );
});

final pendingWritesProvider = StreamProvider<int>(
  (ref) => ref.watch(tradeRepositoryProvider).watchPendingWriteCount(),
);

final disciplineHistoryProvider =
    StreamProvider.family<List<DailyDisciplineRecord>, DayRange>((ref, range) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Stream.value(const []);
  return ref.watch(disciplineRepositoryProvider).watchHistory(
        userId,
        fromDayKey: range.from,
        toDayKey: range.to,
      );
});

final dailyReviewProvider =
    StreamProvider.family<DailyReview?, String>((ref, dayKey) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Stream.value(null);
  return ref.watch(reviewRepositoryProvider).watchDailyReview(userId, dayKey);
});

final psychologyForDayProvider =
    StreamProvider.family<List<PsychologyEntry>, String>((ref, dayKey) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Stream.value(const []);
  return ref
      .watch(psychologyRepositoryProvider)
      .watchEntriesForDay(userId, dayKey);
});

final behaviourWatchesProvider = StreamProvider<List<BehaviourWatch>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Stream.value(const []);
  return ref.watch(psychologyRepositoryProvider).watchBehaviourWatches(userId);
});

// --- The composed day ------------------------------------------------------

/// The finished [DaySnapshot] for a day.
///
/// Everything the dashboard, calendar detail and daily review render comes
/// through here, so the score a user sees in three places is computed exactly
/// once from exactly one set of inputs.
final daySnapshotProvider =
    Provider.family<AsyncValue<DaySnapshot>, String>((ref, dayKey) {
  final account = ref.watch(activeAccountProvider);
  if (account == null) return const AsyncValue.loading();

  final trades = ref.watch(tradesForDayProvider(dayKey));
  final rules = ref.watch(rulesProvider);
  final strategies = ref.watch(strategiesProvider);
  final review = ref.watch(dailyReviewProvider(dayKey));
  final psychology = ref.watch(psychologyForDayProvider(dayKey));

  // History reaches back 120 days: enough for the 90-day rolling score plus a
  // margin, and small enough to stay a single query.
  final historyRange = DayRange(_shiftDays(dayKey, -120), dayKey);
  final history = ref.watch(disciplineHistoryProvider(historyRange));

  // Week-to-date, for week-scoped rules.
  final weekRange = DayRange(_weekStart(dayKey), dayKey);
  final weekTrades = ref.watch(tradesInRangeProvider(weekRange));

  if (trades.isLoading || rules.isLoading || strategies.isLoading) {
    return const AsyncValue.loading();
  }
  final error = trades.error ?? rules.error ?? strategies.error;
  if (error != null) {
    return AsyncValue.error(error, StackTrace.current);
  }

  final weekMetrics =
      PerformanceCalculator.compute(weekTrades.value ?? const []);

  return AsyncValue.data(
    DaySnapshot.build(
      dayKey: dayKey,
      account: account,
      trades: trades.value ?? const [],
      rules: rules.value ?? const [],
      strategies: strategies.value ?? const [],
      priorHistory: history.value ?? const [],
      preferences: ref.watch(preferencesProvider),
      psychology: psychology.value ?? const [],
      review: review.value,
      weekNetPnl: weekMetrics.netPnl,
      weekTotalR: weekMetrics.totalR,
    ),
  );
});

/// The snapshot for the day currently in focus.
final activeDaySnapshotProvider = Provider<AsyncValue<DaySnapshot>>(
  (ref) => ref.watch(daySnapshotProvider(ref.watch(activeDayKeyProvider))),
);

/// The most recent day *before* [dayKey] that has any trades on it.
///
/// A day with nothing logged is a dead end otherwise: the dashboard is a
/// today-only screen, so someone opening the app before the session — or on a
/// Monday morning, or right after onboarding loads the worked example onto the
/// last finished session — is shown an empty page with no indication that the
/// journal behind it has anything in it at all.
///
/// Looks back three weeks, which covers a holiday plus a long weekend and is
/// short enough that a journal abandoned a month ago does not resurface as if
/// it were current. Returns null when there is genuinely nothing to point at.
final lastActiveDayBeforeProvider =
    Provider.family<String?, String>((ref, dayKey) {
  final yesterday = _shiftDays(dayKey, -1);
  final trades =
      ref.watch(tradesInRangeProvider(DayRange(_shiftDays(dayKey, -21), yesterday)));
  final keys = trades.value?.map((t) => t.tradingDayKey);
  if (keys == null || keys.isEmpty) return null;
  // Day keys are ISO dates, so the lexical maximum is the chronological one.
  return keys.reduce((a, b) => a.compareTo(b) >= 0 ? a : b);
});

String _shiftDays(String dayKey, int days) {
  final date = TradingDay.parseKey(dayKey);
  if (date == null) return dayKey;
  return TradingDay.format(date.add(Duration(days: days)));
}

/// Monday of the week containing [dayKey].
String _weekStart(String dayKey) {
  final date = TradingDay.parseKey(dayKey);
  if (date == null) return dayKey;
  return TradingDay.format(
    date.subtract(Duration(days: date.weekday - DateTime.monday)),
  );
}

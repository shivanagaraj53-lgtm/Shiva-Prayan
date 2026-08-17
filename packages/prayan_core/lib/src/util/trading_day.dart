/// Trading-day bucketing.
///
/// Every aggregate in the product — the calendar, the daily score, the streak,
/// "maximum 3 trades per day" — depends on agreeing which calendar day a trade
/// belongs to. Getting this wrong is the classic journalling bug: a trade
/// entered at 09:15 IST is stored as 03:45 UTC, and a naive `toUtc().day`
/// buckets a late-evening trade into tomorrow.
///
/// The rule here: canonical timestamps are always UTC, and the *day key* is
/// derived by shifting into the user's zone once, at the point of bucketing.
///
/// This package takes a fixed UTC offset rather than an IANA zone name so it
/// stays dependency-free. The app layer resolves the user's IANA zone (via the
/// `timezone` package) to the offset in effect at that instant and passes it
/// in, which keeps daylight-saving transitions correct without pulling a
/// timezone database into the domain engine.
library;

/// A user's day-boundary configuration.
class TradingDayConfig {
  /// Offset from UTC in minutes, at the instant being bucketed.
  /// India is +330, New York in winter is -300.
  final int utcOffsetMinutes;

  /// Minutes past local midnight where the trading day starts.
  ///
  /// Zero for almost everyone. Futures and FX traders whose session opens the
  /// previous evening can shift it, e.g. `-360` to start the day at 18:00 the
  /// previous evening.
  final int dayStartMinutes;

  const TradingDayConfig({
    required this.utcOffsetMinutes,
    this.dayStartMinutes = 0,
  });

  /// UTC, no shift. The safe default before onboarding completes.
  static const TradingDayConfig utc = TradingDayConfig(utcOffsetMinutes: 0);

  /// India Standard Time, the brief's primary example market.
  static const TradingDayConfig ist = TradingDayConfig(utcOffsetMinutes: 330);

  Map<String, dynamic> toMap() => {
        'utcOffsetMinutes': utcOffsetMinutes,
        'dayStartMinutes': dayStartMinutes,
      };

  factory TradingDayConfig.fromMap(Map<String, dynamic> map) =>
      TradingDayConfig(
        utcOffsetMinutes: (map['utcOffsetMinutes'] as num?)?.toInt() ?? 0,
        dayStartMinutes: (map['dayStartMinutes'] as num?)?.toInt() ?? 0,
      );
}

/// Converts between UTC instants and `yyyy-MM-dd` trading-day keys.
class TradingDay {
  const TradingDay._();

  /// The trading-day key for [instantUtc] under [config].
  static String keyFor(DateTime instantUtc, TradingDayConfig config) {
    final local = _toLocal(instantUtc, config);
    return format(local);
  }

  /// The local wall-clock time an instant corresponds to, already shifted by
  /// the session start so the key falls out of a plain date read.
  static DateTime _toLocal(DateTime instantUtc, TradingDayConfig config) =>
      instantUtc.toUtc().add(Duration(
            minutes: config.utcOffsetMinutes - config.dayStartMinutes,
          ));

  /// Formats a date as `yyyy-MM-dd`.
  static String format(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  /// Parses a `yyyy-MM-dd` key into a date at local midnight.
  /// Returns `null` for a malformed key rather than throwing, because keys can
  /// arrive from stored documents.
  static DateTime? parseKey(String key) {
    final parts = key.split('-');
    if (parts.length != 3) return null;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) return null;
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    return DateTime.utc(year, month, day);
  }

  /// The UTC instant range `[start, end)` covered by a trading-day key.
  ///
  /// This is what Firestore queries range over, so it must be exact: an
  /// off-by-one here silently drops the first or last trade of every day.
  static (DateTime start, DateTime end) utcRangeFor(
    String dayKey,
    TradingDayConfig config,
  ) {
    final date = parseKey(dayKey) ?? DateTime.utc(1970);
    final shift = Duration(
      minutes: config.utcOffsetMinutes - config.dayStartMinutes,
    );
    final start = date.subtract(shift);
    return (start, start.add(const Duration(days: 1)));
  }

  /// The ISO week key (`yyyy-Www`) a trading day belongs to, for weekly
  /// aggregates and week-scoped rules.
  static String weekKeyFor(String dayKey) {
    final date = parseKey(dayKey);
    if (date == null) return dayKey;
    // ISO-8601: week 1 is the week containing the first Thursday of the year.
    final thursday =
        date.add(Duration(days: DateTime.thursday - date.weekday));
    final firstOfYear = DateTime.utc(thursday.year, 1, 1);
    final week = ((thursday.difference(firstOfYear).inDays) ~/ 7) + 1;
    return '${thursday.year}-W${week.toString().padLeft(2, '0')}';
  }

  /// The month key (`yyyy-MM`) a trading day belongs to.
  static String monthKeyFor(String dayKey) =>
      dayKey.length >= 7 ? dayKey.substring(0, 7) : dayKey;

  /// Every day key from [startKey] to [endKey] inclusive. Used to render a
  /// calendar month with gaps for untraded days.
  static List<String> range(String startKey, String endKey) {
    final start = parseKey(startKey);
    final end = parseKey(endKey);
    if (start == null || end == null || end.isBefore(start)) return const [];
    final keys = <String>[];
    var cursor = start;
    while (!cursor.isAfter(end)) {
      keys.add(format(cursor));
      cursor = cursor.add(const Duration(days: 1));
    }
    return keys;
  }
}

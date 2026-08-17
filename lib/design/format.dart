import 'package:intl/intl.dart';
import 'package:prayan_core/prayan_core.dart';

/// Presentation-layer formatting.
///
/// The domain engine returns exact [Dec] values with no opinion about display;
/// this is the single place those become strings. Keeping it here means a
/// change to how R is rendered happens once, not in eleven widgets.
class Fmt {
  const Fmt._();

  /// Money in the account's currency.
  static String money(
    Dec? amount,
    Currency currency, {
    bool showSign = false,
    bool compact = false,
  }) {
    if (amount == null) return emptyValue;
    return Money(amount, currency).format(showSign: showSign, compact: compact);
  }

  /// An R-multiple, e.g. `+2.4R` or `-1R`.
  static String r(Dec? value, {bool showSign = true}) {
    if (value == null) return emptyValue;
    final rounded = value.roundTo(2).normalized;
    final sign = showSign && !rounded.isNegative && !rounded.isZero ? '+' : '';
    return '$sign${rounded}R';
  }

  /// A reward:risk ratio, e.g. `1:2.4`.
  static String rewardRisk(Dec? value) {
    if (value == null) return emptyValue;
    return '1:${value.roundTo(2).normalized}';
  }

  /// A percentage, e.g. `0.8%`.
  static String percent(Dec? value, {int decimals = 2, bool showSign = false}) {
    if (value == null) return emptyValue;
    final rounded = value.roundTo(decimals).normalized;
    final sign = showSign && !rounded.isNegative && !rounded.isZero ? '+' : '';
    return '$sign$rounded%';
  }

  /// A discipline score, always an integer 0–100.
  static String score(Dec? value) {
    if (value == null) return emptyValue;
    return value.roundTo(0).toString();
  }

  /// A plain decimal, e.g. a price or a quantity.
  static String number(Dec? value, {int? decimals}) {
    if (value == null) return emptyValue;
    return (decimals == null ? value.normalized : value.roundTo(decimals))
        .toString();
  }

  /// What is shown where a value genuinely is not known.
  ///
  /// An em dash, never `0` or `—0.00`: the difference between "no stop was
  /// recorded so R is undefined" and "R was zero" is the whole point.
  static const String emptyValue = '—';

  // --- Dates and times --------------------------------------------------

  static String dayLong(DateTime date) =>
      DateFormat('EEEE, d MMMM y').format(date);

  static String dayMedium(DateTime date) => DateFormat('d MMM y').format(date);

  static String dayShort(DateTime date) => DateFormat('d MMM').format(date);

  static String monthYear(DateTime date) => DateFormat('MMMM y').format(date);

  static String weekdayInitial(int weekday) =>
      DateFormat('EEEEE').format(DateTime.utc(2024, 1, weekday));

  static String time(DateTime localTime) =>
      DateFormat('HH:mm').format(localTime);

  /// A trading-day key rendered for humans.
  static String dayKey(String key, {bool long = false}) {
    final parsed = TradingDay.parseKey(key);
    if (parsed == null) return key;
    return long ? dayLong(parsed) : dayMedium(parsed);
  }

  /// A holding period, at the coarsest useful precision.
  static String duration(Duration? value) {
    if (value == null) return emptyValue;
    if (value.inMinutes < 1) return '${value.inSeconds}s';
    if (value.inHours < 1) return '${value.inMinutes}m';
    if (value.inDays < 1) {
      final hours = value.inHours;
      final minutes = value.inMinutes % 60;
      return minutes == 0 ? '${hours}h' : '${hours}h ${minutes}m';
    }
    final days = value.inDays;
    final hours = value.inHours % 24;
    return hours == 0 ? '${days}d' : '${days}d ${hours}h';
  }

  /// A count with its noun pluralised.
  static String count(int value, String singular, [String? plural]) =>
      '$value ${value == 1 ? singular : (plural ?? '${singular}s')}';
}

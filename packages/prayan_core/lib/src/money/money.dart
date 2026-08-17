import 'currency.dart';
import 'dec.dart';

/// Thrown when two [Money] values in different currencies are combined.
///
/// This is a programming error rather than a user error: an account is
/// single-currency by construction, so reaching here means a trade was
/// attached to the wrong account.
class CurrencyMismatchError extends Error {
  final Currency left;
  final Currency right;
  CurrencyMismatchError(this.left, this.right);

  @override
  String toString() =>
      'CurrencyMismatchError: cannot combine ${left.code} with ${right.code}';
}

/// Non-breaking space (U+00A0) placed between an amount and a trailing symbol
/// or code, so `10.00 AED` can never wrap across two lines mid-value. Written
/// as an escape rather than a literal because an invisible character in source
/// is impossible to review.
const String _nbsp = '\u00A0';

/// An exact monetary amount in a single [Currency].
///
/// The amount keeps full working precision internally (a fee of ₹0.0125 per
/// unit stays exact through a multiplication) and is only rounded to the
/// currency's minor unit at the display boundary via [format] or [rounded].
class Money implements Comparable<Money> {
  final Dec amount;
  final Currency currency;

  const Money(this.amount, this.currency);

  Money.zero(this.currency) : amount = Dec.zero;

  /// Parses user input such as `1,25,000.50`.
  factory Money.parse(String source, Currency currency) =>
      Money(Dec.parse(source), currency);

  bool get isZero => amount.isZero;
  bool get isNegative => amount.isNegative;
  bool get isPositive => amount.isPositive;
  int get signum => amount.signum;

  void _assertSameCurrency(Money other) {
    if (currency != other.currency) {
      throw CurrencyMismatchError(currency, other.currency);
    }
  }

  Money operator +(Money other) {
    _assertSameCurrency(other);
    return Money(amount + other.amount, currency);
  }

  Money operator -(Money other) {
    _assertSameCurrency(other);
    return Money(amount - other.amount, currency);
  }

  Money operator -() => Money(-amount, currency);

  /// Scales an amount by a dimensionless quantity (a size, a weight, a rate).
  Money scaleBy(Dec factor) => Money(amount * factor, currency);

  Money get abs => Money(amount.abs, currency);

  /// The ratio of two amounts in the same currency, e.g. profit factor.
  /// Returns `null` when [other] is zero so callers must handle "undefined"
  /// explicitly rather than rendering a misleading `0` or `∞`.
  Dec? ratioTo(Money other, {int scale = 4}) {
    _assertSameCurrency(other);
    if (other.amount.isZero) return null;
    return amount.divide(other.amount, scale: scale);
  }

  /// This amount as a percentage of [total]; `null` when [total] is zero.
  Dec? percentOf(Money total, {int scale = 4}) {
    _assertSameCurrency(total);
    return amount.percentOf(total.amount, scale: scale);
  }

  /// The amount rounded to the currency's minor unit.
  Money get rounded =>
      Money(amount.roundTo(currency.decimalDigits), currency);

  /// Renders the amount for display.
  ///
  /// [showSign] forces an explicit `+` on positive values, which the P&L
  /// surfaces use so a gain and a loss are distinguishable without relying on
  /// colour alone (brief §11, accessibility).
  String format({
    bool showSymbol = true,
    bool showCode = false,
    bool showSign = false,
    bool compact = false,
    int? decimalDigits,
  }) {
    final digits = decimalDigits ?? currency.decimalDigits;
    final value = amount.roundTo(digits);
    final negative = value.isNegative;

    final String body;
    if (compact) {
      body = _compactBody(value.abs, digits);
    } else {
      final text = value.abs.toString();
      final dot = text.indexOf('.');
      final integerPart = dot < 0 ? text : text.substring(0, dot);
      final fractionPart = dot < 0 ? '' : text.substring(dot + 1);
      final grouped = currency.groupDigits(integerPart);
      body = fractionPart.isEmpty ? grouped : '$grouped.$fractionPart';
    }

    final sign = negative ? '-' : (showSign && !value.isZero ? '+' : '');
    final buffer = StringBuffer(sign);
    if (showSymbol && currency.symbolPosition == SymbolPosition.before) {
      buffer.write(currency.symbol);
    }
    buffer.write(body);
    if (showSymbol && currency.symbolPosition == SymbolPosition.after) {
      buffer.write('$_nbsp${currency.symbol}');
    }
    if (showCode) buffer.write('$_nbsp${currency.code}');
    return buffer.toString();
  }

  /// Abbreviates large magnitudes so dashboard tiles never overflow.
  ///
  /// Indian-grouped currencies use the lakh/crore ladder their users read
  /// natively; everything else uses K/M/B.
  String _compactBody(Dec magnitude, int digits) {
    const oneThousand = 1000;
    final units = <(int, String)>[
      if (currency.grouping == DigitGrouping.indian) ...[
        (10000000, 'Cr'),
        (100000, 'L'),
        (oneThousand, 'K'),
      ] else ...[
        (1000000000, 'B'),
        (1000000, 'M'),
        (oneThousand, 'K'),
      ],
    ];
    for (final (threshold, suffix) in units) {
      final divisor = Dec.fromInt(threshold);
      if (magnitude >= divisor) {
        final scaled = magnitude.divide(divisor, scale: 2).normalized;
        return '${scaled.toString()}$suffix';
      }
    }
    final text = magnitude.roundTo(digits).toString();
    final dot = text.indexOf('.');
    final integerPart = dot < 0 ? text : text.substring(0, dot);
    final fractionPart = dot < 0 ? '' : text.substring(dot + 1);
    final grouped = currency.groupDigits(integerPart);
    return fractionPart.isEmpty ? grouped : '$grouped.$fractionPart';
  }

  @override
  int compareTo(Money other) {
    _assertSameCurrency(other);
    return amount.compareTo(other.amount);
  }

  bool operator <(Money other) => compareTo(other) < 0;
  bool operator <=(Money other) => compareTo(other) <= 0;
  bool operator >(Money other) => compareTo(other) > 0;
  bool operator >=(Money other) => compareTo(other) >= 0;

  @override
  bool operator ==(Object other) =>
      other is Money && other.currency == currency && other.amount == amount;

  @override
  int get hashCode => Object.hash(amount, currency);

  @override
  String toString() => '${amount.normalized} ${currency.code}';

  /// Sums [values], which must share a currency. Returns zero in [fallback]
  /// when the list is empty.
  static Money sum(Iterable<Money> values, Currency fallback) {
    var total = Money.zero(fallback);
    for (final value in values) {
      total += value;
    }
    return total;
  }
}

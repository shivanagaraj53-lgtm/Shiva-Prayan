/// Exact base-10 fixed-point arithmetic.
///
/// Prayan never stores money, prices or quantities in `double`. IEEE-754
/// binary floating point cannot represent `0.1`, so a naive `0.1 + 0.2`
/// produces `0.30000000000000004`. Accumulated over a few thousand journalled
/// trades that error becomes a P&L the user cannot reconcile against their
/// broker statement, which would destroy trust in every downstream metric.
///
/// [Dec] stores an arbitrary-precision integer of *units* together with a
/// [scale] (the number of implied decimal places), so `12.34` is
/// `units = 1234, scale = 2`. Addition, subtraction and multiplication are
/// therefore exact. Division is the only lossy operation and it demands an
/// explicit target scale and rounding mode from the caller.
library;

/// How a value that cannot be represented exactly at the target scale is
/// resolved.
enum Rounding {
  /// Ties move away from zero: `2.5 -> 3`, `-2.5 -> -3`. The convention users
  /// see on broker contract notes, and Prayan's default for display.
  halfUp,

  /// Ties move to the nearest even digit: `2.5 -> 2`, `3.5 -> 4`. Removes the
  /// systematic upward bias of [halfUp] when summing long series.
  halfEven,

  /// Always toward negative infinity.
  floor,

  /// Always toward positive infinity.
  ceil,

  /// Always toward zero (truncation).
  truncate,
}

/// An exact decimal number held as `units * 10^-scale`.
class Dec implements Comparable<Dec> {
  /// The unscaled integer value.
  final BigInt units;

  /// Number of implied decimal places. Always `>= 0`.
  final int scale;

  const Dec._(this.units, this.scale);

  /// Zero at scale 0.
  static final Dec zero = Dec._(BigInt.zero, 0);

  /// One at scale 0.
  static final Dec one = Dec._(BigInt.one, 0);

  /// One hundred at scale 0. Used pervasively by percentage maths.
  static final Dec hundred = Dec._(BigInt.from(100), 0);

  static final List<BigInt> _pow10Cache = _buildPow10Cache();

  static List<BigInt> _buildPow10Cache() {
    final cache = <BigInt>[];
    var value = BigInt.one;
    final ten = BigInt.from(10);
    for (var i = 0; i <= 40; i++) {
      cache.add(value);
      value *= ten;
    }
    return cache;
  }

  static BigInt _pow10(int exponent) {
    if (exponent < 0) {
      throw ArgumentError.value(exponent, 'exponent', 'must be >= 0');
    }
    if (exponent < _pow10Cache.length) return _pow10Cache[exponent];
    return BigInt.from(10).pow(exponent);
  }

  /// Builds a value directly from its unscaled representation.
  factory Dec.fromUnits(BigInt units, int scale) {
    if (scale < 0) throw ArgumentError.value(scale, 'scale', 'must be >= 0');
    return Dec._(units, scale);
  }

  /// Builds a value from an [int], optionally shifted by [scale] decimals.
  ///
  /// `Dec.fromInt(1234, 2)` is `12.34`.
  factory Dec.fromInt(int value, [int scale = 0]) {
    if (scale < 0) throw ArgumentError.value(scale, 'scale', 'must be >= 0');
    return Dec._(BigInt.from(value), scale);
  }

  /// Parses a decimal string such as `-1,234.5678`, `1e3` or `.5`.
  ///
  /// Grouping commas and surrounding whitespace are tolerated because this is
  /// the entry point for values typed into the trade form.
  factory Dec.parse(String source) {
    final result = Dec.tryParse(source);
    if (result == null) {
      throw FormatException('Not a valid decimal number', source);
    }
    return result;
  }

  /// Like [Dec.parse] but returns `null` instead of throwing.
  static Dec? tryParse(String source) {
    var text = source.trim().replaceAll(',', '').replaceAll('_', '');
    if (text.isEmpty) return null;

    var exponent = 0;
    final expIndex = text.indexOf(RegExp('[eE]'));
    if (expIndex >= 0) {
      final expPart = text.substring(expIndex + 1);
      final parsedExponent = int.tryParse(expPart);
      if (parsedExponent == null) return null;
      exponent = parsedExponent;
      text = text.substring(0, expIndex);
    }

    var negative = false;
    if (text.startsWith('-')) {
      negative = true;
      text = text.substring(1);
    } else if (text.startsWith('+')) {
      text = text.substring(1);
    }
    if (text.isEmpty) return null;

    String integerPart;
    String fractionPart;
    final dot = text.indexOf('.');
    if (dot < 0) {
      integerPart = text;
      fractionPart = '';
    } else {
      integerPart = text.substring(0, dot);
      fractionPart = text.substring(dot + 1);
      if (fractionPart.contains('.')) return null;
    }
    if (integerPart.isEmpty) integerPart = '0';
    final digits = '$integerPart$fractionPart';
    if (digits.isEmpty) return null;
    for (final codeUnit in digits.codeUnits) {
      if (codeUnit < 0x30 || codeUnit > 0x39) return null;
    }

    var units = BigInt.parse(digits);
    var scale = fractionPart.length;
    if (negative) units = -units;

    // Fold the exponent into the scale, growing units when the exponent
    // outruns the available decimal places.
    scale -= exponent;
    if (scale < 0) {
      units *= _pow10(-scale);
      scale = 0;
    }
    return Dec._(units, scale);
  }

  /// Converts a [double] at a bounded [scale].
  ///
  /// Only for values that entered the system as `double` already (chart
  /// gestures, third-party payloads). Never use it on money the user typed —
  /// parse the raw string with [Dec.parse] so no precision is lost upstream.
  factory Dec.fromDouble(double value, {int scale = 8}) {
    if (value.isNaN || value.isInfinite) {
      throw ArgumentError.value(value, 'value', 'must be finite');
    }
    return Dec.parse(value.toStringAsFixed(scale));
  }

  bool get isZero => units == BigInt.zero;
  bool get isNegative => units.isNegative;
  bool get isPositive => units > BigInt.zero;

  /// -1, 0 or 1 according to the sign.
  int get signum => units.isNegative ? -1 : (units == BigInt.zero ? 0 : 1);

  BigInt _unitsAtScale(int targetScale) {
    if (targetScale == scale) return units;
    if (targetScale > scale) return units * _pow10(targetScale - scale);
    return _divideRounded(units, _pow10(scale - targetScale), Rounding.halfUp);
  }

  static int _widerScale(Dec a, Dec b) => a.scale > b.scale ? a.scale : b.scale;

  Dec operator +(Dec other) {
    final target = _widerScale(this, other);
    return Dec._(_unitsAtScale(target) + other._unitsAtScale(target), target);
  }

  Dec operator -(Dec other) {
    final target = _widerScale(this, other);
    return Dec._(_unitsAtScale(target) - other._unitsAtScale(target), target);
  }

  /// Exact multiplication. The result's scale is the sum of the operand
  /// scales, so no precision is discarded here; round at the display boundary.
  Dec operator *(Dec other) =>
      Dec._(units * other.units, scale + other.scale);

  Dec operator -() => Dec._(-units, scale);

  Dec get abs => units.isNegative ? Dec._(-units, scale) : this;

  /// Divides by [other], producing a result at [scale] decimal places.
  ///
  /// Division is the only operation that can lose information, so the target
  /// scale and [rounding] are always explicit. Throws [UnsupportedError] on a
  /// zero divisor — callers in this package guard against undefined metrics
  /// (an R-multiple with no stop, a profit factor with no losses) by returning
  /// `null` rather than a sentinel number.
  Dec divide(Dec other, {int scale = 10, Rounding rounding = Rounding.halfUp}) {
    if (other.isZero) {
      throw UnsupportedError('Division by zero is undefined');
    }
    if (scale < 0) throw ArgumentError.value(scale, 'scale', 'must be >= 0');
    // (a/10^sa) / (b/10^sb) at target scale st
    //   = a * 10^(sb + st) / (b * 10^sa)
    final numerator = units * _pow10(other.scale + scale);
    final denominator = other.units * _pow10(this.scale);
    return Dec._(_divideRounded(numerator, denominator, rounding), scale);
  }

  static BigInt _divideRounded(BigInt numerator, BigInt denominator, Rounding rounding) {
    if (denominator.isNegative) {
      numerator = -numerator;
      denominator = -denominator;
    }
    final quotient = numerator ~/ denominator;
    final remainder = numerator.remainder(denominator);
    if (remainder == BigInt.zero) return quotient;

    final negative = numerator.isNegative;
    switch (rounding) {
      case Rounding.truncate:
        return quotient;
      case Rounding.floor:
        return negative ? quotient - BigInt.one : quotient;
      case Rounding.ceil:
        return negative ? quotient : quotient + BigInt.one;
      case Rounding.halfUp:
      case Rounding.halfEven:
        final twiceRemainder = remainder.abs() * BigInt.two;
        final comparison = twiceRemainder.compareTo(denominator);
        final bool roundAway;
        if (comparison > 0) {
          roundAway = true;
        } else if (comparison < 0) {
          roundAway = false;
        } else if (rounding == Rounding.halfUp) {
          roundAway = true;
        } else {
          roundAway = quotient.isOdd;
        }
        if (!roundAway) return quotient;
        return negative ? quotient - BigInt.one : quotient + BigInt.one;
    }
  }

  /// Returns this value expressed at exactly [newScale] decimal places.
  Dec roundTo(int newScale, [Rounding rounding = Rounding.halfUp]) {
    if (newScale < 0) {
      throw ArgumentError.value(newScale, 'newScale', 'must be >= 0');
    }
    if (newScale == scale) return this;
    if (newScale > scale) {
      return Dec._(units * _pow10(newScale - scale), newScale);
    }
    final divisor = _pow10(scale - newScale);
    return Dec._(_divideRounded(units, divisor, rounding), newScale);
  }

  /// Drops trailing fractional zeros: `1.2500` becomes `1.25`.
  Dec get normalized {
    if (scale == 0 || units == BigInt.zero) {
      return units == BigInt.zero ? Dec._(BigInt.zero, 0) : this;
    }
    var value = units;
    var currentScale = scale;
    final ten = BigInt.from(10);
    while (currentScale > 0 && value.remainder(ten) == BigInt.zero) {
      value = value ~/ ten;
      currentScale--;
    }
    return Dec._(value, currentScale);
  }

  /// This value as a percentage of [total], or `null` when [total] is zero.
  Dec? percentOf(Dec total, {int scale = 4}) {
    if (total.isZero) return null;
    return (this * hundred).divide(total, scale: scale);
  }

  @override
  int compareTo(Dec other) {
    final target = _widerScale(this, other);
    return _unitsAtScale(target).compareTo(other._unitsAtScale(target));
  }

  bool operator <(Dec other) => compareTo(other) < 0;
  bool operator <=(Dec other) => compareTo(other) <= 0;
  bool operator >(Dec other) => compareTo(other) > 0;
  bool operator >=(Dec other) => compareTo(other) >= 0;

  /// Numeric equality — `1.50` equals `1.5` despite the differing scale.
  @override
  bool operator ==(Object other) => other is Dec && compareTo(other) == 0;

  @override
  int get hashCode {
    final n = normalized;
    return Object.hash(n.units, n.scale);
  }

  /// A lossy `double`, for charting and layout only. Never round-trip money
  /// through this.
  double toDouble() => double.parse(toString());

  /// Plain, locale-independent representation such as `-12.3400`.
  @override
  String toString() {
    if (scale == 0) return units.toString();
    final negative = units.isNegative;
    final digits = units.abs().toString().padLeft(scale + 1, '0');
    final integerPart = digits.substring(0, digits.length - scale);
    final fractionPart = digits.substring(digits.length - scale);
    return '${negative ? '-' : ''}$integerPart.$fractionPart';
  }
}

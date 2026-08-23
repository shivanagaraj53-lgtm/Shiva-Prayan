/// Currency metadata and formatting.
///
/// Currency in Prayan is a *display and accounting* preference. The journal
/// never converts between currencies silently: an account is denominated in
/// one currency and every trade booked against it is arithmetic in that same
/// currency. Introducing FX would require a dated rate source and an audit
/// trail, which is deliberately out of MVP scope (brief §5).
library;

/// Where the currency symbol sits relative to the digits.
enum SymbolPosition { before, after }

/// Digit grouping convention.
enum DigitGrouping {
  /// 1,234,567 — groups of three.
  western,

  /// 12,34,567 — the Indian lakh/crore system: three digits, then pairs.
  indian,

  /// 1234567 — no separators.
  none,
}

/// An ISO-4217 currency together with the conventions needed to render it.
class Currency {
  /// ISO-4217 alphabetic code, e.g. `INR`.
  final String code;

  /// Display symbol, e.g. `₹`.
  final String symbol;

  /// A human-readable name for settings screens.
  final String name;

  /// Minor-unit digits. Note JPY is 0 — code must never assume 2.
  final int decimalDigits;

  final SymbolPosition symbolPosition;
  final DigitGrouping grouping;

  const Currency({
    required this.code,
    required this.symbol,
    required this.name,
    required this.decimalDigits,
    this.symbolPosition = SymbolPosition.before,
    this.grouping = DigitGrouping.western,
  });

  static const inr = Currency(
    code: 'INR',
    symbol: '₹',
    name: 'Indian Rupee',
    decimalDigits: 2,
    grouping: DigitGrouping.indian,
  );
  static const usd =
      Currency(code: 'USD', symbol: r'$', name: 'US Dollar', decimalDigits: 2);
  static const eur =
      Currency(code: 'EUR', symbol: '€', name: 'Euro', decimalDigits: 2);
  static const gbp = Currency(
      code: 'GBP', symbol: '£', name: 'Pound Sterling', decimalDigits: 2);
  static const aed = Currency(
      code: 'AED', symbol: 'د.إ', name: 'UAE Dirham', decimalDigits: 2);
  static const sgd = Currency(
      code: 'SGD', symbol: r'S$', name: 'Singapore Dollar', decimalDigits: 2);

  /// Yen has no minor unit — the classic off-by-two bug in money code.
  static const jpy = Currency(
      code: 'JPY', symbol: '¥', name: 'Japanese Yen', decimalDigits: 0);
  static const aud = Currency(
      code: 'AUD', symbol: r'A$', name: 'Australian Dollar', decimalDigits: 2);
  static const cad = Currency(
      code: 'CAD', symbol: r'C$', name: 'Canadian Dollar', decimalDigits: 2);
  static const chf = Currency(
      code: 'CHF', symbol: 'CHF', name: 'Swiss Franc', decimalDigits: 2);
  static const hkd = Currency(
      code: 'HKD', symbol: r'HK$', name: 'Hong Kong Dollar', decimalDigits: 2);
  static const zar = Currency(
      code: 'ZAR', symbol: 'R', name: 'South African Rand', decimalDigits: 2);

  /// Currencies offered in onboarding and settings.
  static const supported = <Currency>[
    inr,
    usd,
    eur,
    gbp,
    aed,
    sgd,
    jpy,
    aud,
    cad,
    chf,
    hkd,
    zar,
  ];

  /// Looks up a supported currency by ISO code.
  ///
  /// Unknown codes fall back to a generic 2-decimal currency rather than
  /// throwing, so a value synced from a newer client build can still render.
  static Currency fromCode(String code) {
    final upper = code.toUpperCase();
    for (final currency in supported) {
      if (currency.code == upper) return currency;
    }
    return Currency(
      code: upper,
      symbol: upper,
      name: upper,
      decimalDigits: 2,
      symbolPosition: SymbolPosition.after,
    );
  }

  /// Applies [grouping] to a run of integer digits.
  String groupDigits(String digits) {
    switch (grouping) {
      case DigitGrouping.none:
        return digits;
      case DigitGrouping.western:
        return _group(digits, headSize: 3, tailSize: 3);
      case DigitGrouping.indian:
        return _group(digits, headSize: 3, tailSize: 2);
    }
  }

  /// Groups the last [headSize] digits, then repeatedly [tailSize] digits.
  ///
  /// With `headSize: 3, tailSize: 2` this yields the Indian system:
  /// `500000` renders as `5,00,000`.
  static String _group(String digits,
      {required int headSize, required int tailSize}) {
    if (digits.length <= headSize) return digits;
    final head = digits.substring(digits.length - headSize);
    var rest = digits.substring(0, digits.length - headSize);
    final parts = <String>[];
    while (rest.length > tailSize) {
      parts.insert(0, rest.substring(rest.length - tailSize));
      rest = rest.substring(0, rest.length - tailSize);
    }
    if (rest.isNotEmpty) parts.insert(0, rest);
    parts.add(head);
    return parts.join(',');
  }

  @override
  bool operator ==(Object other) => other is Currency && other.code == code;

  @override
  int get hashCode => code.hashCode;

  @override
  String toString() => code;
}

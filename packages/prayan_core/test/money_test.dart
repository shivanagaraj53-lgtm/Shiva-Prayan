import 'package:prayan_core/prayan_core.dart';
import 'package:test/test.dart';

void main() {
  group('Currency formatting', () {
    test('groups INR in the lakh/crore system', () {
      final amount = Money.parse('500000', Currency.inr);
      expect(amount.format(), '₹5,00,000.00');
    });

    test('formats the brief\'s worked-example equity', () {
      expect(Money.parse('500000', Currency.inr).format(), '₹5,00,000.00');
      expect(
          Money.parse('12345678.5', Currency.inr).format(), '₹1,23,45,678.50');
    });

    test('groups USD in threes', () {
      expect(
          Money.parse('1234567.89', Currency.usd).format(), r'$1,234,567.89');
    });

    test('respects JPY having no minor unit', () {
      expect(Money.parse('1234.6', Currency.jpy).format(), '¥1,235');
      expect(Currency.jpy.decimalDigits, 0);
    });

    test('places the symbol after the amount when the currency requires it',
        () {
      final unknown = Currency.fromCode('XYZ');
      expect(Money.parse('10', unknown).format(), '10.00 XYZ');
      // A non-breaking space keeps the code from wrapping away from the
      // digits, so the assertion names the code point explicitly.
      expect(Money.parse('10', unknown).format().codeUnitAt(5), 0x00A0);
    });

    test('shows an explicit sign so gains and losses do not rely on colour',
        () {
      expect(
          Money.parse('250', Currency.usd).format(showSign: true), r'+$250.00');
      expect(Money.parse('-250', Currency.usd).format(showSign: true),
          r'-$250.00');
      expect(Money.zero(Currency.usd).format(showSign: true), r'$0.00');
    });

    test('compacts large values per currency convention', () {
      expect(
          Money.parse('2500000', Currency.inr).format(compact: true), '₹25L');
      expect(Money.parse('35000000', Currency.inr).format(compact: true),
          '₹3.5Cr');
      expect(
          Money.parse('2500000', Currency.usd).format(compact: true), r'$2.5M');
      expect(Money.parse('1500', Currency.usd).format(compact: true), r'$1.5K');
    });

    test('unknown currency codes degrade gracefully instead of throwing', () {
      final currency = Currency.fromCode('zzz');
      expect(currency.code, 'ZZZ');
      expect(currency.decimalDigits, 2);
    });
  });

  group('Money arithmetic', () {
    test('adds and subtracts within one currency', () {
      final a = Money.parse('100.25', Currency.usd);
      final b = Money.parse('50.75', Currency.usd);
      expect((a + b).format(), r'$151.00');
      expect((a - b).format(), r'$49.50');
      expect((-a).format(), r'-$100.25');
    });

    test('refuses to combine different currencies', () {
      final rupees = Money.parse('100', Currency.inr);
      final dollars = Money.parse('100', Currency.usd);
      expect(() => rupees + dollars, throwsA(isA<CurrencyMismatchError>()));
      expect(() => rupees.compareTo(dollars),
          throwsA(isA<CurrencyMismatchError>()));
    });

    test('keeps working precision then rounds only at display', () {
      // A per-unit fee of 0.0125 on 3 units is 0.0375, which must not round
      // to zero mid-calculation.
      final fee = Money.parse('0.0125', Currency.usd).scaleBy(Dec.fromInt(3));
      expect(fee.amount, Dec.parse('0.0375'));
      expect(fee.format(), r'$0.04');
    });

    test('ratioTo returns null rather than infinity on a zero divisor', () {
      final profit = Money.parse('500', Currency.usd);
      expect(profit.ratioTo(Money.zero(Currency.usd)), isNull);
      expect(profit.ratioTo(Money.parse('250', Currency.usd)), Dec.parse('2'));
    });

    test('sums a list', () {
      final total = Money.sum([
        Money.parse('10', Currency.usd),
        Money.parse('20.5', Currency.usd),
        Money.parse('-5.5', Currency.usd),
      ], Currency.usd);
      expect(total.format(), r'$25.00');
      expect(Money.sum(const [], Currency.usd).isZero, isTrue);
    });
  });
}

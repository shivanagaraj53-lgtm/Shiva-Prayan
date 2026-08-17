import 'package:prayan_core/prayan_core.dart';
import 'package:test/test.dart';

void main() {
  group('Dec parsing', () {
    test('parses plain decimals and preserves scale', () {
      final value = Dec.parse('12.3400');
      expect(value.toString(), '12.3400');
      expect(value.scale, 4);
    });

    test('parses negatives, leading dots and grouping separators', () {
      expect(Dec.parse('-0.5').toString(), '-0.5');
      expect(Dec.parse('.75').toString(), '0.75');
      expect(Dec.parse('5,00,000').toString(), '500000');
      expect(Dec.parse('1,234,567.89').toString(), '1234567.89');
    });

    test('parses scientific notation', () {
      expect(Dec.parse('1.5e3'), Dec.parse('1500'));
      expect(Dec.parse('1.5e-2'), Dec.parse('0.015'));
    });

    test('rejects malformed input', () {
      expect(Dec.tryParse('abc'), isNull);
      expect(Dec.tryParse('1.2.3'), isNull);
      expect(Dec.tryParse(''), isNull);
      expect(Dec.tryParse('  '), isNull);
      expect(() => Dec.parse('nope'), throwsFormatException);
    });
  });

  group('Dec arithmetic is exact', () {
    test('0.1 + 0.2 == 0.3 exactly, unlike binary floating point', () {
      final sum = Dec.parse('0.1') + Dec.parse('0.2');
      expect(sum, Dec.parse('0.3'));
      expect(sum.toString(), '0.3');
      // The bug this type exists to prevent:
      expect(0.1 + 0.2 == 0.3, isFalse);
    });

    test('accumulates a thousand fractional values without drift', () {
      var total = Dec.zero;
      for (var i = 0; i < 1000; i++) {
        total += Dec.parse('0.07');
      }
      expect(total, Dec.parse('70'));
    });

    test('multiplication keeps full precision', () {
      final product = Dec.parse('1.05') * Dec.parse('2.5');
      expect(product, Dec.parse('2.625'));
      expect(product.scale, 3);
    });

    test('subtraction across differing scales aligns correctly', () {
      expect(Dec.parse('10') - Dec.parse('0.001'), Dec.parse('9.999'));
    });

    test('handles very large magnitudes without overflow', () {
      final big = Dec.parse('99999999999999999999.99');
      expect((big + Dec.parse('0.01')).toString(), '100000000000000000000.00');
    });
  });

  group('Dec division and rounding', () {
    test('division requires an explicit scale', () {
      expect(Dec.parse('1').divide(Dec.parse('3'), scale: 5),
          Dec.parse('0.33333'));
    });

    test('half-up rounds ties away from zero', () {
      expect(Dec.parse('2.5').roundTo(0), Dec.parse('3'));
      expect(Dec.parse('-2.5').roundTo(0), Dec.parse('-3'));
      expect(Dec.parse('2.4').roundTo(0), Dec.parse('2'));
    });

    test('half-even rounds ties to the nearest even digit', () {
      expect(Dec.parse('2.5').roundTo(0, Rounding.halfEven), Dec.parse('2'));
      expect(Dec.parse('3.5').roundTo(0, Rounding.halfEven), Dec.parse('4'));
    });

    test('floor, ceil and truncate behave on both signs', () {
      expect(Dec.parse('-1.1').roundTo(0, Rounding.floor), Dec.parse('-2'));
      expect(Dec.parse('-1.1').roundTo(0, Rounding.ceil), Dec.parse('-1'));
      expect(Dec.parse('-1.9').roundTo(0, Rounding.truncate), Dec.parse('-1'));
      expect(Dec.parse('1.9').roundTo(0, Rounding.truncate), Dec.parse('1'));
    });

    test('dividing by zero throws rather than returning a sentinel', () {
      expect(() => Dec.one.divide(Dec.zero), throwsUnsupportedError);
    });

    test('negative division rounds symmetrically', () {
      expect(Dec.parse('-1').divide(Dec.parse('3'), scale: 4),
          Dec.parse('-0.3333'));
    });
  });

  group('Dec comparison and equality', () {
    test('equality is numeric, not representational', () {
      expect(Dec.parse('1.50'), Dec.parse('1.5'));
      expect(Dec.parse('1.50').hashCode, Dec.parse('1.5').hashCode);
    });

    test('ordering works across scales and signs', () {
      expect(Dec.parse('1.5') > Dec.parse('1.49999'), isTrue);
      expect(Dec.parse('-2') < Dec.parse('-1.9'), isTrue);
      expect(Dec.parse('0.0') >= Dec.zero, isTrue);
    });

    test('signum and sign helpers', () {
      expect(Dec.parse('-3').signum, -1);
      expect(Dec.zero.signum, 0);
      expect(Dec.parse('0.0001').isPositive, isTrue);
      expect(Dec.parse('-0.5').abs, Dec.parse('0.5'));
    });
  });

  group('Dec helpers', () {
    test('normalized strips trailing zeros', () {
      expect(Dec.parse('1.2500').normalized.toString(), '1.25');
      expect(Dec.parse('5.000').normalized.toString(), '5');
      expect(Dec.parse('0.000').normalized.toString(), '0');
    });

    test('percentOf computes a percentage and guards zero', () {
      expect(Dec.parse('25').percentOf(Dec.parse('200')), Dec.parse('12.5'));
      expect(Dec.parse('25').percentOf(Dec.zero), isNull);
    });

    test('fromDouble bounds the imprecision it inherits', () {
      expect(Dec.fromDouble(0.1, scale: 2), Dec.parse('0.10'));
      expect(() => Dec.fromDouble(double.nan), throwsArgumentError);
    });
  });
}

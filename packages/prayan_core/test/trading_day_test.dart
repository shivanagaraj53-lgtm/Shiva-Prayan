import 'package:prayan_core/prayan_core.dart';
import 'package:test/test.dart';

void main() {
  group('Day bucketing', () {
    test('an Indian morning trade lands on the local calendar day', () {
      // 09:15 IST on 16 March is 03:45 UTC the same day.
      final instant = DateTime.utc(2026, 3, 16, 3, 45);
      expect(TradingDay.keyFor(instant, TradingDayConfig.ist), '2026-03-16');
    });

    test('a late-evening local trade does not roll into tomorrow', () {
      // 23:30 IST on 16 March is 18:00 UTC the same day.
      final instant = DateTime.utc(2026, 3, 16, 18, 0);
      expect(TradingDay.keyFor(instant, TradingDayConfig.ist), '2026-03-16');
      // Bucketing by raw UTC would have been correct here by luck, so also
      // check the case that actually breaks: 00:30 IST on the 17th.
      final afterMidnight = DateTime.utc(2026, 3, 16, 19, 0);
      expect(
          TradingDay.keyFor(afterMidnight, TradingDayConfig.ist), '2026-03-17');
    });

    test('a US evening trade belongs to the local day, not the UTC one', () {
      // 20:00 on 16 March in UTC-5 is 01:00 UTC on the 17th.
      const newYorkWinter = TradingDayConfig(utcOffsetMinutes: -300);
      final instant = DateTime.utc(2026, 3, 17, 1, 0);
      expect(TradingDay.keyFor(instant, newYorkWinter), '2026-03-16');
    });

    test('a daylight-saving shift is handled by the offset in effect', () {
      // The caller supplies the offset live at that instant, so the same wall
      // clock before and after a DST change maps to the right day either way.
      const winter = TradingDayConfig(utcOffsetMinutes: -300); // EST
      const summer = TradingDayConfig(utcOffsetMinutes: -240); // EDT
      final beforeDst = DateTime.utc(2026, 3, 7, 2, 30); // 21:30 EST on the 6th
      final afterDst =
          DateTime.utc(2026, 3, 14, 1, 30); // 21:30 EDT on the 13th
      expect(TradingDay.keyFor(beforeDst, winter), '2026-03-06');
      expect(TradingDay.keyFor(afterDst, summer), '2026-03-13');
    });

    test('a custom session start shifts the day boundary', () {
      // A futures trader whose day starts at 18:00 the previous evening.
      const eveningStart =
          TradingDayConfig(utcOffsetMinutes: 0, dayStartMinutes: -360);
      // 19:00 UTC on the 16th belongs to the 17th's session.
      expect(TradingDay.keyFor(DateTime.utc(2026, 3, 16, 19), eveningStart),
          '2026-03-17');
      // 17:00 UTC is still the 16th.
      expect(TradingDay.keyFor(DateTime.utc(2026, 3, 16, 17), eveningStart),
          '2026-03-16');
    });
  });

  group('Round-tripping', () {
    test('the UTC range for a day contains its own trades and no others', () {
      const config = TradingDayConfig.ist;
      final (start, end) = TradingDay.utcRangeFor('2026-03-16', config);

      final firstMoment = start;
      final lastMoment = end.subtract(const Duration(milliseconds: 1));
      expect(TradingDay.keyFor(firstMoment, config), '2026-03-16');
      expect(TradingDay.keyFor(lastMoment, config), '2026-03-16');
      // One millisecond outside the range belongs to a neighbouring day.
      expect(
          TradingDay.keyFor(
              start.subtract(const Duration(milliseconds: 1)), config),
          '2026-03-15');
      expect(TradingDay.keyFor(end, config), '2026-03-17');
    });

    test('the range is exactly 24 hours', () {
      final (start, end) =
          TradingDay.utcRangeFor('2026-03-16', TradingDayConfig.ist);
      expect(end.difference(start), const Duration(days: 1));
    });
  });

  group('Key helpers', () {
    test('parses and formats', () {
      expect(TradingDay.parseKey('2026-03-16'), DateTime.utc(2026, 3, 16));
      expect(TradingDay.format(DateTime.utc(2026, 3, 6)), '2026-03-06');
    });

    test('rejects malformed keys without throwing', () {
      expect(TradingDay.parseKey('not-a-date'), isNull);
      expect(TradingDay.parseKey('2026-13-40'), isNull);
      expect(TradingDay.parseKey('2026-03'), isNull);
    });

    test('month keys', () {
      expect(TradingDay.monthKeyFor('2026-03-16'), '2026-03');
    });

    test('week keys group a Monday-to-Friday run together', () {
      // 2026-03-16 is a Monday; the 20th is that Friday.
      final monday = TradingDay.weekKeyFor('2026-03-16');
      expect(TradingDay.weekKeyFor('2026-03-20'), monday);
      // The following Monday is a different week.
      expect(TradingDay.weekKeyFor('2026-03-23'), isNot(monday));
    });

    test('ranges enumerate every day inclusive of both ends', () {
      final keys = TradingDay.range('2026-03-01', '2026-03-05');
      expect(keys, [
        '2026-03-01',
        '2026-03-02',
        '2026-03-03',
        '2026-03-04',
        '2026-03-05',
      ]);
      expect(TradingDay.range('2026-03-05', '2026-03-01'), isEmpty);
    });

    test('a range spanning a month boundary is continuous', () {
      final keys = TradingDay.range('2026-02-27', '2026-03-02');
      expect(keys, [
        '2026-02-27',
        '2026-02-28',
        '2026-03-01',
        '2026-03-02',
      ]);
    });

    test('a leap-year February is handled', () {
      final keys = TradingDay.range('2028-02-27', '2028-03-01');
      expect(keys, contains('2028-02-29'));
    });
  });
}

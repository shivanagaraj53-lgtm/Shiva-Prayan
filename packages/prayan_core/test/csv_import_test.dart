import 'package:prayan_core/prayan_core.dart';
import 'package:test/test.dart';

/// Importing a broker's CSV.
///
/// An import that guesses wrong is worse than one that imports nothing: the
/// wrong number becomes history and is indistinguishable from something the
/// user typed. So most of what follows is about what this refuses to do.
void main() {
  const ist = TradingDayConfig(utcOffsetMinutes: 330);
  final fallback = DateTime.utc(2026, 8, 23, 4);

  group('reading numbers a human wrote', () {
    test('thousands separators and currency symbols', () {
      expect(CsvImporter.number('₹1,234.50'), Dec.parse('1234.50'));
      expect(CsvImporter.number(' \$2,000 '), Dec.parse('2000'));
      expect(CsvImporter.number('1 234,00'.replaceAll(',', '.')),
          Dec.parse('1234.00'));
    });

    test('the several ways a negative is written', () {
      expect(CsvImporter.number('(250.25)'), Dec.parse('-250.25'));
      expect(CsvImporter.number('250.25-'), Dec.parse('-250.25'));
      expect(CsvImporter.number('-250.25'), Dec.parse('-250.25'));
    });

    test('nothing usable returns null rather than zero', () {
      // Zero is a number a broker might mean. Null is the absence of one, and
      // conflating them turns a missing fee into a fee of nothing.
      for (final junk in ['', '  ', '-', '.', 'N/A', 'â€”']) {
        expect(CsvImporter.number(junk), isNull, reason: 'parsed "$junk"');
      }
    });

    test('precision survives — this is money', () {
      expect(CsvImporter.number('0.1').toString(), '0.1');
      expect(CsvImporter.number('1234.567890'), Dec.parse('1234.567890'));
    });
  });

  group('buy or sell', () {
    test('the usual spellings', () {
      for (final long in ['Buy', 'B', 'BOUGHT', 'long', 'Buy to Open']) {
        expect(CsvImporter.direction(long), TradeDirection.long, reason: long);
      }
      for (final short in ['Sell', 'S', 'SOLD', 'short', 'Sell to Open']) {
        expect(CsvImporter.direction(short), TradeDirection.short,
            reason: short);
      }
    });

    test('something unrecognised is not silently a buy', () {
      expect(CsvImporter.direction('transfer'), isNull);
      expect(CsvImporter.direction(''), isNull);
    });
  });

  group('the date-order trap', () {
    test('a component over twelve proves the order', () {
      expect(CsvImporter.proveDateOrder(['31/12/2026']), DateOrder.dayFirst);
      expect(CsvImporter.proveDateOrder(['12/31/2026']), DateOrder.monthFirst);
    });

    test('an ambiguous file proves nothing, and says so', () {
      // 01/02/2026 is two valid dates. Picking one silently would rewrite
      // every date in the file, and nothing downstream could tell.
      expect(CsvImporter.proveDateOrder(['01/02/2026', '03/04/2026']), isNull);
    });

    test('the same file read both ways gives different days', () {
      final dayFirst =
          CsvImporter.dateTime('01/02/2026 09:30', DateOrder.dayFirst, ist);
      final monthFirst =
          CsvImporter.dateTime('01/02/2026 09:30', DateOrder.monthFirst, ist);
      expect(dayFirst, isNot(monthFirst));
      expect(TradingDay.keyFor(dayFirst!, ist), '2026-02-01');
      expect(TradingDay.keyFor(monthFirst!, ist), '2026-01-02');
    });
  });

  group('reading a date', () {
    test('ISO with a zone is taken at its word', () {
      expect(
        CsvImporter.dateTime('2026-08-23T09:15:00Z', DateOrder.dayFirst, ist),
        DateTime.utc(2026, 8, 23, 9, 15),
      );
    });

    test('a time with no zone is local, not UTC', () {
      // The difference is a whole trading day for anyone far enough east.
      final parsed =
          CsvImporter.dateTime('2026-08-23 09:15', DateOrder.dayFirst, ist);
      expect(parsed, DateTime.utc(2026, 8, 23, 3, 45));
      expect(TradingDay.keyFor(parsed!, ist), '2026-08-23');
    });

    test('a date that does not exist is refused, not rolled over', () {
      // DateTime would happily turn 31 February into 3 March.
      expect(
          CsvImporter.dateTime('31/02/2026', DateOrder.dayFirst, ist), isNull);
      expect(
          CsvImporter.dateTime('13/13/2026', DateOrder.dayFirst, ist), isNull);
    });

    test('two-digit years are this century', () {
      final parsed = CsvImporter.dateTime('23/08/26', DateOrder.dayFirst, ist);
      expect(parsed!.year, 2026);
    });
  });

  group('mapping columns', () {
    test('common headers are found', () {
      final mapping = ColumnMapping.detect(
        ['Symbol', 'Side', 'Qty', 'Entry Price', 'Exit Price', 'Brokerage'],
      );
      expect(mapping.indexOf(ImportField.symbol), 0);
      expect(mapping.indexOf(ImportField.side), 1);
      expect(mapping.indexOf(ImportField.quantity), 2);
      expect(mapping.indexOf(ImportField.entryPrice), 3);
      expect(mapping.indexOf(ImportField.exitPrice), 4);
      expect(mapping.indexOf(ImportField.fees), 5);
    });

    test('a longer alias wins over a shorter one it contains', () {
      // With "Price" and "Entry Price" both present, the bare one must not
      // claim the entry field and leave the real column unmapped.
      final mapping = ColumnMapping.detect(['Price', 'Entry Price', 'Qty']);
      expect(mapping.indexOf(ImportField.entryPrice), 1);
    });

    test('an unrecognised file maps nothing rather than guessing', () {
      final mapping = ColumnMapping.detect(['col_a', 'col_b', 'col_c']);
      expect(mapping.hasRequired, isFalse);
      expect(mapping.missingRequired, contains(ImportField.symbol));
    });

    test('assigning a column to a second field moves it', () {
      var mapping = const ColumnMapping({ImportField.symbol: 0});
      mapping = mapping.withField(ImportField.note, 0);
      expect(mapping.indexOf(ImportField.symbol), isNull);
      expect(mapping.indexOf(ImportField.note), 0);
    });
  });

  group('reading a file', () {
    const mapping = ColumnMapping({
      ImportField.symbol: 0,
      ImportField.side: 1,
      ImportField.quantity: 2,
      ImportField.entryPrice: 3,
      ImportField.exitPrice: 4,
      ImportField.openedAt: 5,
    });

    ImportPreview read(List<List<String>> rows,
            {Set<String> existing = const {}}) =>
        CsvImporter.read(
          rows: rows,
          mapping: mapping,
          dateOrder: DateOrder.dayFirst,
          config: ist,
          fallbackTime: fallback,
          existingFingerprints: existing,
        );

    test('a good row becomes a trade', () {
      final preview = read([
        ['INFY', 'Buy', '200', '1580', '1642', '23/08/2026 09:20'],
      ]);
      expect(preview.problems, isEmpty);
      expect(preview.importable, 1);
      final row = preview.rows.single;
      expect(row.symbol, 'INFY');
      expect(row.direction, TradeDirection.long);
      expect(row.entryPrice, Dec.parse('1580'));
      expect(row.exitPrice, Dec.parse('1642'));
    });

    test('a bad row is reported by line, not dropped', () {
      // Silently skipping is how an import loses half a file and nobody
      // notices until the numbers stop adding up.
      final preview = read([
        ['INFY', 'Buy', '200', '1580', '', '23/08/2026'],
        ['', 'Buy', '10', '100', '', '23/08/2026'],
        ['TCS', 'Buy', 'many', '100', '', '23/08/2026'],
        ['WIPRO', 'Buy', '10', '100', '', 'not a date'],
      ]);
      expect(preview.importable, 1);
      expect(preview.problems, hasLength(3));
      expect(preview.problems.map((p) => p.line), [3, 4, 5],
          reason: 'lines count the header, so they match a spreadsheet');
      expect(preview.problems[0].message, contains('instrument'));
    });

    test('blank rows are skipped without being called problems', () {
      final preview = read([
        ['INFY', 'Buy', '200', '1580', '', '23/08/2026'],
        ['', '', '', '', '', ''],
      ]);
      expect(preview.importable, 1);
      expect(preview.problems, isEmpty);
    });

    test('an exit before its entry is refused', () {
      final withClose = const ColumnMapping({
        ImportField.symbol: 0,
        ImportField.quantity: 1,
        ImportField.entryPrice: 2,
        ImportField.openedAt: 3,
        ImportField.closedAt: 4,
      });
      final preview = CsvImporter.read(
        rows: [
          ['INFY', '10', '100', '23/08/2026 10:00', '23/08/2026 09:00'],
        ],
        mapping: withClose,
        dateOrder: DateOrder.dayFirst,
        config: ist,
        fallbackTime: fallback,
      );
      expect(preview.importable, 0);
      expect(preview.problems.single.message, contains('before'));
    });

    test('re-importing an overlapping export skips what is already there', () {
      // Brokers hand out "last 90 days" and people import monthly.
      final first = read([
        ['INFY', 'Buy', '200', '1580', '1642', '23/08/2026 09:20'],
      ]);
      final again = read(
        [
          ['INFY', 'Buy', '200', '1580', '1642', '23/08/2026 09:20'],
          ['TCS', 'Buy', '50', '3900', '', '24/08/2026 09:20'],
        ],
        existing: {first.rows.single.fingerprint},
      );
      expect(again.importable, 1);
      expect(again.rows.single.symbol, 'TCS');
      expect(again.duplicates, hasLength(1));
    });

    test('a file that repeats a row does not import it twice', () {
      final preview = read([
        ['INFY', 'Buy', '200', '1580', '1642', '23/08/2026 09:20'],
        ['INFY', 'Buy', '200', '1580', '1642', '23/08/2026 09:20'],
      ]);
      expect(preview.importable, 1);
      expect(preview.duplicates, hasLength(1));
    });

    test('two trades in the same instrument on the same day are both kept', () {
      // Same symbol, same day, different entry — scaling in is not a
      // duplicate, and a fingerprint that collapsed them would quietly delete
      // half of someone's session.
      final preview = read([
        ['INFY', 'Buy', '200', '1580', '1642', '23/08/2026 09:20'],
        ['INFY', 'Buy', '200', '1585', '1642', '23/08/2026 10:05'],
      ]);
      expect(preview.importable, 2);
      expect(preview.duplicates, isEmpty);
    });

    test('a missing date falls back rather than failing the row', () {
      final noDate = const ColumnMapping({
        ImportField.symbol: 0,
        ImportField.quantity: 1,
        ImportField.entryPrice: 2,
      });
      final preview = CsvImporter.read(
        rows: [
          ['INFY', '10', '100'],
        ],
        mapping: noDate,
        dateOrder: DateOrder.dayFirst,
        config: ist,
        fallbackTime: fallback,
      );
      expect(preview.importable, 1);
      expect(preview.rows.single.openedAtUtc, fallback);
    });
  });
}

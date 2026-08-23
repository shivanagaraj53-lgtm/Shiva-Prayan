import 'package:csv/csv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prayan_core/prayan_core.dart';

/// A real CSV, through the real decoder, into trades.
///
/// The domain tests take rows that are already split. This one starts from
/// text, because the split is where quoting lives: a note containing a comma,
/// a price in quotes, a symbol with a leading zero. Every one of those is
/// ordinary in a broker export and every one of them corrupts a journal
/// quietly if it is handled wrong.
void main() {
  const ist = TradingDayConfig(utcOffsetMinutes: 330);
  final fallback = DateTime.utc(2026, 8, 23, 4);

  List<List<String>> split(String text) =>
      const CsvDecoder(dynamicTyping: false)
          .convert(text.replaceAll('\r\n', '\n'))
          .map((r) => r.map((c) => '${c ?? ''}').toList(growable: false))
          .toList(growable: false);

  test('a quoted note containing commas does not shift the columns', () {
    // The classic. One unescaped comma and every column after it is wrong,
    // which shows up as a price in the quantity field rather than as an error.
    const text = 'Symbol,Qty,Entry Price,Note\n'
        'INFY,200,1580,"Broke out, then retested"\n';
    final table = split(text);
    final mapping = ColumnMapping.detect(table.first);
    final preview = CsvImporter.read(
      rows: table.skip(1).toList(),
      mapping: mapping,
      dateOrder: DateOrder.dayFirst,
      config: ist,
      fallbackTime: fallback,
    );

    expect(preview.problems, isEmpty);
    final row = preview.rows.single;
    expect(row.symbol, 'INFY');
    expect(row.quantity, Dec.parse('200'));
    expect(row.entryPrice, Dec.parse('1580'));
    expect(row.note, 'Broke out, then retested');
  });

  test('a quoted thousands separator survives as a number', () {
    const text = 'Symbol,Qty,Entry Price\nRELIANCE,10,"2,450.75"\n';
    final table = split(text);
    final preview = CsvImporter.read(
      rows: table.skip(1).toList(),
      mapping: ColumnMapping.detect(table.first),
      dateOrder: DateOrder.dayFirst,
      config: ist,
      fallbackTime: fallback,
    );
    expect(preview.rows.single.entryPrice, Dec.parse('2450.75'));
  });

  test('a leading-zero symbol is not turned into a number', () {
    // Hong Kong tickers look like 0700. Typed as a number that becomes 700,
    // and the journal now holds a different instrument.
    const text = 'Symbol,Qty,Entry Price\n0700,100,320\n';
    final table = split(text);
    final preview = CsvImporter.read(
      rows: table.skip(1).toList(),
      mapping: ColumnMapping.detect(table.first),
      dateOrder: DateOrder.dayFirst,
      config: ist,
      fallbackTime: fallback,
    );
    expect(preview.rows.single.symbol, '0700');
  });

  test('a full export maps, reads and reports in one pass', () {
    const text =
        'Trade Date,Symbol,Side,Quantity,Entry Price,Exit Price,Brokerage\n'
        '23/08/2026 09:20,INFY,BUY,200,1580.00,1642.00,45.50\n'
        '23/08/2026 11:05,TCS,SELL,50,3900.00,3860.00,32.00\n'
        ',BADROW,BUY,,100,,0\n'
        '24/08/2026 09:15,WIPRO,BUY,300,410.25,,18.00\n';

    final table = split(text);
    final mapping = ColumnMapping.detect(table.first);
    expect(mapping.hasRequired, isTrue);

    final dateColumn = mapping.indexOf(ImportField.openedAt)!;
    final proven = CsvImporter.proveDateOrder(
      table
          .skip(1)
          .where((r) => dateColumn < r.length)
          .map((r) => r[dateColumn]),
    );
    expect(proven, DateOrder.dayFirst, reason: '23 and 24 can only be days');

    final preview = CsvImporter.read(
      rows: table.skip(1).toList(),
      mapping: mapping,
      dateOrder: proven!,
      config: ist,
      fallbackTime: fallback,
    );

    expect(preview.importable, 3);
    expect(preview.problems, hasLength(1));
    expect(preview.problems.single.line, 4,
        reason: 'the row with no quantity, counted as a spreadsheet would');

    final infy = preview.rows.first;
    expect(infy.direction, TradeDirection.long);
    expect(infy.fees, Dec.parse('45.50'));
    expect(TradingDay.keyFor(infy.openedAtUtc, ist), '2026-08-23');

    final tcs = preview.rows[1];
    expect(tcs.direction, TradeDirection.short);

    final wipro = preview.rows[2];
    expect(wipro.exitPrice, isNull, reason: 'no exit price means still open');
  });

  test('the same export imported twice adds nothing the second time', () {
    const text = 'Trade Date,Symbol,Side,Quantity,Entry Price\n'
        '23/08/2026 09:20,INFY,BUY,200,1580.00\n';
    final table = split(text);
    final mapping = ColumnMapping.detect(table.first);

    ImportPreview run(Set<String> existing) => CsvImporter.read(
          rows: table.skip(1).toList(),
          mapping: mapping,
          dateOrder: DateOrder.dayFirst,
          config: ist,
          fallbackTime: fallback,
          existingFingerprints: existing,
        );

    final first = run({});
    expect(first.importable, 1);

    final second = run({first.rows.single.fingerprint});
    expect(second.importable, 0);
    expect(second.duplicates, hasLength(1));
  });
}

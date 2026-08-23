import '../models/enums.dart';
import '../money/dec.dart';
import '../util/trading_day.dart';

/// Importing a broker's CSV export.
///
/// Every broker exports something different, so nothing here assumes a format.
/// The caller supplies rows already split from the file; this decides what the
/// columns mean, what each row says, and — the part that matters most — which
/// rows it refuses to guess at.
///
/// A journal is a record. An import that silently guesses wrong is worse than
/// one that imports nothing, because the wrong number is now history and looks
/// exactly like something the user typed.

/// A field an imported row can supply.
enum ImportField {
  symbol('Instrument'),
  side('Long or short'),
  quantity('Quantity'),
  entryPrice('Entry price'),
  exitPrice('Exit price'),
  fees('Fees'),
  openedAt('Entry time'),
  closedAt('Exit time'),
  note('Note');

  const ImportField(this.label);
  final String label;

  /// Without these a row is not a trade.
  static const required = [
    ImportField.symbol,
    ImportField.quantity,
    ImportField.entryPrice,
  ];

  /// Header names seen in the wild, lower-cased. Matched by containment, so
  /// "Avg. Entry Price" finds "entry price".
  List<String> get aliases => switch (this) {
        ImportField.symbol => [
            'symbol',
            'ticker',
            'instrument',
            'scrip',
            'contract',
            'stock',
            'security',
          ],
        ImportField.side => [
            'side',
            'direction',
            'buy/sell',
            'b/s',
            'action',
            'transaction type',
            'trade type',
            'type',
          ],
        ImportField.quantity => [
            'quantity',
            'qty',
            'size',
            'shares',
            'lots',
            'volume',
            'filled',
            'units',
          ],
        ImportField.entryPrice => [
            'entry price',
            'avg entry',
            'entry',
            'buy price',
            'open price',
            'opening price',
            'avg. price',
            'average price',
            'price',
          ],
        ImportField.exitPrice => [
            'exit price',
            'avg exit',
            'exit',
            'sell price',
            'close price',
            'closing price',
          ],
        ImportField.fees => [
            'fees',
            'fee',
            'commission',
            'brokerage',
            'charges',
            'taxes',
            'tax',
          ],
        ImportField.openedAt => [
            'entry time',
            'entry date',
            'open time',
            'opened',
            'trade date',
            'date/time',
            'datetime',
            'date',
            'time',
          ],
        ImportField.closedAt => [
            'exit time',
            'exit date',
            'close time',
            'closed',
          ],
        ImportField.note => ['note', 'notes', 'comment', 'remarks', 'reason'],
      };
}

/// How to read `01/02/2026`.
///
/// The single most dangerous ambiguity in any trade import: the same file read
/// day-first or month-first produces two different journals, both plausible,
/// and nothing downstream can tell they are wrong.
enum DateOrder {
  dayFirst('Day first', '31/12/2026'),
  monthFirst('Month first', '12/31/2026');

  const DateOrder(this.label, this.example);
  final String label;
  final String example;
}

/// Which column supplies which field. Absent means the field is not imported.
class ColumnMapping {
  final Map<ImportField, int> columns;
  const ColumnMapping(this.columns);

  int? indexOf(ImportField field) => columns[field];

  bool get hasRequired =>
      ImportField.required.every((f) => columns.containsKey(f));

  List<ImportField> get missingRequired =>
      ImportField.required.where((f) => !columns.containsKey(f)).toList();

  ColumnMapping withField(ImportField field, int? index) {
    final next = Map<ImportField, int>.from(columns);
    if (index == null) {
      next.remove(field);
    } else {
      // One column cannot be two fields; assigning it moves it.
      next.removeWhere((_, value) => value == index);
      next[field] = index;
    }
    return ColumnMapping(next);
  }

  /// Best guess from a header row.
  ///
  /// Longer aliases are tried first so "entry price" wins over "price" on a
  /// file that has both — otherwise the first column containing "price" claims
  /// the field and the real one is left unmapped.
  static ColumnMapping detect(List<String> headers) {
    final normalised =
        headers.map((h) => h.toLowerCase().trim()).toList(growable: false);
    final found = <ImportField, int>{};
    final taken = <int>{};

    for (final field in ImportField.values) {
      final aliases = [...field.aliases]
        ..sort((a, b) => b.length.compareTo(a.length));
      for (final alias in aliases) {
        final index = normalised.indexWhere(
          (h) => h == alias || h.contains(alias),
        );
        if (index >= 0 && !taken.contains(index)) {
          found[field] = index;
          taken.add(index);
          break;
        }
      }
    }
    return ColumnMapping(found);
  }
}

/// Why a row could not be imported.
class RowProblem {
  /// 1-based, counting the header, so it matches what a spreadsheet shows.
  final int line;
  final String message;
  const RowProblem(this.line, this.message);

  @override
  String toString() => 'Line $line: $message';
}

/// One row, understood.
class ImportedRow {
  final int line;
  final String symbol;
  final TradeDirection direction;
  final Dec quantity;
  final Dec entryPrice;
  final Dec? exitPrice;
  final Dec? fees;
  final DateTime openedAtUtc;
  final DateTime? closedAtUtc;
  final String? note;

  const ImportedRow({
    required this.line,
    required this.symbol,
    required this.direction,
    required this.quantity,
    required this.entryPrice,
    required this.openedAtUtc,
    this.exitPrice,
    this.fees,
    this.closedAtUtc,
    this.note,
  });

  /// Identifies this trade regardless of which file it arrived in.
  ///
  /// Re-importing an export that overlaps the last one is normal — brokers
  /// hand out "last 90 days" and people import monthly. Matching on the values
  /// that describe the trade means the overlap is skipped rather than
  /// duplicated.
  String get fingerprint => [
        symbol.toUpperCase(),
        direction.wireName,
        openedAtUtc.toIso8601String(),
        entryPrice.toString(),
        quantity.toString(),
      ].join('|');
}

class ImportPreview {
  final List<ImportedRow> rows;
  final List<RowProblem> problems;

  /// Rows that match a trade already in the journal.
  final List<ImportedRow> duplicates;

  const ImportPreview({
    required this.rows,
    required this.problems,
    this.duplicates = const [],
  });

  int get importable => rows.length;
}

class CsvImporter {
  const CsvImporter._();

  /// Reads a number that a broker wrote for humans.
  ///
  /// Thousands separators, currency symbols, a trailing minus, parentheses for
  /// negatives — all of it appears in real exports, and `Dec.tryParse` should
  /// not have to know about any of it.
  static Dec? number(String raw) {
    var value = raw.trim();
    if (value.isEmpty) return null;

    var negative = false;
    if (value.startsWith('(') && value.endsWith(')')) {
      negative = true;
      value = value.substring(1, value.length - 1);
    }
    if (value.endsWith('-')) {
      negative = true;
      value = value.substring(0, value.length - 1);
    }

    value = value.replaceAll(RegExp(r'[^0-9.\-]'), '');
    if (value.isEmpty || value == '-' || value == '.') return null;

    final parsed = Dec.tryParse(value);
    if (parsed == null) return null;
    return negative ? -parsed : parsed;
  }

  /// Buy or sell, in the several ways brokers spell it.
  static TradeDirection? direction(String raw) {
    final value = raw.toLowerCase().trim();
    if (value.isEmpty) return null;
    const longs = ['buy', 'b', 'long', 'bought', 'buy to open', 'l'];
    const shorts = ['sell', 's', 'short', 'sold', 'sell to open', 'sl'];
    if (longs.contains(value)) return TradeDirection.long;
    if (shorts.contains(value)) return TradeDirection.short;
    // Fall back to containment for "Buy to Open (BTO)" and similar.
    if (value.contains('short') || value.startsWith('sell')) {
      return TradeDirection.short;
    }
    if (value.contains('long') || value.startsWith('buy')) {
      return TradeDirection.long;
    }
    return null;
  }

  /// Whether a set of date strings proves an order.
  ///
  /// A component above twelve can only be a day, which settles it. Absent that
  /// proof this returns null rather than picking: guessing here silently
  /// rewrites every date in the file.
  static DateOrder? proveDateOrder(Iterable<String> samples) {
    for (final sample in samples) {
      final match = RegExp(r'^\s*(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{2,4})')
          .firstMatch(sample);
      if (match == null) continue;
      final first = int.parse(match.group(1)!);
      final second = int.parse(match.group(2)!);
      if (first > 12 && second <= 12) return DateOrder.dayFirst;
      if (second > 12 && first <= 12) return DateOrder.monthFirst;
    }
    return null;
  }

  /// Parses a date, in UTC, using the trading day's offset for local times.
  static DateTime? dateTime(
    String raw,
    DateOrder order,
    TradingDayConfig config,
  ) {
    final value = raw.trim();
    if (value.isEmpty) return null;

    // ISO first: unambiguous, and what a well-behaved export uses.
    final iso = DateTime.tryParse(value);
    if (iso != null) {
      final zoned =
          value.endsWith('Z') || RegExp(r'[+\-]\d{2}:?\d{2}$').hasMatch(value);
      if (zoned) return iso.toUtc();

      // No zone means the broker wrote local time. `DateTime.tryParse` hands
      // that back as a *local* DateTime — local to whatever machine is running
      // — so the components are re-read as if they were UTC and then shifted.
      // Subtracting from the parsed value directly returns something that is
      // still not UTC, and is wrong by the runtime's own offset on top.
      return DateTime.utc(
        iso.year,
        iso.month,
        iso.day,
        iso.hour,
        iso.minute,
        iso.second,
      ).subtract(Duration(minutes: config.utcOffsetMinutes));
    }

    final match = RegExp(
      r'^(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{2,4})'
      r'(?:[ T]+(\d{1,2}):(\d{2})(?::(\d{2}))?)?',
    ).firstMatch(value);
    if (match == null) return null;

    final a = int.parse(match.group(1)!);
    final b = int.parse(match.group(2)!);
    var year = int.parse(match.group(3)!);
    if (year < 100) year += 2000;

    final day = order == DateOrder.dayFirst ? a : b;
    final month = order == DateOrder.dayFirst ? b : a;
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;

    final hour = int.tryParse(match.group(4) ?? '') ?? 0;
    final minute = int.tryParse(match.group(5) ?? '') ?? 0;
    final second = int.tryParse(match.group(6) ?? '') ?? 0;

    final local = DateTime.utc(year, month, day, hour, minute, second);
    // Reject the impossible rather than letting DateTime roll it over: 31/02
    // becoming the 3rd of March is a silently wrong journal entry.
    if (local.month != month || local.day != day) return null;

    return local.subtract(Duration(minutes: config.utcOffsetMinutes));
  }

  /// Turns rows into trades, or into reasons they could not be.
  ///
  /// [rows] excludes the header. [existingFingerprints] are the trades already
  /// in the journal.
  static ImportPreview read({
    required List<List<String>> rows,
    required ColumnMapping mapping,
    required DateOrder dateOrder,
    required TradingDayConfig config,
    required DateTime fallbackTime,
    Set<String> existingFingerprints = const {},
  }) {
    final ready = <ImportedRow>[];
    final problems = <RowProblem>[];
    final duplicates = <ImportedRow>[];
    final seen = <String>{};

    String cell(List<String> row, ImportField field) {
      final index = mapping.indexOf(field);
      if (index == null || index >= row.length) return '';
      return row[index].trim();
    }

    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      final line = i + 2; // header is line 1

      if (row.every((c) => c.trim().isEmpty)) continue;

      final symbol = cell(row, ImportField.symbol);
      if (symbol.isEmpty) {
        problems.add(RowProblem(line, 'No instrument'));
        continue;
      }

      final quantity = number(cell(row, ImportField.quantity));
      if (quantity == null || !quantity.isPositive) {
        problems.add(RowProblem(line, 'Quantity is missing or not a number'));
        continue;
      }

      final entry = number(cell(row, ImportField.entryPrice));
      if (entry == null || !entry.isPositive) {
        problems
            .add(RowProblem(line, 'Entry price is missing or not a number'));
        continue;
      }

      final rawDate = cell(row, ImportField.openedAt);
      final opened =
          rawDate.isEmpty ? fallbackTime : dateTime(rawDate, dateOrder, config);
      if (opened == null) {
        problems.add(RowProblem(line, 'Could not read the date "$rawDate"'));
        continue;
      }

      final rawClose = cell(row, ImportField.closedAt);
      final closed =
          rawClose.isEmpty ? null : dateTime(rawClose, dateOrder, config);
      if (rawClose.isNotEmpty && closed == null) {
        problems.add(RowProblem(line, 'Could not read the exit time'));
        continue;
      }
      if (closed != null && closed.isBefore(opened)) {
        problems.add(RowProblem(line, 'Exit time is before the entry time'));
        continue;
      }

      final imported = ImportedRow(
        line: line,
        symbol: symbol.toUpperCase(),
        direction:
            direction(cell(row, ImportField.side)) ?? TradeDirection.long,
        quantity: quantity,
        entryPrice: entry,
        exitPrice: number(cell(row, ImportField.exitPrice)),
        fees: number(cell(row, ImportField.fees))?.abs,
        openedAtUtc: opened,
        closedAtUtc: closed,
        note: cell(row, ImportField.note).isEmpty
            ? null
            : cell(row, ImportField.note),
      );

      // Both against the journal and within the file: an export that repeats a
      // row would otherwise import it twice on its own.
      if (existingFingerprints.contains(imported.fingerprint) ||
          !seen.add(imported.fingerprint)) {
        duplicates.add(imported);
        continue;
      }
      ready.add(imported);
    }

    return ImportPreview(
      rows: ready,
      problems: problems,
      duplicates: duplicates,
    );
  }
}

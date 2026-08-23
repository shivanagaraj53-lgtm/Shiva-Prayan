import 'package:csv/csv.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prayan_core/prayan_core.dart';

import '../../design/components/feedback.dart';
import '../../design/components/surfaces.dart';
import '../../design/palette.dart';
import '../../design/tokens.dart';
import '../../domain/repositories.dart';
import '../../state/providers.dart';

/// Importing a broker's CSV export.
///
/// Four steps, in the order the risk sits: read the file, agree what the
/// columns mean, look at what will actually be created, then write it. The
/// preview is the point — an import that writes first and reports afterwards
/// puts wrong rows into a record the user cannot tell apart from their own
/// typing.
class ImportScreen extends ConsumerStatefulWidget {
  const ImportScreen({super.key});

  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen> {
  String? _fileName;
  List<String> _headers = const [];
  List<List<String>> _rows = const [];
  ColumnMapping _mapping = const ColumnMapping({});
  DateOrder _dateOrder = DateOrder.dayFirst;
  bool _orderProven = false;
  String? _error;
  bool _busy = false;
  int? _imported;

  Future<void> _pick() async {
    setState(() {
      _busy = true;
      _error = null;
      _imported = null;
    });
    try {
      final file = await openFile(
        acceptedTypeGroups: const [
          XTypeGroup(label: 'CSV', extensions: ['csv', 'txt']),
        ],
      );
      if (file == null) return;

      final text = await file.readAsString();
      // dynamicTyping off: every cell stays a string. Letting the decoder
      // turn "1,234.50" or a leading-zero ticker into a number would lose
      // precision and mangle symbols before this code ever sees them.
      final table = const CsvDecoder(dynamicTyping: false)
          .convert(text.replaceAll('\r\n', '\n'));

      if (table.length < 2) {
        setState(() => _error = 'That file has no rows under its header.');
        return;
      }

      final headers =
          table.first.map((c) => '$c'.trim()).toList(growable: false);
      final rows = table
          .skip(1)
          .map((r) => r.map((c) => '${c ?? ''}').toList(growable: false))
          .toList(growable: false);

      final mapping = ColumnMapping.detect(headers);
      final dateColumn = mapping.indexOf(ImportField.openedAt);
      final proven = dateColumn == null
          ? null
          : CsvImporter.proveDateOrder(
              rows
                  .where((r) => dateColumn < r.length)
                  .map((r) => r[dateColumn]),
            );

      setState(() {
        _fileName = file.name;
        _headers = headers;
        _rows = rows;
        _mapping = mapping;
        _dateOrder = proven ?? DateOrder.dayFirst;
        _orderProven = proven != null;
      });
    } on Object catch (error) {
      setState(() => _error = 'Could not read that file. $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  ImportPreview? get _preview {
    if (_rows.isEmpty || !_mapping.hasRequired) return null;
    return CsvImporter.read(
      rows: _rows,
      mapping: _mapping,
      dateOrder: _dateOrder,
      config: ref.read(tradingDayConfigProvider),
      fallbackTime: ref.read(nowProvider)(),
      existingFingerprints: ref.read(existingFingerprintsProvider),
    );
  }

  Future<void> _import(ImportPreview preview) async {
    final account = ref.read(activeAccountProvider);
    final userId = ref.read(currentUserIdProvider);
    if (account == null || userId == null) return;

    setState(() => _busy = true);
    final config = ref.read(tradingDayConfigProvider);
    final repository = ref.read(tradeRepositoryProvider);
    final now = ref.read(nowProvider)();

    try {
      for (final row in preview.rows) {
        await repository.saveTrade(
          Trade(
            id: 'imp_${row.fingerprint.hashCode.toUnsigned(32)}_${row.line}',
            userId: userId,
            accountId: account.id,
            symbol: row.symbol,
            assetClass: AssetClass.equity,
            direction: row.direction,
            status:
                row.exitPrice == null ? TradeStatus.open : TradeStatus.closed,
            openedAtUtc: row.openedAtUtc,
            closedAtUtc: row.exitPrice == null
                ? null
                : (row.closedAtUtc ?? row.openedAtUtc),
            tradingDayKey: TradingDay.keyFor(row.openedAtUtc, config),
            session: MarketSession.open,
            multiplier: Dec.one,
            plannedQuantity: row.quantity,
            executions: [
              TradeExecution(
                id: 'imp_e_${row.line}_in',
                kind: ExecutionKind.entry,
                price: row.entryPrice,
                quantity: row.quantity,
                timestampUtc: row.openedAtUtc,
                fees: row.fees ?? Dec.zero,
              ),
              if (row.exitPrice != null)
                TradeExecution(
                  id: 'imp_e_${row.line}_out',
                  kind: ExecutionKind.exit,
                  price: row.exitPrice!,
                  quantity: row.quantity,
                  timestampUtc: row.closedAtUtc ?? row.openedAtUtc,
                  fees: Dec.zero,
                ),
            ],
            entryReason: row.note,
            emotionBefore: EmotionTag.neutral,
            mistake: MistakeCategory.none,
            // Marks these as arrived rather than written, which the journal
            // shows: nobody completed a pre-trade checklist for a row a
            // broker exported, and scoring them as if they had would be a
            // score about the export rather than about the trader.
            importSource: _fileName,
            createdAtUtc: now,
            updatedAtUtc: now,
          ),
        );
      }
      if (mounted) {
        setState(() {
          _imported = preview.rows.length;
          _rows = const [];
          _headers = const [];
        });
      }
    } on RepositoryException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final preview = _preview;

    return Scaffold(
      appBar: AppBar(title: const Text('Import from CSV')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          Spacing.page,
          Spacing.lg,
          Spacing.page,
          Spacing.scrollBottom,
        ),
        children: [
          if (_imported != null) ...[
            PrayanCard(
              borderColor: colors.compliant,
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline_rounded,
                      color: colors.compliant),
                  const SizedBox(width: Spacing.md),
                  Expanded(
                    child: Text(
                      '$_imported ${_imported == 1 ? 'trade' : 'trades'} '
                      'imported, and marked as imported in your journal.',
                      style: text.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Spacing.lg),
          ],
          Text(
            'Most brokers can export your trades as a CSV. Pick that file and '
            'this shows exactly what it would create before anything is '
            'written.',
            style: text.bodyMedium?.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: Spacing.lg),
          FilledButton.icon(
            onPressed: _busy ? null : _pick,
            icon: const Icon(Icons.upload_file_rounded),
            label: Text(_fileName == null
                ? 'Choose a CSV file'
                : 'Choose another file'),
          ),
          if (_fileName != null) ...[
            const SizedBox(height: Spacing.sm),
            Text(
              '$_fileName — ${_rows.length} rows',
              style: text.bodySmall?.copyWith(color: colors.textSecondary),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: Spacing.lg),
            ErrorState(title: 'Could not import', message: _error!),
          ],
          if (_headers.isNotEmpty) ...[
            const SizedBox(height: Spacing.section),
            const SectionHeader(
              title: 'What the columns mean',
              subtitle: 'Guessed from the header row. Correct anything wrong.',
            ),
            for (final field in ImportField.values)
              _MappingRow(
                field: field,
                headers: _headers,
                index: _mapping.indexOf(field),
                onChanged: (index) =>
                    setState(() => _mapping = _mapping.withField(field, index)),
              ),
            if (!_mapping.hasRequired) ...[
              const SizedBox(height: Spacing.md),
              PrayanCard(
                borderColor: colors.warning,
                child: Text(
                  'Still needed: '
                  '${_mapping.missingRequired.map((f) => f.label).join(', ')}.',
                  style: text.bodyMedium,
                ),
              ),
            ],
            const SizedBox(height: Spacing.section),
            _DateOrderChoice(
              order: _dateOrder,
              proven: _orderProven,
              onChanged: (order) => setState(() => _dateOrder = order),
            ),
          ],
          if (preview != null) ...[
            const SizedBox(height: Spacing.section),
            const SectionHeader(title: 'What will be created'),
            _PreviewSummary(preview: preview),
            const SizedBox(height: Spacing.lg),
            FilledButton(
              onPressed: _busy || preview.importable == 0
                  ? null
                  : () => _import(preview),
              child: Text(
                preview.importable == 0
                    ? 'Nothing to import'
                    : 'Import ${preview.importable} '
                        '${preview.importable == 1 ? 'trade' : 'trades'}',
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MappingRow extends StatelessWidget {
  final ImportField field;
  final List<String> headers;
  final int? index;
  final ValueChanged<int?> onChanged;

  const _MappingRow({
    required this.field,
    required this.headers,
    required this.index,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final required = ImportField.required.contains(field);

    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.md),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              required ? '${field.label} *' : field.label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: required && index == null
                        ? colors.warning
                        : colors.textPrimary,
                  ),
            ),
          ),
          Expanded(
            flex: 3,
            child: DropdownButtonFormField<int?>(
              initialValue: index,
              isExpanded: true,
              decoration: const InputDecoration(isDense: true),
              items: [
                const DropdownMenuItem<int?>(child: Text('Not imported')),
                for (var i = 0; i < headers.length; i++)
                  DropdownMenuItem<int?>(
                    value: i,
                    child: Text(
                      headers[i].isEmpty ? 'Column ${i + 1}' : headers[i],
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _DateOrderChoice extends StatelessWidget {
  final DateOrder order;
  final bool proven;
  final ValueChanged<DateOrder> onChanged;

  const _DateOrderChoice({
    required this.order,
    required this.proven,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;

    return PrayanCard(
      borderColor: proven ? null : colors.warning,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('How dates are written', style: text.titleMedium),
          const SizedBox(height: Spacing.xs),
          Text(
            proven
                ? 'Worked out from the file itself — a value above twelve can '
                    'only be a day.'
                : 'Every date in this file could be read either way, and the '
                    'file gives no clue which. Check against your broker '
                    'before importing.',
            style: text.bodySmall?.copyWith(
              color: proven ? colors.textSecondary : colors.warning,
            ),
          ),
          const SizedBox(height: Spacing.md),
          for (final option in DateOrder.values)
            InkWell(
              onTap: () => onChanged(option),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
                child: Row(
                  children: [
                    Icon(
                      option == order
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color:
                          option == order ? colors.accent : colors.textTertiary,
                    ),
                    const SizedBox(width: Spacing.md),
                    Text('${option.label} — ${option.example}'),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PreviewSummary extends StatelessWidget {
  final ImportPreview preview;
  const _PreviewSummary({required this.preview});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PrayanCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Line(
                icon: Icons.check_circle_outline_rounded,
                color: colors.compliant,
                text: '${preview.importable} ready to import',
              ),
              if (preview.duplicates.isNotEmpty)
                _Line(
                  icon: Icons.content_copy_outlined,
                  color: colors.textSecondary,
                  text: '${preview.duplicates.length} already in your journal, '
                      'so they will be skipped',
                ),
              if (preview.problems.isNotEmpty)
                _Line(
                  icon: Icons.error_outline_rounded,
                  color: colors.warning,
                  text: '${preview.problems.length} could not be read',
                ),
            ],
          ),
        ),
        if (preview.rows.isNotEmpty) ...[
          const SizedBox(height: Spacing.md),
          PrayanCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('FIRST FEW',
                    style:
                        text.labelSmall?.copyWith(color: colors.textTertiary)),
                const SizedBox(height: Spacing.sm),
                for (final row in preview.rows.take(3))
                  Padding(
                    padding: const EdgeInsets.only(bottom: Spacing.xs),
                    child: Text(
                      '${row.symbol} · ${row.direction.label} · '
                      '${row.quantity} @ ${row.entryPrice}'
                      '${row.exitPrice == null ? ' · still open' : ' -> ${row.exitPrice}'}',
                      style: text.bodySmall,
                    ),
                  ),
              ],
            ),
          ),
        ],
        if (preview.problems.isNotEmpty) ...[
          const SizedBox(height: Spacing.md),
          PrayanCard(
            borderColor: colors.warning,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ROWS THAT WERE NOT READ',
                    style: text.labelSmall?.copyWith(color: colors.warning)),
                const SizedBox(height: Spacing.sm),
                // Listed by line so they can be found in the spreadsheet and
                // fixed, rather than silently lost.
                for (final problem in preview.problems.take(8))
                  Padding(
                    padding: const EdgeInsets.only(bottom: Spacing.xs),
                    child: Text('$problem', style: text.bodySmall),
                  ),
                if (preview.problems.length > 8)
                  Text('and ${preview.problems.length - 8} more',
                      style: text.bodySmall
                          ?.copyWith(color: colors.textSecondary)),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _Line extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _Line({required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: Spacing.xs),
        child: Row(
          children: [
            Icon(icon, size: Sizes.iconMd, color: color),
            const SizedBox(width: Spacing.sm),
            Expanded(
              child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
            ),
          ],
        ),
      );
}

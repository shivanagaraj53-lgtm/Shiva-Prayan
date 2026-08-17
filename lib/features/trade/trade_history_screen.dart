import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:prayan_core/prayan_core.dart';

import '../../app/router.dart';
import '../../design/components/feedback.dart';
import '../../design/components/segmented_control.dart';
import '../../design/components/surfaces.dart';
import '../../design/components/trade_row.dart';
import '../../design/format.dart';
import '../../design/palette.dart';
import '../../design/tokens.dart';
import '../../state/providers.dart';

/// Search, filter and browse trade history (§17).
class TradeHistoryScreen extends ConsumerStatefulWidget {
  const TradeHistoryScreen({super.key});

  @override
  ConsumerState<TradeHistoryScreen> createState() => _TradeHistoryScreenState();
}

enum _HistoryRange {
  week('7 days', 7),
  month('30 days', 30),
  quarter('90 days', 90),
  year('1 year', 365);

  const _HistoryRange(this.label, this.days);
  final String label;
  final int days;
}

class _TradeHistoryScreenState extends ConsumerState<TradeHistoryScreen> {
  final _searchController = TextEditingController();
  _HistoryRange _range = _HistoryRange.month;
  String _query = '';
  TradeOutcome? _outcome;
  bool _violationsOnly = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final today = ref.watch(todayKeyProvider);
    final from = _shift(today, -_range.days);
    final tradesAsync = ref.watch(tradesInRangeProvider(DayRange(from, today)));
    final strategies = ref.watch(strategiesProvider).value ?? const [];
    final account = ref.watch(activeAccountProvider);
    final rules = ref.watch(rulesProvider).value ?? const [];

    final strategyNames = {for (final s in strategies) s.id: s.name};

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Spacing.page,
                Spacing.lg,
                Spacing.page,
                Spacing.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Journal',
                      style: Theme.of(context).textTheme.headlineLarge),
                  const SizedBox(height: Spacing.md),
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search symbol, setup, tag or note',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close_rounded),
                              tooltip: 'Clear',
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _query = '');
                              },
                            ),
                    ),
                    onChanged: (value) => setState(() => _query = value),
                  ),
                  const SizedBox(height: Spacing.md),
                  PrayanSegmentedControl<_HistoryRange>(
                    compact: true,
                    value: _range,
                    onChanged: (value) => setState(() => _range = value),
                    options: [
                      for (final range in _HistoryRange.values)
                        SegmentOption(value: range, label: range.label),
                    ],
                  ),
                  const SizedBox(height: Spacing.md),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        PrayanChoiceChip(
                          label: 'Wins',
                          selected: _outcome == TradeOutcome.win,
                          onSelected: (selected) => setState(() =>
                              _outcome = selected ? TradeOutcome.win : null),
                        ),
                        const SizedBox(width: Spacing.sm),
                        PrayanChoiceChip(
                          label: 'Losses',
                          selected: _outcome == TradeOutcome.loss,
                          onSelected: (selected) => setState(() =>
                              _outcome = selected ? TradeOutcome.loss : null),
                        ),
                        const SizedBox(width: Spacing.sm),
                        PrayanChoiceChip(
                          label: 'Rules broken',
                          selected: _violationsOnly,
                          selectedColor: colors.warning,
                          onSelected: (selected) =>
                              setState(() => _violationsOnly = selected),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: switch (tradesAsync) {
                AsyncData(:final value) => _buildList(
                    context,
                    value,
                    strategyNames,
                    account?.currency ?? Currency.usd,
                    rules,
                  ),
                AsyncError() => Padding(
                    padding: const EdgeInsets.all(Spacing.page),
                    child: ErrorState(
                      title: 'Could not load your journal',
                      message: 'Your trades are safe. Try again in a moment.',
                      onRetry: () => ref.invalidate(
                          tradesInRangeProvider(DayRange(from, today))),
                    ),
                  ),
                _ => const Center(child: CircularProgressIndicator()),
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    List<Trade> all,
    Map<String, String> strategyNames,
    Currency currency,
    List<Rule> rules,
  ) {
    final filtered = _applyFilters(all, strategyNames, rules);

    if (all.isEmpty) {
      return EmptyState(
        icon: Icons.auto_stories_outlined,
        title: 'Your journal starts here',
        message:
            'Log your first trade and Prayan will start measuring how closely '
            'you follow your own plan.',
        actionLabel: 'Log a trade',
        onAction: () => context.push(Routes.logTrade),
      );
    }
    if (filtered.isEmpty) {
      return const EmptyState(
        icon: Icons.filter_alt_off_outlined,
        title: 'Nothing matches',
        message: 'Try a wider date range or clear a filter.',
      );
    }

    // Group by trading day so the list reads as a diary rather than a feed.
    final byDay = <String, List<Trade>>{};
    for (final trade in filtered) {
      byDay.putIfAbsent(trade.tradingDayKey, () => []).add(trade);
    }
    final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        Spacing.page,
        Spacing.sm,
        Spacing.page,
        Spacing.scrollBottom,
      ),
      itemCount: days.length,
      itemBuilder: (context, index) {
        final dayKey = days[index];
        final trades = byDay[dayKey]!;
        return Padding(
          padding: const EdgeInsets.only(bottom: Spacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(
                  left: Spacing.xs,
                  bottom: Spacing.sm,
                ),
                child: InkWell(
                  onTap: () => context.push(Routes.dailyReview(dayKey)),
                  child: Row(
                    children: [
                      Text(
                        Fmt.dayKey(dayKey),
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(width: Spacing.xs),
                      Icon(Icons.chevron_right_rounded,
                          size: Sizes.iconSm,
                          color: context.colors.textTertiary),
                    ],
                  ),
                ),
              ),
              PrayanCard(
                padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
                child: Column(
                  children: [
                    for (final trade in trades)
                      TradeRow(
                        trade: trade,
                        metrics: TradeCalculator.compute(trade),
                        currency: currency,
                        strategyName: strategyNames[trade.strategyId],
                        violationCount: _violationCount(trade, rules),
                        hasMajorViolation: _hasMajor(trade, rules),
                        onTap: () => context.push(Routes.tradeDetail(trade.id)),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Trade> _applyFilters(
    List<Trade> trades,
    Map<String, String> strategyNames,
    List<Rule> rules,
  ) {
    final query = _query.trim().toLowerCase();
    return trades.reversed.where((trade) {
      if (query.isNotEmpty) {
        final haystack = [
          trade.symbol,
          strategyNames[trade.strategyId] ?? '',
          trade.entryReason ?? '',
          trade.exitReason ?? '',
          trade.managementNotes ?? '',
          trade.mistake.label,
          ...trade.tags,
        ].join(' ').toLowerCase();
        if (!haystack.contains(query)) return false;
      }
      if (_outcome != null) {
        if (TradeCalculator.compute(trade).outcome != _outcome) return false;
      }
      if (_violationsOnly && _violationCount(trade, rules) == 0) return false;
      return true;
    }).toList(growable: false);
  }

  int _violationCount(Trade trade, List<Rule> rules) {
    final account = ref.read(activeAccountProvider);
    if (account == null) return 0;
    return RulesEngine.evaluateTrade(
      trade: trade,
      rules: rules,
      context: DayContext(
        tradingDayKey: trade.tradingDayKey,
        account: account,
        strategiesById: {
          for (final s
              in ref.read(strategiesProvider).value ?? const <Strategy>[])
            s.id: s,
        },
      ),
    ).where((e) => e.isViolation).length;
  }

  bool _hasMajor(Trade trade, List<Rule> rules) {
    final account = ref.read(activeAccountProvider);
    if (account == null) return false;
    return RulesEngine.evaluateTrade(
      trade: trade,
      rules: rules,
      context: DayContext(
        tradingDayKey: trade.tradingDayKey,
        account: account,
        strategiesById: {
          for (final s
              in ref.read(strategiesProvider).value ?? const <Strategy>[])
            s.id: s,
        },
      ),
    ).any((e) => e.isMajorViolation);
  }

  static String _shift(String dayKey, int days) {
    final date = TradingDay.parseKey(dayKey);
    if (date == null) return dayKey;
    return TradingDay.format(date.add(Duration(days: days)));
  }
}

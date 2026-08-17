import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:prayan_core/prayan_core.dart';

import '../../app/router.dart';
import '../../design/components/calendar_day_cell.dart';
import '../../design/components/metric_card.dart';
import '../../design/components/surfaces.dart';
import '../../design/format.dart';
import '../../design/palette.dart';
import '../../design/tokens.dart';
import '../../state/providers.dart';

/// The monthly calendar / heatmap (§11).
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime? _month;

  DateTime get _visibleMonth {
    final today = TradingDay.parseKey(ref.read(todayKeyProvider)) ??
        DateTime.now().toUtc();
    return _month ?? DateTime.utc(today.year, today.month);
  }

  void _shiftMonth(int months) {
    final current = _visibleMonth;
    setState(() {
      _month = DateTime.utc(current.year, current.month + months);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final month = _visibleMonth;
    final today = ref.watch(todayKeyProvider);

    final first = DateTime.utc(month.year, month.month);
    final last = DateTime.utc(month.year, month.month + 1, 0);
    final fromKey = TradingDay.format(first);
    final toKey = TradingDay.format(last);

    final trades = ref.watch(tradesInRangeProvider(DayRange(fromKey, toKey)));
    final history =
        ref.watch(disciplineHistoryProvider(DayRange(fromKey, toKey)));
    final account = ref.watch(activeAccountProvider);
    final currency = account?.currency ?? Currency.usd;

    final days = _buildDays(
      month: month,
      today: today,
      trades: trades.value ?? const [],
      history: history.value ?? const [],
    );

    final monthMetrics =
        PerformanceCalculator.compute(trades.value ?? const []);
    final tradedDays = days.where((d) => d.hasActivity).length;
    final disciplinedLosses = days.where((d) => d.isDisciplinedLoss).length;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            Spacing.page,
            Spacing.lg,
            Spacing.page,
            Spacing.scrollBottom,
          ),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    Fmt.monthYear(month),
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                ),
                IconButton(
                  onPressed: () => _shiftMonth(-1),
                  icon: const Icon(Icons.chevron_left_rounded),
                  tooltip: 'Previous month',
                ),
                IconButton(
                  onPressed: () => _shiftMonth(1),
                  icon: const Icon(Icons.chevron_right_rounded),
                  tooltip: 'Next month',
                ),
              ],
            ),
            const SizedBox(height: Spacing.lg),
            PrayanCard(
              child: Column(
                children: [
                  const CalendarWeekdayHeader(),
                  const SizedBox(height: Spacing.sm),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 7,
                      childAspectRatio: 0.82,
                      mainAxisSpacing: Spacing.xs,
                      crossAxisSpacing: Spacing.xs,
                    ),
                    itemCount: days.length,
                    itemBuilder: (context, index) => CalendarDayCell(
                      data: days[index],
                      onTap: days[index].isOutsideMonth
                          ? null
                          : () => context
                              .push(Routes.dailyReview(days[index].dayKey)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Spacing.md),
            const _CalendarLegend(),
            const SizedBox(height: Spacing.section),
            const SectionHeader(title: 'This month'),
            Row(
              children: [
                Expanded(
                  child: MetricCard(
                    compact: true,
                    label: 'Net P&L',
                    value: Fmt.money(monthMetrics.netPnl, currency,
                        showSign: true, compact: true),
                    valueColor: monthMetrics.hasData
                        ? colors.forSign(monthMetrics.netPnl.signum)
                        : null,
                  ),
                ),
                const SizedBox(width: Spacing.sm),
                Expanded(
                  child: MetricCard(
                    compact: true,
                    label: 'Total R',
                    value: monthMetrics.rSampleCount == 0
                        ? Fmt.emptyValue
                        : Fmt.r(monthMetrics.totalR),
                  ),
                ),
                const SizedBox(width: Spacing.sm),
                Expanded(
                  child: MetricCard(
                    compact: true,
                    label: 'Days traded',
                    value: '$tradedDays',
                  ),
                ),
              ],
            ),
            if (disciplinedLosses > 0) ...[
              const SizedBox(height: Spacing.md),
              PrayanCard(
                child: Row(
                  children: [
                    Icon(Icons.verified_outlined, color: colors.compliant),
                    const SizedBox(width: Spacing.md),
                    Expanded(
                      child: Text(
                        '$disciplinedLosses losing '
                        '${disciplinedLosses == 1 ? 'day' : 'days'} this month '
                        'where you broke no rules. Those are the ones worth '
                        'repeating.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Builds the grid, padding the first week so the 1st lands on its weekday.
  List<CalendarDayData> _buildDays({
    required DateTime month,
    required String today,
    required List<Trade> trades,
    required List<DailyDisciplineRecord> history,
  }) {
    final first = DateTime.utc(month.year, month.month);
    final daysInMonth = DateTime.utc(month.year, month.month + 1, 0).day;
    final leadingBlanks = (first.weekday - DateTime.monday) % 7;

    final byDay = <String, List<Trade>>{};
    for (final trade in trades) {
      byDay.putIfAbsent(trade.tradingDayKey, () => []).add(trade);
    }
    final historyByDay = {for (final record in history) record.dayKey: record};

    return [
      for (var i = 0; i < leadingBlanks; i++)
        const CalendarDayData(
          dayKey: '',
          dayOfMonth: 0,
          isOutsideMonth: true,
        ),
      for (var day = 1; day <= daysInMonth; day++)
        () {
          final date = DateTime.utc(month.year, month.month, day);
          final key = TradingDay.format(date);
          final dayTrades = byDay[key] ?? const [];
          final metrics = PerformanceCalculator.compute(dayTrades);
          final record = historyByDay[key];
          return CalendarDayData(
            dayKey: key,
            dayOfMonth: day,
            netPnl: dayTrades.isEmpty ? null : metrics.netPnl,
            disciplineScore: record?.score,
            tradeCount: dayTrades.where((t) => t.countsAsTaken).length,
            hadMajorViolation: record?.hadMajorViolation ?? false,
            isToday: key == today,
            isFuture: key.compareTo(today) > 0,
          );
        }(),
    ];
  }
}

class _CalendarLegend extends StatelessWidget {
  const _CalendarLegend();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;

    Widget item(Widget marker, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            marker,
            const SizedBox(width: Spacing.xs),
            Text(
              label,
              style: text.labelSmall
                  ?.copyWith(color: colors.textTertiary, letterSpacing: 0),
            ),
          ],
        );

    return Wrap(
      spacing: Spacing.lg,
      runSpacing: Spacing.sm,
      children: [
        item(
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.positive,
            ),
          ),
          'Positive day',
        ),
        item(
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: colors.negative, width: 1.5),
            ),
          ),
          'Negative day',
        ),
        item(
          Row(
            children: [
              for (var i = 0; i < 3; i++)
                Padding(
                  padding: const EdgeInsets.only(right: 2),
                  child: Container(
                    width: 5,
                    height: 3,
                    decoration: BoxDecoration(
                      color: colors.compliant,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
            ],
          ),
          'Discipline',
        ),
        item(
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: colors.violation,
              borderRadius: BorderRadius.circular(1.5),
            ),
          ),
          'Major rule broken',
        ),
      ],
    );
  }
}

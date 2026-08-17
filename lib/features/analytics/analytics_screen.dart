import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prayan_core/prayan_core.dart';

import '../../design/components/coaching_card.dart';
import '../../design/components/feedback.dart';
import '../../design/components/metric_card.dart';
import '../../design/components/segmented_control.dart';
import '../../design/components/surfaces.dart';
import '../../design/format.dart';
import '../../design/palette.dart';
import '../../design/tokens.dart';
import '../../design/typography.dart';
import '../../state/providers.dart';

/// Analytics (§12).
///
/// Every metric carries a plain-language tooltip, and nothing here implies
/// that past results predict future ones — small samples are labelled as such
/// rather than presented as an established edge.
class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

enum _Range {
  month('30d', 30),
  quarter('90d', 90),
  half('180d', 180),
  year('1y', 365);

  const _Range(this.label, this.days);
  final String label;
  final int days;
}

enum _Breakdown { strategy, direction, weekday, session, emotion, mistake }

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  _Range _range = _Range.quarter;
  _Breakdown _breakdown = _Breakdown.strategy;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final today = ref.watch(todayKeyProvider);
    final from = _shift(today, -_range.days);
    final tradesAsync = ref.watch(tradesInRangeProvider(DayRange(from, today)));
    final account = ref.watch(activeAccountProvider);
    final currency = account?.currency ?? Currency.usd;
    final strategies = ref.watch(strategiesProvider).value ?? const [];

    final trades = tradesAsync.value ?? const <Trade>[];
    final metrics = PerformanceCalculator.compute(trades);

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
            Text('Analytics', style: Theme.of(context).textTheme.headlineLarge),
            const SizedBox(height: Spacing.md),
            PrayanSegmentedControl<_Range>(
              compact: true,
              value: _range,
              onChanged: (value) => setState(() => _range = value),
              options: [
                for (final range in _Range.values)
                  SegmentOption(value: range, label: range.label),
              ],
            ),
            const SizedBox(height: Spacing.lg),
            if (!metrics.hasData)
              const EmptyState(
                icon: Icons.query_stats_outlined,
                title: 'Not enough closed trades yet',
                message:
                    'Analytics appear once trades are closed. A handful of '
                    'trades is a story, not a statistic — the numbers become '
                    'meaningful after twenty or so.',
              )
            else ...[
              if (metrics.isSmallSample)
                Padding(
                  padding: const EdgeInsets.only(bottom: Spacing.md),
                  child: PrayanCard(
                    child: Row(
                      children: [
                        Icon(Icons.info_outline_rounded,
                            size: Sizes.iconMd, color: colors.textSecondary),
                        const SizedBox(width: Spacing.md),
                        Expanded(
                          child: Text(
                            'Only ${metrics.tradeCount} closed trades in this '
                            'range. Treat these figures as a first look, not '
                            'a measured edge.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // --- Headline figures -------------------------------------
              Row(
                children: [
                  Expanded(
                    child: MetricCard(
                      compact: true,
                      label: 'Net P&L',
                      value: Fmt.money(metrics.netPnl, currency,
                          showSign: true, compact: true),
                      valueColor: colors.forSign(metrics.netPnl.signum),
                    ),
                  ),
                  const SizedBox(width: Spacing.sm),
                  Expanded(
                    child: MetricCard(
                      compact: true,
                      label: 'Total R',
                      value: Fmt.r(metrics.totalR),
                      support: '${metrics.rSampleCount} measurable',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Spacing.sm),
              Row(
                children: [
                  Expanded(
                    child: MetricCard(
                      compact: true,
                      label: 'Expectancy',
                      value: Fmt.r(metrics.expectancyR),
                      support: 'Per trade',
                    ),
                  ),
                  const SizedBox(width: Spacing.sm),
                  Expanded(
                    child: MetricCard(
                      compact: true,
                      label: 'Profit factor',
                      value: metrics.profitFactor == null
                          ? Fmt.emptyValue
                          : Fmt.number(metrics.profitFactor, decimals: 2),
                      support: metrics.profitFactor == null
                          ? 'No losses yet'
                          : 'Gross win ÷ gross loss',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Spacing.sm),
              Row(
                children: [
                  Expanded(
                    child: MetricCard(
                      compact: true,
                      label: 'Win rate',
                      value: Fmt.percent(metrics.winRate, decimals: 0),
                      support: '${metrics.winCount}W '
                          '${metrics.lossCount}L '
                          '${metrics.breakevenCount}BE',
                    ),
                  ),
                  const SizedBox(width: Spacing.sm),
                  Expanded(
                    child: MetricCard(
                      compact: true,
                      label: 'Max drawdown',
                      value: Fmt.money(metrics.maxDrawdown, currency,
                          compact: true),
                      support: '${metrics.maxDrawdownR.roundTo(1)}R peak to '
                          'trough',
                    ),
                  ),
                ],
              ),

              const SizedBox(height: Spacing.section),

              // --- Equity curve -----------------------------------------
              ChartContainer(
                title: 'Cumulative R',
                explanation:
                    'Your result measured in units of planned risk. Size-'
                    'independent, so a change in position size does not '
                    'distort the trend.',
                child: _EquityChart(
                  points: metrics.equityCurve,
                  useR: true,
                ),
              ),
              const SizedBox(height: Spacing.md),
              ChartContainer(
                title: 'Cumulative P&L',
                explanation:
                    'Running net profit and loss after fees, in your account '
                    'currency.',
                child: _EquityChart(
                  points: metrics.equityCurve,
                  useR: false,
                ),
              ),

              const SizedBox(height: Spacing.section),

              // --- Breakdowns -------------------------------------------
              const SectionHeader(
                title: 'Breakdown',
                subtitle: 'Where the results actually come from.',
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final breakdown in _Breakdown.values)
                      Padding(
                        padding: const EdgeInsets.only(right: Spacing.sm),
                        child: PrayanChoiceChip(
                          label: _breakdownLabel(breakdown),
                          selected: _breakdown == breakdown,
                          onSelected: (_) =>
                              setState(() => _breakdown = breakdown),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: Spacing.md),
              _BreakdownTable(
                trades: trades,
                breakdown: _breakdown,
                strategies: strategies,
                currency: currency,
              ),

              const SizedBox(height: Spacing.section),
              const SectionHeader(
                title: 'Averages',
              ),
              PrayanCard(
                child: Column(
                  children: [
                    DetailRow(
                      label: 'Average win',
                      value: Fmt.money(metrics.averageWin, currency),
                    ),
                    DetailRow(
                      label: 'Average loss',
                      value: Fmt.money(metrics.averageLoss, currency),
                    ),
                    DetailRow(
                      label: 'Average planned R:R',
                      value: Fmt.rewardRisk(metrics.averagePlannedRewardRisk),
                    ),
                    DetailRow(
                      label: 'Average realised R:R',
                      value: Fmt.rewardRisk(metrics.averageRealizedRewardRisk),
                    ),
                    DetailRow(
                      label: 'Average hold time',
                      value: Fmt.duration(metrics.averageHoldingTime),
                    ),
                    DetailRow(
                      label: 'Total fees',
                      value: Fmt.money(metrics.totalFees, currency),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: Spacing.lg),
            const DisclaimerNote(),
          ],
        ),
      ),
    );
  }

  static String _breakdownLabel(_Breakdown breakdown) => switch (breakdown) {
        _Breakdown.strategy => 'Setup',
        _Breakdown.direction => 'Long / short',
        _Breakdown.weekday => 'Day of week',
        _Breakdown.session => 'Session',
        _Breakdown.emotion => 'Emotion',
        _Breakdown.mistake => 'Mistake',
      };

  static String _shift(String dayKey, int days) {
    final date = TradingDay.parseKey(dayKey);
    if (date == null) return dayKey;
    return TradingDay.format(date.add(Duration(days: days)));
  }
}

/// The cumulative equity curve.
class _EquityChart extends StatelessWidget {
  final List<EquityPoint> points;
  final bool useR;

  const _EquityChart({required this.points, required this.useR});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    if (points.isEmpty) {
      return Center(
        child: Text(
          'No closed trades in this range',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: colors.textTertiary),
        ),
      );
    }

    final spots = <FlSpot>[
      const FlSpot(0, 0),
      for (var i = 0; i < points.length; i++)
        FlSpot(
          (i + 1).toDouble(),
          (useR ? points[i].cumulativeR : points[i].cumulativePnl).toDouble(),
        ),
    ];

    final last = spots.last.y;
    final lineColor = last >= 0 ? colors.positive : colors.negative;

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: colors.border,
            strokeWidth: value == 0 ? 1.4 : 0.6,
          ),
        ),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              getTitlesWidget: (value, meta) => Text(
                useR ? '${value.toStringAsFixed(0)}R' : _compact(value),
                style: PrayanType.figure(colors.textTertiary, size: 10),
              ),
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => colors.textPrimary,
            getTooltipItems: (spots) => [
              for (final spot in spots)
                LineTooltipItem(
                  useR
                      ? '${spot.y.toStringAsFixed(2)}R'
                      : spot.y.toStringAsFixed(0),
                  TextStyle(color: colors.canvas, fontSize: 12),
                ),
            ],
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: false,
            color: lineColor,
            barWidth: 2,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: lineColor.withValues(alpha: 0.10),
            ),
          ),
        ],
      ),
    );
  }

  static String _compact(double value) {
    final magnitude = value.abs();
    if (magnitude >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    }
    if (magnitude >= 1000) return '${(value / 1000).toStringAsFixed(0)}K';
    return value.toStringAsFixed(0);
  }
}

/// A grouped performance table.
class _BreakdownTable extends StatelessWidget {
  final List<Trade> trades;
  final _Breakdown breakdown;
  final List<Strategy> strategies;
  final Currency currency;

  const _BreakdownTable({
    required this.trades,
    required this.breakdown,
    required this.strategies,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final strategyNames = {for (final s in strategies) s.id: s.name};

    final grouped = PerformanceCalculator.groupBy<String>(
      trades,
      (trade) => switch (breakdown) {
        _Breakdown.strategy =>
          strategyNames[trade.strategyId] ?? 'No setup recorded',
        _Breakdown.direction => trade.direction.label,
        _Breakdown.weekday => _weekdayName(trade.tradingDayKey),
        _Breakdown.session => trade.session.label,
        _Breakdown.emotion => trade.emotionBefore.label,
        _Breakdown.mistake => trade.mistake.label,
      },
    );

    final rows = grouped.entries.where((entry) => entry.value.hasData).toList()
      ..sort((a, b) => b.value.netPnl.compareTo(a.value.netPnl));

    if (rows.isEmpty) {
      return PrayanCard(
        child: Text(
          'No closed trades to break down yet.',
          style: text.bodySmall?.copyWith(color: colors.textTertiary),
        ),
      );
    }

    return PrayanCard(
      child: Column(
        children: [
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: Spacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          row.key,
                          style: text.titleSmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        Fmt.r(row.value.totalR),
                        style: PrayanType.figure(
                          colors.forSign(row.value.netPnl.signum),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Spacing.xxs),
                  Text(
                    '${row.value.tradeCount} trades · '
                    '${Fmt.percent(row.value.winRate, decimals: 0)} win rate · '
                    '${Fmt.money(row.value.netPnl, currency, showSign: true, compact: true)}',
                    style: text.labelSmall?.copyWith(
                      color: colors.textTertiary,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static String _weekdayName(String dayKey) {
    final date = TradingDay.parseKey(dayKey);
    if (date == null) return 'Unknown';
    return switch (date.weekday) {
      DateTime.monday => 'Monday',
      DateTime.tuesday => 'Tuesday',
      DateTime.wednesday => 'Wednesday',
      DateTime.thursday => 'Thursday',
      DateTime.friday => 'Friday',
      DateTime.saturday => 'Saturday',
      _ => 'Sunday',
    };
  }
}

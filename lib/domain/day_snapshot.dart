import 'package:prayan_core/prayan_core.dart';

import 'models.dart';

/// Everything the dashboard, calendar and daily review need about one day,
/// computed once.
///
/// This is the app's only "use case" layer: it orchestrates
/// [TradeCalculator], [RulesEngine], [DisciplineScorer] and [InsightEngine]
/// and hands screens a finished object. Screens do no arithmetic, which is the
/// brief's §35 requirement ("business calculations must live outside UI
/// widgets") made structural rather than aspirational.
class DaySnapshot {
  final String dayKey;
  final TradingAccount account;

  final List<Trade> trades;

  /// Metrics per trade id, in the same order as [trades].
  final Map<String, TradeMetrics> metricsByTrade;

  final DayRuleReport ruleReport;
  final DisciplineScore score;
  final PerformanceMetrics performance;
  final DisciplineHistory history;
  final List<Insight> insights;

  /// Emotions the user tagged today.
  final List<EmotionTag> emotions;

  final DailyReview? review;

  /// True when the day's configured loss stop was reached.
  final bool reachedDailyStop;

  /// True when trades were taken after that point.
  final bool tradedAfterDailyStop;

  const DaySnapshot({
    required this.dayKey,
    required this.account,
    required this.trades,
    required this.metricsByTrade,
    required this.ruleReport,
    required this.score,
    required this.performance,
    required this.history,
    required this.insights,
    required this.emotions,
    required this.reachedDailyStop,
    required this.tradedAfterDailyStop,
    this.review,
  });

  Currency get currency => account.currency;

  List<Trade> get takenTrades =>
      trades.where((t) => t.countsAsTaken).toList(growable: false);

  int get tradeCount => takenTrades.length;

  Dec get netPnl => performance.netPnl;
  Dec get totalR => performance.totalR;

  bool get isProfitable => netPnl.isPositive;
  bool get hasTrades => tradeCount > 0;

  /// A losing day with no rule broken — the brief's "good loss" (§11).
  bool get isDisciplinedLoss =>
      hasTrades && !isProfitable && score.violations.isEmpty;

  /// A profitable day that broke a major rule.
  bool get isUndisciplinedWin =>
      hasTrades && isProfitable && score.majorViolations.isNotEmpty;

  /// Rule evaluations for one trade.
  List<RuleEvaluation> evaluationsFor(String tradeId) =>
      ruleReport.byTrade[tradeId] ?? const [];

  int violationCountFor(String tradeId) =>
      evaluationsFor(tradeId).where((e) => e.isViolation).length;

  bool hasMajorViolationFor(String tradeId) =>
      evaluationsFor(tradeId).any((e) => e.isMajorViolation);

  /// Metrics for a trade, or `null` if that trade is not part of this day.
  ///
  /// Nullable rather than a zeroed placeholder: a caller asking about an
  /// unknown trade has a bug, and silently handing back zeros would render a
  /// convincing but fictional row.
  TradeMetrics? metricsFor(String tradeId) => metricsByTrade[tradeId];

  /// The facts handed to the coaching layer. No raw trades ever leave here.
  CoachingFacts get coachingFacts => CoachingFacts.build(
        dayKey: dayKey,
        netPnlFormatted: Money(netPnl, currency).format(showSign: true),
        totalR: totalR,
        tradesTaken: tradeCount,
        winCount: performance.winCount,
        lossCount: performance.lossCount,
        breakevenCount: performance.breakevenCount,
        score: score,
        history: history,
        emotionsToday: emotions,
        reachedDailyStop: reachedDailyStop,
        tradedAfterDailyStop: tradedAfterDailyStop,
        dayWasProfitable: isProfitable,
      );

  /// Builds a snapshot from raw inputs.
  ///
  /// Pure and synchronous — no IO — so it is trivially testable and can run
  /// inside a provider without an await.
  static DaySnapshot build({
    required String dayKey,
    required TradingAccount account,
    required List<Trade> trades,
    required List<Rule> rules,
    required List<Strategy> strategies,
    required List<DailyDisciplineRecord> priorHistory,
    required AppPreferences preferences,
    List<PsychologyEntry> psychology = const [],
    DailyReview? review,
    Dec? weekNetPnl,
    Dec? weekTotalR,
  }) {
    final context = DayContext(
      tradingDayKey: dayKey,
      account: account,
      strategiesById: {for (final s in strategies) s.id: s},
      dailyReviewCompleted: review?.isComplete ?? false,
      weekNetPnl: weekNetPnl,
      weekTotalR: weekTotalR,
    );

    final report = RulesEngine.evaluateDay(
      trades: trades,
      rules: rules,
      context: context,
    );

    final score = DisciplineScorer.score(
      report.all,
      config: preferences.scoring,
    );

    final performance = PerformanceCalculator.compute(trades);

    final metrics = <String, TradeMetrics>{
      for (final trade in trades) trade.id: TradeCalculator.compute(trade),
    };

    // Append today's record so the streak includes the day being viewed.
    final todayRecord = StreakCalculator.recordFor(
      dayKey: dayKey,
      score: score,
      tradeCount: trades.where((t) => t.countsAsTaken).length,
      evaluations: report.all,
    );
    final history = StreakCalculator.compute(
      [
        ...priorHistory.where((r) => r.dayKey != dayKey),
        todayRecord,
      ],
      countNoTradeDaysInStreak: preferences.countNoTradeDaysInStreak,
    );

    // "No trading after the daily stop" is the rule that knows whether the
    // stop was hit, so its verdict is reused rather than recomputed.
    final stopRule = report.dayLevel
        .where((e) => e.measure == RuleMeasure.noTradingAfterDailyStop)
        .firstOrNull;
    final reachedStop =
        stopRule != null && stopRule.observed != 'Stop not reached';
    final tradedAfterStop = stopRule?.isViolation ?? false;

    final emotions = <EmotionTag>{
      for (final trade in trades) trade.emotionBefore,
      for (final trade in trades)
        if (trade.emotionAfter != null) trade.emotionAfter!,
      for (final entry in psychology) entry.emotion,
    }.toList(growable: false);

    final snapshot = DaySnapshot(
      dayKey: dayKey,
      account: account,
      trades: trades,
      metricsByTrade: metrics,
      ruleReport: report,
      score: score,
      performance: performance,
      history: history,
      insights: const [],
      emotions: emotions,
      reachedDailyStop: reachedStop,
      tradedAfterDailyStop: tradedAfterStop,
      review: review,
    );

    // Insights depend on the assembled facts, so they are computed last and
    // folded back in.
    return snapshot._withInsights(
      InsightEngine.forDay(snapshot.coachingFacts),
    );
  }

  DaySnapshot _withInsights(List<Insight> value) => DaySnapshot(
        dayKey: dayKey,
        account: account,
        trades: trades,
        metricsByTrade: metricsByTrade,
        ruleReport: ruleReport,
        score: score,
        performance: performance,
        history: history,
        insights: value,
        emotions: emotions,
        reachedDailyStop: reachedDailyStop,
        tradedAfterDailyStop: tradedAfterDailyStop,
        review: review,
      );

  /// An empty day, used before data loads and for days with no activity.
  static DaySnapshot empty(String dayKey, TradingAccount account) =>
      DaySnapshot(
        dayKey: dayKey,
        account: account,
        trades: const [],
        metricsByTrade: const {},
        ruleReport: DayRuleReport(
          tradingDayKey: dayKey,
          byTrade: const {},
          dayLevel: const [],
        ),
        score: DisciplineScore.empty,
        performance: PerformanceMetrics.empty,
        history: DisciplineHistory.empty,
        insights: const [],
        emotions: const [],
        reachedDailyStop: false,
        tradedAfterDailyStop: false,
      );
}

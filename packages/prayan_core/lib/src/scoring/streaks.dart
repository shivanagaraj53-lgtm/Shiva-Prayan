import '../models/enums.dart';
import '../models/rule.dart';
import '../money/dec.dart';
import 'discipline_score.dart';

/// One day's discipline outcome, as persisted in `dailySummaries`.
class DailyDisciplineRecord {
  /// `yyyy-MM-dd` in the user's timezone.
  final String dayKey;

  /// The day's discipline score, or `null` when no rule applied.
  final Dec? score;

  final bool hadMajorViolation;
  final int violationCount;
  final int tradeCount;

  /// Per-rule outcomes for rule-specific compliance tracking.
  final List<RuleEvaluation> evaluations;

  const DailyDisciplineRecord({
    required this.dayKey,
    required this.hadMajorViolation,
    required this.violationCount,
    required this.tradeCount,
    this.score,
    this.evaluations = const [],
  });

  bool get hadTrades => tradeCount > 0;

  /// A day that ends the clean streak. Only a *major* violation does this;
  /// minor breaches reduce the score without erasing the run (brief §9).
  bool get breaksStreak => hadMajorViolation;

  /// A traded day with no violations at all.
  bool get isCleanTradingDay => hadTrades && violationCount == 0;
}

/// Compliance history for a single rule.
class RuleComplianceStat {
  final String ruleId;
  final String ruleName;
  final int passedCount;
  final int violatedCount;

  const RuleComplianceStat({
    required this.ruleId,
    required this.ruleName,
    required this.passedCount,
    required this.violatedCount,
  });

  int get applicableCount => passedCount + violatedCount;

  /// Compliance rate 0–100, or `null` when the rule never applied.
  Dec? get compliancePercent => applicableCount == 0
      ? null
      : Dec.fromInt(passedCount)
          .percentOf(Dec.fromInt(applicableCount), scale: 2);
}

/// The five distinct concepts the brief insists on keeping separate (§9):
/// lifetime history, current clean streak, rolling score, per-rule compliance
/// and major-violation reset logic.
class DisciplineHistory {
  /// Consecutive days, ending at the most recent record, with no major
  /// violation.
  final int currentCleanStreak;

  /// The longest such run ever achieved. Never reset.
  final int bestCleanStreak;

  /// Total days with at least one major violation, over all history.
  final int majorViolationDays;

  /// Total days that carried a score.
  final int scoredDays;

  /// Total days with at least one trade.
  final int tradingDays;

  /// Mean discipline score over all scored days. Preserved through every
  /// violation — this is the "history remains intact" guarantee.
  final Dec? lifetimeAverageScore;

  final Dec? rolling7DayScore;
  final Dec? rolling30DayScore;
  final Dec? rolling90DayScore;

  /// Per-rule compliance, worst first — the "your most repeated violation is…"
  /// input for the coaching layer.
  final List<RuleComplianceStat> ruleCompliance;

  /// The day the current streak began, or `null` when there is no live streak.
  final String? streakStartedOn;

  const DisciplineHistory({
    required this.currentCleanStreak,
    required this.bestCleanStreak,
    required this.majorViolationDays,
    required this.scoredDays,
    required this.tradingDays,
    required this.ruleCompliance,
    this.lifetimeAverageScore,
    this.rolling7DayScore,
    this.rolling30DayScore,
    this.rolling90DayScore,
    this.streakStartedOn,
  });

  static const DisciplineHistory empty = DisciplineHistory(
    currentCleanStreak: 0,
    bestCleanStreak: 0,
    majorViolationDays: 0,
    scoredDays: 0,
    tradingDays: 0,
    ruleCompliance: [],
  );

  /// The rule broken most often, if any — used verbatim by the coaching layer.
  RuleComplianceStat? get weakestRule {
    RuleComplianceStat? worst;
    for (final stat in ruleCompliance) {
      if (stat.violatedCount == 0) continue;
      if (worst == null || stat.violatedCount > worst.violatedCount) {
        worst = stat;
      }
    }
    return worst;
  }

  /// The rule followed most reliably, among those that applied often enough
  /// to be meaningful.
  RuleComplianceStat? get strongestRule {
    RuleComplianceStat? best;
    for (final stat in ruleCompliance) {
      if (stat.applicableCount < 3) continue;
      final rate = stat.compliancePercent;
      if (rate == null) continue;
      final bestRate = best?.compliancePercent;
      if (best == null || bestRate == null || rate > bestRate) best = stat;
    }
    return best;
  }
}

/// Derives streaks and rolling scores from stored daily records.
class StreakCalculator {
  const StreakCalculator._();

  /// Computes history from [records], which need not be sorted.
  ///
  /// [countNoTradeDaysInStreak] controls whether a day with no trades extends
  /// the clean streak. It defaults to `false`: a no-trade day *preserves* a
  /// streak (it is never a violation) but does not inflate it, so the number
  /// keeps meaning "sessions I traded within my rules".
  static DisciplineHistory compute(
    List<DailyDisciplineRecord> records, {
    bool countNoTradeDaysInStreak = false,
  }) {
    if (records.isEmpty) return DisciplineHistory.empty;

    final sorted = [...records]..sort((a, b) => a.dayKey.compareTo(b.dayKey));

    var bestStreak = 0;
    var runningStreak = 0;
    String? runningStreakStart;
    var currentStreak = 0;
    String? currentStreakStart;
    var majorViolationDays = 0;
    var scoredDays = 0;
    var tradingDays = 0;
    var scoreTotal = Dec.zero;

    final complianceById = <String, _ComplianceAccumulator>{};

    for (final record in sorted) {
      if (record.hadTrades) tradingDays++;
      if (record.score != null) {
        scoredDays++;
        scoreTotal += record.score!;
      }
      if (record.hadMajorViolation) majorViolationDays++;

      for (final evaluation in record.evaluations) {
        if (evaluation.status == RuleStatus.passed ||
            evaluation.status == RuleStatus.violated) {
          final accumulator = complianceById.putIfAbsent(
            evaluation.ruleId,
            () => _ComplianceAccumulator(evaluation.ruleName),
          );
          accumulator.name = evaluation.ruleName;
          if (evaluation.isViolation) {
            accumulator.violated++;
          } else {
            accumulator.passed++;
          }
        }
      }

      // Streak transition. A major violation is the only thing that zeroes it.
      if (record.breaksStreak) {
        runningStreak = 0;
        runningStreakStart = null;
      } else if (record.hadTrades || countNoTradeDaysInStreak) {
        if (runningStreak == 0) runningStreakStart = record.dayKey;
        runningStreak++;
        if (runningStreak > bestStreak) bestStreak = runningStreak;
      }
      // A no-trade day with no violation falls through: the run is neither
      // broken nor extended.

      currentStreak = runningStreak;
      currentStreakStart = runningStreakStart;
    }

    final lifetimeAverage = scoredDays == 0
        ? null
        : scoreTotal.divide(Dec.fromInt(scoredDays), scale: 2);

    final compliance = complianceById.entries
        .map((entry) => RuleComplianceStat(
              ruleId: entry.key,
              ruleName: entry.value.name,
              passedCount: entry.value.passed,
              violatedCount: entry.value.violated,
            ))
        .toList()
      ..sort((a, b) {
        // Worst compliance first, then most-applied, then id for stability.
        final aRate = a.compliancePercent ?? Dec.hundred;
        final bRate = b.compliancePercent ?? Dec.hundred;
        final byRate = aRate.compareTo(bRate);
        if (byRate != 0) return byRate;
        final byVolume = b.applicableCount.compareTo(a.applicableCount);
        if (byVolume != 0) return byVolume;
        return a.ruleId.compareTo(b.ruleId);
      });

    return DisciplineHistory(
      currentCleanStreak: currentStreak,
      bestCleanStreak: bestStreak,
      majorViolationDays: majorViolationDays,
      scoredDays: scoredDays,
      tradingDays: tradingDays,
      lifetimeAverageScore: lifetimeAverage,
      rolling7DayScore: _rollingAverage(sorted, 7),
      rolling30DayScore: _rollingAverage(sorted, 30),
      rolling90DayScore: _rollingAverage(sorted, 90),
      ruleCompliance: List.unmodifiable(compliance),
      streakStartedOn: currentStreak > 0 ? currentStreakStart : null,
    );
  }

  /// Mean score over the last [days] *records* that carry a score.
  ///
  /// Deliberately window-by-record rather than by calendar date: a swing
  /// trader who journals twice a week should still get a meaningful 30-day
  /// trend instead of a number diluted by empty calendar days.
  static Dec? _rollingAverage(List<DailyDisciplineRecord> sorted, int days) {
    var total = Dec.zero;
    var count = 0;
    for (final record in sorted.reversed) {
      if (record.score == null) continue;
      total += record.score!;
      count++;
      if (count >= days) break;
    }
    if (count == 0) return null;
    return total.divide(Dec.fromInt(count), scale: 2);
  }

  /// Builds a day record from a computed score, for callers that have just
  /// evaluated a day and want to append it to history.
  ///
  /// [evaluations] must be the day's *full* evaluation list, not just the
  /// violations — per-rule compliance needs the passes to form a denominator.
  static DailyDisciplineRecord recordFor({
    required String dayKey,
    required DisciplineScore score,
    required int tradeCount,
    List<RuleEvaluation> evaluations = const [],
  }) =>
      DailyDisciplineRecord(
        dayKey: dayKey,
        score: score.hasScore ? score.value : null,
        hadMajorViolation: score.majorViolations.isNotEmpty,
        violationCount: score.violations.length,
        tradeCount: tradeCount,
        evaluations:
            evaluations.isEmpty ? [...score.violations] : evaluations,
      );
}

class _ComplianceAccumulator {
  _ComplianceAccumulator(this.name);
  String name;
  int passed = 0;
  int violated = 0;
}

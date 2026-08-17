import '../models/enums.dart';
import '../money/dec.dart';
import '../scoring/discipline_score.dart';
import '../scoring/streaks.dart';

/// The complete, computed picture of a trading day.
///
/// This is the *only* structure handed to the AI coaching layer (brief §15).
/// Every number here was produced by [TradeCalculator], [RulesEngine] and
/// [DisciplineScorer]; the model is asked to phrase it, never to derive it.
/// Because the model receives no raw trades, it has nothing to hallucinate a
/// price or a violation from.
class CoachingFacts {
  final String dayKey;

  /// Display-formatted day P&L, e.g. `-₹4,200.00`. Pre-formatted so the
  /// narrative layer never has to reason about currency or precision.
  final String netPnlFormatted;

  /// Signed day result in R, rounded for display.
  final Dec? totalR;

  final int tradesTaken;
  final int winCount;
  final int lossCount;
  final int breakevenCount;

  final int? disciplineScore;
  final bool hasScore;
  final int rulesFollowed;
  final int rulesApplicable;

  /// Names of rules broken today, deduplicated.
  final List<String> violatedRuleNames;

  /// Names of major rules broken today.
  final List<String> majorViolationNames;

  final int currentCleanStreak;
  final int bestCleanStreak;
  final Dec? rolling30DayScore;

  /// The rule broken most often across history, if any.
  final String? weakestRuleName;
  final Dec? weakestRuleCompliancePercent;

  /// The rule followed most reliably across history, if any.
  final String? strongestRuleName;

  /// Emotions the user tagged today.
  final List<EmotionTag> emotionsToday;

  /// True when the day's configured loss stop was reached.
  final bool reachedDailyStop;

  /// True when trades were taken after the stop was reached.
  final bool tradedAfterDailyStop;

  /// True when the day lost money but broke no rules — the brief's
  /// "disciplined loss" (§11, §37).
  final bool isDisciplinedLoss;

  /// True when the day made money but broke a major rule.
  final bool isUndisciplinedWin;

  const CoachingFacts({
    required this.dayKey,
    required this.netPnlFormatted,
    required this.tradesTaken,
    required this.winCount,
    required this.lossCount,
    required this.breakevenCount,
    required this.hasScore,
    required this.rulesFollowed,
    required this.rulesApplicable,
    required this.violatedRuleNames,
    required this.majorViolationNames,
    required this.currentCleanStreak,
    required this.bestCleanStreak,
    required this.emotionsToday,
    required this.reachedDailyStop,
    required this.tradedAfterDailyStop,
    required this.isDisciplinedLoss,
    required this.isUndisciplinedWin,
    this.totalR,
    this.disciplineScore,
    this.rolling30DayScore,
    this.weakestRuleName,
    this.weakestRuleCompliancePercent,
    this.strongestRuleName,
  });

  /// Serialises for the coaching endpoint. Note the absence of symbols,
  /// prices, sizes and account balances: the narrative layer does not need
  /// them, so they are never sent (brief §32, data minimisation).
  Map<String, dynamic> toMap() => {
        'dayKey': dayKey,
        'netPnlFormatted': netPnlFormatted,
        'totalR': totalR?.toString(),
        'tradesTaken': tradesTaken,
        'winCount': winCount,
        'lossCount': lossCount,
        'breakevenCount': breakevenCount,
        'disciplineScore': disciplineScore,
        'hasScore': hasScore,
        'rulesFollowed': rulesFollowed,
        'rulesApplicable': rulesApplicable,
        'violatedRuleNames': violatedRuleNames,
        'majorViolationNames': majorViolationNames,
        'currentCleanStreak': currentCleanStreak,
        'bestCleanStreak': bestCleanStreak,
        'rolling30DayScore': rolling30DayScore?.toString(),
        'weakestRuleName': weakestRuleName,
        'weakestRuleCompliancePercent':
            weakestRuleCompliancePercent?.toString(),
        'strongestRuleName': strongestRuleName,
        'emotionsToday': emotionsToday.map((e) => e.wireName).toList(),
        'reachedDailyStop': reachedDailyStop,
        'tradedAfterDailyStop': tradedAfterDailyStop,
        'isDisciplinedLoss': isDisciplinedLoss,
        'isUndisciplinedWin': isUndisciplinedWin,
      };

  /// Assembles the facts from already-computed inputs.
  factory CoachingFacts.build({
    required String dayKey,
    required String netPnlFormatted,
    required Dec? totalR,
    required int tradesTaken,
    required int winCount,
    required int lossCount,
    required int breakevenCount,
    required DisciplineScore score,
    required DisciplineHistory history,
    required List<EmotionTag> emotionsToday,
    required bool reachedDailyStop,
    required bool tradedAfterDailyStop,
    required bool dayWasProfitable,
  }) {
    final violated = score.violations
        .map((v) => v.ruleName)
        .toSet()
        .toList(growable: false);
    final major = score.majorViolations
        .map((v) => v.ruleName)
        .toSet()
        .toList(growable: false);
    final weakest = history.weakestRule;
    final strongest = history.strongestRule;

    return CoachingFacts(
      dayKey: dayKey,
      netPnlFormatted: netPnlFormatted,
      totalR: totalR,
      tradesTaken: tradesTaken,
      winCount: winCount,
      lossCount: lossCount,
      breakevenCount: breakevenCount,
      disciplineScore: score.hasScore ? score.rounded : null,
      hasScore: score.hasScore,
      rulesFollowed: score.rulesFollowed,
      rulesApplicable: score.rulesApplicable,
      violatedRuleNames: violated,
      majorViolationNames: major,
      currentCleanStreak: history.currentCleanStreak,
      bestCleanStreak: history.bestCleanStreak,
      rolling30DayScore: history.rolling30DayScore,
      weakestRuleName: weakest?.ruleName,
      weakestRuleCompliancePercent: weakest?.compliancePercent,
      strongestRuleName: strongest?.ruleName,
      emotionsToday: emotionsToday,
      reachedDailyStop: reachedDailyStop,
      tradedAfterDailyStop: tradedAfterDailyStop,
      isDisciplinedLoss:
          tradesTaken > 0 && !dayWasProfitable && score.violations.isEmpty,
      isUndisciplinedWin:
          tradesTaken > 0 && dayWasProfitable && score.majorViolations.isNotEmpty,
    );
  }
}

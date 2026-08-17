import '../calc/trade_calculator.dart';
import '../models/account.dart';
import '../models/enums.dart';
import '../models/rule.dart';
import '../models/trade.dart';
import '../money/dec.dart';

/// Everything the engine needs to judge one trading day that is not derivable
/// from the trades themselves.
class DayContext {
  /// `yyyy-MM-dd` in the user's timezone.
  final String tradingDayKey;

  final TradingAccount account;

  /// Approved-setup lookups.
  final Map<String, Strategy> strategiesById;

  /// Whether the user completed the guided daily review (brief §14).
  final bool dailyReviewCompleted;

  /// Self-reported compliance for rules the engine cannot measure, keyed by
  /// rule id. A missing entry yields [RuleStatus.indeterminate] — never a
  /// silent pass.
  final Map<String, bool> manualCompliance;

  /// Week-to-date net P&L and R, for week-scoped rules. Null when the caller
  /// did not supply the week's context.
  final Dec? weekNetPnl;
  final Dec? weekTotalR;

  const DayContext({
    required this.tradingDayKey,
    required this.account,
    this.strategiesById = const {},
    this.dailyReviewCompleted = false,
    this.manualCompliance = const {},
    this.weekNetPnl,
    this.weekTotalR,
  });

  /// ISO weekday (`DateTime.monday`..`DateTime.sunday`) for [tradingDayKey].
  ///
  /// Parsed from the key rather than from a UTC timestamp so a trade logged at
  /// 23:30 local time is judged by the weekday the user experienced.
  int get weekday {
    final parsed = DateTime.tryParse(tradingDayKey);
    return parsed?.weekday ?? DateTime.monday;
  }
}

/// The complete verdict for one trading day.
class DayRuleReport {
  final String tradingDayKey;

  /// Evaluations grouped by trade id, in the order the trades were taken.
  final Map<String, List<RuleEvaluation>> byTrade;

  /// Day- and week-scoped evaluations.
  final List<RuleEvaluation> dayLevel;

  const DayRuleReport({
    required this.tradingDayKey,
    required this.byTrade,
    required this.dayLevel,
  });

  /// Every evaluation produced for the day.
  List<RuleEvaluation> get all =>
      [for (final list in byTrade.values) ...list, ...dayLevel];

  List<RuleEvaluation> get violations =>
      all.where((e) => e.isViolation).toList(growable: false);

  List<RuleEvaluation> get majorViolations =>
      all.where((e) => e.isMajorViolation).toList(growable: false);

  bool get hasMajorViolation => majorViolations.isNotEmpty;
}

/// Evaluates configured discipline rules against trades and days.
///
/// The engine is deterministic and side-effect free: the same trades, rules
/// and context always produce the same evaluations. That property is what lets
/// the same code run on the client for instant feedback and on Cloud Functions
/// as the authoritative writer (brief §4, §35).
class RulesEngine {
  const RulesEngine._();

  /// Evaluates a whole trading day.
  ///
  /// [trades] should be every trade belonging to [context.tradingDayKey],
  /// which the method sorts chronologically — sequence-sensitive rules such as
  /// "no trading after the daily stop" depend on the true order.
  static DayRuleReport evaluateDay({
    required List<Trade> trades,
    required List<Rule> rules,
    required DayContext context,
  }) {
    final ordered = [...trades]
      ..sort((a, b) => a.openedAtUtc.compareTo(b.openedAtUtc));
    final taken = ordered.where((t) => t.countsAsTaken).toList(growable: false);

    final byTrade = <String, List<RuleEvaluation>>{};
    for (final trade in ordered) {
      byTrade[trade.id] = evaluateTrade(
        trade: trade,
        rules: rules,
        context: context,
        priorTradesToday:
            taken.where((t) => t.openedAtUtc.isBefore(trade.openedAtUtc)).toList(
                growable: false),
      );
    }

    final dayLevel = _evaluateDayScope(
      taken: taken,
      rules: rules,
      context: context,
    );

    return DayRuleReport(
      tradingDayKey: context.tradingDayKey,
      byTrade: byTrade,
      dayLevel: dayLevel,
    );
  }

  /// Evaluates every trade-scoped rule against a single trade.
  static List<RuleEvaluation> evaluateTrade({
    required Trade trade,
    required List<Rule> rules,
    required DayContext context,
    List<Trade> priorTradesToday = const [],
  }) {
    final metrics = TradeCalculator.compute(trade);
    final results = <RuleEvaluation>[];

    for (final rule in rules) {
      // Resolve the version that was in force when the trade was opened, so
      // editing a rule today never rewrites yesterday's verdict.
      final version = rule.versionAt(trade.openedAtUtc);
      if (version == null) continue;
      if (version.measure.scope != RuleScope.trade) continue;

      if (!rule.isActive) {
        results.add(_notApplicable(
            version, RuleScope.trade, 'Rule is paused.', trade.id));
        continue;
      }

      // Planned and cancelled trades were never taken, so execution rules
      // cannot be breached by them (brief §37: declining a setup is discipline).
      if (!trade.countsAsTaken) {
        results.add(_notApplicable(version, RuleScope.trade,
            'Trade was not taken.', trade.id));
        continue;
      }

      // `sessionRestriction` treats its session list as the *allowed* set
      // rather than a context filter, so the filter is skipped for it and the
      // comparison happens in the evaluator instead.
      final inContext = version.matchesContext(
        weekday: context.weekday,
        session: trade.session,
        strategyId: trade.strategyId,
        assetClass: trade.assetClass,
        ignoreSessions: version.measure == RuleMeasure.sessionRestriction,
      );
      if (!inContext) {
        results.add(_notApplicable(version, RuleScope.trade,
            'Rule does not apply to this trade.', trade.id));
        continue;
      }

      results.add(_evaluateTradeRule(
        version: version,
        trade: trade,
        metrics: metrics,
        context: context,
        priorTradesToday: priorTradesToday,
      ));
    }

    return results;
  }

  static RuleEvaluation _evaluateTradeRule({
    required RuleVersion version,
    required Trade trade,
    required TradeMetrics metrics,
    required DayContext context,
    required List<Trade> priorTradesToday,
  }) {
    switch (version.measure) {
      case RuleMeasure.maxRiskPercentPerTrade:
        final observed = metrics.plannedRiskPercent;
        if (observed == null) {
          return _indeterminate(version, RuleScope.trade,
              'Risk percentage needs a stop and an account equity figure.',
              trade.id);
        }
        return _compare(
          version: version,
          scope: RuleScope.trade,
          tradeId: trade.id,
          passed: version.threshold == null || observed <= version.threshold!,
          observed: '${observed.roundTo(2).normalized}%',
          threshold: '${version.threshold?.normalized ?? '-'}%',
          passMessage: 'Risk was ${observed.roundTo(2).normalized}% of equity, '
              'inside your ${version.threshold?.normalized}% limit.',
          failMessage: 'Risk was ${observed.roundTo(2).normalized}% of equity, '
              'above your ${version.threshold?.normalized}% limit.',
        );

      case RuleMeasure.maxRiskMoneyPerTrade:
        final observed = metrics.plannedRisk;
        if (observed == null) {
          return _indeterminate(version, RuleScope.trade,
              'Money at risk needs an entry, a stop and a position size.',
              trade.id);
        }
        final formatted =
            context.account.money(observed).format(showSymbol: true);
        final limit = version.threshold == null
            ? '-'
            : context.account.money(version.threshold!).format();
        return _compare(
          version: version,
          scope: RuleScope.trade,
          tradeId: trade.id,
          passed: version.threshold == null || observed <= version.threshold!,
          observed: formatted,
          threshold: limit,
          passMessage: 'Risked $formatted, inside your $limit limit.',
          failMessage: 'Risked $formatted, above your $limit limit.',
        );

      case RuleMeasure.minPlannedRewardRisk:
        final observed = metrics.plannedRewardRisk;
        if (observed == null) {
          return _indeterminate(version, RuleScope.trade,
              'Planned reward:risk needs both a stop and a target.', trade.id);
        }
        final shown = observed.roundTo(2).normalized;
        final limit = version.threshold?.normalized;
        return _compare(
          version: version,
          scope: RuleScope.trade,
          tradeId: trade.id,
          passed: version.threshold == null || observed >= version.threshold!,
          observed: '1:$shown',
          threshold: '1:$limit',
          passMessage: 'Planned 1:$shown, at or above your 1:$limit minimum.',
          failMessage: 'Planned 1:$shown, below your 1:$limit minimum.',
        );

      case RuleMeasure.stopLossRequired:
        return _compare(
          version: version,
          scope: RuleScope.trade,
          tradeId: trade.id,
          passed: trade.hasStop,
          observed: trade.hasStop ? 'Stop set' : 'No stop',
          threshold: 'Stop required',
          passMessage: 'A stop was defined before entry.',
          failMessage: 'No stop was recorded for this trade.',
        );

      case RuleMeasure.approvedStrategyOnly:
        final strategy = trade.strategyId == null
            ? null
            : context.strategiesById[trade.strategyId];
        if (trade.strategyId == null) {
          return _compare(
            version: version,
            scope: RuleScope.trade,
            tradeId: trade.id,
            passed: false,
            observed: 'No setup recorded',
            threshold: 'Approved setup',
            passMessage: '',
            failMessage: 'No setup was recorded, so this cannot be an '
                'approved one.',
          );
        }
        if (strategy == null) {
          return _indeterminate(version, RuleScope.trade,
              'The setup on this trade is no longer available to check.',
              trade.id);
        }
        return _compare(
          version: version,
          scope: RuleScope.trade,
          tradeId: trade.id,
          passed: strategy.isApproved,
          observed: strategy.name,
          threshold: 'Approved setup',
          passMessage: '${strategy.name} is on your approved list.',
          failMessage: '${strategy.name} is not on your approved list.',
        );

      case RuleMeasure.sessionRestriction:
        final allowed = version.sessions;
        if (allowed.isEmpty) {
          return _notApplicable(version, RuleScope.trade,
              'No sessions configured for this rule.', trade.id);
        }
        final labels = allowed.map((s) => s.label).join(', ');
        return _compare(
          version: version,
          scope: RuleScope.trade,
          tradeId: trade.id,
          passed: allowed.contains(trade.session),
          observed: trade.session.label,
          threshold: labels,
          passMessage: 'Taken in the ${trade.session.label} session, which you '
              'trade.',
          failMessage: 'Taken in the ${trade.session.label} session; you trade '
              '$labels.',
        );

      case RuleMeasure.checklistCompletion:
        final ratio = trade.checklistCompletionRatio;
        if (ratio == null) {
          return _notApplicable(version, RuleScope.trade,
              'No checklist was presented for this trade.', trade.id);
        }
        // Default expectation is full completion when no threshold is set.
        final required = version.threshold ?? Dec.one;
        final percent = (ratio * Dec.hundred).roundTo(0);
        final requiredPercent = (required * Dec.hundred).roundTo(0);
        return _compare(
          version: version,
          scope: RuleScope.trade,
          tradeId: trade.id,
          passed: ratio >= required,
          observed: '$percent%',
          threshold: '$requiredPercent%',
          passMessage: 'Completed $percent% of your pre-trade checklist.',
          failMessage: 'Completed only $percent% of your pre-trade checklist; '
              'you require $requiredPercent%.',
        );

      case RuleMeasure.notesRequired:
        return _compare(
          version: version,
          scope: RuleScope.trade,
          tradeId: trade.id,
          passed: trade.hasNotes,
          observed: trade.hasNotes ? 'Notes present' : 'No notes',
          threshold: 'Notes required',
          passMessage: 'You recorded your reasoning for this trade.',
          failMessage: 'No entry reason or management notes were recorded.',
        );

      case RuleMeasure.screenshotRequired:
        return _compare(
          version: version,
          scope: RuleScope.trade,
          tradeId: trade.id,
          passed: trade.hasAttachment,
          observed:
              trade.hasAttachment ? '${trade.attachmentIds.length} attached' : 'None',
          threshold: 'Screenshot required',
          passMessage: 'A chart screenshot is attached.',
          failMessage: 'No chart screenshot was attached.',
        );

      case RuleMeasure.noAddingToLosers:
        final added = _addedToLoser(trade);
        return _compare(
          version: version,
          scope: RuleScope.trade,
          tradeId: trade.id,
          passed: !added,
          observed: added ? 'Added while losing' : 'No adds while losing',
          threshold: 'Never add to a loser',
          passMessage: 'You did not add to this position while it was losing.',
          failMessage: 'You added to this position at a price worse than your '
              'average entry.',
        );

      // Day- and week-scoped measures never reach here.
      case RuleMeasure.maxTradesPerDay:
      case RuleMeasure.maxDailyLossMoney:
      case RuleMeasure.maxDailyLossPercent:
      case RuleMeasure.maxDailyLossR:
      case RuleMeasure.maxConsecutiveLosses:
      case RuleMeasure.noTradingAfterDailyStop:
      case RuleMeasure.maxWeeklyLossMoney:
      case RuleMeasure.maxWeeklyLossR:
      case RuleMeasure.dailyReviewCompleted:
      case RuleMeasure.manualCustom:
        return _notApplicable(version, RuleScope.trade,
            'Evaluated at day level.', trade.id);
    }
  }

  /// Detects an entry fill placed at a price worse than the running average
  /// entry — the deterministic signature of averaging down (or up, if short).
  static bool _addedToLoser(Trade trade) {
    final entries = trade.entries.toList(growable: false)
      ..sort((a, b) => a.timestampUtc.compareTo(b.timestampUtc));
    if (entries.length < 2) return false;

    var notional = entries.first.price * entries.first.quantity.abs;
    var quantity = entries.first.quantity.abs;

    for (final execution in entries.skip(1)) {
      if (quantity.isZero) break;
      final average = notional.divide(quantity, scale: 10);
      final worse = trade.direction == TradeDirection.long
          ? execution.price < average
          : execution.price > average;
      if (worse) return true;
      notional += execution.price * execution.quantity.abs;
      quantity += execution.quantity.abs;
    }
    return false;
  }

  static List<RuleEvaluation> _evaluateDayScope({
    required List<Trade> taken,
    required List<Rule> rules,
    required DayContext context,
  }) {
    final results = <RuleEvaluation>[];

    // Precompute the day's realised totals once.
    var dayNetPnl = Dec.zero;
    var dayTotalR = Dec.zero;
    final outcomes = <TradeOutcome?>[];
    for (final trade in taken) {
      final metrics = TradeCalculator.compute(trade);
      if (metrics.netPnl != null) dayNetPnl += metrics.netPnl!;
      if (metrics.realizedR != null) dayTotalR += metrics.realizedR!;
      outcomes.add(metrics.outcome);
    }

    // The instant the day's configured loss stop was first breached, used by
    // `noTradingAfterDailyStop`.
    final stopBreachIndex = _dailyStopBreachIndex(taken, rules, context);

    for (final rule in rules) {
      final anchor = taken.isEmpty
          ? DateTime.now().toUtc()
          : taken.first.openedAtUtc;
      final version = rule.versionAt(anchor) ?? rule.current;
      final scope = version.measure.scope;
      if (scope == RuleScope.trade) continue;

      if (!rule.isActive) {
        results.add(_notApplicable(version, scope, 'Rule is paused.', null));
        continue;
      }
      if (version.weekdays.isNotEmpty &&
          !version.weekdays.contains(context.weekday)) {
        results.add(_notApplicable(
            version, scope, 'Rule does not apply on this day.', null));
        continue;
      }

      switch (version.measure) {
        case RuleMeasure.maxTradesPerDay:
          final count = taken.length;
          final limit = version.threshold ?? Dec.fromInt(count);
          results.add(_compare(
            version: version,
            scope: scope,
            passed: Dec.fromInt(count) <= limit,
            observed: '$count',
            threshold: limit.normalized.toString(),
            passMessage: 'Took $count of your maximum ${limit.normalized} '
                'trades.',
            failMessage: 'Took $count trades against a maximum of '
                '${limit.normalized}.',
          ));

        case RuleMeasure.maxDailyLossMoney:
          if (taken.isEmpty) {
            results.add(_notApplicable(
                version, scope, 'No trades were taken.', null));
            break;
          }
          final loss = dayNetPnl.isNegative ? dayNetPnl.abs : Dec.zero;
          final limit = version.threshold;
          final shown = context.account.money(loss).format();
          final limitShown = limit == null
              ? '-'
              : context.account.money(limit).format();
          results.add(_compare(
            version: version,
            scope: scope,
            passed: limit == null || loss <= limit,
            observed: shown,
            threshold: limitShown,
            passMessage: 'Day loss of $shown stayed inside your $limitShown '
                'limit.',
            failMessage: 'Day loss of $shown exceeded your $limitShown limit.',
          ));

        case RuleMeasure.maxDailyLossPercent:
          if (taken.isEmpty) {
            results.add(_notApplicable(
                version, scope, 'No trades were taken.', null));
            break;
          }
          final equity = context.account.riskBaseEquity;
          if (equity.isZero) {
            results.add(_indeterminate(version, scope,
                'Add your account equity to measure percentage limits.', null));
            break;
          }
          final loss = dayNetPnl.isNegative ? dayNetPnl.abs : Dec.zero;
          final percent = loss.percentOf(equity, scale: 4) ?? Dec.zero;
          results.add(_compare(
            version: version,
            scope: scope,
            passed:
                version.threshold == null || percent <= version.threshold!,
            observed: '${percent.roundTo(2).normalized}%',
            threshold: '${version.threshold?.normalized ?? '-'}%',
            passMessage: 'Day loss of ${percent.roundTo(2).normalized}% stayed '
                'inside your ${version.threshold?.normalized}% limit.',
            failMessage: 'Day loss of ${percent.roundTo(2).normalized}% '
                'exceeded your ${version.threshold?.normalized}% limit.',
          ));

        case RuleMeasure.maxDailyLossR:
          if (taken.isEmpty) {
            results.add(_notApplicable(
                version, scope, 'No trades were taken.', null));
            break;
          }
          final lossR = dayTotalR.isNegative ? dayTotalR.abs : Dec.zero;
          final shown = lossR.roundTo(2).normalized;
          final limit = version.threshold?.normalized;
          results.add(_compare(
            version: version,
            scope: scope,
            passed:
                version.threshold == null || lossR <= version.threshold!,
            observed: '${shown}R',
            threshold: '${limit}R',
            passMessage: 'Lost ${shown}R, inside your ${limit}R daily stop.',
            failMessage: 'Lost ${shown}R against a ${limit}R daily stop.',
          ));

        case RuleMeasure.maxConsecutiveLosses:
          if (version.threshold == null) {
            results.add(_notApplicable(
                version, scope, 'No limit configured.', null));
            break;
          }
          final limit = version.threshold!;
          final continuedAfter =
              _tradedAfterConsecutiveLosses(outcomes, limit);
          final longest = _longestLossRun(outcomes);
          results.add(_compare(
            version: version,
            scope: scope,
            passed: !continuedAfter,
            observed: '$longest in a row',
            threshold: '${limit.normalized} in a row',
            passMessage: 'You stopped after your configured run of losses.',
            failMessage: 'You kept trading after ${limit.normalized} '
                'consecutive losses.',
          ));

        case RuleMeasure.noTradingAfterDailyStop:
          if (stopBreachIndex == null) {
            results.add(_compare(
              version: version,
              scope: scope,
              passed: true,
              observed: 'Stop not reached',
              threshold: 'Stop trading at the daily limit',
              passMessage: 'Your daily stop was never reached.',
              failMessage: '',
            ));
            break;
          }
          final tradesAfter = taken.length - (stopBreachIndex + 1);
          results.add(_compare(
            version: version,
            scope: scope,
            passed: tradesAfter <= 0,
            observed: '$tradesAfter after the stop',
            threshold: 'Stop trading at the daily limit',
            passMessage: 'You reached your daily stop and stopped trading.',
            failMessage: 'You took $tradesAfter more '
                '${tradesAfter == 1 ? 'trade' : 'trades'} after reaching your '
                'daily stop.',
          ));

        case RuleMeasure.maxWeeklyLossMoney:
          final weekPnl = context.weekNetPnl;
          if (weekPnl == null) {
            results.add(_indeterminate(
                version, scope, 'Week-to-date result is not available.', null));
            break;
          }
          final loss = weekPnl.isNegative ? weekPnl.abs : Dec.zero;
          final shown = context.account.money(loss).format();
          final limitShown = version.threshold == null
              ? '-'
              : context.account.money(version.threshold!).format();
          results.add(_compare(
            version: version,
            scope: scope,
            passed:
                version.threshold == null || loss <= version.threshold!,
            observed: shown,
            threshold: limitShown,
            passMessage: 'Week-to-date loss of $shown is inside your '
                '$limitShown limit.',
            failMessage: 'Week-to-date loss of $shown exceeded your '
                '$limitShown limit.',
          ));

        case RuleMeasure.maxWeeklyLossR:
          final weekR = context.weekTotalR;
          if (weekR == null) {
            results.add(_indeterminate(
                version, scope, 'Week-to-date R is not available.', null));
            break;
          }
          final lossR = weekR.isNegative ? weekR.abs : Dec.zero;
          final shown = lossR.roundTo(2).normalized;
          results.add(_compare(
            version: version,
            scope: scope,
            passed:
                version.threshold == null || lossR <= version.threshold!,
            observed: '${shown}R',
            threshold: '${version.threshold?.normalized}R',
            passMessage: 'Week-to-date loss of ${shown}R is inside your limit.',
            failMessage: 'Week-to-date loss of ${shown}R exceeded your '
                '${version.threshold?.normalized}R limit.',
          ));

        case RuleMeasure.dailyReviewCompleted:
          results.add(_compare(
            version: version,
            scope: scope,
            passed: context.dailyReviewCompleted,
            observed: context.dailyReviewCompleted ? 'Completed' : 'Not done',
            threshold: 'Complete the daily review',
            passMessage: 'You completed your daily review.',
            failMessage: 'The daily review for this day is not complete yet.',
          ));

        case RuleMeasure.manualCustom:
          final reported = context.manualCompliance[rule.id];
          if (reported == null) {
            results.add(_indeterminate(version, scope,
                'Mark whether you followed this rule to include it in your '
                'score.',
                null));
            break;
          }
          results.add(_compare(
            version: version,
            scope: scope,
            passed: reported,
            observed: reported ? 'Followed' : 'Broken',
            threshold: version.name,
            passMessage: 'You marked "${version.name}" as followed.',
            failMessage: 'You marked "${version.name}" as broken.',
          ));

        // Trade-scoped measures are handled per trade.
        case RuleMeasure.maxRiskPercentPerTrade:
        case RuleMeasure.maxRiskMoneyPerTrade:
        case RuleMeasure.minPlannedRewardRisk:
        case RuleMeasure.stopLossRequired:
        case RuleMeasure.approvedStrategyOnly:
        case RuleMeasure.sessionRestriction:
        case RuleMeasure.checklistCompletion:
        case RuleMeasure.notesRequired:
        case RuleMeasure.screenshotRequired:
        case RuleMeasure.noAddingToLosers:
          break;
      }
    }

    return results;
  }

  /// Index of the trade after which the day's loss stop had been breached, or
  /// `null` if it never was.
  ///
  /// Uses the tightest configured daily-loss rule so a user with both a money
  /// and an R stop is held to whichever binds first.
  static int? _dailyStopBreachIndex(
    List<Trade> taken,
    List<Rule> rules,
    DayContext context,
  ) {
    if (taken.isEmpty) return null;

    Dec? moneyLimit;
    Dec? rLimit;
    Dec? percentLimit;
    for (final rule in rules) {
      if (!rule.isActive) continue;
      final version = rule.versionAt(taken.first.openedAtUtc) ?? rule.current;
      final threshold = version.threshold;
      if (threshold == null) continue;
      switch (version.measure) {
        case RuleMeasure.maxDailyLossMoney:
          moneyLimit = moneyLimit == null || threshold < moneyLimit
              ? threshold
              : moneyLimit;
        case RuleMeasure.maxDailyLossR:
          rLimit = rLimit == null || threshold < rLimit ? threshold : rLimit;
        case RuleMeasure.maxDailyLossPercent:
          percentLimit = percentLimit == null || threshold < percentLimit
              ? threshold
              : percentLimit;
        default:
          break;
      }
    }
    if (moneyLimit == null && rLimit == null && percentLimit == null) {
      return null;
    }

    final equity = context.account.riskBaseEquity;
    var cumulativePnl = Dec.zero;
    var cumulativeR = Dec.zero;

    for (var i = 0; i < taken.length; i++) {
      final metrics = TradeCalculator.compute(taken[i]);
      if (metrics.netPnl != null) cumulativePnl += metrics.netPnl!;
      if (metrics.realizedR != null) cumulativeR += metrics.realizedR!;

      final loss = cumulativePnl.isNegative ? cumulativePnl.abs : Dec.zero;
      final lossR = cumulativeR.isNegative ? cumulativeR.abs : Dec.zero;

      if (moneyLimit != null && loss >= moneyLimit) return i;
      if (rLimit != null && lossR >= rLimit) return i;
      if (percentLimit != null && !equity.isZero) {
        final percent = loss.percentOf(equity, scale: 4) ?? Dec.zero;
        if (percent >= percentLimit) return i;
      }
    }
    return null;
  }

  static int _longestLossRun(List<TradeOutcome?> outcomes) {
    var longest = 0;
    var current = 0;
    for (final outcome in outcomes) {
      if (outcome == TradeOutcome.loss) {
        current++;
        if (current > longest) longest = current;
      } else {
        current = 0;
      }
    }
    return longest;
  }

  /// True when another trade was taken after the loss run reached [limit].
  static bool _tradedAfterConsecutiveLosses(
      List<TradeOutcome?> outcomes, Dec limit) {
    var run = 0;
    for (var i = 0; i < outcomes.length; i++) {
      if (Dec.fromInt(run) >= limit && limit > Dec.zero) {
        return true; // this trade was taken with the run already at the limit
      }
      if (outcomes[i] == TradeOutcome.loss) {
        run++;
      } else {
        run = 0;
      }
    }
    return false;
  }

  // ---- Evaluation constructors ----------------------------------------

  static RuleEvaluation _compare({
    required RuleVersion version,
    required RuleScope scope,
    required bool passed,
    required String observed,
    required String threshold,
    required String passMessage,
    required String failMessage,
    String? tradeId,
  }) =>
      RuleEvaluation(
        ruleId: version.ruleId,
        ruleVersionId: version.id,
        ruleName: version.name,
        category: version.category,
        severity: version.severity,
        measure: version.measure,
        scope: scope,
        status: passed ? RuleStatus.passed : RuleStatus.violated,
        observed: observed,
        threshold: threshold,
        message: passed ? passMessage : failMessage,
        tradeId: tradeId,
        weight: version.weight,
      );

  static RuleEvaluation _notApplicable(
    RuleVersion version,
    RuleScope scope,
    String message,
    String? tradeId,
  ) =>
      RuleEvaluation(
        ruleId: version.ruleId,
        ruleVersionId: version.id,
        ruleName: version.name,
        category: version.category,
        severity: version.severity,
        measure: version.measure,
        scope: scope,
        status: RuleStatus.notApplicable,
        message: message,
        tradeId: tradeId,
        weight: version.weight,
      );

  static RuleEvaluation _indeterminate(
    RuleVersion version,
    RuleScope scope,
    String message,
    String? tradeId,
  ) =>
      RuleEvaluation(
        ruleId: version.ruleId,
        ruleVersionId: version.id,
        ruleName: version.name,
        category: version.category,
        severity: version.severity,
        measure: version.measure,
        scope: scope,
        status: RuleStatus.indeterminate,
        message: message,
        tradeId: tradeId,
        weight: version.weight,
      );
}

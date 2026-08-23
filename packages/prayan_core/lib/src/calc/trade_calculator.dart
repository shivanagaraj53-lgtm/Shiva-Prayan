import '../models/enums.dart';
import '../models/trade.dart';
import '../money/dec.dart';

/// Everything derivable from a single [Trade] (brief §22).
///
/// Fields are nullable wherever the input does not determine them. A trade
/// with no stop has `plannedRisk == null`, not zero — the difference matters,
/// because zero risk would make the R-multiple infinite and quietly poison
/// every aggregate that touched it.
class TradeMetrics {
  /// Size-weighted average fill price of the entry legs.
  final Dec? averageEntryPrice;

  /// Size-weighted average fill price of the exit legs.
  final Dec? averageExitPrice;

  /// Total quantity entered.
  final Dec entryQuantity;

  /// Total quantity exited.
  final Dec exitQuantity;

  /// Quantity that is round-turned, i.e. matched by both an entry and an exit.
  final Dec closedQuantity;

  /// Quantity still exposed to the market.
  final Dec openQuantity;

  /// Notional of the entered position.
  final Dec? entryNotional;

  /// P&L before costs, on the closed portion only.
  final Dec? grossPnl;

  /// Sum of fees across every fill.
  final Dec fees;

  /// P&L after costs. This is the number the journal reports everywhere.
  final Dec? netPnl;

  /// Price distance from entry to stop, per unit.
  final Dec? riskPerUnit;

  /// Money at risk if the stop had been hit on the full planned size.
  final Dec? plannedRisk;

  /// [plannedRisk] as a percentage of account equity at plan time.
  final Dec? plannedRiskPercent;

  /// Planned reward:risk, e.g. `2.4` meaning 1:2.4.
  final Dec? plannedRewardRisk;

  /// Realised profit in units of planned risk. The core process metric.
  final Dec? realizedR;

  /// Realised reward:risk actually achieved on a winner.
  final Dec? realizedRewardRisk;

  final TradeOutcome? outcome;

  /// Wall-clock holding time of the closed portion.
  final Duration? holdingTime;

  /// True when the position was reduced in more than one fill.
  final bool isPartiallyExited;

  const TradeMetrics({
    required this.entryQuantity,
    required this.exitQuantity,
    required this.closedQuantity,
    required this.openQuantity,
    required this.fees,
    this.averageEntryPrice,
    this.averageExitPrice,
    this.entryNotional,
    this.grossPnl,
    this.netPnl,
    this.riskPerUnit,
    this.plannedRisk,
    this.plannedRiskPercent,
    this.plannedRewardRisk,
    this.realizedR,
    this.realizedRewardRisk,
    this.outcome,
    this.holdingTime,
    this.isPartiallyExited = false,
  });

  bool get hasRealizedResult => netPnl != null;
  bool get isWin => outcome == TradeOutcome.win;
  bool get isLoss => outcome == TradeOutcome.loss;
}

/// Anomalies found while validating a trade before it is saved.
class ValidationIssue {
  final String field;
  final String message;

  /// Blocking issues prevent a save; non-blocking ones are shown as a caution
  /// the user can knowingly override (brief §7: "validate impossible or
  /// suspicious values and explain errors clearly").
  final bool isBlocking;

  const ValidationIssue(this.field, this.message, {this.isBlocking = true});

  @override
  String toString() => '$field: $message';
}

/// Deterministic trade arithmetic.
///
/// Every method is pure and static. No UI widget performs this arithmetic
/// itself (brief §35), and the server recomputes the same values from the same
/// inputs so a tampered client cannot write an authoritative score.
class TradeCalculator {
  const TradeCalculator._();

  /// Working precision for intermediate price maths. Deliberately wider than
  /// any instrument's tick so rounding never happens mid-formula; results are
  /// rounded once at the display boundary.
  static const int _workingScale = 10;

  /// Below this absolute net P&L a trade is called breakeven rather than a
  /// win or loss, expressed as a fraction of planned risk (2% of 1R).
  static final Dec _breakevenRFraction = Dec.parse('0.02');

  /// Computes every derived metric for [trade].
  static TradeMetrics compute(Trade trade) {
    final entryQuantity = _sumQuantity(trade.entries);
    final exitQuantity = _sumQuantity(trade.exits);
    final fees = _sumFees(trade.executions);

    final averageEntryPrice =
        _weightedAveragePrice(trade.entries) ?? trade.plannedEntryPrice;
    final averageExitPrice = _weightedAveragePrice(trade.exits);

    final closedQuantity =
        entryQuantity <= exitQuantity ? entryQuantity : exitQuantity;
    final openQuantity = entryQuantity - closedQuantity;

    // --- Risk (available from the plan alone, before any fill) ------------
    // Planned risk uses the *planned* entry where one exists, so a trade that
    // was planned but filled at a worse price still reports the risk the user
    // signed up for. Actual slippage shows up in the realised R instead.
    final riskReferenceEntry = trade.plannedEntryPrice ?? averageEntryPrice;
    final stop = trade.stopLossPrice;
    Dec? riskPerUnit;
    if (riskReferenceEntry != null && stop != null) {
      riskPerUnit = (riskReferenceEntry - stop).abs;
    }

    final riskQuantity =
        trade.plannedQuantity ?? (entryQuantity.isZero ? null : entryQuantity);

    Dec? plannedRisk;
    if (riskPerUnit != null && riskQuantity != null && !riskPerUnit.isZero) {
      plannedRisk = (riskPerUnit * riskQuantity * trade.multiplier)
          .roundTo(_workingScale);
    }

    Dec? plannedRiskPercent;
    final equity = trade.accountEquityAtOpen;
    if (plannedRisk != null && equity != null && !equity.isZero) {
      plannedRiskPercent = plannedRisk.percentOf(equity, scale: 4);
    }

    Dec? plannedRewardRisk;
    final target = trade.targetPrice;
    if (riskReferenceEntry != null &&
        target != null &&
        riskPerUnit != null &&
        !riskPerUnit.isZero) {
      final reward = (target - riskReferenceEntry).abs;
      plannedRewardRisk = reward.divide(riskPerUnit, scale: 4);
    }

    Dec? entryNotional;
    if (averageEntryPrice != null && !entryQuantity.isZero) {
      entryNotional = (averageEntryPrice * entryQuantity * trade.multiplier)
          .roundTo(_workingScale);
    }

    // --- Realised result (only once something has been closed) -----------
    Dec? grossPnl;
    Dec? netPnl;
    TradeOutcome? outcome;
    Dec? realizedR;
    Dec? realizedRewardRisk;

    if (averageEntryPrice != null &&
        averageExitPrice != null &&
        !closedQuantity.isZero) {
      final perUnit = averageExitPrice - averageEntryPrice;
      final directed = trade.direction == TradeDirection.long
          ? perUnit
          : -perUnit; // short profits when price falls
      grossPnl =
          (directed * closedQuantity * trade.multiplier).roundTo(_workingScale);
      netPnl = (grossPnl - fees).roundTo(_workingScale);

      if (plannedRisk != null && !plannedRisk.isZero) {
        realizedR = netPnl.divide(plannedRisk, scale: 4);
        if (netPnl.isPositive) {
          realizedRewardRisk = realizedR;
        }
      }

      outcome = _classify(netPnl, plannedRisk);
    }

    Duration? holdingTime;
    if (trade.closedAtUtc != null) {
      final span = trade.closedAtUtc!.difference(trade.openedAtUtc);
      holdingTime = span.isNegative ? Duration.zero : span;
    }

    return TradeMetrics(
      entryQuantity: entryQuantity,
      exitQuantity: exitQuantity,
      closedQuantity: closedQuantity,
      openQuantity: openQuantity,
      fees: fees,
      averageEntryPrice: averageEntryPrice,
      averageExitPrice: averageExitPrice,
      entryNotional: entryNotional,
      grossPnl: grossPnl,
      netPnl: netPnl,
      riskPerUnit: riskPerUnit,
      plannedRisk: plannedRisk,
      plannedRiskPercent: plannedRiskPercent,
      plannedRewardRisk: plannedRewardRisk,
      realizedR: realizedR,
      realizedRewardRisk: realizedRewardRisk,
      outcome: outcome,
      holdingTime: holdingTime,
      isPartiallyExited: trade.exits.length > 1 ||
          (!openQuantity.isZero && !exitQuantity.isZero),
    );
  }

  /// Classifies a result, treating a negligible P&L as breakeven.
  ///
  /// The breakeven band is scaled to the trade's own risk when known, so a
  /// ₹40 result on a ₹200 risk is not reported as a "win".
  static TradeOutcome _classify(Dec netPnl, Dec? plannedRisk) {
    if (plannedRisk != null && !plannedRisk.isZero) {
      final band = plannedRisk.abs * _breakevenRFraction;
      if (netPnl.abs <= band) return TradeOutcome.breakeven;
    } else if (netPnl.isZero) {
      return TradeOutcome.breakeven;
    }
    if (netPnl.isPositive) return TradeOutcome.win;
    if (netPnl.isNegative) return TradeOutcome.loss;
    return TradeOutcome.breakeven;
  }

  static Dec _sumQuantity(Iterable<TradeExecution> executions) {
    var total = Dec.zero;
    for (final execution in executions) {
      total += execution.quantity.abs;
    }
    return total;
  }

  static Dec _sumFees(Iterable<TradeExecution> executions) {
    var total = Dec.zero;
    for (final execution in executions) {
      total += execution.fees;
    }
    return total;
  }

  /// Size-weighted average price, or `null` when there are no fills.
  static Dec? _weightedAveragePrice(Iterable<TradeExecution> executions) {
    var notional = Dec.zero;
    var quantity = Dec.zero;
    for (final execution in executions) {
      final size = execution.quantity.abs;
      notional += execution.price * size;
      quantity += size;
    }
    if (quantity.isZero) return null;
    return notional.divide(quantity, scale: _workingScale);
  }

  /// Pre-save sanity checks (brief §7, §26).
  ///
  /// Returns an empty list for a valid trade. Blocking issues describe states
  /// that are arithmetically impossible; non-blocking ones describe states
  /// that are merely unusual and may be intentional.
  static List<ValidationIssue> validate(Trade trade) {
    final issues = <ValidationIssue>[];

    if (trade.symbol.trim().isEmpty) {
      issues.add(
          const ValidationIssue('symbol', 'Add the instrument you traded.'));
    }
    if (trade.multiplier.isZero || trade.multiplier.isNegative) {
      issues.add(const ValidationIssue(
          'multiplier', 'Contract multiplier must be greater than zero.'));
    }

    for (final execution in trade.executions) {
      if (execution.quantity.isNegative || execution.quantity.isZero) {
        issues.add(const ValidationIssue(
            'executions', 'Every fill needs a quantity greater than zero.'));
        break;
      }
    }
    for (final execution in trade.executions) {
      if (execution.price.isNegative) {
        issues.add(const ValidationIssue(
            'executions', 'A fill price cannot be negative.'));
        break;
      }
    }

    final entryQuantity = _sumQuantity(trade.entries);
    final exitQuantity = _sumQuantity(trade.exits);
    if (exitQuantity > entryQuantity) {
      issues.add(const ValidationIssue(
          'executions', 'You have exited more quantity than you entered.'));
    }

    final entry =
        trade.plannedEntryPrice ?? _weightedAveragePrice(trade.entries);
    final stop = trade.stopLossPrice;
    final target = trade.targetPrice;

    // A stop on the wrong side of entry is not a stop — it is a second target,
    // and it would silently invert every risk figure on the trade.
    if (entry != null && stop != null && !stop.isZero) {
      if (trade.direction == TradeDirection.long && stop >= entry) {
        issues.add(const ValidationIssue('stopLossPrice',
            'For a long trade the stop must sit below your entry.'));
      }
      if (trade.direction == TradeDirection.short && stop <= entry) {
        issues.add(const ValidationIssue('stopLossPrice',
            'For a short trade the stop must sit above your entry.'));
      }
    }
    if (entry != null && target != null && !target.isZero) {
      if (trade.direction == TradeDirection.long && target <= entry) {
        issues.add(const ValidationIssue('targetPrice',
            'For a long trade the target must sit above your entry.'));
      }
      if (trade.direction == TradeDirection.short && target >= entry) {
        issues.add(const ValidationIssue('targetPrice',
            'For a short trade the target must sit below your entry.'));
      }
    }

    if (trade.status == TradeStatus.closed && trade.exits.isEmpty) {
      issues.add(const ValidationIssue(
          'status', 'A closed trade needs at least one exit fill.'));
    }
    if (trade.closedAtUtc != null &&
        trade.closedAtUtc!.isBefore(trade.openedAtUtc)) {
      issues.add(const ValidationIssue(
          'closedAtUtc', 'The exit time is before the entry time.'));
    }
    if (trade.confidence != null &&
        (trade.confidence! < 1 || trade.confidence! > 10)) {
      issues.add(const ValidationIssue(
          'confidence', 'Confidence is rated from 1 to 10.'));
    }

    if (stop == null && trade.status != TradeStatus.planned) {
      issues.add(const ValidationIssue('stopLossPrice',
          'No stop recorded, so risk and R-multiple cannot be measured.',
          isBlocking: false));
    }

    final equity = trade.accountEquityAtOpen;
    if (equity != null && equity.isNegative) {
      issues.add(const ValidationIssue(
          'accountEquityAtOpen', 'Account equity cannot be negative.'));
    }

    return issues;
  }
}

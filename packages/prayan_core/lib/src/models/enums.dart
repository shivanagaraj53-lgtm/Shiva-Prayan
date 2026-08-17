/// Domain vocabulary shared by the journal, the rules engine and analytics.
///
/// Every enum here is persisted by its [wireName], never by its ordinal
/// position. Firestore documents outlive app builds, so reordering an enum
/// must never silently reinterpret historical trades.
library;

/// Restores an enum from its persisted name, falling back to [fallback] when a
/// document written by a newer client carries an unknown value.
T decodeEnum<T>(
  Iterable<T> values,
  String? name,
  String Function(T) nameOf,
  T fallback,
) {
  if (name == null) return fallback;
  for (final value in values) {
    if (nameOf(value) == name) return value;
  }
  return fallback;
}

enum AssetClass {
  equity('equity', 'Equity'),
  futures('futures', 'Futures'),
  options('options', 'Options'),
  forex('forex', 'Forex'),
  crypto('crypto', 'Crypto'),
  commodity('commodity', 'Commodity'),
  bond('bond', 'Bond'),
  other('other', 'Other');

  const AssetClass(this.wireName, this.label);
  final String wireName;
  final String label;

  /// Instruments whose notional is a multiple of the quoted price. Getting
  /// this wrong understates risk by the lot size, so the trade form surfaces
  /// the multiplier field for these.
  bool get usesContractMultiplier =>
      this == AssetClass.futures ||
      this == AssetClass.options ||
      this == AssetClass.commodity;

  static AssetClass fromWire(String? name) =>
      decodeEnum(values, name, (v) => v.wireName, AssetClass.equity);
}

enum TradeDirection {
  long('long', 'Long'),
  short('short', 'Short');

  const TradeDirection(this.wireName, this.label);
  final String wireName;
  final String label;

  /// +1 for long, -1 for short. Every P&L and risk formula multiplies by this
  /// instead of branching, which keeps short handling from drifting.
  int get sign => this == TradeDirection.long ? 1 : -1;

  static TradeDirection fromWire(String? name) =>
      decodeEnum(values, name, (v) => v.wireName, TradeDirection.long);
}

enum TradeStatus {
  /// Planned before entry — the pre-trade plan exists but no position is open.
  planned('planned', 'Planned'),
  open('open', 'Open'),
  closed('closed', 'Closed'),

  /// Planned but never taken. Counts as discipline, not as a trade.
  cancelled('cancelled', 'Cancelled');

  const TradeStatus(this.wireName, this.label);
  final String wireName;
  final String label;

  static TradeStatus fromWire(String? name) =>
      decodeEnum(values, name, (v) => v.wireName, TradeStatus.planned);
}

enum TradeOutcome {
  win('win', 'Win'),
  loss('loss', 'Loss'),
  breakeven('breakeven', 'Breakeven');

  const TradeOutcome(this.wireName, this.label);
  final String wireName;
  final String label;

  static TradeOutcome fromWire(String? name) =>
      decodeEnum(values, name, (v) => v.wireName, TradeOutcome.breakeven);
}

/// Emotional state tags (brief §13).
///
/// Deliberately plain-language and non-clinical: these are self-reported
/// journalling labels, not a psychological assessment.
enum EmotionTag {
  calm('calm', 'Calm'),
  focused('focused', 'Focused'),
  confident('confident', 'Confident'),
  neutral('neutral', 'Neutral'),
  anxious('anxious', 'Anxious'),
  fomo('fomo', 'FOMO'),
  frustrated('frustrated', 'Frustrated'),
  overconfident('overconfident', 'Overconfident'),
  tired('tired', 'Tired'),
  distracted('distracted', 'Distracted'),
  bored('bored', 'Bored');

  const EmotionTag(this.wireName, this.label);
  final String wireName;
  final String label;

  /// States the coaching layer treats as elevated-risk context. Used only to
  /// surface the user's own observed patterns — never to block trading.
  bool get isElevatedRisk => const {
        EmotionTag.anxious,
        EmotionTag.fomo,
        EmotionTag.frustrated,
        EmotionTag.overconfident,
        EmotionTag.tired,
        EmotionTag.distracted,
        EmotionTag.bored,
      }.contains(this);

  static EmotionTag fromWire(String? name) =>
      decodeEnum(values, name, (v) => v.wireName, EmotionTag.neutral);
}

enum MistakeCategory {
  none('none', 'No mistake'),
  noStop('noStop', 'Entered without a stop'),
  movedStop('movedStop', 'Widened the stop'),
  oversized('oversized', 'Position too large'),
  earlyExit('earlyExit', 'Exited before the plan'),
  lateExit('lateExit', 'Held past the plan'),
  chasedEntry('chasedEntry', 'Chased the entry'),
  revengeTrade('revengeTrade', 'Revenge trade'),
  unapprovedSetup('unapprovedSetup', 'Unapproved setup'),
  overtrading('overtrading', 'Overtraded'),
  addedToLoser('addedToLoser', 'Added to a loser'),
  ignoredPlan('ignoredPlan', 'Ignored the plan'),
  other('other', 'Other');

  const MistakeCategory(this.wireName, this.label);
  final String wireName;
  final String label;

  static MistakeCategory fromWire(String? name) =>
      decodeEnum(values, name, (v) => v.wireName, MistakeCategory.none);
}

/// Market session buckets. Actual clock ranges are per-market configuration;
/// this is the coarse label used for "no trading outside my session" rules and
/// time-of-day analytics.
enum MarketSession {
  preMarket('preMarket', 'Pre-market'),
  open('open', 'Opening'),
  midday('midday', 'Mid-session'),
  close('close', 'Closing'),
  afterHours('afterHours', 'After hours'),
  overnight('overnight', 'Overnight');

  const MarketSession(this.wireName, this.label);
  final String wireName;
  final String label;

  static MarketSession fromWire(String? name) =>
      decodeEnum(values, name, (v) => v.wireName, MarketSession.midday);
}

/// How severely a rule breach is treated (brief §8, §9).
enum RuleSeverity {
  /// Recorded and explained, no score impact. For habits being trialled.
  info('info', 'Informational', 0),

  /// Reduces the discipline score proportionally to its weight.
  warning('warning', 'Warning', 1),

  /// Reduces the score, caps the day, and resets the clean streak.
  major('major', 'Major', 2);

  const RuleSeverity(this.wireName, this.label, this.rank);
  final String wireName;
  final String label;
  final int rank;

  bool get affectsScore => this != RuleSeverity.info;
  bool get resetsStreak => this == RuleSeverity.major;

  static RuleSeverity fromWire(String? name) =>
      decodeEnum(values, name, (v) => v.wireName, RuleSeverity.warning);
}

/// The scoring bucket a rule contributes to (brief §38).
///
/// Weights are configured per category, so several user rules can share a
/// bucket without any one of them dominating the score.
enum RuleCategory {
  riskLimit('riskLimit', 'Risk limit', 25),
  stopLoss('stopLoss', 'Stop discipline', 15),
  rewardRisk('rewardRisk', 'Reward:risk', 15),
  approvedSetup('approvedSetup', 'Approved setup', 15),
  dailyLimits('dailyLimits', 'Daily limits', 15),
  checklist('checklist', 'Pre-trade checklist', 10),
  journalQuality('journalQuality', 'Journal & review', 5),
  custom('custom', 'Custom', 10);

  const RuleCategory(this.wireName, this.label, this.defaultWeight);
  final String wireName;
  final String label;

  /// Percentage points from the brief's starting model. Users may override.
  final int defaultWeight;

  static RuleCategory fromWire(String? name) =>
      decodeEnum(values, name, (v) => v.wireName, RuleCategory.custom);
}

/// What a rule measures. Determines which evaluator runs and which unit the
/// threshold is expressed in.
enum RuleMeasure {
  maxRiskPercentPerTrade('maxRiskPercentPerTrade', RuleScope.trade),
  maxRiskMoneyPerTrade('maxRiskMoneyPerTrade', RuleScope.trade),
  minPlannedRewardRisk('minPlannedRewardRisk', RuleScope.trade),
  stopLossRequired('stopLossRequired', RuleScope.trade),
  approvedStrategyOnly('approvedStrategyOnly', RuleScope.trade),
  sessionRestriction('sessionRestriction', RuleScope.trade),
  checklistCompletion('checklistCompletion', RuleScope.trade),
  notesRequired('notesRequired', RuleScope.trade),
  screenshotRequired('screenshotRequired', RuleScope.trade),
  noAddingToLosers('noAddingToLosers', RuleScope.trade),
  maxTradesPerDay('maxTradesPerDay', RuleScope.day),
  maxDailyLossMoney('maxDailyLossMoney', RuleScope.day),
  maxDailyLossPercent('maxDailyLossPercent', RuleScope.day),
  maxDailyLossR('maxDailyLossR', RuleScope.day),
  maxConsecutiveLosses('maxConsecutiveLosses', RuleScope.day),
  noTradingAfterDailyStop('noTradingAfterDailyStop', RuleScope.day),
  maxWeeklyLossMoney('maxWeeklyLossMoney', RuleScope.week),
  maxWeeklyLossR('maxWeeklyLossR', RuleScope.week),
  dailyReviewCompleted('dailyReviewCompleted', RuleScope.day),

  /// A rule the engine cannot evaluate automatically; the user self-reports
  /// compliance. Kept explicit so the score never silently assumes a pass.
  manualCustom('manualCustom', RuleScope.day);

  const RuleMeasure(this.wireName, this.scope);
  final String wireName;
  final RuleScope scope;

  static RuleMeasure fromWire(String? name) =>
      decodeEnum(values, name, (v) => v.wireName, RuleMeasure.manualCustom);
}

/// The unit of evaluation a rule applies to.
enum RuleScope {
  trade('trade'),
  day('day'),
  week('week');

  const RuleScope(this.wireName);
  final String wireName;

  static RuleScope fromWire(String? name) =>
      decodeEnum(values, name, (v) => v.wireName, RuleScope.trade);
}

/// Outcome of evaluating one rule against one trade or day.
enum RuleStatus {
  /// The rule applied and was followed.
  passed('passed'),

  /// The rule applied and was breached.
  violated('violated'),

  /// The rule did not apply here (wrong day, wrong strategy, inactive).
  /// Excluded from the score denominator entirely (brief §38).
  notApplicable('notApplicable'),

  /// The rule applied but the data needed to judge it is missing. Never
  /// silently counted as a pass — surfaced so the user can complete the entry.
  indeterminate('indeterminate');

  const RuleStatus(this.wireName);
  final String wireName;

  static RuleStatus fromWire(String? name) =>
      decodeEnum(values, name, (v) => v.wireName, RuleStatus.notApplicable);
}

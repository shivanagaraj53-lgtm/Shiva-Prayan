import '../money/dec.dart';
import 'enums.dart';

/// An immutable snapshot of a rule's configuration.
///
/// Rules are versioned (brief §21). Editing a rule creates a new
/// [RuleVersion] rather than mutating the old one, so a trade from March is
/// always re-evaluated against the thresholds that were live in March. Without
/// this, tightening a limit would retroactively turn a compliant month into a
/// violation-riddled one and destroy the audit trail.
class RuleVersion {
  final String id;
  final String ruleId;

  /// Monotonic, starting at 1.
  final int version;

  final String name;
  final String description;
  final RuleCategory category;
  final RuleSeverity severity;
  final RuleMeasure measure;

  /// The comparison threshold, in the unit implied by [measure]:
  /// percent for `maxRiskPercentPerTrade`, a ratio for
  /// `minPlannedRewardRisk`, a count for `maxTradesPerDay`, R for
  /// `maxDailyLossR`, account currency for money measures. Null for boolean
  /// measures such as `stopLossRequired`.
  final Dec? threshold;

  /// Restricts the rule to given weekdays (`DateTime.monday`..`sunday`).
  /// Empty means every day.
  final List<int> weekdays;

  /// Restricts to specific sessions. Empty means all.
  final List<MarketSession> sessions;

  /// Restricts to specific strategies. Empty means all.
  final List<String> strategyIds;

  /// Restricts to specific asset classes. Empty means all.
  final List<AssetClass> assetClasses;

  /// Relative weight inside [category]. Two rules in the same category split
  /// that category's weight in proportion to this.
  final int weight;

  final DateTime effectiveFromUtc;

  /// Null while this is the live version.
  final DateTime? effectiveToUtc;

  const RuleVersion({
    required this.id,
    required this.ruleId,
    required this.version,
    required this.name,
    required this.description,
    required this.category,
    required this.severity,
    required this.measure,
    required this.effectiveFromUtc,
    this.threshold,
    this.weekdays = const [],
    this.sessions = const [],
    this.strategyIds = const [],
    this.assetClasses = const [],
    this.weight = 1,
    this.effectiveToUtc,
  });

  /// True when this version governed the instant [atUtc].
  bool wasEffectiveAt(DateTime atUtc) {
    if (atUtc.isBefore(effectiveFromUtc)) return false;
    final end = effectiveToUtc;
    return end == null || atUtc.isBefore(end);
  }

  /// Whether this rule's scope filters admit the given trade context.
  ///
  /// A rule that does not apply is reported as [RuleStatus.notApplicable] and
  /// removed from the score denominator, never counted as a free pass.
  /// [ignoreSessions] skips the session filter entirely. Needed by
  /// `sessionRestriction`, where [sessions] is the *allowed* set the rule
  /// tests against rather than a filter narrowing when the rule applies —
  /// filtering on it there would make the rule unable to ever fail.
  bool matchesContext({
    required int weekday,
    MarketSession? session,
    String? strategyId,
    AssetClass? assetClass,
    bool ignoreSessions = false,
  }) {
    if (weekdays.isNotEmpty && !weekdays.contains(weekday)) return false;
    if (!ignoreSessions &&
        sessions.isNotEmpty &&
        (session == null || !sessions.contains(session))) {
      return false;
    }
    if (strategyIds.isNotEmpty &&
        (strategyId == null || !strategyIds.contains(strategyId))) {
      return false;
    }
    if (assetClasses.isNotEmpty &&
        (assetClass == null || !assetClasses.contains(assetClass))) {
      return false;
    }
    return true;
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'ruleId': ruleId,
        'version': version,
        'name': name,
        'description': description,
        'category': category.wireName,
        'severity': severity.wireName,
        'measure': measure.wireName,
        'threshold': threshold?.toString(),
        'weekdays': weekdays,
        'sessions': sessions.map((s) => s.wireName).toList(),
        'strategyIds': strategyIds,
        'assetClasses': assetClasses.map((a) => a.wireName).toList(),
        'weight': weight,
        'effectiveFromUtc': effectiveFromUtc.toUtc().toIso8601String(),
        'effectiveToUtc': effectiveToUtc?.toUtc().toIso8601String(),
      };

  factory RuleVersion.fromMap(Map<String, dynamic> map) => RuleVersion(
        id: map['id'] as String? ?? '',
        ruleId: map['ruleId'] as String? ?? '',
        version: (map['version'] as num?)?.toInt() ?? 1,
        name: map['name'] as String? ?? '',
        description: map['description'] as String? ?? '',
        category: RuleCategory.fromWire(map['category'] as String?),
        severity: RuleSeverity.fromWire(map['severity'] as String?),
        measure: RuleMeasure.fromWire(map['measure'] as String?),
        threshold: map['threshold'] == null
            ? null
            : Dec.tryParse('${map['threshold']}'),
        weekdays: ((map['weekdays'] as List?) ?? const [])
            .map((e) => (e as num).toInt())
            .toList(growable: false),
        sessions: ((map['sessions'] as List?) ?? const [])
            .map((e) => MarketSession.fromWire('$e'))
            .toList(growable: false),
        strategyIds: ((map['strategyIds'] as List?) ?? const []).cast<String>(),
        assetClasses: ((map['assetClasses'] as List?) ?? const [])
            .map((e) => AssetClass.fromWire('$e'))
            .toList(growable: false),
        weight: (map['weight'] as num?)?.toInt() ?? 1,
        effectiveFromUtc:
            DateTime.tryParse('${map['effectiveFromUtc']}')?.toUtc() ??
                DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        effectiveToUtc: DateTime.tryParse('${map['effectiveToUtc']}')?.toUtc(),
      );
}

/// The stable identity of a discipline rule across all its versions.
class Rule {
  final String id;
  final String userId;

  /// The version currently in force.
  final RuleVersion current;

  /// Superseded versions, newest first. Historical evaluation walks these.
  final List<RuleVersion> history;

  /// A user can pause a rule without deleting it; paused rules evaluate as
  /// not-applicable from the moment they are paused.
  final bool isActive;

  final int position;

  const Rule({
    required this.id,
    required this.userId,
    required this.current,
    this.history = const [],
    this.isActive = true,
    this.position = 0,
  });

  /// The version that governed [atUtc], or `null` if the rule did not yet
  /// exist then — in which case a historical trade is simply not judged by it.
  RuleVersion? versionAt(DateTime atUtc) {
    if (current.wasEffectiveAt(atUtc)) return current;
    for (final version in history) {
      if (version.wasEffectiveAt(atUtc)) return version;
    }
    return null;
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'current': current.toMap(),
        'history': history.map((v) => v.toMap()).toList(),
        'isActive': isActive,
        'position': position,
      };

  factory Rule.fromMap(Map<String, dynamic> map) => Rule(
        id: map['id'] as String? ?? '',
        userId: map['userId'] as String? ?? '',
        current: RuleVersion.fromMap(
            ((map['current'] as Map?) ?? const {}).cast<String, dynamic>()),
        history: ((map['history'] as List?) ?? const [])
            .whereType<Map<Object?, Object?>>()
            .map((e) => RuleVersion.fromMap(e.cast<String, dynamic>()))
            .toList(growable: false),
        isActive: map['isActive'] as bool? ?? true,
        position: (map['position'] as num?)?.toInt() ?? 0,
      );
}

/// The result of evaluating one rule version against one trade or day.
///
/// This is the atom of the audit trail. Every number the Discipline Score
/// shows can be traced back to a list of these (brief §10).
class RuleEvaluation {
  final String ruleId;
  final String ruleVersionId;
  final String ruleName;
  final RuleCategory category;
  final RuleSeverity severity;
  final RuleMeasure measure;
  final RuleScope scope;
  final RuleStatus status;

  /// What the trade/day actually measured, formatted for display.
  final String? observed;

  /// The configured limit, formatted for display.
  final String? threshold;

  /// One plain sentence explaining the verdict, shown verbatim in the audit
  /// trail. Never contains jargon or raw error text (brief §26).
  final String message;

  /// The trade this applies to; null for day- and week-scoped rules.
  final String? tradeId;

  /// Relative weight of this rule inside its [category]. Carried on the
  /// evaluation so the scorer never has to re-resolve the rule version.
  final int weight;

  const RuleEvaluation({
    required this.ruleId,
    required this.ruleVersionId,
    required this.ruleName,
    required this.category,
    required this.severity,
    required this.measure,
    required this.scope,
    required this.status,
    required this.message,
    this.observed,
    this.threshold,
    this.tradeId,
    this.weight = 1,
  });

  bool get isViolation => status == RuleStatus.violated;
  bool get isMajorViolation => isViolation && severity == RuleSeverity.major;
  bool get countsTowardScore =>
      severity.affectsScore &&
      (status == RuleStatus.passed ||
          status == RuleStatus.violated ||
          status == RuleStatus.indeterminate);

  Map<String, dynamic> toMap() => {
        'ruleId': ruleId,
        'ruleVersionId': ruleVersionId,
        'ruleName': ruleName,
        'category': category.wireName,
        'severity': severity.wireName,
        'measure': measure.wireName,
        'scope': scope.wireName,
        'status': status.wireName,
        'observed': observed,
        'threshold': threshold,
        'message': message,
        'tradeId': tradeId,
        'weight': weight,
      };

  factory RuleEvaluation.fromMap(Map<String, dynamic> map) => RuleEvaluation(
        ruleId: map['ruleId'] as String? ?? '',
        ruleVersionId: map['ruleVersionId'] as String? ?? '',
        ruleName: map['ruleName'] as String? ?? '',
        category: RuleCategory.fromWire(map['category'] as String?),
        severity: RuleSeverity.fromWire(map['severity'] as String?),
        measure: RuleMeasure.fromWire(map['measure'] as String?),
        scope: RuleScope.fromWire(map['scope'] as String?),
        status: RuleStatus.fromWire(map['status'] as String?),
        observed: map['observed'] as String?,
        threshold: map['threshold'] as String?,
        message: map['message'] as String? ?? '',
        tradeId: map['tradeId'] as String?,
        weight: (map['weight'] as num?)?.toInt() ?? 1,
      );
}

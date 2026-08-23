import '../money/dec.dart';
import 'enums.dart';

/// One fill against a position.
///
/// Modelling entries and exits as a list of executions from day one is what
/// makes scale-in / scale-out possible later without a data migration
/// (brief §7). A simple single-entry/single-exit trade is just a trade with
/// one execution of each kind.
class TradeExecution {
  final String id;
  final ExecutionKind kind;

  /// Fill price, exact as entered.
  final Dec price;

  /// Absolute quantity filled. Always positive; direction lives on the trade.
  final Dec quantity;

  final DateTime timestampUtc;

  /// Fees attributable to this fill, in the account currency.
  final Dec fees;

  final String? note;

  // Not `const`: [Dec] wraps a [BigInt], which has no const constructor, so
  // there is no const zero to default `fees` to.
  TradeExecution({
    required this.id,
    required this.kind,
    required this.price,
    required this.quantity,
    required this.timestampUtc,
    Dec? fees,
    this.note,
  }) : fees = fees ?? Dec.zero;

  TradeExecution copyWith({
    String? id,
    ExecutionKind? kind,
    Dec? price,
    Dec? quantity,
    DateTime? timestampUtc,
    Dec? fees,
    String? note,
  }) =>
      TradeExecution(
        id: id ?? this.id,
        kind: kind ?? this.kind,
        price: price ?? this.price,
        quantity: quantity ?? this.quantity,
        timestampUtc: timestampUtc ?? this.timestampUtc,
        fees: fees ?? this.fees,
        note: note ?? this.note,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'kind': kind.wireName,
        'price': price.toString(),
        'quantity': quantity.toString(),
        'timestampUtc': timestampUtc.toUtc().toIso8601String(),
        'fees': fees.toString(),
        if (note != null) 'note': note,
      };

  factory TradeExecution.fromMap(Map<String, dynamic> map) => TradeExecution(
        id: map['id'] as String? ?? '',
        kind: ExecutionKind.fromWire(map['kind'] as String?),
        price: Dec.tryParse('${map['price']}') ?? Dec.zero,
        quantity: Dec.tryParse('${map['quantity']}') ?? Dec.zero,
        timestampUtc: DateTime.tryParse('${map['timestampUtc']}')?.toUtc() ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        fees: Dec.tryParse('${map['fees']}') ?? Dec.zero,
        note: map['note'] as String?,
      );
}

enum ExecutionKind {
  entry('entry'),
  exit('exit');

  const ExecutionKind(this.wireName);
  final String wireName;

  static ExecutionKind fromWire(String? name) =>
      decodeEnum(values, name, (v) => v.wireName, ExecutionKind.entry);
}

/// A single journalled trade: the plan, the execution and the reflection.
///
/// Prices and quantities are [Dec] rather than `double` throughout. Nullable
/// fields mean "not recorded" — the rules engine distinguishes a missing stop
/// from a stop of zero, because only one of those is a discipline breach.
class Trade {
  final String id;
  final String userId;
  final String accountId;

  // ---- Plan ------------------------------------------------------------
  final String symbol;
  final AssetClass assetClass;
  final TradeDirection direction;
  final String? strategyId;
  final TradeStatus status;

  /// Canonical instant of entry, always UTC. Rendered in the user's timezone
  /// at the presentation edge (brief §5).
  final DateTime openedAtUtc;
  final DateTime? closedAtUtc;

  /// The trading day this trade belongs to, as `yyyy-MM-dd` in the *user's*
  /// timezone. Precomputed because grouping by day is the single hottest
  /// query in the app and must not depend on the reader's clock.
  final String tradingDayKey;

  final MarketSession session;

  final Dec? plannedEntryPrice;
  final Dec? stopLossPrice;
  final Dec? targetPrice;

  /// Contract/lot multiplier. 1 for cash equity; 50 for an index future, etc.
  final Dec multiplier;

  /// Planned position size, used for pre-trade risk before any fill exists.
  final Dec? plannedQuantity;

  /// Account equity snapshot at plan time. Frozen on the trade so a later
  /// deposit cannot retroactively change whether a rule was breached.
  final Dec? accountEquityAtOpen;

  // ---- Execution -------------------------------------------------------
  final List<TradeExecution> executions;

  // ---- Reflection ------------------------------------------------------
  final String? entryReason;
  final String? exitReason;
  final String? managementNotes;
  final EmotionTag emotionBefore;
  final EmotionTag? emotionDuring;
  final EmotionTag? emotionAfter;

  /// Self-rated conviction, 1–10.
  final int? confidence;

  final MistakeCategory mistake;
  final List<String> tags;
  final List<String> attachmentIds;

  /// Checklist item ids the user ticked before entry.
  final List<String> completedChecklistItemIds;

  /// Checklist items that were presented, so completion can be scored as a
  /// ratio rather than assumed complete when the template later changes.
  final List<String> presentedChecklistItemIds;

  /// "Would I take this exact setup again?" (brief §7).
  final bool? wouldRepeat;

  /// True when the user marked this as taken outside the plan.
  final bool isImpulsive;

  // ---- Provenance ------------------------------------------------------
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;

  /// Set when a trade arrived from a future CSV/broker import rather than
  /// being typed by the user (brief §17, §31).
  final String? importSource;

  /// Bumped on every edit; analytics recompute keys off this.
  final int revision;

  Trade({
    required this.id,
    required this.userId,
    required this.accountId,
    required this.symbol,
    required this.assetClass,
    required this.direction,
    required this.status,
    required this.openedAtUtc,
    required this.tradingDayKey,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    this.strategyId,
    this.closedAtUtc,
    this.session = MarketSession.midday,
    this.plannedEntryPrice,
    this.stopLossPrice,
    this.targetPrice,
    required this.multiplier,
    this.plannedQuantity,
    this.accountEquityAtOpen,
    this.executions = const [],
    this.entryReason,
    this.exitReason,
    this.managementNotes,
    this.emotionBefore = EmotionTag.neutral,
    this.emotionDuring,
    this.emotionAfter,
    this.confidence,
    this.mistake = MistakeCategory.none,
    this.tags = const [],
    this.attachmentIds = const [],
    this.completedChecklistItemIds = const [],
    this.presentedChecklistItemIds = const [],
    this.wouldRepeat,
    this.isImpulsive = false,
    this.importSource,
    this.revision = 1,
  });

  Iterable<TradeExecution> get entries =>
      executions.where((e) => e.kind == ExecutionKind.entry);

  Iterable<TradeExecution> get exits =>
      executions.where((e) => e.kind == ExecutionKind.exit);

  bool get hasStop => stopLossPrice != null;
  bool get hasTarget => targetPrice != null;
  bool get isClosed => status == TradeStatus.closed;

  /// A trade counts toward daily limits once it has been entered. Planned and
  /// cancelled trades deliberately do not — declining a setup is discipline,
  /// not activity (brief §37).
  bool get countsAsTaken =>
      status == TradeStatus.open || status == TradeStatus.closed;

  /// Whether the reflection on this trade is recorded.
  ///
  /// Three things, chosen because each is a different question and none can be
  /// answered from the numbers: why it was taken, why it was left, and whether
  /// it would be taken again. Prices and P&L say what happened; only these say
  /// anything about the decision, which is the part a journal exists to hold.
  bool get isReviewed =>
      (entryReason?.trim().isNotEmpty ?? false) &&
      (exitReason?.trim().isNotEmpty ?? false) &&
      wouldRepeat != null;

  /// How far through the method this entry has been taken.
  ///
  /// Derived, never stored: a stored copy is a second source of truth that
  /// goes stale the moment someone edits the trade it describes.
  TradeStage get stage => switch (status) {
        TradeStatus.cancelled => TradeStage.cancelled,
        TradeStatus.planned => TradeStage.planned,
        TradeStatus.open => TradeStage.entered,
        TradeStatus.closed =>
          isReviewed ? TradeStage.executed : TradeStage.exited,
      };

  /// Fraction of the presented checklist the user actually ticked.
  /// `null` when no checklist was presented, so the scorer can mark the rule
  /// not-applicable instead of penalising a user who has none configured.
  Dec? get checklistCompletionRatio {
    if (presentedChecklistItemIds.isEmpty) return null;
    final presented = presentedChecklistItemIds.toSet();
    final completed =
        completedChecklistItemIds.where(presented.contains).toSet().length;
    return Dec.fromInt(completed)
        .divide(Dec.fromInt(presented.length), scale: 4);
  }

  bool get hasNotes =>
      (entryReason != null && entryReason!.trim().isNotEmpty) ||
      (managementNotes != null && managementNotes!.trim().isNotEmpty);

  bool get hasAttachment => attachmentIds.isNotEmpty;

  Trade copyWith({
    String? id,
    String? userId,
    String? accountId,
    String? symbol,
    AssetClass? assetClass,
    TradeDirection? direction,
    Object? strategyId = _sentinel,
    TradeStatus? status,
    DateTime? openedAtUtc,
    Object? closedAtUtc = _sentinel,
    String? tradingDayKey,
    MarketSession? session,
    Object? plannedEntryPrice = _sentinel,
    Object? stopLossPrice = _sentinel,
    Object? targetPrice = _sentinel,
    Dec? multiplier,
    Object? plannedQuantity = _sentinel,
    Object? accountEquityAtOpen = _sentinel,
    List<TradeExecution>? executions,
    Object? entryReason = _sentinel,
    Object? exitReason = _sentinel,
    Object? managementNotes = _sentinel,
    EmotionTag? emotionBefore,
    Object? emotionDuring = _sentinel,
    Object? emotionAfter = _sentinel,
    Object? confidence = _sentinel,
    MistakeCategory? mistake,
    List<String>? tags,
    List<String>? attachmentIds,
    List<String>? completedChecklistItemIds,
    List<String>? presentedChecklistItemIds,
    Object? wouldRepeat = _sentinel,
    bool? isImpulsive,
    DateTime? createdAtUtc,
    DateTime? updatedAtUtc,
    Object? importSource = _sentinel,
    int? revision,
  }) =>
      Trade(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        accountId: accountId ?? this.accountId,
        symbol: symbol ?? this.symbol,
        assetClass: assetClass ?? this.assetClass,
        direction: direction ?? this.direction,
        strategyId: _pick(strategyId, this.strategyId),
        status: status ?? this.status,
        openedAtUtc: openedAtUtc ?? this.openedAtUtc,
        closedAtUtc: _pick(closedAtUtc, this.closedAtUtc),
        tradingDayKey: tradingDayKey ?? this.tradingDayKey,
        session: session ?? this.session,
        plannedEntryPrice: _pick(plannedEntryPrice, this.plannedEntryPrice),
        stopLossPrice: _pick(stopLossPrice, this.stopLossPrice),
        targetPrice: _pick(targetPrice, this.targetPrice),
        multiplier: multiplier ?? this.multiplier,
        plannedQuantity: _pick(plannedQuantity, this.plannedQuantity),
        accountEquityAtOpen:
            _pick(accountEquityAtOpen, this.accountEquityAtOpen),
        executions: executions ?? this.executions,
        entryReason: _pick(entryReason, this.entryReason),
        exitReason: _pick(exitReason, this.exitReason),
        managementNotes: _pick(managementNotes, this.managementNotes),
        emotionBefore: emotionBefore ?? this.emotionBefore,
        emotionDuring: _pick(emotionDuring, this.emotionDuring),
        emotionAfter: _pick(emotionAfter, this.emotionAfter),
        confidence: _pick(confidence, this.confidence),
        mistake: mistake ?? this.mistake,
        tags: tags ?? this.tags,
        attachmentIds: attachmentIds ?? this.attachmentIds,
        completedChecklistItemIds:
            completedChecklistItemIds ?? this.completedChecklistItemIds,
        presentedChecklistItemIds:
            presentedChecklistItemIds ?? this.presentedChecklistItemIds,
        wouldRepeat: _pick(wouldRepeat, this.wouldRepeat),
        isImpulsive: isImpulsive ?? this.isImpulsive,
        createdAtUtc: createdAtUtc ?? this.createdAtUtc,
        updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
        importSource: _pick(importSource, this.importSource),
        revision: revision ?? this.revision,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'accountId': accountId,
        'symbol': symbol,
        'assetClass': assetClass.wireName,
        'direction': direction.wireName,
        'strategyId': strategyId,
        'status': status.wireName,
        'openedAtUtc': openedAtUtc.toUtc().toIso8601String(),
        'closedAtUtc': closedAtUtc?.toUtc().toIso8601String(),
        'tradingDayKey': tradingDayKey,
        'session': session.wireName,
        'plannedEntryPrice': plannedEntryPrice?.toString(),
        'stopLossPrice': stopLossPrice?.toString(),
        'targetPrice': targetPrice?.toString(),
        'multiplier': multiplier.toString(),
        'plannedQuantity': plannedQuantity?.toString(),
        'accountEquityAtOpen': accountEquityAtOpen?.toString(),
        'executions': executions.map((e) => e.toMap()).toList(),
        'entryReason': entryReason,
        'exitReason': exitReason,
        'managementNotes': managementNotes,
        'emotionBefore': emotionBefore.wireName,
        'emotionDuring': emotionDuring?.wireName,
        'emotionAfter': emotionAfter?.wireName,
        'confidence': confidence,
        'mistake': mistake.wireName,
        'tags': tags,
        'attachmentIds': attachmentIds,
        'completedChecklistItemIds': completedChecklistItemIds,
        'presentedChecklistItemIds': presentedChecklistItemIds,
        'wouldRepeat': wouldRepeat,
        'isImpulsive': isImpulsive,
        'createdAtUtc': createdAtUtc.toUtc().toIso8601String(),
        'updatedAtUtc': updatedAtUtc.toUtc().toIso8601String(),
        'importSource': importSource,
        'revision': revision,
      };

  factory Trade.fromMap(Map<String, dynamic> map) {
    final epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    return Trade(
      id: map['id'] as String? ?? '',
      userId: map['userId'] as String? ?? '',
      accountId: map['accountId'] as String? ?? '',
      symbol: map['symbol'] as String? ?? '',
      assetClass: AssetClass.fromWire(map['assetClass'] as String?),
      direction: TradeDirection.fromWire(map['direction'] as String?),
      strategyId: map['strategyId'] as String?,
      status: TradeStatus.fromWire(map['status'] as String?),
      openedAtUtc: DateTime.tryParse('${map['openedAtUtc']}')?.toUtc() ?? epoch,
      closedAtUtc: DateTime.tryParse('${map['closedAtUtc']}')?.toUtc(),
      tradingDayKey: map['tradingDayKey'] as String? ?? '',
      session: MarketSession.fromWire(map['session'] as String?),
      plannedEntryPrice: _decOrNull(map['plannedEntryPrice']),
      stopLossPrice: _decOrNull(map['stopLossPrice']),
      targetPrice: _decOrNull(map['targetPrice']),
      multiplier: _decOrNull(map['multiplier']) ?? Dec.one,
      plannedQuantity: _decOrNull(map['plannedQuantity']),
      accountEquityAtOpen: _decOrNull(map['accountEquityAtOpen']),
      executions: ((map['executions'] as List?) ?? const [])
          .whereType<Map<Object?, Object?>>()
          .map((e) => TradeExecution.fromMap(e.cast<String, dynamic>()))
          .toList(growable: false),
      entryReason: map['entryReason'] as String?,
      exitReason: map['exitReason'] as String?,
      managementNotes: map['managementNotes'] as String?,
      emotionBefore: EmotionTag.fromWire(map['emotionBefore'] as String?),
      emotionDuring: map['emotionDuring'] == null
          ? null
          : EmotionTag.fromWire(map['emotionDuring'] as String?),
      emotionAfter: map['emotionAfter'] == null
          ? null
          : EmotionTag.fromWire(map['emotionAfter'] as String?),
      confidence: (map['confidence'] as num?)?.toInt(),
      mistake: MistakeCategory.fromWire(map['mistake'] as String?),
      tags: ((map['tags'] as List?) ?? const []).cast<String>(),
      attachmentIds:
          ((map['attachmentIds'] as List?) ?? const []).cast<String>(),
      completedChecklistItemIds:
          ((map['completedChecklistItemIds'] as List?) ?? const [])
              .cast<String>(),
      presentedChecklistItemIds:
          ((map['presentedChecklistItemIds'] as List?) ?? const [])
              .cast<String>(),
      wouldRepeat: map['wouldRepeat'] as bool?,
      isImpulsive: map['isImpulsive'] as bool? ?? false,
      createdAtUtc:
          DateTime.tryParse('${map['createdAtUtc']}')?.toUtc() ?? epoch,
      updatedAtUtc:
          DateTime.tryParse('${map['updatedAtUtc']}')?.toUtc() ?? epoch,
      importSource: map['importSource'] as String?,
      revision: (map['revision'] as num?)?.toInt() ?? 1,
    );
  }

  static Dec? _decOrNull(Object? value) {
    if (value == null) return null;
    return Dec.tryParse('$value');
  }
}

const Object _sentinel = Object();

/// Distinguishes "not passed" from "explicitly set to null" in `copyWith`.
T? _pick<T>(Object? provided, T? current) =>
    identical(provided, _sentinel) ? current : provided as T?;

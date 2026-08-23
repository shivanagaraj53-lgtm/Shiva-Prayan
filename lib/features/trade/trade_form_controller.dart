import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prayan_core/prayan_core.dart';

import '../../state/providers.dart';

/// The editable state of the trade form.
///
/// Numbers are held as the raw strings the user typed and only parsed when
/// they form a valid decimal. Storing them as `double` would round `0.0075`
/// the moment it was keyed, and storing them as [Dec] would make a half-typed
/// "1." unrepresentable.
class TradeFormState {
  final String? tradeId;
  final String symbol;
  final AssetClass assetClass;
  final TradeDirection direction;
  final String? strategyId;
  final MarketSession session;
  final TradeStatus status;

  /// Set when the user is recording a plan they have not acted on.
  ///
  /// The only part of status left to a choice, because it is the only part
  /// that cannot be inferred: an empty entry price is equally "a plan" and
  /// "not filled in yet".
  final bool isPlanOnly;

  final String entryPrice;
  final String stopLoss;
  final String target;
  final String exitPrice;
  final String quantity;
  final String fees;
  final String multiplier;

  final String entryReason;
  final String exitReason;
  final String managementNotes;

  final EmotionTag emotionBefore;
  final EmotionTag? emotionAfter;
  final int? confidence;
  final MistakeCategory mistake;
  final List<String> tags;
  final List<String> attachmentIds;
  final Set<String> completedChecklistIds;
  final bool? wouldRepeat;
  final bool isImpulsive;

  final DateTime openedAtUtc;
  final DateTime? closedAtUtc;

  /// True once the user has touched the form, so validation errors are not
  /// shown against a pristine form.
  final bool isDirty;

  const TradeFormState({
    required this.openedAtUtc,
    this.tradeId,
    this.symbol = '',
    this.assetClass = AssetClass.equity,
    this.direction = TradeDirection.long,
    this.strategyId,
    this.session = MarketSession.open,
    this.status = TradeStatus.closed,
    this.isPlanOnly = false,
    this.entryPrice = '',
    this.stopLoss = '',
    this.target = '',
    this.exitPrice = '',
    this.quantity = '',
    this.fees = '',
    this.multiplier = '1',
    this.entryReason = '',
    this.exitReason = '',
    this.managementNotes = '',
    this.emotionBefore = EmotionTag.calm,
    this.emotionAfter,
    this.confidence,
    this.mistake = MistakeCategory.none,
    this.tags = const [],
    this.attachmentIds = const [],
    this.completedChecklistIds = const {},
    this.wouldRepeat,
    this.isImpulsive = false,
    this.closedAtUtc,
    this.isDirty = false,
  });

  TradeFormState copyWith({
    String? symbol,
    AssetClass? assetClass,
    TradeDirection? direction,
    Object? strategyId = _unset,
    MarketSession? session,
    TradeStatus? status,
    bool? isPlanOnly,
    String? entryPrice,
    String? stopLoss,
    String? target,
    String? exitPrice,
    String? quantity,
    String? fees,
    String? multiplier,
    String? entryReason,
    String? exitReason,
    String? managementNotes,
    EmotionTag? emotionBefore,
    Object? emotionAfter = _unset,
    Object? confidence = _unset,
    MistakeCategory? mistake,
    List<String>? tags,
    List<String>? attachmentIds,
    Set<String>? completedChecklistIds,
    Object? wouldRepeat = _unset,
    bool? isImpulsive,
    DateTime? openedAtUtc,
    Object? closedAtUtc = _unset,
    bool? isDirty,
  }) =>
      TradeFormState(
        tradeId: tradeId,
        symbol: symbol ?? this.symbol,
        assetClass: assetClass ?? this.assetClass,
        direction: direction ?? this.direction,
        strategyId: identical(strategyId, _unset)
            ? this.strategyId
            : strategyId as String?,
        session: session ?? this.session,
        status: status ?? this.status,
        isPlanOnly: isPlanOnly ?? this.isPlanOnly,
        entryPrice: entryPrice ?? this.entryPrice,
        stopLoss: stopLoss ?? this.stopLoss,
        target: target ?? this.target,
        exitPrice: exitPrice ?? this.exitPrice,
        quantity: quantity ?? this.quantity,
        fees: fees ?? this.fees,
        multiplier: multiplier ?? this.multiplier,
        entryReason: entryReason ?? this.entryReason,
        exitReason: exitReason ?? this.exitReason,
        managementNotes: managementNotes ?? this.managementNotes,
        emotionBefore: emotionBefore ?? this.emotionBefore,
        emotionAfter: identical(emotionAfter, _unset)
            ? this.emotionAfter
            : emotionAfter as EmotionTag?,
        confidence: identical(confidence, _unset)
            ? this.confidence
            : confidence as int?,
        mistake: mistake ?? this.mistake,
        tags: tags ?? this.tags,
        attachmentIds: attachmentIds ?? this.attachmentIds,
        completedChecklistIds:
            completedChecklistIds ?? this.completedChecklistIds,
        wouldRepeat: identical(wouldRepeat, _unset)
            ? this.wouldRepeat
            : wouldRepeat as bool?,
        isImpulsive: isImpulsive ?? this.isImpulsive,
        openedAtUtc: openedAtUtc ?? this.openedAtUtc,
        closedAtUtc: identical(closedAtUtc, _unset)
            ? this.closedAtUtc
            : closedAtUtc as DateTime?,
        isDirty: isDirty ?? true,
      );

  Dec? get entryDec => Dec.tryParse(entryPrice);
  Dec? get stopDec => Dec.tryParse(stopLoss);
  Dec? get targetDec => Dec.tryParse(target);
  Dec? get exitDec => Dec.tryParse(exitPrice);
  Dec? get quantityDec => Dec.tryParse(quantity);
  Dec get feesDec => Dec.tryParse(fees) ?? Dec.zero;
  Dec get multiplierDec => Dec.tryParse(multiplier) ?? Dec.one;

  /// The minimum needed to save: an instrument, an entry and a size.
  bool get canSave =>
      symbol.trim().isNotEmpty && entryDec != null && quantityDec != null;

  /// The stage this entry has reached, by what is filled in.
  ///
  /// Status used to be a segmented control the user set by hand, which meant
  /// the journal could disagree with itself: a trade marked Closed with no
  /// exit price, or an exit typed under a trade still marked Open. Derived, it
  /// cannot.
  TradeStatus get derivedStatus {
    if (isPlanOnly) return TradeStatus.planned;
    return exitDec != null ? TradeStatus.closed : TradeStatus.open;
  }

  /// How far through the method this entry has been taken, for the header that
  /// shows the three parts. Mirrors `Trade.stage` on what the form knows.
  TradeStage get stage {
    if (isPlanOnly) return TradeStage.planned;
    if (exitDec == null) return TradeStage.entered;
    final reviewed = entryReason.trim().isNotEmpty &&
        exitReason.trim().isNotEmpty &&
        wouldRepeat != null;
    return reviewed ? TradeStage.executed : TradeStage.exited;
  }

  /// Whether this is yet enough of a trade to be measured against the rules.
  ///
  /// A blank form breaks almost every rule there is — no stop, no setup, no
  /// checklist, no reasoning — and saying so before a single character is
  /// typed is not coaching, it is a screen of red that means nothing. An
  /// instrument and an entry price is the point at which the answer starts
  /// depending on what the user actually did.
  bool get isJudgeable => symbol.trim().isNotEmpty && entryDec != null;

  /// Builds the [Trade] this form describes.
  ///
  /// Returns the same object the calculator and rules engine will see, so the
  /// live preview on the form and the saved result can never disagree.
  Trade toTrade({
    required String userId,
    required String accountId,
    required String dayKey,
    required Dec? accountEquity,
    required List<String> presentedChecklistIds,
    required DateTime now,
    int revision = 1,
    String? existingId,
    DateTime? createdAtUtc,
  }) {
    final id = existingId ?? tradeId ?? 'trade_${now.microsecondsSinceEpoch}';
    final entry = entryDec;
    final quantity = quantityDec;

    final executions = <TradeExecution>[
      if (entry != null && quantity != null)
        TradeExecution(
          id: '${id}_entry',
          kind: ExecutionKind.entry,
          price: entry,
          quantity: quantity,
          timestampUtc: openedAtUtc,
          fees: feesDec,
        ),
      if (derivedStatus == TradeStatus.closed &&
          exitDec != null &&
          quantity != null)
        TradeExecution(
          id: '${id}_exit',
          kind: ExecutionKind.exit,
          price: exitDec!,
          quantity: quantity,
          timestampUtc: closedAtUtc ?? now,
        ),
    ];

    return Trade(
      id: id,
      userId: userId,
      accountId: accountId,
      symbol: symbol.trim().toUpperCase(),
      assetClass: assetClass,
      direction: direction,
      strategyId: strategyId,
      status: derivedStatus,
      openedAtUtc: openedAtUtc,
      closedAtUtc:
          derivedStatus == TradeStatus.closed ? (closedAtUtc ?? now) : null,
      tradingDayKey: dayKey,
      session: session,
      plannedEntryPrice: entry,
      stopLossPrice: stopDec,
      targetPrice: targetDec,
      multiplier: multiplierDec,
      plannedQuantity: quantity,
      accountEquityAtOpen: accountEquity,
      executions: executions,
      entryReason: entryReason.trim().isEmpty ? null : entryReason.trim(),
      exitReason: exitReason.trim().isEmpty ? null : exitReason.trim(),
      managementNotes:
          managementNotes.trim().isEmpty ? null : managementNotes.trim(),
      emotionBefore: emotionBefore,
      emotionAfter: emotionAfter,
      confidence: confidence,
      mistake: mistake,
      tags: tags,
      attachmentIds: attachmentIds,
      presentedChecklistItemIds: presentedChecklistIds,
      completedChecklistItemIds: completedChecklistIds.toList(),
      wouldRepeat: wouldRepeat,
      isImpulsive: isImpulsive,
      createdAtUtc: createdAtUtc ?? now,
      updatedAtUtc: now,
      revision: revision,
    );
  }

  /// Rehydrates the form from an existing trade, for editing.
  static TradeFormState fromTrade(Trade trade) {
    final metrics = TradeCalculator.compute(trade);
    return TradeFormState(
      tradeId: trade.id,
      symbol: trade.symbol,
      assetClass: trade.assetClass,
      direction: trade.direction,
      strategyId: trade.strategyId,
      session: trade.session,
      status: trade.status,
      isPlanOnly: trade.status == TradeStatus.planned,
      entryPrice: (trade.plannedEntryPrice ?? metrics.averageEntryPrice)
              ?.normalized
              .toString() ??
          '',
      stopLoss: trade.stopLossPrice?.normalized.toString() ?? '',
      target: trade.targetPrice?.normalized.toString() ?? '',
      exitPrice: metrics.averageExitPrice?.normalized.toString() ?? '',
      quantity: (trade.plannedQuantity ?? metrics.entryQuantity)
          .normalized
          .toString(),
      fees: metrics.fees.isZero ? '' : metrics.fees.normalized.toString(),
      multiplier: trade.multiplier.normalized.toString(),
      entryReason: trade.entryReason ?? '',
      exitReason: trade.exitReason ?? '',
      managementNotes: trade.managementNotes ?? '',
      emotionBefore: trade.emotionBefore,
      emotionAfter: trade.emotionAfter,
      confidence: trade.confidence,
      mistake: trade.mistake,
      tags: trade.tags,
      attachmentIds: trade.attachmentIds,
      completedChecklistIds: trade.completedChecklistItemIds.toSet(),
      wouldRepeat: trade.wouldRepeat,
      isImpulsive: trade.isImpulsive,
      openedAtUtc: trade.openedAtUtc,
      closedAtUtc: trade.closedAtUtc,
    );
  }
}

const Object _unset = Object();

/// Holds the form for one editing session.
class TradeFormController extends StateNotifier<TradeFormState> {
  TradeFormController(DateTime now) : super(TradeFormState(openedAtUtc: now));

  void set(TradeFormState next) => state = next;

  void load(Trade trade) => state = TradeFormState.fromTrade(trade);

  /// Normalises a tag to the form it is stored and compared in.
  ///
  /// Lower-cased, trimmed, internal whitespace collapsed. Without this a
  /// journal accumulates "FOMO", "fomo" and "fomo " as three separate tags
  /// and the filter that was supposed to group them does the opposite — which
  /// is how tagging quietly becomes useless a few hundred trades in.
  ///
  /// Returns null for anything that is not a usable tag.
  static String? normaliseTag(String raw) {
    final tag = raw.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');
    if (tag.isEmpty) return null;
    // Long enough to be a phrase, short enough to stay a label.
    return tag.length > 32 ? tag.substring(0, 32).trim() : tag;
  }

  /// Adds a tag if it is usable and not already present. Returns whether it
  /// changed anything, so the field can keep the text on a rejected entry
  /// rather than silently swallowing it.
  bool addTag(String raw) {
    final tag = normaliseTag(raw);
    if (tag == null || state.tags.contains(tag)) return false;
    state = state.copyWith(tags: [...state.tags, tag]);
    return true;
  }

  void removeTag(String tag) {
    if (!state.tags.contains(tag)) return;
    state = state.copyWith(tags: state.tags.where((t) => t != tag).toList());
  }

  /// Records a stored attachment against this trade.
  ///
  /// The upload happens before this is called; the form only ever holds ids.
  void addAttachment(String id) {
    if (state.attachmentIds.contains(id)) return;
    state = state.copyWith(attachmentIds: [...state.attachmentIds, id]);
  }

  void removeAttachment(String id) {
    if (!state.attachmentIds.contains(id)) return;
    state = state.copyWith(
      attachmentIds: state.attachmentIds.where((a) => a != id).toList(),
    );
  }

  void toggleChecklistItem(String id, bool selected) {
    final next = {...state.completedChecklistIds};
    if (selected) {
      next.add(id);
    } else {
      next.remove(id);
    }
    state = state.copyWith(completedChecklistIds: next);
  }
}

final tradeFormProvider =
    StateNotifierProvider.autoDispose<TradeFormController, TradeFormState>(
  (ref) => TradeFormController(ref.read(nowProvider)()),
);

import '../money/currency.dart';
import '../money/dec.dart';
import '../money/money.dart';
import 'enums.dart';

/// A trading account or portfolio. All money on trades booked to an account is
/// denominated in [currency]; Prayan never converts between accounts.
class TradingAccount {
  final String id;
  final String userId;
  final String name;
  final Currency currency;

  /// Equity at account creation. The denominator for percentage risk rules
  /// unless [useLiveEquityForRisk] is on.
  final Dec startingEquity;

  /// Latest user-confirmed equity. Kept separate from [startingEquity] so
  /// deposits and withdrawals do not distort historical risk percentages.
  final Dec? currentEquity;

  /// When true, percentage risk rules measure against [currentEquity];
  /// otherwise against [startingEquity]. Compounding traders want the former,
  /// fixed-risk traders the latter.
  final bool useLiveEquityForRisk;

  final bool isArchived;
  final bool isDefault;
  final DateTime createdAtUtc;

  const TradingAccount({
    required this.id,
    required this.userId,
    required this.name,
    required this.currency,
    required this.startingEquity,
    required this.createdAtUtc,
    this.currentEquity,
    this.useLiveEquityForRisk = true,
    this.isArchived = false,
    this.isDefault = false,
  });

  /// Equity a percentage-risk rule should measure against right now.
  Dec get riskBaseEquity =>
      useLiveEquityForRisk ? (currentEquity ?? startingEquity) : startingEquity;

  Money money(Dec amount) => Money(amount, currency);

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'name': name,
        'currencyCode': currency.code,
        'startingEquity': startingEquity.toString(),
        'currentEquity': currentEquity?.toString(),
        'useLiveEquityForRisk': useLiveEquityForRisk,
        'isArchived': isArchived,
        'isDefault': isDefault,
        'createdAtUtc': createdAtUtc.toUtc().toIso8601String(),
      };

  factory TradingAccount.fromMap(Map<String, dynamic> map) => TradingAccount(
        id: map['id'] as String? ?? '',
        userId: map['userId'] as String? ?? '',
        name: map['name'] as String? ?? 'Account',
        currency: Currency.fromCode(map['currencyCode'] as String? ?? 'USD'),
        startingEquity:
            Dec.tryParse('${map['startingEquity']}') ?? Dec.zero,
        currentEquity: map['currentEquity'] == null
            ? null
            : Dec.tryParse('${map['currentEquity']}'),
        useLiveEquityForRisk: map['useLiveEquityForRisk'] as bool? ?? true,
        isArchived: map['isArchived'] as bool? ?? false,
        isDefault: map['isDefault'] as bool? ?? false,
        createdAtUtc: DateTime.tryParse('${map['createdAtUtc']}')?.toUtc() ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      );
}

/// A named setup the user trades. "Approved setup" rules reference these.
class Strategy {
  final String id;
  final String userId;
  final String name;
  final String? description;

  /// Only approved strategies satisfy an `approvedStrategyOnly` rule. A
  /// strategy can be kept for historical analytics while being un-approved,
  /// which is how a user retires a setup without losing its record.
  final bool isApproved;

  final bool isArchived;
  final List<AssetClass> assetClasses;

  /// Hex colour for charts and chips, e.g. `#2E7D64`.
  final String? colorHex;

  const Strategy({
    required this.id,
    required this.userId,
    required this.name,
    this.description,
    this.isApproved = true,
    this.isArchived = false,
    this.assetClasses = const [],
    this.colorHex,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'name': name,
        'description': description,
        'isApproved': isApproved,
        'isArchived': isArchived,
        'assetClasses': assetClasses.map((a) => a.wireName).toList(),
        'colorHex': colorHex,
      };

  factory Strategy.fromMap(Map<String, dynamic> map) => Strategy(
        id: map['id'] as String? ?? '',
        userId: map['userId'] as String? ?? '',
        name: map['name'] as String? ?? '',
        description: map['description'] as String?,
        isApproved: map['isApproved'] as bool? ?? true,
        isArchived: map['isArchived'] as bool? ?? false,
        assetClasses: ((map['assetClasses'] as List?) ?? const [])
            .map((e) => AssetClass.fromWire('$e'))
            .toList(growable: false),
        colorHex: map['colorHex'] as String?,
      );
}

/// One line of the pre-trade checklist (brief §8).
class ChecklistItem {
  final String id;
  final String userId;
  final String prompt;

  /// Display order. Users can reorder freely.
  final int position;

  final bool isActive;

  /// Restricts the item to specific strategies; empty means all.
  final List<String> strategyIds;

  const ChecklistItem({
    required this.id,
    required this.userId,
    required this.prompt,
    required this.position,
    this.isActive = true,
    this.strategyIds = const [],
  });

  bool appliesToStrategy(String? strategyId) =>
      isActive && (strategyIds.isEmpty || strategyIds.contains(strategyId));

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'prompt': prompt,
        'position': position,
        'isActive': isActive,
        'strategyIds': strategyIds,
      };

  factory ChecklistItem.fromMap(Map<String, dynamic> map) => ChecklistItem(
        id: map['id'] as String? ?? '',
        userId: map['userId'] as String? ?? '',
        prompt: map['prompt'] as String? ?? '',
        position: (map['position'] as num?)?.toInt() ?? 0,
        isActive: map['isActive'] as bool? ?? true,
        strategyIds:
            ((map['strategyIds'] as List?) ?? const []).cast<String>(),
      );

  /// The default checklist offered at onboarding, taken from brief §8.
  static List<ChecklistItem> defaults(String userId) {
    const prompts = [
      'Is this an approved setup?',
      'Is the market condition suitable?',
      'Is entry within my planned zone?',
      'Is my stop defined before entry?',
      'Is risk within my per-trade maximum?',
      'Does planned R:R meet my minimum?',
      'Am I still under my daily loss limit?',
      'Am I still under my maximum number of trades?',
      'Am I entering for the setup, not FOMO or boredom?',
      'Have I checked for a major scheduled event?',
    ];
    return [
      for (var i = 0; i < prompts.length; i++)
        ChecklistItem(
          id: 'checklist_${i + 1}',
          userId: userId,
          prompt: prompts[i],
          position: i,
        ),
    ];
  }
}

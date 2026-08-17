import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prayan_core/prayan_core.dart';

import '../../domain/models.dart';
import '../../state/providers.dart';
import 'sample_journal.dart';

/// Everything onboarding collects, held in one immutable draft.
///
/// Nothing is written until [OnboardingController.commit]: a user who
/// abandons setup halfway leaves no partial account behind.
class OnboardingDraft {
  final ExperienceLevel experience;
  final List<AssetClass> markets;
  final TradingStyle style;
  final String currencyCode;
  final String timezoneName;

  /// Optional starting equity, as typed. Empty means "not now".
  final String startingEquity;

  final String templateId;

  /// Risk settings, as typed, so a partially entered number is never coerced.
  final String maxRiskPercent;
  final String minRewardRisk;
  final String maxTradesPerDay;
  final String dailyLossR;

  final NotificationPreferences notifications;

  /// Load a worked example so the app is explorable before the first real
  /// trade. Off by default — a journal pre-filled with fictional trades the
  /// user did not take would be dishonest unless they asked for it.
  final bool loadSampleJournal;

  const OnboardingDraft({
    this.experience = ExperienceLevel.developing,
    this.markets = const [AssetClass.equity],
    this.style = TradingStyle.intraday,
    this.currencyCode = 'INR',
    this.timezoneName = 'Asia/Kolkata',
    this.startingEquity = '',
    this.templateId = 'balanced',
    this.maxRiskPercent = '1',
    this.minRewardRisk = '2',
    this.maxTradesPerDay = '3',
    this.dailyLossR = '2',
    this.notifications = const NotificationPreferences(),
    this.loadSampleJournal = false,
  });

  OnboardingDraft copyWith({
    ExperienceLevel? experience,
    List<AssetClass>? markets,
    TradingStyle? style,
    String? currencyCode,
    String? timezoneName,
    String? startingEquity,
    String? templateId,
    String? maxRiskPercent,
    String? minRewardRisk,
    String? maxTradesPerDay,
    String? dailyLossR,
    NotificationPreferences? notifications,
    bool? loadSampleJournal,
  }) =>
      OnboardingDraft(
        experience: experience ?? this.experience,
        markets: markets ?? this.markets,
        style: style ?? this.style,
        currencyCode: currencyCode ?? this.currencyCode,
        timezoneName: timezoneName ?? this.timezoneName,
        startingEquity: startingEquity ?? this.startingEquity,
        templateId: templateId ?? this.templateId,
        maxRiskPercent: maxRiskPercent ?? this.maxRiskPercent,
        minRewardRisk: minRewardRisk ?? this.minRewardRisk,
        maxTradesPerDay: maxTradesPerDay ?? this.maxTradesPerDay,
        dailyLossR: dailyLossR ?? this.dailyLossR,
        notifications: notifications ?? this.notifications,
        loadSampleJournal: loadSampleJournal ?? this.loadSampleJournal,
      );

  Currency get currency => Currency.fromCode(currencyCode);

  RuleTemplate get template =>
      RuleTemplates.byId(templateId) ?? RuleTemplates.balanced;
}

/// Builds and persists the initial account state.
class OnboardingController extends StateNotifier<OnboardingDraft> {
  final Ref _ref;

  OnboardingController(this._ref) : super(const OnboardingDraft());

  void update(OnboardingDraft draft) => state = draft;

  /// Writes the profile, account, strategies, checklist and rules.
  ///
  /// The profile is saved *last*, because `onboardingComplete` is what the
  /// router keys on: setting it before the rules exist would drop the user
  /// onto a dashboard with nothing to score against.
  Future<void> commit() async {
    final userId = _ref.read(currentUserIdProvider);
    if (userId == null) return;

    final now = _ref.read(nowProvider)();
    final draft = state;
    final equity = Dec.tryParse(draft.startingEquity) ?? Dec.zero;

    final account = TradingAccount(
      id: '${userId}_primary',
      userId: userId,
      name: 'Primary account',
      currency: draft.currency,
      startingEquity: equity,
      currentEquity: equity,
      createdAtUtc: now,
      isDefault: true,
    );
    await _ref.read(accountRepositoryProvider).saveAccount(account);

    // Two starter setups, both approved, matching the brief's worked example.
    final strategyRepository = _ref.read(strategyRepositoryProvider);
    for (final (index, name) in const ['Breakout', 'Pullback'].indexed) {
      await strategyRepository.saveStrategy(
        Strategy(
          id: '${userId}_strategy_$index',
          userId: userId,
          name: name,
          description: 'Starter setup — rename or replace it with your own.',
        ),
      );
    }

    final checklistRepository = _ref.read(checklistRepositoryProvider);
    for (final item in ChecklistItem.defaults(userId)) {
      await checklistRepository.saveChecklistItem(
        ChecklistItem(
          id: '${userId}_${item.id}',
          userId: userId,
          prompt: item.prompt,
          position: item.position,
        ),
      );
    }

    // Instantiate the chosen template, then apply the user's own thresholds
    // over it so the numbers they just typed are the ones that take effect.
    final rules = draft.template.instantiate(
      userId: userId,
      now: now,
      idPrefix: '${userId}_rule',
    );
    final ruleRepository = _ref.read(ruleRepositoryProvider);
    for (final rule in rules) {
      await ruleRepository.createRule(_applyOverrides(rule, draft));
    }

    await _ref
        .read(profileRepositoryProvider)
        .saveNotificationPreferences(userId, draft.notifications);

    if (draft.loadSampleJournal) {
      await SampleJournal.install(
        trades: _ref.read(tradeRepositoryProvider),
        strategies: await _ref
            .read(strategyRepositoryProvider)
            .watchStrategies(userId)
            .first,
        config: _ref.read(tradingDayConfigProvider),
        userId: userId,
        account: account,
        now: now,
      );
    }

    final auth = _ref.read(authRepositoryProvider).currentUser;
    await _ref.read(profileRepositoryProvider).saveProfile(
          UserProfile(
            id: userId,
            email: auth?.email,
            displayName: auth?.displayName,
            timezoneName: draft.timezoneName,
            defaultCurrencyCode: draft.currencyCode,
            experience: draft.experience,
            markets: draft.markets,
            style: draft.style,
            onboardingComplete: true,
            createdAtUtc: now,
          ),
        );
  }

  /// Replaces a template rule's threshold with the user's typed value.
  Rule _applyOverrides(Rule rule, OnboardingDraft draft) {
    final override = switch (rule.current.measure) {
      RuleMeasure.maxRiskPercentPerTrade => draft.maxRiskPercent,
      RuleMeasure.minPlannedRewardRisk => draft.minRewardRisk,
      RuleMeasure.maxTradesPerDay => draft.maxTradesPerDay,
      RuleMeasure.maxDailyLossR => draft.dailyLossR,
      _ => null,
    };
    final threshold = override == null ? null : Dec.tryParse(override);
    if (threshold == null) return rule;

    return Rule(
      id: rule.id,
      userId: rule.userId,
      position: rule.position,
      isActive: rule.isActive,
      history: rule.history,
      current: RuleVersion(
        id: rule.current.id,
        ruleId: rule.current.ruleId,
        version: rule.current.version,
        name: rule.current.name,
        description: rule.current.description,
        category: rule.current.category,
        severity: rule.current.severity,
        measure: rule.current.measure,
        threshold: threshold,
        weekdays: rule.current.weekdays,
        sessions: rule.current.sessions,
        strategyIds: rule.current.strategyIds,
        assetClasses: rule.current.assetClasses,
        weight: rule.current.weight,
        effectiveFromUtc: rule.current.effectiveFromUtc,
      ),
    );
  }
}

final onboardingProvider =
    StateNotifierProvider<OnboardingController, OnboardingDraft>(
  OnboardingController.new,
);

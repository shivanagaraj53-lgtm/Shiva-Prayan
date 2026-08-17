import 'package:prayan_core/prayan_core.dart';

import '../design/palette.dart';

/// The signed-in user's profile and trading context.
class UserProfile {
  final String id;
  final String? email;
  final String? displayName;

  /// IANA zone name, e.g. `Asia/Kolkata`. Resolved to a UTC offset at the
  /// moment of bucketing; see [TradingDayConfig].
  final String timezoneName;

  final String defaultCurrencyCode;
  final ExperienceLevel experience;
  final List<AssetClass> markets;
  final TradingStyle style;

  /// Weekdays the user trades, `DateTime.monday`..`DateTime.sunday`.
  final List<int> tradingDays;

  final bool onboardingComplete;
  final DateTime createdAtUtc;

  const UserProfile({
    required this.id,
    required this.timezoneName,
    required this.defaultCurrencyCode,
    required this.createdAtUtc,
    this.email,
    this.displayName,
    this.experience = ExperienceLevel.developing,
    this.markets = const [AssetClass.equity],
    this.style = TradingStyle.intraday,
    this.tradingDays = const [1, 2, 3, 4, 5],
    this.onboardingComplete = false,
  });

  Currency get currency => Currency.fromCode(defaultCurrencyCode);

  UserProfile copyWith({
    String? displayName,
    String? timezoneName,
    String? defaultCurrencyCode,
    ExperienceLevel? experience,
    List<AssetClass>? markets,
    TradingStyle? style,
    List<int>? tradingDays,
    bool? onboardingComplete,
  }) =>
      UserProfile(
        id: id,
        email: email,
        displayName: displayName ?? this.displayName,
        timezoneName: timezoneName ?? this.timezoneName,
        defaultCurrencyCode: defaultCurrencyCode ?? this.defaultCurrencyCode,
        experience: experience ?? this.experience,
        markets: markets ?? this.markets,
        style: style ?? this.style,
        tradingDays: tradingDays ?? this.tradingDays,
        onboardingComplete: onboardingComplete ?? this.onboardingComplete,
        createdAtUtc: createdAtUtc,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'email': email,
        'displayName': displayName,
        'timezoneName': timezoneName,
        'defaultCurrencyCode': defaultCurrencyCode,
        'experience': experience.name,
        'markets': markets.map((m) => m.wireName).toList(),
        'style': style.name,
        'tradingDays': tradingDays,
        'onboardingComplete': onboardingComplete,
        'createdAtUtc': createdAtUtc.toUtc().toIso8601String(),
      };

  factory UserProfile.fromMap(Map<String, dynamic> map) => UserProfile(
        id: map['id'] as String? ?? '',
        email: map['email'] as String?,
        displayName: map['displayName'] as String?,
        timezoneName: map['timezoneName'] as String? ?? 'UTC',
        defaultCurrencyCode: map['defaultCurrencyCode'] as String? ?? 'USD',
        experience: ExperienceLevel.values.firstWhere(
          (e) => e.name == map['experience'],
          orElse: () => ExperienceLevel.developing,
        ),
        markets: ((map['markets'] as List?) ?? const [])
            .map((e) => AssetClass.fromWire('$e'))
            .toList(),
        style: TradingStyle.values.firstWhere(
          (e) => e.name == map['style'],
          orElse: () => TradingStyle.intraday,
        ),
        tradingDays: ((map['tradingDays'] as List?) ?? const [1, 2, 3, 4, 5])
            .map((e) => (e as num).toInt())
            .toList(),
        onboardingComplete: map['onboardingComplete'] as bool? ?? false,
        createdAtUtc: DateTime.tryParse('${map['createdAtUtc']}')?.toUtc() ??
            DateTime.now().toUtc(),
      );
}

enum ExperienceLevel {
  beginner('Beginner', 'Less than a year of active trading'),
  developing('Developing', 'One to three years'),
  experienced('Experienced', 'Three years or more');

  const ExperienceLevel(this.label, this.description);
  final String label;
  final String description;
}

enum TradingStyle {
  scalping('Scalping', 'Minutes per trade'),
  intraday('Intraday', 'Positions closed the same day'),
  swing('Swing', 'Days to weeks'),
  position('Position', 'Weeks to months'),
  investing('Investing', 'Months and longer');

  const TradingStyle(this.label, this.description);
  final String label;
  final String description;
}

/// Appearance and behaviour preferences.
class AppPreferences {
  final PrayanTheme theme;

  /// Follows the OS light/dark setting, overriding [theme]'s brightness by
  /// swapping to that theme's counterpart.
  final bool followSystemBrightness;

  /// Text scale multiplier applied on top of the OS setting.
  final double textScale;

  /// Suppresses non-essential motion beyond the OS setting.
  final bool reduceMotion;

  /// Requires a biometric or device credential to open the app.
  final bool biometricLock;

  /// Shows money figures as blurred until tapped, for journalling in public.
  final bool privacyBlur;

  final ScoringConfig scoring;

  /// Whether a no-trade day extends the clean streak.
  final bool countNoTradeDaysInStreak;

  /// Opt-in to the AI-written coaching narrative. Off means the deterministic
  /// on-device insight engine is used, which is always available.
  final bool aiCoachingEnabled;

  /// Opt-in to product analytics. Defaults to off (§32, data minimisation).
  final bool analyticsConsent;

  const AppPreferences({
    this.theme = PrayanTheme.daylight,
    this.followSystemBrightness = true,
    this.textScale = 1.0,
    this.reduceMotion = false,
    this.biometricLock = false,
    this.privacyBlur = false,
    this.scoring = ScoringConfig.standard,
    this.countNoTradeDaysInStreak = false,
    this.aiCoachingEnabled = false,
    this.analyticsConsent = false,
  });

  AppPreferences copyWith({
    PrayanTheme? theme,
    bool? followSystemBrightness,
    double? textScale,
    bool? reduceMotion,
    bool? biometricLock,
    bool? privacyBlur,
    ScoringConfig? scoring,
    bool? countNoTradeDaysInStreak,
    bool? aiCoachingEnabled,
    bool? analyticsConsent,
  }) =>
      AppPreferences(
        theme: theme ?? this.theme,
        followSystemBrightness:
            followSystemBrightness ?? this.followSystemBrightness,
        textScale: textScale ?? this.textScale,
        reduceMotion: reduceMotion ?? this.reduceMotion,
        biometricLock: biometricLock ?? this.biometricLock,
        privacyBlur: privacyBlur ?? this.privacyBlur,
        scoring: scoring ?? this.scoring,
        countNoTradeDaysInStreak:
            countNoTradeDaysInStreak ?? this.countNoTradeDaysInStreak,
        aiCoachingEnabled: aiCoachingEnabled ?? this.aiCoachingEnabled,
        analyticsConsent: analyticsConsent ?? this.analyticsConsent,
      );

  Map<String, dynamic> toMap() => {
        'theme': theme.wireName,
        'followSystemBrightness': followSystemBrightness,
        'textScale': textScale,
        'reduceMotion': reduceMotion,
        'biometricLock': biometricLock,
        'privacyBlur': privacyBlur,
        'scoring': scoring.toMap(),
        'countNoTradeDaysInStreak': countNoTradeDaysInStreak,
        'aiCoachingEnabled': aiCoachingEnabled,
        'analyticsConsent': analyticsConsent,
      };

  factory AppPreferences.fromMap(Map<String, dynamic> map) => AppPreferences(
        theme: PrayanTheme.fromWire(map['theme'] as String?),
        followSystemBrightness: map['followSystemBrightness'] as bool? ?? true,
        textScale: (map['textScale'] as num?)?.toDouble() ?? 1.0,
        reduceMotion: map['reduceMotion'] as bool? ?? false,
        biometricLock: map['biometricLock'] as bool? ?? false,
        privacyBlur: map['privacyBlur'] as bool? ?? false,
        scoring: ScoringConfig.fromMap(
            ((map['scoring'] as Map?) ?? const {}).cast<String, dynamic>()),
        countNoTradeDaysInStreak:
            map['countNoTradeDaysInStreak'] as bool? ?? false,
        aiCoachingEnabled: map['aiCoachingEnabled'] as bool? ?? false,
        analyticsConsent: map['analyticsConsent'] as bool? ?? false,
      );
}

/// Notification settings (§16).
///
/// Everything defaults to a small, respectful set. Nothing here is designed to
/// pull the user back into the app to trade more — the brief forbids it, and
/// the only reminders that exist are about *finishing* a journal entry or a
/// review.
class NotificationPreferences {
  final bool preMarketPlan;

  /// Minutes past local midnight for the pre-market reminder.
  final int preMarketMinutes;

  final bool journalIncomplete;
  final bool endOfDayReview;
  final int endOfDayMinutes;

  final bool weeklyReview;

  /// Weekday for the weekly review nudge.
  final int weeklyReviewWeekday;

  final bool streakMilestones;
  final bool riskLimitWarnings;
  final bool doneForTodayConfirmation;

  /// No notification is delivered inside this window.
  final int quietHoursStartMinutes;
  final int quietHoursEndMinutes;
  final bool quietHoursEnabled;

  const NotificationPreferences({
    this.preMarketPlan = true,
    this.preMarketMinutes = 8 * 60 + 30,
    this.journalIncomplete = true,
    this.endOfDayReview = true,
    this.endOfDayMinutes = 18 * 60,
    this.weeklyReview = true,
    this.weeklyReviewWeekday = DateTime.saturday,
    this.streakMilestones = true,
    this.riskLimitWarnings = true,
    this.doneForTodayConfirmation = true,
    this.quietHoursEnabled = true,
    this.quietHoursStartMinutes = 21 * 60 + 30,
    this.quietHoursEndMinutes = 7 * 60,
  });

  /// Whether [minutesOfDay] falls inside the quiet window. Handles a window
  /// that wraps past midnight, which the common case does.
  bool isQuiet(int minutesOfDay) {
    if (!quietHoursEnabled) return false;
    if (quietHoursStartMinutes <= quietHoursEndMinutes) {
      return minutesOfDay >= quietHoursStartMinutes &&
          minutesOfDay < quietHoursEndMinutes;
    }
    return minutesOfDay >= quietHoursStartMinutes ||
        minutesOfDay < quietHoursEndMinutes;
  }

  NotificationPreferences copyWith({
    bool? preMarketPlan,
    int? preMarketMinutes,
    bool? journalIncomplete,
    bool? endOfDayReview,
    int? endOfDayMinutes,
    bool? weeklyReview,
    int? weeklyReviewWeekday,
    bool? streakMilestones,
    bool? riskLimitWarnings,
    bool? doneForTodayConfirmation,
    bool? quietHoursEnabled,
    int? quietHoursStartMinutes,
    int? quietHoursEndMinutes,
  }) =>
      NotificationPreferences(
        preMarketPlan: preMarketPlan ?? this.preMarketPlan,
        preMarketMinutes: preMarketMinutes ?? this.preMarketMinutes,
        journalIncomplete: journalIncomplete ?? this.journalIncomplete,
        endOfDayReview: endOfDayReview ?? this.endOfDayReview,
        endOfDayMinutes: endOfDayMinutes ?? this.endOfDayMinutes,
        weeklyReview: weeklyReview ?? this.weeklyReview,
        weeklyReviewWeekday: weeklyReviewWeekday ?? this.weeklyReviewWeekday,
        streakMilestones: streakMilestones ?? this.streakMilestones,
        riskLimitWarnings: riskLimitWarnings ?? this.riskLimitWarnings,
        doneForTodayConfirmation:
            doneForTodayConfirmation ?? this.doneForTodayConfirmation,
        quietHoursEnabled: quietHoursEnabled ?? this.quietHoursEnabled,
        quietHoursStartMinutes:
            quietHoursStartMinutes ?? this.quietHoursStartMinutes,
        quietHoursEndMinutes: quietHoursEndMinutes ?? this.quietHoursEndMinutes,
      );

  Map<String, dynamic> toMap() => {
        'preMarketPlan': preMarketPlan,
        'preMarketMinutes': preMarketMinutes,
        'journalIncomplete': journalIncomplete,
        'endOfDayReview': endOfDayReview,
        'endOfDayMinutes': endOfDayMinutes,
        'weeklyReview': weeklyReview,
        'weeklyReviewWeekday': weeklyReviewWeekday,
        'streakMilestones': streakMilestones,
        'riskLimitWarnings': riskLimitWarnings,
        'doneForTodayConfirmation': doneForTodayConfirmation,
        'quietHoursEnabled': quietHoursEnabled,
        'quietHoursStartMinutes': quietHoursStartMinutes,
        'quietHoursEndMinutes': quietHoursEndMinutes,
      };

  factory NotificationPreferences.fromMap(Map<String, dynamic> map) =>
      NotificationPreferences(
        preMarketPlan: map['preMarketPlan'] as bool? ?? true,
        preMarketMinutes:
            (map['preMarketMinutes'] as num?)?.toInt() ?? 8 * 60 + 30,
        journalIncomplete: map['journalIncomplete'] as bool? ?? true,
        endOfDayReview: map['endOfDayReview'] as bool? ?? true,
        endOfDayMinutes: (map['endOfDayMinutes'] as num?)?.toInt() ?? 18 * 60,
        weeklyReview: map['weeklyReview'] as bool? ?? true,
        weeklyReviewWeekday:
            (map['weeklyReviewWeekday'] as num?)?.toInt() ?? DateTime.saturday,
        streakMilestones: map['streakMilestones'] as bool? ?? true,
        riskLimitWarnings: map['riskLimitWarnings'] as bool? ?? true,
        doneForTodayConfirmation:
            map['doneForTodayConfirmation'] as bool? ?? true,
        quietHoursEnabled: map['quietHoursEnabled'] as bool? ?? true,
        quietHoursStartMinutes:
            (map['quietHoursStartMinutes'] as num?)?.toInt() ?? 21 * 60 + 30,
        quietHoursEndMinutes:
            (map['quietHoursEndMinutes'] as num?)?.toInt() ?? 7 * 60,
      );
}

/// The guided daily review (§14).
class DailyReview {
  final String id;
  final String userId;
  final String dayKey;

  final String? whatWentWell;
  final String? ruleBroken;
  final String? riskAssessment;
  final String? bestTradeId;
  final String? worstProcessDecision;
  final String? oneImprovement;

  /// The user's own end-of-day mood.
  final EmotionTag? closingEmotion;

  /// True once the user submits, which is what `dailyReviewCompleted` reads.
  final bool isComplete;

  final DateTime updatedAtUtc;

  const DailyReview({
    required this.id,
    required this.userId,
    required this.dayKey,
    required this.updatedAtUtc,
    this.whatWentWell,
    this.ruleBroken,
    this.riskAssessment,
    this.bestTradeId,
    this.worstProcessDecision,
    this.oneImprovement,
    this.closingEmotion,
    this.isComplete = false,
  });

  DailyReview copyWith({
    String? whatWentWell,
    String? ruleBroken,
    String? riskAssessment,
    String? bestTradeId,
    String? worstProcessDecision,
    String? oneImprovement,
    EmotionTag? closingEmotion,
    bool? isComplete,
    DateTime? updatedAtUtc,
  }) =>
      DailyReview(
        id: id,
        userId: userId,
        dayKey: dayKey,
        whatWentWell: whatWentWell ?? this.whatWentWell,
        ruleBroken: ruleBroken ?? this.ruleBroken,
        riskAssessment: riskAssessment ?? this.riskAssessment,
        bestTradeId: bestTradeId ?? this.bestTradeId,
        worstProcessDecision: worstProcessDecision ?? this.worstProcessDecision,
        oneImprovement: oneImprovement ?? this.oneImprovement,
        closingEmotion: closingEmotion ?? this.closingEmotion,
        isComplete: isComplete ?? this.isComplete,
        updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'dayKey': dayKey,
        'whatWentWell': whatWentWell,
        'ruleBroken': ruleBroken,
        'riskAssessment': riskAssessment,
        'bestTradeId': bestTradeId,
        'worstProcessDecision': worstProcessDecision,
        'oneImprovement': oneImprovement,
        'closingEmotion': closingEmotion?.wireName,
        'isComplete': isComplete,
        'updatedAtUtc': updatedAtUtc.toUtc().toIso8601String(),
      };

  factory DailyReview.fromMap(Map<String, dynamic> map) => DailyReview(
        id: map['id'] as String? ?? '',
        userId: map['userId'] as String? ?? '',
        dayKey: map['dayKey'] as String? ?? '',
        whatWentWell: map['whatWentWell'] as String?,
        ruleBroken: map['ruleBroken'] as String?,
        riskAssessment: map['riskAssessment'] as String?,
        bestTradeId: map['bestTradeId'] as String?,
        worstProcessDecision: map['worstProcessDecision'] as String?,
        oneImprovement: map['oneImprovement'] as String?,
        closingEmotion: map['closingEmotion'] == null
            ? null
            : EmotionTag.fromWire(map['closingEmotion'] as String?),
        isComplete: map['isComplete'] as bool? ?? false,
        updatedAtUtc: DateTime.tryParse('${map['updatedAtUtc']}')?.toUtc() ??
            DateTime.now().toUtc(),
      );
}

/// A pre- or post-session emotional check-in (§13).
class PsychologyEntry {
  final String id;
  final String userId;
  final String dayKey;
  final EmotionTag emotion;

  /// 1–5 self-rated intensity.
  final int intensity;

  final bool isPreSession;
  final String? note;
  final DateTime recordedAtUtc;

  const PsychologyEntry({
    required this.id,
    required this.userId,
    required this.dayKey,
    required this.emotion,
    required this.recordedAtUtc,
    this.intensity = 3,
    this.isPreSession = true,
    this.note,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'dayKey': dayKey,
        'emotion': emotion.wireName,
        'intensity': intensity,
        'isPreSession': isPreSession,
        'note': note,
        'recordedAtUtc': recordedAtUtc.toUtc().toIso8601String(),
      };

  factory PsychologyEntry.fromMap(Map<String, dynamic> map) => PsychologyEntry(
        id: map['id'] as String? ?? '',
        userId: map['userId'] as String? ?? '',
        dayKey: map['dayKey'] as String? ?? '',
        emotion: EmotionTag.fromWire(map['emotion'] as String?),
        intensity: (map['intensity'] as num?)?.toInt() ?? 3,
        isPreSession: map['isPreSession'] as bool? ?? true,
        note: map['note'] as String?,
        recordedAtUtc: DateTime.tryParse('${map['recordedAtUtc']}')?.toUtc() ??
            DateTime.now().toUtc(),
      );
}

/// A personal warning condition the user defines, e.g. "after 2 losses I tend
/// to revenge trade" (§13). Surfaced as an observation, never as a diagnosis.
class BehaviourWatch {
  final String id;
  final String userId;
  final String description;
  final bool isActive;

  const BehaviourWatch({
    required this.id,
    required this.userId,
    required this.description,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'description': description,
        'isActive': isActive,
      };

  factory BehaviourWatch.fromMap(Map<String, dynamic> map) => BehaviourWatch(
        id: map['id'] as String? ?? '',
        userId: map['userId'] as String? ?? '',
        description: map['description'] as String? ?? '',
        isActive: map['isActive'] as bool? ?? true,
      );
}

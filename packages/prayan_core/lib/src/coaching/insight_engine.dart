import '../money/dec.dart';
import 'coaching_facts.dart';

/// The emotional register of an insight. Drives icon and colour treatment,
/// never a value judgement about the person.
enum InsightTone {
  /// Something the user did well.
  affirming,

  /// Neutral observation or context.
  observation,

  /// A process issue worth attention. Firm about the behaviour, never about
  /// the trader (brief §15: "never shame users").
  caution,

  /// A milestone worth a restrained celebration.
  milestone,
}

/// One coaching line shown on the dashboard or daily review.
class Insight {
  /// Stable identifier so the UI can dedupe and the user can dismiss.
  final String id;
  final InsightTone tone;
  final String title;
  final String body;

  /// Higher sorts first.
  final int priority;

  const Insight({
    required this.id,
    required this.tone,
    required this.title,
    required this.body,
    required this.priority,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'tone': tone.name,
        'title': title,
        'body': body,
        'priority': priority,
      };
}

/// Produces coaching lines from [CoachingFacts] with no AI involved.
///
/// This deterministic layer is what ships in MVP and what the app falls back
/// to whenever the AI narrative service is unavailable, rate-limited or
/// disabled by the user. Because every line is derived from computed facts, it
/// cannot state something the data does not support.
///
/// Editorial rules encoded here, from brief §15 and §32:
///  * never suggest trading more, or trading to recover a loss;
///  * never shame — describe the behaviour, not the person;
///  * a disciplined loss is praised as loudly as a win;
///  * no medical or diagnostic language about emotions.
class InsightEngine {
  const InsightEngine._();

  /// Ranked insights for a day, most important first.
  static List<Insight> forDay(CoachingFacts facts) {
    final insights = <Insight>[];

    // --- Hard stops come first: they are actionable right now. -----------
    if (facts.tradedAfterDailyStop) {
      insights.add(const Insight(
        id: 'traded_after_stop',
        tone: InsightTone.caution,
        title: 'You traded past your daily stop',
        body: 'Your plan says the day is finished once the daily loss limit is '
            'reached. Reaching the limit is not the mistake — continuing after '
            'it is the one worth fixing.',
        priority: 100,
      ));
    } else if (facts.reachedDailyStop) {
      insights.add(const Insight(
        id: 'respected_daily_stop',
        tone: InsightTone.affirming,
        title: 'You stopped when your plan said to stop',
        body: 'You reached your configured daily loss limit and finished for '
            'the day. That is the rule working exactly as intended.',
        priority: 95,
      ));
    }

    // --- The product's central philosophy (§37). --------------------------
    if (facts.isDisciplinedLoss) {
      final rWord = facts.totalR == null
          ? 'You lost money today'
          : 'You lost ${facts.totalR!.abs.roundTo(2).normalized}R today';
      insights.add(Insight(
        id: 'disciplined_loss',
        tone: InsightTone.affirming,
        title: 'A disciplined loss',
        body: '$rWord, and broke none of your rules. Losses inside a followed '
            'process are the cost of doing business, not a failure.',
        priority: 90,
      ));
    }

    if (facts.isUndisciplinedWin) {
      insights.add(Insight(
        id: 'undisciplined_win',
        tone: InsightTone.caution,
        title: 'Profitable, but outside your process',
        body: 'The day finished at ${facts.netPnlFormatted}, but '
            '${_joinNames(facts.majorViolationNames)} '
            '${facts.majorViolationNames.length == 1 ? 'was' : 'were'} broken. '
            'A result that comes from a broken rule is not evidence the rule '
            'is wrong.',
        priority: 88,
      ));
    }

    // --- Score explanation. ----------------------------------------------
    if (facts.hasScore && facts.disciplineScore != null) {
      final score = facts.disciplineScore!;
      if (facts.violatedRuleNames.isEmpty) {
        insights.add(Insight(
          id: 'clean_day',
          tone: InsightTone.affirming,
          title: 'Clean execution',
          body: 'All ${facts.rulesApplicable} applicable '
              '${facts.rulesApplicable == 1 ? 'rule was' : 'rules were'} '
              'followed today. Discipline score $score.',
          priority: 80,
        ));
      } else {
        insights.add(Insight(
          id: 'score_explanation',
          tone: InsightTone.observation,
          title: 'Discipline score $score',
          body: '${facts.rulesFollowed} of ${facts.rulesApplicable} applicable '
              'rules were followed. '
              '${_capitalise(_joinNames(facts.violatedRuleNames))} '
              '${facts.violatedRuleNames.length == 1 ? 'was' : 'were'} broken.',
          priority: 75,
        ));
      }
    }

    // --- Streak milestones, restrained by design (§25). -------------------
    if (facts.currentCleanStreak > 0 &&
        _isMilestone(facts.currentCleanStreak)) {
      insights.add(Insight(
        id: 'streak_milestone_${facts.currentCleanStreak}',
        tone: InsightTone.milestone,
        title: '${facts.currentCleanStreak}-day clean streak',
        body: facts.currentCleanStreak >= facts.bestCleanStreak
            ? 'This is your longest run of days without a major rule break.'
            : 'Your best run is ${facts.bestCleanStreak} days.',
        priority: 70,
      ));
    }

    // --- Long-run patterns. ----------------------------------------------
    final weakest = facts.weakestRuleName;
    final weakestRate = facts.weakestRuleCompliancePercent;
    if (weakest != null && weakestRate != null && weakestRate < Dec.fromInt(80)) {
      insights.add(Insight(
        id: 'weakest_rule',
        tone: InsightTone.observation,
        title: 'Your most repeated violation',
        body: '"$weakest" has been followed on '
            '${weakestRate.roundTo(0)}% of the occasions it applied. One rule '
            'at a time is usually enough to work on.',
        priority: 60,
      ));
    }

    final strongest = facts.strongestRuleName;
    if (strongest != null) {
      insights.add(Insight(
        id: 'strongest_rule',
        tone: InsightTone.affirming,
        title: 'Your strongest habit',
        body: '"$strongest" is the rule you follow most reliably.',
        priority: 40,
      ));
    }

    final rolling = facts.rolling30DayScore;
    if (rolling != null) {
      insights.add(Insight(
        id: 'rolling_score',
        tone: InsightTone.observation,
        title: '30-day discipline ${rolling.roundTo(0)}',
        body: 'Your rolling 30-day average discipline score is '
            '${rolling.roundTo(1).normalized}. Process trends move slowly; '
            'that is normal.',
        priority: 30,
      ));
    }

    // --- Emotional context, phrased as observation only (§13). -----------
    final elevated =
        facts.emotionsToday.where((e) => e.isElevatedRisk).toSet().toList();
    if (elevated.isNotEmpty && facts.violatedRuleNames.isNotEmpty) {
      final labels = elevated.map((e) => e.label.toLowerCase()).join(' and ');
      insights.add(Insight(
        id: 'emotion_context',
        tone: InsightTone.observation,
        title: 'Something to notice',
        body: 'You tagged yourself $labels today, and some rules slipped. '
            'That is worth watching over time — one day is not a pattern.',
        priority: 50,
      ));
    }

    // --- No-trade day. ---------------------------------------------------
    if (facts.tradesTaken == 0) {
      insights.add(const Insight(
        id: 'no_trade_day',
        tone: InsightTone.affirming,
        title: 'No trades today',
        body: 'If no valid setup appeared, taking nothing was the correct '
            'decision. A no-trade day costs nothing and breaks no rules.',
        priority: 85,
      ));
    }

    insights.sort((a, b) => b.priority.compareTo(a.priority));
    return List.unmodifiable(insights);
  }

  /// The single line the dashboard shows (brief §6, "a short coaching insight").
  static Insight? headline(CoachingFacts facts) {
    final all = forDay(facts);
    return all.isEmpty ? null : all.first;
  }

  /// Milestones are sparse on purpose — a nudge every day would be a dark
  /// pattern, and the brief explicitly forbids manipulative streak mechanics.
  static bool _isMilestone(int streak) =>
      streak == 3 || streak == 7 || streak == 14 || streak == 30 ||
      streak == 60 || streak == 90 || (streak > 90 && streak % 30 == 0);

  static String _joinNames(List<String> names) {
    if (names.isEmpty) return 'no rules';
    final quoted = names.map((n) => '"$n"').toList();
    if (quoted.length == 1) return quoted.first;
    if (quoted.length == 2) return '${quoted[0]} and ${quoted[1]}';
    return '${quoted.take(quoted.length - 1).join(', ')} and ${quoted.last}';
  }

  static String _capitalise(String value) =>
      value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);
}

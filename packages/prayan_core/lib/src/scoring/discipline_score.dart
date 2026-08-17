import '../models/enums.dart';
import '../models/rule.dart';
import '../money/dec.dart';

/// User-tunable weighting for the discipline score.
///
/// Defaults come from the brief's starting model (§38). Users may re-weight
/// categories in settings; the scorer always normalises over whichever
/// categories actually applied, so changing one weight cannot make a score
/// exceed 100 or silently deflate an unrelated category.
class ScoringConfig {
  /// Percentage points per category, before normalisation.
  final Map<RuleCategory, int> categoryWeights;

  /// Ceiling applied to a day's score once any major rule is broken.
  ///
  /// This is what enforces "a winning trade with broken risk rules is poor
  /// process" (§37): no amount of compliance elsewhere lifts the day above it.
  final int majorViolationCap;

  /// Whether a major violation resets the current clean streak.
  final bool majorViolationResetsStreak;

  const ScoringConfig({
    this.categoryWeights = const {},
    this.majorViolationCap = 60,
    this.majorViolationResetsStreak = true,
  });

  static const ScoringConfig standard = ScoringConfig();

  int weightFor(RuleCategory category) =>
      categoryWeights[category] ?? category.defaultWeight;

  Map<String, dynamic> toMap() => {
        'categoryWeights': {
          for (final entry in categoryWeights.entries)
            entry.key.wireName: entry.value,
        },
        'majorViolationCap': majorViolationCap,
        'majorViolationResetsStreak': majorViolationResetsStreak,
      };

  factory ScoringConfig.fromMap(Map<String, dynamic> map) {
    final raw = (map['categoryWeights'] as Map?)?.cast<String, dynamic>() ?? {};
    return ScoringConfig(
      categoryWeights: {
        for (final entry in raw.entries)
          RuleCategory.fromWire(entry.key): (entry.value as num).toInt(),
      },
      majorViolationCap: (map['majorViolationCap'] as num?)?.toInt() ?? 60,
      majorViolationResetsStreak:
          map['majorViolationResetsStreak'] as bool? ?? true,
    );
  }
}

/// How one rule category contributed to a score.
class ScoreComponent {
  final RuleCategory category;

  /// Configured weight before normalisation.
  final int weight;

  /// Share of the final score this category could contribute, 0–100, after
  /// normalising across the categories that actually applied.
  final Dec normalizedWeight;

  /// Compliance within the category, 0–100.
  final Dec categoryScore;

  /// Points this category contributed to the final score.
  final Dec contribution;

  final int passedCount;
  final int violatedCount;

  final List<RuleEvaluation> violations;

  const ScoreComponent({
    required this.category,
    required this.weight,
    required this.normalizedWeight,
    required this.categoryScore,
    required this.contribution,
    required this.passedCount,
    required this.violatedCount,
    required this.violations,
  });

  int get applicableCount => passedCount + violatedCount;
  bool get isFullyCompliant => violatedCount == 0;
}

/// A fully explainable discipline score (brief §10).
///
/// Every field needed to answer "why is my score 84?" is present, so the UI
/// never has to re-derive anything and the number is never a black box.
class DisciplineScore {
  /// 0–100, rounded to one decimal place.
  final Dec value;

  /// The score before [ScoringConfig.majorViolationCap] was applied. Equal to
  /// [value] when no major rule was broken.
  final Dec uncappedValue;

  final bool wasCappedByMajorViolation;

  final List<ScoreComponent> components;

  /// Rules that applied and were followed.
  final int rulesFollowed;

  /// Rules that applied in total (followed + broken).
  final int rulesApplicable;

  final List<RuleEvaluation> violations;
  final List<RuleEvaluation> majorViolations;

  /// Rules that applied but could not be judged because data was missing.
  /// Surfaced so the user can complete the entry — never counted as a pass.
  final List<RuleEvaluation> unresolved;

  const DisciplineScore({
    required this.value,
    required this.uncappedValue,
    required this.wasCappedByMajorViolation,
    required this.components,
    required this.rulesFollowed,
    required this.rulesApplicable,
    required this.violations,
    required this.majorViolations,
    required this.unresolved,
  });

  /// A day with no applicable rules — a no-trade day, or a brand-new account.
  /// Scored as `null`-like rather than zero: nothing was breached, so nothing
  /// should be penalised (brief §37, "a no-trade day can be excellent").
  bool get hasScore => rulesApplicable > 0;

  bool get isClean => violations.isEmpty && rulesApplicable > 0;

  /// Integer score for compact display.
  int get rounded => int.parse(value.roundTo(0).toString());

  /// The one-line audit sentence the brief asks for by name (§10):
  /// "Your score is 84 because 8/9 applicable rules were followed; minimum
  /// R:R was violated on Trade #3."
  String get summary {
    if (!hasScore) {
      return 'No rules applied today, so there is no score to report.';
    }
    final buffer = StringBuffer(
      'Your score is $rounded because $rulesFollowed/$rulesApplicable '
      'applicable ${rulesApplicable == 1 ? 'rule was' : 'rules were'} followed',
    );
    if (violations.isNotEmpty) {
      final names = violations.map((v) => v.ruleName).toSet().toList();
      final listed = names.take(3).join(', ');
      buffer.write('; $listed ${names.length == 1 ? 'was' : 'were'} broken');
      if (names.length > 3) buffer.write(' and ${names.length - 3} more');
    }
    if (wasCappedByMajorViolation) {
      buffer.write('. A major rule was broken, so the day is capped at '
          '$rounded');
    }
    buffer.write('.');
    return buffer.toString();
  }

  Map<String, dynamic> toMap() => {
        'value': value.toString(),
        'uncappedValue': uncappedValue.toString(),
        'wasCappedByMajorViolation': wasCappedByMajorViolation,
        'rulesFollowed': rulesFollowed,
        'rulesApplicable': rulesApplicable,
        'components': [
          for (final component in components)
            {
              'category': component.category.wireName,
              'weight': component.weight,
              'normalizedWeight': component.normalizedWeight.toString(),
              'categoryScore': component.categoryScore.toString(),
              'contribution': component.contribution.toString(),
              'passedCount': component.passedCount,
              'violatedCount': component.violatedCount,
            },
        ],
        'violations': violations.map((v) => v.toMap()).toList(),
        'unresolved': unresolved.map((v) => v.toMap()).toList(),
      };

  static DisciplineScore get empty => DisciplineScore(
        value: Dec.zero,
        uncappedValue: Dec.zero,
        wasCappedByMajorViolation: false,
        components: const [],
        rulesFollowed: 0,
        rulesApplicable: 0,
        violations: const [],
        majorViolations: const [],
        unresolved: const [],
      );
}

/// Turns rule evaluations into an explainable 0–100 score.
///
/// The scorer is intentionally ignorant of P&L. It receives only rule
/// evaluations, which is the structural guarantee behind the brief's core
/// philosophy: a profitable trade that broke rules cannot outscore a losing
/// trade that followed them (§10, §37).
class DisciplineScorer {
  const DisciplineScorer._();

  static const int _scale = 4;

  /// Scores a set of evaluations.
  static DisciplineScore score(
    List<RuleEvaluation> evaluations, {
    ScoringConfig config = ScoringConfig.standard,
  }) {
    // Informational rules are excluded by design: they are recorded and
    // explained in the audit trail but never move the number.
    final scored = evaluations.where((e) => e.severity.affectsScore);

    final unresolved = <RuleEvaluation>[];
    final byCategory = <RuleCategory, List<RuleEvaluation>>{};

    for (final evaluation in scored) {
      switch (evaluation.status) {
        case RuleStatus.passed:
        case RuleStatus.violated:
          byCategory
              .putIfAbsent(evaluation.category, () => <RuleEvaluation>[])
              .add(evaluation);
        case RuleStatus.indeterminate:
          unresolved.add(evaluation);
        case RuleStatus.notApplicable:
          break;
      }
    }

    if (byCategory.isEmpty) {
      return DisciplineScore(
        value: Dec.zero,
        uncappedValue: Dec.zero,
        wasCappedByMajorViolation: false,
        components: const [],
        rulesFollowed: 0,
        rulesApplicable: 0,
        violations: const [],
        majorViolations: const [],
        unresolved: List.unmodifiable(unresolved),
      );
    }

    // Normalise across only the categories that applied, so a user with no
    // checklist configured is not penalised for the checklist category.
    var totalWeight = 0;
    for (final category in byCategory.keys) {
      totalWeight += config.weightFor(category);
    }
    if (totalWeight <= 0) totalWeight = 1;
    final totalWeightDec = Dec.fromInt(totalWeight);

    final components = <ScoreComponent>[];
    final allViolations = <RuleEvaluation>[];
    var rulesFollowed = 0;
    var rulesApplicable = 0;
    var weightedTotal = Dec.zero;

    // Deterministic ordering keeps the audit trail stable between runs.
    final categories = byCategory.keys.toList()
      ..sort((a, b) => a.index.compareTo(b.index));

    for (final category in categories) {
      final items = byCategory[category]!;
      var passedWeight = Dec.zero;
      var appliedWeight = Dec.zero;
      var passedCount = 0;
      var violatedCount = 0;
      final violations = <RuleEvaluation>[];

      for (final item in items) {
        // Rule weight is clamped to at least 1 so a misconfigured zero-weight
        // rule cannot silently vanish from the denominator.
        final itemWeight = Dec.fromInt(item.weight < 1 ? 1 : item.weight);
        appliedWeight += itemWeight;
        if (item.status == RuleStatus.passed) {
          passedWeight += itemWeight;
          passedCount++;
        } else {
          violatedCount++;
          violations.add(item);
          allViolations.add(item);
        }
      }

      rulesFollowed += passedCount;
      rulesApplicable += passedCount + violatedCount;

      final categoryScore = appliedWeight.isZero
          ? Dec.zero
          : (passedWeight * Dec.hundred).divide(appliedWeight, scale: _scale);

      final weight = config.weightFor(category);
      final normalizedWeight = (Dec.fromInt(weight) * Dec.hundred)
          .divide(totalWeightDec, scale: _scale);
      final contribution =
          (categoryScore * normalizedWeight).divide(Dec.hundred, scale: _scale);

      weightedTotal += contribution;

      components.add(ScoreComponent(
        category: category,
        weight: weight,
        normalizedWeight: normalizedWeight,
        categoryScore: categoryScore.roundTo(1),
        contribution: contribution.roundTo(2),
        passedCount: passedCount,
        violatedCount: violatedCount,
        violations: List.unmodifiable(violations),
      ));
    }

    final uncapped = weightedTotal.roundTo(1);
    final majorViolations = allViolations
        .where((v) => v.severity == RuleSeverity.major)
        .toList(growable: false);

    var finalValue = uncapped;
    var wasCapped = false;
    if (majorViolations.isNotEmpty) {
      final cap = Dec.fromInt(config.majorViolationCap);
      if (uncapped > cap) {
        finalValue = cap;
        wasCapped = true;
      }
    }

    // Clamp defensively: a custom weight set should never be able to produce
    // a score outside the documented 0–100 range.
    if (finalValue > Dec.hundred) finalValue = Dec.hundred;
    if (finalValue.isNegative) finalValue = Dec.zero;

    return DisciplineScore(
      value: finalValue,
      uncappedValue: uncapped,
      wasCappedByMajorViolation: wasCapped,
      components: List.unmodifiable(components),
      rulesFollowed: rulesFollowed,
      rulesApplicable: rulesApplicable,
      violations: List.unmodifiable(allViolations),
      majorViolations: List.unmodifiable(majorViolations),
      unresolved: List.unmodifiable(unresolved),
    );
  }
}

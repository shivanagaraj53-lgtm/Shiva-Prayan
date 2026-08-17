import 'package:flutter/material.dart';
import 'package:prayan_core/prayan_core.dart';

import '../palette.dart';
import '../tokens.dart';

/// Visual treatment for a rule outcome.
///
/// Status is carried by an icon, a shape and a word — never by colour alone
/// (§11: "use accessible visual treatment rather than colour alone").
class RuleStatusStyle {
  final IconData icon;
  final Color color;
  final Color background;
  final String label;

  const RuleStatusStyle({
    required this.icon,
    required this.color,
    required this.background,
    required this.label,
  });

  static RuleStatusStyle of(
    BuildContext context,
    RuleStatus status,
    RuleSeverity severity,
  ) {
    final colors = context.colors;
    return switch (status) {
      RuleStatus.passed => RuleStatusStyle(
          icon: Icons.check_circle_outline_rounded,
          color: colors.compliant,
          background: colors.positiveMuted,
          label: 'Followed',
        ),
      RuleStatus.violated => severity == RuleSeverity.major
          ? RuleStatusStyle(
              icon: Icons.error_outline_rounded,
              color: colors.violation,
              background: colors.violationMuted,
              label: 'Major breach',
            )
          : RuleStatusStyle(
              icon: Icons.warning_amber_rounded,
              color: colors.warning,
              background: colors.warningMuted,
              label: 'Broken',
            ),
      RuleStatus.indeterminate => RuleStatusStyle(
          icon: Icons.help_outline_rounded,
          color: colors.textSecondary,
          background: colors.surfaceSunken,
          label: 'Needs data',
        ),
      RuleStatus.notApplicable => RuleStatusStyle(
          icon: Icons.remove_circle_outline_rounded,
          color: colors.textTertiary,
          background: colors.surfaceSunken,
          label: 'Not applicable',
        ),
    };
  }
}

/// One line of the audit trail: what the rule was, what happened, and why.
class RuleStatusTile extends StatelessWidget {
  final RuleEvaluation evaluation;

  /// Hides not-applicable rules' explanation text to keep long lists calm.
  final bool dense;

  final VoidCallback? onTap;

  const RuleStatusTile({
    super.key,
    required this.evaluation,
    this.dense = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final style =
        RuleStatusStyle.of(context, evaluation.status, evaluation.severity);

    final showDetail = !dense && evaluation.message.isNotEmpty;

    return Semantics(
      label: '${evaluation.ruleName}. ${style.label}. ${evaluation.message}',
      excludeSemantics: true,
      button: onTap != null,
      child: InkWell(
        onTap: onTap,
        borderRadius: Radii.field,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: Spacing.md,
            horizontal: Spacing.xs,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: style.background,
                  borderRadius: BorderRadius.circular(Radii.sm),
                ),
                child: Icon(style.icon, size: Sizes.iconMd, color: style.color),
              ),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            evaluation.ruleName,
                            style: text.titleMedium,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: Spacing.sm),
                        Text(
                          style.label,
                          style: text.labelSmall?.copyWith(color: style.color),
                        ),
                      ],
                    ),
                    if (showDetail) ...[
                      const SizedBox(height: Spacing.xxs),
                      Text(
                        evaluation.message,
                        style: text.bodySmall
                            ?.copyWith(color: colors.textSecondary),
                      ),
                    ],
                    if (!dense &&
                        evaluation.observed != null &&
                        evaluation.threshold != null) ...[
                      const SizedBox(height: Spacing.sm),
                      Wrap(
                        spacing: Spacing.sm,
                        runSpacing: Spacing.xs,
                        children: [
                          _Pill(
                            label: 'Yours',
                            value: evaluation.observed!,
                            color: style.color,
                            background: style.background,
                          ),
                          _Pill(
                            label: 'Limit',
                            value: evaluation.threshold!,
                            color: colors.textSecondary,
                            background: colors.surfaceSunken,
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final Color background;

  const _Pill({
    required this.label,
    required this.value,
    required this.color,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.sm,
        vertical: Spacing.xs,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: Radii.chip,
      ),
      child: Text(
        '$label $value',
        style: text.labelSmall?.copyWith(color: color, letterSpacing: 0.2),
      ),
    );
  }
}

/// A compact severity chip for the rule list and rule builder.
class SeverityChip extends StatelessWidget {
  final RuleSeverity severity;
  const SeverityChip({super.key, required this.severity});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final (color, background) = switch (severity) {
      RuleSeverity.info => (colors.textSecondary, colors.surfaceSunken),
      RuleSeverity.warning => (colors.warning, colors.warningMuted),
      RuleSeverity.major => (colors.violation, colors.violationMuted),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.sm,
        vertical: Spacing.xxs,
      ),
      decoration: BoxDecoration(color: background, borderRadius: Radii.chip),
      child: Text(
        severity.label,
        style: text.labelSmall?.copyWith(color: color),
      ),
    );
  }
}

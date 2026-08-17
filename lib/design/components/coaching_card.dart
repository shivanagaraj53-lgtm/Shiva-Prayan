import 'package:flutter/material.dart';
import 'package:prayan_core/prayan_core.dart';

import '../palette.dart';
import '../tokens.dart';
import 'surfaces.dart';

/// A coaching insight.
///
/// Tone drives only the icon and a hairline accent — never a loud banner. The
/// coaching layer speaks like a calm veteran (§15), and the visual treatment
/// has to match that register or the copy reads as sarcasm.
class CoachingCard extends StatelessWidget {
  final Insight insight;

  /// Shown when the narrative came from the AI service rather than the
  /// on-device deterministic engine, so the user always knows which they are
  /// reading (§15, §32).
  final bool aiGenerated;

  final VoidCallback? onDismiss;

  const CoachingCard({
    super.key,
    required this.insight,
    this.aiGenerated = false,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;

    final (icon, tint) = switch (insight.tone) {
      InsightTone.affirming => (Icons.verified_outlined, colors.compliant),
      InsightTone.observation => (
          Icons.insights_outlined,
          colors.textSecondary
        ),
      InsightTone.caution => (Icons.flag_outlined, colors.warning),
      InsightTone.milestone => (Icons.military_tech_outlined, colors.accent),
    };

    return PrayanCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: Sizes.iconMd, color: tint),
              const SizedBox(width: Spacing.sm),
              Expanded(child: Text(insight.title, style: text.titleMedium)),
              if (onDismiss != null)
                IconButton(
                  onPressed: onDismiss,
                  icon: const Icon(Icons.close_rounded, size: Sizes.iconSm),
                  tooltip: 'Dismiss',
                  visualDensity: VisualDensity.compact,
                  color: colors.textTertiary,
                ),
            ],
          ),
          const SizedBox(height: Spacing.sm),
          Text(
            insight.body,
            style: text.bodyMedium?.copyWith(color: colors.textSecondary),
          ),
          if (aiGenerated) ...[
            const SizedBox(height: Spacing.md),
            Row(
              children: [
                Icon(Icons.auto_awesome_outlined,
                    size: 12, color: colors.textTertiary),
                const SizedBox(width: Spacing.xs),
                Expanded(
                  child: Text(
                    'Written from your own recorded figures. Educational '
                    'journalling, not financial advice.',
                    style: text.labelSmall?.copyWith(
                      color: colors.textTertiary,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// The compact single-line variant used on the dashboard.
class CoachingStrip extends StatelessWidget {
  final Insight insight;
  final VoidCallback? onTap;

  const CoachingStrip({super.key, required this.insight, this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;

    final (icon, tint) = switch (insight.tone) {
      InsightTone.affirming => (Icons.verified_outlined, colors.compliant),
      InsightTone.observation => (
          Icons.insights_outlined,
          colors.textSecondary
        ),
      InsightTone.caution => (Icons.flag_outlined, colors.warning),
      InsightTone.milestone => (Icons.military_tech_outlined, colors.accent),
    };

    return PrayanCard(
      onTap: onTap,
      padding: const EdgeInsets.all(Spacing.md),
      child: Row(
        children: [
          Icon(icon, size: Sizes.iconMd, color: tint),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(insight.title, style: text.titleSmall),
                const SizedBox(height: Spacing.xxs),
                Text(
                  insight.body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall?.copyWith(color: colors.textSecondary),
                ),
              ],
            ),
          ),
          if (onTap != null)
            Icon(Icons.chevron_right_rounded,
                size: Sizes.iconMd, color: colors.textTertiary),
        ],
      ),
    );
  }
}

/// The standing disclaimer, rendered wherever coaching or analytics appear.
class DisclaimerNote extends StatelessWidget {
  final String? text;
  const DisclaimerNote({super.key, this.text});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.md),
      child: Text(
        text ??
            'Prayan is a journalling and reflection tool. Nothing here is '
                'financial advice, and past results do not predict future ones.',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: colors.textTertiary, letterSpacing: 0, height: 1.5),
      ),
    );
  }
}

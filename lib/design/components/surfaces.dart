import 'package:flutter/material.dart';

import '../palette.dart';
import '../tokens.dart';

/// The standard card. One border, one radius, no elevation.
class PrayanCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  /// Draws the card in the accent wash — used sparingly, for the one card on a
  /// screen that carries the primary message.
  final bool emphasised;

  /// Overrides the border colour, e.g. to mark a violated rule.
  final Color? borderColor;

  const PrayanCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Spacing.lg),
    this.onTap,
    this.emphasised = false,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final decoration = BoxDecoration(
      color: emphasised ? colors.accentMuted : colors.surface,
      borderRadius: Radii.card,
      border: Border.all(
        color: borderColor ?? (emphasised ? colors.accent : colors.border),
        width: emphasised || borderColor != null ? 1.2 : 1,
      ),
    );

    final content = Padding(padding: padding, child: child);

    if (onTap == null) {
      return DecoratedBox(decoration: decoration, child: content);
    }
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: decoration,
        child: InkWell(
          onTap: onTap,
          borderRadius: Radii.card,
          child: content,
        ),
      ),
    );
  }
}

/// A titled section separator.
class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;

  /// Optional trailing affordance, e.g. a "See all" text button.
  final Widget? action;

  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: text.headlineSmall),
                if (subtitle != null) ...[
                  const SizedBox(height: Spacing.xxs),
                  Text(
                    subtitle!,
                    style:
                        text.bodySmall?.copyWith(color: colors.textSecondary),
                  ),
                ],
              ],
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}

/// A framed container for a chart, with a title and an optional explanation.
///
/// The explanation is a tooltip rather than always-on copy: the brief asks for
/// metrics explained in plain language (§12) without cluttering the surface.
class ChartContainer extends StatelessWidget {
  final String title;
  final String? explanation;
  final Widget child;
  final double height;
  final Widget? trailing;

  const ChartContainer({
    super.key,
    required this.title,
    required this.child,
    this.explanation,
    this.height = 200,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;

    return PrayanCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(child: Text(title, style: text.titleMedium)),
              if (explanation != null) ...[
                const SizedBox(width: Spacing.xs),
                Tooltip(
                  message: explanation!,
                  triggerMode: TooltipTriggerMode.tap,
                  showDuration: const Duration(seconds: 6),
                  child: Semantics(
                    label: 'What does $title mean?',
                    child: Icon(
                      Icons.info_outline_rounded,
                      size: Sizes.iconSm,
                      color: colors.textTertiary,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: Spacing.lg),
          SizedBox(height: height, child: child),
        ],
      ),
    );
  }
}

/// A labelled key/value row, used through trade detail and review screens.
class DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final Widget? trailing;

  const DetailRow({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: text.bodyMedium?.copyWith(color: colors.textSecondary),
            ),
          ),
          const SizedBox(width: Spacing.md),
          Expanded(
            flex: 5,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: text.bodyMedium?.copyWith(
                color: valueColor ?? colors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: Spacing.sm),
            trailing!,
          ],
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../palette.dart';
import '../tokens.dart';

/// A sliding segmented control.
///
/// Used for the analytics range picker, the long/short toggle and the review
/// period switcher. Implemented rather than borrowed from Cupertino so it
/// carries Prayan's radii and palette on both platforms.
class PrayanSegmentedControl<T> extends StatelessWidget {
  final List<SegmentOption<T>> options;
  final T value;
  final ValueChanged<T> onChanged;

  /// Renders at a smaller height for use inside a card header.
  final bool compact;

  const PrayanSegmentedControl({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final height = compact ? 34.0 : 42.0;

    return Container(
      height: height,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: colors.surfaceSunken,
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: colors.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final selectedIndex =
              options.indexWhere((option) => option.value == value);
          final segmentWidth = constraints.maxWidth / options.length;

          return Stack(
            children: [
              if (selectedIndex >= 0)
                AnimatedPositioned(
                  duration: Motion.duration(context, Motion.quick),
                  curve: Motion.emphasis,
                  left: segmentWidth * selectedIndex,
                  width: segmentWidth,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(Radii.sm),
                      border: Border.all(color: colors.border),
                    ),
                  ),
                ),
              Row(
                children: [
                  for (final option in options)
                    Expanded(
                      child: Semantics(
                        button: true,
                        selected: option.value == value,
                        label: option.semanticLabel ?? option.label,
                        excludeSemantics: true,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(Radii.sm),
                          onTap: () {
                            if (option.value == value) return;
                            HapticFeedback.selectionClick();
                            onChanged(option.value);
                          },
                          child: Center(
                            child: Text(
                              option.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  (compact ? text.labelMedium : text.labelLarge)
                                      ?.copyWith(
                                color: option.value == value
                                    ? colors.textPrimary
                                    : colors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class SegmentOption<T> {
  final T value;
  final String label;
  final String? semanticLabel;

  const SegmentOption({
    required this.value,
    required this.label,
    this.semanticLabel,
  });
}

/// A selectable chip, used for tags, emotions and asset classes.
class PrayanChoiceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;
  final IconData? icon;

  /// Tints the selected state, e.g. amber for an elevated-risk emotion.
  final Color? selectedColor;

  const PrayanChoiceChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
    this.icon,
    this.selectedColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final tint = selectedColor ?? colors.accent;

    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        borderRadius: Radii.chip,
        onTap: () {
          HapticFeedback.selectionClick();
          onSelected(!selected);
        },
        child: AnimatedContainer(
          duration: Motion.duration(context, Motion.instant),
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.md,
            vertical: Spacing.sm,
          ),
          constraints: const BoxConstraints(minHeight: 36),
          decoration: BoxDecoration(
            color: selected ? tint.withValues(alpha: 0.14) : colors.surface,
            borderRadius: Radii.chip,
            border: Border.all(
              color: selected ? tint : colors.border,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon,
                    size: Sizes.iconSm,
                    color: selected ? tint : colors.textSecondary),
                const SizedBox(width: Spacing.xs),
              ],
              // A check mark makes selection legible without colour.
              if (selected) ...[
                Icon(Icons.check_rounded, size: 14, color: tint),
                const SizedBox(width: Spacing.xs),
              ],
              Text(
                label,
                style: text.labelMedium?.copyWith(
                  color: selected ? colors.textPrimary : colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

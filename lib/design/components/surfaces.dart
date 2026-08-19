import 'package:flutter/material.dart';

import '../palette.dart';
import '../tokens.dart';

/// How far off the page a card sits.
enum CardLift {
  /// Resting on the canvas. Almost every card.
  resting,

  /// Lifted. Reserved for the one card on a screen that carries the argument —
  /// the discipline score, a sheet. More than one lifted card per screen and
  /// neither of them leads.
  lifted,

  /// Flat against the canvas: grouped rows, nested content, anywhere a shadow
  /// would stack on top of another one.
  flat,
}

/// The standard card. One radius, one border, and a shadow that says which of
/// them matters.
class PrayanCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  /// Draws the card in the accent wash — used sparingly, for the one card on a
  /// screen that carries the primary message.
  final bool emphasised;

  /// Overrides the border colour, e.g. to mark a violated rule.
  final Color? borderColor;

  /// How far off the page this card sits. See [CardLift].
  final CardLift lift;

  /// Paints the card as a gradient panel instead of a flat surface.
  ///
  /// For the one card on a screen that is the argument — the discipline score.
  /// Everything else stays flat on purpose: a product where every card is a
  /// gradient is a product where none of them mean anything.
  final Gradient? gradient;

  const PrayanCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Spacing.lg),
    this.onTap,
    this.emphasised = false,
    this.borderColor,
    this.lift = CardLift.resting,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final dark = Theme.of(context).brightness == Brightness.dark;

    // On a light ground the shadow does the separating, so the hairline drops
    // to a whisper — running both at full strength is what makes a card look
    // outlined rather than raised. On dark the border is all there is.
    final resting = borderColor ??
        (emphasised
            ? colors.accent
            : dark
                ? colors.border
                : colors.border
                    .withValues(alpha: lift == CardLift.flat ? 1 : 0.6));

    final decoration = BoxDecoration(
      color: gradient != null
          ? null
          : (emphasised ? colors.accentMuted : colors.surface),
      gradient: gradient,
      borderRadius: Radii.card,
      border: Border.all(
        color:
            gradient != null ? Colors.white.withValues(alpha: 0.10) : resting,
        width: emphasised || borderColor != null ? 1.2 : 1,
      ),
      boxShadow: switch (lift) {
        CardLift.flat => const [],
        CardLift.resting => Elevation.card(colors.shadow, dark: dark),
        CardLift.lifted => Elevation.lifted(colors.shadow, dark: dark),
      },
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

/// Fades and lifts its child in, once, on first build.
///
/// The difference between a screen that appears and a screen that arrives.
/// Deliberately small — 12 pixels and a fifth of a second — because the point
/// is that the eye lands on the top of the page and follows it down, not that
/// anyone notices an animation. [index] staggers a list so sections settle in
/// reading order.
///
/// Honours reduced motion by rendering the finished state on the first frame,
/// which is what someone who asked for stillness should get.
class Entrance extends StatefulWidget {
  final Widget child;
  final int index;

  const Entrance({super.key, required this.child, this.index = 0});

  @override
  State<Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<Entrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(
      Duration(milliseconds: 45 * widget.index),
      () {
        if (mounted) _controller.forward();
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      return widget.child;
    }
    final curved = CurvedAnimation(parent: _controller, curve: Motion.enter);
    return AnimatedBuilder(
      animation: curved,
      builder: (context, child) => Opacity(
        opacity: curved.value,
        child: Transform.translate(
          offset: Offset(0, 12 * (1 - curved.value)),
          child: child,
        ),
      ),
      child: widget.child,
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

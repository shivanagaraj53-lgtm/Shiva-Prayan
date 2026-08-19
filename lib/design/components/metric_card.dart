import 'package:flutter/material.dart';

import '../format.dart';
import '../palette.dart';
import '../tokens.dart';
import '../typography.dart';
import 'surfaces.dart';

/// A single headline figure with its label.
///
/// Every metric surface in the app is one of these, which is what keeps the
/// dashboard from becoming "an overpacked dashboard" (§36): the component
/// enforces one number, one label, at most one qualifier.
class MetricCard extends StatelessWidget {
  final String label;
  final String value;

  /// A smaller qualifier under the value, e.g. "of 3 allowed".
  final String? support;

  /// Tints the value. Pass `null` for the default text colour — most metrics
  /// should not be coloured at all.
  final Color? valueColor;

  final IconData? icon;
  final VoidCallback? onTap;

  /// Renders at half height for dense grids.
  final bool compact;

  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    this.support,
    this.valueColor,
    this.icon,
    this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;

    return PrayanCard(
      onTap: onTap,
      padding: EdgeInsets.all(compact ? Spacing.md : Spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: Sizes.iconSm, color: colors.textTertiary),
                const SizedBox(width: Spacing.xs),
              ],
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: PrayanType.metricLabel(colors.textTertiary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? Spacing.xs : Spacing.sm),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: PrayanType.metric(
                valueColor ?? colors.textPrimary,
                size: compact ? 20 : 26,
              ),
            ),
          ),
          if (support != null) ...[
            const SizedBox(height: Spacing.xxs),
            Text(
              support!,
              style: text.bodySmall?.copyWith(color: colors.textSecondary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

/// A metric showing progress toward a configured limit.
///
/// Used for "risk used vs daily limit" and "trades taken vs allowed" (§6).
/// The bar turns amber approaching the limit and red past it — but the numbers
/// are always spelled out, so colour is never the only signal.
class LimitMeter extends StatelessWidget {
  final String label;

  /// How much of the limit has been consumed, 0–1 or beyond when exceeded.
  final double fraction;

  final String usedLabel;
  final String limitLabel;
  final IconData? icon;

  /// Half-width, for meters shown side by side.
  ///
  /// Two of these stacked full-width spent four hundred vertical pixels
  /// saying "0 of 3" and "0R of 2R" — most of a phone screen, above the fold,
  /// to deliver two numbers nobody needed at that size.
  final bool dense;

  /// Announced to a screen reader in place of [label] when the visible label
  /// has been shortened to fit. Keeps the spoken version a full sentence.
  final String? semanticLabel;

  const LimitMeter({
    super.key,
    required this.label,
    required this.fraction,
    required this.usedLabel,
    required this.limitLabel,
    this.icon,
    this.dense = false,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final exceeded = fraction > 1.0;
    final approaching = fraction >= 0.8 && !exceeded;

    final barColor = exceeded
        ? colors.violation
        : (approaching ? colors.warning : colors.accent);

    return PrayanCard(
      borderColor: exceeded ? colors.violation : null,
      padding: dense
          ? const EdgeInsets.symmetric(
              horizontal: Spacing.md, vertical: Spacing.md)
          : const EdgeInsets.all(Spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: Sizes.iconSm, color: colors.textTertiary),
                const SizedBox(width: Spacing.xs),
              ],
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: PrayanType.metricLabel(colors.textTertiary),
                ),
              ),
              if (exceeded)
                Text(
                  'OVER',
                  style: PrayanType.metricLabel(colors.violation),
                ),
            ],
          ),
          const SizedBox(height: Spacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(usedLabel,
                  style: PrayanType.metric(colors.textPrimary,
                      size: dense ? 20 : 22)),
              const SizedBox(width: Spacing.xs),
              Text(
                'of $limitLabel',
                style: text.bodySmall?.copyWith(color: colors.textSecondary),
              ),
            ],
          ),
          SizedBox(height: dense ? Spacing.sm : Spacing.md),
          Semantics(
            label: '${semanticLabel ?? label}: $usedLabel of $limitLabel used'
                '${exceeded ? ', over the limit' : ''}',
            excludeSemantics: true,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(Radii.xs),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: fraction.clamp(0.0, 1.0)),
                duration: Motion.duration(context, Motion.standard),
                curve: Motion.enter,
                builder: (context, value, _) => LinearProgressIndicator(
                  value: value,
                  minHeight: 8,
                  backgroundColor: colors.surfaceSunken,
                  valueColor: AlwaysStoppedAnimation(barColor),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Two limit meters shown side by side.
///
/// The day's guardrails are read together and in one glance. Stacked
/// full-width they cost four hundred vertical pixels to say "0 of 3" and "0R
/// of 2R", which pushed everything that matters below the fold.
///
/// A component rather than three lines inside the dashboard, because the
/// layout has a trap in it: `CrossAxisAlignment.stretch` asks children to fill
/// the row's height, and inside a sliver that height is unbounded. Written
/// inline it threw at runtime and took every section below it off the screen —
/// silently, in a release build. Here it can be pumped in exactly that context
/// by a test.
class LimitMeterPair extends StatelessWidget {
  final List<LimitMeter> meters;
  const LimitMeterPair({super.key, required this.meters});

  @override
  Widget build(BuildContext context) {
    if (meters.isEmpty) return const SizedBox.shrink();
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < meters.length; i++) ...[
            if (i > 0) const SizedBox(width: Spacing.md),
            Expanded(child: meters[i]),
          ],
        ],
      ),
    );
  }
}

/// A win / loss / breakeven tally rendered as a single proportional bar.
class OutcomeSplitBar extends StatelessWidget {
  final int wins;
  final int losses;
  final int breakevens;

  const OutcomeSplitBar({
    super.key,
    required this.wins,
    required this.losses,
    required this.breakevens,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final total = wins + losses + breakevens;

    if (total == 0) {
      return Text(
        'No closed trades yet',
        style: text.bodySmall?.copyWith(color: colors.textTertiary),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: '$wins wins, $losses losses, $breakevens breakeven',
          excludeSemantics: true,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(Radii.xs),
            child: SizedBox(
              height: 8,
              child: Row(
                children: [
                  if (wins > 0)
                    Expanded(
                        flex: wins, child: ColoredBox(color: colors.positive)),
                  if (breakevens > 0)
                    Expanded(
                        flex: breakevens,
                        child: ColoredBox(color: colors.neutral)),
                  if (losses > 0)
                    Expanded(
                        flex: losses,
                        child: ColoredBox(color: colors.negative)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: Spacing.sm),
        Wrap(
          spacing: Spacing.md,
          children: [
            _Legend(color: colors.positive, label: Fmt.count(wins, 'win')),
            _Legend(color: colors.neutral, label: '$breakevens breakeven'),
            _Legend(
                color: colors.negative,
                label: Fmt.count(losses, 'loss', 'losses')),
          ],
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: Spacing.xs),
        Text(label,
            style:
                text.bodySmall?.copyWith(color: context.colors.textSecondary)),
      ],
    );
  }
}

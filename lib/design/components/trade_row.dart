import 'package:flutter/material.dart';
import 'package:prayan_core/prayan_core.dart';

import '../format.dart';
import '../palette.dart';
import '../tokens.dart';
import '../typography.dart';

/// One trade in a list.
///
/// The layout is fixed so a column of these scans vertically: symbol and
/// direction left, R-multiple and money right, process signals underneath.
/// A rule breach is shown as an explicit chip rather than by tinting the row,
/// because tinting would compete with the win/loss colour already in use.
class TradeRow extends StatelessWidget {
  final Trade trade;
  final TradeMetrics metrics;
  final Currency currency;

  /// How many rules this trade broke, if evaluated.
  final int violationCount;
  final bool hasMajorViolation;

  /// Strategy display name, resolved by the caller.
  final String? strategyName;

  final VoidCallback? onTap;

  const TradeRow({
    super.key,
    required this.trade,
    required this.metrics,
    required this.currency,
    this.violationCount = 0,
    this.hasMajorViolation = false,
    this.strategyName,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;

    final signum = metrics.netPnl?.signum ?? 0;
    final resultColor =
        metrics.netPnl == null ? colors.textTertiary : colors.forSign(signum);

    final isOpen = trade.status == TradeStatus.open;
    final isPlanned = trade.status == TradeStatus.planned;

    return Semantics(
      button: onTap != null,
      label: _semanticLabel(context),
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: Radii.card,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.lg,
            vertical: Spacing.md,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DirectionMark(direction: trade.direction, status: trade.status),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            trade.symbol,
                            style: text.titleMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: Spacing.sm),
                        if (isOpen || isPlanned)
                          _StatusChip(
                            label: trade.status.label,
                            color: colors.textSecondary,
                            background: colors.surfaceSunken,
                          ),
                      ],
                    ),
                    const SizedBox(height: Spacing.xxs),
                    Text(
                      [
                        strategyName ?? 'No setup',
                        trade.assetClass.label,
                      ].join(' · '),
                      style:
                          text.bodySmall?.copyWith(color: colors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (violationCount > 0) ...[
                      const SizedBox(height: Spacing.sm),
                      _StatusChip(
                        label: hasMajorViolation
                            ? 'Major rule broken'
                            : '${Fmt.count(violationCount, 'rule')} broken',
                        color: hasMajorViolation
                            ? colors.violation
                            : colors.warning,
                        background: hasMajorViolation
                            ? colors.violationMuted
                            : colors.warningMuted,
                        icon: hasMajorViolation
                            ? Icons.error_outline_rounded
                            : Icons.warning_amber_rounded,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: Spacing.md),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    Fmt.r(metrics.realizedR),
                    style: PrayanType.figure(resultColor, size: 16),
                  ),
                  const SizedBox(height: Spacing.xxs),
                  Text(
                    Fmt.money(metrics.netPnl, currency, showSign: true),
                    style: PrayanType.figure(colors.textSecondary, size: 13),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _semanticLabel(BuildContext context) {
    final parts = <String>[
      '${trade.direction.label} ${trade.symbol}',
      if (strategyName != null) strategyName!,
      trade.status.label,
      if (metrics.realizedR != null) '${Fmt.r(metrics.realizedR)} result',
      if (metrics.netPnl != null)
        Fmt.money(metrics.netPnl, currency, showSign: true),
      if (violationCount > 0)
        hasMajorViolation
            ? 'major rule broken'
            : '$violationCount rules broken',
    ];
    return parts.join(', ');
  }
}

/// The long/short marker. Uses an arrow glyph plus a letter so direction never
/// depends on colour.
class _DirectionMark extends StatelessWidget {
  final TradeDirection direction;
  final TradeStatus status;

  const _DirectionMark({required this.direction, required this.status});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isLong = direction == TradeDirection.long;
    final dimmed =
        status == TradeStatus.planned || status == TradeStatus.cancelled;
    final tint = dimmed ? colors.textTertiary : colors.textSecondary;

    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: colors.surfaceSunken,
        borderRadius: BorderRadius.circular(Radii.sm),
        border: Border.all(color: colors.border),
      ),
      child: Icon(
        isLong ? Icons.north_east_rounded : Icons.south_east_rounded,
        size: Sizes.iconMd,
        color: tint,
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final Color background;
  final IconData? icon;

  const _StatusChip({
    required this.label,
    required this.color,
    required this.background,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.sm,
        vertical: Spacing.xxs,
      ),
      decoration: BoxDecoration(color: background, borderRadius: Radii.chip),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: Spacing.xs),
          ],
          Text(label, style: text.labelSmall?.copyWith(color: color)),
        ],
      ),
    );
  }
}

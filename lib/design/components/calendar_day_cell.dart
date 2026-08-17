import 'package:flutter/material.dart';
import 'package:prayan_core/prayan_core.dart';

import '../palette.dart';
import '../tokens.dart';
import '../typography.dart';

/// What the calendar knows about one day.
class CalendarDayData {
  final String dayKey;
  final int dayOfMonth;

  /// Net result for the day; null when nothing was closed.
  final Dec? netPnl;

  /// Discipline score; null when no rule applied.
  final Dec? disciplineScore;

  final int tradeCount;
  final bool hadMajorViolation;
  final bool isToday;
  final bool isFuture;

  /// A day outside the displayed month, rendered as a spacer.
  final bool isOutsideMonth;

  const CalendarDayData({
    required this.dayKey,
    required this.dayOfMonth,
    this.netPnl,
    this.disciplineScore,
    this.tradeCount = 0,
    this.hadMajorViolation = false,
    this.isToday = false,
    this.isFuture = false,
    this.isOutsideMonth = false,
  });

  bool get hasActivity => tradeCount > 0;

  /// A losing day where no rule was broken — the brief's "good loss" (§11).
  bool get isDisciplinedLoss =>
      hasActivity &&
      (netPnl?.isNegative ?? false) &&
      !hadMajorViolation &&
      (disciplineScore == null || disciplineScore! >= Dec.fromInt(80));
}

/// One cell of the monthly calendar.
///
/// Encodes three independent facts without relying on colour for any of them:
///  * result — a filled/hollow/absent dot;
///  * discipline — a bar under the number;
///  * major violation — a corner notch.
///
/// A user who cannot distinguish the result colours still reads the month
/// correctly, which is the accessibility requirement in §11.
class CalendarDayCell extends StatelessWidget {
  final CalendarDayData data;
  final bool isSelected;
  final VoidCallback? onTap;

  const CalendarDayCell({
    super.key,
    required this.data,
    this.isSelected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    if (data.isOutsideMonth) {
      return const SizedBox.shrink();
    }

    final signum = data.netPnl?.signum ?? 0;
    final resultColor =
        data.hasActivity ? colors.forSign(signum) : colors.neutral;

    final background = isSelected
        ? colors.accentMuted
        : (data.hasActivity ? colors.surface : Colors.transparent);
    final borderColor = isSelected
        ? colors.accent
        : (data.isToday ? colors.borderStrong : colors.border);

    return Semantics(
      button: onTap != null,
      selected: isSelected,
      label: _semanticLabel(),
      excludeSemantics: true,
      child: InkWell(
        onTap: data.isFuture ? null : onTap,
        borderRadius: BorderRadius.circular(Radii.sm),
        child: Opacity(
          opacity: data.isFuture ? 0.35 : 1,
          child: Container(
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(Radii.sm),
              border: Border.all(
                color: data.hasActivity || isSelected || data.isToday
                    ? borderColor
                    : Colors.transparent,
                width: isSelected ? 1.4 : 1,
              ),
            ),
            padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
            child: Stack(
              children: [
                if (data.hadMajorViolation)
                  Positioned(
                    top: 2,
                    right: 2,
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: colors.violation,
                        borderRadius: BorderRadius.circular(1.5),
                      ),
                    ),
                  ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${data.dayOfMonth}',
                      style: PrayanType.figure(
                        data.isToday ? colors.accent : colors.textPrimary,
                        size: 13,
                      ).copyWith(
                        fontWeight:
                            data.isToday ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: Spacing.xxs),
                    _ResultDot(
                      hasActivity: data.hasActivity,
                      signum: signum,
                      color: resultColor,
                    ),
                    const SizedBox(height: Spacing.xxs),
                    _DisciplineTick(score: data.disciplineScore),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _semanticLabel() {
    if (!data.hasActivity) {
      return 'Day ${data.dayOfMonth}, no trades';
    }
    final parts = <String>[
      'Day ${data.dayOfMonth}',
      '${data.tradeCount} ${data.tradeCount == 1 ? 'trade' : 'trades'}',
      if (data.netPnl != null)
        data.netPnl!.isNegative
            ? 'negative day'
            : (data.netPnl!.isZero ? 'flat day' : 'positive day'),
      if (data.disciplineScore != null)
        'discipline ${data.disciplineScore!.roundTo(0)}',
      if (data.hadMajorViolation) 'major rule broken',
      if (data.isDisciplinedLoss) 'loss within the rules',
    ];
    return parts.join(', ');
  }
}

/// Result marker: filled for a gain, hollow for a loss, dash for flat.
class _ResultDot extends StatelessWidget {
  final bool hasActivity;
  final int signum;
  final Color color;

  const _ResultDot({
    required this.hasActivity,
    required this.signum,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (!hasActivity) {
      return const SizedBox(height: 8);
    }
    if (signum == 0) {
      return Container(width: 8, height: 2, color: color);
    }
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: signum > 0 ? color : Colors.transparent,
        border: Border.all(color: color, width: 1.5),
      ),
    );
  }
}

/// A three-segment discipline indicator under the day number.
class _DisciplineTick extends StatelessWidget {
  final Dec? score;
  const _DisciplineTick({required this.score});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    if (score == null) return const SizedBox(height: 3);

    final filled = switch (score!) {
      final s when s >= Dec.fromInt(85) => 3,
      final s when s >= Dec.fromInt(60) => 2,
      final s when s >= Dec.fromInt(30) => 1,
      _ => 0,
    };
    final tint = switch (filled) {
      3 => colors.compliant,
      2 => colors.accent,
      1 => colors.warning,
      _ => colors.violation,
    };

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < 3; i++) ...[
          Container(
            width: 5,
            height: 3,
            decoration: BoxDecoration(
              color: i < filled ? tint : colors.surfaceSunken,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
          if (i < 2) const SizedBox(width: 2),
        ],
      ],
    );
  }
}

/// The weekday header row above the grid.
class CalendarWeekdayHeader extends StatelessWidget {
  /// First day of the week, `DateTime.monday` or `DateTime.sunday`.
  final int firstWeekday;

  const CalendarWeekdayHeader({super.key, this.firstWeekday = DateTime.monday});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      children: [
        for (var i = 0; i < 7; i++)
          Expanded(
            child: Center(
              child: Text(
                _initial((firstWeekday + i - 1) % 7 + 1),
                style: PrayanType.metricLabel(colors.textTertiary),
              ),
            ),
          ),
      ],
    );
  }

  static String _initial(int weekday) => switch (weekday) {
        DateTime.monday => 'M',
        DateTime.tuesday => 'T',
        DateTime.wednesday => 'W',
        DateTime.thursday => 'T',
        DateTime.friday => 'F',
        DateTime.saturday => 'S',
        _ => 'S',
      };
}

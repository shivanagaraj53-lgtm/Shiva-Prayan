import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:prayan_core/prayan_core.dart';

import '../format.dart';
import '../palette.dart';
import '../tokens.dart';
import '../typography.dart';

/// The discipline score, drawn as an arc.
///
/// Two deliberate choices, both from the brief:
///  * the arc animates from the *previous* score, not from zero, so the user
///    reads the change rather than a performance (§25);
///  * the number and a text label are always present, so the ring is never the
///    only carrier of meaning for a colour-blind or low-vision user (§2).
class ScoreRing extends StatelessWidget {
  /// 0–100, or null when no rules applied and there is no score.
  final Dec? score;

  /// The score before this update, used as the animation origin.
  final Dec? previousScore;

  final double size;

  /// Shown under the number, e.g. "Today" or "30-day".
  final String? caption;

  /// Set when a major violation capped the day; changes the arc treatment so
  /// the cap is visible rather than implied.
  final bool wasCapped;

  const ScoreRing({
    super.key,
    required this.score,
    this.previousScore,
    this.size = Sizes.scoreRing,
    this.caption,
    this.wasCapped = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final target = _fraction(score);
    final origin = _fraction(previousScore) ?? target;

    final arcColor = switch (score) {
      null => colors.neutral,
      _ when wasCapped => colors.warning,
      final value when value >= Dec.fromInt(85) => colors.compliant,
      final value when value >= Dec.fromInt(60) => colors.accent,
      final value when value >= Dec.fromInt(40) => colors.warning,
      _ => colors.violation,
    };

    final label = score == null ? 'No score' : Fmt.score(score);

    return Semantics(
      label: score == null
          ? 'Discipline score not available. No rules applied.'
          : 'Discipline score ${Fmt.score(score)} out of 100'
              '${wasCapped ? ', capped by a major rule violation' : ''}',
      excludeSemantics: true,
      child: SizedBox(
        width: size,
        height: size,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: origin ?? 0, end: target ?? 0),
          duration: Motion.duration(context, Motion.deliberate),
          curve: Motion.emphasis,
          builder: (context, value, _) => CustomPaint(
            painter: _RingPainter(
              fraction: value,
              arcColor: arcColor,
              trackColor: colors.surfaceSunken,
              strokeWidth: size * 0.085,
              isIndeterminate: score == null,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: score == null
                        ? PrayanType.figure(colors.textTertiary,
                            size: size * 0.13)
                        : PrayanType.metric(colors.textPrimary,
                            size: size * 0.3),
                  ),
                  if (caption != null) ...[
                    const SizedBox(height: Spacing.xxs),
                    Text(
                      caption!.toUpperCase(),
                      style: PrayanType.metricLabel(colors.textTertiary),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Score as a 0–1 fraction, or null when there is no score.
  static double? _fraction(Dec? score) {
    if (score == null) return null;
    final clamped = score < Dec.zero
        ? Dec.zero
        : (score > Dec.hundred ? Dec.hundred : score);
    return clamped.divide(Dec.hundred, scale: 6).toDouble();
  }
}

class _RingPainter extends CustomPainter {
  final double fraction;
  final Color arcColor;
  final Color trackColor;
  final double strokeWidth;
  final bool isIndeterminate;

  _RingPainter({
    required this.fraction,
    required this.arcColor,
    required this.trackColor,
    required this.strokeWidth,
    required this.isIndeterminate,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;

    // The arc runs from -215° to +35°, a 250° sweep. An open bottom reads as
    // a gauge rather than a pie chart, and leaves room for the caption.
    const startAngle = -215 * math.pi / 180;
    const sweepAngle = 250 * math.pi / 180;

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = trackColor;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      track,
    );

    if (isIndeterminate || fraction <= 0) return;

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = arcColor;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle * fraction.clamp(0.0, 1.0),
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.fraction != fraction ||
      old.arcColor != arcColor ||
      old.trackColor != trackColor ||
      old.isIndeterminate != isIndeterminate;
}

/// A compact horizontal discipline bar, for list rows and the daily review.
class ScoreBar extends StatelessWidget {
  final Dec? score;
  final double height;

  const ScoreBar({super.key, required this.score, this.height = 6});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final fraction = ScoreRing._fraction(score) ?? 0;
    final barColor = switch (score) {
      null => colors.neutral,
      final value when value >= Dec.fromInt(85) => colors.compliant,
      final value when value >= Dec.fromInt(60) => colors.accent,
      final value when value >= Dec.fromInt(40) => colors.warning,
      _ => colors.violation,
    };

    return Semantics(
      label: score == null
          ? 'No discipline score'
          : 'Discipline ${Fmt.score(score)} out of 100',
      excludeSemantics: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(height),
        child: SizedBox(
          height: height,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: fraction),
            duration: Motion.duration(context, Motion.standard),
            curve: Motion.enter,
            builder: (context, value, _) => LinearProgressIndicator(
              value: value,
              minHeight: height,
              backgroundColor: colors.surfaceSunken,
              valueColor: AlwaysStoppedAnimation(barColor),
            ),
          ),
        ),
      ),
    );
  }
}

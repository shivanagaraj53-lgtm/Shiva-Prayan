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

  /// Drawn on a dark ground: the track lifts, the numerals go light.
  ///
  /// The ring is the one element in the product people will recognise it by,
  /// so it has to survive being the centrepiece of a deep panel as well as a
  /// small figure on a white card.
  final bool onDark;

  const ScoreRing({
    super.key,
    required this.score,
    this.previousScore,
    this.size = Sizes.scoreRing,
    this.caption,
    this.wasCapped = false,
    this.onDark = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final target = _fraction(score);
    final origin = _fraction(previousScore) ?? target;

    // The bands run compliant -> amber -> red, and none of them is the brand
    // colour. They used to include the accent, which worked only while the
    // accent happened to be green; with a blue brand a blue band in the middle
    // of that ramp says nothing about how the day went. The middle band is a
    // yellow-green mixed from the two it sits between, so the ramp reads in
    // order whatever the brand becomes next.
    final arcColor = switch (score) {
      null => colors.neutral,
      _ when wasCapped => colors.warning,
      final value when value >= Dec.fromInt(85) => colors.compliant,
      final value when value >= Dec.fromInt(60) =>
        Color.lerp(colors.compliant, colors.warning, 0.45)!,
      final value when value >= Dec.fromInt(40) => colors.warning,
      _ => colors.violation,
    };
    // The arc runs from the band's colour into a lit version of it, so the
    // stroke has a direction and a highlight instead of being one flat band.
    //
    // On a dark panel the band colour has to be lifted at *both* ends. Left as
    // it is, the deep green the arc starts in is darker than the ground it is
    // drawn on, so the first third of the sweep disappears and the ring reads
    // as a soft smudge rather than a gauge with a level.
    //
    // Lifted in HSL rather than blended toward white: mixing white in raises
    // luminance by draining colour, which turned a green band into pale sage.
    // Raising lightness and holding saturation keeps the hue that carries the
    // meaning — a warning band still reads amber, a breach still reads red.
    Color lift(double lightness, double saturation) {
      final hsl = HSLColor.fromColor(arcColor);
      return hsl
          .withLightness((hsl.lightness + lightness).clamp(0.0, 1.0))
          .withSaturation((hsl.saturation + saturation).clamp(0.0, 1.0))
          .toColor();
    }

    final arcBase = onDark ? lift(0.18, 0.10) : arcColor;
    final arcLit =
        onDark ? lift(0.36, 0.06) : Color.lerp(arcColor, Colors.white, 0.32)!;
    final numberColor = onDark ? Colors.white : colors.textPrimary;
    final captionColor =
        onDark ? Colors.white.withValues(alpha: 0.72) : colors.textTertiary;
    final trackColor =
        onDark ? Colors.white.withValues(alpha: 0.16) : colors.surfaceSunken;

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
              arcColor: arcBase,
              arcLit: arcLit,
              trackColor: trackColor,
              strokeWidth: size * 0.085,
              isIndeterminate: score == null,
              glow: onDark,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    // While the arc is sweeping, the number climbs with it —
                    // reading 88 the instant the ring starts moving makes the
                    // sweep look like decoration. The exact label takes over
                    // the moment it settles, so precision is never lost to
                    // the animation.
                    (value - (target ?? 0)).abs() < 0.002
                        ? label
                        : (value * 100).round().toString(),
                    style: score == null
                        ? PrayanType.figure(captionColor, size: size * 0.13)
                        : PrayanType.metric(numberColor, size: size * 0.3),
                  ),
                  if (caption != null) ...[
                    const SizedBox(height: Spacing.xxs),
                    Text(
                      caption!.toUpperCase(),
                      style: PrayanType.metricLabel(captionColor),
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
  final Color arcLit;
  final Color trackColor;
  final double strokeWidth;
  final bool isIndeterminate;

  /// Lays a blurred copy of the arc under itself. Only on dark grounds, where
  /// there is something for light to fall on.
  final bool glow;

  _RingPainter({
    required this.fraction,
    required this.arcColor,
    required this.arcLit,
    required this.trackColor,
    required this.strokeWidth,
    required this.isIndeterminate,
    this.glow = false,
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

    final circle = Rect.fromCircle(center: center, radius: radius);
    final swept = sweepAngle * fraction.clamp(0.0, 1.0);

    // The gradient is swept around the same circle the arc follows, so the
    // highlight travels with the stroke instead of sitting at a fixed corner.
    final shader = SweepGradient(
      startAngle: startAngle,
      endAngle: startAngle + sweepAngle,
      colors: [arcColor, arcLit],
      transform: const GradientRotation(startAngle),
    ).createShader(circle);

    if (glow) {
      canvas.drawArc(
        circle,
        startAngle,
        swept,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          // Kept close to the stroke's own width and lightly blurred. Wider or
          // softer and the halo spills across the empty part of the track,
          // which is the one thing the ring has to keep legible: how far round
          // it has actually gone.
          ..strokeWidth = strokeWidth * 1.15
          ..strokeCap = StrokeCap.round
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, strokeWidth * 0.5)
          ..color = arcLit.withValues(alpha: 0.35),
      );
    }

    canvas.drawArc(
      circle,
      startAngle,
      swept,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..shader = shader,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.fraction != fraction ||
      old.arcColor != arcColor ||
      old.arcLit != arcLit ||
      old.trackColor != trackColor ||
      old.glow != glow ||
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

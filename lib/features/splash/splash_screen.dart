import 'package:flutter/material.dart';

import '../../design/palette.dart';
import '../../design/tokens.dart';

/// Brand reveal shown while the first auth event resolves.
///
/// Deliberately short and non-blocking: the router moves on the instant auth
/// reports, so this is never a fixed-duration delay standing between the user
/// and their journal.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: colors.canvas,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const PrayanMark(size: 96),
            const SizedBox(height: Spacing.xl),
            Text('Prayan', style: text.headlineLarge),
            const SizedBox(height: Spacing.xs),
            Text(
              'Trading Journal',
              style: text.titleSmall?.copyWith(
                color: colors.textSecondary,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: Spacing.xxxl),
            SizedBox(
              width: 120,
              child: LinearProgressIndicator(
                minHeight: 2,
                backgroundColor: colors.surfaceSunken,
                valueColor: AlwaysStoppedAnimation(colors.accent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The Prayan logo mark.
///
/// "Prayan" means journey, so the mark is a rising path: a measured ascent of
/// three steps inside a rounded square, with the last step reaching the top
/// edge. It carries the brief's brand ideas — forward journey, disciplined
/// path, measured progress (§36) — and stays legible at 20pt, which a literal
/// candlestick or arrow would not.
///
/// Drawn rather than imported so it inherits the active theme's accent and
/// needs no raster asset per density bucket.
class PrayanMark extends StatelessWidget {
  final double size;

  /// Overrides the mark colour; defaults to the theme accent.
  final Color? color;

  const PrayanMark({super.key, this.size = 64, this.color});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      label: 'Prayan',
      excludeSemantics: true,
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _MarkPainter(
            mark: color ?? colors.accent,
            plate: colors.accentMuted,
          ),
        ),
      ),
    );
  }
}

class _MarkPainter extends CustomPainter {
  final Color mark;
  final Color plate;

  _MarkPainter({required this.mark, required this.plate});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final radius = size.width * 0.26;

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(radius)),
      Paint()..color = plate,
    );

    final stroke = size.width * 0.085;
    final paint = Paint()
      ..color = mark
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Three rising steps: the disciplined path, not a price chart.
    final left = size.width * 0.24;
    final right = size.width * 0.76;
    final bottom = size.height * 0.72;
    final top = size.height * 0.30;
    final stepWidth = (right - left) / 3;
    final stepHeight = (bottom - top) / 3;

    final path = Path()..moveTo(left, bottom);
    for (var i = 0; i < 3; i++) {
      final x = left + stepWidth * i;
      final y = bottom - stepHeight * i;
      path
        ..lineTo(x + stepWidth, y)
        ..lineTo(x + stepWidth, y - stepHeight);
    }
    canvas.drawPath(path, paint);

    // A single dot marking the start of the journey.
    canvas.drawCircle(
      Offset(left, bottom),
      stroke * 0.85,
      Paint()..color = mark,
    );
  }

  @override
  bool shouldRepaint(_MarkPainter old) =>
      old.mark != mark || old.plate != plate;
}

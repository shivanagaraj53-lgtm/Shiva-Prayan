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
            const PrayanMark(size: 96, animate: true, filled: true),
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

/// The Prayan logo mark: a **P** that draws itself.
///
/// "Prayan" means journey, and the previous mark said so literally — three
/// rising steps. It was honest and it was anonymous: an abstract ascent is
/// what every second finance app uses, and nothing about it said *this*
/// product. A letterform does. The stem rises, the bowl closes, and the whole
/// thing is one continuous stroke that can be drawn on rather than appearing
/// fully formed.
///
/// Geometry lives in [MarkGeometry] because two renderers have to agree on it:
/// this painter, and the plain-Dart rasteriser in
/// `tool/generate_launcher_icons.dart` that produces every launcher icon. A
/// drift between them ships an app whose icon is not its logo, so
/// `test/brand_mark_test.dart` asserts they still match.
///
/// Drawn rather than imported so it inherits the active theme and needs no
/// raster asset per density bucket.
class MarkGeometry {
  const MarkGeometry._();

  /// All values are fractions of the mark's side.
  static const double stroke = 0.115;
  static const double stemX = 0.335;
  static const double stemTop = 0.265;
  static const double stemBottom = 0.755;

  /// Where the bowl rejoins the stem.
  static const double bowlBottom = 0.525;

  /// The x at which the bowl's arc starts and ends; it bulges right from here.
  static const double bowlX = 0.545;

  /// Corner radius of the plate behind the mark.
  static const double plateRadius = 0.26;

  static double get arcRadius => (bowlBottom - stemTop) / 2;

  /// The letter as one continuous path, in a box of [side].
  ///
  /// Ordered stem-first so a partial draw rises before it curves, which is the
  /// way a hand writes the letter.
  static Path path(double side) {
    final p = Path()
      ..moveTo(stemX * side, stemBottom * side)
      ..lineTo(stemX * side, stemTop * side)
      ..lineTo(bowlX * side, stemTop * side)
      ..arcToPoint(
        Offset(bowlX * side, bowlBottom * side),
        radius: Radius.circular(arcRadius * side),
        clockwise: true,
      )
      ..lineTo(stemX * side, bowlBottom * side);
    return p;
  }
}

class PrayanMark extends StatefulWidget {
  final double size;

  /// Overrides the mark colour; defaults to a gradient from the theme accent.
  final Color? color;

  /// Overrides the rounded plate behind the mark; defaults to the theme's
  /// muted accent. The launcher-icon generator passes a transparent plate to
  /// render the adaptive-icon foreground layer on its own.
  final Color? plateColor;

  /// Deep ground, lit letter — the way the launcher icon is drawn.
  ///
  /// The inline mark sits on white cards, where a pale plate is right. The
  /// arrival screens are the app introducing itself, and there it should look
  /// like the thing the user tapped on their home screen.
  final bool filled;

  /// Draws the letter on rather than showing it complete.
  ///
  /// Off by default: a logo that redraws itself every time a screen rebuilds
  /// is a distraction, so only the places that are genuinely an arrival — the
  /// splash, the sign-in screen, the first onboarding page — ask for it.
  final bool animate;

  const PrayanMark({
    super.key,
    this.size = 64,
    this.color,
    this.plateColor,
    this.animate = false,
    this.filled = false,
  });

  @override
  State<PrayanMark> createState() => _PrayanMarkState();
}

class _PrayanMarkState extends State<PrayanMark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1150),
  );

  @override
  void initState() {
    super.initState();
    if (widget.animate) {
      _controller.forward();
    } else {
      _controller.value = 1;
    }
  }

  @override
  void didUpdateWidget(PrayanMark old) {
    super.didUpdateWidget(old);
    if (widget.animate && !old.animate) _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // Reduced motion is not a preference to consult only for page
    // transitions: someone who asked for stillness should get the finished
    // letter, immediately.
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    return Semantics(
      label: 'Prayan',
      excludeSemantics: true,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => CustomPaint(
            painter: PrayanMarkPainter(
              mark: widget.color ??
                  (widget.filled ? colors.accentBright : colors.accent),
              markBright: widget.color ??
                  (widget.filled
                      ? Color.lerp(colors.accentBright, Colors.white, 0.45)!
                      : colors.accentBright),
              plate: widget.plateColor ??
                  (widget.filled ? colors.accentDeep : colors.accentMuted),
              plateLit: widget.plateColor ??
                  (widget.filled
                      ? Color.lerp(colors.accentDeep, colors.accent, 0.35)!
                      : colors.accentMuted),
              progress: still ? 1 : _controller.value,
            ),
          ),
        ),
      ),
    );
  }
}

/// Public so a test can read [progress] and prove the letter is drawn rather
/// than faded in. Nothing outside the mark should construct one.
class PrayanMarkPainter extends CustomPainter {
  final Color mark;
  final Color markBright;
  final Color plate;
  final Color plateLit;

  /// 0 draws nothing, 1 draws the finished letter.
  final double progress;

  PrayanMarkPainter({
    required this.mark,
    required this.markBright,
    required this.plate,
    required this.plateLit,
    this.progress = 1,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect,
        Radius.circular(size.width * MarkGeometry.plateRadius),
      ),
      Paint()
        // Lit from the opposite corner to the letter, so the plate and the
        // stroke read as one object under one light rather than two flat
        // shapes stacked on each other.
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [plateLit, plate],
        ).createShader(rect),
    );

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * MarkGeometry.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      // The gradient runs across the letter rather than down it, so the bowl
      // catches the light and the stem stays grounded.
      ..shader = LinearGradient(
        begin: Alignment.bottomLeft,
        end: Alignment.topRight,
        colors: [mark, markBright],
      ).createShader(rect);

    final path = MarkGeometry.path(size.width);
    if (progress >= 1) {
      canvas.drawPath(path, paint);
      return;
    }

    // One continuous stroke, revealed along its own length — the letter is
    // written, not faded in.
    for (final metric in path.computeMetrics()) {
      canvas.drawPath(
        metric.extractPath(0, metric.length * progress.clamp(0.0, 1.0)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(PrayanMarkPainter old) =>
      old.mark != mark ||
      old.markBright != markBright ||
      old.plate != plate ||
      old.plateLit != plateLit ||
      old.progress != progress;
}

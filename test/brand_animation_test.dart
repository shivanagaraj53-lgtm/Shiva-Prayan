import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prayan_trading_journal/design/palette.dart';
import 'package:prayan_trading_journal/design/theme.dart';
import 'package:prayan_trading_journal/features/splash/splash_screen.dart';

/// The mark is written, not faded in.
///
/// A logo that animates is easy to claim and easy to lose: someone sets
/// `animate: false` by default, or a rebuild resets the controller, and the
/// letter simply appears. Neither shows up in a screenshot taken a moment too
/// late — which is exactly how the first attempt to check this by eye failed.
Widget host(Widget child) => MaterialApp(
      theme: PrayanThemeBuilder.build(PrayanTheme.daylight),
      home: Scaffold(body: Center(child: child)),
    );

double progressOf(WidgetTester tester) {
  final paint = tester.widget<CustomPaint>(
    find.descendant(
      of: find.byType(PrayanMark),
      matching: find.byType(CustomPaint),
    ),
  );
  return (paint.painter! as PrayanMarkPainter).progress;
}

void main() {
  testWidgets('the letter draws on over time', (tester) async {
    await tester.pumpWidget(host(const PrayanMark(size: 96, animate: true)));

    expect(progressOf(tester), 0,
        reason: 'the first frame should show nothing drawn');

    await tester.pump(const Duration(milliseconds: 400));
    final partway = progressOf(tester);
    expect(partway, greaterThan(0));
    expect(partway, lessThan(1), reason: 'it arrived complete, not drawn');

    await tester.pump(const Duration(milliseconds: 400));
    expect(progressOf(tester), greaterThan(partway),
        reason: 'the draw stalled partway through');

    await tester.pump(const Duration(milliseconds: 800));
    expect(progressOf(tester), 1, reason: 'the letter never finished');
  });

  testWidgets('without animate it is simply there', (tester) async {
    // The inline mark appears on screens that rebuild constantly. Redrawing
    // itself every time would be a distraction, not a delight.
    await tester.pumpWidget(host(const PrayanMark(size: 32)));
    expect(progressOf(tester), 1);
  });

  testWidgets('reduced motion gets the finished letter immediately',
      (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: host(const PrayanMark(size: 96, animate: true)),
      ),
    );
    expect(progressOf(tester), 1,
        reason: 'someone who asked for stillness was shown an animation');
  });

  testWidgets('the mark carries its name for a screen reader', (tester) async {
    await tester.pumpWidget(host(const PrayanMark(size: 96)));
    expect(find.bySemanticsLabel('Prayan'), findsOneWidget);
  });
}

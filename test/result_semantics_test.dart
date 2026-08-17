import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prayan_core/prayan_core.dart';
import 'package:prayan_trading_journal/design/components/calendar_day_cell.dart';
import 'package:prayan_trading_journal/design/components/metric_card.dart';
import 'package:prayan_trading_journal/design/format.dart';
import 'package:prayan_trading_journal/design/palette.dart';
import 'package:prayan_trading_journal/design/theme.dart';

/// Proves the non-colour redundancies the palette relies on.
///
/// `theme_contrast_test.dart` deliberately keeps the positive and negative
/// result colours at similar luminance so the product reads as calm rather
/// than as a trading terminal. That choice is only defensible because result
/// meaning is *also* carried by a sign, a shape and a screen-reader label —
/// which is what this file asserts (§11, §36).
Widget wrap(Widget child, {PrayanTheme theme = PrayanTheme.daylight}) =>
    MaterialApp(
      theme: PrayanThemeBuilder.build(theme),
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  group('Money never relies on colour', () {
    test('a signed amount always carries an explicit + or -', () {
      final gain = Money.parse('250', Currency.usd).format(showSign: true);
      final loss = Money.parse('-250', Currency.usd).format(showSign: true);
      expect(gain.startsWith('+'), isTrue);
      expect(loss.startsWith('-'), isTrue);
      // Strip the sign and the two are identical — the sign is the only thing
      // distinguishing them in text, so it must always be present.
      expect(gain.substring(1), loss.substring(1));
    });

    test('Fmt.r signs R-multiples the same way', () {
      expect(Fmt.r(Dec.parse('2')), '+2R');
      expect(Fmt.r(Dec.parse('-1')), '-1R');
      expect(Fmt.r(null), Fmt.emptyValue);
    });

    test('an unknown value renders as a dash, never as zero', () {
      expect(Fmt.money(null, Currency.inr), Fmt.emptyValue);
      expect(Fmt.percent(null), Fmt.emptyValue);
      expect(Fmt.rewardRisk(null), Fmt.emptyValue);
      // The distinction that matters: no stop means R is undefined, and
      // rendering that as "0R" would read as a scratch trade.
      expect(Fmt.r(null), isNot(contains('0')));
    });
  });

  group('Calendar cells encode result without colour', () {
    testWidgets('a positive day is announced as positive', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(wrap(
        SizedBox(
          width: 48,
          height: 56,
          child: CalendarDayCell(
            data: CalendarDayData(
              dayKey: '2026-03-16',
              dayOfMonth: 16,
              netPnl: Dec.parse('1200'),
              disciplineScore: Dec.parse('92'),
              tradeCount: 2,
            ),
          ),
        ),
      ));
      expect(
        find.bySemanticsLabel(RegExp('positive day')),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel(RegExp('discipline 92')), findsOneWidget);
      handle.dispose();
    });

    testWidgets('a negative day is announced as negative', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(wrap(
        SizedBox(
          width: 48,
          height: 56,
          child: CalendarDayCell(
            data: CalendarDayData(
              dayKey: '2026-03-17',
              dayOfMonth: 17,
              netPnl: Dec.parse('-800'),
              disciplineScore: Dec.parse('95'),
              tradeCount: 1,
            ),
          ),
        ),
      ));
      expect(find.bySemanticsLabel(RegExp('negative day')), findsOneWidget);
      handle.dispose();
    });

    testWidgets('a major violation is announced, not just marked',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(wrap(
        SizedBox(
          width: 48,
          height: 56,
          child: CalendarDayCell(
            data: CalendarDayData(
              dayKey: '2026-03-18',
              dayOfMonth: 18,
              netPnl: Dec.parse('400'),
              disciplineScore: Dec.parse('55'),
              tradeCount: 3,
              hadMajorViolation: true,
            ),
          ),
        ),
      ));
      expect(
        find.bySemanticsLabel(RegExp('major rule broken')),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('a day with no trades says so', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(wrap(
        const SizedBox(
          width: 48,
          height: 56,
          child: CalendarDayCell(
            data: CalendarDayData(dayKey: '2026-03-19', dayOfMonth: 19),
          ),
        ),
      ));
      expect(find.bySemanticsLabel(RegExp('no trades')), findsOneWidget);
      handle.dispose();
    });
  });

  group('Outcome split bar carries a text legend', () {
    testWidgets('counts are spelled out beside the bar', (tester) async {
      await tester.pumpWidget(wrap(
        const SizedBox(
          width: 320,
          child: OutcomeSplitBar(wins: 3, losses: 2, breakevens: 1),
        ),
      ));
      // The proportional bar is colour; the legend is the redundancy.
      expect(find.text('3 wins'), findsOneWidget);
      expect(find.text('2 losses'), findsOneWidget);
      expect(find.text('1 breakeven'), findsOneWidget);
    });

    testWidgets('an empty sample says so rather than drawing nothing',
        (tester) async {
      await tester.pumpWidget(wrap(
        const SizedBox(
          width: 320,
          child: OutcomeSplitBar(wins: 0, losses: 0, breakevens: 0),
        ),
      ));
      expect(find.text('No closed trades yet'), findsOneWidget);
    });
  });

  group('Limit meters state the numbers, not just the bar', () {
    testWidgets('an exceeded limit is labelled in text', (tester) async {
      await tester.pumpWidget(wrap(
        const SizedBox(
          width: 320,
          child: LimitMeter(
            label: 'Daily loss limit',
            fraction: 1.4,
            usedLabel: '2.8R',
            limitLabel: '2R',
          ),
        ),
      ));
      expect(find.text('OVER'), findsOneWidget);
      expect(find.text('2.8R'), findsOneWidget);
      expect(find.text('of 2R'), findsOneWidget);
    });
  });

  group('Every theme renders the same widget without error', () {
    for (final theme in PrayanTheme.values) {
      testWidgets('${theme.label} builds a metric card', (tester) async {
        await tester.pumpWidget(wrap(
          const SizedBox(
            width: 200,
            child: MetricCard(
              label: 'Net P&L',
              value: r'+$1,250.00',
              support: '3 trades',
            ),
          ),
          theme: theme,
        ));
        expect(find.text(r'+$1,250.00'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });
}

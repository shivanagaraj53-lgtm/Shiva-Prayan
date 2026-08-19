import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prayan_trading_journal/design/components/metric_card.dart';
import 'package:prayan_trading_journal/design/palette.dart';
import 'package:prayan_trading_journal/design/theme.dart';

/// The day's guardrails, side by side, in the context that broke.
///
/// `CrossAxisAlignment.stretch` asks a row's children to fill its height. In a
/// sliver that height is unbounded, so the row threw — and in a release build
/// a throw during layout does not show a red box, it shows nothing: every
/// section of the dashboard below the meters simply disappeared, and the
/// screen looked merely empty rather than broken.
///
/// Pumped inside a real `CustomScrollView` for that reason. In a plain `Column`
/// under a `Scaffold` the bug does not reproduce.
void main() {
  Widget host(List<LimitMeter> meters) => MaterialApp(
        theme: PrayanThemeBuilder.build(PrayanTheme.daylight),
        home: Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverList.list(children: [
                LimitMeterPair(meters: meters),
                const Text('below the meters'),
              ]),
            ],
          ),
        ),
      );

  const lossLimit = LimitMeter(
    label: 'Loss limit',
    fraction: 0,
    usedLabel: '0R',
    limitLabel: '2R',
  );
  const trades = LimitMeter(
    label: 'Trades',
    fraction: 0,
    usedLabel: '0',
    limitLabel: '3',
  );

  testWidgets('a pair lays out inside a sliver', (tester) async {
    await tester.pumpWidget(host(const [lossLimit, trades]));
    expect(tester.takeException(), isNull);

    expect(find.text('LOSS LIMIT'), findsOneWidget);
    expect(find.text('TRADES'), findsOneWidget);
    // The half that actually mattered: everything after them still renders.
    expect(find.text('below the meters'), findsOneWidget);
  });

  testWidgets('they share a height even when one wraps', (tester) async {
    // A wrapping label used to make one card taller than the other, which is
    // what `stretch` is here to prevent.
    await tester.pumpWidget(host(const [
      LimitMeter(
        label: 'A considerably longer limit name that wraps',
        fraction: 0.5,
        usedLabel: '1R',
        limitLabel: '2R',
      ),
      trades,
    ]));
    expect(tester.takeException(), isNull);

    final boxes = tester
        .widgetList<LimitMeter>(find.byType(LimitMeter))
        .map((m) => tester.getSize(find.byWidget(m)).height)
        .toList();
    expect(boxes.first, boxes.last,
        reason: 'the two guardrail cards should be the same height');
  });

  testWidgets('one meter alone still renders', (tester) async {
    await tester.pumpWidget(host(const [trades]));
    expect(tester.takeException(), isNull);
    expect(find.text('TRADES'), findsOneWidget);
  });

  testWidgets('no meters renders nothing rather than an empty row',
      (tester) async {
    await tester.pumpWidget(host(const []));
    expect(tester.takeException(), isNull);
    expect(find.byType(LimitMeter), findsNothing);
    expect(find.text('below the meters'), findsOneWidget);
  });
}

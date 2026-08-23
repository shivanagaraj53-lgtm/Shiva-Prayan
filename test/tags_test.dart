import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prayan_core/prayan_core.dart';
import 'package:prayan_trading_journal/design/components/tag_editor.dart';
import 'package:prayan_trading_journal/design/palette.dart';
import 'package:prayan_trading_journal/design/theme.dart';
import 'package:prayan_trading_journal/features/trade/trade_form_controller.dart';

/// Tags, and the normalisation that keeps them useful.
///
/// The journal has always searched and filtered by tag; nothing could set one,
/// so the feature was a dead end in both directions. Adding the field is the
/// easy half. The half that decides whether tagging still works a few hundred
/// trades in is what happens to what people type: "FOMO", "fomo" and "fomo "
/// have to be one tag, or the filter meant to group them splits them instead.
void main() {
  group('normalising', () {
    test('case and surrounding space do not make a new tag', () {
      const forms = ['FOMO', 'fomo', '  Fomo  ', 'FoMo'];
      for (final form in forms) {
        expect(TradeFormController.normaliseTag(form), 'fomo',
            reason: '"$form" became a separate tag');
      }
    });

    test('internal whitespace collapses', () {
      expect(
          TradeFormController.normaliseTag('a  plus   setup'), 'a plus setup');
      expect(TradeFormController.normaliseTag('news\tevent'), 'news event');
    });

    test('nothing usable returns null rather than an empty tag', () {
      for (final empty in ['', '   ', '\n', '\t ']) {
        expect(TradeFormController.normaliseTag(empty), isNull,
            reason: 'whitespace became a tag');
      }
    });

    test('a very long tag is cut to a label, not stored whole', () {
      final long = 'x' * 80;
      final tag = TradeFormController.normaliseTag(long)!;
      expect(tag.length, 32);
    });
  });

  group('editing', () {
    TradeFormController controller() =>
        TradeFormController(DateTime.utc(2026, 8, 23, 10));

    test('adding, refusing duplicates, and removing', () {
      final c = controller();
      expect(c.addTag('Revenge'), isTrue);
      expect(c.state.tags, ['revenge']);

      // The same idea typed differently is the same tag.
      expect(c.addTag('  REVENGE '), isFalse,
          reason: 'a duplicate was added under a different spelling');
      expect(c.state.tags, ['revenge']);

      expect(c.addTag('news'), isTrue);
      expect(c.state.tags, ['revenge', 'news']);

      c.removeTag('revenge');
      expect(c.state.tags, ['news']);
    });

    test('rejected input reports false so the field can keep it', () {
      // Silently clearing what someone typed is worse than doing nothing.
      final c = controller();
      expect(c.addTag('   '), isFalse);
      expect(c.state.tags, isEmpty);
    });

    test('removing something that is not there changes nothing', () {
      final c = controller();
      c.addTag('news');
      c.removeTag('absent');
      expect(c.state.tags, ['news']);
    });

    test('tags reach the trade that gets saved', () {
      // The whole point: the journal filters on `Trade.tags`, so the form's
      // list has to survive the conversion.
      final c = controller();
      c.addTag('news');
      c.addTag('A Plus Setup');
      final trade = c.state.copyWith(symbol: 'INFY', entryPrice: '100').toTrade(
            userId: 'user',
            accountId: 'acct',
            dayKey: '2026-08-23',
            accountEquity: Dec.parse('500000'),
            presentedChecklistIds: const [],
            now: DateTime.utc(2026, 8, 23, 10),
          );
      expect(trade.tags, ['news', 'a plus setup']);
    });
  });

  group('the editor', () {
    Widget host({
      List<String> tags = const [],
      List<String> suggestions = const [],
      void Function(String)? added,
      void Function(String)? removed,
    }) =>
        MaterialApp(
          theme: PrayanThemeBuilder.build(PrayanTheme.daylight),
          home: Scaffold(
            body: TagEditor(
              tags: tags,
              suggestions: suggestions,
              onAdd: (raw) {
                added?.call(raw);
                return true;
              },
              onRemove: (tag) => removed?.call(tag),
            ),
          ),
        );

    testWidgets('typing and submitting adds a tag', (tester) async {
      final added = <String>[];
      await tester.pumpWidget(host(added: added.add));
      await tester.enterText(find.byType(TextField), 'revenge');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(added, ['revenge']);
    });

    testWidgets('a comma separates tags, because people type it anyway',
        (tester) async {
      final added = <String>[];
      await tester.pumpWidget(host(added: added.add));
      await tester.enterText(find.byType(TextField), 'news, revenge');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(added, ['news', ' revenge'],
          reason: 'both halves should be offered; normalising trims the space');
    });

    testWidgets('applied tags are not offered again as suggestions',
        (tester) async {
      await tester.pumpWidget(host(
        tags: const ['news'],
        suggestions: const ['news', 'revenge'],
      ));
      await tester.pumpAndSettle();
      // "news" appears once, as the applied chip — not a second time below.
      expect(find.text('news'), findsOneWidget);
      expect(find.text('revenge'), findsOneWidget);
    });

    testWidgets('with no history there is no suggestion strip', (tester) async {
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      expect(find.text('USED BEFORE'), findsNothing);
    });

    testWidgets('a tag chip can be removed and says what it removes',
        (tester) async {
      final removed = <String>[];
      await tester.pumpWidget(
        host(tags: const ['news'], removed: removed.add),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Remove news'));
      await tester.pumpAndSettle();
      expect(removed, ['news']);
    });
  });
}

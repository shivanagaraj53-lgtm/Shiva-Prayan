import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prayan_core/prayan_core.dart';
import 'package:prayan_trading_journal/design/palette.dart';
import 'package:prayan_trading_journal/design/theme.dart';
import 'package:prayan_trading_journal/domain/repositories.dart';
import 'package:prayan_trading_journal/features/rules/setups_screen.dart';
import 'package:prayan_trading_journal/state/providers.dart';

/// Setups, and editing the templates that live on them.
///
/// Setups could only ever be created during onboarding — no way to add,
/// rename or retire one afterwards, which is a strange thing to tell someone
/// whose trading changes. This screen is that, and it is where note templates
/// are written, so the two are tested together.
class _FakeStrategies implements StrategyRepository {
  _FakeStrategies(this._strategies);

  final List<Strategy> _strategies;
  final saved = <Strategy>[];
  late final _controller = StreamController<List<Strategy>>.broadcast();

  @override
  Stream<List<Strategy>> watchStrategies(String userId) async* {
    yield _strategies;
    yield* _controller.stream;
  }

  @override
  Future<void> saveStrategy(Strategy strategy) async => saved.add(strategy);

  @override
  Future<void> deleteStrategy(String id) async {}
}

void main() {
  const breakout = Strategy(id: 's1', userId: 'user', name: 'Breakout');
  const retired = Strategy(
    id: 's2',
    userId: 'user',
    name: 'Old scalp',
    isArchived: true,
  );

  Future<_FakeStrategies> pump(
    WidgetTester tester,
    List<Strategy> strategies,
  ) async {
    final repo = _FakeStrategies(strategies);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          strategyRepositoryProvider.overrideWithValue(repo),
          currentUserIdProvider.overrideWithValue('user'),
        ],
        child: MaterialApp(
          theme: PrayanThemeBuilder.build(PrayanTheme.daylight),
          home: const SetupsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return repo;
  }

  testWidgets('setups are listed, and say whether they have a template',
      (tester) async {
    await pump(tester, const [breakout]);
    expect(find.text('Breakout'), findsOneWidget);
    expect(find.text('No note template'), findsOneWidget);
  });

  testWidgets('a setup with a template says so', (tester) async {
    await pump(tester, const [
      Strategy(
        id: 's1',
        userId: 'user',
        name: 'Breakout',
        entryPrompt: 'Trigger:',
        exitPrompt: 'What ended it:',
      ),
    ]);
    expect(find.text('Template for entry and exit'), findsOneWidget);
  });

  testWidgets('retired setups are kept, under their own heading',
      (tester) async {
    // They have to stay: old trades point at them, and losing the name would
    // rewrite history.
    await pump(tester, const [breakout, retired]);
    expect(find.text('Retired'), findsOneWidget);
    expect(find.text('Old scalp'), findsOneWidget);
  });

  testWidgets('tapping a setup opens the editor with its values',
      (tester) async {
    await pump(tester, const [breakout]);
    await tester.tap(find.text('Breakout'));
    await tester.pumpAndSettle();

    expect(find.text('Edit setup'), findsOneWidget);
    expect(find.text('Before entering'), findsOneWidget);
    expect(find.text('After exiting'), findsOneWidget);
  });

  testWidgets('writing a template saves it onto the setup', (tester) async {
    final repo = await pump(tester, const [breakout]);
    await tester.tap(find.text('Breakout'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Before entering'),
      'Trigger:\nInvalidation:',
    );
    // The sheet is taller than the test surface, so the button has to be
    // brought on screen before it can be tapped.
    final save = find.widgetWithText(FilledButton, 'Save');
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(repo.saved, hasLength(1));
    expect(repo.saved.single.entryPrompt, 'Trigger:\nInvalidation:');
    expect(repo.saved.single.name, 'Breakout',
        reason: 'editing a template should not disturb the name');
  });

  testWidgets('cancelling saves nothing', (tester) async {
    final repo = await pump(tester, const [breakout]);
    await tester.tap(find.text('Breakout'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Before entering'),
      'Discarded',
    );
    final cancel = find.widgetWithText(OutlinedButton, 'Cancel');
    await tester.ensureVisible(cancel);
    await tester.pumpAndSettle();
    await tester.tap(cancel);
    await tester.pumpAndSettle();
    expect(repo.saved, isEmpty);
  });

  testWidgets('a new setup cannot be saved without a name', (tester) async {
    await pump(tester, const [breakout]);
    await tester.tap(find.widgetWithText(FloatingActionButton, 'New setup'));
    await tester.pumpAndSettle();

    expect(find.text('New setup'), findsWidgets);
    final saveButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Save'),
    );
    expect(saveButton.onPressed, isNull,
        reason: 'an unnamed setup is not something to save');
  });

  testWidgets('with nothing configured the screen explains what a setup is',
      (tester) async {
    await pump(tester, const []);
    expect(find.text('No setups yet'), findsOneWidget);
  });
}

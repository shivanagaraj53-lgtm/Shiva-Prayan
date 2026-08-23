import 'package:flutter_test/flutter_test.dart';
import 'package:prayan_core/prayan_core.dart';
import 'package:prayan_trading_journal/features/trade/trade_form_controller.dart';

/// Note templates: the same questions every time, without eating what you
/// wrote.
///
/// A blank "Why this trade?" box gets a blank answer, or one word that means
/// nothing three months later. Templates fix that by asking the setup's own
/// questions — and the whole feature is worthless the first time it overwrites
/// a paragraph of someone's reasoning, because nobody writes a second one.
void main() {
  Strategy setup(String name, {String? entry, String? exit}) => Strategy(
        id: name.toLowerCase(),
        userId: 'user',
        name: name,
        entryPrompt: entry,
        exitPrompt: exit,
      );

  final breakout = setup(
    'Breakout',
    entry: 'Trigger:\nInvalidation:\nWhy now:',
    exit: 'What ended it:',
  );
  final pullback = setup('Pullback', entry: 'Level:\nConfirmation:');
  final plain = setup('Scalp');

  TradeFormController controller() =>
      TradeFormController(DateTime.utc(2026, 8, 23, 4));

  test('picking a setup fills empty notes with its template', () {
    final c = controller();
    c.selectStrategy(breakout.id, breakout);
    expect(c.state.entryReason, breakout.entryPrompt);
    expect(c.state.exitReason, breakout.exitPrompt);
    expect(c.state.strategyId, breakout.id);
  });

  test('a setup with no template leaves the notes alone', () {
    final c = controller();
    c.selectStrategy(plain.id, plain);
    expect(c.state.entryReason, isEmpty);
    expect(c.state.exitReason, isEmpty);
  });

  test('changing setup replaces a template nobody edited', () {
    final c = controller();
    c.selectStrategy(breakout.id, breakout);
    c.selectStrategy(pullback.id, pullback);
    expect(c.state.entryReason, pullback.entryPrompt);
    // Pullback has no exit template, so the stale one is cleared rather than
    // left behind under the wrong setup.
    expect(c.state.exitReason, isEmpty);
  });

  test('what the user wrote is never overwritten', () {
    // The one that matters. Losing this paragraph to a dropdown would be the
    // last time anyone wrote one.
    final c = controller();
    c.selectStrategy(breakout.id, breakout);
    c.set(c.state.copyWith(
      entryReason: 'Broke the overnight high on three times average volume.',
    ));

    c.selectStrategy(pullback.id, pullback);
    expect(c.state.entryReason,
        'Broke the overnight high on three times average volume.');
    expect(c.state.strategyId, pullback.id,
        reason: 'the setup still changes; only the note is protected');
  });

  test('deselecting a setup clears an untouched template', () {
    final c = controller();
    c.selectStrategy(breakout.id, breakout);
    c.selectStrategy(null, null);
    expect(c.state.strategyId, isNull);
    expect(c.state.entryReason, isEmpty);
  });

  test('deselecting a setup keeps what the user wrote', () {
    final c = controller();
    c.selectStrategy(breakout.id, breakout);
    c.set(c.state.copyWith(entryReason: 'My own words'));
    c.selectStrategy(null, null);
    expect(c.state.entryReason, 'My own words');
  });

  test('a template that is only whitespace counts as no template', () {
    final c = controller();
    c.selectStrategy('x', setup('Whitespace', entry: '   \n  '));
    expect(c.state.entryReason, isEmpty);
  });

  group('the strategy model', () {
    test('templates survive a save and load', () {
      final restored = Strategy.fromMap(breakout.toMap());
      expect(restored.entryPrompt, breakout.entryPrompt);
      expect(restored.exitPrompt, breakout.exitPrompt);
    });

    test('a template can be cleared, not just changed', () {
      // `??` cannot tell "leave it" from "remove it", so copyWith takes a
      // sentinel. Without this, a user could never delete a template.
      final cleared = breakout.copyWith(entryPrompt: null);
      expect(cleared.entryPrompt, isNull);
      expect(cleared.exitPrompt, breakout.exitPrompt,
          reason: 'clearing one template should not touch the other');
    });

    test('an older stored setup with no templates still loads', () {
      final old = {
        'id': 's1',
        'userId': 'user',
        'name': 'Breakout',
        'isApproved': true,
      };
      final restored = Strategy.fromMap(old);
      expect(restored.entryPrompt, isNull);
      expect(restored.name, 'Breakout');
    });
  });
}

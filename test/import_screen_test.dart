import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prayan_trading_journal/design/palette.dart';
import 'package:prayan_trading_journal/design/theme.dart';
import 'package:prayan_trading_journal/features/settings/import_screen.dart';

/// The import screen builds and says what it is for.
///
/// The parsing is covered in the domain tests and end to end from real CSV
/// text. What this covers is the screen itself: that it renders before a file
/// is chosen, which is the state everyone sees first and the one a dropdown
/// with a null option is most likely to throw in.
void main() {
  Widget host() => const ProviderScope(
        child: _Host(),
      );

  testWidgets('it opens with an explanation and a way to choose a file',
      (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Import from CSV'), findsOneWidget);
    expect(find.text('Choose a CSV file'), findsOneWidget);
  });

  testWidgets('it promises a preview before anything is written',
      (tester) async {
    // The promise is the feature. An import that writes first and reports
    // afterwards puts wrong rows into a record the user cannot tell apart
    // from their own typing.
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    expect(find.textContaining('before anything is written'), findsOneWidget);
  });

  testWidgets('nothing to map or import is offered until a file is chosen',
      (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    expect(find.text('What the columns mean'), findsNothing);
    expect(find.text('What will be created'), findsNothing);
  });
}

class _Host extends StatelessWidget {
  const _Host();

  @override
  Widget build(BuildContext context) => MaterialApp(
        theme: PrayanThemeBuilder.build(PrayanTheme.daylight),
        home: const ImportScreen(),
      );
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:prayan_trading_journal/data/local/local_repositories.dart';
import 'package:prayan_trading_journal/data/local/local_store.dart';
import 'package:prayan_trading_journal/domain/repositories.dart';
import 'package:prayan_trading_journal/features/auth/sign_in_screen.dart';
import 'package:prayan_trading_journal/state/providers.dart';

/// The first screen must offer something that can succeed.
///
/// It did not. The screen opened on "Sign in" on every device, including one
/// with no account on it — and because accounts here are created on the device
/// and nowhere else, the first thing a new user could possibly be told was
/// "No account found". The button that would have worked was a text link
/// underneath.
///
/// So the screen now asks the backend what is possible before it decides, and
/// a sign-in that fails for a missing account offers to create it rather than
/// leaving the user to work that out.
Widget wrap(AuthRepository auth) => ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(auth)],
      child: const MaterialApp(home: SignInScreen()),
    );

Future<LocalAuthRepository> freshAuth() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  return LocalAuthRepository(LocalStore(await SharedPreferences.getInstance()));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a device with no account opens on creating one', (tester) async {
    final auth = await freshAuth();
    await tester.pumpWidget(wrap(auth));
    await tester.pumpAndSettle();

    expect(find.text('Create account'), findsOneWidget,
        reason: 'the primary button should create the account');
    expect(find.text('Create your journal'), findsOneWidget);
    expect(find.text('Sign in'), findsNothing,
        reason: 'there is nothing on this device to sign in to');
    // The way back is still there for anyone who wants it.
    expect(find.text('I already have an account'), findsOneWidget);
  });

  testWidgets('a device with an account opens on signing in', (tester) async {
    final auth = await freshAuth();
    await auth.registerWithEmail('shiva@example.com', 'a-password');
    await auth.signOut();

    await tester.pumpWidget(wrap(auth));
    await tester.pumpAndSettle();

    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets('the identifier is prefilled for a returning user',
      (tester) async {
    // Retyping an address is where the second typo comes from, and a typo here
    // reads as "account not found" — the same dead end wearing a disguise.
    final auth = await freshAuth();
    await auth.registerWithEmail('Shiva@Example.com', 'a-password');
    await auth.signOut();

    await tester.pumpWidget(wrap(auth));
    await tester.pumpAndSettle();

    expect(find.text('shiva@example.com'), findsOneWidget);
  });

  testWidgets('signing in to an account that does not exist offers to make it',
      (tester) async {
    // Reaching this needs an account on the device (so the screen opens on
    // sign-in) and then a *different* identifier typed into it.
    final auth = await freshAuth();
    await auth.registerWithEmail('someone@example.com', 'a-password');
    await auth.signOut();

    await tester.pumpWidget(wrap(auth));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byType(TextFormField).first, 'shiva@example.com');
    await tester.enterText(find.byType(TextFormField).last, 'a-password');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.textContaining('No account found'), findsOneWidget);
    expect(find.text('Create this account'), findsOneWidget,
        reason: 'the fix is one tap away and must be offered');

    await tester.tap(find.text('Create this account'));
    await tester.pumpAndSettle();

    expect(find.text('Create account'), findsOneWidget);
    // What was typed survives the switch — retyping it is a second chance to
    // get it wrong.
    expect(find.text('shiva@example.com'), findsOneWidget);
  });

  testWidgets('a wrong password is not offered an account', (tester) async {
    // Only a *missing* account gets the offer. Turning "wrong password" into
    // "create an account" would quietly make a second account for someone who
    // simply mistyped, and strand the journal in the first one.
    final auth = await freshAuth();
    await auth.registerWithEmail('shiva@example.com', 'a-password');
    await auth.signOut();

    await tester.pumpWidget(wrap(auth));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byType(TextFormField).first, 'shiva@example.com');
    await tester.enterText(find.byType(TextFormField).last, 'wrong-password');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    expect(find.textContaining('does not match'), findsOneWidget);
    expect(find.text('Create this account'), findsNothing);
  });

  test('deleting the account forgets the identifier too', () async {
    // Otherwise the next visitor is greeted by the address of an account that
    // no longer exists, and signing in with it fails — the exact dead end.
    final auth = await freshAuth();
    await auth.registerWithEmail('shiva@example.com', 'a-password');
    await auth.deleteAccount();

    expect(await auth.hasExistingAccount(), isFalse);
    expect(await auth.lastUsedIdentifier(), isNull);
  });
}

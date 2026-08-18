import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:prayan_trading_journal/data/local/local_repositories.dart';
import 'package:prayan_trading_journal/data/local/local_store.dart';
import 'package:prayan_trading_journal/domain/repositories.dart';
import 'package:prayan_trading_journal/features/auth/sign_in_screen.dart';
import 'package:prayan_trading_journal/state/providers.dart';

/// The account identifier is whatever the backend can key an account by.
///
/// Nothing in the shipping build sends mail — no verification, no reset, no
/// federation — so requiring an email address was a formality, and one that
/// turned away anyone who wanted to be `shiva`. The repository declares what
/// it accepts and the screen asks for that, the same arrangement already used
/// for sign-in providers.
///
/// Firebase does need a real address, so the distinction is asserted rather
/// than assumed: a backend that declares [AuthIdentifier.email] must still
/// refuse a username.
Future<LocalAuthRepository> freshAuth() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  return LocalAuthRepository(LocalStore(await SharedPreferences.getInstance()));
}

class _FakeAuth implements AuthRepository {
  _FakeAuth(this.identifierKind);

  @override
  final AuthIdentifier identifierKind;

  @override
  Set<AuthProvider> get supportedProviders => const {
        AuthProvider.emailPassword,
      };

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError();
}

Widget wrap(AuthRepository auth) => ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(auth)],
      child: const MaterialApp(home: SignInScreen()),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the device-local backend', () {
    test('accepts a username, and signs back in with it', () async {
      final auth = await freshAuth();
      expect(auth.identifierKind, AuthIdentifier.emailOrUsername);

      final registered = await auth.registerWithEmail('Shiva', 'a-password');
      expect(registered.username, 'shiva',
          reason: 'a username account should carry a username');
      expect(registered.email, isNull,
          reason: 'writing a username into the email field is a lie that '
              'reaches the profile record');
      expect(registered.identifier, 'shiva');

      await auth.signOut();

      // Case is not part of the identity: someone who registered as "Shiva"
      // and signs in as "shiva" is the same person.
      final back = await auth.signInWithEmail('shiva', 'a-password');
      expect(back.id, registered.id);
    });

    test('still treats an email address as an email address', () async {
      final auth = await freshAuth();
      final user = await auth.registerWithEmail('Shiva@Prayan.app', 'a-password');
      expect(user.email, 'shiva@prayan.app');
      expect(user.username, isNull);
      expect(user.identifier, 'shiva@prayan.app');
    });

    test('a half-typed address is a slip, not a username', () async {
      // The '@' is what decides which kind it is, so anything carrying one has
      // to survive the email check — otherwise `shiva@` quietly becomes an
      // account nobody would think to type again.
      for (final bad in ['shiva@', 'shiva@localhost', '@prayan.app']) {
        await expectLater(
          (await freshAuth()).registerWithEmail(bad, 'a-password'),
          throwsA(isA<RepositoryException>()),
          reason: '"$bad" was accepted',
        );
      }
    });

    test('a username has to be usable', () async {
      for (final bad in ['sh', 'shiva nagaraj']) {
        await expectLater(
          (await freshAuth()).registerWithEmail(bad, 'a-password'),
          throwsA(isA<RepositoryException>()),
          reason: '"$bad" was accepted',
        );
      }
    });

    test('the wrong password is still the wrong password', () async {
      final auth = await freshAuth();
      await auth.registerWithEmail('shiva', 'a-password');
      await auth.signOut();
      await expectLater(
        auth.signInWithEmail('shiva', 'not-the-password'),
        throwsA(isA<RepositoryException>()),
      );
    });

    test('deleting a username account really deletes the login', () async {
      // This one was broken: the credential was keyed off the email field, so
      // for a username account "delete my account" wiped the data and left the
      // password behind — the account still signs in, into an empty journal.
      // Both stores treat a delete that does not delete as a policy breach.
      final auth = await freshAuth();
      await auth.registerWithEmail('shiva', 'a-password');
      await auth.deleteAccount();

      await expectLater(
        auth.signInWithEmail('shiva', 'a-password'),
        throwsA(isA<RepositoryException>()),
        reason: 'the deleted account can still sign in',
      );
    });
  });

  group('the sign-in screen', () {
    testWidgets('asks for a username when the backend accepts one',
        (tester) async {
      await tester.pumpWidget(wrap(_FakeAuth(AuthIdentifier.emailOrUsername)));
      await tester.pumpAndSettle();
      expect(find.text('Email or username'), findsOneWidget);
      expect(find.text('Email'), findsNothing);
    });

    testWidgets('asks for an email when the backend needs one', (tester) async {
      await tester.pumpWidget(wrap(_FakeAuth(AuthIdentifier.email)));
      await tester.pumpAndSettle();
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Email or username'), findsNothing);
    });

    testWidgets('an email-only backend rejects a username in the field',
        (tester) async {
      // The screen must not send something the backend will refuse. Firebase
      // needs a real address, so a username has to fail here rather than in a
      // round trip.
      await tester.pumpWidget(wrap(_FakeAuth(AuthIdentifier.email)));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).first, 'Shiva');
      await tester.enterText(find.byType(TextFormField).last, 'a-password');
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();

      expect(find.text('That does not look like an email address.'),
          findsOneWidget);
    });
  });
}

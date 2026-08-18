import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:prayan_trading_journal/data/local/local_repositories.dart';
import 'package:prayan_trading_journal/data/local/local_store.dart';
import 'package:prayan_trading_journal/domain/repositories.dart';
import 'package:prayan_trading_journal/features/auth/sign_in_screen.dart';
import 'package:prayan_trading_journal/state/providers.dart';

/// A sign-in button that cannot complete a sign-in is an App Review rejection
/// under guideline 2.1 (App Completeness), and a dead end for the user either
/// way. The screen therefore renders a provider button only when the backend
/// in use declares it can serve that provider.
///
/// This is exactly the kind of thing that comes back the next time someone
/// adds a provider or swaps the backend, so it is asserted rather than
/// remembered.
class _FakeAuth implements AuthRepository {
  _FakeAuth(this.supportedProviders);

  @override
  final Set<AuthProvider> supportedProviders;

  @override
  AuthUser? get currentUser => null;

  @override
  Stream<AuthUser?> authStateChanges() => const Stream<AuthUser?>.empty();

  @override
  Future<AuthUser> signInWithEmail(String email, String password) async =>
      throw UnimplementedError();

  @override
  Future<AuthUser> registerWithEmail(String email, String password) async =>
      throw UnimplementedError();

  @override
  Future<AuthUser> signInWithGoogle() async => throw UnimplementedError();

  @override
  Future<AuthUser> signInWithApple() async => throw UnimplementedError();

  @override
  Future<void> sendPasswordReset(String email) async {}

  @override
  Future<void> sendEmailVerification() async {}

  @override
  Future<void> signOut() async {}

  @override
  Future<void> deleteAccount() async {}
}

Widget wrap(AuthRepository auth) => ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(auth)],
      child: const MaterialApp(home: SignInScreen()),
    );

void main() {
  testWidgets('email-only backend offers no third-party buttons',
      (tester) async {
    await tester.pumpWidget(wrap(_FakeAuth(const {AuthProvider.emailPassword})));
    await tester.pumpAndSettle();

    expect(find.text('Continue with Google'), findsNothing);
    expect(find.text('Continue with Apple'), findsNothing);
    // The "or" separator belongs to that block and goes with it.
    expect(find.text('or'), findsNothing);
    // Email sign-in is still fully present.
    expect(find.text('Sign in'), findsOneWidget);
  });

  testWidgets('a backend that supports Google offers exactly that',
      (tester) async {
    await tester.pumpWidget(wrap(
      _FakeAuth(const {AuthProvider.emailPassword, AuthProvider.google}),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Continue with Apple'), findsNothing);
    expect(find.text('or'), findsOneWidget);
  });

  testWidgets('a backend that supports both offers both', (tester) async {
    await tester.pumpWidget(wrap(_FakeAuth(const {
      AuthProvider.emailPassword,
      AuthProvider.google,
      AuthProvider.apple,
    })));
    await tester.pumpAndSettle();

    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Continue with Apple'), findsOneWidget);
  });

  testWidgets('the shipping local backend declares email only',
      (tester) async {
    // The build that goes to the stores today runs on device-local storage,
    // which can verify a password and nothing else.
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final auth = LocalAuthRepository(
      LocalStore(await SharedPreferences.getInstance()),
    );
    expect(auth.supportedProviders, {AuthProvider.emailPassword});
  });
}

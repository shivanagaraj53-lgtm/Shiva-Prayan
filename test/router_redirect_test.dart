import 'package:flutter_test/flutter_test.dart';
import 'package:prayan_trading_journal/app/router.dart';

/// Signed out, sign-in is the only screen worth being on.
///
/// Onboarding used to be allowed there too, and it is reachable: the web build
/// restores the last route on reload, so losing a session mid-onboarding put
/// someone straight back into twelve steps of form with no user to save them
/// against, and no way to reach the sign-in screen.
void main() {
  String? at(
    String path, {
    bool authLoading = false,
    bool signedIn = true,
    bool onboardingComplete = true,
  }) =>
      redirectFor(
        authLoading: authLoading,
        signedIn: signedIn,
        onboardingComplete: onboardingComplete,
        path: path,
      );

  group('signed out', () {
    test('every route lands on sign-in', () {
      for (final path in [
        Routes.onboarding,
        Routes.dashboard,
        Routes.journal,
        Routes.settings,
        Routes.logTrade,
        Routes.splash,
      ]) {
        expect(at(path, signedIn: false), Routes.signIn,
            reason: '$path was reachable with no user');
      }
    });

    test('sign-in itself is left alone', () {
      expect(at(Routes.signIn, signedIn: false), isNull);
    });
  });

  group('signed in, onboarding unfinished', () {
    test('everything funnels into onboarding', () {
      expect(
          at(Routes.dashboard, onboardingComplete: false), Routes.onboarding);
      expect(at(Routes.signIn, onboardingComplete: false), Routes.onboarding);
    });

    test('onboarding itself is left alone', () {
      expect(at(Routes.onboarding, onboardingComplete: false), isNull);
    });
  });

  group('signed in and set up', () {
    test('the entry screens hand over to the dashboard', () {
      expect(at(Routes.splash), Routes.dashboard);
      expect(at(Routes.signIn), Routes.dashboard);
      expect(at(Routes.onboarding), Routes.dashboard);
    });

    test('anywhere else is left alone', () {
      expect(at(Routes.journal), isNull);
      expect(at(Routes.dashboard), isNull);
      expect(at(Routes.dailyReview('2026-08-18')), isNull);
    });
  });

  test('the splash holds only while auth is still resolving', () {
    expect(at(Routes.splash, authLoading: true), isNull);
    expect(at(Routes.dashboard, authLoading: true), Routes.splash);
    // And stops holding the moment the answer arrives.
    expect(at(Routes.splash, signedIn: false), Routes.signIn);
  });
}

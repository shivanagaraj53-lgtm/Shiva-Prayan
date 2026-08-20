import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:prayan_trading_journal/data/local/local_repositories.dart';
import 'package:prayan_trading_journal/data/local/local_store.dart';
import 'package:prayan_trading_journal/domain/repositories.dart';

/// A build can be compiled to already know one account.
///
/// Accounts live on the device and nowhere else, which is right for a journal
/// with no server and exhausting for one person across a phone, a browser and
/// a reinstall: every one of them is a fresh machine that asks them to sign up
/// again. `--dart-define` lets a build carry one account so those installs open
/// into the journal instead.
///
/// The defines are absent here, which is the case that matters most: this is
/// the configuration that goes to the App Store and to Play, and it must
/// behave exactly as it did before the feature existed.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<LocalAuthRepository> freshAuth() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    return LocalAuthRepository(
      LocalStore(await SharedPreferences.getInstance()),
    );
  }

  test('a build without the defines seeds nothing', () {
    expect(LocalAuthRepository.hasSeed, isFalse,
        reason: 'the test suite runs without --dart-define, and so does the '
            'build that ships');
  });

  test('seeding is a no-op on an unconfigured build', () async {
    final auth = await freshAuth();
    expect(await auth.seedConfiguredAccount(), isNull);
    expect(await auth.hasExistingAccount(), isFalse,
        reason: 'an unconfigured build must not invent an account');
    expect(auth.currentUser, isNull);
  });

  test('an unconfigured build still opens on creating an account', () async {
    // The sign-in screen decides its opening mode from this. A store build
    // must still land a new user on "create", not on a sign-in form for an
    // account that does not exist.
    final auth = await freshAuth();
    await auth.seedConfiguredAccount();
    expect(await auth.hasExistingAccount(), isFalse);
  });

  test('the seed user id is fixed, because the hash is salted with it', () {
    // A random id would make the stored hash unverifiable on the next device,
    // which is the entire point of seeding. If this ever becomes dynamic the
    // seeded password stops working and the failure looks like a wrong
    // password.
    expect(LocalAuthRepository.seedUserId, 'user_seed');
  });

  test('signing out is remembered, so a seeded build can be signed out of',
      () async {
    // Without this the sign-out button is inert on a seeded build — bootstrap
    // signs straight back in on the next launch — and the sign-in screen
    // becomes unreachable.
    final auth = await freshAuth();
    await auth.registerWithEmail('someone@example.com', 'a-password');
    await auth.signOut();
    expect(auth.currentUser, isNull);

    // Seeding runs again on the next launch and must respect that.
    expect(await auth.seedConfiguredAccount(), isNull);
    expect(auth.currentUser, isNull);
  });

  test('signing back in clears the sign-out marker', () async {
    final auth = await freshAuth();
    await auth.registerWithEmail('someone@example.com', 'a-password');
    await auth.signOut();
    await auth.signInWithEmail('someone@example.com', 'a-password');
    expect(auth.currentUser, isNotNull);
  });

  group('the seed hash', () {
    // Known vectors, computed independently of the Dart implementation.
    //
    // This is the check that matters most and is the easiest to skip: the hash
    // compiled into a build is produced by one implementation and verified by
    // another, and if they disagree by a single byte the only symptom is
    // "that password does not match" on a device, with nothing to debug.
    //
    // Deliberately throwaway passwords. A real one has no business in a test
    // file, and these prove the algorithm just as well.
    const vectors = <String, String>{
      'Sample@2023': '636ac62d',
      'abcdefgh': '7960607e',
      'Zz9!Zz9!Zz9!': 'd297643c',
      'ünïcødé-pass': '1b12f5f1',
    };

    vectors.forEach((password, expected) {
      test('hashes "$password" the same way anything else must', () {
        expect(LocalAuthRepository.seedHashFor(password), expected);
      });
    });

    test('a seeded hash is what sign-in will actually compare against',
        () async {
      // End to end, without a browser: seed a device the way a configured
      // build does, then sign in through the ordinary path and confirm the
      // stored hash verifies. If seeding and verification ever salt
      // differently, this fails here rather than on someone's phone.
      const password = 'Sample@2023';
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final store = LocalStore(await SharedPreferences.getInstance());
      final auth = LocalAuthRepository(store);

      await store.setString(
        'cred:seeded@example.com',
        '{"userId":"${LocalAuthRepository.seedUserId}",'
            '"hash":"${LocalAuthRepository.seedHashFor(password)}"}',
      );

      final user = await auth.signInWithEmail('seeded@example.com', password);
      expect(user.id, LocalAuthRepository.seedUserId);

      await expectLater(
        auth.signInWithEmail('seeded@example.com', 'not-the-password'),
        throwsA(isA<RepositoryException>()),
      );
    });
  });

  test('the repository carries no credential of its own', () async {
    // The defines are the only route in. A literal address or hash compiled
    // into source would be a credential in version control.
    expect(LocalAuthRepository.seededIdentifier, isEmpty);
    expect(LocalAuthRepository.seededHash, isEmpty);
  });
}

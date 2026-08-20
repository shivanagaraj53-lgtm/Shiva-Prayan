import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest_10y.dart' as tz_data;

import '../data/local/local_repositories.dart';
import '../data/local/local_store.dart';
import '../state/providers.dart';

/// Wires concrete implementations into the provider graph.
///
/// This is the *only* file that names a concrete repository. Enabling the
/// Firebase backend means changing the right-hand side of these overrides and
/// nothing else — see `docs/FIREBASE_SETUP.md`.
class Bootstrap {
  const Bootstrap._();

  /// Prepares platform services and returns the provider overrides.
  static Future<List<Override>> initialise() async {
    // The timezone database has to be loaded before any day-key bucketing.
    // The 10-year dataset is a fraction of the full database's size and
    // comfortably covers a journal's useful range.
    tz_data.initializeTimeZones();

    final store = await LocalStore.open();

    final auth = LocalAuthRepository(store);
    final profiles = LocalProfileRepository(store);

    // A build compiled with a seeded account puts it on the device before the
    // router asks who is signed in, so a fresh install opens into the journal
    // rather than into a sign-up form. Does nothing on a build without the
    // defines, which is every build that goes to a store.
    await auth.seedConfiguredAccount();

    return [
      localStoreProvider.overrideWithValue(store),
      authRepositoryProvider.overrideWithValue(auth),
      profileRepositoryProvider.overrideWithValue(profiles),
      accountRepositoryProvider
          .overrideWithValue(LocalAccountRepository(store)),
      strategyRepositoryProvider
          .overrideWithValue(LocalStrategyRepository(store)),
      checklistRepositoryProvider
          .overrideWithValue(LocalChecklistRepository(store)),
      ruleRepositoryProvider.overrideWithValue(LocalRuleRepository(store)),
      tradeRepositoryProvider.overrideWithValue(LocalTradeRepository(store)),
      reviewRepositoryProvider.overrideWithValue(LocalReviewRepository(store)),
      psychologyRepositoryProvider
          .overrideWithValue(LocalPsychologyRepository(store)),
      disciplineRepositoryProvider
          .overrideWithValue(LocalDisciplineRepository(store)),
      attachmentRepositoryProvider
          .overrideWithValue(LocalAttachmentRepository(store)),
      // No AI narrative without the backend; the deterministic
      // InsightEngine supplies every coaching line instead.
      coachingRepositoryProvider
          .overrideWithValue(const UnavailableCoachingRepository()),

      // --- Firebase configuration -------------------------------------
      // Replace the overrides above with the Firestore implementations once
      // `flutterfire configure` has generated lib/firebase_options.dart:
      //
      //   await Firebase.initializeApp(
      //     options: DefaultFirebaseOptions.currentPlatform,
      //   );
      //   final firestore = FirebaseFirestore.instance;
      //   firestore.settings = const Settings(
      //     persistenceEnabled: true,          // offline-first (§19)
      //     cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      //   );
      //
      //   authRepositoryProvider.overrideWithValue(
      //     FirebaseAuthRepository(FirebaseAuth.instance),
      //   ),
      //   tradeRepositoryProvider.overrideWithValue(
      //     FirestoreTradeRepository(firestore),
      //   ),
      //   ... and so on for each repository.
      //
      // `coachingRepositoryProvider` points at the Cloud Run service in the
      // Shiva-PrayanAI repository; until it is deployed the deterministic
      // on-device InsightEngine supplies every coaching line.
    ];
  }
}

/// Exposes the store so account deletion can clear everything at once.
final localStoreProvider = Provider<LocalStore>(
  (ref) => throw UnimplementedError('Override this provider in bootstrap.dart'),
);

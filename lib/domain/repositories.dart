/// Repository interfaces.
///
/// Feature code depends only on these. Two implementations exist:
///  * `lib/data/local/` — device-local persistence, which is what runs today
///    and what the offline queue writes through;
///  * `lib/data/firestore/` — the Cloud Firestore implementation, enabled by
///    the steps in `docs/FIREBASE_SETUP.md`.
///
/// Because every method here is expressed in domain types with no Firestore
/// or SharedPreferences vocabulary leaking through, swapping implementations
/// touches exactly one file: `lib/app/bootstrap.dart`.
library;

import 'package:prayan_core/prayan_core.dart';

import 'models.dart';

/// Signed-in identity. Deliberately minimal: the journal needs a stable user
/// id and nothing else about the person.
class AuthUser {
  final String id;

  /// Set only when the account really is keyed by an email address.
  ///
  /// A backend with no server behind it can let someone sign in as `shiva`,
  /// and writing that into an email field is a lie that outlives the moment:
  /// the day anything sends mail, it sends it to nobody. So a username lands
  /// in [username] and this stays null.
  final String? email;

  /// Set instead of [email] when the account is keyed by a plain username.
  final String? username;

  final String? displayName;
  final bool isEmailVerified;
  final bool isAnonymous;

  const AuthUser({
    required this.id,
    this.email,
    this.username,
    this.displayName,
    this.isEmailVerified = false,
    this.isAnonymous = false,
  });

  /// What this person typed to sign in, whichever kind it is.
  ///
  /// Falls back to the user id so a screen showing "you are signed in as…"
  /// always has something true to show.
  String get identifier => email ?? username ?? id;
}

/// Why a repository call failed, when a screen needs to do something about it
/// rather than just show the sentence.
///
/// Deliberately tiny. A screen matching on the *text* of an error breaks the
/// day someone rewords it, and rewording user-facing copy should never be a
/// behavioural change.
enum RepositoryFailure {
  /// No account exists for the identifier given.
  noSuchAccount,

  /// Anything else. The message is the whole story.
  other,
}

/// A failure that already carries a sentence fit to show a user.
///
/// Repositories translate transport errors here, so no screen ever has to
/// decide what a `PERMISSION_DENIED` looks like in plain English (§26).
class RepositoryException implements Exception {
  /// Shown to the user.
  final String message;

  /// Kept for logs and crash reports; never rendered.
  final Object? cause;

  final bool isRetryable;

  /// What went wrong, for the rare case a screen must branch on it.
  final RepositoryFailure failure;

  const RepositoryException(
    this.message, {
    this.cause,
    this.isRetryable = true,
    this.failure = RepositoryFailure.other,
  });

  bool get isNoSuchAccount => failure == RepositoryFailure.noSuchAccount;

  @override
  String toString() => 'RepositoryException($message)';
}

/// A way of signing in that a backend may or may not be able to serve.
enum AuthProvider { emailPassword, google, apple }

/// What a backend accepts as the account identifier.
///
/// Declared by the repository for the same reason [AuthProvider] is: the
/// screen should ask for what the backend can actually use, rather than
/// demanding an email address for a field nothing will ever send mail to.
enum AuthIdentifier {
  /// An email address, and nothing else. Required by any backend that sends
  /// mail — verification, password reset — or federates identity.
  email,

  /// An email address or a plain username, whichever the user prefers. Only
  /// honest for a device-local backend, where the identifier is a key in a
  /// local store and nothing more.
  emailOrUsername,
}

abstract interface class AuthRepository {
  /// Emits on sign-in, sign-out and token refresh. `null` means signed out.
  Stream<AuthUser?> authStateChanges();

  AuthUser? get currentUser;

  /// The providers this backend can actually complete a sign-in with.
  ///
  /// The sign-in screen renders a button only for what is in here. Showing a
  /// "Continue with Google" button that throws the moment it is tapped is an
  /// App Review rejection under guideline 2.1 (App Completeness), and it is a
  /// worse experience than not offering it — so availability is a property of
  /// the backend rather than something the UI assumes.
  Set<AuthProvider> get supportedProviders;

  /// What this backend accepts as the account identifier.
  AuthIdentifier get identifierKind;

  /// Whether signing in could succeed on this device at all.
  ///
  /// A device-local backend knows exactly: with no stored credentials there is
  /// nothing to sign into, and offering "Sign in" first means a new user's
  /// first experience of the app is being told their account does not exist.
  /// A server-backed one cannot know — the account may have been created on
  /// another phone — so it answers true and lets the attempt decide.
  Future<bool> hasExistingAccount();

  /// The identifier last used to sign in on this device, if any.
  ///
  /// Only ever the identifier: the password is not something to remember for
  /// someone. Lets a returning user tap straight into the password field
  /// rather than retype an address they may have typed differently.
  Future<String?> lastUsedIdentifier();

  Future<AuthUser> signInWithEmail(String email, String password);
  Future<AuthUser> registerWithEmail(String email, String password);
  Future<AuthUser> signInWithGoogle();
  Future<AuthUser> signInWithApple();
  Future<void> sendPasswordReset(String email);
  Future<void> sendEmailVerification();
  Future<void> signOut();

  /// Deletes the account and every document belonging to it.
  ///
  /// Required by both stores for any app with accounts (§4, §28). The
  /// implementation must remove data, not just disable the login.
  Future<void> deleteAccount();
}

abstract interface class ProfileRepository {
  Stream<UserProfile?> watchProfile(String userId);
  Future<UserProfile?> getProfile(String userId);
  Future<void> saveProfile(UserProfile profile);

  Future<AppPreferences> getPreferences(String userId);
  Future<void> savePreferences(String userId, AppPreferences preferences);

  Future<NotificationPreferences> getNotificationPreferences(String userId);
  Future<void> saveNotificationPreferences(
    String userId,
    NotificationPreferences preferences,
  );
}

abstract interface class AccountRepository {
  Stream<List<TradingAccount>> watchAccounts(String userId);
  Future<void> saveAccount(TradingAccount account);
  Future<void> archiveAccount(String accountId);
}

abstract interface class StrategyRepository {
  Stream<List<Strategy>> watchStrategies(String userId);
  Future<void> saveStrategy(Strategy strategy);
  Future<void> deleteStrategy(String strategyId);
}

abstract interface class ChecklistRepository {
  Stream<List<ChecklistItem>> watchChecklist(String userId);
  Future<void> saveChecklistItem(ChecklistItem item);
  Future<void> deleteChecklistItem(String itemId);
  Future<void> reorderChecklist(List<String> orderedIds);
}

abstract interface class RuleRepository {
  Stream<List<Rule>> watchRules(String userId);
  Future<List<Rule>> getRules(String userId);

  /// Creates a rule at version 1.
  Future<void> createRule(Rule rule);

  /// Supersedes the live version with [newVersion], closing the old one at
  /// [effectiveFromUtc]. Never mutates history — that is the guarantee the
  /// audit trail depends on (§21).
  Future<void> publishRuleVersion(
    String ruleId,
    RuleVersion newVersion,
    DateTime effectiveFromUtc,
  );

  Future<void> setRuleActive(String ruleId, bool isActive);
  Future<void> deleteRule(String ruleId);
  Future<void> reorderRules(List<String> orderedIds);
}

abstract interface class TradeRepository {
  /// All trades on a given trading day.
  Stream<List<Trade>> watchTradesForDay(String userId, String dayKey);

  /// Trades in a day-key range, inclusive. Powers history and analytics.
  Stream<List<Trade>> watchTradesInRange(
    String userId, {
    required String fromDayKey,
    required String toDayKey,
    String? accountId,
  });

  Future<Trade?> getTrade(String tradeId);

  /// Creates or updates. Implementations must be idempotent on [Trade.id] so
  /// a retried offline write cannot create a duplicate trade (§19).
  Future<void> saveTrade(Trade trade);

  Future<void> deleteTrade(String tradeId);

  /// Number of writes waiting to reach the server.
  Stream<int> watchPendingWriteCount();
}

abstract interface class ReviewRepository {
  Stream<DailyReview?> watchDailyReview(String userId, String dayKey);
  Future<void> saveDailyReview(DailyReview review);
  Stream<List<DailyReview>> watchReviewsInRange(
    String userId, {
    required String fromDayKey,
    required String toDayKey,
  });
}

abstract interface class PsychologyRepository {
  Stream<List<PsychologyEntry>> watchEntriesForDay(
    String userId,
    String dayKey,
  );
  Future<void> saveEntry(PsychologyEntry entry);

  Stream<List<BehaviourWatch>> watchBehaviourWatches(String userId);
  Future<void> saveBehaviourWatch(BehaviourWatch watch);
  Future<void> deleteBehaviourWatch(String id);
}

/// Persisted daily discipline records — the history the streak reads.
///
/// These are written by the server in the Firebase configuration so a client
/// cannot fabricate a score (§4: "never trust client-calculated scores for
/// authoritative stored results"). The local implementation computes them on
/// device, which is correct for a single-device journal but is explicitly not
/// the production trust model.
abstract interface class DisciplineRepository {
  Stream<List<DailyDisciplineRecord>> watchHistory(
    String userId, {
    required String fromDayKey,
    required String toDayKey,
  });

  Future<void> upsertDailyRecord(String userId, DailyDisciplineRecord record);
}

/// Chart screenshots and other attachments.
abstract interface class AttachmentRepository {
  /// Uploads [bytes] and returns the stored attachment id.
  ///
  /// [onProgress] reports 0–1 so the UI can show real progress rather than an
  /// indeterminate spinner (§18).
  Future<String> upload(
    String userId,
    List<int> bytes, {
    required String filename,
    required String contentType,
    void Function(double progress)? onProgress,
  });

  Future<Uri?> resolveUrl(String attachmentId);
  Future<void> delete(String attachmentId);
}

/// The AI narrative layer (§15).
///
/// Takes only computed [CoachingFacts] and returns prose. An implementation
/// that cannot reach the service must return `null` rather than inventing
/// anything; callers fall back to [InsightEngine], which always works.
abstract interface class CoachingRepository {
  Future<String?> narrateDay(CoachingFacts facts);
}

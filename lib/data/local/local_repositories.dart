import 'dart:async';
import 'dart:convert';

import 'package:prayan_core/prayan_core.dart';

import '../../domain/models.dart';
import '../../domain/repositories.dart';
import 'local_store.dart';

/// Device-local implementations of every repository interface.
///
/// Documents are serialised with the same `toMap`/`fromMap` pairs the
/// Firestore implementation uses, so the two stores hold byte-identical
/// documents and a migration is a copy rather than a translation.

/// Signs a user in against locally stored credentials.
///
/// Passwords are never stored — only a salted hash — because even a local-only
/// build should not keep a recoverable secret on disk. Real multi-device auth
/// arrives with Firebase Authentication; this exists so the app is fully
/// usable, and fully testable, before that is wired up.
class LocalAuthRepository implements AuthRepository {
  final LocalStore _store;
  final _controller = StreamController<AuthUser?>.broadcast();
  AuthUser? _current;

  LocalAuthRepository(this._store) {
    final raw = _store.getString(Collections.sessionUserKey);
    if (raw != null) {
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        _current = AuthUser(
          id: map['id'] as String,
          email: map['email'] as String?,
          displayName: map['displayName'] as String?,
          isEmailVerified: map['isEmailVerified'] as bool? ?? false,
        );
      } on FormatException {
        _current = null;
      }
    }
  }

  @override
  AuthUser? get currentUser => _current;

  @override
  Stream<AuthUser?> authStateChanges() async* {
    yield _current;
    yield* _controller.stream;
  }

  Future<void> _setSession(AuthUser? user) async {
    _current = user;
    if (user == null) {
      await _store.removeKey(Collections.sessionUserKey);
    } else {
      await _store.setString(
        Collections.sessionUserKey,
        jsonEncode({
          'id': user.id,
          'email': user.email,
          'displayName': user.displayName,
          'isEmailVerified': user.isEmailVerified,
        }),
      );
    }
    _controller.add(user);
  }

  static const _credentialPrefix = 'cred:';
  String _credentialKey(String email) =>
      '$_credentialPrefix${email.toLowerCase().trim()}';

  /// Deliberately not a password hash you would ship to production.
  ///
  /// A real implementation uses Firebase Authentication, which never sees the
  /// password in plaintext and applies scrypt server-side. This exists only so
  /// the local build does not keep a recoverable secret on disk; it is not a
  /// substitute, and `docs/FIREBASE_SETUP.md` says so.
  String _obscure(String password, String salt) {
    var hash = 0x811c9dc5;
    for (final unit in utf8.encode('$salt::$password')) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16);
  }

  /// Whether [identifier] is being used as an email address.
  ///
  /// The presence of an `@` is the whole test. Someone typing an address gets
  /// an address; someone typing `shiva` gets a username. Nothing else in the
  /// app has to care which it was.
  static bool _looksLikeEmail(String identifier) => identifier.contains('@');

  /// Rejects an identifier this store cannot key an account by.
  ///
  /// An address still has to look like one — a half-typed `shiva@` is far
  /// more likely to be a mistake than a deliberate choice, and it would
  /// otherwise become an account nobody could find their way back into.
  static void _checkIdentifier(String identifier) {
    if (_looksLikeEmail(identifier)) {
      final parts = identifier.split('@');
      if (parts.length != 2 || parts[0].isEmpty || !parts[1].contains('.')) {
        throw const RepositoryException(
          'That does not look like a valid email address.',
          isRetryable: false,
        );
      }
      return;
    }
    if (identifier.length < 3) {
      throw const RepositoryException(
        'Choose a username of at least 3 characters.',
        isRetryable: false,
      );
    }
    if (identifier.contains(RegExp(r'\s'))) {
      throw const RepositoryException(
        'A username cannot contain spaces.',
        isRetryable: false,
      );
    }
  }

  AuthUser _userFor(String id, String identifier) => AuthUser(
        id: id,
        email: _looksLikeEmail(identifier) ? identifier : null,
        username: _looksLikeEmail(identifier) ? null : identifier,
      );

  @override
  Future<AuthUser> registerWithEmail(String email, String password) async {
    final normalised = email.toLowerCase().trim();
    _checkIdentifier(normalised);
    if (password.length < 8) {
      throw const RepositoryException(
        'Choose a password of at least 8 characters.',
        isRetryable: false,
      );
    }
    if (_store.getString(_credentialKey(normalised)) != null) {
      throw RepositoryException(
        'An account already exists for that '
        '${_looksLikeEmail(normalised) ? 'email' : 'username'}. '
        'Try signing in instead.',
        isRetryable: false,
      );
    }

    final id = 'user_${DateTime.now().microsecondsSinceEpoch}';
    await _store.setString(
      _credentialKey(normalised),
      jsonEncode({'userId': id, 'hash': _obscure(password, id)}),
    );
    final user = _userFor(id, normalised);
    await _store.setString(Collections.lastIdentifierKey, normalised);
    await _setSession(user);
    return user;
  }

  @override
  Future<AuthUser> signInWithEmail(String email, String password) async {
    final normalised = email.toLowerCase().trim();
    final raw = _store.getString(_credentialKey(normalised));
    if (raw == null) {
      throw RepositoryException(
        'No account found for that '
        '${_looksLikeEmail(normalised) ? 'email' : 'username'}.',
        isRetryable: false,
        failure: RepositoryFailure.noSuchAccount,
      );
    }
    final record = jsonDecode(raw) as Map<String, dynamic>;
    final userId = record['userId'] as String;
    if (record['hash'] != _obscure(password, userId)) {
      throw const RepositoryException(
        'That password does not match.',
        isRetryable: false,
      );
    }
    final user = _userFor(userId, normalised);
    await _store.setString(Collections.lastIdentifierKey, normalised);
    await _setSession(user);
    return user;
  }

  /// Device-local storage can verify an email and password and nothing else.
  /// Federated sign-in needs Firebase Auth, so it is not offered here.
  @override
  Set<AuthProvider> get supportedProviders =>
      const {AuthProvider.emailPassword};

  /// Nothing here sends mail, so nothing here needs an address. Demanding one
  /// would be theatre — the identifier is a key in a local store.
  @override
  AuthIdentifier get identifierKind => AuthIdentifier.emailOrUsername;

  /// Exactly: an account exists here if a credential is stored here.
  @override
  Future<bool> hasExistingAccount() async =>
      _store.hasKeyStartingWith(_credentialPrefix);

  @override
  Future<String?> lastUsedIdentifier() async =>
      _store.getString(Collections.lastIdentifierKey);

  @override
  Future<AuthUser> signInWithGoogle() => _federatedUnavailable('Google');

  @override
  Future<AuthUser> signInWithApple() => _federatedUnavailable('Apple');

  /// Federated sign-in genuinely cannot work without Firebase Auth, so it says
  /// so rather than silently creating a fake "Google" account.
  Future<AuthUser> _federatedUnavailable(String provider) async {
    throw RepositoryException(
      'Sign in with $provider needs the Firebase backend enabled. '
      'Use email and password for now.',
      isRetryable: false,
    );
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    throw const RepositoryException(
      'Password reset emails are sent by the Firebase backend, which is not '
      'enabled in this build.',
      isRetryable: false,
    );
  }

  @override
  Future<void> sendEmailVerification() async {
    throw const RepositoryException(
      'Email verification is sent by the Firebase backend, which is not '
      'enabled in this build.',
      isRetryable: false,
    );
  }

  @override
  Future<void> signOut() => _setSession(null);

  @override
  Future<void> deleteAccount() async {
    final user = _current;
    // Keyed on the identifier, not the email: a username account has no email,
    // and keying on one leaves the credential behind after "delete my account"
    // — the data gone but the login still working, which is the one outcome
    // both stores treat as a policy violation.
    if (user != null) {
      await _store.removeKey(_credentialKey(user.identifier));
    }
    // "Delete my account" has to take the name off the door as well; a
    // prefilled identifier for an account that no longer exists is exactly the
    // dead end this whole change is about.
    await _store.removeKey(Collections.lastIdentifierKey);
    await _store.clearAll();
    await _setSession(null);
  }
}

class LocalProfileRepository implements ProfileRepository {
  final LocalStore _store;
  LocalProfileRepository(this._store);

  @override
  Stream<UserProfile?> watchProfile(String userId) =>
      _store.watch(Collections.profiles).map((docs) => docs
          .map(UserProfile.fromMap)
          .where((p) => p.id == userId)
          .firstOrNull);

  @override
  Future<UserProfile?> getProfile(String userId) async {
    final doc = _store.read(Collections.profiles, userId);
    return doc == null ? null : UserProfile.fromMap(doc);
  }

  @override
  Future<void> saveProfile(UserProfile profile) =>
      _store.write(Collections.profiles, profile.id, profile.toMap());

  @override
  Future<AppPreferences> getPreferences(String userId) async {
    final raw = _store.getString('${Collections.prefsKey}:$userId');
    if (raw == null) return const AppPreferences();
    try {
      return AppPreferences.fromMap(jsonDecode(raw) as Map<String, dynamic>);
    } on FormatException {
      return const AppPreferences();
    }
  }

  @override
  Future<void> savePreferences(String userId, AppPreferences preferences) =>
      _store.setString(
        '${Collections.prefsKey}:$userId',
        jsonEncode(preferences.toMap()),
      );

  @override
  Future<NotificationPreferences> getNotificationPreferences(
      String userId) async {
    final raw = _store.getString('${Collections.notificationPrefsKey}:$userId');
    if (raw == null) return const NotificationPreferences();
    try {
      return NotificationPreferences.fromMap(
          jsonDecode(raw) as Map<String, dynamic>);
    } on FormatException {
      return const NotificationPreferences();
    }
  }

  @override
  Future<void> saveNotificationPreferences(
    String userId,
    NotificationPreferences preferences,
  ) =>
      _store.setString(
        '${Collections.notificationPrefsKey}:$userId',
        jsonEncode(preferences.toMap()),
      );
}

class LocalAccountRepository implements AccountRepository {
  final LocalStore _store;
  LocalAccountRepository(this._store);

  @override
  Stream<List<TradingAccount>> watchAccounts(String userId) =>
      _store.watch(Collections.accounts).map((docs) => docs
          .map(TradingAccount.fromMap)
          .where((a) => a.userId == userId && !a.isArchived)
          .toList());

  @override
  Future<void> saveAccount(TradingAccount account) =>
      _store.write(Collections.accounts, account.id, account.toMap());

  @override
  Future<void> archiveAccount(String accountId) async {
    final doc = _store.read(Collections.accounts, accountId);
    if (doc == null) return;
    // Archive rather than delete: historical trades reference this account,
    // and removing it would orphan their currency and equity context.
    await _store.write(
      Collections.accounts,
      accountId,
      {...doc, 'isArchived': true},
    );
  }
}

class LocalStrategyRepository implements StrategyRepository {
  final LocalStore _store;
  LocalStrategyRepository(this._store);

  @override
  Stream<List<Strategy>> watchStrategies(String userId) =>
      _store.watch(Collections.strategies).map((docs) => docs
          .map(Strategy.fromMap)
          .where((s) => s.userId == userId && !s.isArchived)
          .toList());

  @override
  Future<void> saveStrategy(Strategy strategy) =>
      _store.write(Collections.strategies, strategy.id, strategy.toMap());

  @override
  Future<void> deleteStrategy(String strategyId) async {
    final doc = _store.read(Collections.strategies, strategyId);
    if (doc == null) return;
    // Same reasoning as accounts: trades point at this strategy.
    await _store.write(
      Collections.strategies,
      strategyId,
      {...doc, 'isArchived': true},
    );
  }
}

class LocalChecklistRepository implements ChecklistRepository {
  final LocalStore _store;
  LocalChecklistRepository(this._store);

  @override
  Stream<List<ChecklistItem>> watchChecklist(String userId) =>
      _store.watch(Collections.checklist).map((docs) {
        final items = docs
            .map(ChecklistItem.fromMap)
            .where((i) => i.userId == userId)
            .toList()
          ..sort((a, b) => a.position.compareTo(b.position));
        return items;
      });

  @override
  Future<void> saveChecklistItem(ChecklistItem item) =>
      _store.write(Collections.checklist, item.id, item.toMap());

  @override
  Future<void> deleteChecklistItem(String itemId) =>
      _store.delete(Collections.checklist, itemId);

  @override
  Future<void> reorderChecklist(List<String> orderedIds) async {
    for (var i = 0; i < orderedIds.length; i++) {
      final doc = _store.read(Collections.checklist, orderedIds[i]);
      if (doc == null) continue;
      await _store
          .write(Collections.checklist, orderedIds[i], {...doc, 'position': i});
    }
  }
}

class LocalRuleRepository implements RuleRepository {
  final LocalStore _store;
  LocalRuleRepository(this._store);

  @override
  Stream<List<Rule>> watchRules(String userId) =>
      _store.watch(Collections.rules).map((docs) {
        final rules = docs
            .map(Rule.fromMap)
            .where((r) => r.userId == userId)
            .toList()
          ..sort((a, b) => a.position.compareTo(b.position));
        return rules;
      });

  @override
  Future<List<Rule>> getRules(String userId) async => _store
      .readAll(Collections.rules)
      .map(Rule.fromMap)
      .where((r) => r.userId == userId)
      .toList()
    ..sort((a, b) => a.position.compareTo(b.position));

  @override
  Future<void> createRule(Rule rule) =>
      _store.write(Collections.rules, rule.id, rule.toMap());

  @override
  Future<void> publishRuleVersion(
    String ruleId,
    RuleVersion newVersion,
    DateTime effectiveFromUtc,
  ) async {
    final doc = _store.read(Collections.rules, ruleId);
    if (doc == null) {
      throw const RepositoryException('That rule no longer exists.');
    }
    final existing = Rule.fromMap(doc);

    // Close the outgoing version at the instant the new one takes effect, so
    // every point in time maps to exactly one version — no gaps, no overlap.
    final retired = RuleVersion(
      id: existing.current.id,
      ruleId: existing.current.ruleId,
      version: existing.current.version,
      name: existing.current.name,
      description: existing.current.description,
      category: existing.current.category,
      severity: existing.current.severity,
      measure: existing.current.measure,
      threshold: existing.current.threshold,
      weekdays: existing.current.weekdays,
      sessions: existing.current.sessions,
      strategyIds: existing.current.strategyIds,
      assetClasses: existing.current.assetClasses,
      weight: existing.current.weight,
      effectiveFromUtc: existing.current.effectiveFromUtc,
      effectiveToUtc: effectiveFromUtc,
    );

    final updated = Rule(
      id: existing.id,
      userId: existing.userId,
      current: newVersion,
      history: [retired, ...existing.history],
      isActive: existing.isActive,
      position: existing.position,
    );
    await _store.write(Collections.rules, ruleId, updated.toMap());
  }

  @override
  Future<void> setRuleActive(String ruleId, bool isActive) async {
    final doc = _store.read(Collections.rules, ruleId);
    if (doc == null) return;
    await _store
        .write(Collections.rules, ruleId, {...doc, 'isActive': isActive});
  }

  @override
  Future<void> deleteRule(String ruleId) =>
      _store.delete(Collections.rules, ruleId);

  @override
  Future<void> reorderRules(List<String> orderedIds) async {
    for (var i = 0; i < orderedIds.length; i++) {
      final doc = _store.read(Collections.rules, orderedIds[i]);
      if (doc == null) continue;
      await _store
          .write(Collections.rules, orderedIds[i], {...doc, 'position': i});
    }
  }
}

class LocalTradeRepository implements TradeRepository {
  final LocalStore _store;
  LocalTradeRepository(this._store);

  @override
  Stream<List<Trade>> watchTradesForDay(String userId, String dayKey) =>
      _store.watch(Collections.trades).map((docs) {
        final trades = docs
            .map(Trade.fromMap)
            .where((t) => t.userId == userId && t.tradingDayKey == dayKey)
            .toList()
          ..sort((a, b) => a.openedAtUtc.compareTo(b.openedAtUtc));
        return trades;
      });

  @override
  Stream<List<Trade>> watchTradesInRange(
    String userId, {
    required String fromDayKey,
    required String toDayKey,
    String? accountId,
  }) =>
      _store.watch(Collections.trades).map((docs) {
        // Day keys are `yyyy-MM-dd`, so lexicographic comparison is
        // chronological — the same property the Firestore range query relies on.
        final trades = docs
            .map(Trade.fromMap)
            .where((t) =>
                t.userId == userId &&
                t.tradingDayKey.compareTo(fromDayKey) >= 0 &&
                t.tradingDayKey.compareTo(toDayKey) <= 0 &&
                (accountId == null || t.accountId == accountId))
            .toList()
          ..sort((a, b) => a.openedAtUtc.compareTo(b.openedAtUtc));
        return trades;
      });

  @override
  Future<Trade?> getTrade(String tradeId) async {
    final doc = _store.read(Collections.trades, tradeId);
    return doc == null ? null : Trade.fromMap(doc);
  }

  @override
  Future<void> saveTrade(Trade trade) =>
      _store.write(Collections.trades, trade.id, trade.toMap());

  @override
  Future<void> deleteTrade(String tradeId) =>
      _store.delete(Collections.trades, tradeId);

  /// Local writes commit synchronously, so nothing is ever pending.
  @override
  Stream<int> watchPendingWriteCount() => Stream.value(0);
}

class LocalReviewRepository implements ReviewRepository {
  final LocalStore _store;
  LocalReviewRepository(this._store);

  @override
  Stream<DailyReview?> watchDailyReview(String userId, String dayKey) =>
      _store.watch(Collections.reviews).map((docs) => docs
          .map(DailyReview.fromMap)
          .where((r) => r.userId == userId && r.dayKey == dayKey)
          .firstOrNull);

  @override
  Future<void> saveDailyReview(DailyReview review) =>
      _store.write(Collections.reviews, review.id, review.toMap());

  @override
  Stream<List<DailyReview>> watchReviewsInRange(
    String userId, {
    required String fromDayKey,
    required String toDayKey,
  }) =>
      _store.watch(Collections.reviews).map((docs) => docs
          .map(DailyReview.fromMap)
          .where((r) =>
              r.userId == userId &&
              r.dayKey.compareTo(fromDayKey) >= 0 &&
              r.dayKey.compareTo(toDayKey) <= 0)
          .toList());
}

class LocalPsychologyRepository implements PsychologyRepository {
  final LocalStore _store;
  LocalPsychologyRepository(this._store);

  @override
  Stream<List<PsychologyEntry>> watchEntriesForDay(
          String userId, String dayKey) =>
      _store.watch(Collections.psychology).map((docs) => docs
          .map(PsychologyEntry.fromMap)
          .where((e) => e.userId == userId && e.dayKey == dayKey)
          .toList());

  @override
  Future<void> saveEntry(PsychologyEntry entry) =>
      _store.write(Collections.psychology, entry.id, entry.toMap());

  @override
  Stream<List<BehaviourWatch>> watchBehaviourWatches(String userId) =>
      _store.watch(Collections.behaviourWatches).map((docs) => docs
          .map(BehaviourWatch.fromMap)
          .where((w) => w.userId == userId)
          .toList());

  @override
  Future<void> saveBehaviourWatch(BehaviourWatch watch) =>
      _store.write(Collections.behaviourWatches, watch.id, watch.toMap());

  @override
  Future<void> deleteBehaviourWatch(String id) =>
      _store.delete(Collections.behaviourWatches, id);
}

class LocalDisciplineRepository implements DisciplineRepository {
  final LocalStore _store;
  LocalDisciplineRepository(this._store);

  String _id(String userId, String dayKey) => '${userId}_$dayKey';

  @override
  Stream<List<DailyDisciplineRecord>> watchHistory(
    String userId, {
    required String fromDayKey,
    required String toDayKey,
  }) =>
      _store.watch(Collections.disciplineRecords).map((docs) => docs
          .where((d) =>
              d['userId'] == userId &&
              '${d['dayKey']}'.compareTo(fromDayKey) >= 0 &&
              '${d['dayKey']}'.compareTo(toDayKey) <= 0)
          .map(_recordFromMap)
          .toList());

  @override
  Future<void> upsertDailyRecord(String userId, DailyDisciplineRecord record) =>
      _store.write(
        Collections.disciplineRecords,
        _id(userId, record.dayKey),
        {
          'userId': userId,
          'dayKey': record.dayKey,
          'score': record.score?.toString(),
          'hadMajorViolation': record.hadMajorViolation,
          'violationCount': record.violationCount,
          'tradeCount': record.tradeCount,
          'evaluations':
              record.evaluations.map((e) => e.toMap()).toList(growable: false),
        },
      );

  static DailyDisciplineRecord _recordFromMap(Map<String, dynamic> map) =>
      DailyDisciplineRecord(
        dayKey: map['dayKey'] as String? ?? '',
        score: map['score'] == null ? null : Dec.tryParse('${map['score']}'),
        hadMajorViolation: map['hadMajorViolation'] as bool? ?? false,
        violationCount: (map['violationCount'] as num?)?.toInt() ?? 0,
        tradeCount: (map['tradeCount'] as num?)?.toInt() ?? 0,
        evaluations: ((map['evaluations'] as List?) ?? const [])
            .whereType<Map<Object?, Object?>>()
            .map((e) => RuleEvaluation.fromMap(e.cast<String, dynamic>()))
            .toList(growable: false),
      );
}

/// Stores attachment bytes as data URIs in the local store.
///
/// Fine for the handful of chart screenshots a local build accumulates;
/// Firebase Storage replaces it for real use, where images are large and must
/// not sit inside preference storage.
class LocalAttachmentRepository implements AttachmentRepository {
  final LocalStore _store;
  LocalAttachmentRepository(this._store);

  @override
  Future<String> upload(
    String userId,
    List<int> bytes, {
    required String filename,
    required String contentType,
    void Function(double progress)? onProgress,
  }) async {
    final id = 'att_${DateTime.now().microsecondsSinceEpoch}';
    onProgress?.call(0.5);
    await _store.write(Collections.attachments, id, {
      'id': id,
      'userId': userId,
      'filename': filename,
      'contentType': contentType,
      'dataUri': 'data:$contentType;base64,${base64Encode(bytes)}',
      'createdAtUtc': DateTime.now().toUtc().toIso8601String(),
    });
    onProgress?.call(1);
    return id;
  }

  @override
  Future<Uri?> resolveUrl(String attachmentId) async {
    final doc = _store.read(Collections.attachments, attachmentId);
    final uri = doc?['dataUri'] as String?;
    return uri == null ? null : Uri.parse(uri);
  }

  @override
  Future<void> delete(String attachmentId) =>
      _store.delete(Collections.attachments, attachmentId);
}

/// No AI narrative without the backend.
///
/// Returns `null` rather than a canned sentence, which routes the caller to
/// the deterministic [InsightEngine] — real coaching, just not AI-written.
class UnavailableCoachingRepository implements CoachingRepository {
  const UnavailableCoachingRepository();

  @override
  Future<String?> narrateDay(CoachingFacts facts) async => null;
}

# Enabling the Firebase backend

The app ships running on device-local persistence. Everything works, but data
lives on one device and the discipline score is computed by the client.

This document turns that into a production backend: multi-device sync,
server-authoritative scoring, screenshot storage and push notifications.

**Why it is not already wired up.** `flutterfire configure` generates
`lib/firebase_options.dart` and the platform config files from a *real* Firebase
project. Committing placeholders would produce a build that compiles and then
crashes on launch — worse than one that is honestly not connected yet. Every
seam is in place; this is the last mile.

---

## 1. Create the projects

Three environments, fully separate (brief §29):

```bash
firebase projects:create prayan-dev
firebase projects:create prayan-staging
firebase projects:create prayan-prod
```

Enable in each: **Authentication**, **Firestore** (Native mode, region close to
your users — `asia-south1` for India), **Storage**, **Cloud Messaging**,
**Crashlytics**, **Performance Monitoring**.

Under Authentication → Sign-in method, enable **Email/Password**, **Google**,
and **Apple** (Apple is mandatory if Google ships — App Store review §4.8).

## 2. Register the apps

Bundle / package IDs:

| Environment | ID |
|---|---|
| dev | `com.prayan.tradingjournal.dev` |
| staging | `com.prayan.tradingjournal.staging` |
| production | `com.prayan.tradingjournal` |

## 3. Generate the config

```bash
dart pub global activate flutterfire_cli
flutterfire configure --project=prayan-dev
```

This writes `lib/firebase_options.dart`,
`android/app/google-services.json` and `ios/Runner/GoogleService-Info.plist`.

> **Add the two platform files to `.gitignore`.** They are per-environment and
> should be injected by CI, not committed.

## 4. Add the dependencies

```yaml
dependencies:
  firebase_core: ^3.8.0
  firebase_auth: ^5.3.3
  cloud_firestore: ^5.5.0
  firebase_storage: ^12.3.6
  firebase_messaging: ^15.1.5
  firebase_crashlytics: ^4.1.5
  google_sign_in: ^6.2.2
  sign_in_with_apple: ^6.1.3
```

> Verify the latest stable versions on pub.dev before pinning. The versions
> above were current when this was written and will drift.

## 5. Deploy rules and indexes

```bash
firebase deploy --only firestore:rules,firestore:indexes,storage --project prayan-dev
```

These are already written and complete:
`firebase/firestore.rules`, `firebase/firestore.indexes.json`,
`firebase/storage.rules`.

Read `firestore.rules` before deploying. It enforces three things: per-user
isolation, immutable rule history, and **`allow write: if false` on every score
document** — the datastore-level guarantee that a client cannot fabricate a
discipline score.

## 6. Implement the Firestore repositories

Create `lib/data/firestore/` implementing the interfaces in
`lib/domain/repositories.dart`. Each is mechanical, because the document shapes
are already the `toMap()`/`fromMap()` output the local store uses — the two
stores hold byte-identical documents.

```dart
class FirestoreTradeRepository implements TradeRepository {
  final FirebaseFirestore _db;
  FirestoreTradeRepository(this._db);

  CollectionReference<Map<String, dynamic>> _trades(String uid) =>
      _db.collection('users').doc(uid).collection('trades');

  @override
  Stream<List<Trade>> watchTradesForDay(String userId, String dayKey) =>
      _trades(userId)
          .where('tradingDayKey', isEqualTo: dayKey)
          .orderBy('openedAtUtc')
          .snapshots()
          .map((s) => s.docs.map((d) => Trade.fromMap(d.data())).toList());

  @override
  Future<void> saveTrade(Trade trade) =>
      // set() with the trade's own id is idempotent, so a retried offline
      // write cannot create a duplicate trade (brief §19).
      _trades(trade.userId).doc(trade.id).set(trade.toMap());

  @override
  Stream<int> watchPendingWriteCount() => _db
      .snapshotsInSync()
      .map((_) => 0); // replace with a real pending-write counter
}
```

Two things to get right:

**Offline persistence is the offline story.** Firestore's local cache *is* the
queue — enable it and writes survive a dead connection automatically:

```dart
FirebaseFirestore.instance.settings = const Settings(
  persistenceEnabled: true,
  cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
);
```

**Translate errors at the repository boundary.** No screen should ever have to
decide what `PERMISSION_DENIED` looks like in English:

```dart
} on FirebaseException catch (e) {
  throw RepositoryException(
    switch (e.code) {
      'permission-denied' => 'You do not have access to that.',
      'unavailable' => 'No connection. Your entry is saved on this device.',
      _ => 'Something went wrong. Your journal is safe.',
    },
    cause: e,
  );
}
```

## 7. Flip the overrides

`lib/app/bootstrap.dart` is the **only** file that names a concrete repository.
Swap the right-hand sides:

```dart
await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
);
final db = FirebaseFirestore.instance
  ..settings = const Settings(persistenceEnabled: true);

return [
  authRepositoryProvider.overrideWithValue(
    FirebaseAuthRepository(FirebaseAuth.instance),
  ),
  tradeRepositoryProvider.overrideWithValue(FirestoreTradeRepository(db)),
  // ...and so on for each repository.
];
```

No feature file changes. That is what the interfaces were for.

## 8. Deploy the backend

Server-authoritative scoring and the AI coaching service live in the companion
repository **Shiva-PrayanAI**. See its README.

The Cloud Function mirrors `prayan_core`'s scoring logic and writes
`dailySummaries`. Until it is deployed, `dailySummaries` will be empty and the
app falls back to computing the score on device — correct, but not the
production trust model.

## 9. Verify

```bash
firebase emulators:start --only firestore,auth
flutter test integration_test/
```

Checklist:

- [ ] A second device sees the same journal
- [ ] Airplane mode → log a trade → reconnect → it syncs, exactly once
- [ ] A client attempt to write `dailySummaries` is **rejected**
- [ ] Signing in as user B cannot read user A's trades
- [ ] Deleting the account removes documents, not just the login
- [ ] Screenshot upload shows real progress and survives a retry

---

## Cost note

Firestore bills per document read. The two things that matter:

1. **Never read a trade to display a score.** Read `dailySummaries` — one
   document per day instead of N trades.
2. **Bound every range query.** The app already caps discipline history at 120
   days, which covers the 90-day rolling window with margin.

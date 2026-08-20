# Building with your account already on it

Accounts in Prayan live on the device and nowhere else. There is no server, so
a new phone, a new browser or a reinstall is a machine that has never heard of
you and asks you to sign up again. That is correct for the privacy model and
tiring if the person using it is you.

A build can be compiled to already know one account. Do this for **your own**
builds. It is not what goes to the App Store or to Play.

## Make the hash

```bash
dart run tool/seed_hash.dart
```

It asks for a password, does not echo it, and prints a short value. Nothing is
written anywhere.

## Build with it

```bash
flutter build appbundle --release \
  --dart-define=PRAYAN_SEED_IDENTIFIER=you@example.com \
  --dart-define=PRAYAN_SEED_HASH=<the printed value>
```

The same two defines work for `flutter build apk`, `ios` and `web`.

Every install of that build opens straight into the journal. Sign out and the
sign-in screen behaves normally — your password gets you back in, and the app
remembers that you meant to sign out rather than signing you back in on the
next launch.

## What this does not do

**It is not sync.** Two devices built this way share a login and nothing else.
Each keeps its own journal, because each has its own storage. Two phones will
not show the same trades. That needs the Firebase backend —
`docs/FIREBASE_SETUP.md`.

## What to know before you use it

The hash is compiled into the app. Anyone who gets the APK or the web bundle
can read it, and the scrambling it uses is deliberately **not** a real password
hash — `local_repositories.dart` says so in as many words, because the
production answer is Firebase Authentication, which never sees the password at
all.

So: **use a password you do not use anywhere else.** Not your email password,
not your broker's. Treat this one as belonging to this app and nothing more.

Never commit either value. Neither is in this repository and neither should be:
a credential in version control is a credential everyone with repository access
has.

## Shipping without it

A build with neither define behaves exactly as it always did — no seeded
account, ordinary sign-up. `test/seeded_account_test.dart` asserts that, because
that is the configuration that reaches the stores, and "the feature is off by
default" is worth more than a comment saying so.

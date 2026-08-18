# Getting Prayan onto your phone

Three ways, in increasing order of how much they cost you. The first works in
about a minute and needs nothing. The third is the App Store and Play Store,
and it needs the developer accounts.

Read the short version first: **today, on Android, you can install the real
app. On iPhone you cannot** — and that is Apple's rule, not a gap in this
repository. The browser build below is the iPhone answer until an Apple
Developer account exists.

---

## 1. In the browser — both phones, right now

The app is built for the web from the same source as the phone apps. Open the
link on your phone and it runs: the real screens, the real scoring engine, real
data saved in the browser.

- Nothing to install, no account, no store.
- **iPhone**: open in Safari, then Share → *Add to Home Screen*. It gets an
  icon and opens full-screen without the browser chrome.
- **Android**: Chrome offers *Install app* in the ⋮ menu, same effect.

What it will not show you: how the app feels with native scroll physics, how
the keyboard behaves over the trade form, or how it handles a real notch. Those
are the reasons the device pass is still an open item on the release checklist.

## 2. A real Android install — today, no Google account

CI builds an installable APK on every push. It is the actual release build:
R8-shrunk, release-signed, identical code to what would go to Play.

1. Open the repository's **Actions** tab on GitHub.
2. Click the most recent **Build** run on `claude/mobile-app-creation-tkly3l`.
3. Scroll to **Artifacts** and download **`prayan-sideload-apk`**.
4. Unzip it — GitHub always wraps artifacts in a zip — and move
   `app-release.apk` to your phone.
5. Tap it. Android will ask once whether to allow installs from wherever you
   opened it (Files, Chrome, Drive); allow it for that app.

Two things to know:

- **This APK can never go to Play.** It is signed with a key CI generates and
  destroys in the same run. Play binds an app permanently to the first key it
  sees, so uploading this one would burn the identity with a key nobody holds.
  The `android` job builds the Play bundle separately and refuses to sign it
  with anything but a real upload key, precisely so the two cannot be mixed up.
- **A newer build will not install over an older one.** Different run,
  different key, and Android rejects a signature change on an existing app.
  Uninstall Prayan first, then install. Your journal is on the device, so
  export from Settings first if you want to keep it.

## 3. iPhone — what it actually takes

There is no equivalent of step 2 on iOS. Apple has no sideloading path that
does not run through an Apple ID with a developer relationship:

| Route | What it needs | How long the app lasts |
|---|---|---|
| TestFlight | Apple Developer account ($99/yr) | 90 days per build |
| Ad-hoc distribution | Same account, plus the phone's UDID registered | 1 year |
| Free personal team via Xcode | A Mac, a cable, an Apple ID | **7 days**, then it stops opening |

The last one is free but needs a Mac with Xcode and the phone plugged into it,
and the app dies after a week. CI already proves the iOS build compiles and
links on macOS — `flutter build ios --release --no-codesign` — so the moment an
Apple Developer account exists, the remaining work is certificates, not code.

Until then: option 1, added to the home screen.

---

## Signing in

There is no server. Accounts are created and stored on the device, so you
choose the credentials at the moment you create them.

On the first screen tap **Create a new account**, then use any username or
email address and any password of **8 characters or more**. A username needs
three characters and no spaces; an email address has to look like one. Nothing
is sent anywhere and nothing checks that an address is real — which is exactly
why a username is allowed: this build has no server to mail you.

If you would rather use the same credentials as the App Review notes:

```
Email:    review@prayan.app
Password: ReviewPrayan1
```

Because the account lives on the device, these do not carry across from your
phone to the browser build, or from one install to the next. Creating the
account again is the way back in — there is no password reset, because there is
nobody to reset it with.

One thing worth knowing before you choose: the password is kept on the device
behind a scrambling step that is deliberately **not** a real password hash —
`local_repositories.dart` says so in as many words, because the production
answer is Firebase Authentication, which never sees the password at all. Until
that is wired up, use a password you do not use anywhere else.

## Seeing the app with something in it

Onboarding is twelve short steps and most of them accept **Skip for now**. Two
choices matter:

- Pick the **Balanced** rule set when it offers one. It is what the sample
  trades are scored against.
- On the **last** step, switch on **Load the sample journal**. It writes three
  example trades dated to the most recent finished session.

Then the route that shows what the product argues:

1. **Home** — the discipline score, and the sentence explaining how it got
   there.
2. **Tap the score ring** — the breakdown, category by category, with the
   weight each carried.
3. **Journal → TATAMOTORS** — made money, scored 56.
4. **Journal → RELIANCE** — lost money, scored 100.

Steps 3 and 4 are the point. Everything else is bookkeeping around them.

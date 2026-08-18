# Release checklist

> **Approval is never guaranteed.** Financial-adjacent apps draw extra scrutiny.
> Verify every policy point against *current* Apple and Google policy at
> submission time, not against this document.

Status is honest: `[x]` means done and verified in this repository, `[ ]` means
it is not.

---

## What still blocks a submission

These are the things that would stop an upload or draw a rejection today. None
of them can be closed from inside this repository — each needs an account, a
machine, or a decision that is yours.

| Blocker | Why it blocks | What closes it |
|---|---|---|
| **No Apple Developer / Play Console account wired up** | Nothing can be uploaded without one | Enrol (Apple $99/yr, Play $25 one-off), create the app records |
| **No signed iOS build** | An IPA can only be built on macOS with Xcode. CI now compiles the iOS app unsigned on every push, which proves it builds; signing it needs the Apple account | Enrol, then add the certificate secrets listed in `.github/workflows/build.yml` |
| **No Android upload key** | Release builds are unsigned until `android/key.properties` exists — deliberately, so a debug-signed bundle can never reach Play | `keytool -genkey` per `android/key.properties.example` |
| **The app has never run on a physical device** | Every test so far is a unit, widget or browser test. Touch targets, keyboard behaviour, scroll physics and text input are unverified on real hardware | An hour with one iPhone and one Android phone |
| **Privacy policy and terms not yet hosted** | Both stores require a reachable URL. The documents are written — `store/legal/` — but a URL is needed | Publish `store/legal/*.md`, fill in the bracketed entity name and jurisdiction |
| ~~No store screenshots~~ | Done — `store/screenshots/`, three device classes | — |
| **Firebase is not connected** | The app works fully on device-local storage, but there is no sync, no account recovery and no server-authoritative scoring | `docs/FIREBASE_SETUP.md`, then the backend in `Shiva-PrayanAI` |

**Realistic timeline.** Apple review is typically 24–48 hours *after* a build
uploads cleanly, and first submissions are frequently rejected for metadata
before a human sees the app. Play's first review of a new account can take
several days. Same-day publication is not achievable from this starting point.

---

## Identifiers and signing

- [x] Android `applicationId` — `com.prayan.prayan_trading_journal`
- [x] iOS bundle id — `com.prayan.prayanTradingJournal`
- [x] Release signing reads `android/key.properties`; **no debug-key fallback**
- [x] `android/key.properties` and `*.jks` are gitignored
- [x] Version set to `1.0.0+1`
- [ ] Play App Signing enabled; upload key backed up offline
- [ ] iOS distribution certificate and provisioning profiles

> The upload key is the one secret you cannot regenerate yourself. Losing it
> means asking Google to reset it before you can ship another update.

## Assets

- [x] Launcher icons at every density, both platforms, generated from the app's
      own mark — `dart run tool/generate_launcher_icons.dart`
- [x] Android adaptive icon: foreground, background colour and monochrome layers
- [x] iOS 1024 marketing icon has **no alpha channel** (asserted in
      `test/brand_mark_test.dart`)
- [x] Play listing icon, 512×512 — `store/play/icon-512.png`
- [x] Screenshots: iPhone 6.9" (1320×2868), 6.5" (1290×2796), Play phone
      (1080×1920) — 10 each, in `store/screenshots/`
- [x] Feature graphic (Play, 1024×500) — `store/play/feature-graphic-1024x500.png`
- [ ] iPad screenshots, if you ship an iPad build (submit iPhone-only to skip)

Lead the screenshots with the **discipline score and the audit trail**, not a
P&L curve. That is what the product is, and it is what reads as credible under
review.

## App completeness — guideline 2.1

Apple rejects apps with UI that does not work. The two that mattered here:

- [x] **No dead sign-in buttons.** `AuthRepository.supportedProviders` declares
      what a backend can actually complete, and the sign-in screen renders only
      those. On the local build that is email alone, so the Google and Apple
      buttons are absent rather than present-and-broken. Asserted in
      `test/auth_providers_test.dart`.
- [x] Account deletion is reachable in-app and removes data rather than
      disabling the login — required by both stores.
- [x] App Review notes written, with demo credentials and a walkthrough that
      puts the reviewer in front of the scoring in four taps — `store/LISTING.md`

> If Google or Apple sign-in is enabled later, Apple requires Sign in with Apple
> alongside any other third-party login (guideline 4.8).

## Privacy and policy

- [x] No brokerage credentials are collected anywhere in the app
- [x] Analytics is opt-in and off by default; it carries no symbols, prices or
      sizes
- [x] AI coaching is opt-in; it sends computed summary figures only
- [x] `ITSAppUsesNonExemptEncryption` declared `false` (HTTPS only, exempt)
- [x] Privacy policy and terms written — `store/legal/`
- [x] Play **Data safety** answers prepared — `store/LISTING.md`
- [x] Apple **privacy nutrition label** answers prepared — `store/LISTING.md`
- [x] Age rating answers prepared (expect 4+ / Everyone)
- [ ] Policy documents published at stable URLs
- [ ] Console forms actually submitted

## Financial-app positioning

The single largest rejection risk for this category is reading as investment
advice. The app is built not to be, and the listing has to match:

- [x] No price predictions, signals, guarantees or return claims in the product
- [x] The app cannot place orders or connect to a broker
- [x] Coaching output is guarded against predictions and trade instructions
      (`Shiva-PrayanAI/src/coaching/guard.ts`)
- [x] Store description written to that standard — `store/LISTING.md`
- [x] Disclaimer in the description: not financial advice, no returns predicted

## Build and verify

```bash
flutter analyze                                   # 0 issues
flutter test                                      # 60 widget/accessibility tests
cd packages/prayan_core && dart test              # 157 domain tests
dart run tool/generate_launcher_icons.dart        # regenerate icons

flutter build appbundle --release                 # needs android/key.properties
flutter build ipa --release                       # needs macOS + Xcode
```

- [x] Analyzer clean
- [x] 217 tests passing across the app and domain package
- [x] Release shrinking enabled (`isMinifyEnabled`, `isShrinkResources`)
- [x] CI builds the Android bundle and compiles the iOS app on every push —
      `.github/workflows/build.yml`. Neither can run on a Linux workstation,
      so before this nothing had ever been built for a phone.
- [ ] `flutter build appbundle` signed with a real upload key
- [ ] `flutter build ipa` with a distribution certificate
- [ ] Tested on a physical iPhone and a physical Android device
- [ ] Tested at largest dynamic-type setting and with a screen reader on device

## Submission

- [ ] TestFlight internal build installs and runs
- [ ] Play internal testing track build installs and runs
- [ ] App Review notes: demo account, what the app does, what it deliberately
      does not do
- [ ] Staged rollout on Play (start at 20%)

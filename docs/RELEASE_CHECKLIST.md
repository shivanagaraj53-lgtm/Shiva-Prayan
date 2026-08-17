# Release checklist

> **Approval is never guaranteed.** Financial-adjacent apps draw extra scrutiny.
> Every policy point below must be verified against *current* Apple and Google
> policy at submission time, not against this document.

## Identifiers and signing

- [ ] `com.prayan.tradingjournal` (+ `.dev`, `.staging`)
- [ ] Play App Signing enabled; upload key backed up offline
- [ ] iOS distribution certificate and provisioning profiles
- [ ] Version in `pubspec.yaml`; build number injected by CI

## Assets

- [ ] App icon at every required density, both platforms
- [ ] Adaptive icon (Android): separate foreground and background layers
- [ ] Splash configured for light and dark
- [ ] Screenshots: 6.7" and 6.1" iPhone, 12.9" iPad, Android phone and tablet
- [ ] Feature graphic (Play, 1024×500)

Screenshots should lead with the **discipline score and the audit trail**, not a
P&L curve. It is what the product is, and it is what will read as credible under
review.

## Privacy and policy

- [ ] Privacy policy and terms published at stable URLs
- [ ] Play **Data safety** form completed
- [ ] Apple **privacy nutrition label** completed
- [ ] Declare: journal content (user-generated), optional analytics.
      Declare **no** financial-account linkage — Prayan never connects to a broker
- [ ] Analytics consent default **off**, honoured
- [ ] **In-app account deletion** — required by both stores; implemented
- [ ] Account deletion removes data, not just the login
- [ ] **Sign in with Apple** offered — mandatory if Google sign-in ships (§4.8)
- [ ] Age rating: likely 17+ / Mature for financial content — **verify**
- [ ] "Not financial advice" disclaimer visible in-app, in the listing, and in
      any coaching output

### Areas most likely to draw questions

1. **Age rating and financial content.** Prayan gives no advice and places no
   trades; be ready to say so in review notes.
2. **Apple §3.1.1** if subscriptions are ever added — entitlement logic is
   abstracted for StoreKit / Play Billing, and must not route around them.
3. **Data-safety accuracy.** Journal content is sensitive; declare it honestly.
4. **AI coaching.** If enabled, disclose that computed summaries are sent to a
   third-party model — no trades, prices or balances ever are.

## Build and release

- [ ] Separate dev / staging / prod Firebase projects
- [ ] No secrets in the app bundle (`grep -ri "api[_-]key" lib/` is clean)
- [ ] Firestore rules and indexes deployed to production
- [ ] Crashlytics and Performance verified reporting
- [ ] `flutter build appbundle --release` / `flutter build ipa --release`
- [ ] Release build tested on a physical device of each platform
- [ ] R8/ProGuard does not break Firebase or reflection

## Testing gates

- [ ] TestFlight internal → external
- [ ] Play internal testing → closed track
- [ ] Crash-free sessions **≥ 99.5%** before widening rollout
- [ ] Staged rollout 5% → 20% → 50% → 100%, Crashlytics-gated at each step

## Monitoring and rollback

- [ ] Crashlytics alerting on a new-issue spike
- [ ] Performance traces on app start and trade save
- [ ] Play staged rollout can be **halted**; iOS phased release can be **paused**
- [ ] A previous build is retained and ready to re-promote
- [ ] Firestore rules changes deployed separately from the app, so a rules
      rollback does not need a store review

## Post-launch

- [ ] Watch first-session completion of onboarding
- [ ] Watch time-to-first-trade-logged — the 20–30s target is the product promise
- [ ] Watch daily-review completion; low numbers mean the prompts are wrong
- [ ] Read reviews for confusion about the score. If users cannot explain their
      own number, the audit trail has failed and that is a P1.

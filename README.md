# Prayan Trading Journal

**Plan the trade. Follow the rules. Measure the discipline. Improve the process.**

A mobile trading journal for iOS and Android whose primary output is not profit
and loss, but an explainable 0–100 **Discipline Score** measuring how closely
you followed rules you set for yourself.

A losing trade that respected every rule scores **100**.
A profitable trade that broke a major rule is capped at **60**.

That inversion is structural, not a convention: the scorer receives only rule
evaluations and has no access to P&L, so it is incapable of rewarding a
profitable rule-break.

---

## Status

| | |
|---|---|
| **Tests** | 201 passing (157 domain + 44 widget/accessibility) |
| **Analyzer** | 0 issues, both packages |
| **Flutter** | 3.47.0 · **Dart** 3.13.0 |
| **Backend** | Local-first today; Firebase is an additive swap — see [docs/FIREBASE_SETUP.md](docs/FIREBASE_SETUP.md) |

---

## Quick start

```bash
flutter pub get
flutter run                 # runs on device-local persistence, no backend needed

# Verification
flutter analyze                                    # app
flutter test                                       # 44 widget tests
cd packages/prayan_core && dart test               # 157 domain tests
```

The app is fully usable out of the box: sign up with an email and password, work
through onboarding, and log trades. Everything persists on the device. Enabling
Firebase adds multi-device sync and server-authoritative scoring without
touching a single feature file.

---

## Architecture

```
lib/features/    →  lib/state/  →  lib/domain/  →  packages/prayan_core/
   screens          Riverpod       interfaces        the actual maths
                                        ↓
                                   lib/data/local/   (or lib/data/firestore/)
```

**`packages/prayan_core` is the whole point.** It is pure Dart — no Flutter, no
Firebase, no `dart:io` — and it owns every authoritative number the product
produces: money arithmetic, trade metrics, rule evaluation, the discipline
score, streaks and the deterministic coaching layer.

Because it is pure Dart it runs on the plain VM (fast tests), is mirrored by the
Cloud Functions backend (so the server can recompute what the client claims),
and can be reused by a future web client without touching mobile UI.

No UI widget performs a business calculation anywhere in this codebase.

### Notable engineering decisions

**Money never touches `double`.** `Dec` is a BigInt-backed fixed-point type.
`0.1 + 0.2 == 0.3` exactly, and 1,000 accumulated fractional values drift by
zero — both asserted in tests. IEEE-754 would produce a P&L the user cannot
reconcile against their broker statement.

**Undeterminable metrics are `null`, never `0`.** A trade with no stop has
`plannedRisk == null` and `realisedR == null`. Zero risk would make R infinite
and silently poison every downstream aggregate. The UI renders `—`.

**Rules are versioned.** Editing a rule closes the live version and opens a new
one; it never mutates. A trade from March is always judged against March's
thresholds, so tightening a limit today cannot retroactively turn a compliant
month into a violation-riddled one.

**Colour is never the only signal.** Positive and negative deliberately share
luminance to keep the palette calm — so meaning is carried by explicit `+`/`−`
signs, filled-vs-hollow shapes, text legends and semantic labels.
`test/result_semantics_test.dart` asserts this; `test/theme_contrast_test.dart`
asserts WCAG AA across all four themes.

---

## Repository layout

```
packages/prayan_core/     pure-Dart domain engine (157 tests)
lib/app/                  bootstrap, router, shell
lib/design/               tokens, palette, typography, 23 components
lib/domain/               models, repository interfaces, DaySnapshot use case
lib/data/local/           device-local persistence
lib/state/                Riverpod providers
lib/features/             13 feature folders, 25 screens
firebase/                 firestore.rules, indexes, storage.rules
docs/                     blueprint, data model, design system, setup, release
```

---

## Documentation

| Document | Contents |
|---|---|
| **[BLUEPRINT.md](docs/BLUEPRINT.md)** | The full product blueprint: architecture diagram, schema, security model, rules spec, **score formula with worked examples**, roadmap |
| [DATA_MODEL.md](docs/DATA_MODEL.md) | Firestore collections and document shapes |
| [DESIGN_SYSTEM.md](docs/DESIGN_SYSTEM.md) | Tokens, palettes, components, motion, accessibility |
| [FIREBASE_SETUP.md](docs/FIREBASE_SETUP.md) | Enabling the backend, step by step |
| [TESTING.md](docs/TESTING.md) | Test strategy and the device QA checklist |
| [RELEASE_CHECKLIST.md](docs/RELEASE_CHECKLIST.md) | App Store and Play submission |

The companion repository **Shiva-PrayanAI** holds the Cloud Functions backend
(server-authoritative scoring) and the AI coaching service.

---

## What Prayan is not

It does not place trades, connect to a broker, ask for brokerage credentials,
predict returns, sell signals, or rank users against each other. It is a
journalling and reflection tool. Nothing in it is financial advice.

---

## Licence

Proprietary. All rights reserved.

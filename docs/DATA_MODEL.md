# Data model

Firestore, user-scoped. Every path begins `users/{uid}/`, which is what makes
the isolation rule in `firebase/firestore.rules` total.

## Two conventions that matter

**1. Money and prices are decimal STRINGS.**

```json
{ "plannedEntryPrice": "22150.75", "multiplier": "50" }
```

Not numbers. Firestore numbers are IEEE-754 doubles; storing `0.1` there and
reading it back does not give you `0.1`. The app parses these into `Dec`
(BigInt-backed fixed point) at the boundary and never converts to `double`
except for chart pixel positions.

**2. Enums are stored by name, never by ordinal.**

```json
{ "direction": "long", "severity": "major" }
```

Documents outlive app builds. Reordering an enum must never silently
reinterpret a historical trade. Every enum has a `wireName` and a `fromWire`
that falls back rather than throwing, so a document written by a newer client
degrades gracefully on an older one.

---

## Collections

### `profiles/{uid}`
`timezoneName` (IANA), `defaultCurrencyCode`, `experience`, `markets[]`,
`style`, `tradingDays[]`, `onboardingComplete`.

### `accounts/{accountId}`
`currencyCode`, `startingEquity`, `currentEquity`, `useLiveEquityForRisk`,
`isDefault`, `isArchived`.

Archived, never deleted — historical trades reference the account for their
currency and equity context.

### `strategies/{strategyId}`
`name`, `isApproved`, `assetClasses[]`, `colorHex`.

`isApproved` is separate from `isArchived` so a user can retire a setup from the
approved list while keeping its analytics.

### `rules/{ruleId}` + `ruleVersions/{versionId}`

The schema's load-bearing decision.

```json
{
  "id": "rule_max_risk",
  "isActive": true,
  "current": {
    "version": 2,
    "name": "Maximum risk per trade",
    "category": "riskLimit",
    "severity": "warning",
    "measure": "maxRiskPercentPerTrade",
    "threshold": "1",
    "effectiveFromUtc": "2026-04-01T00:00:00.000Z",
    "effectiveToUtc": null
  }
}
```

Editing a rule **closes** the live version at `effectiveToUtc` and **opens** a
new one. Every instant maps to exactly one version — no gaps, no overlaps —
so `rule.versionAt(trade.openedAtUtc)` always resolves. `ruleVersions` is
create-only in the security rules; the history cannot be rewritten.

### `trades/{tradeId}`

Executions are **embedded**, not a subcollection: a trade is always read whole,
and a subcollection would double the read count for no benefit.

```json
{
  "symbol": "NIFTY",
  "direction": "long",
  "status": "closed",
  "tradingDayKey": "2026-03-16",
  "openedAtUtc": "2026-03-16T03:45:00.000Z",
  "plannedEntryPrice": "22000",
  "stopLossPrice": "21900",
  "targetPrice": "22200",
  "multiplier": "50",
  "accountEquityAtOpen": "500000",
  "executions": [
    { "kind": "entry", "price": "22000", "quantity": "2", "fees": "45.50" },
    { "kind": "exit",  "price": "22200", "quantity": "2", "fees": "45.50" }
  ],
  "presentedChecklistItemIds": ["c1", "c2", "c3"],
  "completedChecklistItemIds": ["c1", "c2"],
  "revision": 3
}
```

`tradingDayKey` is precomputed in the user's timezone. Grouping by day is the
hottest query in the app and must not depend on the reader's clock.

`accountEquityAtOpen` is frozen on the trade. A later deposit must not
retroactively change whether a percentage-risk rule was breached.

`presentedChecklistItemIds` is stored alongside the completed list so completion
is a ratio of what was actually shown — editing the checklist template later
cannot retroactively fail an old trade.

`revision` bumps on every edit so aggregates know to recompute (§17).

### `dailySummaries/{yyyy-MM-dd}` — **server-written**

```json
{
  "dayKey": "2026-03-16",
  "score": "60.0",
  "uncappedScore": "84.6",
  "wasCappedByMajorViolation": true,
  "hadMajorViolation": true,
  "violationCount": 3,
  "tradeCount": 3,
  "netPnl": "21000",
  "totalR": "3.22",
  "evaluations": [ ... ],
  "scoredAtUtc": "2026-03-16T18:00:00.000Z",
  "scoreVersion": 1
}
```

`allow write: if false` for clients. Written only by the Cloud Function, which
runs the same `prayan_core` logic. The client computes an identical score
locally for instant feedback; what is *stored* is the server's.

`scoreVersion` allows a scoring-algorithm change to trigger a backfill without
guessing which documents are stale.

### `tradeRuleEvaluations/{tradeId}` — **server-written**
The per-trade audit trail: rule id, version id, status, observed, threshold,
message.

### `reviews/{dayKey}`, `psychologyEntries/{entryId}`, `behaviourWatches/{id}`
Guided daily review, mood check-ins, and the user's own written warning
conditions.

### `attachments/{attachmentId}`
Metadata only — `contentType`, `sizeBytes`, `storagePath`. Bytes live in Cloud
Storage under `users/{uid}/attachments/`.

### `auditEvents/{eventId}` — **server-written, append-only**
Trade edits, rule version publications, deletions.

### `coachingUsage/{yyyy-MM-dd}` — **server-written**
`{ userId, periodKey, count, updatedAtUtc }`. How many model-backed
reflections the user has requested today, so the app can show what remains.
Readable by the owner and writable only by the coaching service — a
client-writable counter is not a limit. Exceeding the cap is not an error: the
service falls back to the deterministic narrative, which is built from the same
computed facts.

---

## Retention and deletion

Account deletion removes every subcollection above via a Cloud Function
(a client cannot delete a subcollection). Both app stores require in-app
account deletion, and "delete" must mean the data is gone, not that the login
is disabled.

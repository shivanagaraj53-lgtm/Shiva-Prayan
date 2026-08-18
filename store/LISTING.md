# Store listing — copy and console answers

Everything a submission asks for, written out so it can be pasted rather than
composed under time pressure. Character limits are noted; the copy is inside
them.

**The positioning rule that governs all of it:** this is a *journal*, and the
listing must never read as investment advice or a promise of returns. Words
like "profit", "signals", "returns", "edge that works" and "strategy that wins"
draw exactly the scrutiny that gets financial-adjacent apps rejected — and they
would be false here anyway, since the product's whole argument is that profit
is not the measure.

---

## Names and identifiers

| Field | Value |
|---|---|
| App name (App Store, ≤30) | `Prayan: Trading Journal` (23) |
| App name (Play, ≤30) | `Prayan — Trading Journal` (24) |
| Subtitle (App Store, ≤30) | `Score your discipline` (21) |
| Short description (Play, ≤80) | `A trading journal that scores how well you followed your own rules.` (67) |
| Bundle id (iOS) | `com.prayan.prayanTradingJournal` |
| Application id (Android) | `com.prayan.prayan_trading_journal` |
| Primary category | Finance |
| Secondary category | Productivity |
| Content rating | 4+ / Everyone (no gambling, no user content sharing, no ads) |

---

## Full description

Used for both stores. Play allows 4000 characters; App Store allows 4000. This
is ~1,900.

```
Prayan is a trading journal with an unusual measure of a good day.

Log a trade and it scores how closely you followed the rules you set for
yourself — not how much money you made. A losing trade that respected every
rule scores 100. A profitable trade that broke a major risk rule is capped at
60. That inversion is the whole product.

WHAT IT MEASURES

Set your own rules: maximum risk per trade, a minimum reward-to-risk, a stop
before entry, approved setups only, a daily loss limit, a trade budget, a
pre-trade checklist. Every trade is measured against the version of those rules
that was live when you took it, so tightening a limit today never rewrites
last month.

THE SCORE EXPLAINS ITSELF

Every score comes with the sentence behind it: "Your score is 88 because 21 of
24 applicable rules were followed; maximum risk per trade and approved setups
only were broken." Open it and you see each category, the weight it carried and
the points it contributed. Nothing is a black box, and nothing is a number you
have to take on faith.

BUILT FOR REVIEW, NOT FOR DOPAMINE

- A calendar that separates a good day from a good result — a disciplined loss
  reads differently from a lucky win
- Streaks that only a major breach resets, with your lifetime record kept
  intact underneath
- Analytics that tell you when your sample is too small to mean anything
- Per-rule compliance, so you find the one habit costing you the most
- A guided daily review, and mood check-ins if you want to see whether your
  worst sessions have a pattern

BUILT PROPERLY

- Money is exact. No floating-point drift between your journal and your broker
  statement.
- Works fully offline. Your journal is stored on your device.
- Four themes, full dynamic type, screen-reader labelled, and never colour
  alone to carry meaning.
- Export everything, or delete everything, from inside the app.

WHAT PRAYAN IS NOT

It does not connect to a broker, ask for your brokerage login, place trades,
predict returns or sell signals. It is a journalling and reflection tool.
Nothing in it is financial advice, and trading carries risk including the loss
of your capital.

Plan the trade. Follow the rules. Measure the discipline. Improve the process.
```

---

## Keywords (App Store, ≤100 characters, comma-separated, no spaces)

```
trading,journal,trade,discipline,risk,rules,log,review,checklist,process,journaling,stocks,futures
```
(98 characters. Do not repeat words already in the app name or subtitle —
Apple indexes those separately, so "Prayan" and "discipline" are wasted here if
duplicated.)

---

## Promotional text (App Store, ≤170, changeable without review)

```
A losing trade that followed every rule scores 100. A profitable one that broke
a major rule is capped at 60. Prayan measures your process, not your luck.
```
(152)

---

## Release notes — version 1.0.0

```
First release.

Log a trade in under thirty seconds and see immediately which of your rules it
respected. Every discipline score explains itself, down to the rule and the
number behind it.

- Your own rules, versioned, so old trades keep being judged by the thresholds
  that applied when you took them
- A calendar that tells a disciplined loss apart from a lucky win
- Streaks, per-rule compliance and a guided daily review
- Four themes, full accessibility support, and a journal that works offline
```

---

## Screenshot captions

Ordering matters more than the captions: the first two are what most people
ever see. Lead with the argument, not the dashboard. Files are in
`store/screenshots/`.

| # | File | Caption |
|---|---|---|
| 1 | `5-profitable-rule-break` | **Made ₹20,000. Scored 56.** Because four of seven rules were followed. |
| 2 | `7-disciplined-loss` | **Lost ₹4,000. Scored 100.** Every rule respected. This is the day to repeat. |
| 3 | `1-discipline-score` | Your day, measured by process |
| 4 | `2-score-explained` | Every score explains itself |
| 5 | `3-where-points-came-from` | See exactly where the points came from |
| 6 | `6-audit-trail` | Every verdict traced to the rule and the number |
| 7 | `10-log-trade` | Warned before you commit, not after |
| 8 | `8-calendar` | A good day is not the same as a good result |
| 9 | `9-analytics` | Honest about small samples |
| 10 | `4-journal` | Your whole journal, searchable |

---

## App Review notes (App Store Connect → App Review Information)

```
WHAT THIS APP IS
Prayan is a personal trading journal. The user types in trades they have
already taken and rules they set for themselves, and the app scores how closely
they followed those rules. It is a record-keeping and self-review tool.

IT DOES NOT TRADE
The app has no broker connection, no market data feed and no order routing. It
cannot buy, sell or execute anything, and it never asks for brokerage
credentials. It gives no investment advice and makes no return predictions.
Please see the "What Prayan is not" section of the description.

DEMO ACCOUNT
No account is needed in advance — tap "Create a new account" on the first
screen and use any email and any password of 8+ characters. Accounts are
created and stored on the device; nothing is sent to a server.

  Email:    review@prayan.app
  Password: ReviewPrayan1

SEEING POPULATED SCREENS
Onboarding is 12 short steps and "Skip for now" works on most of them. On the
LAST step, please switch ON "Load the sample journal". That writes three
example trades and is what makes the scoring visible.

Suggested route once you are in:
  1. Home — the discipline score and the sentence explaining it
  2. Tap the score ring — the full breakdown by rule category
  3. Journal tab → tap TATAMOTORS — a trade that made money and scored 56
  4. Journal tab → tap RELIANCE — a trade that lost money and scored 100
  5. "Log trade" — the form flags rule breaches before anything is entered

That third and fourth step are the product's entire point: the score measures
process, not profit.

DATA AND PRIVACY
Everything is stored on the device. Analytics and the optional AI-written
reflection are both OFF by default; the AI feature sends only computed summary
figures (score, rule counts, streaks) and never instrument names, prices or
position sizes. Account deletion is in Settings and removes the data.
```

---

## Play Data safety form

| Question | Answer |
|---|---|
| Does your app collect or share any of the required user data types? | **No** — in this version nothing leaves the device |
| Is all user data encrypted in transit? | Not applicable (no data in transit). If AI reflections are enabled: **Yes**, HTTPS |
| Do you provide a way for users to request data deletion? | **Yes** — in-app, Settings → Delete my account |
| Data types collected | **None** |

> If you enable AI reflections or cloud sync before submitting, this changes.
> You would then declare: *App activity → Other actions*, collected, not
> shared, optional, purpose "App functionality". Update the privacy policy in
> the same pass.

---

## Apple privacy nutrition label

| Question | Answer |
|---|---|
| Do you or your third-party partners collect data from this app? | **No** for the submitted build |
| Tracking (ATT prompt required)? | **No** — no advertising identifiers, no cross-app tracking |
| Third-party analytics SDKs | None bundled |

> With AI reflections enabled, declare *Usage Data → Product Interaction*,
> "Not linked to the user", used for App Functionality, not for tracking.

---

## Age rating questionnaires

Both stores ask about gambling. Answer carefully and truthfully: Prayan
contains **no gambling, no simulated gambling and no contests**. It records
trades the user made elsewhere. Answer "None" to every violence, sexuality,
substance and gambling question. Expected outcome: **4+ (Apple)** and
**Everyone (Play)**.

---

## Things that commonly get financial apps rejected

Worth reading once before you submit.

1. **Any UI that does not work.** Fixed here — sign-in options that a backend
   cannot serve are no longer displayed. Check nothing else has crept in.
2. **A reviewer who cannot see the app work.** They will not log twenty trades
   to populate a chart. The demo credentials and the sample-journal switch
   above are what prevent this.
3. **Reading as investment advice.** Keep "profit", "returns", "signals" and
   "winning strategy" out of the description, screenshots and any web page you
   link.
4. **A privacy policy URL that 404s** or does not match the developer name on
   the account.
5. **Account creation without account deletion.** Both stores require it.
   Prayan has it in Settings; confirm it still works on the build you upload.

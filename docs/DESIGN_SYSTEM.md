# Design system

`lib/design/`. The brief's direction (§36): *sophisticated, disciplined, calm,
institutional-quality, spacious, trustworthy* — and explicitly **not** cheap
gradients, flashing P&L, gambling aesthetics or generic Material defaults.

## Tokens — `tokens.dart`

**Spacing** on a 4pt grid: `xxs 2 · xs 4 · sm 8 · md 12 · lg 16 · xl 24 ·
xxl 32 · xxxl 48`, plus `page 20` and `section 28`.

**Radii**: `xs 6 · sm 10 · md 14 · lg 18 · xl 24 · pill`. Cards are *always*
`lg`. One radius used nearly everywhere is what reads as designed rather than
assembled.

**Motion**: `instant 90 · quick 160 · standard 240 · slow 360 · deliberate 620`.
Only two places earn `deliberate` — the splash reveal and the score-change
explanation.

Every animation goes through `Motion.duration(context, …)`, which collapses to
`Duration.zero` under reduced-motion. Accessibility is the default rather than
something each widget remembers.

**Sizes**: 48dp minimum touch target throughout.

## Colour — `palette.dart`

**24 semantic roles**, four palettes. Widgets read roles (`colors.positive`),
never hex values — which is how four themes coexist without a single
conditional in feature code.

| | Light | Dark |
|---|---|---|
| Default | **Daylight** — cool paper, ink text | **Midnight** — deep navy-slate, not pure black |
| Alternate | **Parchment** — warm, low blue for evening review | **Graphite** — neutral, high contrast |

Result colours are a desaturated teal and a muted terracotta, **not** a trading
terminal's red and green. A loss inside the rules is a normal business outcome
and the palette should not shout about it.

### The accessibility trade, stated plainly

Positive and negative deliberately sit at *similar luminance*. That is what
makes the product read as calm — and it means a red/green colour-blind user
cannot distinguish them by colour.

So the product never asks them to. Meaning is carried redundantly:

- explicit `+` / `−` on every signed figure (`Money.format(showSign: true)`)
- filled vs hollow result dots on calendar cells
- text legends beside every proportional bar
- full semantic labels for screen readers
- `—` for undeterminable values, never a misleading `0`

`test/theme_contrast_test.dart` asserts WCAG AA (4.5:1 body, 3:1 large and
non-text) across all four palettes, and asserts hue separation rather than
luminance contrast between the two result colours — with a comment explaining
exactly why. `test/result_semantics_test.dart` asserts the redundancies.

## Type — `typography.dart`

Platform UI sans for prose — San Francisco on iOS, Roboto on Android. A bundled
sans would look foreign on one of the two platforms.

**Every compared number uses tabular figures.** `PrayanType.metric()` and
`PrayanType.figure()` set `FontFeature.tabularFigures()` and a monospaced
fallback stack. Proportional digits misalign decimal points and make a trade
list unscannable — the single highest-leverage typographic decision here.

Scale: display 48/36 (the score) · headline 28/22/18 · title 17/15/13 ·
body 16/14/13 · label 15/13/11.

## Components — `design/components/`

| Component | Role |
|---|---|
| `PrayanCard` | The surface. One border, one radius, no elevation. |
| `SectionHeader`, `DetailRow` | Structure and key/value rows |
| `ChartContainer` | Framed chart with a tap-to-read plain-language tooltip |
| `MetricCard` | One number, one label, at most one qualifier |
| `LimitMeter` | Progress toward a configured limit; amber near, red past |
| `OutcomeSplitBar` | Win/loss/breakeven proportions **with a text legend** |
| `ScoreRing` | The discipline arc — animates from the *previous* score |
| `ScoreBar` | Compact horizontal variant |
| `RuleStatusTile` | One line of the audit trail: icon, shape, word, values |
| `SeverityChip` | info / warning / major |
| `TradeRow` | Symbol and direction left, R and money right, breaches below |
| `CalendarDayCell` | Three independent facts, none colour-only |
| `CoachingCard`, `CoachingStrip` | Insights, in a calm register |
| `DisclaimerNote` | The standing "not financial advice" line |
| `EmptyState`, `ErrorState`, `Skeleton`, `SyncBanner` | Every non-happy path |
| `PrayanSegmentedControl`, `PrayanChoiceChip` | Selection |
| `confirmAction` | Destructive-action confirmation sheet |

## Motion, deliberately restrained

Splash reveal · dashboard card entrance · animated discipline arc · calendar
transitions · score-change explanation · streak milestone · save confirmation ·
advanced-fields expand · chart transitions.

**No confetti for profit.** The brief forbids casino-like celebration of P&L. A
discipline milestone gets restrained feedback; a winning trade gets none.

## Brand

`PrayanMark` in `features/splash/splash_screen.dart` — drawn, not imported, so
it inherits the active theme's accent and needs no raster asset per density.

"Prayan" means *journey*, so the mark is a rising path: three measured steps
inside a rounded square, with a dot marking the start. It reads at 20pt, which
a literal candlestick or arrow would not.

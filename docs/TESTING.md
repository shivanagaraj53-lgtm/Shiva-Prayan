# Testing

**201 tests, zero analyzer issues.**

```bash
cd packages/prayan_core && dart test    # 157 domain tests
flutter test                            # 44 widget/accessibility tests
flutter analyze && (cd packages/prayan_core && dart analyze)
```

## Domain — `packages/prayan_core/test/`

| Suite | Tests | Covers |
|---|---|---|
| `dec_test` | 21 | Parsing, exact arithmetic, 5 rounding modes, drift |
| `money_test` | 19 | Indian/Western grouping, JPY, currency mismatch |
| `trade_calculator_test` | 42 | Long/short, multipliers, partial exits, validation |
| `performance_metrics_test` | 18 | Expectancy, profit factor, drawdown, grouping |
| `rules_engine_test` | 21 | Every measure, rule versioning, day/week scope |
| `discipline_score_test` | 17 | Weighting, normalisation, major cap |
| `streaks_test` | 16 | Reset semantics, history preservation, rolling windows |
| `trading_day_test` | 13 | Timezone bucketing, DST, leap years |
| `scenario_brief_39_test` | 27 | The brief's worked example, end to end |

## App — `test/`

`theme_contrast_test` (26) — WCAG AA across all four palettes.
`result_semantics_test` (18) — colour-independence and screen-reader labels.

## Edge cases covered because this is where journals break

Long decimals · negative values · zero values · short positions · missing stops
· zero fees · partial exits · scale-ins · **timezone boundaries** · **DST
transitions** · leap years · JPY zero-decimals · Indian lakh/crore grouping ·
rule-version changes · duplicate submission · unknown enum values from a newer
client · corrupted stored documents.

## The tests that matter most

**`scenario_brief_39_test`** encodes the product thesis as an executable
assertion: a losing trade scores 100, a rule-breaking winner scores ≤60, and the
streak resets while every historical figure survives. If a refactor ever
inverts process-over-profit, this fails.

**`trading_day_test`** covers the classic journalling bug — a 09:15 IST trade is
03:45 UTC, and naive `toUtc().day` buckets a late-evening trade into tomorrow.

**`theme_contrast_test`** already caught one real design issue during
development, which is the point of writing it.

## Still to write

Integration tests against the Firebase emulator (auth, sync, offline queue,
account deletion), and golden tests for the four themes.

## Device QA checklist

**iPhone**: SE 3rd gen (small, no notch) · 15 (standard) · 15 Pro Max (large) ·
iPad Pro 12.9".
**Android**: Pixel 4a (small) · Pixel 8 (standard) · Galaxy S24 Ultra (large,
high density) · a foldable, unfolded.

Per device: log a trade in under 30 s · largest accessibility text size without
clipping · dark and light, all four themes · TalkBack/VoiceOver through the
dashboard and trade form · reduced-motion honoured · airplane mode → log →
reconnect → syncs exactly once · rotate during entry, no data lost · keyboard
never covers the field being typed.

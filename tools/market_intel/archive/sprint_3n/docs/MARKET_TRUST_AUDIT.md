# Market Intelligence Trust Audit — Sprint 3G

**Date:** June 2026  
**Scope:** All Market Intelligence UI surfaces. Read-only audit. No code changes.  
**Principles:**

> **Trust > Coverage** — Shelfy should prefer "correct but incomplete" over "complete but incorrect."
>
> **Blind Box ≠ Real Estate** — a series-level average is not equivalent to a figure-level value.

---

## Part 1 — Trust Tiers

### Tier A — Figure Snapshot

**Data model:** `SnapshotLevel.figure` — Firestore document keyed to an individual catalog figure id.

**What it means:**
- `estimatedValueUsd` was computed from sold eBay listings matched to this specific figure.
- `confidence` is typically `SnapshotConfidence.high` — meaningful sold-data volume for this figure.
- `recentSalesCount`, `priceRangeMinUsd/Max`, and `trend` all describe this figure specifically.
- The estimate is as close as the current data pipeline can get to "what buyers are actually paying for this figure right now."

**Legitimate uses:**
- Display as "Market Value" with the raw dollar figure.
- Use as the denominator for listing price deltas (above / below / at market).
- Include without qualification in shelf value totals.

**Inherent uncertainty that is not communicated today:**
- The estimate reflects a lagged computation window (hours to days old — `computedAt` is shown but not near the price).
- It is still eBay-only (acknowledged in the Data Source footer, but far from the price itself).
- `recentSalesCount` may be as low as 1; no minimum sample-size floor is enforced before calling a snapshot `SnapshotConfidence.high`.

---

### Tier B — Series Estimate

**Data model:** `SnapshotLevel.series` — Firestore document keyed to a series id, never to a specific figure. Reached via the fallback path in `marketSnapshotProvider`: figure snapshot not found → look up catalog figure → look up series snapshot.

**What it means:**
- `estimatedValueUsd` was computed from sold eBay listings for the series as a whole — or for whichever figures happened to sell recently — averaged or aggregated without per-figure discrimination.
- `confidence` is `SnapshotConfidence.low`.
- `recentSalesCount` reflects series-wide activity, not this figure's sales.
- `priceRangeMinUsd/Max` is the series range, which may span a 10× price spread.

**Critical limitation:**
Within a single blind-box series, figure prices vary enormously:

```
Regular figures:  $20–$40
Popular figure:   $80
Secret:           $350
```

A series average might be $45. Applying that to a secret figure creates a **10× underestimate**. Applying it to a regular figure may overestimate by 2–3×.

**`isSeriesEstimate` is a computed bool on `MarketSnapshot`** — it is available everywhere a snapshot is consumed. Every surface that receives a snapshot can distinguish tiers A and B at zero cost.

---

### Tier C — No Match

**Data model:** `marketSnapshotProvider` returns `null`.

**What it means:**
- No figure-level snapshot exists.
- Either no series-level snapshot exists, or the figure is not in the catalog bundle (custom figure, unlisted series, new release not yet seeded).

**Behavior today:**
- `MarketSnapshotBadge` is not rendered (caller guards on null).
- `MarketInsightsScreen` shows `kMarketDetailInsightsUnavailable` ("Market insights unavailable").
- `MarketListingPriceDeltaLine` returns `SizedBox.shrink()`.
- `collectionValueProvider` excludes the figure from the total and increments `unavailableCount`.

**Assessment:** Tier C behavior is correct. Absence of data is correctly communicated as absence.

---

## Part 2 — Places Where Series Estimate May Be Mistaken for Figure Value

### Finding 2.1 — `market_snapshot_badge.dart` — `Market Value` label

**File:** `lib/features/market_intel/widgets/market_snapshot_badge.dart`  
**UI text:** `Market Value` (rendered unconditionally as the section heading regardless of tier)

```dart
Text('Market Value', ...)  // line 45 — no tier check
```

The chip `≈ Series Estimate` is shown below the price when `isSeriesEstimate` — which is a correct signal. However, `Market Value` is the dominant visual label that appears first. A user scanning quickly reads:

> Market Value  
> $37  
> ≈ Series Estimate

The word order implies `$37` **is** the market value; the series estimate chip reads like a metadata footnote rather than a correction of the primary label.

**Risk:** Medium. The chip is visible. But the primary label `Market Value` is authoritative-sounding for what is actually a rough proxy.

---

### Finding 2.2 — `market_insights_screen.dart` — Purchase Context delta lines

**File:** `lib/features/market_intel/presentation/market_insights_screen.dart`  
**UI text:** `▲ 14% above market` / `✓ Below market` / `≈ At market`

These delta lines are produced by `formatMarketListingPriceDeltaLine()` which has no knowledge of whether the estimate is figure-level or series-level. When `isSeriesEstimate = true`:

- `▲ 8% above market` actually means "8% above the series average" — not above this figure's market value.
- `≈ At market` could be deeply wrong: the listing may be priced at the series mean while the figure itself is a popular variant worth 2× more.
- `✓ Below market` could mean a secret figure is being sold below the series average — which itself is below the figure's true value.

**The word "market" implies figure-level accuracy. It does not have it.**

**Risk:** High. This is the most impactful trust gap. A user deciding to buy based on `✓ Below market` for a series-estimate figure may be making a materially misinformed decision.

---

### Finding 2.3 — `market_snapshot_format.dart` — Discover summary line structure

**File:** `lib/features/market_intel/widgets/market_snapshot_format.dart`  
**Function:** `formatMarketSnapshotDiscoverSummaryLine()`

```dart
// Figure snapshot:
'Market Value · $42 · 18 sales'

// Series fallback:
'Using Series Estimate · $37 · 4 sales'
```

The formatting pattern is identical. Both render a price inline. While the prefix changes, the visual rhythm is the same. Users who quickly scan the Discover gallery accordion may not register the prefix switch.

**Risk:** Low-medium. The prefix is present and correct. The rendering parity is the issue — both variants look like a peer fact.

---

### Finding 2.4 — `market_insights_screen.dart` — `Market Value` label in purchase context card

**File:** `lib/features/market_intel/presentation/market_insights_screen.dart`  
**UI text:** `Market Value` (left column label in the purchase context summary card)

The `Using Series Estimate` label appears above the card when `isSeriesEstimate`. However, inside the card the column is still labelled `Market Value`. A user reading the card in isolation (e.g., after briefly scrolling past the label) sees:

```
Market Value      Current Listing
$37               $40
▲ 8% above market
```

Both `Market Value` and `▲ 8% above market` imply figure-level grounding.

**Risk:** Medium. The card is self-contained and the "above market" language particularly misleads.

---

### Finding 2.5 — `shelf_value_card.dart` — `_SeriesValueRow` total lacks estimate-mix indicator

**File:** `lib/features/collection/insights/widgets/shelf_value_card.dart`  
**UI text:** Per-series total (e.g., `$183`) with subtitle `3 of 5 figures valued`

The `SeriesValueEntry.totalValueUsd` may aggregate both figure-level and series-level snapshots. If 2 of the 3 "valued" figures use series estimates, the total for that series is partially speculative — but the series row shows a clean dollar amount with no signal.

The top-level total `~$4,382` uses the `~` prefix, which signals approximation globally but does not communicate which figures are driving inaccuracy.

**Risk:** Low-medium. The `~` helps globally. The per-series row and the "Most Valuable" figure list lack per-item qualifiers when mixing tiers.

---

## Part 3 — Places Where Estimate May Be Mistaken for Fact

### Finding 3.1 — `4 sales*` — asterisk with no legend

**File:** `lib/features/market_intel/widgets/market_snapshot_format.dart`  
**Function:** `formatMarketSnapshotSalesLine()`

```dart
final suffix = snapshot.confidence == SnapshotConfidence.low ? '*' : '';
return '${snapshot.recentSalesCount} sales$suffix';
```

The `*` suffix is generated when `SnapshotConfidence.low`. It appears in `MarketSnapshotBadge`. However:
- There is no footnote, tooltip, or legend explaining what `*` means anywhere in the UI.
- `SnapshotConfidence.low` always accompanies a series estimate, so the asterisk effectively means "series estimate" — but that meaning is invisible to the user.

**Risk:** Medium. The signal exists but is opaque. A user seeing `4 sales*` cannot know what the asterisk means.

---

### Finding 3.2 — `formatMarketSnapshotValue()` — raw dollar with no uncertainty prefix

**File:** `lib/features/market_intel/widgets/market_snapshot_format.dart`  
**Function:** `formatMarketSnapshotValue()`

```dart
String formatMarketSnapshotValue(double estimatedValueUsd) {
  return formatMarketUsd(estimatedValueUsd);  // e.g. '$42'
}
```

No tilde, no qualifier. The function is used in:
- `MarketSnapshotBadge` — primary price display
- `MarketInsightsScreen` — Market Value and Current Listing columns
- `formatMarketSnapshotDiscoverSummaryLine()` — Discover accordion

This is intentional for compactness — the tilde appears at the collection level (`~$4,382`). But at the individual figure level, a bare `$42` with the label `Market Value` reads as a fact rather than an eBay-derived estimate.

**Risk:** Low-medium. This is a UX calibration question. The design intent (calm, confident presentation) is valid. But "Market Value $42" has no qualifier that could alert a user to its approximate nature.

---

### Finding 3.3 — Freshness signal is present but separated from the price

**Files:** `market_snapshot_badge.dart`, `market_insights_screen.dart`

`Updated 35h ago` is shown in both surfaces. This is good. However, the `computedAt` timestamp is always rendered well below the price. A user reading `$42` does not immediately know it may be 35 hours stale. In volatile markets (trending figures), 35-hour-old eBay data can meaningfully differ from current prices.

**Risk:** Low. The information is present. Placement below the price is the issue.

---

### Finding 3.4 — `▲ N% above market` — false precision on series estimates (repeated from Part 2)

**File:** `lib/features/market_intel/widgets/market_snapshot_format.dart`  
**Function:** `formatMarketListingPriceDeltaLine()`

The ±5% threshold for `≈ At market` implies precision. For figure snapshots, this is reasonable. For series estimates, applying a 5% threshold to a series average and calling it `≈ At market` may be precise arithmetic on an imprecise input.

**Risk:** High (same as Finding 2.2 — listed here for completeness).

---

### Finding 3.5 — `SnapshotConfidence.high` does not enforce a minimum sales floor

**File:** `lib/features/market_intel/data/firestore/firestore_market_snapshot_repository.dart` and admin write pipeline (outside Flutter app)

The Flutter mapper accepts any `SnapshotConfidence.high` document. There is no known minimum sample size in the domain model. A figure snapshot with `recentSalesCount = 1` and `confidence = 'high'` would be rendered with full authority as `Market Value $42` with no caveat.

**Risk:** Low-medium in the short term (data is admin-authored). Medium in the long term if snapshot generation becomes automated.

---

## Part 4 — Wording Recommendations

No implementation. Recommendations only.

---

### 4.1 — `Market Value` label in `MarketSnapshotBadge`

| Current | Recommended (Tier A) | Recommended (Tier B) |
|---------|----------------------|----------------------|
| `Market Value` | `Market Value` (unchanged) | `Series Avg. Value` |

Rationale: The badge already shows the `≈ Series Estimate` chip for Tier B. If the primary label is also changed, the combined message is unambiguous: users see "Series Avg. Value / $37 / ≈ Series Estimate" and cannot mistake it for figure-level data.

---

### 4.2 — `Market Value` column label in `MarketInsightsScreen` purchase context card

| Current | Recommended (Tier A) | Recommended (Tier B) |
|---------|----------------------|----------------------|
| `Market Value` | `Market Value` (unchanged) | `Series Avg.` |

Rationale: The compact label `Series Avg.` inside the card, combined with the `Using Series Estimate` label already shown above the card, provides two-layer signalling without cluttering the card.

---

### 4.3 — Delta line wording when source is a series estimate

| Current | Recommended |
|---------|-------------|
| `▲ 14% above market` | `▲ 14% above series avg.` |
| `✓ Below market` | `✓ Below series avg.` |
| `≈ At market` | `≈ Near series avg.` |

Rationale: The word "market" implies figure-level accuracy. "Series avg." communicates the actual basis of the comparison. This change is scoped entirely to `formatMarketListingPriceDeltaLine()` — it already receives `estimatedValueUsd` but not `isSeriesEstimate`. Passing the tier flag (or a boolean) is the only logic change required.

---

### 4.4 — `Using Series Estimate` label (Discover accordion, Market Insights screen)

| Current | Recommended |
|---------|-------------|
| `Using Series Estimate` | `Series-Level Estimate` |

Rationale: The current wording is passive ("using" doesn't explain the limitation). `Series-Level Estimate` is noun-form and matches the tier language elsewhere. An optional one-line sub-label could add: _"This figure has no individual sales data."_ — but this is only needed on the Market Insights screen where the user has committed attention.

---

### 4.5 — `4 sales*` asterisk

| Current | Recommended option A | Recommended option B |
|---------|----------------------|----------------------|
| `4 sales*` | `4 sales (series avg.)` | Remove asterisk; rely on separate tier label |

Rationale: Option A makes the asterisk self-explaining. Option B removes a signal that is currently meaningless without a legend. The asterisk was intended to communicate low confidence but it is invisible to users who do not know what it means. If the tier is already communicated via `≈ Series Estimate` chip or `Series-Level Estimate` label, the asterisk is redundant and its removal reduces clutter.

---

### 4.6 — `Est. shelf value` label (Collection Home summary section)

| Current | Recommended |
|---------|-------------|
| `Est. shelf value` | `Est. shelf value` (unchanged) |

The `Est.` prefix is correct and appropriately humble. No wording change needed at this level.

However, the sub-label `Based on 12 of 15 figures` should optionally add when any of the 12 are series estimates:

| Current | Recommended |
|---------|-------------|
| `Based on 12 of 15 figures` | `Based on 12 of 15 figures · includes estimates` |

Rationale: Transparent without alarming. The `~` prefix on the dollar amount already signals approximation; the sub-label annotation closes the loop on _why_ the approximation exists.

---

## Part 5 — Collection Value Review

### Surfaces reviewed

1. `collection_summary_section.dart` — `Est. shelf value ~$4,382 / Based on X of Y figures` (Collection Home glance)
2. `shelf_value_card.dart` — `Shelf Value ~$4,382`, `Most Valuable` top-5, `By Series` breakdown (Collection Insights screen)
3. `collection_value_providers.dart` — aggregation logic

---

### What the current wording communicates

| Signal | Mechanism | Assessment |
|--------|-----------|------------|
| Approximation | `~` prefix | ✓ Correct |
| Abbreviation "est." | `Est. shelf value` label | ✓ Correct |
| Incomplete coverage | `Based on X of Y figures` | ✓ Correct |
| Series-estimate contamination | None | ✗ Missing |
| Individual figure uncertainty | `~` prefix on per-figure rows | ✓ Partial — present in `_FigureValueRow`, absent in `_SeriesValueRow` |

---

### Problem: the total does not distinguish estimate quality

`collectionValueProvider` aggregates figure-level and series-level snapshots without weighting or flagging. A user with 15 owned figures:
- 3 have figure-level snapshots → Tier A
- 9 have series-level fallback → Tier B  
- 3 have no snapshot → excluded

The display shows `~$612 / Based on 12 of 15 figures`. The user cannot tell that 9 of those 12 values are series averages that may be completely wrong for their specific figures.

A user who owns 3 popular variants (each worth $150) and 9 regulars (each estimated at $42 via series avg = true value $30) will see a total that underestimates by a significant margin — with no indication of the quality gap.

---

### Recommendations for Collection Value

**R5.1 — Add estimate-mix indicator to total**

When `ShelfValueSummary.topFigures` or `seriesBreakdown` contains any `ValuedFigure.isSeriesEstimate = true`:
- Sub-label change: `Based on 12 of 15 figures · includes estimates`
- Or a compact note: `Some values are series estimates`

**R5.2 — Add estimate quality split to coverage bar**

Replace `N% coverage` with two-part coverage breakdown:

```
12 of 15 figures with market data
  └── 3 with figure data · 9 with series estimates
```

This is a deeper change but is the clearest way to communicate the quality split.

**R5.3 — `_SeriesValueRow` — tilde for mixed series**

In the `By Series` breakdown, a `SeriesValueEntry.totalValueUsd` that includes series-estimate backing should carry the `~` prefix in the row. Currently `formatShelfValueUsd()` is called without qualification for series totals. No per-series mix flag exists in `SeriesValueEntry`.

Domain change required: `SeriesValueEntry` would need `hasSeriesEstimates: bool` (or `seriesEstimateCount: int`).

**R5.4 — Individual figure rows in `Most Valuable` — current behavior is good**

`_FigureValueRow` already uses `~` prefix for `isSeriesEstimate` figures:
```dart
final valueLabel = fig.isSeriesEstimate
    ? '~${formatShelfValueUsd(fig.estimatedValueUsd)}'
    : formatShelfValueUsd(fig.estimatedValueUsd);
```
This is the correct pattern. The other surfaces should match it.

---

## Part 6 — Future Large-Format Collectibles

### Context

The current Market Intelligence model was designed for standard blind-box figures. As Shelfy's catalog grows, it will include:

- **MEGA / 400%** — oversized versions of blind-box characters ($80–$500)
- **1000%** — very large display pieces ($300–$1,500)
- **Vinyl statues / art collectibles** — limited-edition premium ($200–$5,000)
- **Artist proof / chase** — ultra-limited variants within a MEGA line

### Why the current model breaks for large-format

**Problem 1 — Series average is meaningless across format types**

A single IP (e.g., THE MONSTERS) may include:
- Regular blind-box: $12–$35
- Pocket-size: $8–$15
- MEGA 400%: $120–$280
- 1000% statue: $600–$1,200

If `marketSnapshotProvider` falls back to a series-level snapshot and the series average blends all formats, the resulting estimate is garbage for any individual item. A `Using Series Estimate` badge on a $400 MEGA showing `$42 series avg.` actively misleads the user into thinking the item might be worth $42.

**Problem 2 — Sales volume for large-format is structurally low**

MEGAs have:
- Higher prices → fewer transactions per period
- Less commodity — condition, original packaging, and colorway matter more
- Different eBay listing behavior (auctions vs. Buy It Now)

`SnapshotConfidence.low` would be the permanent state for most large-format figures even with a figure-level snapshot, since `recentSalesCount` will often be under 5.

**Problem 3 — Series range is more misleading for MEGA lines**

For a regular blind-box, `Range $38–$48` on a series estimate means ±10 on either side. For a large-format line, a "series" might span $80 for a basic MEGA to $1,200 for a chase. Showing this range near a listing price comparison is actively false.

**Problem 4 — "At market" threshold is wrong for large-format**

`formatMarketListingPriceDeltaLine` uses a ±5% threshold. For a $42 figure, 5% = $2.10. For a $400 MEGA, 5% = $20. The same threshold may be too tight or too loose depending on format tier. More importantly, if the underlying estimate is a series average that mixes formats, the ±5% calculation has no meaning.

---

### Recommended design direction for large-format (future sprint)

**Option A — Format-level snapshot exclusion**

Introduce a `formatType` field on `CatalogFigure` (e.g., `standard`, `mega_400`, `mega_1000`, `statue`). When `marketSnapshotProvider` resolves a series fallback:

- If the figure's `formatType` != `standard`, return `null` rather than the series estimate.

This ensures large-format figures always land in Tier C (no match) unless a figure-specific snapshot exists.

**Option B — Format-aware series snapshot**

Introduce separate series snapshot documents per format tier:
```
market_snapshots / {seriesId}_mega / ...
market_snapshots / {seriesId}_standard / ...
```

Higher complexity. Requires admin tooling changes.

**Option C — Suppress series fallback entirely for new formats**

Until large-format data collection is robust enough for `SnapshotConfidence.high` at the figure level, render no market intelligence for MEGAs/statues rather than a misleading series average. Tier C with a contextual message like `Market data not yet available for this format` is strictly more honest than Tier B with a wildly incorrect series average.

**Recommended approach:** Option A for the medium term. It requires catalog enrichment (one new enum field) but has zero impact on the existing UI rendering pipeline — large-format figures simply return `null` and land in the existing "unavailable" state.

---

## Part 7 — Final Recommendations (Prioritized)

### P0 — Fix immediately (active trust violations)

| # | Finding | Change Required | Files |
|---|---------|-----------------|-------|
| P0-1 | `▲ N% above market` / `✓ Below market` / `≈ At market` when source is series estimate | Pass `isSeriesEstimate` into `formatMarketListingPriceDeltaLine()` and substitute "series avg." for "market" when true | `market_snapshot_format.dart`, `market_detail_insights_section.dart`, `market_insights_screen.dart` |
| P0-2 | `Market Value` label on `MarketSnapshotBadge` renders identically for Tier A and Tier B | Change label to `Series Avg. Value` when `isSeriesEstimate` | `market_snapshot_badge.dart` |
| P0-3 | `Market Value` column label inside `MarketInsightsScreen` purchase context card renders identically for both tiers | Change column label to `Series Avg.` when `isSeriesEstimate` | `market_insights_screen.dart` |

---

### P1 — Trust improvements (important, not immediately harmful)

| # | Finding | Change Required | Files |
|---|---------|-----------------|-------|
| P1-1 | `4 sales*` asterisk has no legend | Either make the asterisk self-describing (`4 sales (series avg.)`) or remove it and rely on the tier label already present | `market_snapshot_format.dart` |
| P1-2 | Collection total does not distinguish estimate-mix quality | Add `includes estimates` qualifier to sub-label when any valued figure is `isSeriesEstimate` | `collection_summary_section.dart`, `shelf_value_card.dart` |
| P1-3 | `Using Series Estimate` wording is passive | Rename to `Series-Level Estimate`; optionally add: `This figure has no individual sales data.` on `MarketInsightsScreen` only | `market_snapshot_format.dart` |
| P1-4 | `_SeriesValueRow` in `By Series` breakdown shows clean total even when mix includes series estimates | Add `~` prefix to series total when any contributing figure is `isSeriesEstimate`; requires `hasSeriesEstimates` flag on `SeriesValueEntry` | `shelf_value_card.dart`, `shelf_value_summary.dart`, `collection_value_providers.dart` |

---

### P2 — Future enhancements

| # | Topic | Description |
|---|-------|-------------|
| P2-1 | Large-format exclusion | Introduce `formatType` on `CatalogFigure`; suppress series fallback for non-standard formats | See Part 6 |
| P2-2 | Minimum sales floor for `SnapshotConfidence.high` | Define and document a minimum `recentSalesCount` threshold before a figure snapshot can be rated `high`; enforce in admin write pipeline | Admin tooling + domain docs |
| P2-3 | Freshness signal proximity | Move `Updated N ago` or a compact data-age badge closer to the price in `MarketInsightsScreen` and `MarketSnapshotBadge` | `market_insights_screen.dart`, `market_snapshot_badge.dart` |
| P2-4 | Collection value quality split | Add detailed two-line coverage note: `3 with figure data · 9 with series estimates` in `ShelfValueCard` | `shelf_value_card.dart`, `shelf_value_summary.dart` |
| P2-5 | `SnapshotConfidence.high` does not imply a sample-size floor | Document explicitly in `market_snapshot.dart` what `high` and `low` guarantee — or add a `recentSalesCount` threshold field to the domain model | `market_snapshot.dart` |

---

## Summary Table — All Findings

| Finding | Surface | Trust Risk | Tier Affected |
|---------|---------|------------|---------------|
| 2.1 | `MarketSnapshotBadge` — "Market Value" primary label | Medium | B |
| 2.2 | Delta lines — "above/below/at market" on series estimates | **High** | B |
| 2.3 | Discover summary line — structural parity | Low-medium | B |
| 2.4 | Market Insights purchase context card — "Market Value" label | Medium | B |
| 2.5 | `_SeriesValueRow` total — no estimate-mix flag | Low-medium | A+B mix |
| 3.1 | `4 sales*` — legend-free asterisk | Medium | B |
| 3.2 | `formatMarketSnapshotValue()` — no uncertainty prefix | Low-medium | A, B |
| 3.3 | Freshness signal placement below price | Low | A, B |
| 3.4 | `▲ N% above market` false precision (duplicate of 2.2) | **High** | B |
| 3.5 | `SnapshotConfidence.high` — no sales floor | Low-medium | A |

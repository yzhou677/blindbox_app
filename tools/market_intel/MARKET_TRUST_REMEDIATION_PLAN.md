# Market Intelligence Trust Remediation Plan — Sprint 3H

**Date:** June 2026  
**Type:** Design document. P0 wording implemented in Sprint 3I (June 2026).  
**Precondition:** Audit completed in Sprint 3G — `tools/market_intel/MARKET_TRUST_AUDIT.md`

**Sprint 3I status:** P0-1, P0-2, P0-3, and Discover summary trust wording implemented. P1/P2 remain future work.

**Sprint 3J status:** Market Insights navigation hidden when `snapshot.isSeriesEstimate` (Option B — Trust > Coverage). Tier A unchanged; Tier B keeps delta wording only.

**Sprint 3K status:** Collection Home / Insights overview sub-label appends `· includes estimates` when `ShelfValueSummary.includesSeriesEstimates` is true.

**Sprint 3L status:** By Series row prefixes `~` on series total when `SeriesValueEntry.hasSeriesEstimates` is true (P1-4).

**Sprint 3M-B status:** Collection Insights `Shelf Value` section header includes an inline ⓘ that opens `ShelfValueInfoSheet` — P0-2 from `VALUATION_TRANSPARENCY_AUDIT.md`. Educational disclosure only; no valuation logic changes.

---

## Core Principles

### Principle 1 — Trust > Coverage

Shelfy will show less information rather than misleading information. An absent value is always more honest than a wrong one.

### Principle 2 — Blind Box ≠ Real Estate

A series-level average is not a reliable proxy for an individual figure's value. Within a single series:

```
Regular A            $25
Regular B            $30
Popular Variant      $80
Secret               $350
```

A series average of ~$45 is simultaneously an overestimate for regulars and a catastrophic underestimate for the secret. This is not a rounding error — it is a category error.

Series-Level Estimates must therefore never be presented with the same vocabulary, visual weight, or implied accuracy as Figure Snapshots.

---

## Part 1 — Current State Inventory

### 1A — Discover Figure Detail (Catalog Figure Gallery)

**File:** `lib/features/catalog/presentation/figure_gallery/catalog_figure_gallery_sheet.dart`

**Widget:** `_GalleryMarketInformationAccordion`

**Current behavior:**

Collapsed state shows: `▶ Market Information`

Expanded state shows:
- Tier A: `Market Value · $42 · 18 sales`
- Tier B: `Using Series Estimate · $37 · 4 sales`
- Then: `Range $38–$48` / `Updated 35h ago` (via `MarketSnapshotDiscoverExpandPanel`)

**Current trust tier behavior:**

- Tier distinction exists in the summary line (prefix changes).
- No distinction in the expanded secondary data (range, updated) — identical rendering for A and B.
- Tier C: accordion is hidden entirely (correct).

**Current risks:**

- `Using Series Estimate · $37` and `Market Value · $42` render with identical visual weight inside the accordion. A quick-scan user registers `$37` not `Using Series Estimate · $37`.
- `Range $38–$48` for a series estimate is the series price range, not a figure-specific range. Showing it in the expanded panel implies figure-level precision.

---

### 1B — Market Detail Screen

**File:** `lib/features/market/market_detail_screen.dart`

**Widgets:** `MarketListingPriceDeltaLine`, `MarketInsightsNavigationRow`

**Current behavior:**

Below the listing ask price, shows one of:
- Tier A: `▲ 14% above market`
- Tier A: `✓ Below market`  
- Tier A: `≈ At market`
- Tier B: same three strings — **no tier distinction**
- Tier C: hidden

The `MarketInsightsNavigationRow` appears when `insightsFigureId != null` — available for both Tier A and Tier B listings.

**Current trust tier behavior:**

`formatMarketListingPriceDeltaLine()` receives `estimatedValueUsd` only — it has no knowledge of `isSeriesEstimate`. The function produces identical output for A and B.

**Current risks:**

- **High.** A user sees `≈ At market` for a figure whose "market" is actually a series average. The listing price may be dramatically below or above the figure's true value.
- This surface is the most action-oriented: the user is one tap away from "View on eBay." Trust errors here have direct financial consequences.

---

### 1C — Market Insights Screen

**File:** `lib/features/market_intel/presentation/market_insights_screen.dart`

**Widget:** `_MarketInsightsContent`

**Current behavior:**

- When Tier B: shows `Using Series Estimate` above the purchase context card.
- Purchase context card: `Market Value | $37 / Current Listing | $40 / ▲ 8% above market`
- Activity: `4 recent sales · Stable`
- Range: `Range $30–$45`

**Current trust tier behavior:**

- Tier B is flagged with `Using Series Estimate` (correct, present).
- Inside the card, the left column is still labelled `Market Value` regardless of tier.
- The delta line `▲ 8% above market` still uses "market" regardless of tier.

**Current risks:**

- Medium-high. The `Using Series Estimate` label is correct but placed above the card as a heading. Once the user reads the card, they see `Market Value $37 / Current Listing $40 / ▲ 8% above market` — three Tier A signals — with no inline Tier B signal inside the card itself.
- The user mentally registers the card content, not the label above it.

---

### 1D — MarketSnapshotBadge

**File:** `lib/features/market_intel/widgets/market_snapshot_badge.dart`

**Current behavior:**

```
Market Value          ← always this label
$37                   ← dominant price
≈ Series Estimate     ← chip, below price, Tier B only
4 sales*              ← asterisk with no legend
$38–$48 range
Updated 35h ago
```

**Current trust tier behavior:**

- `≈ Series Estimate` chip is rendered when `isSeriesEstimate` — the distinction exists.
- `Market Value` label is rendered unconditionally — it is never changed for Tier B.
- The asterisk on `4 sales*` has no associated legend anywhere in the UI.

**Current risks:**

- Medium. The visual reading order is: `Market Value` → `$37` → (chip). The chip comes after the authoritative-sounding label and dominant price. Users who scan top-to-bottom register `Market Value $37` before they reach the chip.
- The `*` asterisk is opaque — it is generated for `SnapshotConfidence.low` but that meaning is never surfaced to the user.

---

### 1E — Collection Home (Summary Section)

**File:** `lib/features/collection/widgets/collection_summary_section.dart`

**Widget:** `_ShelfValueGlance`

**Current behavior:**

```
Est. shelf value    ~$612
                    Based on 12 of 15 figures
```

**Current trust tier behavior:**

- `Est.` prefix signals estimate. ✓
- `~` tilde prefix signals approximation. ✓
- `Based on 12 of 15 figures` signals incomplete coverage. ✓
- No signal for whether those 12 values are Tier A or Tier B.

**Current risks:**

- Low-medium. The `Est.` and `~` qualifiers are present. The missing signal is estimate quality: if 10 of 12 are Tier B series estimates, `~$612` may be dramatically wrong — but nothing on this surface communicates that.

---

### 1F — Collection Insights Screen (ShelfValueCard)

**File:** `lib/features/collection/insights/widgets/shelf_value_card.dart`

**Current behavior:**

Three sections:
1. **Shelf Value** — `~$612` total, `Based on 12 of 15 figures`, coverage bar
2. **Most Valuable** — top-5 figure rows; series-estimate figures show `~$80`, figure-snapshot figures show `$80` (tilde distinction is present ✓)
3. **By Series** — collapsed list; each row shows series total and `3 of 5 figures valued`

**Current trust tier behavior:**

- `_FigureValueRow` correctly uses `~` for `isSeriesEstimate`. ✓
- `_SeriesValueRow` total (`formatShelfValueUsd`) is called without qualification — no `~` even when the series total is partly or entirely Tier B.
- The "By Series" per-series total has no estimate-quality signal.

**Current risks:**

- Low-medium. The per-figure tilde is correct. The per-series total and the overall total do not distinguish confidence quality beyond the global `~`.

---

## Part 2 — Canonical Trust Tier Model

### Tier Definitions

#### Tier A — Figure Snapshot

**Requirements:**
- `SnapshotLevel.figure` — a Firestore document exists for this specific figure id.
- The estimate is derived from sold data matched to this figure.

**Permitted vocabulary:**
- `Market Value`
- `Above market`
- `Below market`
- `At market`
- Unqualified dollar amounts (`$42`)
- Unqualified range (`Range $38–$48`)

**Permitted because:** The estimate is specific, figure-grounded, and as accurate as the current pipeline allows.

---

#### Tier B — Series-Level Estimate

**Requirements:**
- No figure-level snapshot exists.
- A series-level snapshot is used as a fallback.
- `MarketSnapshot.isSeriesEstimate == true`.

**The naming problem:**

Several candidate labels were considered. The audit notes `Using Series Estimate` (current) as passive and unclear. Here is the full evaluation:

| Candidate | Assessment |
|-----------|------------|
| `Using Series Estimate` | Passive. "Using" tells the user what we're doing, not what the number means. ✗ |
| `Series Estimate` | Noun-form. Shorter. Still ambiguous — estimate of what? ∼ |
| `Series-Level Estimate` | Explicit level reference. Matches "figure-level" as a conceptual counterpart. ✓ |
| `Estimated Series Value` | Reads as the series having a value — not this figure. Could confuse. ✗ |
| `Series Average` | Accurate description of the computation. Clear and plain-language. ✓✓ |
| `Series Avg. Value` | Compact form. Works well as a label. ✓✓ |
| `Based on series data` | Describes source, not the limitation. Too soft. ✗ |
| `No figure data` | Accurate but alarming; shifts tone to absence rather than approximation. ✗ |

**Recommended naming system — "Series Average" vocabulary:**

Use `Series Avg.` as the compact label form (space-constrained contexts) and `Series Average` as the full label form (prose contexts). The word "average" is the key — it immediately tells the user _why_ the number may not apply to their specific figure, without requiring any further explanation.

**Permitted vocabulary (Tier B):**

| Tier A (forbidden for Tier B) | Tier B replacement |
|-------------------------------|-------------------|
| `Market Value` | `Series Avg.` / `Series Average` |
| `▲ N% above market` | `▲ N% above series avg.` |
| `✓ Below market` | `Below series avg.` |
| `≈ At market` | `Near series avg.` |
| `Market insights unavailable` | unchanged (Tier C, not B) |
| `Using Series Estimate` | `Series-Level Estimate` |

**Rationale for keeping the tilde (`~`) on Tier B dollar amounts:**

The tilde already signals approximation in the collection value context. In market contexts (badge, insights screen), the label change (`Market Value` → `Series Avg.`) carries the trust signal. The tilde is optional in market contexts but should remain in collection contexts where it is already established.

---

#### Tier C — No Match

**Requirements:**
- No figure-level snapshot AND no series-level snapshot (or figure not in catalog bundle).
- `marketSnapshotProvider` returns `null`.

**Recommended behavior: hide valuation completely on all surfaces.**

Current Tier C behavior per surface:

| Surface | Current behavior | Correct? |
|---------|-----------------|----------|
| Discover accordion | Hidden entirely | ✓ |
| Market Detail delta line | `SizedBox.shrink()` | ✓ |
| Market Detail nav row | Hidden (no `insightsFigureId`) | ✓ |
| Market Insights screen | `Market insights unavailable` text | ✓ |
| Collection Home total | Excluded from count; shown in `X of Y` denominator | ✓ |
| Collection Insights Most Valuable | Excluded | ✓ |
| MarketSnapshotBadge | Caller-guarded — badge not rendered | ✓ |

**Assessment:** Tier C behavior is already correct on all surfaces. No changes needed.

---

## Part 3 — P0 Remediation Design

### P0-1 — Price Delta Wording

**Surface:** Market Detail Screen, Market Insights Screen  
**Files:** `lib/features/market_intel/widgets/market_snapshot_format.dart`, `lib/features/market_intel/widgets/market_detail_insights_section.dart`, `lib/features/market_intel/presentation/market_insights_screen.dart`

---

**Current behavior:**

`formatMarketListingPriceDeltaLine(double listingPriceUsd, double estimatedValueUsd)` produces:

```
▲ 14% above market      ← for both Tier A and Tier B
✓ Below market          ← for both Tier A and Tier B
≈ At market             ← for both Tier A and Tier B
```

The function signature has no awareness of `isSeriesEstimate`.

---

**Risk:**

The highest-risk finding in the audit. A user evaluating a listing sees `≈ At market` and interprets it as "this figure's ask price is fair relative to what similar figures have sold for." When the denominator is a series average, that interpretation is wrong. The listing may be:
- At the series average, but far above this specific popular figure's true value
- At the series average, but far below a secret figure's true value

The phrase "at market" carries an authoritative connotation. It is the sentence the user acts on.

---

**Recommended fix:**

Add a `bool isSeriesEstimate` parameter to `formatMarketListingPriceDeltaLine()`. The function then selects vocabulary based on tier:

```
Tier A output:           Tier B output:
▲ 14% above market   →   ▲ 14% above series avg.
✓ Below market       →   Below series avg.
≈ At market          →   Near series avg.
```

**Tier B delta lines — vocabulary evaluation:**

| Delta direction | Candidate A | Candidate B | Recommended |
|----------------|-------------|-------------|-------------|
| Above | `▲ 14% above series avg.` | `▲ 14% above series average` | `▲ 14% above series avg.` — compact, consistent with label |
| Below | `✓ Below series avg.` | `Below series average` | `Below series avg.` — remove ✓ checkmark (below series avg. is not unconditionally good) |
| At | `≈ Near series avg.` | `≈ At series avg.` | `≈ Near series avg.` — "near" is more honest than "at"; the 5% band around a series average carries much less meaning than around a figure-specific value |

**Note on the `✓` checkmark:** The checkmark on `✓ Below market` (Tier A) communicates "this is potentially a good deal." For Tier B, "below series avg." is not a purchasing signal — a listing below the series average could still be above the figure's actual value if the series average is inflated by popular variants. The checkmark should be removed from Tier B delta lines.

---

**Migration impact:**

Minimal. The function is called in exactly two places:
1. `market_detail_insights_section.dart` — `MarketListingPriceDeltaLine` widget, which already has access to the full `MarketSnapshot` via its own provider watch
2. `market_insights_screen.dart` — `_MarketInsightsPurchaseDeltaLine`, which already receives `snapshot`

Both call sites have direct access to `snapshot.isSeriesEstimate`. The signature change is additive — existing callers would need to pass the flag, but no other files are affected.

---

**User-facing before/after (Tier B):**

```
BEFORE (series estimate, $40 listing vs $37 avg):
  ▲ 8% above market

AFTER:
  ▲ 8% above series avg.
```

```
BEFORE (series estimate, $35 listing vs $37 avg):
  ✓ Below market

AFTER:
  Below series avg.
```

```
BEFORE (series estimate, $37 listing vs $37 avg):
  ≈ At market

AFTER:
  ≈ Near series avg.
```

---

### P0-2 — MarketSnapshotBadge Wording

**Surface:** Anywhere `MarketSnapshotBadge` is rendered (currently: `MarketSnapshotDevScreen` only in production paths; available for future use in figure detail contexts)  
**File:** `lib/features/market_intel/widgets/market_snapshot_badge.dart`

---

**Current behavior:**

```
Market Value      ← unconditional heading
$37               ← dominant price
≈ Series Estimate ← chip, shown only for Tier B
4 sales*          ← asterisk undefined
$38–$48 range
Updated 35h ago
```

For Tier A, no chip is shown. For Tier B, `≈ Series Estimate` chip appears below `$37`.

---

**Risk:**

Medium. The reading order matters. Users encounter `Market Value` first, then the price, then the clarifying chip. The word `Market Value` primes the user to read `$37` as an authoritative figure-level value. By the time the chip is reached, the anchor is set.

---

**Recommended fix:**

Change the section heading based on tier:

| Tier | Current heading | Recommended heading |
|------|----------------|---------------------|
| A | `Market Value` | `Market Value` (unchanged) |
| B | `Market Value` | `Series Avg. Value` |

The `≈ Series Estimate` chip below the price can remain as reinforcement, but the primary trust signal must be in the dominant label — not below the price.

Additionally, replace or remove the `*` asterisk from the sales line:

| Current | Recommended |
|---------|-------------|
| `4 sales*` | `4 sales` (asterisk removed — tier is communicated by the heading) |

Rationale: with `Series Avg. Value` as the heading and `≈ Series Estimate` chip below the price, adding `*` creates three overlapping signals for the same fact. The asterisk without a legend is less clear than no asterisk at all. Remove it; rely on the heading and chip.

---

**Migration impact:**

Contained to `market_snapshot_badge.dart`. The `snapshot.isSeriesEstimate` flag is already available on the `snapshot` parameter. A single conditional on the heading text. The `*` asterisk is generated in `formatMarketSnapshotSalesLine()` in `market_snapshot_format.dart` — removal there is a one-line change and affects only the badge (the badge is the only current consumer of that function outside of dev screens).

---

**User-facing before/after:**

```
BEFORE (Tier B):          AFTER (Tier B):
Market Value              Series Avg. Value
$37                       $37
≈ Series Estimate         ≈ Series Estimate
4 sales*                  4 sales
$38–$48 range             $38–$48 range
Updated 35h ago           Updated 35h ago
```

```
BEFORE (Tier A):          AFTER (Tier A):
Market Value              Market Value        ← unchanged
$42                       $42
18 sales                  18 sales
$38–$48 range             $38–$48 range
Updated 35h ago           Updated 35h ago
```

---

### P0-3 — Market Insights Purchase Context Wording

**Surface:** Market Insights Screen  
**File:** `lib/features/market_intel/presentation/market_insights_screen.dart`

---

**Current behavior (Tier B):**

```
[Header: Hope / THE MONSTERS Big Into Energy …]

Using Series Estimate     ← label above card

┌────────────────────────────────────────┐
│ Market Value   │  Current Listing      │
│ $37            │  $40                  │
│                                        │
│ ▲ 8% above market                     │
└────────────────────────────────────────┘

4 recent sales · Stable
Range $30–$45
Updated 35h ago
…
```

---

**Risk:**

Medium-high. The `Using Series Estimate` label is correct but acts as a heading above the card. Inside the card, the user reads:
- `Market Value` (authoritative label — implies figure-specific)
- `$37` (dominant display)
- `▲ 8% above market` (action-oriented delta — implies figure-specific comparison)

The card is visually self-contained and reads coherently as figure-level data, independent of the external heading above it.

---

**Recommended fix:**

Three simultaneous changes to the card interior for Tier B:

**Change 1 — Left column heading**

| Tier | Current | Recommended |
|------|---------|-------------|
| A | `Market Value` | `Market Value` (unchanged) |
| B | `Market Value` | `Series Avg.` |

**Change 2 — Delta line**

Per P0-1 recommendation: change `▲ 8% above market` → `▲ 8% above series avg.`

**Change 3 — `Using Series Estimate` label**

Rename the external label from `Using Series Estimate` to `Series-Level Estimate`. This is the label that appears between the figure header and the card. While this is a P1 item in the audit, it is directly adjacent to the card and should be updated in the same pass for coherence.

---

**Alternative considered — hide the card entirely for Tier B:**

A more conservative approach would be to suppress the purchase context card for Tier B and show only a message: _"No figure-specific market data. Series estimate available in the activity section below."_ This would be the most trust-conservative option. However, it removes legitimately useful information: even a series average gives a rough ballpark for regulars and is better than nothing if the user understands what it is. The recommended approach (label changes) achieves trust without sacrificing useful context.

---

**Migration impact:**

`_MarketInsightsContent` and `_MarketInsightsPurchaseDeltaLine` both receive the full `MarketSnapshot` object. `snapshot.isSeriesEstimate` is available at both sites. The changes are conditional label swaps — no new data, no new providers.

The `kMarketSnapshotDiscoverSeriesFallbackLabel` constant (`Using Series Estimate`) is shared across surfaces. A rename here requires checking all consumers: Discover accordion uses the same constant. Both can be updated simultaneously since the rename is purely cosmetic.

---

**User-facing before/after:**

```
BEFORE (Tier B):

Using Series Estimate

┌────────────────────────────────────────┐
│ Market Value   │  Current Listing      │
│ $37            │  $40                  │
│                                        │
│ ▲ 8% above market                     │
└────────────────────────────────────────┘
```

```
AFTER (Tier B):

Series-Level Estimate

┌────────────────────────────────────────┐
│ Series Avg.    │  Current Listing      │
│ $37            │  $40                  │
│                                        │
│ ▲ 8% above series avg.                │
└────────────────────────────────────────┘
```

```
AFTER (Tier A — unchanged):

┌────────────────────────────────────────┐
│ Market Value   │  Current Listing      │
│ $42            │  $48                  │
│                                        │
│ ▲ 14% above market                    │
└────────────────────────────────────────┘
```

---

## Part 4 — Collection Value Review

### Surfaces

1. `collection_summary_section.dart` — `Est. shelf value ~$612 / Based on 12 of 15 figures`
2. `shelf_value_card.dart` — `Shelf Value ~$612`, top-5 Most Valuable, By Series breakdown

---

### Does Collection currently overstate certainty?

**Partial yes.**

The existing signals that correctly communicate uncertainty:
- `Est.` prefix (Collection Home) ✓
- `~` tilde on the total (both surfaces) ✓
- `Based on X of Y figures` shows incomplete coverage ✓
- Per-figure `~` tilde in Most Valuable list when `isSeriesEstimate` ✓

**What is missing:**

The `Based on 12 of 15 figures` line does not distinguish whether those 12 figures are backed by figure-level snapshots (Tier A) or series averages (Tier B). A user with 12 series-estimate figures and 0 figure-level snapshots sees the same display as a user with 12 figure-level snapshots.

The `By Series` per-series total shows a clean dollar amount even when the total is derived entirely from series estimates.

---

### The conservative UX recommendation

**Do not change the total display.** The `~` prefix already signals approximation. Adding more qualifiers to a headline number risks alarming users without giving them actionable information.

**Add a single secondary signal when Tier B is in the mix:**

For the Collection Home glance (`_ShelfValueGlance`):

| Current | Recommended (when any figure is Tier B) |
|---------|----------------------------------------|
| `Based on 12 of 15 figures` | `Based on 12 of 15 figures · includes estimates` |

For the `ShelfValueCard` total (`_ValueOverview`):

| Current | Recommended (when any figure is Tier B) |
|---------|----------------------------------------|
| `Based on 12 of 15 figures` | `Based on 12 of 15 figures · some are series estimates` |

This is the most conservative option that still provides useful information. It does not alarm, does not remove data, and does not require restructuring. It tells the user the total may have more uncertainty than the `~` alone implies.

---

### Coverage bar recommendation

The current bar shows `N% coverage` (figure count coverage). No change recommended. The coverage bar communicates incompleteness; adding a second bar or segment for estimate quality would be visually cluttered without proportional trust benefit at this level.

---

### Most Valuable list recommendation

The per-figure `~` tilde for `isSeriesEstimate` is already correct and should be kept. No change needed.

---

### By Series breakdown recommendation

Add `~` prefix to the per-series dollar total in `_SeriesValueRow` when any contributing figure in that series is `isSeriesEstimate`. This requires `SeriesValueEntry` to carry a `hasSeriesEstimates` flag (or `seriesEstimateCount: int`).

```
CURRENT:
THE MONSTERS Big Into Energy    $183

AFTER (when some figures in that series use series estimates):
THE MONSTERS Big Into Energy    ~$183
```

This is a P1 change — it requires a domain model addition (`SeriesValueEntry.hasSeriesEstimates`) and a corresponding change in `collection_value_providers.dart` aggregation logic.

---

## Part 5 — Future Large-Format Collectibles

### The Blind Box model

Standard blind-box series have these characteristics relevant to market valuation:

- **Uniform format** — all figures in a series are the same scale and medium (e.g., 3" vinyl, pendant, plush)
- **High transaction volume** — popular regulars sell frequently on eBay; enough data for figure-level snapshots
- **Predictable price distribution** — regulars cluster around a series mean; secrets and chases are outliers that can be identified by ID
- **Series average meaningful as a floor** — even without a figure-specific snapshot, the series average is a rough lower bound for most figures

### Large-format categories

| Category | Examples | Price range (typical) |
|----------|----------|----------------------|
| MEGA 400% | BE@RBRICK 400%, Pop Mart MEGA 400% | $80–$350 |
| 1000% | BE@RBRICK 1000%, large display collectibles | $300–$2,000 |
| Designer vinyl statues | Kaws Companion, Medicom figures | $200–$5,000 |
| Standalone releases | Large IP figures, collaborations | $50–$500 |
| Artist proofs / signed | Limited edition variants | unpredictable |

### Why the series-estimate fallback breaks for large-format

**Problem 1 — Format types cannot share a series average**

A single IP (e.g., THE MONSTERS) releases both 3" blind-box figures ($25–$350) and MEGA 400% versions ($120–$280). These are catalogued under the same IP but are not the same product category. A series snapshot that blends formats produces an average that is meaningful for neither.

If `marketSnapshotProvider` falls back to a series snapshot for a MEGA 400% figure, and that series snapshot was computed from blind-box sales, the resulting `Series Avg. $42` displayed next to a MEGA listing that cost $180 retail is actively misleading — by a factor of 4×.

**Problem 2 — Structural sales volume differences**

MEGAs and statues are:
- Higher price → fewer transactions per period
- More collector-grade → condition, authentication, and packaging significantly affect price
- Less commodity → no meaningful "average" exists across units

A series-level snapshot for a MEGA line will always be `SnapshotConfidence.low` due to low `recentSalesCount`, and the computed estimate will often be based on 1–3 sales. The `Series-Level Estimate` label does not adequately communicate this level of uncertainty.

**Problem 3 — Series range is uninformative**

For a blind-box series, `Range $38–$48` tells the user something useful about regulars. For a MEGA series that includes multiple colorways, the range might be `Range $80–$400` — a 5× spread that provides no actionable pricing context.

**Problem 4 — The trust degradation compounds**

At the current P0 fixes, a Tier B large-format figure would show:

```
Series-Level Estimate

Series Avg.    Current Listing
$42            $180

▲ 329% above series avg.
```

This is technically more honest than the pre-remediation display, but it is still confusing and arguably harmful: a user sees `329% above series avg.` and wonders if they are being overcharged, when in reality the MEGA simply does not belong to the same price class as the series average.

---

### Recommended architecture boundary for large-format

**Near-term (no Firestore schema change):**

Introduce a `formatType` or `productTier` field on `CatalogFigure`. Possible values: `standard`, `mega`, `large_format`, `standalone`.

In `marketSnapshotProvider`, add a guard after the figure lookup:

```
if catalogFigure.productTier != standard:
    return null   // skip series fallback entirely
```

This ensures large-format figures land in Tier C (no match) rather than receiving a misleading Tier B series estimate. The user sees no market data rather than wrong market data. Trust > Coverage.

**Medium-term (with admin tooling investment):**

Create format-specific series snapshot documents:

```
market_snapshots / {seriesId}_standard / ...
market_snapshots / {seriesId}_mega / ...
```

This allows the pipeline to compute a MEGA-specific series average (which is at least comparing MEGAs to MEGAs) without contaminating the blind-box average. This is a schema-level change and requires admin tool updates.

**Long-term:**

Figure-level snapshots for MEGAs are the correct solution. Once MEGA transaction volume is sufficient, `getSnapshotForFigure()` returns a Tier A result and all trust issues resolve. The format-type exclusion gate is a bridge, not a destination.

---

### Standalone releases and artist proofs

These have no predictable price relationship to any "series" and should always return Tier C. The format-type exclusion gate above handles this correctly — any non-standard figure type skips the series fallback.

---

## Part 6 — Rollout Strategy

### Rollout priorities

```
P0 — Fix before any broader rollout or user-facing promotion of Market Intelligence
P1 — Implement before Collection Value is featured prominently (e.g., onboarding, sharing)
P2 — Implement as the catalog grows to include large-format figures
```

---

### P0 — Must fix before broader rollout

All three P0 items are contained to `market_snapshot_format.dart` and two screen files. They share a single underlying change: propagate `isSeriesEstimate` into display paths that currently ignore it.

**Recommended implementation order within P0:**

1. **`market_snapshot_format.dart` first** — Add `isSeriesEstimate` parameter to `formatMarketListingPriceDeltaLine()`. Update the constant `kMarketSnapshotDiscoverSeriesFallbackLabel` to the new string. Define new constants for Tier B delta strings. This is purely additive and the existing tests are the safety net.

2. **`market_snapshot_badge.dart` second** — Conditional heading based on `isSeriesEstimate`. Remove `*` from `formatMarketSnapshotSalesLine()` (or add a separate Tier-B-aware function). Both changes are local to the badge.

3. **`market_insights_screen.dart` third** — Update `_MarketInsightsContent` to pass `isSeriesEstimate` into the card column heading and delta line. Update `_MarketInsightsPurchaseDeltaLine` to receive and pass the flag.

**These three changes can be made in a single commit.** They are all wording changes, no logic changes, and all affected tests should be updated simultaneously.

---

### P1 — Strong trust improvements

| Item | Description | Prerequisite |
|------|-------------|--------------|
| P1-1 | `4 sales*` asterisk removal | P0 badge change (asterisk removed as part of P0-2 badge rework) |
| P1-2 | Collection total adds `· includes estimates` when Tier B is in the mix | **Implemented Sprint 3K** — `ShelfValueSummary.includesSeriesEstimates` + `coverageLabel` |
| P1-3 | `Using Series Estimate` → `Series-Level Estimate` label | Part of P0-3 (the two are adjacent; do together) |
| P1-4 | `_SeriesValueRow` adds `~` when series has series-estimate figures | **Implemented Sprint 3L** — `SeriesValueEntry.hasSeriesEstimates` |

P1-3 overlaps with P0-3 and should be done in the same pass. The remaining P1 items are independent and can be done in a follow-up sprint.

---

### P2 — Future enhancements

| Item | Description | Trigger |
|------|-------------|---------|
| P2-1 | Large-format exclusion gate | When `CatalogFigure` gains a `productTier` field |
| P2-2 | Minimum sales floor for `SnapshotConfidence.high` | Admin pipeline change; document in `market_snapshot.dart` |
| P2-3 | Freshness signal proximity | Move `Updated N ago` closer to the price in badge and insights screen |
| P2-4 | Format-specific series snapshots | When MEGA/large-format catalog coverage grows |

---

## Part 7 — Final Recommendation

### The question

> What is the most conservative market valuation UX that still provides useful information?

---

### The answer

The conservative UX maximizes trust by ensuring that:

1. **Vocabulary is tier-matched.** Users never encounter "market" language when the source is a series average. The distinction between `Market Value` and `Series Avg.` is not a pedantic footnote — it is the primary fact the user needs to evaluate the number.

2. **The primary label carries the trust signal, not a secondary chip.** A chip below the price is easy to miss. The heading above the price is always read. Trust signals belong in dominant positions.

3. **Purchase-context language is honest about its denominator.** `▲ 8% above series avg.` tells the user what the comparison actually is. It does not withhold information; it labels it correctly.

4. **Absence is preferred over fiction for large-format.** When a figure type structurally cannot produce a meaningful series average, Tier C (no match) is the correct and trust-preserving outcome. Showing nothing is more honest than showing `Series Avg. $42` for a $180 MEGA.

5. **Collection value signals are additive, not restructured.** The `~` prefix and `Est.` label are already correct. Adding `· includes estimates` to the coverage sub-label closes the last transparency gap without alarming or overcomplicating the display.

---

### What the remediated UI looks like at steady state

**Market Detail — Tier A (figure snapshot):**
```
$48
▲ 14% above market
```

**Market Detail — Tier B (series estimate):**
```
$40
▲ 8% above series avg.
(no Market Insights row — Sprint 3J)
```

**Market Insights — Tier A only** (Tier B cannot navigate here):
```
┌────────────────────────────────────────┐
│ Market Value   │  Current Listing      │
│ $42            │  $48                  │
│ ▲ 14% above market                    │
└────────────────────────────────────────┘
```

**Market Insights — Tier B:** Not reachable from Market Detail (Sprint 3J). Screen may still render series fallback if opened via dev/deep link; production entry is figure-snapshot only.

**MarketSnapshotBadge — Tier A:**
```
Market Value
$42
18 sales
$38–$48 range
Updated 35h ago
```

**MarketSnapshotBadge — Tier B:**
```
Series Avg. Value
$37
≈ Series Estimate
4 sales
$38–$48 range
Updated 35h ago
```

**Collection Home — with Tier B in mix:**
```
Est. shelf value    ~$612
                    Based on 12 of 15 figures · includes estimates
```

---

### What we are willing to give up

- **Checkmark on Tier B delta.** `✓ Below market` becomes `Below series avg.` — the affirming checkmark is removed because "below a series average" is not unconditionally a positive signal for a figure that may have its own distinct value.
- **Uniform delta vocabulary.** The delta line now uses different words depending on tier. This is a UX cost (less terse, slightly more to read) that is outweighed by the trust gain.
- **Clean collection totals.** Adding `· includes estimates` to the sub-label makes the display slightly busier. This is acceptable — it is the minimum signal needed to communicate quality uncertainty.

### What we preserve

- **Useful Tier B information is still shown.** Series averages provide a rough ballpark. We do not suppress them — we label them honestly. A collector comparing $40 to `Series Avg. $37` still gets context. They just know what they are looking at.
- **Tier A is unchanged and fully authoritative.** `Market Value $42 / ▲ 14% above market` remains exactly as designed for figure-level snapshots.
- **Architecture is unchanged.** The remediation is purely vocabulary. No new providers, repositories, routes, or Firestore queries.

---

## Sprint 3M-B — Shelf Value Transparency Info Sheet (P0-2)

**Status:** Implemented June 2026  
**Audit reference:** `tools/market_intel/VALUATION_TRANSPARENCY_AUDIT.md` — P0-2

### What shipped

- Inline `Icons.info_outline` on the **Shelf Value** section header in `shelf_value_card.dart` (Collection Insights only).
- Tapping opens `showShelfValueInfoSheet` → `ShelfValueInfoSheet` modal bottom sheet via `showCollectibleBottomSheet`.
- Copy explains figure snapshot vs series estimate, `~`, `includes estimates`, exclusions, and eBay data source.

### Files

| File | Role |
|------|------|
| `lib/features/collection/insights/widgets/shelf_value_info_sheet.dart` | Sheet widget + `showShelfValueInfoSheet` |
| `lib/features/collection/insights/widgets/shelf_value_card.dart` | ⓘ on `_SectionHeader` for Shelf Value |
| `test/shelf_value_info_sheet_test.dart` | Widget tests (icon, tap, copy) |

### Constraints honored

- No valuation math, provider, repository, Firestore, or routing changes.
- No copy changes outside the new disclosure sheet.
- Educational tone only — no warning language.

### Screenshots

`tools/market_intel/screenshots/sprint_3m/`


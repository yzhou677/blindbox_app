# Sprint 3N-E — Non-Blind-Box Tier B Vocabulary (Implementation Plan)

**Date:** 2026-06-16  
**Type:** Audit + implementation plan only — **no code changes in this sprint.**  
**Scope:** User-facing copy when `snapshot.isSeriesEstimate == true` **and** `catalogSeries.isBlindBox == false`.  
**Out of scope:** Valuation math, series fallback logic, providers, repositories, Firestore schema, snapshot pipeline, matching, routing.

---

## Problem

Tier B is architecturally valid for non-blind-box SKUs (figure miss → series hit). The **number** can be right; the **words** are wrong.  
`Series Avg.` implies blind-box averaging across multiple random pulls. MEGA / 400% / standalone products are single-SKU items — users think in terms of **that product's market estimate**, not a series average.

**Production today:** 0 non-blind-box Tier B cases (no series snapshots for `isBlindBox: false` series). This is **latent** copy risk when the pipeline adds series-level docs.

---

## 1 — Complete Tier B string inventory

### Central constants (`market_snapshot_format.dart`)

| Constant / output | Current string | Tier |
|-------------------|----------------|------|
| `kMarketSnapshotSeriesAvgLabel` | `Series Avg.` | B label |
| `kMarketSnapshotSeriesAvgValueBadgeHeading` | `Series Avg. Value` | B badge heading |
| `kMarketSnapshotSeriesEstimateLabel` | `Series Estimate` | B chip |
| `kMarketSnapshotInsightsSeriesLevelEstimateLabel` | `Series-Level Estimate` | B insights banner |
| `formatMarketSnapshotDiscoverSummaryLine` (series branch) | `Series Avg. · $37 · 4 sales` | B Discover |
| `formatMarketListingPriceDeltaLine` (above) | `▲ N% above series avg.` | B delta |
| `formatMarketListingPriceDeltaLine` (below) | `Below series avg.` | B delta |
| `formatMarketListingPriceDeltaLine` (near) | `≈ Near series avg.` | B delta |

### Disclosure / semantics (`market_series_average_info_sheet.dart`)

| Constant | Current string |
|----------|----------------|
| `kMarketSeriesAverageInfoSemanticsLabel` | `About series average pricing` |
| `kMarketSeriesAverageInfoSheetTitle` | `About series average pricing` |
| Body paragraph 1 | *"This comparison uses marketplace activity from the same series, not sales of this specific figure."* |
| Body paragraph 2 | *"Within a blind-box series, regular figures…"* |
| Body paragraph 3 | *"Use series averages as a general reference…"* |

### Shelf Value education (`shelf_value_info_sheet.dart`)

| String | Context |
|--------|---------|
| `Series Estimate` (section heading) | Tier B concept in shelf disclosure |
| *"Based on marketplace activity from the same series when figure-specific data is limited."* | Tier B explanation |
| *"includes estimates" means some figures used **series averages** instead of figure-specific sales.* | Coverage footnote |

### Shelf Value display (`shelf_value_summary.dart` / `shelf_value_card.dart`)

| String | Tier B related? |
|--------|-----------------|
| `Based on N of M figures · includes estimates` | Indirect — no "Series Avg." literal |
| `~$` prefix on figure/series rows when `isSeriesEstimate` / `hasSeriesEstimates` | Visual only — **not in scope** (not wording change per sprint) |

### Unchanged Tier B-adjacent strings (no fork needed)

| String | Why unchanged |
|--------|----------------|
| `Market Information` / `▶ Market Information` | Disclosure heading — tier-neutral |
| `Market Value` | Tier A only |
| `above market` / `Below market` / `At market` | Tier A only |
| `Market Insights` nav row | Hidden for all Tier B (`MarketInsightsNavigationEntry`) |

### Dev-only (update for consistency, low priority)

| Surface | Strings |
|---------|---------|
| `MarketSnapshotBadge` | `Series Avg. Value`, `≈ Series Estimate` |
| `market_snapshot_dev_screen.dart` | Uses badge |

---

## 2 — Which formatter decides Tier A vs Tier B wording?

**Primary:** `lib/features/market_intel/widgets/market_snapshot_format.dart`

| Function / constant | Tier gate today |
|---------------------|-----------------|
| `formatMarketSnapshotDiscoverSummaryLine` | `snapshot.isSeriesEstimate` |
| `formatMarketListingPriceDeltaLine` | `isSeriesEstimate` parameter |
| Label constants | Used when `isSeriesEstimate` / series branch |

**Secondary (inline, not formatters):**

| Widget | Branch |
|--------|--------|
| `market_snapshot_badge.dart` | `snapshot.isSeriesEstimate` |
| `market_insights_screen.dart` `_MarketInsightsPurchaseContext` | `snapshot.isSeriesEstimate` |
| `market_series_average_info_sheet.dart` | Shown only when Tier B delta + info icon |

**Tier A vs Tier B is decided by domain:** `MarketSnapshot.isSeriesEstimate` → `level == SnapshotLevel.series` (`market_snapshot.dart:40`).

**There is no formatter branch for `isBlindBox` today.**

---

## 3 — Is `CatalogSeries.isBlindBox` available at render time?

**Yes — via in-memory catalog cache, without provider or repository changes.**

### Data-flow proof

```
Firestore market_snapshots/{seriesId}
  → FirestoreMarketSnapshotRepository.getSnapshotForSeries()
  → MarketSnapshot { seriesId, level: series, isSeriesEstimate: true }
  → marketSnapshotProvider(figureId)
       (already uses CatalogBundleCache to resolve seriesId fallback)
  → Widget (MarketListingPriceDeltaLine, gallery accordion, etc.)
  → NEW: resolveCatalogSeries(snapshot.seriesId)
       → CatalogBundleCache.current
       → CatalogSeries.isBlindBox
  → Wording branch
```

**Evidence catalog cache is already in the provider path:**

```23:35:lib/features/market_intel/application/market_snapshot_providers.dart
    final bundle = CatalogBundleCache.current;
    if (bundle == null) return null;

    CatalogFigure? catalogFigure;
    for (final figure in bundle.figures) {
      if (figure.id == trimmedId) {
        catalogFigure = figure;
        break;
      }
    }
    if (catalogFigure == null) return null;

    return repo.getSnapshotForSeries(catalogFigure.seriesId);
```

**`MarketSnapshot` always carries `seriesId`** (`market_snapshot.dart:30`) — sufficient for catalog lookup on both figure and series snapshot documents.

**`CatalogSeries.isBlindBox`** is on the catalog model (`catalog_series.dart:25`) and populated from Firestore / seed via `fromJson`.

**Precedent:** `resolveMarketInsightsFigureContext()` already reads `CatalogBundleCache.current` for header copy (`market_insights_figure_context.dart:27-45`).

### Lookup helper (proposed)

```dart
// lib/features/market_intel/widgets/market_snapshot_vocabulary.dart

enum MarketSnapshotWordingMode {
  figureSnapshot,           // Tier A
  blindBoxSeriesEstimate,   // Tier B + isBlindBox == true
  standaloneSeriesEstimate, // Tier B + isBlindBox == false
}

CatalogSeries? lookupCatalogSeries(String seriesId) { ... }

MarketSnapshotWordingMode resolveWordingMode(MarketSnapshot snapshot) {
  if (!snapshot.isSeriesEstimate) return figureSnapshot;
  final series = lookupCatalogSeries(snapshot.seriesId);
  if (series != null && !series.isBlindBox) return standaloneSeriesEstimate;
  return blindBoxSeriesEstimate; // default when series unknown
}
```

**Default when catalog missing:** `blindBoxSeriesEstimate` — preserves current copy (safe for offline / stale cache). Log debug assert in tests when series not found.

---

## 4 — Smallest architecture-safe branching model

### Three-way model

| Mode | Condition | Value label | Delta above | Delta below | Delta near | Chip / banner |
|------|-----------|-------------|-------------|-------------|------------|---------------|
| **Tier A** | `!isSeriesEstimate` | Market Value | above market | Below market | At market | — |
| **Tier B blind-box** | `isSeriesEstimate && isBlindBox` | Series Avg. *(unchanged)* | above series avg. | Below series avg. | Near series avg. | Series Estimate / Series-Level Estimate |
| **Tier B non-blind-box** | `isSeriesEstimate && !isBlindBox` | **Estimated Value** | **above estimate** | **below estimate** | **near estimate** | **Market Estimate** / **Market Estimate** banner |

### Proposed target copy (non-blind-box Tier B)

| Surface | Current | Target |
|---------|---------|--------|
| Discover summary | `Series Avg. · $X · N sales` | `Estimated Value · $X · N sales` |
| Market Detail delta | `▲ N% above series avg.` | `▲ N% above estimate` |
| Market Detail delta | `Below series avg.` | `Below estimate` |
| Market Detail delta | `≈ Near series avg.` | `≈ Near estimate` |
| Info sheet title | `About series average pricing` | `About this estimate` |
| Info sheet semantics | same | `About this estimate` |
| Insights banner | `Series-Level Estimate` | `Market Estimate` |
| Insights value column | `Series Avg.` | `Estimated Value` |
| Badge heading (dev) | `Series Avg. Value` | `Estimated Value` |
| Badge chip (dev) | `≈ Series Estimate` | `≈ Market Estimate` |

### Implementation strategy (minimal diff)

1. **Add** `market_snapshot_vocabulary.dart` — mode resolution + label functions (keeps `market_snapshot_format.dart` as thin wrappers for backward-compatible call sites).
2. **Change formatters** to accept `MarketSnapshot` (not just `isSeriesEstimate: bool`) OR accept `MarketSnapshotWordingMode` — resolve mode inside formatter from snapshot.
3. **Parameterize disclosure sheet** — `MarketSeriesEstimateInfoSheet(isBlindBoxSeries: bool)` with two body copy variants; blind-box body keeps current paragraphs; standalone uses SKU-focused copy (*"This estimate reflects marketplace activity for this product when figure-specific sales are limited."*).
4. **Do not touch** `marketSnapshotProvider`, `collectionValueProvider`, `ValuedFigure`, or `~` prefix logic.
5. **Tests** — table-driven cases in `market_snapshot_format_test.dart` for three modes; one widget test for non-blind-box delta + info sheet title.

---

## 5 — Files affected

| File | Change |
|------|--------|
| **NEW** `lib/features/market_intel/widgets/market_snapshot_vocabulary.dart` | Mode enum, catalog lookup, label getters |
| `lib/features/market_intel/widgets/market_snapshot_format.dart` | Delegate to vocabulary; extend `formatMarketListingPriceDeltaLine` / `formatMarketSnapshotDiscoverSummaryLine` |
| `lib/features/market_intel/widgets/market_series_average_info_sheet.dart` | Parameterize title + body; rename show helper optional |
| `lib/features/market_intel/widgets/market_detail_insights_section.dart` | Pass `isBlindBox` to info sheet; resolve mode for delta (via formatter) |
| `lib/features/market_intel/presentation/market_insights_screen.dart` | Use vocabulary labels in Tier B branch |
| `lib/features/market_intel/widgets/market_snapshot_badge.dart` | Use vocabulary labels (dev consistency) |
| `lib/features/collection/insights/widgets/shelf_value_info_sheet.dart` | Add standalone-product sentence OR rename "Series Estimate" section to dual bullet (P2 — see below) |
| `test/market_snapshot_format_test.dart` | +3 mode cases |
| `test/market_insights_screen_test.dart` | +non-blind-box Tier B case |
| `test/catalog_figure_gallery_market_snapshot_test.dart` | +standalone summary case |
| `test/market_snapshot_badge_test.dart` | +standalone badge case |
| `test/shelf_value_info_sheet_test.dart` | Optional disclosure copy update |

**Not affected:** providers, repositories, mappers, pipeline, routing, `market_insights_figure_context.dart` (header uses figure/series display names only).

---

## 6 — Screens that change

| Screen / surface | When copy changes | Example |
|------------------|-------------------|---------|
| **Market Detail** | Tier B + `!isBlindBox` | Mega 400% listing: `▲ 12% above estimate` + ⓘ → `About this estimate` |
| **Discover gallery** | Tier B + `!isBlindBox` accordion expanded | `Estimated Value · $1,240 · 6 sales` |
| **Market Insights** | Tier B + `!isBlindBox` *(if screen opened — dev/direct only today)* | `Market Estimate` banner, `Estimated Value` column |
| **Market Snapshot Badge** | Dev screen only | `Estimated Value` / `≈ Market Estimate` |

---

## 7 — Screens that remain unchanged

| Screen / surface | Why |
|------------------|-----|
| **Market Detail — Tier A** | `Market Value` / `above market` |
| **Market Detail — Tier B blind-box** | Hope-style Big Into Energy — keep `Series Avg.` |
| **Market Detail — Tier C** | No snapshot → no lines |
| **Market Insights nav row** | Hidden for all Tier B (unchanged policy) |
| **Discover — Tier A** | `Market Value · …` |
| **Discover — Tier C** | Accordion hidden |
| **Shelf Value totals** | `~` prefix and math unchanged |
| **Shelf Value — `includes estimates`** | Generic footnote *(optional P2 copy tweak in info sheet only)* |
| **Collection / catalog / search** | No market snapshot copy |

---

## 8 — Migration risk assessment

| Risk | Severity | Mitigation |
|------|----------|------------|
| **Zero production UI change today** | None | No non-blind-box Tier B snapshots exist |
| **Catalog cache null offline** | Low | Default to blind-box wording |
| **Series missing from cache** | Low | Default to blind-box wording; figureId fallback lookup optional |
| **`isBlindBox` wrong in catalog** | Medium | Catalog admin truth — same as rest of app |
| **Test churn** | Low | Table-driven formatter tests |
| **Shelf info sheet ambiguity** | Low | P2: add one bullet distinguishing standalone vs blind-box estimates |
| **Regression on Hope / Big Into Energy** | Medium | Explicit blind-box regression tests — strings must not change |
| **i18n** | None today | English constants only — same pattern as Sprint 3I |

**Rollback:** Revert vocabulary file; formatters return to `isSeriesEstimate` bool branch only.

---

## 9 — Exact implementation plan (ordered tasks)

### Step 1 — Vocabulary module (~0.5d)

- Create `market_snapshot_vocabulary.dart` with `MarketSnapshotWordingMode`, `resolveWordingMode(MarketSnapshot)`, and getters:
  - `valueLabel(mode)` → `Market Value` | `Series Avg.` | `Estimated Value`
  - `deltaAbove(mode, pct)` / `deltaBelow(mode)` / `deltaNear(mode)`
  - `insightsBannerLabel(mode)` → `null` | `Series-Level Estimate` | `Market Estimate`
  - `estimateChipLabel(mode)` → `Series Estimate` | `Market Estimate`
  - `infoSheetTitle(mode)` → `About series average pricing` | `About this estimate`

### Step 2 — Formatters (~0.5d)

- `formatMarketSnapshotDiscoverSummaryLine(snapshot)` → resolve mode internally
- `formatMarketListingPriceDeltaLine(price, estimate, {MarketSnapshot? snapshot, bool? isSeriesEstimate})` → prefer snapshot for mode; deprecate bool-only overload in tests
- Keep exported constants for blind-box; add parallel constants for standalone

### Step 3 — Disclosure sheet (~0.5d)

- Add `isBlindBoxSeries` parameter to `MarketSeriesAverageInfoSheet`
- Blind-box: current body copy unchanged
- Standalone: replace blind-box paragraph with product-level estimate explanation
- `MarketListingPriceDeltaLine`: resolve mode from snapshot → pass to `showMarketSeriesEstimateInfoSheet(context, isBlindBoxSeries: …)`

### Step 4 — Insights + badge (~0.25d)

- Replace inline `kMarketSnapshotSeriesAvgLabel` ternaries with vocabulary getters

### Step 5 — Tests (~0.5d)

- Formatter: 3×3 delta matrix (above/below/near × A / B-blind / B-standalone)
- Widget: `MarketListingPriceDeltaLine` with mock non-blind-box catalog series + series snapshot
- Regression: Hope / Luck blind-box strings unchanged

### Step 6 — Shelf info sheet (optional P2, ~0.25d)

- Add bullet: *"Standalone products (e.g. MEGA, statues) may show a market estimate instead of a series average."*
- Or split "Series Estimate" heading into "Series or product estimate"

**Total estimate:** ~2 days.

---

## 10 — Acceptance criteria

- [ ] Blind-box Tier B (Hope / Big Into Energy): **byte-identical** user strings vs today
- [ ] Non-blind-box Tier B: no string contains `series avg` or `Series Avg`
- [ ] Tier A: unchanged
- [ ] No changes to `marketSnapshotProvider`, valuation providers, or Firestore
- [ ] `flutter analyze` + affected tests green

---

## Appendix — Formatter call graph

```
marketSnapshotProvider(figureId)
  └─ MarketSnapshot
       ├─ MarketListingPriceDeltaLine
       │    └─ formatMarketListingPriceDeltaLine
       │    └─ showMarketSeriesAverageInfoSheet (Tier B only)
       ├─ catalog_figure_gallery_sheet
       │    └─ formatMarketSnapshotDiscoverSummaryLine
       ├─ market_insights_screen (direct route / dev)
       │    └─ vocabulary labels + formatMarketListingPriceDeltaLine
       └─ collectionValueProvider → ShelfValueCard
            └─ ~ prefix only (no Series Avg. string)
```

**Catalog join point (new):** `resolveWordingMode(snapshot)` reads `CatalogBundleCache.current` + `snapshot.seriesId` → `CatalogSeries.isBlindBox`.

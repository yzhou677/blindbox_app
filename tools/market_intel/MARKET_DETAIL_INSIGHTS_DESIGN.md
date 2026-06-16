# Market Detail Insights — Sprint 3C / 3C.1 / 3D

Sold-data `MarketSnapshot` intelligence for Market Listing Detail and the dedicated Market Insights screen. No Browse/Collection/Discover changes beyond Market Detail navigation.

---

## Final architecture

```
MarketDetailScreen (_MarketDetailBody)
        │
        ├─ marketListingInsightsFigureId(listing)
        │
        ├─ MarketListingPriceDeltaLine          ← under ask price
        │       └─ marketSnapshotProvider(figureId)
        │
        └─ MarketInsightsNavigationEntry          ← below View listing CTA
                ├─ marketSnapshotProvider(figureId)
                └─ hidden when snapshot.isSeriesEstimate
                └─ push /market/insights?figureId=&listingId= (figure snapshot only)

MarketInsightsScreen
        │
        └─ marketSnapshotProvider(figureId)
                └─ marketSnapshotRepositoryProvider
                        ├─ FirestoreMarketSnapshotRepository (release)
                        ├─ DevMockMarketSnapshotRepository (debug default)
                        └─ (future) EbaySoldDataMarketSnapshotRepository
```

Widgets watch Riverpod providers only; no Firestore or repository calls in presentation code.

**Sprint 3D verification:** Provider chain unchanged. Repository swap remains dependency-injection only via `marketSnapshotRepositoryProvider`.

---

## Provider flow

1. `MarketListing.catalogMatch.matchedFigureId` → `marketListingInsightsFigureId()`.
2. When figure id is present, detail shows price delta for Tier A and Tier B.
3. **Market Insights** navigation row appears only when snapshot resolves to a **figure snapshot** (`!snapshot.isSeriesEstimate`). Series estimates keep the delta line but cannot open `MarketInsightsScreen` (Sprint 3J — Trust > Coverage).
4. Row pushes `/market/insights?figureId=…&listingId=…` via `marketInsightsRoute()`.
5. `MarketInsightsScreen` watches `marketSnapshotProvider(figureId)`.
6. Provider loads figure snapshot via `MarketSnapshotRepository.getSnapshotForFigure`.
7. On miss, provider resolves catalog figure → `getSnapshotForSeries(seriesId)` (unchanged series fallback).

When `matchedFigureId` is absent (Tier C), delta and navigation row are omitted.

---

## Market Detail layout (Sprint 3D)

```
Photo / title / metadata
Price
Above / Below / At market delta
View listing CTA
────────────────────
Market Insights        >     ← figure snapshot only (Sprint 3J)
```

Series estimate listings show the delta line (`▲ N% above series avg.`) but **no** Market Insights row.

No market data, info icon, or dialog on Market Detail.

---

## Market Insights screen layout (Sprint 3F / trust wording Sprint 3I)

Route: `/market/insights` (query: `figureId`, `listingId`)

**Header** — catalog figure thumb + name + series from `resolveMarketInsightsFigureContext()` (listing + in-memory catalog only; no extra repository calls).

**Series fallback** — `Series-Level Estimate` once, between header and purchase context (not repeated elsewhere).

**Purchase context summary** — compact card directly below header / series label:

Tier A (figure snapshot):

```
Market Value          Current Listing
$42                   $48

▲ 14% above market
```

Tier B (series estimate):

```
Series Avg.           Current Listing
$37                   $40

▲ 8% above series avg.
```

Uses `listing.currentPriceUsd` from `marketListingByIdProvider(listingId)` and `formatMarketListingPriceDeltaLine(..., isSeriesEstimate:)` — tier-aware vocabulary only; no new comparison logic.

**Activity & metadata** (market value appears only in purchase context card):

```
18 recent sales · Trending

Range $38–$48
Updated 35h ago

Data Source
eBay marketplace activity

Data is currently estimated from eBay listings and sales activity.
Other marketplaces are not included.
```

No per-field label/value dashboard blocks beyond purchase context. No dialogs or info icons.

---

## UI states (Market Insights screen)

| State | Behavior |
|-------|----------|
| Loading | Header visible; compact value skeleton |
| Error / null | Header visible; `Market insights unavailable` |
| Data present | Collector-focused layout above |

Price delta on detail: hidden while loading / on error (unchanged).

---

## Offline-first verification

| Scenario | Result |
|----------|--------|
| Snapshot available | Insights screen renders from provider |
| Loading | Skeleton on insights screen; detail unchanged |
| Error / null | Unavailable copy on insights screen |
| No connection | Async provider handles; no network in widgets |

Works with `DevMockMarketSnapshotRepository` and `FirestoreMarketSnapshotRepository` without UI branching.

---

## Future eBay sold-data API swap

Replace `MarketSnapshotRepository` implementation only — UI and providers unchanged.

---

## Files

| File | Role |
|------|------|
| `lib/features/market/market_detail_screen.dart` | Delta + navigation row |
| `lib/features/market_intel/application/market_listing_insights.dart` | Figure id + route helper |
| `lib/features/market_intel/application/market_insights_figure_context.dart` | Header metadata resolver |
| `lib/features/market_intel/presentation/market_insights_screen.dart` | Dedicated insights screen |
| `lib/features/market_intel/widgets/market_insights_navigation_row.dart` | Detail navigation row |
| `lib/features/market_intel/widgets/market_detail_insights_section.dart` | Price delta widget |
| `lib/features/market_intel/widgets/market_snapshot_format.dart` | Screen formatters + copy |
| `lib/core/router/app_router.dart` | `/market/insights` route |
| `test/market_insights_screen_test.dart` | Screen + nav + delta tests |
| `test/market_snapshot_format_test.dart` | Formatter unit tests |

---

## Screenshots

**Sprint 3E before/after:** `tools/market_intel/screenshots/sprint_3e/before/` and `sprint_3e/after/`

| File | Scenario |
|------|----------|
| `2_market_insights_screen.png` | Figure snapshot (light) |
| `3_market_insights_series_estimate.png` | Series fallback |
| `4_market_insights_dark_mode.png` | Dark mode |

Captured via `tools/market_intel/capture_sprint_3e_device_screenshots.py` on a debug build with `--dart-define=MARKET_GATEWAY_EBAY=false --dart-define=MARKET_FIXTURE_SOURCE=true`.

**Sprint 3F purchase context:** `tools/market_intel/screenshots/sprint_3f/`

| File | Scenario |
|------|----------|
| `1_market_insights_above_market.png` | Soymilk listing $48 vs $42 estimate |
| `2_market_insights_below_market.png` | Lychee Berry listing $35 vs $38 estimate |
| `3_market_insights_at_market.png` | Luck listing $42 vs $42 estimate |
| `4_market_insights_series_estimate.png` | Hope series fallback |
| `5_market_insights_dark_mode.png` | At-market (Luck) dark mode |

Captured via `tools/market_intel/capture_sprint_3f_device_screenshots.py` on the same debug build flags.

**Sprint 3I trust vocabulary:** `tools/market_intel/screenshots/sprint_3i/`

| File | Scenario |
|------|----------|
| `1_discover_tier_a.png` | Luck — `Market Value · $42 · 18 sales` |
| `2_discover_tier_b.png` | Hope — `Series Avg. · $37 · 4 sales` |
| `3_market_detail_tier_a.png` | Soymilk — `▲ 14% above market` |
| `4_market_detail_tier_b.png` | Hope — `▲ 8% above series avg.` |
| `5_market_insights_tier_a.png` | Luck — `Market Value` purchase context |
| `6_market_insights_tier_b.png` | Hope — `Series-Level Estimate` / `Series Avg.` |
| `7_dark_mode_tier_b.png` | Hope series fallback — dark mode |

Captured via `tools/market_intel/capture_sprint_3i_device_screenshots.py` on the same debug build flags.

**Sprint 3J Market Insights gating:** `tools/market_intel/screenshots/sprint_3j/`

| File | Scenario |
|------|----------|
| `1_market_detail_tier_a_with_insights.png` | Soymilk — `▲ 14% above market` + Market Insights row visible |
| `2_market_detail_tier_b_no_insights.png` | Hope — `▲ 8% above series avg.`; no Market Insights row |
| `3_market_insights_tier_a.png` | Luck — Market Insights screen still reachable (Tier A) |
| `4_market_detail_tier_b_no_navigation_path.png` | Hope — scrolled detail; no path to Market Insights |

Captured via `tools/market_intel/capture_sprint_3j_device_screenshots.py` on the same debug build flags.

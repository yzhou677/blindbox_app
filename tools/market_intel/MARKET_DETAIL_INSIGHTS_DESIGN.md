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
        └─ MarketInsightsNavigationRow          ← below View listing CTA
                └─ push /market/insights?figureId=&listingId=

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
2. When figure id is present, detail shows price delta + **Market Insights >** navigation row.
3. Row pushes `/market/insights?figureId=…&listingId=…` via `marketInsightsRoute()`.
4. `MarketInsightsScreen` watches `marketSnapshotProvider(figureId)`.
5. Provider loads figure snapshot via `MarketSnapshotRepository.getSnapshotForFigure`.
6. On miss, provider resolves catalog figure → `getSnapshotForSeries(seriesId)` (unchanged series fallback).

When `matchedFigureId` is absent, delta and navigation row are omitted.

---

## Market Detail layout (Sprint 3D)

```
Photo / title / metadata
Price
Above / Below / At market delta
View listing CTA
────────────────────
Market Insights        >
```

No market data, info icon, or dialog on Market Detail.

---

## Market Insights screen layout

Route: `/market/insights` (query: `figureId`, `listingId`)

**Figure snapshot**

| Section | Example |
|---------|---------|
| Market Value | $42 |
| Recent Sales | 18 |
| Range | $38–$48 |
| Trend | Trending |
| Updated | 35h ago |
| Data Source | eBay marketplace activity |

**Series fallback** — `Using Series Estimate` once at top; same sections below.

**Footer** (no modal):

> Data is currently estimated from eBay listings and sales activity.  
> Other marketplaces are not included.

---

## UI states (Market Insights screen)

| State | Behavior |
|-------|----------|
| Loading | Section skeleton |
| Error / null | `Market insights unavailable` |
| Data present | Sectioned layout + footer |

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
| `lib/features/market_intel/presentation/market_insights_screen.dart` | Dedicated insights screen |
| `lib/features/market_intel/widgets/market_insights_navigation_row.dart` | Detail navigation row |
| `lib/features/market_intel/widgets/market_detail_insights_section.dart` | Price delta widget |
| `lib/features/market_intel/widgets/market_snapshot_format.dart` | Screen formatters + copy |
| `lib/core/router/app_router.dart` | `/market/insights` route |
| `test/market_insights_screen_test.dart` | Screen + nav + delta tests |
| `test/market_snapshot_format_test.dart` | Formatter unit tests |

---

## Screenshots

`tools/market_intel/screenshots/sprint_3d/`

| File | Scenario |
|------|----------|
| `1_market_detail_navigation_row.png` | Detail with Market Insights > row |
| `2_market_insights_screen.png` | Figure snapshot insights screen |
| `3_market_insights_series_estimate.png` | Series fallback |
| `4_market_insights_dark_mode.png` | Insights screen (dark mode) |

Captured via `tools/market_intel/capture_sprint_3d_device_screenshots.py` on a debug build with `--dart-define=MARKET_GATEWAY_EBAY=false --dart-define=MARKET_FIXTURE_SOURCE=true`.

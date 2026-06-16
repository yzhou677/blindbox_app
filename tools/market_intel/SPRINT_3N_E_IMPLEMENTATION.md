# Sprint 3N-E — Implementation Summary

**Date:** 2026-06-16  
**Scope:** Non-blind-box Tier B vocabulary only (copy). No math, providers, Firestore, routing, or fallback changes.

---

## Vocabulary implemented

| Tier | Value label | Delta (above) | Info sheet |
|------|-------------|---------------|------------|
| A | Market Value | above market | — |
| B blind-box | Series Avg. | above series avg. | About series average pricing |
| B non-blind-box | Market Estimate | above market estimate | About this market estimate |

Sales count on Discover (`N sales`) unchanged — still reflects `recentSalesCount` from the snapshot document; scope clarification lives in the info sheet body.

---

## Files changed

| File | Change |
|------|--------|
| `lib/features/market_intel/widgets/market_snapshot_format.dart` | `resolveIsBlindBoxSeries()`, tier label helpers, branched formatters |
| `lib/features/market_intel/widgets/market_series_average_info_sheet.dart` | `isBlindBoxSeries` param; dual title/body copy |
| `lib/features/market_intel/widgets/market_detail_insights_section.dart` | Pass `seriesId`; tier-aware info sheet |
| `lib/features/market_intel/presentation/market_insights_screen.dart` | Tier-aware banner/value/delta labels |
| `lib/features/market_intel/widgets/market_snapshot_badge.dart` | Tier-aware heading/chip (dev screen) |
| `test/market_snapshot_format_test.dart` | Tier A / B blind / B standalone regression |
| `test/market_snapshot_badge_test.dart` | + standalone badge test |
| `test/market_insights_screen_test.dart` | + standalone insights/delta/sheet tests |
| `test/catalog_figure_gallery_market_snapshot_test.dart` | + standalone Discover summary test |

---

## Architecture

- **No** `market_snapshot_vocabulary.dart` — branching in `market_snapshot_format.dart` only.
- Catalog join: `MarketSnapshot.seriesId` → `CatalogBundleCache.current` → `CatalogSeries.isBlindBox`.
- Default when series missing: blind-box wording (Hope regression safe).

---

## Tests

```bash
flutter test test/market_snapshot_format_test.dart \
  test/market_snapshot_badge_test.dart \
  test/market_insights_screen_test.dart \
  test/catalog_figure_gallery_market_snapshot_test.dart
```

**Result:** 66 tests passed.

```bash
flutter analyze lib/features/market_intel
```

**Result:** No issues found.

---

## Screenshots

Production Firestore still has **0** non-blind-box Tier B snapshots — device screenshots require mock/dev seed or future pipeline data.

**Widget-test coverage (string verification):**

| Surface | Test |
|---------|------|
| Discover | `non-blind-box series fallback shows market estimate summary` |
| Market Detail delta + sheet | `non-blind-box series estimate uses market estimate delta and sheet` |
| Market Insights | `non-blind-box series fallback shows market estimate labels` |
| Badge (dev) | `non-blind-box series fallback shows market estimate indicator` |

Blind-box regression: Hope / Big Into Energy strings byte-identical in dedicated tests.

**Device capture (when data exists):** follow `tools/market_intel/capture_sprint_3m_device_screenshots.py` pattern with `MARKET_SNAPSHOT_LIVE=true` and a non-blind-box series snapshot in Firestore.

---

## Unchanged

- `marketSnapshotProvider`, repositories, Firestore schema
- Valuation math, `~` prefix, collection calculations
- Market Insights nav (hidden for all Tier B)
- Tier A and blind-box Tier B user-facing strings

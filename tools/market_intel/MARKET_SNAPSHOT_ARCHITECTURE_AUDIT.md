# Market Snapshot Architecture Audit — Sprint 3B.1

Audit date: 2026-06-15  
Scope: Sprint 2 (Discover market information) + Sprint 3 (Collection Value) + Sprint 3B.1 navigation cleanup.

---

## Executive summary

The sold-data **Market Snapshot** stack remains **Clean Architecture compliant**, **repository-driven**, and **swappable** between mock and Firestore without UI changes. Debug builds default to `DevMockMarketSnapshotRepository`; production uses `FirestoreMarketSnapshotRepository`.

**Not yet connected:** eBay Finding / Browse / Sold Items APIs — architecture supports a future `EbayMarketSnapshotRepository` implementing the same domain interface.

**Known gap:** No persistent offline cache for sold-data snapshots (Firestore reads are async; mock is in-memory). UI degrades gracefully to empty states when data is unavailable.

---

## 1. Clean Architecture

### Intended layers

```
UI (widgets / screens)
  ↓ ref.watch
Application (Riverpod providers)
  ↓ ref.read(repository)
Domain (MarketSnapshot, MarketSnapshotRepository)
  ↓ implements
Data (FirestoreMarketSnapshotRepository, DevMockMarketSnapshotRepository)
```

### Verified call paths

| Surface | Widget | Provider | Repository access |
|---------|--------|----------|-------------------|
| Discover gallery accordion | `catalog_figure_gallery_sheet.dart` | `marketSnapshotProvider` | via provider only |
| Collection home glance | `collection_summary_section.dart` | `collectionValueProvider` → `marketSnapshotProvider` | via provider only |
| Collection insights card | `shelf_value_card.dart` | `collectionValueProvider` | via provider only |
| Dev validation screen | `market_snapshot_dev_screen.dart` | `marketSnapshotProvider` | via provider only |

### Violations found

**None.** Grep confirms no `firestore` imports under:

- `lib/features/market_intel/widgets/`
- `lib/features/collection/insights/widgets/`
- `lib/features/collection/widgets/collection_summary_section.dart`
- `lib/features/catalog/presentation/figure_gallery/`

Repository binding is centralized:

- Default: `marketSnapshotRepositoryProvider` → `FirestoreMarketSnapshotRepository` (`market_snapshot_providers.dart`)
- Debug override: `main.dart` → `DevMockMarketSnapshotRepository` when `kMarketSnapshotRepositoryUsesMock`

### Domain purity

- `MarketSnapshot` and `MarketSnapshotRepository` live in `domain/` with no Flutter/Firestore imports.
- `ShelfValueSummary` / `ValuedFigure` are collection-side view models — aggregation rules stay in `collection_value_providers.dart`, not widgets.

---

## 2. Offline-first behavior

| Surface | Network down | Firestore down | Mock (debug) |
|---------|--------------|----------------|--------------|
| Discover Market Information | Provider returns null → accordion hidden | Same | In-memory mock → full UX |
| Collection home value glance | Hidden when `valuedCount == 0` | Same | Shows ~$117 etc. with mock |
| Collection Insights ShelfValueCard | Empty state copy | Same | Full card with mock |
| Catalog browse / shelf | Unaffected (local codec + bundled catalog) | Unaffected | Unaffected |

### Gaps

1. **No snapshot disk cache** — unlike catalog images, `MarketSnapshot` is not persisted locally. Re-fetch on every provider lifecycle. Acceptable for MVP; recommend in-memory + TTL cache at repository layer before eBay migration.
2. **`collectionValueProvider` fans out N async reads** — large shelves may feel slow on first load. Future: batch repository method `getSnapshotsForFigureIds`.
3. **Series fallback requires `CatalogBundleCache.current`** — if catalog bundle failed to load, figure-level miss won't fall back to series snapshot. Edge case only.

---

## 3. Future eBay API migration

### Current abstraction

```dart
abstract class MarketSnapshotRepository {
  Future<MarketSnapshot?> getSnapshotForFigure(String figureId);
  Future<MarketSnapshot?> getSnapshotForSeries(String seriesId);
  Future<List<MarketSnapshot>> getSnapshotsForSeries(String seriesId);
}
```

### Swap path (no UI changes required)

| Phase | Implementation | Wiring |
|-------|----------------|--------|
| Now (dev) | `DevMockMarketSnapshotRepository` | `main.dart` override when `kMarketSnapshotRepositoryUsesMock` |
| Now (prod) | `FirestoreMarketSnapshotRepository` | Default in `marketSnapshotRepositoryProvider` |
| Future | `EbayMarketSnapshotRepository` | Replace provider binding; map eBay sold stats → `MarketSnapshot` |

UI widgets consume `marketSnapshotProvider` and `collectionValueProvider` only — **no coupling to data source**.

### Separate universe warning

`CollectibleMarketSnapshot` (Market **Browse** intelligence from live listings) is a **different model** in `lib/features/market/`. Do not merge with sold-data `MarketSnapshot` without an explicit adapter. Sprint 3 Collection Value uses sold-data intel only.

---

## 4. Technical debt review

### Removed / cleaned in 3B.1

- Removed duplicate Collection Home entries (`Reveal collector type`, `Shelf value breakdown`) — single `Collection insights >` remains; Collector Type reveal lives on Insights screen only
- Obsolete screenshots: `4_partial_coverage_no_data.png`, `debug_mock_home.png`, pre-cleanup home captures

### Retained (intentional, dev-only)

| Item | Location | Notes |
|------|----------|-------|
| `DevMockMarketSnapshotRepository` | `lib/features/market_intel/dev/` | Remove when Firestore seed is stable in all envs |
| `market_snapshot_dev_screen.dart` | dev/ | `--dart-define=MARKET_SNAPSHOT_DEV=true` |
| `kMarketSnapshotRepositoryUsesMock` | `market_snapshot_dev_config.dart` | Debug default; override with `MARKET_SNAPSHOT_LIVE=true` |

### Not dead — do not delete

- `FirestoreMarketSnapshotRepository` — production path
- `MARKET_SNAPSHOT_SURFACE_REFACTOR.md` — canonical Discover UX doc
- `COLLECTION_VALUE_DESIGN.md` — Collection Value design (updated for 3B.1 nav)

### Pre-existing unrelated debt (out of scope)

- `CollectibleMarketSnapshot` browse intelligence not wired to Collection Value (by design)
- 4 failing tests in `market_intel_snapshot_provider_test.dart` (badge widget) — pre-existing

---

## 5. Navigation (Sprint 3B.1)

**Before:** Multiple entry rows on Collection Home (`Reveal collector type`, `Shelf value breakdown`) → same destination  
**After:** One `Collection insights >` row inside summary card. Collector Type reveal is **not** duplicated on Home — it appears only on the Insights screen.

Collection Insights page order unchanged:

1. Collector Type  
2. Collector Journey  
3. Shelf Value  

---

## 6. Mock data for UI validation

Debug builds use `DevMockMarketSnapshotRepository` with Exciting Macaron figure snapshots:

- Chestnut Cocoa ~$210  
- Soymilk ~$42  
- Lychee Berry ~$38  
- Green Grape ~$37  

Partial coverage demo: own 5 figures, 3 with snapshots → **~$117, Based on 3 of 5 figures**.

Force live Firestore: `--dart-define=MARKET_SNAPSHOT_LIVE=true`

---

## Confirmation checklist

- [x] Clean Architecture compliant — UI → Provider → Repository → Data Source  
- [x] Offline-first for shelf/catalog; snapshot intel degrades gracefully  
- [x] Mock → Firestore → future eBay swappable via `MarketSnapshotRepository`  
- [x] No new architectural regressions in Sprint 3B.1 navigation cleanup  

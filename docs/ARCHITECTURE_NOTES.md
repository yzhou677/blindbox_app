# Architecture Notes

Operational decisions and future assumptions captured so we do not re-investigate the same topics months later.

**Related docs:**

- [`.cursor/ARCHITECTURE.md`](../.cursor/ARCHITECTURE.md) — full agent/contributor architecture reference (three universes, folder layout, data flow)
- [`KNOWN_RUNTIME_NOTES.md`](KNOWN_RUNTIME_NOTES.md) — logcat / debug console noise vs actionable failures
- [`COLLECTION_ARCHITECTURE_NOTES.md`](COLLECTION_ARCHITECTURE_NOTES.md) — Collection maintenance-mode tradeoffs (snapshot persistence, journey history, collector identity)
- [`EBAY_GATEWAY.md`](EBAY_GATEWAY.md) — live gateway configuration; notes identity skip on default path
- [`FIREBASE_LOCAL_SETUP.md`](FIREBASE_LOCAL_SETUP.md) — Firebase / SHA local setup

---

## Firestore Authoritative Catalog

### Current behavior

Catalog metadata (`brands`, `ips`, `series`, `figures`) is loaded through [`CatalogBundleCache`](../lib/features/catalog/application/catalog_bundle_cache.dart).

**After the first successful Firestore sync**, Firestore is the **authoritative** catalog source. Bundled seed is bootstrap/offline fallback only — not the long-term source of truth.

### Startup order

1. **Persisted catalog bundle** — last successful Firestore snapshot on disk (`{ApplicationSupport}/catalog_bundle_cache/catalog_bundle_v1.json`), when available
2. **Seed bundle** — `tools/seed/` JSON, **only** before the device has ever completed a successful Firestore sync
3. **Background Firestore refresh** — stale-while-revalidate; updates in-memory bundle and re-persists on success

If synced before but persisted file is missing/corrupt: empty in-memory bundle until refresh succeeds (edge case).

### Deletions and seed resurrection

Once a successful Firestore sync has been **persisted**, entries **deleted from Firestore must not reappear** from bundled seed on subsequent cold starts. Persisted snapshot replaces seed as the offline baseline.

### Why this architecture was introduced

Previously, cold start always loaded bundled seed first and Firestore refresh only updated **memory**. After a Firestore deletion, the next app restart could still show removed series/figures from seed until the user went online again — confusing for operators who expected Firestore edits to stick.

Persistence after successful Firestore fetch makes offline cold start reflect the last known cloud catalog and stops deleted entries from resurrecting from seed.

### Implementation notes

- Memory + listener notification happen **before** disk persist; persist failure must not block UI refresh ([`_commitFirestoreBundle`](../lib/features/catalog/application/catalog_bundle_cache.dart)).
- Debug startup logs: `CatalogBundleCache: startup source=persisted|seed|empty|memory origin=<CatalogBundleMemoryOrigin>` and `refresh source=firestore origin=...` (see [`KNOWN_RUNTIME_NOTES.md`](KNOWN_RUNTIME_NOTES.md)).
- **Not catalog sync:** user shelf (`CollectionNotifier`) remains local-first and independent.

### Catalog bundle readiness (`CatalogBundleMemoryOrigin`)

[`CatalogBundleCache`](../lib/features/catalog/application/catalog_bundle_cache.dart) tracks **where the in-memory bundle came from** with a single enum — no parallel placeholder flag. Provenance and readiness cannot drift.

```dart
enum CatalogBundleMemoryOrigin {
  none,                   // no bundle in memory
  bootstrapPlaceholder,   // only non-ready state with a memory slot
  seed,
  persisted,
  firestore,
  resolved,               // fallbacks exhausted; lists may still be empty
}
```

- **`hasValue`** — `_bundle != null` (includes `bootstrapPlaceholder`)
- **`isCatalogReady`** — `memoryOrigin.isCatalogReady` (`!= none` and `!= bootstrapPlaceholder`)
- **Debug logs** — `origin=<name>` on startup and refresh lines

#### Mental model (readiness ladder)

```
No bundle (none)
      │
      │  loadOfflineFirst — synced before, no persisted snapshot
      ▼
Bootstrap placeholder          ← not catalog-ready; getOrLoad() must wait
      │
      │  refresh / getOrLoad network path completes
      ▼
Ready (catalog-ready)
 ├─ seed            first install / never synced
 ├─ persisted       disk snapshot on cold start
 ├─ firestore       successful Firestore fetch (refresh or getOrLoad)
 └─ resolved        refresh/load failed after placeholder (may be empty lists)
```

`seed` and `persisted` are **ready immediately** on cold start — they skip the placeholder rung. Only the post-sync / no-persist edge case enters `bootstrapPlaceholder`.

#### Cold-start paths (from `none`)

```
                    loadOfflineFirst()
                           │
         ┌─────────────────┼─────────────────┐
         ▼                 ▼                 ▼
    persisted            seed      bootstrapPlaceholder
    (disk hit)      (never synced)   (synced, no disk)
         │                 │                 │
    catalog-ready     catalog-ready     NOT catalog-ready
         │                 │                 │
         └────────┬────────┘                 │
                  │              ┌───────────┴───────────┐
                  │              ▼                       ▼
                  │         firestore              resolved
                  │      (refresh OK)          (refresh/load fail)
                  │              │                       │
                  └──────────────┴───────────────────────┘
                                 │
                          all catalog-ready
```

Background refresh can later move `seed` / `persisted` → `firestore` when Firestore succeeds. `onBundleReplaced` fires on that commit.

#### Caller contract

| `memoryOrigin` | `loadOfflineFirst()` | `getOrLoad()` |
|----------------|----------------------|---------------|
| `persisted` | Returns disk snapshot; starts background refresh | Returns immediately |
| `seed` | Returns seed; starts background refresh | Returns immediately |
| `bootstrapPlaceholder` | Returns empty for offline-first paint; starts background refresh | **Does not** return early — awaits `_refreshInFlight` or shared network load |
| `firestore` | Returns memory bundle | Returns immediately |
| `resolved` | Returns empty | Returns empty (no duplicate fetch) |

This prevents the race where `loadOfflineFirst()` sets an empty bootstrap bundle, background Firestore refresh starts, and a concurrent `getOrLoad()` returns the empty slot before refresh finishes. Removing bundled seed bootstrap would expose that race without this guard.

**Related:** `CatalogBundleLoadSource` (`persisted` / `seed` / `empty` / `memory`) is for **startup debug logging only** — it describes which branch `loadOfflineFirst()` took, not ongoing memory provenance.

---

## Market Identity Architecture

### Components (retained in codebase)

| Component | Role |
|-----------|------|
| [`MarketCatalogIdentityCache`](../lib/features/market/data/market_catalog_identity_cache.dart) | In-memory install of catalog bundle as identity index |
| [`CatalogIdentityIndex`](../lib/features/market/data/catalog_identity_index.dart) | Offline figure/series/brand/IP lookup for title matching |
| [`MarketIdentityMatcher`](../lib/features/market/application/market_identity_matcher.dart) | Listing title → `MarketListing.catalogMatch` |
| [`enrichBrowseListingsIdentity`](../lib/features/market/application/market_listing_identity_enricher.dart) | Batch attach `catalogMatch` before aggregation |

Installed at startup in [`main.dart`](../lib/main.dart): `MarketCatalogIdentityCache.install(catalogBundle)`.

### Default production runtime reality (verified audit)

When **`MARKET_GATEWAY_EBAY=true`** (default), the live browse path **skips** identity enrichment:

```
MarketLiveBrowseController._commitInstall
  → installLiveBrowseListings()   // does NOT call enrichBrowseListingsIdentity
  → applyQueryTaxonomyHints only
  → buildCollectibleMarketSnapshots()
```

**Implication:** Default production Market feed behaves primarily as **eBay listings + snapshot wrapper** — one card per listing (`listingFallback` tier), not catalog-driven figure/series merge.

`catalogMatch` is null on listings entering the aggregator on this path.

### Where identity enrichment still runs

| Path | When |
|------|------|
| [`market_listings_bootstrap.dart`](../lib/features/market/data/market_listings_bootstrap.dart) | Gateway **inactive** — loads fixture/offline sources |
| [`market_browse_refresh_controller.dart`](../lib/features/market/application/market_browse_refresh_controller.dart) | Gateway off, non-sandbox refresh |
| [`market_sandbox_browse_install.dart`](../lib/features/market/application/market_sandbox_browse_install.dart) | `MARKET_SANDBOX_MERCARI=true` |

Also used by [`resolveCollectibleMarketDisplay`](../lib/features/market/application/collectible_market_display_resolver.dart) for catalog figure/series labels when snapshot identity has matched ids (uncommon on live gateway today).

### Explicit retention note

> **Do not remove** `MarketCatalogIdentityCache`, `CatalogIdentityIndex`, or `MarketIdentityMatcher` solely because the default gateway path currently bypasses them.

They remain useful for sandbox flows, fixture flows, gateway-disabled paths, display resolver catalog lookups, relationship hints on enriched listings, and **potential future catalog grouping** on live eBay (would require wiring `enrichBrowseListingsIdentity` into `installLiveBrowseListings` — skipped today for UI-isolate performance).

### Stale cache after catalog refresh (B3)

`MarketCatalogIdentityCache` is installed once at startup and is **not** automatically rebuilt when `CatalogBundleCache` replaces the bundle. Impact is limited to non-gateway enrichment paths and market display name lookup — not catalog sync or collection filter chips.

---

## Custom Figure ID Assumptions

### Current format

```
{seriesId}-f-{index}
```

Defined in [`CustomSeriesConventions.figureImageKey`](../lib/features/collection/data/custom_series_conventions.dart).

- **`addCustomSeries`:** `index` increments per figure added (empty draft names skipped without consuming index).
- **`addCustomFigure`:** `index = existing.figures.length` (append at end).

Same value used for `ShelfFigure.id` and `ShelfFigure.imageKey` on custom rows.

### Current assumptions

- **Append-only** figure creation — no `removeCustomFigure` API today
- Figure IDs must be **unique within a series**; `figureStates` map keys are global `figureId` strings (series id prefix keeps cross-series uniqueness)
- Dense indices `f-0 … f-{n-1}` hold while only appending

### Future: figure deletion

If figure deletion is introduced, **`figures.length` as next index will collide** with existing ids (e.g. delete `f-1`, later add gets `f-2` while `f-2` may already exist). Orphaned `figureStates` entries could also resurrect ownership on id reuse.

**Revisit ID strategy when adding deletion**, e.g.:

- `max(parsedIndex) + 1` from existing figure ids
- Persistent `nextFigureIndex` on `ShelfSeries`
- Always remove `figureStates[figureId]` on delete

**No action required today** — append-only flows are safe.

---

## Brand / IP Canonicalization Rules

### Save-time pipeline

1. [`CollectionInputSanitizer`](../lib/features/collection/data/collection_input_sanitizer.dart) — trim, collapse whitespace; **does not change casing**
2. [`CollectionTaxonomyCanonicalizer`](../lib/features/collection/data/collection_taxonomy_canonicalizer.dart) — match against `BrandTaxonomyRegistry` / `IpTaxonomyRegistry`

### Display behavior

| Input type | `series.brand` / `series.ipName` (display) | `taxonomyBrandId` / `taxonomyIpId` (filter/insights) |
|------------|---------------------------------------------|--------------------------------------------------------|
| **Known registry** (e.g. `pop mart`, `POPMART`) | Canonical registry name (e.g. `POP MART`, `THE MONSTERS`) | Registry id (e.g. `pop_mart`, `the_monsters`) |
| **Unknown custom** (e.g. `My Wife Brand`, `POP`) | **Preserve user-entered casing** (after sanitize) | Slug id (e.g. `my_wife_brand`, `pop`) |
| **Empty brand** | `Independent` | `independent` |

### Intentional decoupling

- **Display layer** — what the user sees on shelf cards, sheet chrome, and most chip labels
- **Taxonomy layer** — canonical ids for filter chips, insights, journey depth, relationship hints

Filtering uses **normalized keys** ([`normalizeCollectionFacetFilterKey`](../lib/features/collection/presentation/collection_shelf_brand_facets.dart)) and **taxonomy ids** — not raw display casing.

**Do not** automatically title-case or uppercase unknown custom brands/IPs. Known registry hits may normalize to registry styling (e.g. `POP MART`).

### Examples

| User enters | Stored display | Taxonomy id |
|-------------|----------------|-------------|
| `pop mart` | `POP MART` | `pop_mart` |
| `the monsters` | `THE MONSTERS` | `the_monsters` |
| `My Indie Label` | `My Indie Label` | `my_indie_label` |

---

## Collection Feature Status

### Collection core — feature complete (maintenance mode)

See also [`COLLECTION_ARCHITECTURE_NOTES.md`](COLLECTION_ARCHITECTURE_NOTES.md) for persistence tradeoffs and journey semantics.

**Implemented:**

| Area | Notes |
|------|-------|
| Custom Series | Create via `addCustomSeries` |
| Edit Series | Metadata, cover, notes, advanced brand/IP |
| Add Figure | `addCustomFigure` from edit sheet (Phase 2.8) |
| Edit Figure | Name, secret, rarity, local image |
| Figure images | `localImageUri` on shelf only |
| Insights | Shelf emotional profile, summary |
| Journey | Historical exploration metrics |
| Brand / IP filters | Collection shelf chip facets |
| Offline-first catalog | Persisted bundle + seed fallback + background refresh |
| Firestore authoritative catalog sync | See [Firestore Authoritative Catalog](#firestore-authoritative-catalog) |

**Low priority / not currently planned:**

| Feature | Rationale |
|---------|-----------|
| Figure deletion | No user-facing remove flow; ID strategy assumes append-only (see [Custom Figure ID Assumptions](#custom-figure-id-assumptions)) |
| Figure reordering | Shelf order follows creation index; reorder adds complexity without current product ask |

Future work: bug fixes, UX polish, catalog content expansion, performance profiling — not major Collection rewrites unless usage triggers thresholds in `COLLECTION_ARCHITECTURE_NOTES.md`.

---

*Last updated: 2026-06 — reflects catalog persistence sync, add-figure edit flow, and market gateway identity audit.*

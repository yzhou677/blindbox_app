# Architecture Notes

Operational decisions and future assumptions captured so we do not re-investigate the same topics months later.

**Related docs:**

- [`CATALOG_ARCHITECTURE.md`](CATALOG_ARCHITECTURE.md) — **catalog architecture spec** (data flow, state machine, provider graph, Search V2, alias policy)
- [`.cursor/ARCHITECTURE.md`](../.cursor/ARCHITECTURE.md) — full agent/contributor architecture reference (three universes, folder layout, data flow)
- [`KNOWN_RUNTIME_NOTES.md`](KNOWN_RUNTIME_NOTES.md) — logcat / debug console noise vs actionable failures
- [`COLLECTION_ARCHITECTURE_NOTES.md`](COLLECTION_ARCHITECTURE_NOTES.md) — Collection maintenance-mode tradeoffs (snapshot persistence, journey history, collector identity)
- [`EBAY_GATEWAY.md`](EBAY_GATEWAY.md) — live gateway configuration; notes identity skip on default path
- [`FIREBASE_LOCAL_SETUP.md`](FIREBASE_LOCAL_SETUP.md) — Firebase / SHA local setup

---

## Firestore Authoritative Catalog

### Current behavior

Catalog metadata (`brands`, `ips`, `series`, `figures`) is loaded through [`CatalogBundleCache`](../lib/features/catalog/application/catalog_bundle_cache.dart).

**Firestore is the canonical catalog source.** Persisted on-device cache is the offline baseline after the first successful sync.

### Startup order

1. **Persisted catalog bundle** — last successful Firestore snapshot on disk (`{ApplicationSupport}/catalog_bundle_cache/catalog_bundle_v1.json`), when available → **catalog-ready** immediately + background Firestore refresh
2. **Bootstrap placeholder** — empty in-memory slot when no persisted snapshot → **not catalog-ready** until Firestore refresh or `getOrLoad()` network path completes
3. **Background Firestore refresh** — stale-while-revalidate; updates in-memory bundle and re-persists on success

If refresh fails after placeholder: `origin=resolved` (may be empty lists) → first-launch availability UX (offline + Retry).

### Offline baseline

Once a successful Firestore sync has been **persisted**, cold start serves the persisted snapshot offline. Deleted Firestore entries do not reappear on subsequent launches.

### Why persistence was introduced

Previously, Firestore refresh only updated **memory**. After a Firestore deletion, the next cold start could still show removed series until the user went online again.

Persistence after successful Firestore fetch makes offline cold start reflect the last known cloud catalog.

### Implementation notes

- Memory + listener notification happen **before** disk persist; persist failure must not block UI refresh ([`_commitFirestoreBundle`](../lib/features/catalog/application/catalog_bundle_cache.dart)).
- Debug startup logs: `CatalogBundleCache: startup source=persisted|empty|memory origin=<CatalogBundleMemoryOrigin>` and `refresh source=firestore origin=...` (see [`KNOWN_RUNTIME_NOTES.md`](KNOWN_RUNTIME_NOTES.md)).
- **Not catalog sync:** user shelf (`CollectionNotifier`) remains local-first and independent.

### Catalog bundle readiness (`CatalogBundleMemoryOrigin`)

[`CatalogBundleCache`](../lib/features/catalog/application/catalog_bundle_cache.dart) tracks **where the in-memory bundle came from** with a single enum — no parallel placeholder flag. Provenance and readiness cannot drift.

```dart
enum CatalogBundleMemoryOrigin {
  none,                   // no bundle in memory
  bootstrapPlaceholder,   // only non-ready state with a memory slot
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
      │  loadOfflineFirst — no persisted snapshot
      ▼
Bootstrap placeholder          ← not catalog-ready; getOrLoad() must wait
      │
      │  refresh / getOrLoad network path completes
      ▼
Ready (catalog-ready)
 ├─ persisted       disk snapshot on cold start
 ├─ firestore       successful Firestore fetch (refresh or getOrLoad)
 └─ resolved        refresh/load failed after placeholder (may be empty lists)
```

`persisted` is **ready immediately** on cold start when disk has a valid snapshot.

#### Cold-start paths (from `none`)

```
                    loadOfflineFirst()
                           │
              ┌────────────┴────────────┐
              ▼                         ▼
         persisted              bootstrapPlaceholder
         (disk hit)              (no disk snapshot)
              │                         │
         catalog-ready              NOT catalog-ready
              │                         │
              │              ┌──────────┴──────────┐
              │              ▼                     ▼
              │         firestore            resolved
              │      (refresh OK)        (refresh/load fail)
              │              │                     │
              └──────────────┴─────────────────────┘
                             │
                      all catalog-ready
```

Background refresh can later move `persisted` → `firestore` when Firestore succeeds. `onBundleReplaced` fires on that commit.

#### Runtime propagation (provider graph)

When the in-memory bundle is replaced, [catalogBundleRevisionProvider](../lib/features/catalog/application/catalog_bundle_provider.dart) bumps and **all dependents rebuild declaratively** — no per-feature `ref.invalidate` list.

```
CatalogBundleCache._commitFirestoreBundle
        │
        ▼
addBundleReplacedListener → catalogBundleRevisionProvider (state++)
        │
        ├── catalogBundleProvider (FutureProvider re-reads cache)
        │        ├── catalogSearchServiceProvider
        │        ├── addSeriesCatalogRecommendationsProvider
        │        ├── homeFeedSnapshotProvider → homeSeriesReleaseLookupProvider
        │        └── collectibleRelationshipProviders (already watched bundle)
        │
        └── MarketCatalogIdentityCache.install (same bundle, no duplicate index)
```

[`CatalogBundleRefreshBridge`](../lib/features/home/application/catalog_bundle_refresh_bridge.dart) only keeps the revision notifier alive for the app lifetime; it does not invalidate individual features.

#### Caller contract

| `memoryOrigin` | `loadOfflineFirst()` | `getOrLoad()` |
|----------------|----------------------|---------------|
| `persisted` | Returns disk snapshot; starts background refresh | Returns immediately |
| `bootstrapPlaceholder` | Returns empty for offline-first paint; starts background refresh | **Does not** return early — awaits `_refreshInFlight` or shared network load |
| `firestore` | Returns memory bundle | Returns immediately |
| `resolved` | Returns empty | Returns empty (no duplicate fetch) |

This prevents the race where `loadOfflineFirst()` sets an empty bootstrap bundle, background Firestore refresh starts, and a concurrent `getOrLoad()` returns the empty slot before refresh finishes.

**Related:** `CatalogBundleLoadSource` (`persisted` / `empty` / `memory`) is for **startup debug logging only** — it describes which branch `loadOfflineFirst()` took, not ongoing memory provenance.

---

## Catalog runtime architecture

End-to-end path from cloud catalog to feature surfaces. This is the mental model to use when adding anything that reads catalog metadata at runtime.

```
Firestore
        │
        ▼
CatalogBundleCache
        │
        ▼
catalogBundleRevisionProvider
        │
        ▼
catalogBundleProvider
        │
        ├──────── Search          (catalogSearchServiceProvider, catalog browse)
        ├──────── Home            (homeFeedSnapshotProvider)
        ├──────── Collection      (shelf search, relationship providers)
        ├──────── Market          (MarketCatalogIdentityCache.install)
        ├──────── Add Series      (addSeriesCatalogRecommendationsProvider)
        └──────── Future features (new providers on catalogBundleProvider)
```

**Week-one gap (historical):** `CatalogBundleCache` → `???` → features (ad hoc caches, direct Firestore/loader calls in widgets, manual `ref.invalidate`). **Now:** the `???` is the revision bump + `catalogBundleProvider` graph — one declarative propagation path.

Readiness (`CatalogBundleMemoryOrigin`), placeholder semantics, and the low-level listener wiring live under [Firestore Authoritative Catalog](#firestore-authoritative-catalog) above.

### Catalog-derived runtime objects

Any runtime object derived from catalog metadata (`CatalogSearchService`, identity indexes, relationship graphs, lookup tables, recommendation pickers, etc.) **must** be provided through Riverpod providers that depend on [`catalogBundleProvider`](../lib/features/catalog/application/catalog_bundle_provider.dart).

- **Do not** manually cache catalog-derived state in widget fields, `late` singletons, or `initState` one-shot loads.
- **Do not** refresh catalog-derived state imperatively (`ref.invalidate(homeFeedSnapshotProvider)` per feature, `onBundleReplaced` feature lists, etc.).
- **Do** add a `Provider` / `FutureProvider` that `ref.watch(catalogBundleProvider)` (or a provider that watches it) and let bundle replacement propagate naturally.

When adding something like `RelationshipIndex`, the first instinct should be **`final relationshipIndexProvider = Provider(...)`**, not `late RelationshipIndex _index` installed once at startup.

**Exception (boundary, not a second cache):** [`MarketCatalogIdentityCache`](../lib/features/market/data/market_catalog_identity_cache.dart) remains the runtime slot for enricher code paths that run outside `WidgetRef`. It is **re-installed from the same bundle** when `catalogBundleRevisionProvider` bumps — not a separate source of truth.

---

## Performance Characteristics

Documented after a Collection rendering audit (2026). **No runtime changes implied** — this section records why the current architecture is acceptable today, what it assumes, and when to revisit.

**Related:** [`SEARCH_ARCHITECTURE.md`](SEARCH_ARCHITECTURE.md) · [`COLLECTION_ARCHITECTURE_NOTES.md`](COLLECTION_ARCHITECTURE_NOTES.md) · [`TECH_DEBT.md`](TECH_DEBT.md) (future opportunities)

### Why the current implementation is acceptable

Shelfy’s catalog is currently on the order of **~343 series / ~2,435 figures** (Firestore reference data). User shelves are typically much smaller (tens to low hundreds of series). At these sizes, measured behavior is smooth: widget construction is lazy, pre-render work is linear over small `n`, and normal Collection browsing does not hit the network.

The codebase intentionally favors **readable, predictable pipelines** over caching layers that would only pay off at substantially larger scale.

### Collection rendering

[`CollectionScreen`](../lib/features/collection/collection_screen.dart) uses a **`CustomScrollView`** with mixed slivers.

**Main shelf list — lazy widget construction**

- In-progress and Completed buckets each render via **`SliverList.builder`** when their section is expanded.
- Feed rows are driven by a flat `List<ShelfFeedItem>` from [`buildShelfFeedItems`](../lib/features/collection/presentation/shelf_series_feed.dart); [`buildShelfFeedItemWidget`](../lib/features/collection/presentation/shelf_series_feed.dart) builds one header, gap, or [`SeriesShelfCard`](../lib/features/collection/widgets/series_shelf_cards.dart) per visible index.
- Off-screen series cards are **not** built or laid out. This avoids eagerly constructing hundreds of shelf cards even when a user’s shelf is large.

**Legacy path (not used on the main screen):** [`buildShelfSeriesFeed`](../lib/features/collection/presentation/shelf_series_feed.dart) returns eager `Column` trees — retained for tests only. Production uses `buildShelfFeedItems` + `SliverList.builder`.

**Fixed chrome — always built**

Search field, Summary, filter chip rails, bucket headers, and editorial copy sit in `SliverToBoxAdapter` (or small fixed `Column`s). Filter rails use horizontal `ListView.separated` (lazy per chip). This overhead is bounded and independent of shelf scroll depth.

### Current eager pipeline (intentional tradeoff)

Before any `SliverList.builder` item is built, `CollectionScreen.build()` runs a **single-pass browse pipeline** over the filtered shelf subset:

| Stage | Location | Complexity |
|-------|----------|------------|
| Brand filtering | [`collection_shelf_brand_facets.dart`](../lib/features/collection/presentation/collection_shelf_brand_facets.dart) | O(n) shelf |
| IP filtering | [`collection_shelf_ip_facets.dart`](../lib/features/collection/presentation/collection_shelf_ip_facets.dart) | O(n) shelf |
| Search filtering | [`filterShelfSeriesBySearch`](../lib/features/collection/presentation/collection_shelf_browse.dart) | O(n) shelf; with active query, catalog match set is O(figures) |
| Partition | [`partitionShelfSeries`](../lib/features/collection/presentation/collection_shelf_browse.dart) | O(n) shelf |
| Sort (per bucket) | [`sortShelfSeriesForDisplay`](../lib/features/collection/presentation/collection_shelf_browse.dart) | O(n log n) typical; includes IP grouping for most sort modes |
| Grouping + feed flatten | [`buildShelfFeedItems`](../lib/features/collection/presentation/shelf_series_feed.dart) | O(n) shelf; [`groupShelfSeriesByUniverse`](../lib/features/collection/presentation/shelf_series_feed.dart) + per-series progress/atmosphere |
| Summary aggregation | [`CollectionAggregateStats.fromSnapshot`](../lib/features/collection/widgets/collection_summary_section.dart) → [`countShelfCompletionTiers`](../lib/features/collection/domain/series_completion_resolution.dart) | O(n) full shelf |
| Editorial interpretation | [`shelf_emotional_providers.dart`](../lib/features/collection/application/shelf_emotional_providers.dart) (profile, relationship insights, whispers) | O(n) full shelf per rebuild |

Search text is **debounced** (125 ms) so the pipeline does not re-run on every keystroke; filters, sort, collapse, and provider updates still trigger full pipeline runs.

[`ShelfBrowseProgressLookup`](../lib/features/collection/domain/collection_domain.dart) memoizes per-series progress **within a single `build()`** — it does not persist across rebuilds.

**This is an intentional tradeoff:** for current shelf sizes, O(n) work over the user’s shelf is cheap relative to the cost of extra caching, invalidation, and stale-state bugs. Code simplicity and correctness are preferred until profiling or usage proves otherwise.

### Search

Search V2 ([`lib/core/search/`](../lib/core/search/), [`CatalogSearchService`](../lib/features/catalog/search/catalog_search_service.dart)) performs **linear, in-memory matching** over the catalog bundle held in RAM.

- Tokenization, normalization, and AND-matching scan figures (and derived series ids) synchronously on device.
- No Elasticsearch, SQLite FTS, or remote search index in the local path.
- **Acceptable today** at ~2.5k figures: scans complete in sub-frame time on target devices for typical queries.
- Shelf-side search reuses [`catalogSearchServiceProvider`](../lib/features/catalog/application/catalog_bundle_provider.dart) when the bundle is loaded; custom rows fall back to display-field haystack matching.

Future indexing (inverted index, trie, etc.) should be considered **only** if catalog size or profiling shows user-visible search latency — see [`TECH_DEBT.md`](TECH_DEBT.md).

### Firestore architecture (browsing is memory-only)

**Firestore is not queried during normal Collection browsing.**

Runtime catalog flow:

```
Firestore
  → persisted cache (Application Support, after successful sync)
  → CatalogBundleCache (in-memory + stale-while-revalidate refresh)
  → catalogBundleRevisionProvider / catalogBundleProvider
  → catalogSearchServiceProvider, home feeds, shelf search, etc.
  → UI
```

Collection shelf rows come from **`CollectionNotifier`** (SharedPreferences codec) — not Firestore. Filtering, sorting, grouping, and feed construction operate on in-memory shelf + catalog objects only. Network I/O is limited to catalog refresh TTL / user-initiated retry, not per-scroll or per-filter.

### Growth assumptions

The current implementation assumes:

| Assumption | Order of magnitude (today) | Revisit when |
|------------|----------------------------|--------------|
| Catalog figures in memory | Low thousands (~2.5k) | Approaching **10k–20k+** figures or search latency in profiling |
| User shelf series | Hundreds or less | Consistently **~1,000+** series per user |
| Rebuild frequency | Moderate (filters, sort, debounced search, provider updates) | Rebuild work becomes **user-visible** (jank, frame drops) in profiling |
| Editorial / summary work | Simple O(n) scans per rebuild | Interpretation logic grows substantially or runs hot in traces |

These assumptions should be re-evaluated if product usage, catalog content, or power-user shelf sizes change significantly — not preemptively.

### Engineering principle

Shelfy intentionally avoids premature optimization. Performance work should be driven by **profiling and real-world usage** rather than hypothetical future scale. Until measurable bottlenecks appear, maintaining readable, predictable architecture is preferred over introducing additional complexity.

### App-wide pipeline log prefixes

Debug pipeline profilers share a naming convention via [`AppPipelinePrefix`](../lib/core/debug/app_pipeline_log.dart) and [`AppPipelineLog`](../lib/core/debug/app_pipeline_log.dart):

| Prefix | Tab / surface | Status |
|--------|----------------|--------|
| `CollectionPipeline` | Collection shelf browse | **Shipped** — [`CollectionShelfPipelineTrace`](../lib/features/collection/debug/collection_shelf_pipeline_trace.dart) |
| `MarketPipeline` | Market browse/search | Planned (legacy debug: `MarketSearch` in [`market_search_trace.dart`](../lib/features/market/debug/market_search_trace.dart)) |
| `DiscoverPipeline` | Discover home | Planned |
| `FeedPipeline` | Home feed assembly | Planned |

**Log line shape:** `{Prefix} #{run} [{tag}] {message}`

**Grep / filter:** `Pipeline` surfaces all tab profilers; narrow with `CollectionPipeline [search]`, `MarketPipeline [warn]`, etc.

New pipeline traces should use `AppPipelineLog.line` + `AppPipelineLog.nextRun` so run ids and tags stay consistent across tabs.

### Debug profiling (`CollectionPipeline`)

In **debug builds only**, [`CollectionScreen`](../lib/features/collection/collection_screen.dart) wraps each browse-pipeline stage with [`CollectionShelfPipelineTrace`](../lib/features/collection/debug/collection_shelf_pipeline_trace.dart). Each rebuild gets a monotonic run id (`#12`) and bracket tags for Android Studio / logcat filtering:

```text
CollectionPipeline #12 [total] 7ms
CollectionPipeline #12 [size] series=343 figures=2435 shelf=48 visible=48
CollectionPipeline #12 [insights] 3.0ms
CollectionPipeline #12 [filter] 1.0ms
CollectionPipeline #12 [search] 4.0ms
CollectionPipeline #12 [partition] 142us
CollectionPipeline #12 [sort] 2.0ms
CollectionPipeline #12 [feed] 1.0ms
CollectionPipeline #12 [summary] 1.0ms
```

**Filter examples:** `CollectionPipeline` (all) · `CollectionPipeline [search]` · `CollectionPipeline [warn]` · `CollectionPipeline #12` (one run).

When the pipeline exceeds a single-frame budget (**16 ms** total) or Search alone exceeds **150 ms**, debug logs add `[warn]` lines, e.g. `CollectionPipeline #12 [warn] exceeded 16ms (29ms)` or `CollectionPipeline #12 [warn] slow Search: 132ms`.

Profile/release builds compile the trace to a no-op — no overhead on shipped apps.

Use this when shelf or catalog growth makes performance questionable; compare stage ms against the triggers in [`TECH_DEBT.md`](TECH_DEBT.md) instead of guessing bottlenecks.

---

## Market Identity Architecture

### Components (retained in codebase)

| Component | Role |
|-----------|------|
| [`MarketCatalogIdentityCache`](../lib/features/market/data/market_catalog_identity_cache.dart) | In-memory install of catalog bundle as identity index |
| [`CatalogIdentityIndex`](../lib/features/market/data/catalog_identity_index.dart) | Offline figure/series/brand/IP lookup for title matching |
| [`MarketIdentityMatcher`](../lib/features/market/application/market_identity_matcher.dart) | Listing title → `MarketListing.catalogMatch` |
| [`enrichBrowseListingsIdentity`](../lib/features/market/application/market_listing_identity_enricher.dart) | Batch attach `catalogMatch` before aggregation |

Installed at startup in [`main.dart`](../lib/main.dart) for pre–`ProviderScope` paths; kept in sync on bundle replacement via [`catalogBundleRevisionProvider`](../lib/features/catalog/application/catalog_bundle_provider.dart).

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

`MarketCatalogIdentityCache` is kept as the runtime slot for non-provider enrichment paths; it is **re-installed** when [catalogBundleRevisionProvider](../lib/features/catalog/application/catalog_bundle_provider.dart) observes a bundle replacement (same index as [catalogBundleProvider], no duplicate cache).

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
| Offline-first catalog | Persisted Firestore snapshot + bootstrap placeholder + background refresh |
| Firestore authoritative catalog sync | See [Firestore Authoritative Catalog](#firestore-authoritative-catalog) |

**Low priority / not currently planned:**

| Feature | Rationale |
|---------|-----------|
| Figure deletion | No user-facing remove flow; ID strategy assumes append-only (see [Custom Figure ID Assumptions](#custom-figure-id-assumptions)) |
| Figure reordering | Shelf order follows creation index; reorder adds complexity without current product ask |

Future work: bug fixes, UX polish, catalog content expansion, performance profiling — not major Collection rewrites unless usage triggers thresholds in `COLLECTION_ARCHITECTURE_NOTES.md`.

---

*Last updated: 2026-06 — reflects runtime bootstrap catalog removal, catalog persistence sync, provider propagation, and Performance Characteristics audit.*

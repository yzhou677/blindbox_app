# Catalog Architecture

**Shelfy catalog — architecture specification**

This document is the single reference for how catalog metadata flows from Firestore into the app, how runtime state is modeled, how Riverpod propagates changes, and how search behaves on top of catalog identity.

For operational notes and historical decisions, see [`ARCHITECTURE_NOTES.md`](ARCHITECTURE_NOTES.md). For search-only depth (ranking tiers, history, non-goals), see [`SEARCH_ARCHITECTURE.md`](SEARCH_ARCHITECTURE.md).

**Related code:**

| Layer | Primary files |
|-------|----------------|
| Bundle DTO | [`lib/features/catalog/catalog_bundle.dart`](../lib/features/catalog/catalog_bundle.dart) |
| Runtime cache | [`lib/features/catalog/application/catalog_bundle_cache.dart`](../lib/features/catalog/application/catalog_bundle_cache.dart) |
| Riverpod graph | [`lib/features/catalog/application/catalog_bundle_provider.dart`](../lib/features/catalog/application/catalog_bundle_provider.dart) |
| Availability UX | [`lib/features/catalog/application/catalog_availability.dart`](../lib/features/catalog/application/catalog_availability.dart) |
| Search | [`lib/features/catalog/search/catalog_search_service.dart`](../lib/features/catalog/search/catalog_search_service.dart), [`lib/core/search/`](../lib/core/search/) |
| Persistence | [`lib/features/catalog/data/catalog_bundle_persistence.dart`](../lib/features/catalog/data/catalog_bundle_persistence.dart) |
| Firestore load | [`lib/features/catalog/firestore/firestore_catalog_loader.dart`](../lib/features/catalog/firestore/firestore_catalog_loader.dart) |

---

## 1. Data flow

Catalog metadata is **read-only reference data**. It is not the user shelf, not marketplace listings, and not image URLs built in widgets.

```
Firestore
  brands / ips / series / figures  (one-shot .get(), flat collections)
        │
        ▼
CatalogBundleCache
  in-memory CatalogSeedBundle + CatalogBundleMemoryOrigin
  stale-while-revalidate refresh (5 min TTL, deduped in-flight)
        │
        ├──► Persisted cache (Application Support)
        │         catalog_bundle_v1.json
        │         written after successful Firestore commit
        │
        ▼
catalogBundleRevisionProvider  (bumps on bundle replacement)
        │
        ▼
catalogBundleProvider  (FutureProvider → getOrLoad())
        │
        ├── catalogSearchServiceProvider
        ├── catalogAvailabilityProvider
        ├── homeFeedSnapshotProvider
        ├── addSeriesCatalogRecommendationsProvider
        ├── collectibleRelationshipIndexProvider
        └── … any new catalog-derived Provider
        │
        ▼
Features
  Discover · Catalog browse · Add Series · Collection search · Market identity
```

### Startup (`main.dart`)

1. `CatalogBundleCache.loadOfflineFirst()` — fast path before `ProviderScope`
2. `MarketCatalogIdentityCache.install(bundle)` — pre-provider enricher paths
3. `CatalogBundleRefreshBridge` — keeps revision notifier alive for app lifetime

### Three universes (do not mix)

| Universe | Role | Catalog? |
|----------|------|----------|
| **Catalog** | Reference metadata, search, rails, identity | Yes — this document |
| **Collection shelf** | User-owned state, local photos, custom series | Uses catalog for search/identity only |
| **Market** | External listings, gateway browse | Separate listings; catalog = identity helper only |

### Media identity

- **Catalog art:** `imageKey` → `CatalogImageResolver` → bundled `assets/catalog/**` or Firebase Storage
- **Shelf photos:** `localImageUri` on shelf models only
- **Market listing photos:** external URLs via `MarketListingImage` boundary

Widgets never build Storage URLs or depend on optional `imageUrl` cache fields for catalog art.

---

## 2. State machine

Runtime provenance is a **single enum** — `CatalogBundleMemoryOrigin`. There is no parallel “placeholder bool.” Readiness and provenance cannot drift.

### Memory origins

```dart
enum CatalogBundleMemoryOrigin {
  none,                 // no bundle in memory
  bootstrapPlaceholder, // only NON-ready state with a memory slot
  persisted,            // disk snapshot loaded
  firestore,            // successful network fetch
  resolved,             // load/refresh exhausted; lists may be empty
}
```

- **`isCatalogReady`** — `origin != none && origin != bootstrapPlaceholder`
- **`bootstrapPlaceholder`** — empty lists in memory; UI shows loading until refresh or `getOrLoad()` completes

### Cold start

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
                      catalog-ready
              (persisted | firestore | resolved*)
              *resolved may be empty lists
```

### Simplified ladder (mental model)

```
Placeholder  →  Ready  →  (optional) Refreshing
     │              │
     └──────────────┴──► Resolved (empty, offline UX)
```

| Phase | `memoryOrigin` | `isCatalogReady` | User-visible (via `catalogAvailabilityProvider`) |
|-------|----------------|------------------|--------------------------------------------------|
| First launch, downloading | `bootstrapPlaceholder` | false | **Loading** |
| First launch, offline after fail | `resolved` (empty) | true* | **Offline** + Retry |
| Returning user, disk hit | `persisted` | true | **Ready** (optional **Refreshing** spinner) |
| After Firestore success | `firestore` | true | **Ready** |
| Background refresh in flight | any ready origin | true | **Refreshing** (rails stay visible) |

\*Empty `resolved` bundle is catalog-ready in cache terms but not *usable* — availability maps empty resolved → offline.

### `getOrLoad()` contract

When `memoryOrigin == bootstrapPlaceholder`, `getOrLoad()` **must not** return the empty slot early. It awaits in-flight refresh or the shared network load path. This prevents the race where Discover/search read an empty bundle while Firestore is still downloading.

### Firestore sync rules

- **Authoritative source:** Firestore after first successful persist
- **Offline baseline:** persisted snapshot on disk
- **No bundled metadata seed** in the APK — first install requires network once (or shows offline UX)
- **Deletions stick:** removed Firestore docs do not reappear; persisted snapshot is the offline truth
- **Memory before disk:** `_commitFirestoreBundle` updates memory + notifies listeners before best-effort persist

---

## 3. Provider graph

All catalog-derived runtime objects **must** depend on `catalogBundleProvider` (directly or transitively). Do not cache catalog state in widgets, `late` singletons, or per-feature `ref.invalidate` lists.

```
CatalogBundleCache._commitFirestoreBundle
        │
        ▼
addBundleReplacedListener
        │
        ▼
catalogBundleRevisionProvider  (state++)
        │
        ├── catalogBundleProvider
        │        │
        │        ├── catalogSearchServiceProvider
        │        ├── catalogAvailabilityProvider
        │        ├── homeFeedSnapshotProvider
        │        │        └── homeSeriesReleaseLookupProvider
        │        ├── addSeriesCatalogRecommendationsProvider
        │        └── collectibleRelationshipIndexProvider
        │                 └── shelf / market relationship hints
        │
        └── MarketCatalogIdentityCache.install
                 └── enrichBrowseListingsIdentity (non-gateway paths)
```

### Feature map

| Feature | Providers | Notes |
|---------|-----------|-------|
| **Search** | `catalogBundleProvider` → `catalogSearchServiceProvider` | Catalog browse, Add Series search, shelf catalog leg |
| **Discover** | `homeFeedSnapshotProvider`, `catalogAvailabilityProvider` | Rails from bundle; Official Feed independent |
| **Collection** | `catalogSearchServiceProvider` + `collectionNotifierProvider` | Shelf works offline; catalog search degrades gracefully |
| **Market** | `MarketCatalogIdentityCache` (re-installed on revision) | Browse listings separate; identity enrichment optional by gateway path |
| **Add Series** | `addSeriesCatalogRecommendationsProvider`, `catalogAvailabilityProvider` | Recommendations + search |

### Exceptions (boundaries, not second caches)

| Component | Why |
|-----------|-----|
| `catalogAvailabilityProvider` | Reads `CatalogBundleCache` readiness flags — UI state layer only |
| `MarketCatalogIdentityCache.current` | Sync slot for enrichers outside `WidgetRef`; re-installed from same bundle on revision bump |
| `main.dart` `loadOfflineFirst()` | Pre-`ProviderScope` bootstrap only |

### Adding new catalog consumers

```dart
final myCatalogThingProvider = Provider<MyThing>((ref) {
  final bundle = ref.watch(catalogBundleProvider).valueOrNull;
  if (bundle == null) return MyThing.empty();
  return MyThing.fromBundle(bundle);
});
```

Never: `late MyThing _thing` set once in `initState`. Never: manual `ref.invalidate` lists on bundle replace.

---

## 4. Catalog philosophy

### Catalog = Identity

The catalog answers **what exists** in the collectible universe:

- Stable ids (`brandId`, `ipId`, `seriesId`, `figureId`)
- Display names and **aliases** (alternate identities)
- Taxonomy relationships (brand → IP → series → figure)
- `imageKey` for canonical art identity
- Release metadata (dates, blind-box flags, rarity labels)

Catalog data is **reference**. It does not know what the user owns, what they paid, or what is listed on eBay.

### Search = Behavior

Search answers **how we find** catalog (and shelf/market) rows on device:

- Normalization pipeline (`SearchNormalizer`)
- Tokenization (`SearchTokenizer`)
- Match gate (`SearchMatcher` — token AND)
- Ranking tiers (`CatalogSearchService`)
- History deduplication rules

Search logic lives in **`lib/core/search/`** and **`CatalogSearchService`**. It operates *on* catalog identity; it is not stored in Firestore documents.

### Design consequences

| Question | Answer |
|----------|--------|
| Where do alternate names like “Labubu” for THE MONSTERS go? | Catalog `aliases` on IP/series/brand |
| Where does `popmart` ↔ `POP MART` go? | `SearchNormalizer` — not catalog |
| Can widgets call Firestore for catalog? | No — `catalogBundleProvider` only |
| Can shelf state live in catalog models? | No — collection codec is separate |
| Should search ranking become a shelf sort mode? | No — unless product explicitly requests it |

### Product stance

- **Local-first** — matchers run synchronously over in-memory bundles
- **Deterministic** — same query → same results; no fuzzy/typo engine
- **Calm UX** — explicit loading/offline states via `catalogAvailabilityProvider`; never silent empty catalog surfaces

---

## 5. Alias policy

Four principles govern where alternate names live and how they are used.

### Principle 1 — Aliases are identity, not formatting

Catalog `aliases` represent **alternate identities** that mechanical normalization cannot recover.

| Valid alias | Invalid alias |
|-------------|---------------|
| `Labubu` for THE MONSTERS IP | `popmart` for POP MART |
| `Kimetsu no Yaiba` for Demon Slayer | `POP MART` vs `pop mart` |
| Community / official alternate titles | Punctuation variants (`×` vs `x`) |

Maintain aliases in the **Catalog project** (Firestore seed tooling). Do not push formatting variants into `aliases` to “help search.”

### Principle 2 — Normalization owns mechanical variation

`SearchNormalizer` (Shelfy-owned) recovers:

- Case folding
- Separator folding (`×`, `-`, `/`, em dash → space)
- Symbol stripping (`®`, `™`, `°`, brackets)
- Spacing compaction (`pop mart` + compact twin `popmart` on haystacks)
- Product-title boilerplate stripping (`Blind Box`, `Series Figures`, …)

These **must not** be stored as catalog aliases.

### Principle 3 — Aliases join the haystack; they do not change match rules

At search time, brand/IP/series aliases are **concatenated into the combined haystack** for each figure. Matching is still:

1. Normalize query → tokens
2. Build combined haystack from figure + series + IP + brand (+ aliases)
3. **Token AND** — every token must appear somewhere in the combined haystack

Aliases expand what text is searchable; they do not add fuzzy matching, OR-across-fields logic, or special-case branches.

### Principle 4 — No query expansion in catalog

Shortcuts like `V1` → a series name, or marketplace slang → SKU, belong in a **future Shelfy query map** (if ever), not in Firestore `aliases`. Catalog documents describe entities, not search shortcuts.

**Quick reference:**

| Variation | `SearchNormalizer` | Catalog `aliases` |
|-----------|-------------------|-------------------|
| Case | ✅ | ❌ |
| Spaces / compaction | ✅ | ❌ |
| Punctuation / separators | ✅ | ❌ |
| Boilerplate product words | ✅ | ❌ |
| Official alternate title | ❌ | ✅ |
| Community identity name | ❌ | ✅ |

---

## 6. Search V2

Search V2 is the current local search stack. It is **complete** for on-device surfaces; extend it — do not fork per screen.

### Pipeline

```
User query
    │
    ▼
SearchNormalizer.normalize()     → spaced canonical string
    │
    ▼
SearchTokenizer.tokenize()       → List<String> tokens
    │
    ▼
Per-row haystack build           → SearchNormalizer.normalizeForMatch() per field
    │                              (spaced + compact twin when they differ)
    ▼
SearchMatcher.allTokensMatch()   → token AND gate
    │
    ▼
CatalogSearchService tiers       → relevance ranking (catalog only)
```

### Normalization

| API | Purpose |
|-----|---------|
| `normalize(raw)` | Query + history; lowercase, separators, boilerplate |
| `compact(normalized)` | `pop mart` → `popmart` |
| `normalizeForMatch(raw)` | Haystack segment: spaced + optional compact twin |

### Token AND

Every token from the query must appear as a substring in the row haystack. Empty tokens → no filter (surface-specific empty behavior).

This is **not** per-field OR. Cross-field queries work because tokens can land in different fields while still satisfying one combined haystack (catalog) or joined shelf/market haystack.

### Combined haystack (catalog)

For each figure, `CatalogSearchService` joins normalized segments from:

- Figure display name
- Series display name + series aliases
- IP display name + IP aliases
- Brand display name + brand aliases

```
Figure + Series + IP + Brand (+ aliases)
        ↓ normalize & join
   combined haystack
        ↓
   token AND          ← match gate
        ↓
   tier ranking       ← relevance only
```

### Ranking tiers (catalog only)

1. Exact figure name
2. Figure name (all tokens in figure field)
3. Series name
4. IP name
5. Aliases / brand text

Tie-breakers: tier → earliest token index → `sortOrder` → `figureId`.

Collection shelf does **not** rank by search relevance — filter then user-selected sort.

### Surfaces

| Surface | Matcher entry |
|---------|---------------|
| Catalog browse (`/home/catalog`) | `CatalogSearchService` |
| Add Series sheet | `buildCatalogSeriesSearchRows` → `CatalogSearchService` |
| Collection shelf | `filterShelfSeriesBySearch` + optional `catalogSearchServiceProvider` |
| Market offline filter | `marketListingMatchesFreeText` |
| Market live gateway | **Unchanged** — gateway owns remote keyword search |

### Catalog availability + search

When `catalogAvailabilityProvider` reports not usable:

- Do not show “No matches” — show downloading / offline copy
- Empty query shows availability card or history, not results

When usable, empty query → history / recommendations (not result list).

### Non-goals

Search V2 intentionally excludes: fuzzy search, typo correction, phonetic matching, stemming, SQLite FTS, Elasticsearch/Algolia, background indexing.

At current catalog size (~low thousands of figures), synchronous scan is correct. Revisit precomputed haystacks only if profiling on real devices demands it.

---

## Appendix — File map

```
lib/features/catalog/
  catalog_bundle.dart              # CatalogSeedBundle DTO + JSON parse helpers
  application/
    catalog_bundle_cache.dart        # Runtime state machine
    catalog_bundle_provider.dart   # Riverpod graph root
    catalog_availability.dart        # Loading / offline / refresh UX state
  data/
    catalog_bundle_persistence.dart
    catalog_bundle_codec.dart
  firestore/
    firestore_catalog_loader.dart
  search/
    catalog_search_service.dart
  widgets/
    catalog_availability_card.dart

lib/core/search/
  search_normalizer.dart
  search_tokenizer.dart
  search_matcher.dart
  search_placeholders.dart
```

---

*Last updated: 2026-06 — reflects Search V2, provider propagation, bootstrap catalog removal, and first-launch availability UX.*

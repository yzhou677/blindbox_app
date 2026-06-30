# Blindbox App — Architecture & Coding Instructions

Canonical reference for humans and Cursor agents. Supersedes scattered notes in `docs/` for day-to-day implementation guidance.

**Related:** [`docs/CATALOG_ARCHITECTURE.md`](../docs/CATALOG_ARCHITECTURE.md) (catalog spec — data flow, runtime state, providers, Search V2), [`docs/SEARCH_ARCHITECTURE.md`](../docs/SEARCH_ARCHITECTURE.md) (search-only depth), [`.cursor/rules/`](rules/) (agent rule snippets — **`product-principles`**, **`offline-async-media`**, **`project-architecture`**), [`CONFORMITY_AUDIT.md`](CONFORMITY_AUDIT.md) (codebase checklist), [`FIRESTORE_CATALOG_SCHEMA.md`](../lib/features/catalog/firestore/FIRESTORE_CATALOG_SCHEMA.md), [`FIREBASE_STORAGE_CATALOG.md`](../lib/features/catalog/firestore/FIREBASE_STORAGE_CATALOG.md)

---

## Long-term principles (stable — not one-off cleanup)

Treat these as **ongoing product and architecture law**, not a single refactor ticket.

| Theme | Rule of thumb |
|-------|----------------|
| **Product** | Collectible lifestyle — calm, image-first, immersive; avoid CRUD/dashboard tone and chatty copy |
| **Canonical identity** | Firebase catalog (`brands` / `ips` / `series` / `figures`, `imageKey`, aliases, rarity) is truth; Collection/Market **adapt** via mappers — no parallel per-screen DTOs or title/image logic |
| **Three universes** | Catalog (read-only), Shelf (local-first), Market/Home (discover + listings) — do not mix persistence or media keys |
| **imageKey** | UI renders through shared primitives + `CatalogImageResolver`; never construct Storage URLs in widgets; `imageUrl` is optional cache only |
| **Offline-first** | Usable on bad network — bundled catalog art, persistent disk cache for previously seen Storage images, local shelf codec, placeholders; browse/search/gallery without blocking on Firebase |
| **Async** | Optimistic mutations; background hydration; no `await` resolve before shelf `_commit` or modal dismiss |
| **Reuse** | `commitCatalogSeriesToShelf`, `showCollectibleBottomSheet`, `showCatalogFigureGallery`, shared cards/typography — extend before forking |
| **Layers** | Widgets = render; application = rules/mutations; data/media = Firebase, codec, resolver, DTOs |
| **Evolution** | Small focused diffs; extend existing systems; avoid token explosion and mass rewrites |

Agent rules: `.cursor/rules/product-principles.mdc`, `.cursor/rules/offline-async-media.mdc`.

---

## Product boundaries (three universes)

These must stay separate. Do not merge persistence, media keys, or loading paths across them without an explicit task.

### 1. Catalog Universe (shared, read-only)

- **Purpose:** Canonical brands, IPs, series, and figures for search, browse, and “add to shelf” templates.
- **Location:** `lib/features/catalog/`
- **In-memory shape:** `CatalogSeedBundle` ([`catalog_seed_loader.dart`](../lib/features/catalog/catalog_seed_loader.dart))
- **Default source:** `loadCatalogBundle()` — Firestore (`brands`, `ips`, `series`, `figures`) with seed JSON fallback ([`catalog_bundle_loader.dart`](../lib/features/catalog/catalog_bundle_loader.dart))
- **Media:** Opaque `imageKey` on catalog models; resolve via [`CatalogImageResolver`](../lib/features/catalog/catalog_image_resolver.dart) — **bundled → bounded disk cache (LRU + TTL) → Firebase Storage → placeholder** (see [Firebase](#firebase-firestore--storage)); [`CatalogImageFromKey`](../lib/shared/widgets/catalog_image_from_key.dart) for catalog UI. Disk cache is intermediate resilience; Storage is the freshness source when online.
- **Search:** Pure Dart [`CatalogSearchService`](../lib/features/catalog/search/catalog_search_service.dart) over a bundle — no Riverpod inside search
- **Into shelf:** Only through adapters + `CollectionNotifier` (e.g. [`catalog_seed_to_collection_template.dart`](../lib/features/catalog/adapters/catalog_seed_to_collection_template.dart)) — catalog does **not** own shelf rows

**Never on catalog:** user figure state (owned/wishlist), `localImageUri`, cloud sync of collection, Firestore listeners for shelf.

### 2. User Private Shelf (local-first)

- **Purpose:** What the user saved — series instances, figure slots, progress.
- **Location:** `lib/features/collection/`
- **Source of truth:** `CollectionSnapshot` in [`collection_domain.dart`](../lib/features/collection/domain/collection_domain.dart)
- **Writes:** [`collectionNotifierProvider`](../lib/features/collection/application/collection_notifier.dart) only
- **Persistence:** `SharedPreferences` + [`collection_snapshot_codec.dart`](../lib/features/collection/persistence/collection_snapshot_codec.dart) (schema v2)
- **Media (display contract):**
  - `ShelfFigure.imageKey` + `ShelfSeries.imageKey` — **canonical** for catalog/drop art; UI via [`CatalogImageFromKey`](../lib/shared/widgets/catalog_image_from_key.dart) / [`ShelfFigureThumb`](../lib/features/collection/widgets/shelf_figure_thumb.dart)
  - `ShelfFigure.localImageUri` / `ShelfSeries.customCoverImageUri` — user device photos only
  - `ShelfFigure.imageUrl` — optional persistence cache; **UI must not read it** for catalog tiles (see [`ShelfFigureMedia`](../lib/features/collection/presentation/shelf_figure_media.dart))
- **Add to shelf:** [`commitCatalogSeriesToShelf`](../lib/features/collection/application/catalog_series_shelf_commit.dart) → [`addSeriesFromTemplate`](../lib/features/collection/application/collection_notifier.dart) (optimistic, no pre-resolve); Home: [`addSeriesFromRelease`](../lib/features/collection/application/collection_notifier.dart) commits `imageKey` immediately
- **Shelf emotional intelligence (Phase 4):** derived [`ShelfEmotionalProfile`](../lib/features/collection/domain/shelf_emotional_profile.dart) from [`interpretShelf`](../lib/features/collection/application/shelf_emotional_interpreter.dart); relationship hints via [`analyzeShelfRelationships`](../lib/features/collection/application/shelf_relationship_analyzer.dart); per-series [`SeriesCompletionAtmosphere`](../lib/features/collection/domain/series_completion_atmosphere.dart); optional milestones in [`CollectionMemoryStore`](../lib/features/collection/data/collection_memory_store.dart). Editorial copy: [`ShelfEditorialVoice`](../lib/features/collection/presentation/shelf_editorial_voice.dart). Per-series progress copy remains [`CollectionProgressVoice`](../lib/features/collection/widgets/collection_progress_voice.dart). See [`docs/COLLECTION_EMOTIONAL_INTELLIGENCE.md`](../docs/COLLECTION_EMOTIONAL_INTELLIGENCE.md).
- **Collectible relationship surfaces (Phase 5):** cross-universe derived adjacency in [`lib/features/collectible_relationship/`](../lib/features/collectible_relationship/) — [`CollectibleRelationshipIndex`](../lib/features/collectible_relationship/application/collectible_relationship_index.dart), [`resolveCollectibleRelationshipHint`](../lib/features/collectible_relationship/application/collectible_affinity_resolver.dart), [`CollectibleRelationshipCopy`](../lib/features/collectible_relationship/presentation/collectible_relationship_copy.dart). One calm line per focal view (shelf series sheet, catalog preview, market card/sheet/detail); shelf pairwise insights delegate to [`analyzeCollectibleShelfRelationships`](../lib/features/collectible_relationship/application/collectible_shelf_relationship_bridge.dart). Not ML or recommendation rails. See [`docs/COLLECTIBLE_RELATIONSHIP_SURFACES.md`](../docs/COLLECTIBLE_RELATIONSHIP_SURFACES.md).
- **Immersive presentation (Phase 6):** unified motion + focus framing — [`CollectibleMotion`](../lib/core/theme/collectible_motion.dart), [`CollectibleImmersion`](../lib/core/presentation/collectible_immersion.dart), [`CollectiblePresenceFade`](../lib/core/presentation/collectible_immersion.dart), sheet barrier via [`showCollectibleBottomSheet`](../lib/shared/widgets/collectible_bottom_sheet.dart), gallery via [`showCatalogFigureGallery`](../lib/features/catalog/presentation/figure_gallery/catalog_figure_gallery_sheet.dart). See [`docs/COLLECTIBLE_IMMERSIVE_PRESENTATION.md`](../docs/COLLECTIBLE_IMMERSIVE_PRESENTATION.md).
- **Personal collectible memory (Phase 7):** [`CollectionMemoryStore`](../lib/features/collection/data/collection_memory_store.dart) (`collection_memory_v2`), [`buildCollectionMemoryMoments`](../lib/features/collection/application/collection_memory_index.dart), [`interpretCollectionEvolution`](../lib/features/collection/application/collection_evolution_interpreter.dart), editorial [`CollectionMemoryEditorial`](../lib/features/collection/presentation/collection_memory_editorial.dart). One summary whisper + optional series reflection — no timelines or gamification. See [`docs/COLLECTION_PERSONAL_MEMORY.md`](../docs/COLLECTION_PERSONAL_MEMORY.md).
- **Maintenance mode & intentional tradeoffs:** Collection is stable; single-snapshot prefs, cached collector identity, and add-time journey depth are **by design** — do not “fix” without reading [`docs/COLLECTION_ARCHITECTURE_NOTES.md`](../docs/COLLECTION_ARCHITECTURE_NOTES.md).

**Never on shelf:** Firestore catalog documents on shelf rows, uploading private photos to cloud, or storing catalog `imageKey` as the primary persisted media field in the codec.

### 3. Market / Home (discover + listings)

- **Purpose:** Editorial feed (home) and market browse; entry points to save releases or view listings.
- **Locations:** `lib/features/home/`, `lib/features/market/`
- **Home:** Catalog-backed Latest/Trending via [`home_feed_provider`](../lib/features/home/application/home_feed_provider.dart); **Official drops** via [`official_feed`](../lib/features/official_feed/) (Firestore `official_feed_items`, external URLs). Save via `collectionNotifier.addSeriesFromRelease` + [`series_release_lookup`](../lib/features/collection/data/series_release_lookup.dart)
- **Market listings:** [`MarketSource`](../lib/features/market/data/source/market_source.dart) implementations (default [`AssetMarketSource`](../lib/features/market/data/source/asset_market_source.dart); dormant [`EbayMarketSource`](../lib/features/market/data/source/ebay_market_source.dart), [`MercariMarketSource`](../lib/features/market/data/source/mercari_market_source.dart)) → [`MarketListingsRepository`](../lib/features/market/data/repository/market_listings_repository.dart) → [`MarketListing`](../lib/models/market_listing.dart). Card art via [`MarketListingImage`](../lib/features/market/presentation/market_listing_image.dart) only — **not** catalog `imageKey` / Firestore.
- **Market identity matching (Phase 2A):** listing titles → [`MarketIdentityMatcher`](../lib/features/market/application/market_identity_matcher.dart) over offline [`CatalogIdentityIndex`](../lib/features/market/data/catalog_identity_index.dart) (built from catalog bundle at startup). Result on `MarketListing.catalogMatch` (data layer only; UI stays provider-neutral). Prefer unresolved/partial matches over wrong figure binding.
- **Product live providers (priority):** official APIs first — wire [`EbayMarketSource`](../lib/features/market/data/source/ebay_market_source.dart) when OAuth + Browse mapping are ready; startup stays [`productionMarketSources()`](../lib/features/market/data/source/default_market_sources.dart) (asset) until then.
- **Mercari gateway (paused, retained):** Firebase Functions (`functions/`) + optional app sandbox flag — **not** Product live today. Deploy runs **fixture** mode; `MARKET_SANDBOX_MERCARI` stays off. Wire contract, acquisition runtime, and [`MercariSandboxMarketSource`](../lib/features/market/data/source/mercari_sandbox_market_source.dart) remain for internal experiments. See [`docs/MERCARI_GATEWAY_FUNCTIONS.md`](../docs/MERCARI_GATEWAY_FUNCTIONS.md), [`docs/MERCARI_SANDBOX.md`](../docs/MERCARI_SANDBOX.md), [`functions/src/providers/mercari/ACQUISITION.md`](../functions/src/providers/mercari/ACQUISITION.md).
- **Collectible market intelligence (Phase 3B):** after identity enrich, [`buildCollectibleMarketSnapshots`](../lib/features/market/application/collectible_market_aggregator.dart) rolls listings into [`CollectibleMarketSnapshot`](../lib/features/market/domain/collectible_market_snapshot.dart) (figure/series/fallback tiers; medium+ confidence to merge). Installed via [`installMarketBrowseIntelligence`](../lib/features/market/application/market_browse_intelligence_install.dart) into [`CollectibleMarketSession`](../lib/features/market/data/collectible_market_session.dart) + optional [`CollectibleMarketSnapshotCache`](../lib/features/market/data/cache/collectible_market_snapshot_cache.dart). Browse UI: [`CollectibleMarketCard`](../lib/features/market/widgets/collectible_market_card.dart) (editorial mood, sightings — not trading analytics). Snapshots are derived market interpretation, not canonical collectibles. See [`docs/COLLECTIBLE_MARKET_INTELLIGENCE.md`](../docs/COLLECTIBLE_MARKET_INTELLIGENCE.md).
- **Market filters (shared ids only):** [`MarketTaxonomy`](../lib/features/market/catalog/market_taxonomy.dart) chip rows and predicates use canonical brand/IP **ids** aligned via `applyCatalogBundle()` after catalog bootstrap. Filter chips read `_catalogBrands` / `_catalogIps`; listing title resolution still uses the full [`MarketTaxonomyAdapter`](../lib/features/market/taxonomy/market_taxonomy_adapter.dart) registry. **Do not** load `CatalogSeedBundle` or query Firestore for listing content, prices, or card art.
- **Into shelf:** Notifier methods only (`addSeriesFromDrop`, etc.) — not direct snapshot mutation from widgets

---

## Data flow (high level)

```
Catalog universe (read-only) — NOT used for market listing bodies
  Firestore (brands/ips/series/figures) ──┐
  tools/seed JSON (fallback) ────────────┼──> loadCatalogBundle() ──> CatalogSeedBundle
  Storage catalog/series|figures/* ──────┘         │
        imageKey → CatalogImageResolver            ├──> CatalogSearchService
        (bundled → disk cache → Storage, runtime)  ├──> Add Series / recommendations (add_to_collection_sheet)
                                                   ├──> catalog_seed_to_collection_template → collectionNotifier
                                                   └──> MarketTaxonomy.applyCatalogBundle (filter chip ids/labels only)

User shelf (local-first)
  collectionNotifierProvider ──> CollectionSnapshot ──> SharedPreferences codec
  Home drop ──> addSeriesFromRelease ──> ShelfFigure.imageKey (optimistic commit)
  Add catalog ──> commitCatalogSeriesToShelf ──> addSeriesFromTemplate
  Collection sheet ──> catalogGalleryItemsFromShelfSeries ──> fullscreen figure gallery
  (no Firestore shelf sync)

Market (separate data path — not catalog bodies)
  MarketSource(s) ──> MarketListingsRepository ──> enrichListingIdentity ──> MarketListing
        │                      (CatalogIdentityIndex + MarketIdentityMatcher)
        └──> marketBrowseNotifier (filters via MarketTaxonomy ids; no CatalogSeedBundle for row bodies)
```

**Startup ([`main.dart`](../lib/main.dart)):** optional Firebase init + `loadCatalogBundle()` + `MarketTaxonomy.applyCatalogBundle()` → bootstrap market listings → restore collection snapshot (or seed) → `ProviderScope` → `GoRouter`.

**Navigation:** [`app_router.dart`](../lib/core/router/app_router.dart) — shell tabs Home / Market / Collection.

---

## Folder conventions

```
lib/
  core/           # router, theme, FeedRhythm, Firebase init, device_local_ref
  features/       # feature slices (primary organization)
    catalog/      # read-only universe (no tab)
    collection/   # user shelf
    home/         # discover feed
    market/       # listings browse
  models/         # legacy shared presentation models (see below)
  shared/widgets/ # cross-feature UI only
```

Per feature (when applicable):

- `*_screen.dart` at feature root
- `application/` — Riverpod notifiers/providers
- `data/` — mocks, repositories, datasources, bootstrap
- `domain/` — feature-owned models (collection, home)
- `presentation/` — view helpers, copy, filters, art resolution
- `widgets/` — feature UI components

### `lib/models/` (grandfathered — expansion frozen)

Holds **legacy shared presentation** types only: `Collectible`, `MarketListing`, `ToySeriesHighlight`.

- **Frozen:** Do **not** add new files, classes, DTOs, enums, or transport types under `lib/models/`.
- **Allowed:** Import and extend existing grandfathered types only when a task truly requires touching them.
- **New work:** Put models in the **owning feature** — see [Legacy structure guardrails](#legacy-structure-guardrails-frozen--do-not-expand) below.
- **Not a migration target:** Do not schedule mass moves out of `lib/models/` unless the user explicitly requests a migration project.

There is **no** `lib/services/` folder in the current codebase (older docs may mention it). Do **not** introduce one.

---

## Legacy structure guardrails (frozen — do not expand)

The codebase is **feature-oriented** (`lib/features/<feature>/`). A few **grandfathered** paths remain for compatibility. They are **frozen**: stop growing them; evolve incrementally elsewhere.

### Rules for all new work

- **Do NOT** add new models, DTOs, repositories, or “shared” data types under `lib/models/`.
- **Do NOT** create `lib/services/` or other generic cross-feature service layers — use `features/<feature>/data/` (datasources, repositories, mappers).
- **DO** place new types in the owning feature:
  - API / wire / persistence shapes → `features/<feature>/data/` (e.g. `dto/`, `mappers/`)
  - Feature domain state → `features/<feature>/domain/`
  - UI-only helpers → `features/<feature>/presentation/` or `widgets/`
- **Cross-feature boundaries:** Prefer explicit adapters at the call site (catalog → collection template, market DTO → `MarketListing` mapper) instead of new shared model folders.
- **Grandfathered code may stay** until a task deliberately migrates a call site — no drive-by deletion or “cleanup refactors.”
- **Incremental evolution only** — no mass refactors, folder reshuffles, or architecture rewrites unless the user explicitly asks.

### Grandfathered structures (documented, not to grow)

- **`lib/models/`** — shared presentation models; see [above](#libmodels-grandfathered--expansion-frozen).
- **`CollectionCatalog`** (`collection/data/`) — frozen hardcoded demo suggestions / seed shelf art; **not** used by Add Series search or recommendations (those use `loadCatalogBundle()`).

### What agents should avoid

- “While I’m here” moves of `Collectible` / `MarketListing` into features.
- New `lib/models/foo.dart` because two screens need the same shape — add a feature `data/` type and mapper instead.
- Blocking MVP features on eliminating legacy paths.

Preserve: feature boundaries, local-first collection (`CollectionSnapshot` + codec), catalog vs shelf media separation, cozy collector UX, and existing Riverpod/notifier patterns.

---

## State and persistence

| Concern | Pattern | Key entry points |
|--------|---------|------------------|
| Collection shelf | Riverpod `Notifier` + codec | `collection_notifier.dart`, `collection_snapshot_storage.dart` |
| Market browse UI | Riverpod + session bootstrap | `market_browse_notifier.dart`, `market_listings_bootstrap.dart` |
| Catalog | Load on demand + startup bootstrap (no global catalog provider yet) | `loadCatalogBundle()` in `main.dart` and add sheet |
| Firestore / Storage | Catalog only; `ensureFirebaseInitialized()` before fetch | `firestore_catalog_loader.dart`, `catalog_image_resolver.dart` |

- **Do not** replace Riverpod.
- **Do not** add cloud sync for collection in MVP tasks unless explicitly requested.
- Market listings may use a **session singleton** after bootstrap — intentional; not every list goes through a `FutureProvider`.

---

## Firebase (Firestore + Storage)

Firebase is for the **catalog universe only** in the current roadmap. Collection stays local-first unless explicitly tasked otherwise.

### Firestore (catalog reference)

- **Canonical collections only:** `brands`, `ips`, `series`, `figures` (flat top-level — no nested/duplicate catalog trees). See [`FIRESTORE_CATALOG_SCHEMA.md`](../lib/features/catalog/firestore/FIRESTORE_CATALOG_SCHEMA.md).
- **Loader:** `loadFirestoreCatalogBundle()` / `loadCatalogBundle()` — four one-shot `.get()` queries → `CatalogSeedBundle`. Metadata only (`imageKey`, canonical ids) — no Storage URLs or `imagePath` on docs.
- **Do not** introduce alternate Firestore layouts or `imagePath` fields when extending catalog features.
- **Init:** `ensureFirebaseInitialized()` before any Firestore/Storage call; run `flutterfire configure` and add platform config (`google-services.json`, `GoogleService-Info.plist`). Keep secrets out of git if your pipeline requires it.
- **Canonical ids:** match seed (e.g. IP `the_monsters`, not `labubu`).

### Storage (public catalog art)

- **Scope:** read-only catalog thumbnails keyed by `imageKey`. Deterministic paths: `catalog/series/<imageKey>.<ext>`, `catalog/figures/<imageKey>.<ext>` — probe `.avif`, `.webp`, `.png`, `.jpg`, `.jpeg` until one exists. See [`FIREBASE_STORAGE_CATALOG.md`](../lib/features/catalog/firestore/FIREBASE_STORAGE_CATALOG.md).
- **Not in scope for MVP agents:** uploading `localImageUri` / `customCoverImageUri` (private shelf photos).
- **Resolver:** four-tier display strategy at **display time** (see [`catalog_image_resolver.dart`](../lib/features/catalog/catalog_image_resolver.dart), [`catalog_image_disk_cache.dart`](../lib/features/catalog/data/catalog_image_disk_cache.dart), [`catalog_image_cache_policy.dart`](../lib/features/catalog/data/catalog_image_cache_policy.dart)):
  1. Bundled `assets/catalog/**` (stable offline seed subset)
  2. Bounded disk cache (`ApplicationSupport/catalog_image_cache/`) — **resilience layer**, not canonical storage
  3. Firebase Storage — freshness / enrichment (network when available)
  4. Placeholder when all tiers miss

  **Offline-first ≠ offline-only.** The app degrades gracefully without network (bundled + any disk bytes still on device). When online, Storage opportunistically refreshes stale cache entries without blocking UI.

  **Disk cache lifecycle** ([`CatalogImageCachePolicy`](../lib/features/catalog/data/catalog_image_cache_policy.dart)):
  - **LRU eviction:** ~150 MB cap; oldest-accessed files removed first (`cache_index.json` tracks access + size)
  - **Freshness TTL:** entries older than **14 days** are *stale* — still rendered immediately; background refresh attempted at most once per **24 h** per key (deduped in-flight, no launch-wide re-download storms)
  - **Refresh concurrency:** stale-while-revalidate uses a FIFO queue with at most **4** simultaneous Storage refreshes (feeds do not burst-refresh every visible stale tile at once)
  - **Session negative cache:** missing Storage keys probed once per app session (no repeat 404 spam)
  - **Not permanent truth:** remote Storage changes propagate via background refresh; failed refresh keeps last local bytes until evicted

  Do not write Storage URLs onto Firestore catalog docs. Shelf codec may store optional `imageUrl` cache; UI still renders from `imageKey`.
- **Code location:** `lib/features/catalog/` and `lib/core/firebase/` — no `lib/services/`. Uses `firebase_storage` for catalog art reads.

### What not to do (Firebase integration)

- Firestore listeners or collection cloud sync without explicit scope.
- Storing `imageKey` on shelf models or Firestore payloads in the collection codec.
- Making Firestore the only catalog path (keep `tools/seed/` for offline tests and dev).
- Putting long-lived download URLs on shelf domain models instead of resolving at display time.
- Reintroducing `labubu` as a Firestore IP document id.

Security rules live in the Firebase console or your infra repo — catalog read public (or auth-read); no user shelf paths until a future sync project.

---

## Coding instructions

### Architecture

- Follow existing feature boundaries; extend before inventing new layers.
- **No new types under `lib/models/`** — feature `data/` / `domain/` only (see [Legacy structure guardrails](#legacy-structure-guardrails-frozen--do-not-expand)).
- No HTTP clients in widgets — use `feature/data` datasources and repositories.
- Map DTOs → domain/presentation models in `data/mappers/`.
- Keep mock/fake data paths for tests and offline dev.
- No cleanup refactors or legacy-folder migrations unless the task explicitly requests them.

### UI / UX

- **Tone:** Cozy, collectible, shelf-oriented — not enterprise or search-engine debug copy.
- **Spacing:** Use [`FeedRhythm`](../lib/core/layout/feed_rhythm.dart) constants for tab feeds and collection shelf rhythm. Use [`AppSpacing`](../lib/core/theme/app_spacing.dart) for component-level insets (page gutter, card padding).
- **Imagery:** Large thumbnails, soft cards, placeholders on failure — never broken-image chaos.
- **Add-to-collection:** Series-centric search rows; tap row → preview sheet; **Add** button → commit. Subtitle: `Includes {figure}` or `{n} figures` (+ chase suffix) — not `Matched: …` lists.

### Design tokens

The app uses a **lightweight, two-layer token system**. Do not introduce a third layer.

#### Spacing

| Token file | Scope | Use for |
|---|---|---|
| [`AppSpacing`](../lib/core/theme/app_spacing.dart) | Component-level insets | Page horizontal gutter (`pageHorizontal`=20), card padding (`cardPadding`), below-AppBar gaps, empty-state horizontal |
| [`FeedRhythm`](../lib/core/layout/feed_rhythm.dart) | Compositional layout | Section-to-rail gaps, block gaps, rail heights, sheet constants, tab scroll tail |

**Key `AppSpacing` constants:**

| Constant | Value | Use |
|---|---|---|
| `pageHorizontal` | 20 | All feed content horizontal padding |
| `pageHorizontalCompact` | 16 | Rails, official feed column, sheet body |
| `emptyStateHorizontal` | 28 | Centred empty prompts |
| `cardPadding` | 20×12 | Default card body (`EdgeInsets.symmetric`) |
| `cardPaddingCompact` | 16×12 | Market listing tiles, official feed tiles |
| `belowTabAppBar` | 10 | Gap after main-tab AppBar (no search) |
| `belowTabAppBarToSearch` | 14 | Gap after main-tab AppBar to search field |

#### Typography

Named text roles live in [`AppTypography`](../lib/core/theme/app_typography.dart) (thin wrapper over [`CollectibleTypography`](../lib/core/theme/collectible_typography.dart)):

| Role | Base style | Screens |
|---|---|---|
| `tabTitle` | titleLarge w700 | Home / Market / Collection AppBar |
| `screenTitle` | headlineSmall w700 | Search overlay AppBars |
| `sectionTitle` | titleMedium w600 | Section headers (all tabs) |
| `sectionLabel` | labelSmall w600 ls:0.35 | Chip rails, taxonomy labels |
| `cardTitle` | titleSmall w600 | Market rows, official feed, search |
| `cardMeta` / `supportive` | labelSmall w500 muted | Meta lines, dates |
| `deckText` | bodySmall w400 muted | Section subtitles, quiet copy |
| `insightsTotals` | titleLarge w700 ls:-0.4 | Collection Insights counts |
| `insightsFlavor` | bodyLarge italic α0.72 | Archetype flavor / deck copy |
| `insightsCaption` | labelSmall w600 ls:0.5 α0.65 | Strip section labels |

**Rules:**
- Use `AppTypography.*` for any text role that appears on two or more screens — do not repeat inline `copyWith` chains.
- `CollectibleTypography` continues to be the canonical implementation; `AppTypography` is the stable API layer.
- Feature-local palette and art-direction colors (e.g. Insights donut colors) stay local — do **not** try to centralize them.

#### Intentional deviations (do not flatten)

| Screen | Value | Why |
|---|---|---|
| Search overlay AppBar | `toolbarHeight: 72` (not 52) | Taller AppBar emphasises focused search mode vs browsing tab |
| Search overlay title | `editorialScreenTitle` (headlineSmall) | Larger title reinforces search context |
| Detail body horizontal | 22 (not 20) | Extra breathing room in hero detail contexts |
| Empty-state horizontal | 28 (not 20) | Centred copy reads better with narrower line length |

#### AppBar checklist (pre-merge)

- Main tabs: `toolbarHeight: FeedRhythm.mainTabAppBarToolbarHeight` (52), title `textTheme.titleLarge`, `titleSpacing: AppSpacing.pageHorizontal`
- Search overlays: `toolbarHeight: 72`, title `AppTypography.screenTitle`, `titleSpacing: AppSpacing.pageHorizontal`
- Sub-routes: use `SliverAppBar` with `FeedRhythm.mainTabAppBarToolbarHeight` + `AppSpacing.belowTabAppBar` gap; `CollectibleSectionHeader` below (no extra top gap)

See also: [`docs/DESIGN_SYSTEM_CHECKLIST.md`](../docs/DESIGN_SYSTEM_CHECKLIST.md) (the UI audit checklist from the design-system consistency pass).

### Catalog vs shelf images

- **All catalog/shelf/home lineup UI:** `imageKey` → [`CatalogImageFromKey`](../lib/shared/widgets/catalog_image_from_key.dart) → resolver (never await in widgets before paint)
- **Shelf user photos:** `localImageUri` / `customCoverImageUri` via [`ShelfFigureMedia`](../lib/features/collection/presentation/shelf_figure_media.dart) + [`CollectibleThumbImage`](../lib/shared/widgets/collectible_thumb_image.dart)
- **Market listing photos:** [`MarketListingImage`](../lib/features/market/presentation/market_listing_image.dart) — only place listing `imageUrl` is consumed in UI

### Modals & sheets

- **Bottom sheets:** [`showCollectibleBottomSheet`](../lib/shared/widgets/collectible_bottom_sheet.dart) / [`showCollectionModalBottomSheet`](../lib/features/collection/presentation/collection_modal_overlays.dart) — `FractionallySizedBox` height cap + `DraggableScrollableSheet` (linked scroll, `shouldCloseOnMinExtent`, scroll-top drag dismiss)
- **Figure gallery:** [`showCatalogFigureGallery`](../lib/features/catalog/presentation/figure_gallery/catalog_figure_gallery_sheet.dart) — fullscreen route; adapters pass `catalogImageKey` only

### Figure gallery (collection + catalog)

- **Shelf mapping:** [`catalogGalleryItemsFromShelfSeries`](../lib/features/catalog/presentation/figure_gallery/catalog_figure_gallery_adapters.dart) — `catalogImageKey` + `localImageUri` only
- **Fullscreen:** [`CatalogFigureGalleryPage`](../lib/features/catalog/presentation/figure_gallery/catalog_figure_gallery_page.dart) — local file → `CatalogImageFromKey` → placeholder

### MVP discipline

- Ship focused diffs; avoid rewriting `CatalogSearchService`, collection flow, or switching catalog source unless the task says so.
- Default catalog source is `loadCatalogBundle()` (Firestore with seed fallback) — do not remove seed path without explicit task.
- Firebase Storage: catalog art only; see [Firebase](#firebase-firestore--storage) — not shelf photo upload unless tasked.
- Market listings: keep marketplace provider path separate — do not wire listing cards to Firestore catalog or `imageKey`.
- Do not expand grandfathered architecture (`lib/models/`, new `lib/services/`, growing `CollectionCatalog`) as part of unrelated tasks.

---

## Naming traps

| Name | Where | Meaning |
|------|--------|---------|
| `CatalogSeries` | `features/catalog/models/` | Seed/Firestore entity |
| `CatalogSeries` | `collection/domain/` | Template for cloning onto shelf (`templateId`, `figures`, …) |
| `CatalogFigure` | catalog models | Seed figure |
| `ShelfFigure` | collection domain | User’s figure **instance** on a shelf row |
| `CollectionCatalog` | `collection/data/` | **Hardcoded** legacy suggestion catalog — not the seed JSON universe |

Always check imports when editing “CatalogSeries” or “CatalogFigure”.

---

## Conformity audit

See **[`CONFORMITY_AUDIT.md`](CONFORMITY_AUDIT.md)** for the aligned vs drift checklist and pre-change checklist.

---

## Superseded docs

- [`docs/CURSOR_RULES.md`](../docs/CURSOR_RULES.md) — index only; agents use this file + `.cursor/rules/`
- [`docs/README.md`](../docs/README.md) — human docs index
- [`docs/PROJECT_OVERVIEW.md`](../docs/PROJECT_OVERVIEW.md) — product vision; verify tech stack against this file for current implementation

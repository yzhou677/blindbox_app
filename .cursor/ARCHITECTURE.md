# Blindbox App — Architecture & Coding Instructions

Canonical reference for humans and Cursor agents. Supersedes scattered notes in `docs/` for day-to-day implementation guidance.

**Related:** [`.cursor/rules/`](rules/) (agent rule snippets), [`CONFORMITY_AUDIT.md`](CONFORMITY_AUDIT.md) (codebase checklist), [`FIRESTORE_CATALOG_SCHEMA.md`](../lib/features/catalog/firestore/FIRESTORE_CATALOG_SCHEMA.md), [`FIREBASE_STORAGE_CATALOG.md`](../lib/features/catalog/firestore/FIREBASE_STORAGE_CATALOG.md)

---

## Product boundaries (three universes)

These must stay separate. Do not merge persistence, media keys, or loading paths across them without an explicit task.

### 1. Catalog Universe (shared, read-only)

- **Purpose:** Canonical brands, IPs, series, and figures for search, browse, and “add to shelf” templates.
- **Location:** `lib/features/catalog/`
- **In-memory shape:** `CatalogSeedBundle` ([`catalog_seed_loader.dart`](../lib/features/catalog/catalog_seed_loader.dart))
- **Default source:** Bundled JSON under `tools/seed/` via `loadCatalogSeedBundle()`
- **Optional source:** Firestore one-shot load via `loadFirestoreCatalogBundle()` ([`firestore_catalog_loader.dart`](../lib/features/catalog/firestore/firestore_catalog_loader.dart)) — same bundle shape; **not** the default UI path yet
- **Media:** Opaque `imageKey` on catalog models; resolve via [`CatalogImageResolver`](../lib/features/catalog/catalog_image_resolver.dart) — bundled assets today; Firebase Storage for public catalog art when wired (see [Firebase](#firebase-firestore--storage))
- **Search:** Pure Dart [`CatalogSearchService`](../lib/features/catalog/search/catalog_search_service.dart) over a bundle — no Riverpod inside search
- **Into shelf:** Only through adapters + `CollectionNotifier` (e.g. [`catalog_seed_to_collection_template.dart`](../lib/features/catalog/adapters/catalog_seed_to_collection_template.dart)) — catalog does **not** own shelf rows

**Never on catalog:** user figure state (owned/wishlist), `localImageUri`, cloud sync of collection, Firestore listeners for shelf.

### 2. User Private Shelf (local-first)

- **Purpose:** What the user saved — series instances, figure slots, progress.
- **Location:** `lib/features/collection/`
- **Source of truth:** `CollectionSnapshot` in [`collection_domain.dart`](../lib/features/collection/domain/collection_domain.dart)
- **Writes:** [`collectionNotifierProvider`](../lib/features/collection/application/collection_notifier.dart) only
- **Persistence:** `SharedPreferences` + [`collection_snapshot_codec.dart`](../lib/features/collection/persistence/collection_snapshot_codec.dart) (schema v2)
- **Media:**
  - `ShelfFigure.localImageUri` — device paths / `file:` URIs for user photos
  - `ShelfSeries.customCoverImageUri` — optional series cover (local only)
  - `ShelfFigure.imageUrl` — resolved catalog asset paths, network placeholders, or drop art — **not** `imageKey`
- **Resolution:** [`ShelfFigureMedia`](../lib/features/collection/presentation/shelf_figure_media.dart) for display priority

**Never on shelf:** `imageKey`, Firestore catalog documents, uploading private photos to cloud.

### 3. Market / Home (discover + listings)

- **Purpose:** Editorial feed (home) and market browse; entry points to save releases or view listings.
- **Locations:** `lib/features/home/`, `lib/features/market/`
- **Home:** Mock-driven today (`mock_latest_drops.dart`, etc.); save via `collectionNotifier.addSeriesFromRelease` + [`series_release_lookup`](../lib/features/collection/data/series_release_lookup.dart)
- **Market:** Bootstrap session → repository → Riverpod providers; DTOs/mappers under `features/market/data/`; UI uses [`MarketListing`](../lib/models/market_listing.dart) (shared presentation model)
- **Into shelf:** Notifier methods only (`addSeriesFromDrop`, etc.) — not direct snapshot mutation from widgets

---

## Data flow (high level)

```
Catalog universe (read-only)
  tools/seed JSON ──────────────┐
  Firestore loader ─────────────┼──> CatalogSeedBundle ──> CatalogSearchService
  Storage (catalog art) ────────┘     imageKey → bundled asset, then Storage URL
                                │
Adapters and UI                 │
  CatalogSeedBundle ────────────┼──> catalog_seed_to_collection_template ──> collectionNotifierProvider
  CollectionCatalog (hardcoded) ──> AddToCollectionSheet
                                        │
User shelf (local-first)                │
  collectionNotifierProvider <──────────┘
        │
        v
  CollectionSnapshot
        │
        v
  SharedPreferences codec

Market
  market_listings_bootstrap ──> MarketListingsRepository <── marketBrowseNotifier
```

**Startup ([`main.dart`](../lib/main.dart)):** bootstrap market listings → restore collection snapshot (or seed) → `ProviderScope` → `GoRouter`.

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
- **`CollectionCatalog`** (`collection/data/`) — hardcoded legacy suggestions; do not treat as a second catalog universe or extend without explicit task.
- **Dual catalog in add flow** — seed JSON + legacy catalog coexist; consolidating them is a future milestone, not default agent work.

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
| Catalog | Load on demand in UI (no global catalog provider yet) | `loadCatalogSeedBundle()` in add sheet |
| Firestore | Optional; `ensureFirebaseInitialized()` before catalog fetch | `ensure_firebase_initialized.dart` |

- **Do not** replace Riverpod.
- **Do not** add cloud sync for collection in MVP tasks unless explicitly requested.
- Market listings may use a **session singleton** after bootstrap — intentional; not every list goes through a `FutureProvider`.

---

## Firebase (Firestore + Storage)

Firebase is for the **catalog universe only** in the current roadmap. Collection stays local-first unless explicitly tasked otherwise.

### Firestore (catalog reference)

- **Collections:** `brands`, `ips`, `series`, `figures` — same field shapes as `tools/seed/*.json`. See [`FIRESTORE_CATALOG_SCHEMA.md`](../lib/features/catalog/firestore/FIRESTORE_CATALOG_SCHEMA.md).
- **Loader:** `loadFirestoreCatalogBundle()` — four one-shot `.get()` queries → `CatalogSeedBundle`. No realtime listeners for catalog in MVP.
- **Default in UI:** still `loadCatalogSeedBundle()` until a milestone **explicitly** switches the app default — do not change default source as drive-by work.
- **Init:** `ensureFirebaseInitialized()` before any Firestore/Storage call; run `flutterfire configure` and add platform config (`google-services.json`, `GoogleService-Info.plist`). Keep secrets out of git if your pipeline requires it.
- **Canonical ids:** match seed (e.g. IP `the_monsters`, not `labubu`).

### Storage (public catalog art)

- **Scope:** read-only catalog thumbnails keyed by `imageKey`. Paths like `catalog/figures/{imageKey}.webp`, `catalog/series/{imageKey}.webp`. See [`FIREBASE_STORAGE_CATALOG.md`](../lib/features/catalog/firestore/FIREBASE_STORAGE_CATALOG.md).
- **Not in scope for MVP agents:** uploading `localImageUri` / `customCoverImageUri` (private shelf photos).
- **Resolver:** bundled asset first, then Storage download URL, then placeholder — do not persist Storage URLs on `CollectionSnapshot` rows; shelf uses existing `imageUrl` / local URI rules.
- **Code location:** `lib/features/catalog/` and `lib/core/firebase/` — no `lib/services/`. Add `firebase_storage` when implementing reads.

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
- **Spacing:** Use [`FeedRhythm`](../lib/core/layout/feed_rhythm.dart) constants for tab feeds and collection shelf rhythm.
- **Imagery:** Large thumbnails, soft cards, placeholders on failure — never broken-image chaos.
- **Add-to-collection:** Series-centric search rows; tap row → preview sheet; **Add** button → commit. Subtitle: `Includes {figure}` or `{n} figures` (+ chase suffix) — not `Matched: …` lists.

### Catalog vs shelf images

- **Catalog UI/search:** `imageKey` → `CatalogImageResolver`
- **Shelf UI:** `ShelfFigureMedia` → `localImageUri` → `customCoverImageUri` → `imageUrl` → placeholder
- Do not put `imageKey` on `ShelfFigure` / `ShelfSeries`.

### MVP discipline

- Ship focused diffs; avoid rewriting `CatalogSearchService`, collection flow, or switching catalog source unless the task says so.
- Firestore catalog: loader exists; switching the app default source is a separate explicit milestone.
- Firebase Storage: catalog art only; see [Firebase](#firebase-firestore--storage) — not shelf photo upload unless tasked.
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

- [`docs/CURSOR_RULES.md`](../docs/CURSOR_RULES.md) — short rules; see this file + `.cursor/rules/` for agents
- [`docs/PROJECT_OVERVIEW.md`](../docs/PROJECT_OVERVIEW.md) — product vision; verify tech stack against this file for current implementation

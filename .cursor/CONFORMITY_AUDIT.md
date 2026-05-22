# Conformity audit (codebase vs architecture)

Checklist of how the live repo compares to [`.cursor/ARCHITECTURE.md`](ARCHITECTURE.md). **Docs-only** audit — not a mandate to refactor everything listed under drift.

Last reviewed against the repo structure and key files.

---

## Aligned

- [x] Feature-based layout under `lib/features/`
- [x] Collection mutations only via `CollectionNotifier` + `CollectionSnapshotCodec`
- [x] Market: `MarketSource` → repository → providers; HTTP in `ebay_http_browse_data_source.dart` and `data/datasource/mercari/` (sandbox gateway only)
- [x] Mercari live sandbox **off by default** (`MarketSandboxConfig`); asset bootstrap unchanged; manual refresh only
- [x] Catalog search is pure Dart over `CatalogSeedBundle`
- [x] Firestore loader returns same bundle type as seed loader
- [x] Shelf media separation (`imageKey` in catalog only; `localImageUri` / `imageUrl` on shelf)
- [x] `go_router` three-tab shell
- [x] Bootstrap in `main.dart` for market + collection restore
- [x] Legacy expansion guardrails documented (`lib/models/` frozen; feature-owned new models) in `ARCHITECTURE.md`
- [x] Firebase integration boundaries documented (Firestore + Storage catalog-only; shelf local-first) in `ARCHITECTURE.md` + `firebase-catalog.mdc`
- [x] Add Series uses `loadCatalogBundle()` (Firestore + seed fallback) and `pickLatestSeriesRecommendations` — not `CollectionCatalog`
- [x] `CatalogImageResolver` + Storage paths wired for catalog UI (`CatalogImageFromKey`, add sheet search)
- [x] Market browse stays on `MarketSource`/repository — no Firestore catalog queries for listing rows
- [x] Market identity matching: offline `CatalogIdentityIndex` + `MarketIdentityMatcher` at bootstrap (no matcher in widgets)
- [x] `MarketTaxonomy.applyCatalogBundle()` at startup; brand-scoped filter chips use Firestore-backed `_catalogBrands` / `_catalogIps`
- [x] Collectible market snapshots: aggregator + `CollectibleMarketSession` under `features/market/`; browse feed uses snapshot cards (listings stay transient)
- [x] Shelf emotional intelligence: derived `ShelfEmotionalProfile` + `CollectionMemoryStore`; no codec/schema change to shelf rows

---

## Known drift / transitional (documented; fix only when tasked)

- [ ] **`CollectionCatalog`** still exists for demo shelf seed (`collection_seed_data.dart`) — frozen; not the add-flow catalog source
- [ ] **Market listing card images** still from provider wire URLs / mock URLs — not Firebase Storage catalog art (intentional until tasked)
- [ ] **Shelf templates** may persist resolved Storage download URLs in `ShelfFigure.imageUrl` at add time (catalog clone path) — optional hardening later
- [ ] **Collection** remains local-first — no Firestore/Storage sync for shelf (intentional until a future milestone)
- [x] **`docs/PROJECT_OVERVIEW.md`** — updated to **SharedPreferences** and **`http`** (was Hive/Isar + Dio)
- [ ] **`lib/models/`** still **in use** for grandfathered presentation types (`Collectible`, `MarketListing`, …) — **expansion frozen**; migrate call sites only when explicitly tasked, not as default agent work
- [ ] **Market session singleton** alongside Riverpod (by design for bootstrap performance)
- [ ] **No `lib/services/`** directory

---

## When changing behavior

1. Identify which universe (catalog / shelf / market-home) is affected.
2. Avoid coupling UI to raw DTOs.
3. Do **not** add new types under `lib/models/` or introduce `lib/services/` — use the owning feature folder.
4. Preserve local-first collection persistence unless explicitly migrating storage.
5. Firebase work stays in **catalog** (`features/catalog/`, `core/firebase/`) — no shelf uploads, no catalog listeners, unless the task says otherwise.
6. Skip cleanup refactors and mass legacy migrations unless the user asked for them.
7. Run `flutter analyze` and `flutter test` before finishing.

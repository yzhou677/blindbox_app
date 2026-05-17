# Conformity audit (codebase vs architecture)

Checklist of how the live repo compares to [`.cursor/ARCHITECTURE.md`](ARCHITECTURE.md). **Docs-only** audit — not a mandate to refactor everything listed under drift.

Last reviewed against the repo structure and key files.

---

## Aligned

- [x] Feature-based layout under `lib/features/`
- [x] Collection mutations only via `CollectionNotifier` + `CollectionSnapshotCodec`
- [x] Market: datasource → mapper → repository → providers; HTTP only in `ebay_http_browse_data_source.dart`
- [x] Catalog search is pure Dart over `CatalogSeedBundle`
- [x] Firestore loader returns same bundle type as seed loader
- [x] Shelf media separation (`imageKey` in catalog only; `localImageUri` / `imageUrl` on shelf)
- [x] `go_router` three-tab shell
- [x] Bootstrap in `main.dart` for market + collection restore
- [x] Legacy expansion guardrails documented (`lib/models/` frozen; feature-owned new models) in `ARCHITECTURE.md`

---

## Known drift / transitional (documented; fix only when tasked)

- [ ] **Dual catalog in add flow:** Search uses seed JSON (`add_to_collection_sheet.dart`); idle suggestions use hardcoded `CollectionCatalog`; demo shelf seed uses `CollectionCatalog.defaultShelfSeries()` in `collection_seed_data.dart`
- [ ] **Firestore catalog** implemented but UI still defaults to `loadCatalogSeedBundle()`
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
5. Skip cleanup refactors and mass legacy migrations unless the user asked for them.
6. Run `flutter analyze` and `flutter test` before finishing.

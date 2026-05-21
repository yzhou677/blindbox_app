# Firebase Storage — catalog art (read path)

Public **catalog** thumbnails only. User shelf photos (`localImageUri`, `customCoverImageUri`) do **not** belong in Storage unless a future task explicitly adds cloud sync.

**Related:** [Firestore catalog schema](FIRESTORE_CATALOG_SCHEMA.md), [`.cursor/ARCHITECTURE.md`](../../../../.cursor/ARCHITECTURE.md) → Firebase section.

---

## Purpose

- Host series/figure art keyed by catalog **`imageKey`** (same opaque ids as Firestore documents and `tools/seed/`).
- Let the app ship a small bundled subset offline while loading the full catalog from Firestore + Storage when connected.

---

## Object path convention (recommended)

Use stable keys aligned with `imageKey` — not shelf ids, not display names.

```
catalog/figures/{imageKey}.webp
catalog/series/{imageKey}.webp
```

Examples:

- `catalog/figures/the_monsters_exciting_macaron_labubu_soymilk.webp`
- `catalog/series/the_monsters_exciting_macaron.webp`

Prefer **`.webp`** (or **`.avif`**) for size; keep extension consistent per upload pipeline. The app resolver may probe multiple extensions when falling back to bundled assets.

---

## Firestore ↔ Storage

- Firestore documents store **`imageKey` only** — not Storage URLs, not download tokens.
- At runtime, resolve `imageKey` → display URI in **`lib/features/catalog/`** (extend [`CatalogImageResolver`](../catalog_image_resolver.dart) or a sibling helper under `features/catalog/data/` or `firestore/`).
- **Do not** write resolved URLs onto `ShelfFigure` / `ShelfSeries` in `CollectionSnapshot`; shelf keeps `imageUrl` as a resolved path/URL at add time or placeholder, per existing shelf media rules.

---

## Resolver order (when Storage is wired)

1. **Bundled asset** under `assets/catalog/figures/` or `assets/catalog/series/` (offline / tests / partial bundle).
2. **Firebase Storage** download URL for `catalog/{figures|series}/{imageKey}.{ext}` (or cached disk copy of that URL).
3. **Placeholder** — never broken-image UI.

`tools/seed/` and `loadCatalogSeedBundle()` remain the **dev/test fallback** when Firebase is unavailable.

---

## Code placement

- Init: [`ensure_firebase_initialized.dart`](../../../core/firebase/ensure_firebase_initialized.dart) before Firestore or Storage calls.
- Storage access: **`lib/features/catalog/`** only (e.g. `firestore/` or `data/`) — **no** `lib/services/`, **no** `features/collection/` uploads in MVP.
- Package: add `firebase_storage` when implementing; keep `firebase_core` + `cloud_firestore` for catalog documents.

---

## Upload / admin (out of app MVP)

Ingestion scripts or console uploads write objects at the paths above and set matching `imageKey` on Firestore docs. The Flutter app is **read-only** for catalog Storage in Phase 1.

---

## Security rules (console / repo)

Document intent here; implement rules in Firebase console or `storage.rules` in your infra repo:

- **Catalog paths:** world-readable (or authenticated-read) for `catalog/**`.
- **No user shelf paths** under `users/` or similar until a dedicated collection-sync project exists.

---

## Taxonomy ids in Firestore

Use canonical catalog ids (e.g. IP document id **`the_monsters`**, not `labubu`). See [FIRESTORE_CATALOG_SCHEMA.md](FIRESTORE_CATALOG_SCHEMA.md).

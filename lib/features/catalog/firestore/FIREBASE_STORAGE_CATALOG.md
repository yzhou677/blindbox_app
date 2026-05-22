# Firebase Storage — catalog art (read path)

Public **catalog** thumbnails only. User shelf photos (`localImageUri`, `customCoverImageUri`) do **not** belong in Storage unless a future task explicitly adds cloud sync.

**Related:** [Firestore catalog schema](FIRESTORE_CATALOG_SCHEMA.md), [`.cursor/ARCHITECTURE.md`](../../../../.cursor/ARCHITECTURE.md) → Firebase section.

---

## Purpose

- Host series/figure art keyed by catalog **`imageKey`** (same opaque ids as Firestore documents and `tools/seed/`).
- Let the app ship a small bundled subset offline while loading the full catalog from Firestore + Storage when connected.

---

## Object path convention (required)

Paths are **deterministic** — constructed at runtime from `imageKey` only.

**Series:** `catalog/series/<imageKey>.<ext>`  
**Figures:** `catalog/figures/<imageKey>.<ext>`

**Supported `<ext>` (probe in this order until one exists):** `.avif`, `.webp`, `.png`, `.jpg`, `.jpeg`

Catalog art uses mixed formats in the bucket (mostly png / webp / jpg, some avif). Upload any supported extension; the app does not assume png-only.

**Upload rule:** `imageKey` on the Firestore doc must equal the Storage filename stem (no path, no extension). Examples:

- Series cover: `imageKey` `baby_molly_and_baby_tabby_series` → `catalog/series/baby_molly_and_baby_tabby_series.png`
- Figure: `imageKey` `aespa_…_giselle_ver` → `catalog/figures/aespa_…_giselle_ver.png`

The resolver does not rewrite keys (no `_series` suffix injection, no series+figure path concatenation).

Examples:

- `catalog/figures/the_monsters_exciting_macaron_labubu_soymilk.webp`
- `catalog/series/the_monsters_exciting_macaron.webp`

Upload binaries to these paths; set the same string as `imageKey` on the Firestore doc. Do **not** add `imagePath` or URL fields to catalog documents.

Dart helper: `CatalogImageResolver.storageObjectPath(kind:, imageKey:, extension:)`.

---

## Firestore ↔ Storage (separation of concerns)

- **Firestore** — canonical metadata only: ids, `displayName`, `imageKey`, taxonomy fields, dates
- **Storage** — binary assets only, at the paths above
- **App resolver** — `imageKey` + kind (series/figure) + extension → bundled asset or ephemeral download URL

**Never:**

- Store full Storage URLs in Firestore
- Add `imagePath` (or similar) to catalog docs
- Change the `imageKey` architecture

Resolved download URLs may appear in widget/shelf `imageUrl` at add time for display; that is a **runtime cache**, not catalog source of truth.

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

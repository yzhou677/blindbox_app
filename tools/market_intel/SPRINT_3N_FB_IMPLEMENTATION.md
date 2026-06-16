# Sprint 3N-FB — Firestore Catalog Loader (Implementation Summary)

**Date:** 2026-06-16  
**Scope:** Market pipeline reads Firestore catalog by default. No export automation, no schedulers.

---

## What changed

The market snapshot pipeline no longer depends on `tools/seed` for production runs.

| Before | After |
|--------|-------|
| `loadCatalogBundle()` → file / seed | `loadCatalogBundleForSource()` → **Firestore (default)** or file |
| No Firestore catalog read in Node | `loadFirestoreCatalogBundle()` reads 4 collections |
| Silent seed fallback | `CATALOG_STRICT=1` fails file mode on seed fallback |

---

## Architecture

```text
compute_snapshots.mjs
  --catalog-source firestore (default)
    → loadFirestoreCatalogBundle()
      → Firestore brands / ips / series / figures
      → assembleCatalogBundle()  (same shape as file loader)
  --catalog-source file
    → loadCatalogBundle()  (CATALOG_DATA_DIR or tools/seed)
```

Auth reuses the same Firebase Admin pattern as `push_market_snapshots.mjs` (`tools/catalog/_firebase_admin.mjs`).

Mapper mirrors `firestore_catalog_mapper.dart` (`tools/catalog/_firestore_catalog_mapper.mjs`).

---

## Changed files

| File | Change |
|------|--------|
| `tools/catalog/load_firestore_catalog_bundle.mjs` | **New** — Firestore catalog loader |
| `tools/catalog/_firestore_catalog_mapper.mjs` | **New** — Dart-aligned field mapping |
| `tools/catalog/_firebase_admin.mjs` | **New** — shared Admin SDK bootstrap |
| `tools/catalog/_firestore_catalog_mapper.test.mjs` | **New** — mapper tests |
| `tools/catalog/load_firestore_catalog_bundle.test.mjs` | **New** — loader bundle shape tests |
| `tools/catalog/_catalog_source.test.mjs` | **New** — source selection + strict mode |
| `tools/market_intel/_catalog_bundle.mjs` | `assembleCatalogBundle`, `loadCatalogBundleForSource`, strict helpers |
| `tools/market_intel/compute_snapshots.mjs` | `--catalog-source`, default firestore |

---

## Usage

```bash
# Production / default — read live Firestore catalog
node tools/market_intel/compute_snapshots.mjs --dry-run --figure hope

# Explicit Firestore
node tools/market_intel/compute_snapshots.mjs --fetch --catalog-source firestore

# Offline / fixture JSON directory
node tools/market_intel/compute_snapshots.mjs --dry-run --catalog-source file

# Fail if file mode would use tools/seed
CATALOG_STRICT=1 node tools/market_intel/compute_snapshots.mjs --dry-run --catalog-source file
```

Requires Firebase auth (same as `push_market_snapshots.mjs`): `firebase login`, `GOOGLE_APPLICATION_CREDENTIALS`, or `FIREBASE_PROJECT_ID`.

---

## Tests

```bash
node --test tools/catalog/_firestore_catalog_mapper.test.mjs \
  tools/catalog/load_firestore_catalog_bundle.test.mjs \
  tools/catalog/_catalog_source.test.mjs \
  tools/market_intel/_catalog_bundle.test.mjs
```

**Result:** 22 tests passed.

Existing `tools/market_intel/*` tests using sync `loadCatalogBundle()` unchanged.

---

## Analyze / lint

No Dart files changed. Node tests are the verification surface.

---

## Non-goals (unchanged)

Not implemented per sprint scope: export scripts, drift checks, seed refresh, schedulers, Marketplace Insights.

---

## Notes for solo ops

- **Default is Firestore** — running `compute_snapshots` without flags no longer reads stale seed.
- **`tools/seed` remains** for Flutter first-install bootstrap and optional `--catalog-source file` dev runs.
- **`CATALOG_DATA_DIR`** still works with `--catalog-source file` for pinned JSON dirs when debugging without Firebase.
- **No second auth system** — `_firebase_admin.mjs` copies `push_market_snapshots.mjs` credential resolution.

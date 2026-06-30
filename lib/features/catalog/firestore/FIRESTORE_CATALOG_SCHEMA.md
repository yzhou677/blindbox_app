# Firestore catalog schema (canonical)

The live Firebase project uses **four top-level collections only**. The app reads them directly via `loadFirestoreCatalogBundle()` — no alternate layouts, nested hierarchies, duplicate catalog trees, or separate image-metadata collections.

Maps into Dart models (`CatalogBrand`, `CatalogIp`, `CatalogSeries`, `CatalogFigure`) through `firestore_catalog_mapper.dart`. Field names use the same camelCase keys as the external catalog export JSON (historical shape; **not** shipped in the APK at runtime).

**Storage (binary art):** [`FIREBASE_STORAGE_CATALOG.md`](FIREBASE_STORAGE_CATALOG.md) — paths are `catalog/series/<imageKey>.<ext>` and `catalog/figures/<imageKey>.<ext>`, resolved in app code only.

**Agent rules:** [`.cursor/ARCHITECTURE.md`](../../../../.cursor/ARCHITECTURE.md), [`.cursor/rules/firebase-catalog.mdc`](../../../../.cursor/rules/firebase-catalog.mdc).

## Do not introduce

- Alternate collection names or subcollection hierarchies under brands/ips/series
- Duplicate catalog collections (e.g. a second `catalog_*` namespace)
- `imagePath`, Storage URLs, or download tokens on Firestore documents
- Dynamic or generated Storage folder structures — paths are deterministic from `imageKey` + kind + extension (see Storage doc)

## Collections (use as-is)

- `brands`
- `ips`
- `series`
- `figures`

Each **document id** is the **canonical id** (console path `series/the_monsters_exciting_macaron` means document id `the_monsters_exciting_macaron`, not slashes inside the id).

## Canonical id alignment

These ids must match everywhere:

- Firestore document id and `id` field (when present)
- `brandId`, `ipId`, `seriesId` cross-references on child docs
- `imageKey` on series/figure docs (opaque; often equals figure/series id stem)
- Firebase Storage object name: `catalog/series/<imageKey>.<ext>` or `catalog/figures/<imageKey>.<ext>`
- Market/collection filter chips (`MarketTaxonomy.applyCatalogBundle`)
- Shelf `catalogTemplateId` / figure template ids after add-from-catalog

Display names are labels only — never used as filter ids or Storage paths.

## Document fields

Field names use the same camelCase keys as the JSON seed.

### `brands/{brandId}`

- `displayName` (string)
- `aliases` (array of strings, optional)
- `id` (string, optional) — if omitted or empty, the loader uses the document id

### `ips/{ipId}`

- `brandId` (string)
- `displayName` (string)
- `aliases` (array of strings, optional) — e.g. `ips/the_monsters` with `displayName` **THE MONSTERS** and alias **Labubu** for search
- `id` (optional)

Canonical POP MART lineup IP id is **`the_monsters`** (not `labubu`; Labubu is a character alias).

### `series/{seriesId}` (live example: `aespa_fluffy_club_vinyl_plush_doll_pendant_series`)

- `id` (string) — usually equals document id
- `brandId`, `ipId`, `displayName` (strings)
- `imageKey` (string) — equals document id stem; Storage `catalog/series/<imageKey>.<ext>`
- `aliases` (array of strings, optional) — used by catalog search
- `releaseDate` — string `YYYY-MM-DD`, Firestore **`Timestamp`**, or **`null`**
- `isBlindBox` (bool)

### `figures/{figureId}` (live example: `aespa_…_fiuffy_gelbulnyangi_giselle_ver`)

- `id` (string) — equals document id
- `imageKey` (string) — equals document id stem; Storage `catalog/figures/<imageKey>.<ext>`
- `brandId`, `ipId`, `seriesId` (strings) — cross-refs to parent docs
- `displayName` (string)
- `rarityLabel` (string or **`null`**)
- `isSecret` (bool)
- `sortOrder` (int; Firestore may store as number/double)

Documents missing `imageKey` or required strings are **skipped** at load time (logged).

## Loader behavior

- `loadFirestoreCatalogBundle()` performs **four one-shot `.get()` queries** (no streams). Called from `CatalogBundleCache` — widgets consume `catalogBundleProvider`, not Firestore directly.
- Invalid documents are **skipped**; failures are **logged** with `debugPrint` in the mapper.
- Results are sorted by canonical `id` for stable ordering.

## Runtime source of truth

| Layer | Role |
|-------|------|
| **Firestore** | Authoritative catalog metadata at runtime (when network + init succeed) |
| **Persisted cache** | `catalog_bundle_v1.json` on disk — offline runtime baseline after first successful load |
| **`catalogBundleProvider`** | In-memory `CatalogSeedBundle` + `CatalogBundleMemoryOrigin` for the reactive provider graph |

**No APK metadata seed.** Runtime bootstrap `tools/seed/*.json` was removed; the app does not fall back to bundled metadata JSON on Firestore failure.

## External catalog export (dev / ingestion only)

- Canonical export for upload + offline admin: `D:\blindbox-catalog\data\{brands,ips,series,figures}.json` (keep in sync with Firestore).
- Run `flutterfire configure` and add platform config files (`google-services.json`, etc.) before expecting Firestore on device.

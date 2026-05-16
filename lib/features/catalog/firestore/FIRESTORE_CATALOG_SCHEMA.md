# Firestore catalog schema (Phase 1)

Remote catalog data mirrors the shapes in `tools/seed/*.json` and maps into the
same Dart models (`CatalogBrand`, `CatalogIp`, `CatalogSeries`, `CatalogFigure`)
via `firestore_catalog_mapper.dart`.

## Collections (top-level)

- **`brands`**
- **`ips`**
- **`series`**
- **`figures`**

Each **document id** is the **canonical id** (e.g. `series/the_monsters_exciting_macaron` in the console is document id `the_monsters_exciting_macaron`, not a path with slashes).

## Document fields

Field names use the same camelCase keys as the JSON seed.

### `brands/{brandId}`

- `displayName` (string)
- `aliases` (array of strings, optional)
- `id` (string, optional) — if omitted or empty, the loader uses the document id

### `ips/{ipId}`

- `brandId` (string)
- `displayName` (string)
- `aliases` (array of strings, optional)
- `id` (optional)

### `series/{seriesId}`

- `brandId`, `ipId`, `displayName` (strings)
- `releaseDate` — string `YYYY-MM-DD`, Firestore **`Timestamp`**, or **`null`** (normalized to UTC `YYYY-MM-DD` when Timestamp)
- `isBlindBox` (bool)
- `imageKey` (string) — opaque thumbnail identity; mirrors `seriesId` today; clients resolve to bundled assets or future Storage/CDN URLs
- `id` (optional)

Legacy **`thumbnailAsset`** may still arrive from older documents; Dart parsers derive a provisional key from path stems when `imageKey` is missing. Prefer **`imageKey` only** for new writes.

### `figures/{figureId}`

- `seriesId`, `brandId`, `ipId`, `displayName` (strings)
- `isSecret` (bool)
- `rarityLabel` (string, optional)
- `sortOrder` (int or number)
- `imageKey` (string) — opaque thumbnail identity aligned with canonical `figureId`
- `id` (optional)

Legacy **`thumbnailAsset`** is tolerated during migration; **`imageKey` only** going forward.

## Loader behavior

- `loadFirestoreCatalogBundle()` performs **four one-shot `.get()` queries** (no streams).
- Invalid documents are **skipped**; failures are **logged** with `debugPrint` in the mapper.
- Results are sorted by canonical `id` for stable ordering.

## Local JSON

- `loadCatalogSeedBundle()` is unchanged and remains the default for the app and tests.
- Run `flutterfire configure` and add platform config files (`google-services.json`, etc.) before expecting Firestore to work on device.

# Firestore catalog schema (canonical)

The live Firebase project uses **four top-level catalog collections** plus one
**sync cursor** document. The app reads catalog metadata via
`loadFirestoreCatalogBundle()` (today: four one-shot `.get()` calls). Incremental
sync (PR2b) additionally reads `meta/catalog` and `updatedAt`-filtered queries.

Maps into Dart models (`CatalogBrand`, `CatalogIp`, `CatalogSeries`, `CatalogFigure`)
through `firestore_catalog_mapper.dart`. Field names use the same camelCase keys as
the external catalog export JSON (historical shape; **not** shipped in the APK at
runtime).

**Storage (binary art):** [`FIREBASE_STORAGE_CATALOG.md`](FIREBASE_STORAGE_CATALOG.md) —
paths are `catalog/series/<imageKey>.<ext>` and `catalog/figures/<imageKey>.<ext>`,
resolved in app code only.

**Ingest / backfill contract (external repo):**
[`docs/CATALOG_DELTA_SYNC_INGEST.md`](../../../../docs/CATALOG_DELTA_SYNC_INGEST.md).

**Agent rules:** [`.cursor/ARCHITECTURE.md`](../../../../.cursor/ARCHITECTURE.md),
[`.cursor/rules/firebase-catalog.mdc`](../../../../.cursor/rules/firebase-catalog.mdc).

## Product rule: catalog is never deleted

Shelfy is a collectible atlas. Discontinued products **remain** in Firestore.
Do **not** hard-delete catalog documents, introduce `deleted` / tombstone fields,
or prune remote catalog rows as part of sync. Incremental sync is **add + update
only**.

## Do not introduce

- Alternate collection names or subcollection hierarchies under brands/ips/series
- Duplicate catalog collections (e.g. a second `catalog_*` namespace)
- `imagePath`, Storage URLs, or download tokens on Firestore documents
- Dynamic or generated Storage folder structures — paths stay deterministic from
  `imageKey` + kind + extension (see Storage doc)
- Soft-delete / tombstone fields on catalog docs

## Collections

- `brands`
- `ips`
- `series`
- `figures`
- `meta/catalog` — sync cursor only (not entity metadata)

Each **catalog document id** is the **canonical id** (console path
`series/the_monsters_exciting_macaron` means document id
`the_monsters_exciting_macaron`, not slashes inside the id).

## Canonical id alignment

These ids must match everywhere:

- Firestore document id and `id` field (when present)
- `brandId`, `ipId`, `seriesId` cross-references on child docs
- `imageKey` on series/figure docs (opaque; often equals figure/series id stem)
- Firebase Storage object name: `catalog/series/<imageKey>.<ext>` or
  `catalog/figures/<imageKey>.<ext>`
- Market/collection filter chips (`MarketTaxonomy.applyCatalogBundle`)
- Shelf `catalogTemplateId` / figure template ids after add-from-catalog

Display names are labels only — never used as filter ids or Storage paths.

## Sync fields (additive — old clients ignore)

All new fields are **optional for readers**. Missing fields must not break older
apps (they keep doing full-collection `.get()`).

| Field | Where | Type | Meaning |
| --- | --- | --- | --- |
| `updatedAt` | brands, ips, series, figures | Firestore `Timestamp` | Last time this document’s catalog payload meaningfully changed |
| `imageVersion` | series, figures (primary art); each `alternativeImages[]` entry | string | Firebase Storage object **`md5Hash`** for that art object (base64 as returned by GCS/Firebase). **Not** a custom hash. **Never** a URL |
| `lastUpdatedAt` | `meta/catalog` only | Firestore `Timestamp` | Max watermark over catalog writes in the last successful ingest/backfill that changed something |

### `imageVersion` rules

- Source of truth: Storage object metadata `md5Hash` after upload (or existing
  object during backfill — **no re-upload required**).
- Primary series cover → top-level `series.imageVersion`.
- Primary figure art → top-level `figures.imageVersion`.
- Recognition-only `alternativeImages[]` entries → per-entry `imageVersion` for
  that entry’s `imageKey` Storage object.
- Do **not** change `imageKey` when bytes change; bump `imageVersion` + `updatedAt`.
- Do **not** store download URLs or `imagePath` on docs.

### `updatedAt` rules

- Set when document **content** actually changes (metadata and/or `imageVersion`).
- Ingest must **not** bump `updatedAt` on no-op re-uploads of identical payloads
  (avoids false incremental pulls).
- Clients (PR2b) query `updatedAt > lastSyncAt` per collection.

## Document fields

Field names use the same camelCase keys as the JSON seed.

### `brands/{brandId}`

- `displayName` (string)
- `aliases` (array of strings, optional)
- `id` (string, optional) — if omitted or empty, the loader uses the document id
- `updatedAt` (Timestamp, optional until backfill) — sync watermark

### `ips/{ipId}`

- `brandId` (string)
- `displayName` (string)
- `aliases` (array of strings, optional) — e.g. `ips/the_monsters` with
  `displayName` **THE MONSTERS** and alias **Labubu** for search
- `id` (optional)
- `updatedAt` (Timestamp, optional until backfill)

Canonical POP MART lineup IP id is **`the_monsters`** (not `labubu`; Labubu is a
character alias).

### `series/{seriesId}` (live example: `aespa_fluffy_club_vinyl_plush_doll_pendant_series`)

- `id` (string) — usually equals document id
- `brandId`, `ipId`, `displayName` (strings)
- `imageKey` (string) — equals document id stem; Storage
  `catalog/series/<imageKey>.<ext>`
- `imageVersion` (string, optional) — Storage `md5Hash` for primary cover object
- `aliases` (array of strings, optional) — used by catalog search
- `releaseDate` — string `YYYY-MM-DD`, Firestore **`Timestamp`**, or **`null`**
- `isBlindBox` (bool)
- `updatedAt` (Timestamp, optional until backfill)

### `figures/{figureId}` (live example: `aespa_…_fiuffy_gelbulnyangi_giselle_ver`)

- `id` (string) — equals document id
- `imageKey` (string) — equals document id stem; Storage
  `catalog/figures/<imageKey>.<ext>`
- `imageVersion` (string, optional) — Storage `md5Hash` for primary figure object
- `brandId`, `ipId`, `seriesId` (strings) — cross-refs to parent docs
- `displayName` (string)
- `rarityLabel` (string or **`null`**)
- `isSecret` (bool)
- `sortOrder` (int; Firestore may store as number/double)
- `alternativeImages` (array, optional) — recognition-only; not Catalog UI
  - `imageKey` (string)
  - `variant` (string)
  - `imageVersion` (string, optional) — Storage `md5Hash` for that alternative object
- `updatedAt` (Timestamp, optional until backfill)

Documents missing `imageKey` or required strings are **skipped** at load time
(logged). Missing sync fields are ignored by old clients and treated as “unknown
version / needs full reconcile” by new clients after PR2b/PR2c.

### `meta/catalog`

Single document (id must be **`catalog`** under collection **`meta`**):

- `lastUpdatedAt` (Timestamp) — catalog sync watermark for clients

No other fields are required for PR2. Do not put entity lists here.

**Security:** public read, client write denied — see `firestore.rules`.

## Loader behavior (current app — until PR2b)

- `loadFirestoreCatalogBundle()` performs **four one-shot `.get()` queries** (no
  streams). Called from `CatalogBundleCache` — widgets consume
  `catalogBundleProvider`, not Firestore directly.
- Invalid documents are **skipped**; failures are **logged** with `debugPrint` in
  the mapper.
- Results are sorted by canonical `id` for stable ordering (series: release-date
  aware ordering in the loader).

## Indexes

Incremental queries are single-field:

```text
collection.where('updatedAt', isGreaterThan: lastSyncAt)
```

Firestore’s automatic single-field indexes cover `updatedAt`. No composite index
is required for the PR2b query shape. Do **not** combine with a `deleted` filter
(catalog never soft-deletes).

## Runtime source of truth

| Layer | Role |
|-------|------|
| **Firestore** | Authoritative catalog metadata at runtime (when network + init succeed) |
| **Persisted cache** | `catalog_bundle_v1.json` on disk — offline runtime baseline after first successful load |
| **`catalogBundleProvider`** | In-memory `CatalogSeedBundle` + `CatalogBundleMemoryOrigin` for the reactive provider graph |
| **`meta/catalog`** | Sync cursor for incremental refresh (PR2b); ignored by older apps |

**No APK metadata seed.** Runtime bootstrap `tools/seed/*.json` was removed; the
app does not fall back to bundled metadata JSON on Firestore failure.

## External catalog export (dev / ingestion only)

- Canonical export for upload + offline admin:
  `D:\blindbox-catalog\data\{brands,ips,series,figures}.json` (keep in sync with
  Firestore).
- Run `flutterfire configure` and add platform config files
  (`google-services.json`, etc.) before expecting Firestore on device.

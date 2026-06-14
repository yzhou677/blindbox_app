# Firestore market snapshots schema (canonical)

The app reads **one top-level collection only** for V2 market intelligence: `market_snapshots`.

Maps into [`MarketSnapshot`](../../domain/market_snapshot.dart) through [`firestore_market_snapshot_mapper.dart`](firestore_market_snapshot_mapper.dart).

**Writers:** admin tools under `tools/market_intel/` only. The Flutter app is **read-only**.

**Catalog context:** `brandId`, `ipId`, and display names are **not** stored here — resolve from the catalog bundle at UI time using `figureId` / `seriesId`.

**Agent rules:** [`.cursor/ARCHITECTURE.md`](../../../../.cursor/ARCHITECTURE.md).

## Do not introduce

- `brandId` or `ipId` on snapshot documents (derivable from catalog)
- Price history subcollections until explicitly scoped (future additive change)
- Stream listeners in the Flutter app for snapshots (daily admin cadence; one-shot reads only)
- Search terms or matching metadata on snapshot documents (lives in `tools/market_intel/market_metadata.json`)

## Collection

- `market_snapshots`

Each **document id** is the catalog **`figureId`** (figure-level snapshot) or **`seriesId`** (series-level fallback snapshot). Document ids are already globally namespaced by the catalog.

## Document fields

Field names use camelCase.

### `market_snapshots/{snapshotId}`

- `level` (string) — `"figure"` or `"series"`
- `figureId` (string or null) — required when `level == "figure"`; must be absent or null when `level == "series"`
- `seriesId` (string) — always required; used for batch queries by series
- `estimatedValueUsd` (number) — median of qualifying completed sales after outlier filtering; must be > 0
- `trend` (string, optional) — `"rising"` | `"falling"` | `"stable"` | `"unknown"`. When absent or unrecognized, the mapper defaults to `unknown`
- `confidence` (string) — `"high"` | `"low"`
- `recentSalesCount` (number, int) — qualifying sales in the aggregation window
- `priceRangeMinUsd` (number or null, optional)
- `priceRangeMaxUsd` (number or null, optional)
- `computedAt` (Timestamp) — when the admin pipeline last computed this snapshot
- `id` (string, optional) — if omitted or empty, the loader uses the document id

Documents missing required fields or with invalid enum values are **skipped** at load time.

## Composite index

Required for `getSnapshotsForSeries()`:

- Collection: `market_snapshots`
- Fields: `seriesId` Ascending, `level` Ascending

## Loader behavior

- `FirestoreMarketSnapshotRepository` performs **one-shot `.get()`** queries (no streams)
- Invalid documents are **skipped**; failures are **logged** with `debugPrint` in the mapper/repository
- Figure lookup: direct document read by `figureId`
- Series fallback lookup: direct document read by `seriesId`
- Series batch: query `where seriesId == X and level == figure`

## Example figure document

```json
{
  "level": "figure",
  "figureId": "lucky_big_into_energy_popmart",
  "seriesId": "big_into_energy_popmart",
  "estimatedValueUsd": 42,
  "trend": "rising",
  "confidence": "high",
  "recentSalesCount": 18,
  "priceRangeMinUsd": 35,
  "priceRangeMaxUsd": 55,
  "computedAt": "2026-06-14T12:00:00Z"
}
```

## Example series fallback document

```json
{
  "level": "series",
  "seriesId": "big_into_energy_popmart",
  "estimatedValueUsd": 28,
  "trend": "unknown",
  "confidence": "low",
  "recentSalesCount": 5,
  "computedAt": "2026-06-14T12:00:00Z"
}
```

## Future additive changes

- `price_history/{YYYY-MM-DD}` subcollection — not defined or written in Sprint 1. Can be added without migrating existing snapshot documents.

# Firestore Persistence Design

> **Sprint 2 Step 4A** — design only. No Firestore writes. No schema migrations.
>
> Question answered: *When a snapshot is produced, where exactly should it be stored?*

---

## Key Finding

**The Firestore schema already exists.**

Before designing anything, reading the existing codebase reveals:

| Artifact | File | Status |
|----------|------|--------|
| Canonical schema | `lib/features/market_intel/data/firestore/FIRESTORE_MARKET_SNAPSHOTS_SCHEMA.md` | ✅ Done |
| Flutter domain model | `lib/features/market_intel/domain/market_snapshot.dart` | ✅ Done |
| Flutter read repository | `lib/features/market_intel/data/firestore/firestore_market_snapshot_repository.dart` | ✅ Done |
| Firestore mapper | `lib/features/market_intel/data/firestore/firestore_market_snapshot_mapper.dart` | ✅ Done |
| Riverpod provider | `lib/features/market_intel/application/market_snapshot_providers.dart` | ✅ Done |
| Dev badge widget | `lib/features/market_intel/widgets/market_snapshot_badge.dart` | ✅ Done |
| Dev write tool | `tools/market_intel/push_market_snapshots_dev.mjs` | ✅ Done |
| **Production write tool** | `tools/market_intel/push_market_snapshots.mjs` | ❌ Not started |

The schema decision (Option A) was made when the Flutter side was built. This document confirms it is correct and documents the exact bridge needed between the admin pipeline output and the existing Firestore schema.

---

## Section 1 — Current Snapshot Shape

The admin pipeline (`_snapshot_document.mjs`) produces a `SnapshotDocument` with these fields:

| Field | Type | Source | Classification |
|-------|------|--------|----------------|
| `figureId` | `string` | figure catalog row | Required |
| `snapshotAt` | `ISO 8601 string` | `new Date().toISOString()` | Required |
| `sampleSize` | `number` | aggregation result | Required |
| `averagePrice` | `number \| null` | aggregation result | Computed |
| `medianPrice` | `number \| null` | aggregation result | Computed — used as `estimatedValueUsd` |
| `minPrice` | `number \| null` | aggregation result | Computed — optional |
| `maxPrice` | `number \| null` | aggregation result | Computed — optional |
| `dataSource` | `string` | `'fixture'` or `'live'` | Internal provenance only |

**Fields missing for Firestore:**

| Required by Firestore | Currently in pipeline | Gap |
|-----------------------|----------------------|-----|
| `seriesId` | ❌ | Must add — available from catalog bundle at match time |
| `level` | ❌ | Constant `"figure"` for all pipeline-produced documents |
| `confidence` | ❌ | Must compute from `sampleSize` |
| `trend` | ❌ | MVP: always `"unknown"` |

---

## Section 2 — Recommended Firestore Schema

### The existing schema is confirmed: Option A

The Flutter read layer already implements Option A. Changing it would break existing code with no benefit.

```
market_snapshots/{snapshotId}
```

**Document ID rules:**
- Figure-level snapshot: `docId = figureId`
- Series-level fallback: `docId = seriesId`

These IDs are already globally namespaced by the catalog (e.g.
`the_monsters_big_into_energy_vinyl_plush_pendant_luck`). No collision risk.

---

### Option comparison (for documentation)

| | Option A — flat, latest | Option B — flat + subcollection | Option C — run-based |
|--|------------------------|---------------------------------|----------------------|
| Complexity | ✅ Simple | ⚠️ Medium | ❌ Complex |
| Read pattern | ✅ Single doc get | ✅ Single doc get | ❌ Nested query |
| History support | ❌ Overwrite only | ✅ Subcollection optional | ✅ Built-in |
| Firestore cost | ✅ Lowest | Low (additive) | Higher |
| Already implemented | ✅ Yes | ❌ No | ❌ No |
| Solo dev maintenance | ✅ Minimal | Acceptable | High |

Option A is correct. Option B's history subcollection (`price_history/{YYYY-MM-DD}`) is
explicitly designed as an **additive future change** in the canonical schema — it can be added
without migrating existing documents.

---

## Section 3 — Field Mapping: Pipeline → Firestore

This is the exact translation the production writer must perform:

| Pipeline field | Firestore field | Transformation |
|----------------|-----------------|----------------|
| `figureId` | `figureId` | Direct |
| `(catalog lookup)` | `seriesId` | Look up via `figure.seriesId` from bundle |
| `(constant)` | `level` | Always `"figure"` for pipeline-produced documents |
| `medianPrice` | `estimatedValueUsd` | Direct rename; **skip document if null or ≤ 0** |
| `(computed)` | `confidence` | `sampleSize >= 5` → `"high"` ; `< 5` → `"low"` |
| `(constant)` | `trend` | Always `"unknown"` for MVP |
| `sampleSize` | `recentSalesCount` | Direct rename |
| `minPrice` | `priceRangeMinUsd` | Direct rename; omit field if null |
| `maxPrice` | `priceRangeMaxUsd` | Direct rename; omit field if null |
| `snapshotAt` | `computedAt` | Use Firestore `serverTimestamp()` instead of the pipeline ISO string |
| `averagePrice` | _(not stored)_ | Internal only; do not write to Firestore |
| `dataSource` | _(not stored)_ | Internal provenance; do not write to Firestore |

### Write condition

Only write a document to Firestore if:

```
medianPrice !== null && medianPrice > 0
```

Figures with no matched listings (`sampleSize === 0`) produce `medianPrice === null`. Writing a
document with `estimatedValueUsd = 0` or `null` would fail the mapper's validation rule
(`estimatedValueUsd > 0`) and be skipped at read time anyway. Better to not write at all.

### Why `medianPrice` and not `averagePrice`?

Median is more robust to outlier listings (very high chase prices contaminating averages). The
`MarketSnapshot` domain model uses `estimatedValueUsd` as the primary display value, shown as
`~$42` in the badge. A single $200 chase listing skews the average significantly but barely
moves the median.

---

## Section 4 — Read Patterns

All three read patterns are already implemented in `FirestoreMarketSnapshotRepository`.

### Figure page — show latest valuation for one figure

```dart
final snapshot = await repo.getSnapshotForFigure(figureId);
```

Implementation: direct `.doc(figureId).get()` — single document read.

**Fallback (series estimate):** If figure-level document doesn't exist, the Riverpod provider
falls back to `repo.getSnapshotForSeries(catalogFigure.seriesId)`.

### Collection page — show valuations for many owned figures

```dart
// Per figure, called by marketSnapshotProvider
final snapshot = await repo.getSnapshotForFigure(figureId);
```

Each shelf figure triggers one Riverpod provider. Each provider does one Firestore document
read. Riverpod caches results per `figureId` for the lifetime of the widget tree. For a
collection of 50 figures, this is ≤ 50 Firestore reads on first load, then from cache.

### Series page — all figure valuations in one series

```dart
final snapshots = await repo.getSnapshotsForSeries(seriesId);
```

Implementation: composite query `where('seriesId', '==', X).where('level', '==', 'figure')`.
Requires the composite index on `(seriesId ASC, level ASC)` — documented in the schema file,
must be created in the Firebase console or `firestore.indexes.json`.

**No stream listeners.** The schema explicitly requires one-shot `.get()` only. Snapshots are
produced on a daily/weekly admin cadence. There is no value in real-time updates.

---

## Section 5 — Historical Data Strategy

### MVP: Latest Only

Each pipeline run overwrites the existing document for each `figureId`. The `computedAt`
Timestamp reflects when the document was last updated. No history is stored.

This is the correct starting point:
- Zero additional complexity
- Trend computation requires 2+ snapshots; impossible without history anyway
- First production run produces the baseline; history starts from run 2

### Future: Additive History Subcollection

The canonical schema already reserves this path:

```
market_snapshots/{figureId}/price_history/{YYYY-MM-DD}
```

This subcollection can be added in a future sprint **without migrating any existing documents**.
The Flutter repository can be extended with a new `getPriceHistory(figureId)` method.

**Trend computation** becomes possible once at least 2 snapshot dates exist:

```
if medianPrice(today) / medianPrice(7d ago) > 1.15 → "rising"
if medianPrice(today) / medianPrice(7d ago) < 0.85 → "falling"
else → "stable"
```

Until then, `trend = "unknown"` is the correct MVP value. The badge widget suppresses trend
display when `trend == MarketTrend.unknown` (returns null from `_trendLabel`).

### Storage estimate (for context)

| Structure | Documents | Size estimate |
|-----------|----------:|---------------|
| Latest-only, 1,137 figures | ~1,200 | < 200 KB |
| 52 weeks of history per figure | ~62,400 | < 10 MB |

Firestore free tier is 1 GB storage. History for the full catalog for a full year is
negligible.

---

## Section 6 — Rebuild Strategy

Snapshots are purely computed from listing data + catalog context. They can always be fully
rebuilt.

### When to rebuild

| Trigger | Action |
|---------|--------|
| Matcher version changes (new algorithm) | Full rebuild — all snapshot scores may differ |
| Catalog figure added or updated | Targeted rebuild — affected figure(s) only |
| Series metadata changes | Targeted rebuild — affected series |
| `market_metadata.json` override added | Targeted rebuild — affected figure(s) only |
| Scheduled run (cadence) | Incremental or full rebuild per scheduler policy |

### How to rebuild

The CLI already supports targeted runs:

```bash
# Full rebuild (all figures)
node tools/market_intel/compute_snapshots.mjs --fetch

# Single figure
node tools/market_intel/compute_snapshots.mjs --fetch --figure luck

# Single series
node tools/market_intel/compute_snapshots.mjs --fetch --series big_into_energy
```

After generalized matcher, `buildFigureSearchPlans` handles filtering. Once the production
writer (`push_market_snapshots.mjs`) is implemented, a full rebuild is:

```bash
EBAY_ENV=production node tools/market_intel/compute_snapshots.mjs --fetch
# → produces SnapshotDocuments in memory
# → writer reads them and batch-writes to Firestore
```

### Overwrite safety

`push_market_snapshots_dev.mjs` uses `batch.set(..., { merge: true })` which merges rather
than overwrites. For production, `set` without `merge` (or with specific field mask) is safer
— it ensures stale fields from previous matcher versions are not carried forward.

Recommendation for production writer: use `set` without `merge: true` for figure-level
documents. The entire document is recomputed on each run; there is no partial-update scenario.

---

## Section 7 — Migration Plan

### Step 1 — Extend `SnapshotDocument` with `seriesId`

Add `seriesId: string` to the `SnapshotDocument` typedef and `buildSnapshotDocument()`.
The figure's `seriesId` is already available in `buildFigureSnapshot()` via the catalog bundle.
No matcher or aggregator changes needed.

### Step 2 — Add `confidence` computation to `buildSnapshotDocument`

Compute `confidence: 'high' | 'low'` based on `sampleSize >= 5`.
The threshold is defined as a named constant (`CONFIDENCE_HIGH_THRESHOLD = 5`) for easy adjustment.

### Step 3 — Implement `push_market_snapshots.mjs`

Create the production Firestore writer. Pattern is `push_market_snapshots_dev.mjs` extended to:

- Read pipeline output (in-memory `SnapshotDocument[]`) or a JSON file produced by the pipeline
- Map fields per the bridge table in Section 3
- Write to `market_snapshots` via Firebase Admin SDK
- Skip documents where `estimatedValueUsd <= 0`
- Use `set` (not `merge: true`) for clean overwrites
- Report written, skipped, and failed counts

Two integration models:
- **Inline** — writer runs inside `compute_snapshots.mjs` after each figure's snapshot (lowest latency, one write per figure, ~1,137 writes per full run)
- **Batch** — pipeline outputs all documents to a JSON file, writer is a separate invocation that batch-writes them

**Recommendation:** batch model. Separates concerns, allows dry-run inspection of the full
document set before committing, and matches the dev tool pattern.

### Step 4 — Create or verify Firestore composite index

The `getSnapshotsForSeries()` query requires a composite index on
`(seriesId ASC, level ASC)`. Create it in `firestore.indexes.json` or via the Firebase
console before the first production run.

### Step 5 — First production validation run

With Marketplace Insights access:

1. Run `compute_snapshots.mjs --fetch --series the_monsters_big_into_energy_vinyl_plush_pendant`
2. Inspect the in-memory snapshot documents
3. Run the production writer in dry-run mode to verify field mapping
4. Commit the batch write
5. Launch the Flutter app dev screen (`--dart-define=MARKET_SNAPSHOT_DEV=true`) and verify
   Cases A/B/C match expectations

### Step 6 — Full catalog production run

Once single-series validation passes, run full catalog fetch + write.

---

## Section 8 — Recommendation

### Recommended schema

```
Collection:  market_snapshots
Document ID: figureId  (for figure-level documents)
             seriesId  (for series-level fallback documents)
```

```jsonc
// market_snapshots/{figureId}
{
  "level":            "figure",
  "figureId":         "the_monsters_big_into_energy_vinyl_plush_pendant_luck",
  "seriesId":         "the_monsters_big_into_energy_vinyl_plush_pendant",
  "estimatedValueUsd": 42.0,          // medianPrice from aggregation
  "trend":            "unknown",      // always "unknown" for MVP
  "confidence":       "high",         // sampleSize >= 5
  "recentSalesCount": 18,             // sampleSize from aggregation
  "priceRangeMinUsd": 35.0,
  "priceRangeMaxUsd": 55.0,
  "computedAt":       /* Firestore serverTimestamp() */
}
```

### What is not stored

| Field | Reason |
|-------|--------|
| `brandId`, `ipId` | Derivable from catalog at UI time; keeping snapshot documents catalog-independent |
| `averagePrice` | Internal; median is the display value |
| `dataSource` | Pipeline provenance; not relevant to the client |
| `matcherVersion` | Nice-to-have; defer to a later sprint (additive field) |
| `runId` | Nice-to-have; defer (additive field) |
| `figureDisplayName` | Derivable from catalog; not needed in snapshot document |

### Design principles applied

- **Simple first**: flat collection, latest-only overwrites, no subcollections for MVP
- **Already compatible**: the Flutter read layer is wired and waiting; just write conforming documents
- **Additive future**: history subcollection path is reserved and requires zero migration
- **Solo-dev appropriate**: no second collection, no secondary index overhead, no stream subscriptions

---

## What needs to be built

Only two implementation tasks remain to unblock Firestore persistence:

| Task | Where | Priority |
|------|-------|----------|
| Add `seriesId` + `confidence` to `SnapshotDocument` | `_snapshot_document.mjs` | P0 |
| Implement `push_market_snapshots.mjs` production writer | new file | P0 |

Everything else — Flutter read path, Riverpod provider, badge widget, dev screen, mapper —
is already implemented and will work as soon as conforming documents exist in Firestore.

---

> Canonical schema: [`lib/features/market_intel/data/firestore/FIRESTORE_MARKET_SNAPSHOTS_SCHEMA.md`](../../lib/features/market_intel/data/firestore/FIRESTORE_MARKET_SNAPSHOTS_SCHEMA.md)
>
> Dev seeder reference: [`push_market_snapshots_dev.mjs`](./push_market_snapshots_dev.mjs)
>
> Production readiness audit (archived): [`archive/sprint_3n/docs/PRODUCTION_READINESS_AUDIT.md`](./archive/sprint_3n/docs/PRODUCTION_READINESS_AUDIT.md)

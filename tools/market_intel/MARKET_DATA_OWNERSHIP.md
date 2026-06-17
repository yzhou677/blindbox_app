# Market Data Ownership

> **Sprint 3N-FH** — alias consolidation + ownership boundaries.
>
> Status: **pre–Marketplace Insights**. Operational override storage (Firestore
> `market_intel_overrides`) is **deferred** until Insights pilot approval.

This document defines what lives where across the three market-intel universes.
See also [`.cursor/ARCHITECTURE.md`](../../.cursor/ARCHITECTURE.md) and
[`docs/architecture/MARKET_INTELLIGENCE_EVOLUTION.md`](../../docs/architecture/MARKET_INTELLIGENCE_EVOLUTION.md).

---

## Three universes

| Universe | Location | App reads? | Pipeline reads? |
|----------|----------|:----------:|:---------------:|
| **Catalog** | Firestore `brands`, `ips`, `series`, `figures` | Yes | Yes |
| **Marketplace tuning** | `tools/market_intel/market_metadata.json` (today); sparse Firestore overrides (future) | **No** | Yes |
| **Snapshot outputs** | Firestore `market_snapshots` | Yes (read-only) | Writes only |

**Hard rules**

- Flutter never loads `market_metadata.json` or future override collections.
- Catalog documents never store `searchTerms`, `excludeTerms`, or `matchThreshold`.
- Snapshot documents never store matching metadata (see
  [`FIRESTORE_MARKET_SNAPSHOTS_SCHEMA.md`](../../lib/features/market_intel/data/firestore/FIRESTORE_MARKET_SNAPSHOTS_SCHEMA.md)).

---

## Catalog identity (Firestore)

Canonical collectible identity. Same models in app and pipeline (`CatalogFigure`, etc.).

| Field | Level | Purpose |
|-------|-------|---------|
| `displayName` | brand, ip, series, figure | Primary label |
| `aliases` | brand, ip, series, **figure** | Alternate names collectors and marketplaces use |
| `imageKey`, `seriesId`, `isSecret`, … | figure / series | Identity and presentation |

### Figure aliases (3N-FH)

`figures/{figureId}.aliases` is the **sole source of truth** for durable figure name
variants (e.g. `displayName: "Luck"` with `aliases: ["Lucky"]`).

- **Catalog search** may use figure aliases (same pattern as series/IP/brand aliases).
- **Market-intel matcher** reads `figure.aliases` from the catalog bundle
  (`_catalog_matcher.mjs` → `catalogFigureAliasTokens`).
- **Do not** duplicate these in `market_metadata.json` → `marketAliases` for new work.

`marketAliases` in metadata remains for legacy/bootstrap entries only until removed
after Insights pilot backfill (see Sprint 3N-FG).

---

## Marketplace tuning (pipeline only)

Operational exceptions when default behavior is wrong. **Not catalog truth.**

| Field | Owner today | Nature |
|-------|-------------|--------|
| `searchTerms` | `market_metadata.json` | Override only — default is `deriveSearchTerms()` from catalog |
| `excludeTerms` | metadata | Per-figure listing false-positive patterns |
| `matchThreshold` | metadata | Per-figure matcher acceptance gate |
| `disabled` | metadata | Pause snapshot computation for a figure |
| `notes` | metadata | Maintainer annotation |

**Future (post–Insights pilot):** sparse `market_intel_overrides/{figureId}` in
Firestore — documents exist **only for exceptions**, not one row per catalog figure.

**Not in scope until Insights approval:** override collection, migration tooling,
admin UI, export automation.

---

## Snapshot outputs (Firestore)

Computed market estimates. Written by admin pipeline; read by app.

| Field | Examples |
|-------|----------|
| Pricing | `estimatedValueUsd`, `minPrice`, `maxPrice` |
| Quality | `confidence`, `sampleSize`, `trend` |
| Foreign keys | `figureId`, `seriesId`, `level` |

No search terms, aliases, or matcher config on snapshot documents.

---

## Pipeline load order (3N-FB + future)

```text
Today:
  loadFirestoreCatalogBundle()     ← figures include aliases
  + market_metadata.json (Git)     ← sparse overrides only

Future (after Insights pilot):
  loadFirestoreCatalogBundle()
  + loadMarketIntelOverrides()     ← sparse Firestore exceptions
  → merge in memory
  → search → match → aggregate → push snapshots
```

Default path for each figure: **derive** search terms from catalog; **match** using
catalog aliases + global normalizer rules. Metadata / overrides apply only when present.

---

## What to do now vs later

| Action | When |
|--------|------|
| Add `figures.aliases` to Firestore + `CatalogFigure` | **Done (3N-FH)** |
| Backfill aliases from review log | After Insights pilot |
| Remove `marketAliases` from metadata schema | After alias backfill |
| Firestore sparse overrides | After Insights pilot |
| Git as production tuning store | **Never** (fixtures / CI only) |
| Full metadata doc per figure | **Never** (second-catalog anti-pattern) |

---

## Related docs

| Doc | Topic |
|-----|-------|
| [`FIRESTORE_CATALOG_SCHEMA.md`](../../lib/features/catalog/firestore/FIRESTORE_CATALOG_SCHEMA.md) | Figure `aliases` field |
| [`METADATA_AUTOGEN_DESIGN.md`](./METADATA_AUTOGEN_DESIGN.md) | Future generator / merge (deferred) |
| [`SPRINT_3N_FB_IMPLEMENTATION.md`](./SPRINT_3N_FB_IMPLEMENTATION.md) | Firestore catalog loader |

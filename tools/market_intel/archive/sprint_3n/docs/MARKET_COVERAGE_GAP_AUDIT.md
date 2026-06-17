# Sprint 3N-B — Market Coverage Gap Audit

**Type:** Data coverage audit (no wording / trust-tier analysis)  
**Date:** 2026-06-16  
**Firebase project:** `blindbox-collection`

---

## Summary

| Metric | Value |
|--------|------:|
| Production catalog figures (Firestore) | **1,457** |
| Production catalog series (Firestore) | **154** |
| `market_snapshots` documents (Firestore) | **2** |
| Figure-level snapshot coverage | **1 / 1,457 = 0.07%** |
| Series-level snapshot coverage | **1 / 154 = 0.65%** |

**Finding:** The production `market_snapshots` collection contains **two dev-validation documents** written by `push_market_snapshots_dev.mjs`, not output from the eBay → `compute_snapshots.mjs` production pipeline. The snapshot generation pipeline has **not** been run at catalog scale against production Firestore data.

---

## Question 1 — Production catalog size

**Source:** Firestore `series` + `figures` collections (queried 2026-06-16).

| Metric | Count |
|--------|------:|
| Series count | **154** |
| Figure count | **1,457** |

Cross-check: `d:\blindbox-catalog\data\` (Firestore upload source) reports **154** series, **1,455** figures (2-figure delta vs live Firestore).

---

## Question 2 — Market snapshot counts

**Source:** Firestore `market_snapshots` (full collection scan).

| `SnapshotLevel` | Firestore `level` field | Count |
|-----------------|-------------------------|------:|
| Figure | `"figure"` | **1** |
| Series | `"series"` | **1** |
| **Total** | | **2** |

### Document inventory

| docId | level | seriesId |
|-------|-------|----------|
| `the_monsters_big_into_energy_vinyl_plush_pendant_luck` | figure | `the_monsters_big_into_energy_vinyl_plush_pendant` |
| `the_monsters_big_into_energy_vinyl_plush_pendant` | series | `the_monsters_big_into_energy_vinyl_plush_pendant` |

---

## Question 3 — Coverage %

| Numerator | Denominator | % |
|-----------|------------:|--:|
| Figures with `level: "figure"` snapshot (`docId == figureId`) | 1,457 total figures | **0.07%** |
| Series with `level: "series"` snapshot (`docId == seriesId`) | 154 total series | **0.65%** |

Only **one** blind-box series (`the_monsters_big_into_energy_vinyl_plush_pendant`) has any snapshot data. **153** series and **1,456** figures have **zero** `market_snapshots` documents.

---

## Question 4 — Snapshot generation pipeline

### Entrypoints (admin tools — no scheduled jobs in repo)

| Entry | File | Purpose |
|-------|------|---------|
| **Production orchestrator** | `tools/market_intel/compute_snapshots.mjs` | CLI: derive search terms → eBay fetch → build `SnapshotDocument` → optional `--push-firestore` |
| **Production Firestore writer** | `tools/market_intel/push_market_snapshots.mjs` | `buildFirestoreDocument()` + `pushSnapshotsToFirestore()` → `market_snapshots` |
| **Dev Firestore seeder** | `tools/market_intel/push_market_snapshots_dev.mjs` | Writes `market_snapshots_dev.seed.json` (2 docs) — **source of current Firestore data** |
| **Catalog coverage audit** | `tools/market_intel/catalog_coverage_audit.mjs` | Matcher/search-term readiness report (no eBay, no Firestore write) |

**Scheduled jobs:** None in repository. `docs/TECH_DEBT.md` and `PRODUCTION_READINESS_AUDIT.md` document manual CLI-only operation.

### Pipeline flow (production path)

```
compute_snapshots.mjs
  → loadCatalogBundle()                    [_catalog_bundle.mjs → tools/seed/*.json]
  → buildFigureSearchPlans()               [_snapshot_search.mjs]
  → fetchFigureCompletedSales()            [_snapshot_fetch.mjs → _ebay_completed_sales.mjs]
  → buildFigureSnapshot()                  [_snapshot_document.mjs]
      → matchListingsToFigure()            [_snapshot_match.mjs → _catalog_matcher.mjs]
      → aggregateSales()                   [_sales_aggregator.mjs]
  → [optional --push-firestore]
      → pushSnapshotsToFirestore()         [push_market_snapshots.mjs]
          → buildFirestoreDocument()
          → db.collection('market_snapshots').doc(figureId).set()
```

### Firestore write path

| Step | Code location |
|------|---------------|
| Map snapshot → Firestore fields | `push_market_snapshots.mjs` → `buildFirestoreDocument()` (lines 65–95) |
| Batch write | `push_market_snapshots.mjs` → `pushSnapshotsToFirestore()` (lines 210–274) |
| Collection / doc id | `market_snapshots/{figureId}` for figure snapshots |
| App read | `FirestoreMarketSnapshotRepository.getSnapshotForFigure()` → `lib/features/market_intel/data/firestore/firestore_market_snapshot_repository.dart` |

**Dev write path (what populated production today):**

```
push_market_snapshots_dev.mjs
  → market_snapshots_dev.seed.json
  → batch.set(market_snapshots/{id})
```

Documented in `tools/market_intel/DEV_VALIDATION.md` (Step 1 — Push script).

### eBay ingestion

| Component | File |
|-----------|------|
| Completed-sales fetch | `tools/market_intel/_ebay_completed_sales.mjs` |
| Per-figure orchestration | `tools/market_intel/_snapshot_fetch.mjs` → `fetchFigureCompletedSales()` |
| Config | `tools/market_intel/_ebay_env.mjs` (`EBAY_FETCH_MODE`, `EBAY_CLIENT_ID`) |

---

## Question 5 — Why coverage is low (filtering stages)

Measured against **production catalog export** (`blindbox-catalog/data`, 1,455 figures) for search-plan stage; Firestore for write stage.

| Stage | Input | Output | Drop | Notes |
|-------|------:|-------:|-----:|-------|
| **1. Catalog selection** (`buildFigureSearchPlans`) | 1,455 figures (prod export) | 1,455 plans | 0 | All figures included when no `--limit` / `--figure` / `--series` CLI filter |
| **2. Search query generation** (`deriveSearchTerms` + metadata) | 1,455 plans | 1,448 active | **7** | 7 skipped: `NO_SEARCH_TERMS`; 0 skipped: `DISABLED` |
| **3. eBay ingestion** (`fetchFigureCompletedSales`) | 1,448 active plans | **0 written to Firestore** | 1,448 | Full-catalog `--fetch --push-firestore` has **not** been executed against production; live eBay requires `EBAY_CLIENT_ID` |
| **4. Listing match + aggregation** (`buildFigureSnapshot`) | per-figure listings | per-figure `SnapshotDocument` | varies | `medianPrice == null` when `sampleSize == 0` after match |
| **5. Snapshot validation** (`buildFirestoreDocument`) | `SnapshotDocument[]` | docs with `medianPrice > 0` | null/zero median | Skips when `medianPrice == null` or `<= 0` (`push_market_snapshots.mjs:66–68`) |
| **6. Firestore write** | validated docs | **2** in Firestore | — | **Only** `push_market_snapshots_dev.mjs` has written to `market_snapshots`; production `compute_snapshots --push-firestore` not run at scale |

### Additional catalog mismatch (pipeline vs app)

| Catalog | Figures | Used by |
|---------|--------:|---------|
| Firestore / app runtime | 1,457 | `loadFirestoreCatalogBundle()` → `CatalogBundleCache` |
| `tools/seed/*.json` | 1,144 | `compute_snapshots.mjs` → `loadCatalogBundle()` |
| Delta | **313 figures missing from pipeline seed** | Includes all 18 non-blind-box SKUs, Mini ZIMOMO Maia, MEGA 400% lines, etc. |

`node tools/market_intel/compute_snapshots.mjs --dry-run` on default seed: **1,144** figures planned, **1,137** with fetch queries, **7** `NO_SEARCH_TERMS`.

### Metadata tracking list

`tools/market_intel/market_metadata.json` contains **1** figure entry (`lucky_big_into_energy_popmart`). This is **not** an allowlist — figures without metadata entries still receive auto-derived search terms (1,448 / 1,455 on production export).

---

## Question 6 — Trace: Mini ZIMOMO Maia

**Catalog ids:**

- Figure: `the_monsters_mini_zimomo_maia_mini_zimomo_maia`
- Series: `the_monsters_mini_zimomo_maia` (`isBlindBox: false`)

| Step | Status | Evidence / code |
|------|--------|-----------------|
| **Catalog (Firestore)** | **Present** | Figure + series documents in Firestore; visible in app Add-series UI (Sprint 3N-A.2 screenshot) |
| **Catalog (pipeline `loadCatalogBundle`)** | **Absent** | Figure not in `tools/seed/figures.json`. `compute_snapshots.mjs --figure mini_zimomo` → exit 1: *"No figures matched the requested filters."* (`compute_snapshots.mjs:257–259`, filter in `_snapshot_search.mjs:99–109`) |
| **Search plan (production export)** | **Would run** | `buildFigureSearchPlan()` returns 2 terms, `skipReason: null` (`_coverage_gap_pipeline_stats.mjs` output): `POP MART Labubu Mini ZIMOMO Maia…`, `POPMART Labubu…` |
| **eBay ingestion** | **Not executed** | No `market_snapshots` doc for this `figureId`; no repo record of `--fetch` run for this id |
| **Snapshot generation** | **Not executed** | `buildFigureSnapshot()` never invoked for this figure in production |
| **Firestore write** | **Not executed** | `market_snapshots/the_monsters_mini_zimomo_maia_mini_zimomo_maia` → `NOT_EXISTS` (Firestore direct read) |

**Stop point:** Pipeline catalog load (`loadCatalogBundle()` → `tools/seed`) — figure **not in bundle**. Even if catalog export were wired in, **no Firestore write has occurred** for this figure.

**App runtime:** `marketSnapshotProvider(figureId)` → `getSnapshotForFigure` MISS → `getSnapshotForSeries` MISS → **Tier C** (`null`).

---

## Question 7 — Trace: MEGA CRYBABY 400% Crying in Pink

**Catalog ids:**

- Figure: `mega_crybaby_400_crying_in_pink_figure`
- Series: `mega_crybaby_400_crying_in_pink` (`isBlindBox: false`)

| Step | Status | Evidence / code |
|------|--------|-----------------|
| **Catalog (Firestore)** | **Present** | In Firestore `figures` / `series` |
| **Catalog (pipeline `loadCatalogBundle`)** | **Absent** | Not in `tools/seed`. `compute_snapshots.mjs --figure mega_crybaby` → *"No figures matched"* |
| **Search plan (production export)** | **Would run** | 2 derived terms, `skipReason: null`: `POP MART Cry Baby MEGA CRYBABY 400% Crying in Pink…` |
| **eBay ingestion** | **Not executed** | No snapshot doc |
| **Snapshot generation** | **Not executed** | — |
| **Firestore write** | **Not executed** | `market_snapshots/mega_crybaby_400_crying_in_pink_figure` → `NOT_EXISTS` |

**Stop point:** Same as Q6 — **pipeline seed catalog** + **no production pipeline run / write**.

---

## Question 8 — Is production coverage intentionally limited?

### What exists in code/docs

| Mechanism | Type | Effect on coverage today |
|-----------|------|--------------------------|
| `market_metadata.json` | 1 manual metadata entry | **Not** a global allowlist; auto-derivation covers 1,448/1,455 production figures |
| `metadata.disabled: true` | Per-figure opt-out | **0** figures disabled in metadata |
| `deriveSearchTerms` → empty | Per-figure skip | **7** figures → `NO_SEARCH_TERMS` on production export |
| CLI `--limit`, `--figure`, `--series` | Operator filters | Optional; not applied in any automated job |
| `SEARCH_TERM_DERIVATION_DESIGN.md` § operational expectation | Documentation | States full-catalog runs are expensive; **not enforced in code** |
| `tools/seed` vs Firestore catalog | **Catalog source split** | Pipeline processes **1,144** figures; app serves **1,457** — **313 figures never enter pipeline** when using default `loadCatalogBundle()` |
| No scheduler | Operations | No cron / GitHub Action runs `compute_snapshots` |
| `push_market_snapshots_dev.mjs` | Dev validation | **Only** writer that has populated Firestore (2 documents) |
| `buildFirestoreDocument` median guard | Validation | Drops snapshots with `medianPrice == null` or `<= 0` |
| Live eBay gate | `compute_snapshots.mjs:276–280` | Exits if `EBAY_FETCH_MODE=live` and `EBAY_CLIENT_ID` unset |

### Conclusion (factual)

Coverage is low because:

1. **Firestore `market_snapshots` was seeded for dev UI validation only** (2 docs), not by the eBay snapshot pipeline.
2. **The production pipeline has not been executed** with `--fetch --push-firestore` across the catalog.
3. **No scheduled job** exists to regenerate snapshots.
4. **`compute_snapshots.mjs` reads `tools/seed/`**, which lags Firestore by **313 figures**, so production-only SKUs (including Mini ZIMOMO Maia and MEGA 400% items) are **excluded from the default pipeline input** even if the pipeline were run.

There is **no code-level allowlist** restricting snapshots to a small figure set. The effective limit is **operational**: dev seeder + manual pipeline + stale seed input + no scheduler.

---

## Code reference index

| Concern | Path |
|---------|------|
| Pipeline CLI entry | `tools/market_intel/compute_snapshots.mjs` |
| Catalog load (pipeline) | `tools/market_intel/_catalog_bundle.mjs` → `tools/seed/*.json` |
| Catalog load (app) | `lib/features/catalog/firestore/firestore_catalog_loader.dart` |
| Search plans | `tools/market_intel/_snapshot_search.mjs` |
| Search term derivation | `tools/market_intel/_search_term_derivation.mjs` |
| eBay fetch | `tools/market_intel/_ebay_completed_sales.mjs`, `_snapshot_fetch.mjs` |
| Matcher | `tools/market_intel/_snapshot_match.mjs`, `_catalog_matcher.mjs` |
| Aggregation | `tools/market_intel/_sales_aggregator.mjs` |
| Snapshot document | `tools/market_intel/_snapshot_document.mjs` |
| Firestore writer | `tools/market_intel/push_market_snapshots.mjs` |
| Dev seeder (current Firestore data) | `tools/market_intel/push_market_snapshots_dev.mjs`, `market_snapshots_dev.seed.json` |
| Admin metadata | `tools/market_intel/market_metadata.json` |
| Dev validation docs | `tools/market_intel/DEV_VALIDATION.md` |
| Manual-only scheduler note | `docs/TECH_DEBT.md`, `tools/market_intel/PRODUCTION_READINESS_AUDIT.md` |

---

## Audit artifacts

| File | Purpose |
|------|---------|
| `tools/market_intel/_coverage_gap_counts.json` | Firestore count snapshot |
| `tools/market_intel/_coverage_gap_pipeline_stats.mjs` | Production-catalog search-plan stats (re-runnable) |

No application code, providers, or Firestore schemas were modified.

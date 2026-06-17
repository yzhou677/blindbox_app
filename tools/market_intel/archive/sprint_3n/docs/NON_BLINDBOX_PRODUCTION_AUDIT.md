# Sprint 3N-A.1 — Production Catalog Fallback Audit

**Type:** Read-only production-data audit  
**Date:** 2026-06-16  
**Firebase project:** `blindbox-collection`  
**No code changes. No implementation.**

---

## Methodology

### Primary data source (authoritative)

Live **Firestore** collections queried via Firebase Admin SDK on 2026-06-16:

| Collection | Documents read | Purpose |
|------------|---------------:|---------|
| `series` | 154 | `isBlindBox`, `displayName`, `seriesId` |
| `figures` | 1,457 | Figure count per series |
| `market_snapshots` | 2 | Figure vs series snapshot presence |

This matches the runtime path documented in `FIRESTORE_CATALOG_SCHEMA.md` and `CatalogBundleCache`: the app loads catalog from Firestore (`loadFirestoreCatalogBundle()`), caches to device persistence, and reads `market_snapshots` through `FirestoreMarketSnapshotRepository`.

### Not used as evidence

- `tools/seed/*.json` (stale: 109 series vs 154 in Firestore)
- `DevMockMarketSnapshotRepository` / `market_snapshots_dev.seed.json`
- Test fixtures, screenshot fixtures

### Cross-check

`d:\blindbox-catalog\data\` (Firestore upload source per `blindbox-catalog/README.md`) reports **154 series**, **18 non-blind-box** — consistent with Firestore series count and non-blind-box count. Figure count differs by 2 (export 1,455 vs Firestore 1,457); audit uses **Firestore** counts.

---

## Executive summary

| Question | Production answer |
|----------|-------------------|
| Non-blind-box series in live catalog? | **18** (all single-figure) |
| Non-blind-box series with `level: "series"` snapshot? | **0** |
| Real Tier B cases (figure miss + series hit) for non-blind-box? | **0** |
| Can any surface show `Series Avg.` for non-blind-box **today**? | **No** (no snapshot path completes) |

**Recommendation: Option A** — Keep current fallback behavior. **No active production trust violation** exists. Future work (Option B or C) is needed **before** the market pipeline writes snapshots for non-blind-box `seriesId` values.

---

## Q1 — All `isBlindBox == false` series (full list)

| Series | SeriesId | Figure Count |
|--------|----------|-------------:|
| DIMOO WORLD × Honor of Kings 10th Anniversary Limited Figurine | `dimoo_world_honor_of_kings_10th_anniversary_limited_figurine` | 1 |
| Hirono Behind Time Figure | `hirono_behind_time_figure` | 1 |
| Hirono Living Wild Fight for Joy Plush Doll | `hirono_living_wild_fight_for_joy_plush_doll` | 1 |
| Hirono The Pianist Figure | `hirono_the_pianist_figure` | 1 |
| MEGA α SKULLPANDA 400% Guo Pei Alternate Universe | `mega_alpha_skullpanda_400_guo_pei_alternate_universe` | 1 |
| MEGA CRYBABY 400% Crying in Pink | `mega_crybaby_400_crying_in_pink` | 1 |
| MEGA SPACE MOLLY 400% Ashley Wood | `mega_space_molly_400_ashley_wood` | 1 |
| MEGA SPACE MOLLY 400% Jon Burgerman | `mega_space_molly_400_jon_burgerman` | 1 |
| PINO JELLY Chocolate Cookie Figurine | `pino_jelly_chocolate_cookie_figurine` | 1 |
| SKULLPANDA × KUROMI Plush | `skullpanda_kuromi_plush` | 1 |
| SKULLPANDA Lazy Panda Plush Doll Pendant | `skullpanda_lazy_panda_plush_doll_pendant` | 1 |
| SKULLPANDA × MY MELODY Plush | `skullpanda_my_melody_plush` | 1 |
| SKULLPANDA × Wednesday Plush (Classic Dress Version) | `skullpanda_wednesday_plush_classic_dress_version` | 1 |
| THE MONSTERS - ANGEL IN CLOUDS Vinyl Face Doll | `the_monsters_angel_in_clouds_vinyl_face_doll` | 1 |
| THE MONSTERS FALL IN WILD SERIES Vinyl Plush Doll | `the_monsters_fall_in_wild_vinyl_plush_doll` | 1 |
| Mini ZIMOMO Maia | `the_monsters_mini_zimomo_maia` | 1 |
| TYCOCO Goud | `the_monsters_tycoco_goud` | 1 |
| Twinkle Twinkle Warmth in a Freezing Noon Figure | `twinkle_twinkle_warmth_in_a_freezing_noon_figure` | 1 |

**Total: 18 series.**

Includes MEGA 400% (`mega_*_400_*`), large vinyl/plush dolls, limited figurines, and standalone releases — all catalogued as non-blind-box.

---

## Q2 — Non-blind-box figure-count classification

| Bucket | Count |
|--------|------:|
| Single figure | **18** |
| 2–5 figures | **0** |
| 6+ figures | **0** |

Every production non-blind-box series is **exactly one figure**.

---

## Q3 — Can Tier B activate for non-blind-box series?

### `marketSnapshotProvider()` path

```
marketSnapshotProvider(figureId)
  → FirestoreMarketSnapshotRepository.getSnapshotForFigure(figureId)
      → market_snapshots/{figureId}  [miss for all 18 non-blind figures today]
  → CatalogBundleCache.current → find CatalogFigure by id
  → FirestoreMarketSnapshotRepository.getSnapshotForSeries(catalogFigure.seriesId)
      → market_snapshots/{seriesId}  [miss for all 18 non-blind seriesIds today]
  → return null (Tier C)
```

**Tier B requires:** figure doc absent **and** series doc present at `market_snapshots/{seriesId}`.

### Production Firestore `market_snapshots` (complete inventory)

| Document id | level | seriesId | isBlindBox (catalog) |
|-------------|-------|----------|------------------------|
| `the_monsters_big_into_energy_vinyl_plush_pendant_luck` | figure | `the_monsters_big_into_energy_vinyl_plush_pendant` | **true** |
| `the_monsters_big_into_energy_vinyl_plush_pendant` | series | `the_monsters_big_into_energy_vinyl_plush_pendant` | **true** |

The only series-level snapshot in production belongs to a **blind-box** series (`isBlindBox: true`, 7 figures in catalog).

**For all 18 non-blind-box series:** `getSnapshotForSeries(seriesId)` returns **null** today → provider returns **null** → **Tier B cannot activate.**

---

## Q4 — Real examples (non-blind-box + figure miss + series hit)

**None found.**

Searched all 18 non-blind-box series and their 18 figures against all 2 `market_snapshots` documents. Zero intersections where:

- catalog `isBlindBox == false`, and  
- figure snapshot missing, and  
- series snapshot exists.

| Figure | Series | Snapshot result (production) |
|--------|--------|------------------------------|
| — | — | **No qualifying rows** |

Representative non-blind-box figure (all behave the same):

| Figure | Series | Snapshot result |
|--------|--------|-----------------|
| `mega_crybaby_400_crying_in_pink_figure` | `mega_crybaby_400_crying_in_pink` (`isBlindBox: false`) | **null** — no figure doc, no series doc |

---

## Q5 — Wording evaluation for real cases

**No real cases to evaluate.**

When production eventually has a non-blind-box Tier B path, prior UX analysis (Sprint 3N-A discussion) applies to the **18 single-figure** series:

| Wording | Expected verdict for single-figure non-blind-box Tier B |
|---------|--------------------------------------------------------|
| `Series Avg.` | **Clearly misleading** — no multi-figure series to average |
| `Series-Level Estimate` | **Clearly misleading** — same reason |
| `About series average pricing` | **Clearly misleading** — disclosure describes blind-box-style averaging |

This is **forward-looking** only; it is **not observed in production data today**.

---

## Architecture review — provider chain by surface

All surfaces ultimately call `marketSnapshotProvider(figureId)` → `FirestoreMarketSnapshotRepository` + `CatalogBundleCache`.

| Surface | Entry widget / screen | Provider chain | Shows `Series Avg.` label? | Non-blind-box today |
|---------|----------------------|----------------|----------------------------|---------------------|
| **Market Detail** | `MarketListingPriceDeltaLine` | `marketListingInsightsFigureId` → `marketSnapshotProvider(figureId)` → `formatMarketListingPriceDeltaLine(..., isSeriesEstimate)` | Yes, when `snapshot.isSeriesEstimate` | **No** — provider returns null for non-blind-box figures (no snapshots) |
| **Market Detail** | `MarketInsightsNavigationEntry` | same provider | Hidden when `isSeriesEstimate` | **No** |
| **Discover** | `catalog_figure_gallery_sheet.dart` → `_GalleryMarketInformationAccordion` | `marketSnapshotProvider(widget.figureId)` → `formatMarketSnapshotDiscoverSummaryLine` | Yes, when `isSeriesEstimate` | **No** |
| **Collection Insights** | `ShelfValueCard` | `collectionValueProvider` → fans out `marketSnapshotProvider(lookupId)` per owned figure | `~` prefix + `includes estimates` when any `isSeriesEstimate`; not the string `Series Avg.` on card | **No** — non-blind-box owned figures contribute $0 (unavailable) |
| **Collection Home** | `collection_screen.dart` → `CollectionSummarySection` | `collectionValueProvider` → same fan-out | Aggregate shelf $ only; `includes estimates` sub-label possible | **No** |

### Repository chain (runtime)

```
UI surface
  → marketSnapshotProvider(figureId)
      → marketSnapshotRepositoryProvider
          → FirestoreMarketSnapshotRepository
              → collection('market_snapshots').doc(figureId).get()
              → [on miss] collection('market_snapshots').doc(seriesId).get()
      → CatalogBundleCache.current (Firestore-synced catalog bundle)
```

**Conclusion:** Architecture *can* display `Series Avg.` for any figure where `isSeriesEstimate == true`. In **production today**, no non-blind-box figure reaches that state because **no market snapshot documents exist** for any of the 18 non-blind-box `seriesId` or figure ids.

---

## Risk assessment

| Risk | Status in production |
|------|---------------------|
| Active misleading `Series Avg.` on non-blind-box collectibles | **None** — Tier B path never completes |
| Non-blind-box catalog presence | **Real** — 18 series (400%, dolls, figurines, plush) |
| Latent risk when pipeline adds snapshots | **High** — if admin writes `level: "series"` docs for single-figure `seriesId`, Tier B will activate with current blind-box wording |
| Latent risk if only figure snapshots written | **Low** — Tier A `Market Value` is semantically fine |
| `tools/seed` understating catalog | **Confirmed** — seed lacks all 18 non-blind-box series; production audits must use Firestore |

---

## Recommendation

### **Option A — Keep current behavior**

**Rationale from production data:**

1. **Zero real Tier B cases** for `isBlindBox == false` in live Firestore.
2. **Zero surfaces** currently display `Series Avg.` for non-blind-box collectibles.
3. Adding a provider gate or wording fork **changes no production behavior today**.
4. The only live series fallback (`the_monsters_big_into_energy_vinyl_plush_pendant`, blind-box) is intentional and already covered by Tier B disclosure (Sprints 3I–3M).

### Required follow-up (not Option A implementation — pipeline guardrail)

Before writing **any** `market_snapshots` document whose `seriesId` matches one of the **18 non-blind-box series** listed in Q1:

- Re-audit and choose **Option B** (wording fork on `isBlindBox`) or **Option C** (disable fallback when `!isBlindBox`), **or**
- Admin policy: write **figure-level snapshots only** for non-blind-box SKUs (never `level: "series"` at `seriesId`).

### Options not chosen

| Option | Why not now |
|--------|-------------|
| **B** — Wording fork | No live Tier B non-blind-box cases to fix |
| **C** — Disable fallback | No live harm; gate is preventive only |
| **D** — Mixed | Unnecessary complexity until first non-blind-box snapshot ships |

---

## Appendix — Audit query metadata

```
projectId: blindbox-collection
queriedAt: 2026-06-16T19:46:58Z
totalSeries: 154
totalFigures: 1457
nonBlindBoxSeries: 18
marketSnapshotCount: 2
tierBCasesNonBlindBox: 0
```

No providers, UI, tests, or schemas were modified in this sprint.

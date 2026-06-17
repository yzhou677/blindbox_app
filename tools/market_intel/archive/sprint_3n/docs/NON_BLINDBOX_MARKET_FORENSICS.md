# Sprint 3N-A.2 — Non-Blind-Box Market Snapshot Forensics

**Type:** Data forensics only  
**Date:** 2026-06-16  
**Firebase project:** `blindbox-collection`  
**No code changes. No recommendations.**

---

## Evidence sources

| Source | Method | Role |
|--------|--------|------|
| Firestore `series` | Full collection `.get()` | `isBlindBox`, `displayName`, `seriesId` |
| Firestore `figures` | Full collection `.get()` | Figure membership |
| Firestore `market_snapshots` | Full collection `.get()` + per-doc `.doc(id).get()` for all 18 non-blind `figureId` and `seriesId` + `where('seriesId','==',…)` per non-blind series | Snapshot presence |
| Runtime catalog | `loadFirestoreCatalogBundle()` → four collection reads (`firestore_catalog_loader.dart`) → `CatalogBundleCache` | Same Firestore documents as above |
| Device emulator | `app.shelfy.collector` debug APK, **no** `MARKET_FIXTURE_SOURCE`, Firestore network load | UI verification for Tier C example |

**Not used for conclusions:** `tools/seed/*`, `DevMockMarketSnapshotRepository`, `market_snapshots_dev.seed.json`, test fixtures.

**Raw machine output:** `tools/market_intel/_sprint_3n_a2_forensics.json` (generated 2026-06-16).

---

## Firestore inventory (global)

| Collection | Document count |
|------------|---------------:|
| `series` | 154 |
| `figures` | 1,457 |
| `market_snapshots` | **2** |

### All `market_snapshots` documents

| docId | level | figureId | seriesId | estimatedValueUsd | Non-blind-box? |
|-------|-------|----------|----------|------------------:|:--------------:|
| `the_monsters_big_into_energy_vinyl_plush_pendant_luck` | figure | `the_monsters_big_into_energy_vinyl_plush_pendant_luck` | `the_monsters_big_into_energy_vinyl_plush_pendant` | 42 | NO (`isBlindBox: true`) |
| `the_monsters_big_into_energy_vinyl_plush_pendant` | series | — | `the_monsters_big_into_energy_vinyl_plush_pendant` | 37 | NO (`isBlindBox: true`) |

---

## Question 1 — Every `isBlindBox == false` series (full list)

| Series | SeriesId |
|--------|----------|
| DIMOO WORLD × Honor of Kings 10th Anniversary Limited Figurine | `dimoo_world_honor_of_kings_10th_anniversary_limited_figurine` |
| Hirono Behind Time Figure | `hirono_behind_time_figure` |
| Hirono Living Wild Fight for Joy Plush Doll | `hirono_living_wild_fight_for_joy_plush_doll` |
| Hirono The Pianist Figure | `hirono_the_pianist_figure` |
| MEGA α SKULLPANDA 400% Guo Pei Alternate Universe | `mega_alpha_skullpanda_400_guo_pei_alternate_universe` |
| MEGA CRYBABY 400% Crying in Pink | `mega_crybaby_400_crying_in_pink` |
| MEGA SPACE MOLLY 400% Ashley Wood | `mega_space_molly_400_ashley_wood` |
| MEGA SPACE MOLLY 400% Jon Burgerman | `mega_space_molly_400_jon_burgerman` |
| PINO JELLY Chocolate Cookie Figurine | `pino_jelly_chocolate_cookie_figurine` |
| SKULLPANDA × KUROMI Plush | `skullpanda_kuromi_plush` |
| SKULLPANDA Lazy Panda Plush Doll Pendant | `skullpanda_lazy_panda_plush_doll_pendant` |
| SKULLPANDA × MY MELODY Plush | `skullpanda_my_melody_plush` |
| SKULLPANDA × Wednesday Plush (Classic Dress Version) | `skullpanda_wednesday_plush_classic_dress_version` |
| THE MONSTERS - ANGEL IN CLOUDS Vinyl Face Doll | `the_monsters_angel_in_clouds_vinyl_face_doll` |
| THE MONSTERS FALL IN WILD SERIES Vinyl Plush Doll | `the_monsters_fall_in_wild_vinyl_plush_doll` |
| Mini ZIMOMO Maia | `the_monsters_mini_zimomo_maia` |
| TYCOCO Goud | `the_monsters_tycoco_goud` |
| Twinkle Twinkle Warmth in a Freezing Noon Figure | `twinkle_twinkle_warmth_in_a_freezing_noon_figure` |

**Count: 18**

Runtime catalog: `loadFirestoreCatalogBundle()` reads the same `series` collection; `CatalogBundleCache.refreshFromFirestore()` replaces in-memory bundle with this set after sync.

---

## Question 2 — Figures in non-blind-box series (full list)

| Figure | FigureId | Series |
|--------|----------|--------|
| DIMOO WORLD × Honor of Kings 10th Anniversary Limited Figurine | `dimoo_world_honor_of_kings_10th_anniversary_limited_figurine_figure` | DIMOO WORLD × Honor of Kings 10th Anniversary Limited Figurine |
| Hirono Behind Time Figure | `hirono_behind_time_figure_hirono_behind_time` | Hirono Behind Time Figure |
| Hirono Living Wild Fight for Joy Plush Doll | `hirono_living_wild_fight_for_joy_plush_doll_figure` | Hirono Living Wild Fight for Joy Plush Doll |
| Hirono The Pianist Figure | `hirono_the_pianist_figure_figure` | Hirono The Pianist Figure |
| MEGA α SKULLPANDA 400% Guo Pei Alternate Universe | `mega_alpha_skullpanda_400_guo_pei_alternate_universe_figure` | MEGA α SKULLPANDA 400% Guo Pei Alternate Universe |
| MEGA CRYBABY 400% Crying in Pink | `mega_crybaby_400_crying_in_pink_figure` | MEGA CRYBABY 400% Crying in Pink |
| MEGA SPACE MOLLY 400% Ashley Wood | `mega_space_molly_400_ashley_wood_figure` | MEGA SPACE MOLLY 400% Ashley Wood |
| MEGA SPACE MOLLY 400% Jon Burgerman | `mega_space_molly_400_jon_burgerman_figure` | MEGA SPACE MOLLY 400% Jon Burgerman |
| Chocolate Cookie | `pino_jelly_chocolate_cookie_figurine_chocolate_cookie` | PINO JELLY Chocolate Cookie Figurine |
| SKULLPANDA × KUROMI Plush | `skullpanda_kuromi_plush_figure` | SKULLPANDA × KUROMI Plush |
| SKULLPANDA Lazy Panda Plush Doll Pendant | `skullpanda_lazy_panda_plush_doll_pendant_figure` | SKULLPANDA Lazy Panda Plush Doll Pendant |
| SKULLPANDA × MY MELODY Plush | `skullpanda_my_melody_plush_figure` | SKULLPANDA × MY MELODY Plush |
| Classic Dress Version | `skullpanda_wednesday_plush_classic_dress_version_classic_dress` | SKULLPANDA × Wednesday Plush (Classic Dress Version) |
| THE MONSTERS - ANGEL IN CLOUDS Vinyl Face Doll | `the_monsters_angel_in_clouds_vinyl_face_doll_figure` | THE MONSTERS - ANGEL IN CLOUDS Vinyl Face Doll |
| THE MONSTERS FALL IN WILD SERIES Vinyl Plush Doll | `the_monsters_fall_in_wild_vinyl_plush_doll_figure` | THE MONSTERS FALL IN WILD SERIES Vinyl Plush Doll |
| Mini ZIMOMO Maia | `the_monsters_mini_zimomo_maia_mini_zimomo_maia` | Mini ZIMOMO Maia |
| TYCOCO Goud | `the_monsters_tycoco_goud_tycoco_goud` | TYCOCO Goud |
| Twinkle Twinkle Warmth in a Freezing Noon Figure | `twinkle_twinkle_warmth_in_a_freezing_noon_figure_figure` | Twinkle Twinkle Warmth in a Freezing Noon Figure |

**Count: 18 figures**

### Figure-count classification (non-blind-box series only)

| Bucket | Series count |
|--------|-------------:|
| Single figure | 18 |
| 2–5 figures | 0 |
| 6+ figures | 0 |

---

## Question 3 — `marketSnapshotProvider` lookup path

Implementation (`market_snapshot_providers.dart` + `FirestoreMarketSnapshotRepository`):

```
1. getSnapshotForFigure(figureId)
     → market_snapshots.doc(figureId).get()

2. [if null] CatalogBundleCache.current → find figure by id → catalogFigure.seriesId

3. getSnapshotForSeries(catalogFigure.seriesId)
     → market_snapshots.doc(seriesId).get()

4. return snapshot or null
```

Tier B = step 1 MISS, step 3 HIT, returned snapshot has `level == series` → `isSeriesEstimate == true`.

---

## Question 4 — Figure snapshots (`level: figure`) for non-blind-box catalog figures

Searched: full `market_snapshots` scan; `doc(figureId).get()` for each of 18 figure ids; match on `figureId` field.

| Figure | FigureId | Snapshot Exists |
|--------|----------|:---------------:|
| DIMOO WORLD × Honor of Kings 10th Anniversary Limited Figurine | `dimoo_world_honor_of_kings_10th_anniversary_limited_figurine_figure` | **NO** |
| Hirono Behind Time Figure | `hirono_behind_time_figure_hirono_behind_time` | **NO** |
| Hirono Living Wild Fight for Joy Plush Doll | `hirono_living_wild_fight_for_joy_plush_doll_figure` | **NO** |
| Hirono The Pianist Figure | `hirono_the_pianist_figure_figure` | **NO** |
| MEGA α SKULLPANDA 400% Guo Pei Alternate Universe | `mega_alpha_skullpanda_400_guo_pei_alternate_universe_figure` | **NO** |
| MEGA CRYBABY 400% Crying in Pink | `mega_crybaby_400_crying_in_pink_figure` | **NO** |
| MEGA SPACE MOLLY 400% Ashley Wood | `mega_space_molly_400_ashley_wood_figure` | **NO** |
| MEGA SPACE MOLLY 400% Jon Burgerman | `mega_space_molly_400_jon_burgerman_figure` | **NO** |
| Chocolate Cookie | `pino_jelly_chocolate_cookie_figurine_chocolate_cookie` | **NO** |
| SKULLPANDA × KUROMI Plush | `skullpanda_kuromi_plush_figure` | **NO** |
| SKULLPANDA Lazy Panda Plush Doll Pendant | `skullpanda_lazy_panda_plush_doll_pendant_figure` | **NO** |
| SKULLPANDA × MY MELODY Plush | `skullpanda_my_melody_plush_figure` | **NO** |
| Classic Dress Version | `skullpanda_wednesday_plush_classic_dress_version_classic_dress` | **NO** |
| THE MONSTERS - ANGEL IN CLOUDS Vinyl Face Doll | `the_monsters_angel_in_clouds_vinyl_face_doll_figure` | **NO** |
| THE MONSTERS FALL IN WILD SERIES Vinyl Plush Doll | `the_monsters_fall_in_wild_vinyl_plush_doll_figure` | **NO** |
| Mini ZIMOMO Maia | `the_monsters_mini_zimomo_maia_mini_zimomo_maia` | **NO** |
| TYCOCO Goud | `the_monsters_tycoco_goud_tycoco_goud` | **NO** |
| Twinkle Twinkle Warmth in a Freezing Noon Figure | `twinkle_twinkle_warmth_in_a_freezing_noon_figure_figure` | **NO** |

---

## Question 4 (series) — Series snapshots for non-blind-box series

Searched: full collection scan; `doc(seriesId).get()` for each of 18 series ids; `where('seriesId','==', seriesId)` for each non-blind series (0 hits).

| Series | SeriesId | Snapshot Exists |
|--------|----------|:---------------:|
| DIMOO WORLD × Honor of Kings 10th Anniversary Limited Figurine | `dimoo_world_honor_of_kings_10th_anniversary_limited_figurine` | **NO** |
| Hirono Behind Time Figure | `hirono_behind_time_figure` | **NO** |
| Hirono Living Wild Fight for Joy Plush Doll | `hirono_living_wild_fight_for_joy_plush_doll` | **NO** |
| Hirono The Pianist Figure | `hirono_the_pianist_figure` | **NO** |
| MEGA α SKULLPANDA 400% Guo Pei Alternate Universe | `mega_alpha_skullpanda_400_guo_pei_alternate_universe` | **NO** |
| MEGA CRYBABY 400% Crying in Pink | `mega_crybaby_400_crying_in_pink` | **NO** |
| MEGA SPACE MOLLY 400% Ashley Wood | `mega_space_molly_400_ashley_wood` | **NO** |
| MEGA SPACE MOLLY 400% Jon Burgerman | `mega_space_molly_400_jon_burgerman` | **NO** |
| PINO JELLY Chocolate Cookie Figurine | `pino_jelly_chocolate_cookie_figurine` | **NO** |
| SKULLPANDA × KUROMI Plush | `skullpanda_kuromi_plush` | **NO** |
| SKULLPANDA Lazy Panda Plush Doll Pendant | `skullpanda_lazy_panda_plush_doll_pendant` | **NO** |
| SKULLPANDA × MY MELODY Plush | `skullpanda_my_melody_plush` | **NO** |
| SKULLPANDA × Wednesday Plush (Classic Dress Version) | `skullpanda_wednesday_plush_classic_dress_version` | **NO** |
| THE MONSTERS - ANGEL IN CLOUDS Vinyl Face Doll | `the_monsters_angel_in_clouds_vinyl_face_doll` | **NO** |
| THE MONSTERS FALL IN WILD SERIES Vinyl Plush Doll | `the_monsters_fall_in_wild_vinyl_plush_doll` | **NO** |
| Mini ZIMOMO Maia | `the_monsters_mini_zimomo_maia` | **NO** |
| TYCOCO Goud | `the_monsters_tycoco_goud` | **NO** |
| Twinkle Twinkle Warmth in a Freezing Noon Figure | `twinkle_twinkle_warmth_in_a_freezing_noon_figure` | **NO** |

---

## Question 5 — Runtime result per non-blind-box figure (traced lookup chain)

| Figure | FigureId | getSnapshotForFigure | getSnapshotForSeries | `marketSnapshotProvider` result |
|--------|----------|:--------------------:|:-------------------:|-------------------------------|
| DIMOO WORLD × Honor of Kings 10th Anniversary Limited Figurine | `dimoo_world_honor_of_kings_10th_anniversary_limited_figurine_figure` | MISS | MISS | **No Data (Tier C)** |
| Hirono Behind Time Figure | `hirono_behind_time_figure_hirono_behind_time` | MISS | MISS | **No Data (Tier C)** |
| Hirono Living Wild Fight for Joy Plush Doll | `hirono_living_wild_fight_for_joy_plush_doll_figure` | MISS | MISS | **No Data (Tier C)** |
| Hirono The Pianist Figure | `hirono_the_pianist_figure_figure` | MISS | MISS | **No Data (Tier C)** |
| MEGA α SKULLPANDA 400% Guo Pei Alternate Universe | `mega_alpha_skullpanda_400_guo_pei_alternate_universe_figure` | MISS | MISS | **No Data (Tier C)** |
| MEGA CRYBABY 400% Crying in Pink | `mega_crybaby_400_crying_in_pink_figure` | MISS | MISS | **No Data (Tier C)** |
| MEGA SPACE MOLLY 400% Ashley Wood | `mega_space_molly_400_ashley_wood_figure` | MISS | MISS | **No Data (Tier C)** |
| MEGA SPACE MOLLY 400% Jon Burgerman | `mega_space_molly_400_jon_burgerman_figure` | MISS | MISS | **No Data (Tier C)** |
| Chocolate Cookie | `pino_jelly_chocolate_cookie_figurine_chocolate_cookie` | MISS | MISS | **No Data (Tier C)** |
| SKULLPANDA × KUROMI Plush | `skullpanda_kuromi_plush_figure` | MISS | MISS | **No Data (Tier C)** |
| SKULLPANDA Lazy Panda Plush Doll Pendant | `skullpanda_lazy_panda_plush_doll_pendant_figure` | MISS | MISS | **No Data (Tier C)** |
| SKULLPANDA × MY MELODY Plush | `skullpanda_my_melody_plush_figure` | MISS | MISS | **No Data (Tier C)** |
| Classic Dress Version | `skullpanda_wednesday_plush_classic_dress_version_classic_dress` | MISS | MISS | **No Data (Tier C)** |
| THE MONSTERS - ANGEL IN CLOUDS Vinyl Face Doll | `the_monsters_angel_in_clouds_vinyl_face_doll_figure` | MISS | MISS | **No Data (Tier C)** |
| THE MONSTERS FALL IN WILD SERIES Vinyl Plush Doll | `the_monsters_fall_in_wild_vinyl_plush_doll_figure` | MISS | MISS | **No Data (Tier C)** |
| Mini ZIMOMO Maia | `the_monsters_mini_zimomo_maia_mini_zimomo_maia` | MISS | MISS | **No Data (Tier C)** |
| TYCOCO Goud | `the_monsters_tycoco_goud_tycoco_goud` | MISS | MISS | **No Data (Tier C)** |
| Twinkle Twinkle Warmth in a Freezing Noon Figure | `twinkle_twinkle_warmth_in_a_freezing_noon_figure_figure` | MISS | MISS | **No Data (Tier C)** |

**Summary:** Tier A = 0 · Tier B = 0 · Tier C = 18

---

## Question 6 — Real active examples

### Tier A — non-blind-box + figure snapshot

**Count: 0**

No `market_snapshots` document with `level: "figure"` references any of the 18 non-blind-box `figureId` values.

### Tier B — non-blind-box + series fallback

**Count: 0**

No non-blind-box figure has `getSnapshotForFigure` MISS and `getSnapshotForSeries` HIT. No `market_snapshots` series document exists for any of the 18 non-blind-box `seriesId` values.

### Tier C — non-blind-box + no snapshot

**Count: 18** (all non-blind-box figures)

**Documented example:**

| Field | Value |
|-------|-------|
| Figure | Mini ZIMOMO Maia |
| FigureId | `the_monsters_mini_zimomo_maia_mini_zimomo_maia` |
| SeriesId | `the_monsters_mini_zimomo_maia` |
| `isBlindBox` | `false` |
| `getSnapshotForFigure` | MISS |
| `getSnapshotForSeries` | MISS |
| Provider result | `null` (Tier C) |

---

## Question 7 — Screenshot verification

**Build:** `flutter build apk --debug --dart-define=MARKET_GATEWAY_EBAY=false` (no `MARKET_FIXTURE_SOURCE`)  
**Device:** `emulator-5554`  
**Catalog:** Loaded from Firestore (runtime “Latest releases” shows `Mini ZIMOMO Maia` · `1 figure`, `TYCOCO Goud` · `1 figure`)

| Screenshot | Surface | Example | Tier | `Series Avg.` visible? | `Market Information` visible? |
|------------|---------|---------|------|:---------------------:|:-----------------------------:|
| `screenshots/sprint_3n_a2/2_search_crybaby.png` | Collection → Add catalog | Latest releases incl. non-blind-box rows | — | NO | NO |
| `screenshots/sprint_3n_a2/3_catalog_preview_mini_zimomo_maia.png` | Collection → Add → series preview | Mini ZIMOMO Maia | C | NO | NO |
| `screenshots/sprint_3n_a2/4_discover_gallery_mini_zimomo_maia_tier_c.png` | Catalog figure gallery (Discover path) | `figureId=the_monsters_mini_zimomo_maia_mini_zimomo_maia` | C | NO | NO |

**Tier A (non-blind-box):** No production case → no screenshot captured.

**Tier B (non-blind-box):** No production case → no screenshot captured.

**Market Detail (non-blind-box):** Not captured. Firestore has no `market_listings` collection; build uses `MARKET_GATEWAY_EBAY=false`. No market listing was resolved to a non-blind-box `figureId` in this forensics run.

**Collection Insights / Shelf Value (non-blind-box owned):** Not captured. Forensics run did not mutate user shelf state.

---

## Runtime catalog vs Firestore

| Check | Result |
|-------|--------|
| Firestore non-blind-box series count | 18 |
| App “Add a series” shows `Mini ZIMOMO Maia` · `1 figure` | YES (screenshot `2_search_crybaby.png`) |
| `tools/seed` non-blind-box series count | 0 (comparison only — not used as evidence) |

---

## Provider → UI chain (where `Series Avg.` can render)

| Surface | Widget | Condition for `Series Avg.` text |
|---------|--------|----------------------------------|
| Market Detail | `MarketListingPriceDeltaLine` | `snapshot != null` AND `snapshot.isSeriesEstimate` |
| Discover gallery | `formatMarketSnapshotDiscoverSummaryLine` | `snapshot.isSeriesEstimate` |
| Collection Insights | `ShelfValueCard` | `includesSeriesEstimates` (not the string `Series Avg.` on card) |

For all 18 non-blind-box figures: `marketSnapshotProvider` returns `null` → widgets above render empty / hidden → **`Series Avg.` does not appear**.

---

## Forensic facts (success criteria)

| Fact | Evidence |
|------|----------|
| Non-blind-box figures in production catalog | **18** (Firestore `series` + `figures`) |
| Non-blind-box figures visible in app catalog UI | YES (`Mini ZIMOMO Maia`, `TYCOCO Goud` in Add-series sheet) |
| Non-blind-box figure snapshots in Firestore | **0** |
| Non-blind-box series snapshots in Firestore | **0** |
| Non-blind-box figures resolving to Tier A today | **0** |
| Non-blind-box figures resolving to Tier B today | **0** |
| Non-blind-box figures resolving to Tier C today | **18** |
| Any non-blind-box figure currently reaches Tier B | **NO** |
| `Series Avg.` displayed for non-blind-box in captured UI | **NO** (gallery UI dump: `Market Information` absent, `Series Avg.` absent) |
| Wording changes required **in production today** for non-blind-box Tier B | **NO** — Tier B does not occur for any non-blind-box figure in current Firestore data |

---

## Dispute resolution note

Product owner assertion: non-blind-box collectibles exist in Firestore catalog and user-facing app.

**Confirmed by this forensics run:**

- **18** `isBlindBox: false` series and **18** figures in Firestore.
- App runtime catalog surfaces non-blind-box entries (e.g. Mini ZIMOMO Maia, TYCOCO Goud).

**Also confirmed:**

- **`market_snapshots` contains 2 documents**, both for blind-box `the_monsters_big_into_energy_vinyl_plush_pendant`.
- **0** non-blind-box figures have figure or series snapshots.
- **0** non-blind-box figures resolve to Tier B through `marketSnapshotProvider` with current Firestore data.

Catalog presence and market-snapshot absence are both true in production at audit time.

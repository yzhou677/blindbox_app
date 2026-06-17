# Sprint 3N-A — Non-Blind-Box Series Fallback Audit

**Type:** Read-only audit  
**Date:** 2026-06-16  
**Scope:** Determine whether an `isBlindBox` gate in `marketSnapshotProvider` is necessary  
**Data sources:** `tools/seed/series.json`, `tools/seed/figures.json`, `tools/market_intel/market_snapshots_dev.seed.json`, `lib/features/market_intel/dev/dev_mock_market_snapshot_repository.dart`, `lib/features/market_intel/data/firestore/FIRESTORE_MARKET_SNAPSHOTS_SCHEMA.md`

---

## Executive summary

| Finding | Result |
|---------|--------|
| Non-blind-box series in catalog | **0** |
| Single-figure series in catalog | **0** |
| Series snapshot docs for non-blind-box series | **0** |
| Observed fallback risk path (non-blind-box) | **None — no subjects exist** |
| Would `if (!catalogSeries.isBlindBox) return null` change behavior today? | **No** |

**Recommendation: Option A** — Keep current fallback behavior. The planned `isBlindBox` provider gate is **not necessary** based on present catalog and snapshot data. Tier B disclosure work (Sprints 3I–3M) already addresses the only fallback scenario that exists in-repo today (blind-box, multi-figure series). Revisit if/when the first `isBlindBox: false` series enters the catalog.

---

## Part 1 — Catalog reality

### Method

Loaded `tools/seed/series.json` (109 series) and `tools/seed/figures.json` (1,144 figures). Counted `isBlindBox` and figures per `seriesId`. This seed mirrors the Firestore catalog shape (`FIRESTORE_CATALOG_SCHEMA.md`).

### Statistics

| Metric | Count |
|--------|------:|
| Total series | 109 |
| Blind-box series (`isBlindBox: true`) | 109 |
| Non-blind-box series (`isBlindBox: false`) | **0** |
| Series with 1 figure | **0** |
| Series with 2–5 figures | 2 |
| Series with 6–10 figures | 49 |
| Series with 10+ figures | 58 |
| Total figures | 1,144 |
| Orphan series (0 figures) | 0 |

**Figure count range:** min 3, max 21, median 11 per series.

### Cross-tab: `isBlindBox` × figure count

| | 1 figure | 2–5 | 6–10 | 10+ |
|---|:---:|:---:|:---:|:---:|
| `isBlindBox: true` | 0 | 2 | 49 | 58 |
| `isBlindBox: false` | 0 | 0 | 0 | 0 |

### Every `isBlindBox == false` series

**None.** The list is empty.

### Notable blind-box series (context for original MEGA concern)

These are **not** non-blind-box, but were discussed as large-format candidates:

| seriesId | displayName | isBlindBox | figureCount |
|----------|-------------|:----------:|------------:|
| `space_molly_mega_100_series_2_b` | MEGA SPACE MOLLY 100% Series 2-B | true | 13 |
| `space_molly_mega_100_series_3` | MEGA SPACE MOLLY 100% Series 3 | true | 12 |
| `space_molly_mega_100_emoji` | MEGA SPACE MOLLY 100% × emoji™ Series | true | 21 |
| `space_molly_mega_100_series_4` | MEGA SPACE MOLLY 100% Series4 | true | 15 |

Smallest multi-figure blind-box series:

| figureCount | seriesId | displayName |
|------------:|----------|-------------|
| 3 | `the_monsters_coca_cola_vinyl_face` | THE MONSTERS COCA-COLA SERIES-Vinyl Face Blind Box |
| 5 | `moon_gelato_ice_cream_plush_pendant_overseas_series` | MOON GELATO Series Ice Cream Plush Pendant (Overseas Ver.) |

### Competing hypothesis vs. actual catalog

**Hypothesis:** Many non-blind-box series are single-figure series, so series fallback is redundant or harmless.

**Actual catalog:** The hypothesis **cannot be tested** — there are zero non-blind-box series and zero single-figure series. Every series in seed has 3–21 figures and `isBlindBox: true`.

---

## Part 2 — Fallback risk analysis

### Subjects

Every `isBlindBox == false` series: **none.**

Per-series risk questions (figure count, meaningful series avg difference, extra information from series doc, misleading fallback scenario) **do not apply** — no catalog rows match.

### What actually exists today (blind-box only)

The only in-repo series fallback scenario is **dev validation** for a **blind-box** series:

| Field | Value |
|-------|-------|
| seriesId | `the_monsters_big_into_energy_vinyl_plush_pendant` |
| isBlindBox | `true` |
| figureCount | 7 |
| Series snapshot doc | **Yes** (dev seed) |
| Fallback test figure | `the_monsters_big_into_energy_vinyl_plush_pendant_hope` (no figure doc) |

**Observed behavior (by design, `market_snapshot_dev_cases.dart`):**

- Figure `…_luck` → figure snapshot $42 (Tier A)
- Figure `…_hope` → figure miss → series fallback $37 (Tier B, `isSeriesEstimate: true`)
- Figure `…_serenity` → figure miss → no series doc → `null` (Tier C)

This is a **multi-figure blind-box** series where series average is intentionally used as a lower-confidence estimate for figures without individual sales data. It is the scenario Tier B disclosure (Sprints 3I–3M) was built for — not a non-blind-box case.

### Concrete misleading-fallback examples (non-blind-box)

**None in current catalog data.** Cannot cite a real `isBlindBox: false` series where fallback activates.

### Structural note (not speculation — schema fact)

Firestore series snapshot documents use **document id = `seriesId`**. Figure snapshots use **document id = `figureId`**. For a hypothetical future single-figure, non-blind-box series, `seriesId ≠ figureId`; a series doc and figure doc would be separate writes. Whether fallback is misleading depends on catalog shape and admin writes — **neither exists in seed today.**

---

## Part 3 — Firestore / seed / mock snapshot data

### Schema (`FIRESTORE_MARKET_SNAPSHOTS_SCHEMA.md`)

- Collection: `market_snapshots`
- Figure snapshot: doc id = `figureId`, `level: "figure"`
- Series fallback snapshot: doc id = `seriesId`, `level: "series"`
- App read path: `getSnapshotForFigure` → on miss → `getSnapshotForSeries(catalogFigure.seriesId)`

### `tools/market_intel/market_snapshots_dev.seed.json`

| id | level | seriesId | Catalog series isBlindBox |
|----|-------|----------|---------------------------|
| `the_monsters_big_into_energy_vinyl_plush_pendant_luck` | figure | `the_monsters_big_into_energy_vinyl_plush_pendant` | true |
| `the_monsters_big_into_energy_vinyl_plush_pendant` | **series** | `the_monsters_big_into_energy_vinyl_plush_pendant` | **true** |

**Series snapshot documents for non-blind-box series: none.**

### `DevMockMarketSnapshotRepository`

Mirrors dev seed:

- **Figure snapshots:** 5 (Big Into Energy Luck + 4 Macaron figures)
- **Series snapshots:** 1 — `the_monsters_big_into_energy_vinyl_plush_pendant` (blind-box)
- Macaron series has figure snapshots only; no series doc (partial-coverage demo)

**Series snapshot documents for non-blind-box series: none.**

### Production Firestore

No static production snapshot manifest is checked into the repo. Production writes go through `push_market_snapshots.mjs` (not audited live in this sprint). Based on in-repo artifacts only: **zero non-blind-box series snapshots exist.**

---

## Part 4 — Recommendation

### Chosen: **Option A — Keep current fallback behavior**

Do **not** add `if (!catalogSeries.isBlindBox) return null` to `marketSnapshotProvider` at this time.

### Why (grounded in data)

1. **No risk surface today.** Zero non-blind-box series → the gate would change **zero** valuations across Market Detail, Shelf Value, and Discover gallery.

2. **Competing hypothesis is untestable, not disproven.** The idea that non-blind-box series are single-figure (making series fallback harmless) is plausible product logic, but **current seed has no single-figure series and no non-blind-box series** to confirm it.

3. **The only live fallback example is blind-box by design.** Big Into Energy Case B is a 7-figure blind-box line with an intentional series snapshot. Tier B wording and disclosure (series avg label, ⓘ sheet, hidden Insights nav) already address that path.

4. **`isBlindBox` gate does not address the original MEGA/400%/1000% concern in current catalog.** All four MEGA SPACE MOLLY 100% series are `isBlindBox: true` with 12–21 figures each. A non-blind-box gate would **not** suppress fallback for them. Those SKUs also have dedicated `seriesId` values (`space_molly_mega_100_*`), so fallback would target MEGA-series snapshots, not standard blind-box series — a separate concern from “non-blind-box fallback.”

5. **Option B would be a no-op with maintenance cost.** Adding provider logic now ships no user-visible change and cannot be integration-tested against real non-blind-box catalog rows.

6. **Option A wording variant (“Market Estimate” for non-blind-box) is also premature.** No non-blind-box series → no UI surface to label.

### When to reopen

Trigger a new audit when **any** of the following is true:

- First `isBlindBox: false` series is added to catalog seed / Firestore
- First single-figure series appears (`figureCount == 1`)
- Admin pipeline writes a `level: "series"` doc for a non-blind-box `seriesId`
- A documented incident where non-blind-box fallback produced a misleading valuation

At that point, re-evaluate Option B or a catalog-authoring invariant (e.g. non-blind-box series must be single-figure; admin writes figure snapshots only).

### Options not chosen

| Option | Verdict |
|--------|---------|
| **B** — `isBlindBox` provider gate | Unnecessary today; zero catalog subjects; no observed harm |
| **C** — Other | No alternative justified by **current** data beyond “defer and re-audit on first non-blind-box series” (folded into Option A) |

---

## Appendix — Raw extraction commands

Catalog stats were produced from `tools/seed/series.json` + `tools/seed/figures.json` on 2026-06-16. Key outputs:

```
TOTAL_SERIES 109
BLIND_BOX 109
NON_BLIND_BOX 0
BUCKET 1 → 0 | 2-5 → 2 | 6-10 → 49 | 10+ → 58
```

No code, providers, tests, or Firestore schemas were modified in this sprint.

# Technical debt

Tracked items that are not release blockers. Severity and priority are conservative — only active, reachable issues.

## Minor Analyzer Warnings

Current status:

- `test/catalog_image_display_test.dart` — unused local variable
- `test/market_search_anr_repro_test.dart` — unused import
- `test/market_tab_reselect_navigation_test.dart` — unused private element

**Severity:** GREEN

**Impact:** None

**Priority:** Cleanup when convenient.

---

## Market Intelligence — Snapshot Query Volume Optimization

**Status:** Deferred — do not implement before Sprint 4 is complete.

**Observation:** Full snapshot runs derive ~2–3 search terms per figure across ~1,100+ figures → ~2,300+ eBay queries per run. Acceptable during initial development and validation.

**Reason for deferral:** System is not yet on real production snapshot data. Complete first: live completed-sales fetch, matcher, aggregator, Firestore persistence, and several production snapshot runs reviewed.

**Potential future optimizations:** query cache (normalized term + date window), cross-run cache, incremental refresh, shared query pool / query deduplication across figures, snapshot scheduling (daily / weekly full rebuild).

**Post–Step 3C note:** Matcher and aggregator are integrated; evaluate query-volume optimizations before production-scale runs (~1,144 figures / ~2,300 queries).

**Re-evaluate when:** runtime, API quota, operational cost, or production metrics justify it. Until then: prefer correctness and maintainability over optimization.

Full detail: [`tools/market_intel/QUERY_VOLUME_OPTIMIZATION.md`](../tools/market_intel/QUERY_VOLUME_OPTIMIZATION.md)

---

## Market Intelligence — Sold Listing Data Source Migration

**Status:** Blocked by external platform limitations — not a code defect.

**Background (Sprint 2 Step 3B.1):** Finding API decommissioned; `findCompletedItems` unavailable. OAuth credentials work; Browse API is active-listings only; Marketplace Insights access not granted.

**Current strategy:** Continue with fixture mode through matcher, aggregator, and snapshot persistence until a production sold-listing source is available.

**Candidate solutions:** (A) Marketplace Insights API with eBay approval — preferred; (B) third-party sold-listing provider — cost/reliability/TOS evaluation required; (C) active listings + historical snapshots — separate product review.

**Re-evaluate when:** snapshot pipeline is complete, production architecture is stable, Marketplace Insights access decision is known.

Full detail: [`tools/market_intel/SOLD_LISTING_DATA_SOURCE.md`](../tools/market_intel/SOLD_LISTING_DATA_SOURCE.md)

---

## ~~Market Intelligence — Matcher Coverage Validation~~

**Status: RESOLVED — Sprint 2 Step 3E.2.** Generalized matcher implemented. Coverage: 1,137 / 1,144 MATCHABLE (99.4%). Big Into Energy: 7/7 MATCHABLE. All 59 tests passing. This item is closed.

Full detail: [`tools/market_intel/CATALOG_COVERAGE_REPORT.md`](../tools/market_intel/CATALOG_COVERAGE_REPORT.md)

---

## Market Intelligence — Catalog Metadata Quality Audit

**Status:** Deferred — complete after matcher generalization evaluation (Sprint 2 Step 3E.1).

**Background:** Generalized matcher coverage depends on catalog data quality. The Sprint 2 Step 3E.1 simulation identified categories of figures that remain at risk even after matcher generalization due to catalog metadata gaps.

**Known examples:**

- **Smiski Series 2** (7 figures): `extractSeriesDistinctive` returns empty — series distinctive collapses to nothing after boilerplate strip. Currently classified `NO_SEARCH_TERMS`. Needs explicit `series.aliases[]` with a usable distinctive.
- **Sonny Angel Flower / Marine / Sweets / Snack / Fruit series** (12 figures each): single-word generic distinctive (4–6 chars) — satisfies borderline threshold but has false-positive risk. Example: `"Marine"` could match unrelated listings mentioning marine themes.
- **Smiski Bath / Yoga / Toilet series** (7 figures each): same issue — short generic single-word distinctive (4–6 chars).
- **THE MONSTERS Classic Series** (7 figures): distinctive is `"Classic"` (7 chars) — borderline.
- **Hirono Echo / Mime series** (13 figures each): distinctive is 4 chars — borderline minimum.
- **31 figures with `ambiguousFigureName`**: single-token names ≤ 5 chars with no `figure.aliases[]` or `marketAliases`. These pass the series gate after generalization but may fail `gate:figureIdentityRequired` against real listings.

**Potential future work:**

- Enrich `series.aliases[]` for Smiski Series 2 and other empty-distinctive series with explicit marketplace-safe phrases.
- Enrich `ip.aliases[]` for non-POP MART IPs (e.g. Dreams Inc., Rolife) with brand tokens sellers actually use.
- Improve `extractSeriesDistinctive` output for apostrophe-prefix cases (e.g. `"Nanci's..."` strips to `"'s Museum of Fantasy"`).
- Add `figure.aliases[]` for short-name figures (Luck→Lucky, Hope, Love, Id) to the seed catalog.
- Validate borderline series (4–7 char distinctive) against real eBay listing titles before production deployment.

**Priority:** Medium — does not block matcher generalization implementation, but required before production-scale snapshot runs.

**Re-evaluate when:** matcher generalization is implemented and post-generalization coverage audit is run.

---

## ~~Market Intelligence — Firestore Snapshot Persistence~~

**Status: RESOLVED — Sprint 2 Step 4B.** Design (4A) and implementation complete: `SnapshotDocument` includes `seriesId` and `confidence`; `push_market_snapshots.mjs` maps to canonical `market_snapshots` schema; `compute_snapshots.mjs --push-firestore` wires fetch → snapshot → Firestore. Flutter read path was already implemented. Remaining blocker for live data: Marketplace Insights approval.

Full design: [`tools/market_intel/FIRESTORE_PERSISTENCE_DESIGN.md`](../tools/market_intel/FIRESTORE_PERSISTENCE_DESIGN.md)

---

## Market Intelligence — Snapshot Scheduler

**Status:** Not started. Required for production operation.

**Background (Sprint 2 Step 3F):** The pipeline is triggered manually via CLI (`node tools/market_intel/compute_snapshots.mjs --fetch`). No automation, cadence, or failure-recovery mechanism exists.

**Options:**

- Firebase Cloud Scheduled Function (natural fit for existing Firebase project)
- GitHub Actions scheduled workflow (simple, uses CI infrastructure)
- External cron + CLI (minimal overhead, external dependency)

**Cadence decision required:** daily full rebuild vs. incremental refresh vs. per-series rotation. Decision depends on API quota and run cost (requires live Marketplace Insights data).

**Priority:** P1 — required before unattended production operation.

**Re-evaluate when:** Firestore persistence is implemented and first manual production run is validated.

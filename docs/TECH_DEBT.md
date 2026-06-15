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

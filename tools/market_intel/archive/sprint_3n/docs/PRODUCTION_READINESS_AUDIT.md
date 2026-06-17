# Production Readiness Audit — Market Intelligence

> **Sprint 2 Step 3F** — audit and planning only. No production code changes.
>
> Question answered: *If Marketplace Insights access were granted tomorrow, what would still prevent production deployment?*
>
> Generated: 2026-06-15 | Overall status: **Working Prototype**

---

## Section 1 — Current End-to-End Pipeline

### Implemented pipeline

```
Catalog (Firestore + seed JSON fallback)
  ↓ loadCatalogBundle()
Search Term Derivation
  ↓ deriveSearchTerms / extractSeriesDistinctive
Snapshot Search Planning
  ↓ buildFigureSearchPlans()
eBay Fetch Layer  ← BLOCKED on live sold-listing source
  ↓ fetchFigureCompletedSales()
Title Normalizer
  ↓ normalizeMarketTitle()
Matcher
  ↓ matchCatalogFigure()
Sales Aggregator
  ↓ aggregateSales()
Snapshot Document  ← IN-MEMORY ONLY (no Firestore write)
```

### Stage status table

| Stage | Module | Implemented | Tested | Production-Ready | Blocked |
|-------|--------|:-----------:|:------:|:----------------:|:-------:|
| Catalog | `_catalog_bundle.mjs` | ✅ | ✅ | ✅ | — |
| Search Term Derivation | `_search_term_derivation.mjs` | ✅ | ✅ | ✅ | — |
| Snapshot Search Planning | `_snapshot_search.mjs` | ✅ | ✅ | ✅ | — |
| eBay Fetch Layer | `_ebay_completed_sales.mjs` + `_snapshot_fetch.mjs` | ✅ (fixture) | ✅ | ❌ | Marketplace Insights approval |
| Title Normalizer | `_title_normalizer.mjs` | ✅ | ✅ | ✅ | — |
| Matcher | `_catalog_matcher.mjs` | ✅ | ✅ | ⚠️ partial | 137 borderline-distinctive figures unvalidated |
| Sales Aggregator | `_sales_aggregator.mjs` | ✅ | ✅ | ✅ | — |
| Snapshot Document | `_snapshot_document.mjs` | ✅ | ✅ | ❌ | No Firestore write, minimal schema |

**✅ = production-ready | ⚠️ = partial | ❌ = not ready**

### Notes per stage

**eBay Fetch Layer:** Per-query retry (3×) and rate-limit detection are implemented. Fixture
mode is fully functional and used for all current development and CI. The `EBAY_FETCH_MODE=fixture`
environment variable switches between modes transparently. The OAuth credential load path reads
from `functions/.env.blindbox-collection` or `tools/market_intel/.env.ebay` and is wired
correctly. Only the live API endpoint is blocked.

**Matcher:** Generalized in Sprint 3E.2. Big Into Energy: 7/7 MATCHABLE, all tests passing.
Overall: 1,137 / 1,144 MATCHABLE. 137 figures in 13 series have 4–7 char distinctive phrases
(`shortSeriesDistinctive` warning) that have not been validated against real eBay listing titles.

**Snapshot Document:** The document object (`figureId`, `snapshotAt`, `sampleSize`,
`averagePrice`, `medianPrice`, `minPrice`, `maxPrice`, `dataSource`) is produced correctly
in memory and printed via `--snapshot-debug`. No Firestore write logic exists.

---

## Section 2 — Missing Production Components

### P0 — Blocks launch

#### Firestore Persistence

The snapshot document is created in-memory at the end of each figure's pipeline run and then
discarded. Nothing is persisted.

Outstanding design decisions:

| Question | Status |
|----------|--------|
| Collection structure | Not designed |
| Document ID scheme | Not designed |
| Overwrite vs append | Not decided |
| Historical snapshots | Not designed |
| Field set for Firestore queries | Not decided |

Minimum needed before launch: a document write after `buildFigureSnapshot()` in
`compute_snapshots.mjs`. Collection structure must be decided first (see Section 5).

---

#### Live eBay Data Source

The Finding API was decommissioned. All production runs use fixture data. The Marketplace
Insights API requires explicit eBay business approval for the `buy.marketplace.insights` scope.
The OAuth credential infrastructure is ready; the endpoint path is known
(`/buy/marketplace/insights/v1_beta/item_sales/search`). Only approval is missing.

---

### P1 — Required before stable production operation

#### Snapshot Scheduler

Current launch path: manual CLI (`node tools/market_intel/compute_snapshots.mjs --fetch`).
No automation exists.

Options to evaluate:

| Option | Notes |
|--------|-------|
| Firebase Cloud Scheduled Function | Natural fit for Firebase project; requires Functions deployment |
| GitHub Actions scheduled workflow | Simple cron trigger; runs in CI infrastructure |
| External cron + CLI | Minimal overhead but external dependency |

Cadence decision needed: daily full rebuild vs. incremental refresh vs. per-series rotation.

---

#### Flutter Client Snapshot Read Layer

`market_snapshot_dev_screen.dart` exists as a developer display stub. It reads hardcoded dev
cases (`market_snapshot_dev_cases.dart`) and does not read from Firestore. The production
read path — loading per-figure snapshot documents and binding them to the UI — is not
implemented.

---

#### Borderline Series Validation

137 figures across 13 series carry `shortSeriesDistinctive` audit warnings. Their distinctive
phrases are 4–7 chars (e.g. `"Marine"`, `"Flower"`, `"Classic"`, `"Shelter"`, `"Reshape"`,
`"Echo"`, `"Mime"`, `"Bath"`, `"Yoga"`, `"Toilet"`, `"Sweets"`, `"Snack"`, `"Fruit"`). These
are short enough that a real eBay listing unrelated to the target brand/IP might contain them.

Before running production-scale snapshot generation for these series, their distinctive phrases
must be validated against real eBay listing titles to confirm acceptable false-positive rates.

---

### P2 — Deferred until after first production run

#### Observability

Current state: `stdout` / `stderr` logging only. No structured audit logs, no error aggregation,
no metric emission.

Missing for stable production operation:

- Structured per-figure result logging (matched count, rejected count, score distribution)
- Error reporting for failed figures (API error, matcher error, write error)
- Run-level audit log: figures attempted, succeeded, failed, skipped
- Optional: Cloud Logging / monitoring dashboard integration

None of this blocks the first production run, but should be in place before the pipeline
runs unattended on a regular schedule.

---

#### Failure Recovery and Checkpointing

Current failure model: per-query retry (3×), then log failure and move on. If the pipeline
crashes mid-run (process kill, OOM, network outage), the entire run must be restarted from
figure 1.

For 1,144 figures × ~2 queries each: a crash at figure 800 wastes ~70% of already-completed
work. No checkpoint state is written, no resume flag is supported.

Acceptable for manual one-off runs. Becomes a problem if the scheduler runs unattended and
crashes partway through.

---

#### Query Cache / Incremental Refresh

Current cost per full run: **2,433 unique eBay queries** (from dry-run output).

No cache between runs. Every run re-queries every figure. Until Marketplace Insights rate
limits and pricing are known, this cannot be fully evaluated — but it is a known risk.

See: `QUERY_VOLUME_OPTIMIZATION.md` and tech debt entry.

---

## Section 3 — Query Volume Analysis

### Per-run numbers (from `--dry-run`)

| Metric | Value |
|--------|------:|
| Total figures | 1,144 |
| Figures with search terms | 1,137 |
| Figures skipped (NO_SEARCH_TERMS) | 7 |
| Total queries before per-figure dedupe | 2,462 |
| Unique queries (after per-run dedupe) | 2,433 |
| Cross-figure duplicate query strings | 29 |
| Average queries per figure | ~2.15 |

### Frequency projections

| Cadence | Queries per run | Queries per week | Queries per month |
|---------|----------------:|----------------:|------------------:|
| Once daily | 2,433 | 17,031 | ~73,000 |
| Twice daily | 2,433 × 2 | 34,062 | ~146,000 |
| Weekly full rebuild | 2,433 | 2,433 | ~9,700 |

### Cost and quota notes

eBay Marketplace Insights API rate limits are not publicly documented. They vary by approval
tier. Until access is granted and the rate limit confirmed, exact cost cannot be calculated.

The current 29 cross-figure duplicate query strings (queries shared by multiple figures) could
be deduplicated at the fetch layer, reducing 2,433 to ~2,404 per run. Negligible at current
scale. More meaningful optimization would come from a per-normalized-query cache with a
configurable TTL (e.g. skip re-fetch if query ran within last 24h).

**No speculative cost estimate is provided.** This requires actual Marketplace Insights quota
data.

---

## Section 4 — Existing Technical Debt Review

### Query Volume Optimization

**Still relevant:** Yes.
**Blocks production launch:** No.
**Phase:** Post-launch.
**Priority:** P2 — revisit after first successful production run generates real quota data.
**Assessment:** Numbers are now confirmed: 2,433 unique queries per full run. The 29 duplicate
queries are noise-level savings. The real optimization opportunity is a query-level TTL cache
(skip re-fetch if same normalized term ran within N hours). Implement after API quota is known.

---

### Matcher Coverage Validation

**Still relevant:** No — **RESOLVED** in Sprint 3E.2.
**Phase:** Complete.
**Assessment:** Generalization upgraded 1,130 figures. Current coverage: 1,137 / 1,144 MATCHABLE
(99.4%). Big Into Energy: 7/7 MATCHABLE, regression tests passing. This tech debt item can be
closed.

---

### Catalog Metadata Quality Audit

**Still relevant:** Yes.
**Blocks production launch:** No (but should precede production-scale runs).
**Phase:** Pre-production-scale.
**Priority:** P1.
**Assessment:** 137 borderline-distinctive figures, 7 NO_SEARCH_TERMS (Smiski Series 2), 31
ambiguous-figure-name figures without market aliases. These do not block the pipeline from
running, but will produce lower-quality matches. Needs real eBay listing data to validate.

---

## Section 5 — Firestore Readiness

### Current snapshot document shape

```js
{
  figureId:      string,          // "the_monsters_big_into_energy_vinyl_plush_pendant_luck"
  snapshotAt:    ISO 8601 string, // "2026-06-15T03:21:03.439Z"
  sampleSize:    number,          // count of matched listings
  averagePrice:  number | null,   // USD
  medianPrice:   number | null,   // USD
  minPrice:      number | null,   // USD
  maxPrice:      number | null,   // USD
  dataSource:    string           // "fixture" | "live"
}
```

### Can this be stored directly in Firestore?

Yes, technically — every field is a Firestore-compatible primitive. But the shape is
insufficient for production use.

### Missing fields for production

| Field | Purpose |
|-------|---------|
| `seriesId` | Query by series |
| `brandId` | Query by brand |
| `currency` | Price display in non-USD locales |
| `matcherVersion` | Track which matcher built the snapshot |
| `runId` | Link document to the run that produced it |
| `figureDisplayName` | Avoid a catalog read for display-only use |

### Historical support decision

**Option A — Latest only** (`market_snapshots/{figureId}`)

Simple. One document per figure. Each run overwrites. No history. Suitable for MVP.

**Option B — Time series** (`market_snapshots/{figureId}/history/{snapshotAt}`)

Preserves price history over time. Enables trending. Requires a `latest` pointer or
separate `market_snapshots_latest/{figureId}` collection for fast reads.

**Option C — Run-based** (`snapshot_runs/{runId}/figures/{figureId}`)

Groups all figures by run. Allows run-level queries. More complex client reads.

**Recommendation:** Start with Option A (latest only) for the first production run. Add Option B
(subcollection history) in a follow-up sprint once the write path is working and the cadence is
established. The document ID `figureId` is stable and queryable.

### Aggregation strategy

No secondary aggregation (e.g. per-series median) is designed or needed at this stage. The
Flutter client reads per-figure documents; per-series views can be computed client-side from
the per-figure documents.

### Rebuild strategy

Full rebuild on each scheduled run. Incremental refresh (only run figures that haven't been
updated in N days) is a query-optimization decision, deferred to the same tech debt item.

---

## Section 6 — Data Source Readiness

| Source | Status | Notes |
|--------|--------|-------|
| Fixture | **READY** | Fully functional. Used for all development and CI. Realistic fixture data for Big Into Energy. Other series have sparse or no fixture data. |
| Finding API | **BLOCKED** | Decommissioned. `findCompletedItems` unavailable. Not recoverable. |
| Marketplace Insights | **BLOCKED** | Pending eBay business approval. `buy.marketplace.insights` scope required. OAuth infrastructure ready. Endpoint known. |
| Third-party provider | **NOT EVALUATED** | Apify and other data vendors not assessed for cost, reliability, or TOS compliance. Viable fallback if Marketplace Insights approval is delayed. |

---

## Section 7 — Launch Checklist

Items required before "Production Candidate" status:

### External dependencies (not code)

- [ ] eBay Marketplace Insights API approved (`buy.marketplace.insights` scope)

### Architecture decisions (precede implementation)

- [ ] Firestore collection structure and document schema decided
- [ ] Snapshot scheduler approach selected (Cloud Function vs. GitHub Action vs. cron)
- [ ] Query cache strategy documented (TTL, normalized key, invalidation)

### Implementation

- [ ] Firestore persistence implemented in `compute_snapshots.mjs` pipeline
- [ ] Flutter client production read path implemented (Firestore → UI binding)
- [ ] Snapshot scheduler deployed and tested

### Validation

- [ ] Real sold listings fetched via Marketplace Insights and matched against catalog
- [ ] Borderline-distinctive series (4–7 char phrase) validated against real listing titles
- [ ] Full production dry-run completed (1,144 figures, live API)
- [ ] Coverage audit re-run on live Marketplace Insights data
- [ ] Match quality spot-check: 5+ series beyond Big Into Energy manually reviewed
- [ ] API cost and quota review completed with real run data

### Data quality

- [ ] Short-name figure aliases added for critical `ambiguousFigureName` figures (Luck→Lucky, Hope, Love, Id)
- [ ] Smiski Series 2 catalog fix (series.aliases for distinctive) evaluated

---

## Section 8 — Recommendation

### Working Prototype

The market intelligence pipeline is a **Working Prototype**.

**What works:**

- Complete end-to-end pipeline in fixture mode: catalog → search terms → fetch → normalize → match → aggregate → snapshot document
- Matcher generalized to 99.4% catalog coverage (1,137 / 1,144 figures)
- 59/59 tests passing
- Big Into Energy regression: 7/7 MATCHABLE, all test cases preserved
- CLI orchestrator with `--fetch`, `--dry-run`, `--snapshot-debug`, `--figure`, `--series`, `--limit` flags
- Dry-run analysis: 2,433 unique queries quantified

**What doesn't:**

- No live sold-listing data (Marketplace Insights blocked)
- No Firestore persistence (snapshot documents discarded after each run)
- No scheduler (manual CLI only)
- No observability beyond stdout
- 137 borderline-distinctive figures unvalidated on real titles

**Path to Production Candidate:**

| Step | Dependency | Estimate |
|------|-----------|---------|
| Marketplace Insights approval | eBay external | Unknown |
| Firestore schema design | Architecture decision | 1 sprint |
| Firestore persistence implementation | Code | 1 sprint |
| Flutter client read path | Code | 1 sprint |
| Snapshot scheduler | Code + infra | 1 sprint |
| Live data validation | Requires Marketplace Insights | 1 sprint |

**Conservative assessment:** The pipeline is 2–3 engineering sprints away from Production
Candidate status, assuming Marketplace Insights access is granted. The external approval is
the only item that cannot be self-unblocked.

---

Re-run this audit script (JSON output only):

```bash
node tools/market_intel/catalog_coverage_audit.mjs --json-only
node tools/market_intel/compute_snapshots.mjs --dry-run
```

For query volume numbers: redirect `--dry-run` output and grep `PLAN SUMMARY`.

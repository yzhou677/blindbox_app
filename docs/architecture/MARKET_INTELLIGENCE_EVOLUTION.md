# Market Intelligence — Architecture Evolution

> **Purpose:** Permanent historical record of how Shelfy Market Intelligence evolved from earliest concepts to the Sprint 1 architecture on branch `v2-market-intelligence`.
>
> **Audience:** Future maintainers. This is an architecture decision record (ADR-style history), not an implementation spec.
>
> **Evidence sources:** Git history, `lib/features/market_intel/`, `tools/market_intel/`, `.cursor/ARCHITECTURE.md`, `docs/COLLECTIBLE_MARKET_INTELLIGENCE.md`, and a read-only Git investigation performed 2026-06-14.

---

## Overview

### Why Market Intelligence exists

Shelfy collectors want to know what a figure is *worth* in the real world — not just what listings are available right now. Market Intelligence answers that question with a **persisted, catalog-linked price estimate** derived from completed sales, shown quietly alongside catalog and shelf surfaces.

The product goal is **trustworthy context**, not trading analytics. A collector should see something like “~$42, based on 18 sales” and understand it is an estimate grounded in recent sold data — not a live bid, not investment advice, not a guarantee.

### How V2 differs from V1 live market browse

Shelfy already had market-related intelligence before V2. These are **two separate systems** that must not be conflated.

| | **V1 — Collectible Market Intelligence (Phase 3B)** | **V2 — Market Intelligence (Sprint 1)** |
|---|---|---|
| **Introduced** | `77eb98b` — 2026-05-22 | `b3e09ce` — 2026-06-14 |
| **Location** | `lib/features/market/` | `lib/features/market_intel/` |
| **Data source** | Live browse listings via eBay gateway | Completed sales aggregated offline |
| **Persistence** | Session + optional `CollectibleMarketSnapshotCache` (memory + SharedPreferences) | Firestore `market_snapshots` documents |
| **Core model** | `CollectibleMarketSnapshot` — mood, sightings, price range | `MarketSnapshot` — `estimatedValueUsd`, trend, confidence |
| **Write path** | Client aggregates at browse time | Admin Node pipeline writes; app is read-only |
| **UI today** | `CollectibleMarketCard` on Market tab | `MarketSnapshotBadge` (not yet integrated into production screens) |
| **Doc** | [`docs/COLLECTIBLE_MARKET_INTELLIGENCE.md`](../COLLECTIBLE_MARKET_INTELLIGENCE.md) | [`FIRESTORE_MARKET_SNAPSHOTS_SCHEMA.md`](../../lib/features/market_intel/data/firestore/FIRESTORE_MARKET_SNAPSHOTS_SCHEMA.md), [`MATCHING_DESIGN.md`](../../tools/market_intel/MATCHING_DESIGN.md) |

**The critical architectural shift:** V1 tolerates imperfect listing-to-figure matches because a wrong card is dismissible. V2 writes a **persisted dollar estimate** that every future user may see. A false match in V2 corrupts trust at scale. That difference drove every simplification decision below.

V1 remains on `main` and continues to serve the Market browse tab. V2 lives on `v2-market-intelligence` (three commits ahead of `main` as of `ffb17c9`).

---

## Original Concepts Considered

The items below were **seriously discussed during V2 architecture planning** (May–June 2026). Git investigation confirms **none were ever committed as V2 code**. They represent design-time exploration, not removed implementations.

Where a similar concept exists in V1, that is noted — V1 informed what V2 should avoid duplicating.

---

### PriceHistoryPoint

**What it was:** A domain type representing one historical price observation (date, price, sale count) — building blocks for charts or trend lines over time.

**Why it seemed attractive:** Price history is the natural next feature after a point estimate. Charts feel premium and help collectors see momentum beyond a single `estimatedValueUsd`.

**Why it was rejected for Sprint 1:** Price history requires sustained pipeline correctness, storage schema, and UI surfaces none of which were validated yet. Shipping history before matching quality was proven would build infrastructure on uncertain data. Deferred as an **additive** Firestore subcollection path (see Future Expansion), not deleted from the product vision.

**Git evidence:** `PriceHistoryPoint` — zero pickaxe hits in repository history.

---

### TrendStrength

**What it was:** A richer trend signal beyond the four-value `MarketTrend` enum — e.g. graded magnitude of rise/fall, or separate strength from direction.

**Why it seemed attractive:** “Rising” without context can mislead when the underlying sample is thin. A strength dimension could suppress noisy trend labels.

**Why it was rejected:** Added model and UI complexity before the base trend algorithm (two 15-day median windows, 15% threshold) was implemented or validated. Sprint 1 ships `MarketTrend` with `unknown` as the safe default. Strength can be layered later via metadata or additional fields without breaking existing documents.

**Git evidence:** `TrendStrength` — zero pickaxe hits in repository history.

---

### MarketSnapshotCache (V2 app-side cache)

**What it was:** A proposed V2 cache layer — distinct from V1’s `CollectibleMarketSnapshotCache` — to persist Firestore snapshot reads locally (memory + SharedPreferences) for faster repeat loads and offline badge display.

**Why it seemed attractive:** Shelfy is offline-first elsewhere (collection codec, catalog disk cache). Symmetry suggested caching market snapshots too.

**Why it was rejected:** V2 snapshots update on a **daily admin cadence**, not continuously. Firestore’s built-in offline persistence plus Riverpod `FutureProvider.autoDispose.family` caching is sufficient for one-shot reads. A custom SharedPreferences codec would duplicate persistence logic, require migration/versioning, and risk stale estimates without adding proportional value.

**Related V1 artifact (still exists):** `CollectibleMarketSnapshotCache` in `lib/features/market/data/cache/` — appropriate for browse-session data, not copied into V2.

**Git evidence:** No V2 `MarketSnapshotCache` type ever committed. SharedPreferences cache pattern exists only in V1 browse intelligence.

---

### SharedPreferences cache layer (V2)

**What it was:** Same motivation as MarketSnapshotCache — serializing `MarketSnapshot` batches to SharedPreferences for offline badge hydration.

**Why it seemed attractive:** Guarantees badge text on airplane mode without waiting for Firestore.

**Why it was rejected:** Same reasoning as MarketSnapshotCache. Additionally, showing a **stale price estimate** with no indication of age is worse than showing no badge until Firestore resolves or offline cache serves. The “No Market Data Yet” null state (see `MATCHING_DESIGN.md` Section 11) is an intentional product choice. Custom prefs caching fought that contract.

---

### Stream-based repositories

**What it was:** `Stream<MarketSnapshot?>` or `watchSnapshot(figureId)` APIs on `MarketSnapshotRepository` for real-time Firestore listeners.

**Why it seemed attractive:** Riverpod stream providers are idiomatic; live updates feel modern.

**Why it was rejected:** Snapshots change once per day at most. Stream listeners add battery cost, lifecycle complexity, and test surface for no user-visible benefit. The repository intentionally exposes **three `Future` methods only** — one-shot `.get()` queries.

**Git evidence:** Schema doc explicitly forbids stream listeners. No stream implementation committed.

---

### watchSnapshot()

**What it was:** A named stream/watch API on the repository or provider layer — the consumer-facing version of stream-based repositories.

**Why it seemed attractive:** Familiar pattern from other Firebase features; enables reactive UI without manual refresh.

**Why it was rejected:** Same as stream-based repositories. Progressive enrichment via `FutureProvider` matches the product pacing: catalog/shelf render first; badge enriches when snapshot arrives.

**Git evidence:** `watchSnapshot` — zero pickaxe hits in repository history.

---

### marketSearchTerms on CatalogFigure

**What it was:** Storing eBay search terms and exclude terms directly on catalog figure documents / `CatalogFigure` Dart models — co-locating pipeline inputs with canonical identity.

**Why it seemed attractive:** One place to look up everything about a figure. Search terms feel “metadata about the figure.”

**Why it was rejected:** Search terms are **pipeline operational data**, not catalog truth. They change frequently during matching tuning, may be empty for ambiguous figures, and would pollute Firestore catalog documents consumed by the entire app. Moved to admin-only `tools/market_intel/market_metadata.json` — loaded by Node pipeline, never by Flutter.

**Git evidence:** `marketSearchTerms` — zero pickaxe hits on catalog models.

---

### Price history subcollections in Sprint 1

**What it was:** `market_snapshots/{id}/price_history/{YYYY-MM-DD}` written from day one alongside top-level snapshot documents — dual-write on every pipeline run.

**Why it seemed attractive:** Enables future charts without a later backfill migration. Schema-forward design.

**Why it was rejected for Sprint 1:** Doubles pipeline write scope and storage before a single snapshot proved useful in production UI. The schema **reserves** the path as a future additive change; Sprint 1 writes top-level documents only.

**Git evidence:** `price_history` appears in `b3e09ce` schema doc as explicit deferral, not as implemented subcollection code.

---

### Additional confidence tiers

**What it was:** Expanding `SnapshotConfidence` beyond `high` / `low` — e.g. `medium`, `none`, or mirroring V1’s four-tier `MarketMatchConfidence` (exact / high / medium / low).

**Why it seemed attractive:** Finer gradations could drive richer UI (different badge styles per tier) and mirror the existing identity matcher vocabulary.

**Why it was rejected:** More tiers increase ambiguity for collectors (“what does medium confidence mean for my money?”). V2 matching rejects sub-threshold sales outright — there is no “low confidence acceptance” into the aggregate. Two tiers map cleanly to UI: normal display vs. asterisk (`*`) for caution. `MATCHING_DESIGN.md` decouples confidence from snapshot level (figure vs. series).

**V1 context:** `MarketMatchConfidence` and `AggregationConfidence` remain in browse intelligence; V2 deliberately simplified.

---

### Richer snapshot models

**What it was:** Early designs duplicated catalog context on snapshot documents (`brandId`, `ipId`, display names) or added analytics fields (seller patterns, provider breakdown, mood/rarity from V1).

**Why it seemed attractive:** Self-contained Firestore documents; fewer catalog joins at read time; reuse of V1 editorial signals.

**Why it was rejected:** Catalog is already the source of truth for identity and display names. Duplicating fields creates sync drift when catalog updates. V1 mood/rarity signals serve browse editorial tone, not persisted pricing. Final `MarketSnapshot` is intentionally minimal: price estimate, trend, confidence, sale count, optional range, timestamps, and catalog foreign keys (`figureId`, `seriesId`) only.

**Git evidence:** `FIRESTORE_MARKET_SNAPSHOTS_SCHEMA.md` “Do not introduce” section lists `brandId` / `ipId` explicitly.

---

## Key Simplification Decisions

These decisions survived every architecture review pass and are encoded in Sprint 1 code and docs.

### Firestore snapshots are read-only (Flutter app)

**Decision:** The mobile app never writes to `market_snapshots`. All aggregation happens in admin tools under `tools/market_intel/`.

**Maintainability:** Clear security boundary. App engineers cannot accidentally mutate production estimates. Pipeline bugs are isolated to Node scripts, testable without app releases.

---

### Admin pipeline owns writes

**Decision:** Matching, IQR filtering, median computation, and Firestore push are Sprint 2+ Node responsibilities (`MATCHING_DESIGN.md` Sprint 2 order). Sprint 1 validated the read path only.

**Maintainability:** Heavy computation and eBay API integration stay off-device. Solo maintainer runs pipeline on schedule, reviews `_review_log.json`, adjusts `market_metadata.json` — no app store release required for matching fixes.

---

### No custom cache

**Decision:** No V2 SharedPreferences snapshot codec. Rely on Firestore offline persistence and Riverpod provider caching.

**Maintainability:** One less persistence format to version and migrate. Avoids stale estimate display without `computedAt` UI everywhere.

---

### No streams

**Decision:** Repository uses one-shot `Future` + `.get()`. No Firestore listeners in the app.

**Maintainability:** Simpler provider graph, fewer lifecycle edge cases, lower battery use. Matches daily update cadence.

---

### High / low confidence only

**Decision:** `SnapshotConfidence { high, low }` — no medium tier, no “accepted but uncertain” sales in aggregates.

**Maintainability:** Binary UI contract (`*` suffix or not). Matching pipeline rejects ambiguous sales rather than degrading them into aggregates.

---

### Figure-first intelligence

**Decision:** Primary snapshot key is `figureId`. Every figure with sufficient sold data gets its own document at `market_snapshots/{figureId}`.

**Maintainability:** Aligns with how collectors think (this Lucky, not “some figure in Big Into Energy”). Provider lookup tries figure document first.

---

### Series fallback

**Decision:** When no figure snapshot exists, `marketSnapshotProvider` falls back to `market_snapshots/{seriesId}` with `level == "series"`. UI must label this (`isSeriesEstimate`).

**Maintainability:** Covers low-liquidity figures without faking figure-level precision. Fallback is explicit in domain model and display rules — not silent averaging.

---

### market_metadata.json outside catalog

**Decision:** Search terms, exclude terms, aliases, thresholds, and disable flags live in `tools/market_intel/market_metadata.json`.

**Maintainability:** Pipeline tuning does not require catalog migrations or app redeploys. Catalog models stay clean for all three universes (catalog / shelf / market).

---

### No price history in Sprint 1

**Decision:** Top-level snapshot documents only. Subcollection path documented but not written.

**Maintainability:** Proves matching + estimate value before investing in historical storage and chart UI. Additive future change — no migration of existing documents required.

---

## Final Sprint 1 Architecture

Sprint 1 landed in two implementation commits plus one design doc commit on `v2-market-intelligence`:

| Commit | Date | Summary |
|---|---|---|
| `b3e09ce` | 2026-06-14 | Sprint 1 read-only foundation |
| `58cd2f3` | 2026-06-14 | Dev validation screen + Firestore seed tooling |
| `ffb17c9` | 2026-06-14 | Full `MATCHING_DESIGN.md` (Sprint 2 spec) |

No intermediate design commits exist between `main` and `b3e09ce` — architecture conversations condensed directly into implementation.

### Three-universe placement

V2 Market Intelligence is a **fourth read path** adjacent to the three existing universes:

- **Catalog** — canonical identity (figure/series IDs)
- **Shelf** — local-first ownership
- **Market browse** — live listings (V1 intelligence)
- **Market intel (V2)** — persisted sold-data estimates, read via Firestore

It consumes catalog IDs but does not mutate catalog or shelf state.

### Folder layout

```
lib/features/market_intel/
├── application/
│   └── market_snapshot_providers.dart      # Riverpod repo + figure→series fallback
├── data/firestore/
│   ├── FIRESTORE_MARKET_SNAPSHOTS_SCHEMA.md
│   ├── firestore_market_snapshot_mapper.dart
│   └── firestore_market_snapshot_repository.dart
├── domain/
│   ├── market_snapshot.dart                # MarketSnapshot, enums
│   └── market_snapshot_repository.dart     # abstract Future-only interface
├── widgets/
│   └── market_snapshot_badge.dart          # inline pill UI
└── dev/                                    # temporary validation (dart-define gated)
    ├── market_snapshot_dev_screen.dart
    ├── market_snapshot_dev_cases.dart
    ├── market_snapshot_dev_config.dart
    └── dev_mock_market_snapshot_repository.dart

tools/market_intel/
├── MATCHING_DESIGN.md                      # Sprint 2 matching spec (authoritative)
├── market_metadata.json                    # admin pipeline inputs (sample)
├── market_snapshots_dev.seed.json          # dev Firestore seed
├── push_market_snapshots_dev.mjs           # seed push script
└── DEV_VALIDATION.md                       # read-path validation runbook

test/
├── market_intel_mapper_test.dart
└── market_intel_snapshot_provider_test.dart
```

### Domain model

[`MarketSnapshot`](../../lib/features/market_intel/domain/market_snapshot.dart):

- `estimatedValueUsd` — median of qualifying completed sales (computed by future pipeline)
- `MarketTrend` — `rising` | `falling` | `stable` | `unknown` (default when uncomputed)
- `SnapshotConfidence` — `high` | `low`
- `SnapshotLevel` — `figure` | `series`
- `isSeriesEstimate` getter for UI labeling

### Read path

```
Firestore market_snapshots/{id}
  → FirestoreMarketSnapshotMapper
  → FirestoreMarketSnapshotRepository  (one-shot .get())
  → marketSnapshotProvider             (figure doc, then catalog lookup + series doc)
  → MarketSnapshotBadge                (or null → caller shows "No Market Data Yet")
```

### What Sprint 1 explicitly did not include

- eBay completed-sales integration
- Matching/scoring pipeline (`MATCHING_DESIGN.md` is Sprint 2)
- Production screen integration (badge exists; not wired into catalog/shelf sheets yet)
- Price history subcollections
- App-side snapshot cache or streams

### Sprint 2 boundary ( documented, not implemented )

[`MATCHING_DESIGN.md`](../../tools/market_intel/MATCHING_DESIGN.md) defines the admin pipeline: title normalization, catalog matching (≥ 0.75 threshold), IQR outlier removal, minimum 3 sales, trend windows, `SnapshotSkipReason` review log, and Firestore push. Implementation order is listed at the document bottom.

---

## Lessons Learned

### Accuracy over coverage

A missing badge is invisible. A wrong `$85` on a `$12` figure is not. V2 matching design rejects borderline sales rather than including them with a weak confidence tier. Coverage grows through better `market_metadata.json`, not looser gates.

### Trust over data volume

More data points only help when each point is the correct sale. The three-question filter chain in `MATCHING_DESIGN.md` (query scope, title confirmation, transaction plausibility) exists because volume without verification actively harms the product.

### Catalog as source of truth

Snapshot documents store foreign keys (`figureId`, `seriesId`), not duplicated brand/IP/display data. Pipeline search terms live outside catalog. This prevents operational tuning from polluting canonical models and avoids display drift.

### Simplicity beats speculative architecture

Early V2 sketches included caches, streams, history subcollections, and richer enums — patterns that work at scale but cost solo-maintainer time upfront. Each was cut before Sprint 1 code landed. The implemented surface area fits in ~1,600 lines across app, tests, tools, and docs.

### Avoid building infrastructure before proving value

Sprint 1’s dev validation flow (`MarketSnapshotDevScreen`, seed push script) exists to prove **Firestore → Repository → Provider → UI** before any eBay integration. Price history, watchlists, and multi-marketplace support wait until persisted estimates earn their place in collector workflows.

### Document decisions, not just code

Git received Sprint 1 implementation in near-final form; iterative design lived in conversation. This file and `MATCHING_DESIGN.md` exist so future maintainers understand **why** the code looks the way it does — not only **what** it does.

---

## Future Expansion Paths

These ideas were **postponed, not rejected**. The Sprint 1 schema and matching design reserve extension points without requiring migrations of existing snapshot documents.

### Price history

**Status:** Deferred from Sprint 1.

**Path:** Add `market_snapshots/{id}/price_history/{YYYY-MM-DD}` subcollection per [`FIRESTORE_MARKET_SNAPSHOTS_SCHEMA.md`](../../lib/features/market_intel/data/firestore/FIRESTORE_MARKET_SNAPSHOTS_SCHEMA.md). Pipeline dual-writes daily snapshot + history entry. Requires chart UI and validated matching quality first.

**Related deferred concept:** `PriceHistoryPoint` domain type for client-side chart rendering.

---

### Watchlists

**Status:** Not scoped in Sprint 1 or 2.

**Path:** Would likely live in user-private shelf universe or a new user prefs layer — not in `market_snapshots`. Could consume `marketSnapshotProvider` for display. No code or schema started.

---

### Alerts

**Status:** Not scoped.

**Path:** Depends on price history + user notification preferences + reliable pipeline cadence. Meaningful alerts require trustworthy baselines; building them before matching matures would generate false positives.

---

### Additional marketplaces

**Status:** Postponed; architecturally anticipated.

**Path:** `market_metadata.json` search terms are marketplace-agnostic strings. Sprint 2 targets eBay completed sales. Mercari, StockX, or others add a second query function in the Node pipeline — not a schema change. V1 already has multi-provider browse architecture in `lib/features/market/` as precedent.

---

### Advanced matching

**Status:** Sprint 2 baseline is deterministic keyword matching (`MATCHING_DESIGN.md`). ML/embeddings explicitly declared non-goals.

**Path:** Incremental metadata improvements — tighter `searchTerms`, `marketAliases`, per-figure `matchThreshold`, exclude terms — before any algorithmic leap. Optional future: retail-price sanity checks if `retailPrice` joins `CatalogFigure`.

---

## Appendix: Git timeline (V2 branch)

```
2026-05-22  77eb98b  V1 Collectible Market Intelligence (on main, separate system)
2026-06-14  b3e09ce  V2 Sprint 1 foundation — first lib/features/market_intel/
2026-06-14  58cd2f3  Dev validation + Firestore seed tooling
2026-06-14  ffb17c9  Full MATCHING_DESIGN.md (replaces headings-only template from b3e09ce)
```

**Branch state:** `v2-market-intelligence` is ahead of `main` by the three commits above. `main` contains zero `market_intel` files.

**Investigation note:** Concepts listed in “Original Concepts Considered” never appeared in any Git commit as V2 implementations. V1 `CollectibleMarketSnapshotCache` (`77eb98b`) remains on `main` and informed the decision not to duplicate caching in V2.

---

*Last updated: 2026-06-14 — reflects Sprint 1 + matching design through `ffb17c9`.*

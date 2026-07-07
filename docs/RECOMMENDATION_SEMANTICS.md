# ADR: Recommendation Semantics (For You)

**Shelfy For You — canonical product architecture and implementation reference**

| | |
|---|---|
| **Status** | **Accepted** |
| **Scope** | `lib/features/recommendations/`, `functions/src/recommendations*`, For You UI |
| **Supersedes** | Owned-IP affinity, wishlist scoring, figure-level refresh triggers |

---

## Read this first

**Anyone modifying recommendation behavior** — Dart, Cloud Functions, Firestore profile contract, tests, reason copy, or For You visibility — **must read this document before writing code**.

This file is an **Architecture Decision Record (ADR)**. It records *why* For You works the way it does, not only *how*. Do not “fix,” “simplify,” or “make more real-time” behavior documented here without an explicit product decision and an update to this ADR.

Related boundaries: [`.cursor/ARCHITECTURE.md`](../.cursor/ARCHITECTURE.md) (catalog / shelf / market), [`CATALOG_ARCHITECTURE.md`](CATALOG_ARCHITECTURE.md) (catalog identity).

---

## Core principles (non-negotiable)

These five separations define Shelfy recommendations. They are **closed** — not bugs, not TODOs.

| Principle | Meaning |
|-----------|---------|
| **Taste ≠ Progress** | *Taste* = which series/IPs the user decided to collect (**tracked**). *Progress* = owned figures, completion, master complete (**owned**). Progress does not drive For You refresh or ranking. |
| **Progress ≠ Shopping** | *Shopping* = wishlist inside a tracked series. Wishlist is collection and Market intent — not taste, not scoring, not sync. |
| **Recommendations are intentionally stable** | For You refreshes only when **long-term collecting taste** changes (add/remove **tracked** catalog series). Owned progress and wishlist toggles do not reshuffle the rail. |
| **Add Series = explicit collecting intent** | Adding a catalog series to My Collection means *“I am collecting this IP.”* IP affinity follows **tracked** IPs — no owned figure required. |
| **Tracked is the only taste signal** | `trackedCatalogSeriesIds` / `trackedIpIds` alone drive exclusion, readiness, `profileHash`, refresh, sync, and IP affinity (+30). Nothing else is taste. |

---

## Closed decisions

The following are **final** unless this ADR is explicitly revised.

> **Wishlist intentionally does not participate in recommendations.**
>
> Wishlist does not score, hash, sync, upload, or refresh For You. Re-adding wishlist to the recommendation pipeline is out of scope without a new ADR.

> **Owned figures intentionally do not participate in recommendation ranking.**
>
> Owned state drives collection progress, completion UI, and confidence tiers only.

> **“Why doesn’t marking owned / updating wishlist refresh For You?”** → Product design, not a bug. See [§1 Product rules](#1-product-rules).

---

## Context

Collectors express intent at different depths: deciding to collect a series, marking figures owned, or wishlisting for purchase. For You must answer:

> *What should I collect next based on the series I’ve decided to collect?*

—not “what matches figures I already own?” and not “what’s on my wishlist?” A rail that reshuffles on every figure tap feels noisy and untrustworthy. A rail that ignores Add Series feels blind to deliberate taste.

---

## Decision

1. **Taste** = tracked catalog series (and derived `trackedIpIds`).
2. **Refresh** = tracked series add/remove only (`profileHash` = tracked series ids).
3. **Scoring** = tracked IP +30, recent release +10, diversity, 80/20 exploration, quality-first count, gap fill — Dart ≡ Cloud.
4. **Owned** and **wishlist** stay in the collection universe; they do not enter the recommendation pipeline.
5. **Repository owns decisions**; widgets project results only.

---

## Consequences

**We gain:** Stable For You; fewer cloud syncs; higher cache hit rate; intuitive “track series → see same-IP picks”; clear mental model for support and future contributors.

**We give up:** Real-time reshuffle on owned progress or wishlist; wishlist- or owned-based “you might also like” in For You (those belong elsewhere if ever).

**We will not do without a new ADR:** Wishlist scoring; owned-IP affinity; figure-level `profileHash`; backend-driven For You UI; recommendation logic in widgets.

---

## Implementation links

| Layer | Primary files |
|-------|----------------|
| Signals | [`preference_signal_extractor.dart`](../lib/features/recommendations/data/preference_signal_extractor.dart) |
| Readiness | [`recommendation_confidence.dart`](../lib/features/recommendations/domain/recommendation_confidence.dart), [`recommendation_readiness_provider.dart`](../lib/features/recommendations/application/recommendation_readiness_provider.dart) |
| Repository | [`recommendation_repository.dart`](../lib/features/recommendations/data/recommendation_repository.dart) |
| Local rule engine | [`recommendation_rule_engine.dart`](../lib/features/recommendations/data/recommendation_rule_engine.dart) |
| Cloud rule engine | [`functions/src/recommendations/ruleEngine.ts`](../functions/src/recommendations/ruleEngine.ts) |
| UI | [`for_you_section.dart`](../lib/features/recommendations/widgets/for_you_section.dart) |

---

# Implementation reference

The sections below are the **detailed spec** for the decision above. When code and this doc disagree, treat divergence as a bug unless this ADR is updated first.

> **Design philosophy**
>
> Shelfy recommends what a collector is likely to collect **next**. Add Series = collecting intent; tracking a series means *"I am collecting this IP"* — no owned figure required for IP affinity.
>
> Recommendation refreshes only when the user's long-term collecting taste changes.
>
> Collection progress (owned figures) does not immediately trigger recommendation recomputation.
>
> However, whenever a recomputation does occur, the rule engine always uses the latest collection snapshot, including the current **tracked IP** signals.
>
> This intentionally balances recommendation stability with recommendation quality.
>
> **Stability principle:** For You is intentionally stable. Recommendation refreshes only when the user's long-term collecting taste changes (tracked series). Collection progress and shopping intent do not immediately reshuffle recommendations.

---

## 1. Product rules (non-negotiable)

| Rule | Meaning |
|------|---------|
| **Add Series = explicit interest** | Adding a catalog series to **My Collection** is the user’s first deliberate preference signal. No owned figure is required for personalization to begin. |
| **Tracked series are never recommended** | Any catalog series currently on the user’s shelf must **never** appear in For You again — regardless of figure ownership, wishlist, or completion. |
| **Tracked series drive refresh** | `profileHash`, cache invalidation, and cloud profile sync react to **tracked catalog series** changes only — add/remove series is a taste change; owned figures and wishlist are not. |
| **Tracked IPs drive affinity** | Taxonomy IPs from tracked catalog series boost same-IP ranking (`tracked_ip` +30) when recommendations are computed. No owned figure required. |
| **Owned figures are progress, not taste** | Figure `owned` state drives confidence tiers and collection UI only — it does not score, hash, sync, or refresh For You. |
| **Wishlist is not taste** | Wishlist figure state does not score, hash, sync, or refresh recommendations — it remains for collection and Market. **Wishlist intentionally does not participate in recommendations.** |
| **Owned figures increase confidence** | Figure `owned` state drives confidence tiers (`medium` / `high`) for display — separate from For You refresh triggers. |
| **Catalog series only** | Recommendations are catalog-backed `series.id` values. Custom-local rows and Home drop-imports (`drop-*`) are excluded from signals and must not be recommended. |
| **Cloud ≡ Local** | Dart and TypeScript rule engines use the same scoring, exclusion, gap-fill, and 80/20 stable/exploration semantics. Divergence is a bug. |
| **Quality over quantity** | Target **5–10** curated picks. Gap fill only when scored results fall below 5 — never pad to 10 with weak catalog filler. |
| **Readiness waits for signal depth** | For You unlocks at **3 tracked** official catalog series — enough signal for a curated first impression. |
| **Repository owns decisions** | Widgets project results for display (`visibleForYouResult`) but do not implement recommendation logic. |

**One resolver rule:** Recommendation only cares which catalog `series.id` a `ShelfSeries` represents — via [`recommendationCatalogSeriesId()`](../lib/features/collection/domain/collection_domain.dart). UI entry points (Latest, Trending, Search, Feed) are not recommendation concepts.

**What triggers a full refresh (end-to-end):** Add Series or Remove Series → `profileHash` changes → profile HTTP upload → cloud recompute → cache miss → new rail.

**What does not:** Mark owned, wishlist toggle, completion %, master complete — these may update collection UI and confidence display, but For You keeps the previous rail until tracked series change.

**Operational benefit:** Fewer profile syncs and higher cache hit rate, because figure-level churn no longer invalidates recommendations. Users see a calmer rail; the client and Cloud do less work.

---

## 2. Signal definitions

Recommendation taste is centered on **tracked series**. Owned and wishlist remain collection concepts only.

| Signal | Meaning | Recommendation use |
|--------|---------|-------------------|
| `trackedCatalogSeriesIds` / `trackedIpIds` | “I decided to collect this series / IP.” | **Exclusion**, **readiness**, **`profileHash`**, **IP affinity** (`tracked_ip` +30), cloud profile, refresh triggers |
| `ownedCatalogSeriesIds` | Progress inside tracked series | **Confidence tiers only** — not scoring, hash, or sync |
| `wishlistCatalogSeriesIds` / `wishlistIpIds` | Shopping intent inside a tracked series | **None** — wishlist intentionally does not participate in recommendations; extracted for collection/Market only |

Signals are distilled from the local collection snapshot — not a mirror of shelf state.

| Field | Source | Used for |
|--------|--------|----------|
| `trackedCatalogSeriesIds` | Eligible catalog series on shelf | Exclusion, readiness, `profileHash`, profile sync |
| `trackedIpIds` | Taxonomy IPs from all tracked catalog series | Rule-engine tracked IP scoring when recommendations are **computed** |
| `ownedCatalogSeriesIds` | Tracked series with owned figures | Confidence tiers (`medium` / `high`) — UI only |
| `profileHash` | SHA-256 of **tracked catalog series ids only** | Cache invalidation, session memo, cloud profile dedupe |

**Eligible catalog series** = resolvable via [`recommendationCatalogSeriesId`](../lib/features/collection/domain/collection_domain.dart): direct catalog template id, or catalog-backed Home save (`drop-{catalogSeriesId}` → bare id). Custom-local and legacy mock drops (`drop-drop-*`) are excluded.

**Important:** Tracking a series expresses collecting intent for that IP — an owned figure is **not** required for same-IP recommendations. Marking figures owned updates collection progress and confidence but does **not** refresh For You; only add/remove tracked series does.

**Reason copy:** `tracked_ip` → *Because you're collecting {IP}* (legacy cached `owned_ip` maps to the same copy).

---

## 3. User journey

```
Add catalog series to My Collection
        │
        ▼
trackedCatalogSeriesIds updated
        │
        ├──► Readiness unlocks (trackedCatalogSeriesCount ≥ 3)
        │
        ├──► profileHash changes → cache / memo invalidate
        │
        ├──► That series excluded everywhere (local engine, cloud, repository, UI projection)
        │
        └──► For You fetches recommendations for other catalog series (tracked IP + recency rules)
```

`trackedIpIds` are derived from every tracked series at recompute time. Adding the first series from a new IP immediately promotes other series from that IP — no owned figure required.

Marking figures **owned** later updates collection progress and confidence tiers but does not change For You refresh or IP affinity scoring.

---

## 4. Readiness and confidence

| Gate | Threshold |
|------|-----------|
| **For You visible** | `trackedCatalogSeriesCount ≥ 3` (confidence ≥ `low`) |
| **Medium confidence** | `ownedCatalogSeriesCount ≥ 3` |
| **High confidence** | `ownedCatalogSeriesCount ≥ 5` |

Readiness is a **one-way latch** (`reco_readiness_unlocked_v1` in SharedPreferences): once unlocked, the section stays eligible even if the collection is later cleared.

---

## 4b. For You visibility

The For You section is an **optional enhancement**. It must never block, crash, or degrade the Discover experience. When anything goes wrong, the correct default is to hide the section — except where loading or stale content is explicitly allowed below.

**Visibility rules:**

| State | Behavior |
|-------|----------|
| Readiness not met | Hidden |
| Catalog unavailable | Hidden |
| First loading | Skeleton |
| Refresh loading | Keep previous content |
| Empty recommendations | Hidden |
| Refresh error with previous content | Keep previous content |
| Initial error | Hidden |

**Rationale (product, not implementation):**

- **Loading ≠ error.** A short first-load skeleton (100–300ms) is normal; it should not be treated like a failure.
- **Recommendations are not real-time.** If the user already saw a valid rail and a background refresh fails, keeping the previous cards is better than making the section disappear.
- **Empty is not a placeholder.** Zero picks after filtering means hide — do not show an empty rail or error chrome.
- **Discover always wins.** No error widgets, no toasts, no red screens. Repository and provider failures degrade to hidden or empty; they never propagate into the feed.

Implementation lives in [`for_you_section.dart`](../lib/features/recommendations/widgets/for_you_section.dart) (`resolveForYouDisplayResult`, `visibleForYouResult`). Widgets project only; they do not score or fetch.

---

## 5. Result count (quality-first)

| Scored picks (after 80/20 compose) | Behavior |
|-------------------------------------|----------|
| ≥ 5 | Return scored results only (cap at 10). **No gap fill.** |
| < 5 | Gap fill with `new_in_catalog` until **5** total or catalog exhausted. |

Gap fill draws from the **newest 20** eligible catalog series (not tracked, not already scored), shuffled with a seed derived from `profileHash` + catalog fingerprint. Same profile + catalog → same gap-fill picks; profile change → picks may rotate. If the pool cannot reach 5 (e.g. IP diversity cap), older eligible series are considered in release order.

Never gap fill simply to reach 10. An empty or thin rail is acceptable when signals are weak.

---

## 5b. IP diversity (selection constraint)

After score ranking and **before** 80/20 exploration:

- Walk candidates in score order (ties → newest release).
- Keep at most **2 series per catalog IP** (`forYouMaxSeriesPerIp`).
- Skipped over-limit candidates do not reduce scores; the next highest-scoring candidate is considered.

Gap fill uses the same per-IP cap against IPs already present in the rail.

---

## 6. Pipeline exclusions (where tracked series are filtered)

1. **Local rule engine** — skip tracked ids when scoring and gap-filling.
2. **Cloud rule engine** — same; profile carries `trackedCatalogSeriesIds`.
3. **Repository** — `excludeTrackedCatalogSeries()` after HTTP / cache / local compute; stale cloud detection rejects responses containing any tracked id.
4. **UI** — `visibleForYouResult()` applies the same exclusion on display projection (e.g. during `keepPreviousData` refresh).

---

## 7. What recommendations are not

- Not based on custom-local shelf rows or drop-import series.
- Not a replacement for catalog search or market browse.
- Not driven by figure completion percentage or shelf mood.
- Not allowed to use catalog `imageKey` for market listing art (market universe stays separate).

---

## 8. Cloud profile contract

`POST /v1/profile` includes at minimum:

- `trackedCatalogSeriesIds`
- `trackedIpIds` (IP affinity snapshot at last tracked taste change)
- `profileHash` (tracked-only)

`GET /v1/for-you` returns catalog `seriesId` items with `reasonType` / optional `reasonMeta`. Client always re-applies tracked exclusion before render.

---

## 9. Change checklist

**Prerequisite:** Re-read [Core principles](#core-principles-non-negotiable) and [Closed decisions](#closed-decisions). If your change conflicts with them, stop and revise this ADR first.

When editing recommendation behavior, verify:

- [ ] `extractSignals` — `trackedIpIds` from all tracked series; owned/wishlist not in scoring
- [ ] `profileHash` — **tracked catalog series ids only**
- [ ] Wishlist does not score, hash, or sync
- [ ] Tracked IP scoring (+30); owned progress does not invalidate cache
- [ ] `computeConfidence` — readiness still `tracked ≥ 3`
- [ ] For You visibility matrix (§4b): loading skeleton, refresh keep-previous, errors/empty hide
- [ ] Gap fill only below `forYouMinimumResultCount` (5)
- [ ] IP diversity: max `forYouMaxSeriesPerIp` (2) before exploration and during gap fill
- [ ] Gap fill random pool: newest `forYouGapFillRecentPoolSize` (20), profile-seeded shuffle
- [ ] Dart `computeLocalRecommendations` and TS `computeRecommendations` stay in sync
- [ ] `excludeTrackedCatalogSeries` used in repository and UI projection
- [ ] Tests cover shelf-only tracked series (0 owned figures)
- [ ] No recommendation logic added to widgets beyond display projection

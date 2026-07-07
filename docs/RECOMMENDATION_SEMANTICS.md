# Recommendation Semantics

**Shelfy For You — product rules and signal definitions**

This document is the canonical reference for what “personalized recommendations” mean in Shelfy: which user actions count as preference signals, what must never be recommended again, and how client and Cloud Functions stay aligned.

> **Design philosophy**
>
> Recommendation refreshes only when the user's long-term collecting taste changes.
>
> Collection progress (owned figures) does not immediately trigger recommendation recomputation.
>
> However, whenever a recomputation does occur, the rule engine always uses the latest collection snapshot, including the current owned IP signals.
>
> This intentionally balances recommendation stability with recommendation quality.
>
> **Stability principle:** For You is intentionally stable. Recommendation refreshes only when the user's long-term collecting taste changes (tracked series). Collection progress and shopping intent do not immediately reshuffle recommendations.
>
> If someone asks later why marking an owned figure or updating a wishlist does not refresh For You — that is **product design**, not a bug.

For catalog vs shelf vs market boundaries, see [`.cursor/ARCHITECTURE.md`](../.cursor/ARCHITECTURE.md). For catalog identity, see [`CATALOG_ARCHITECTURE.md`](CATALOG_ARCHITECTURE.md).

**Related code:**

| Layer | Primary files |
|-------|----------------|
| Signals | [`preference_signal_extractor.dart`](../lib/features/recommendations/data/preference_signal_extractor.dart) |
| Readiness | [`recommendation_confidence.dart`](../lib/features/recommendations/domain/recommendation_confidence.dart), [`recommendation_readiness_provider.dart`](../lib/features/recommendations/application/recommendation_readiness_provider.dart) |
| Repository | [`recommendation_repository.dart`](../lib/features/recommendations/data/recommendation_repository.dart) |
| Local rule engine | [`recommendation_rule_engine.dart`](../lib/features/recommendations/data/recommendation_rule_engine.dart) |
| Cloud rule engine | [`functions/src/recommendations/ruleEngine.ts`](../functions/src/recommendations/ruleEngine.ts) |
| UI | [`for_you_section.dart`](../lib/features/recommendations/widgets/for_you_section.dart) |

---

## 1. Product rules (non-negotiable)

| Rule | Meaning |
|------|---------|
| **Add Series = explicit interest** | Adding a catalog series to **My Collection** is the user’s first deliberate preference signal. No owned figure is required for personalization to begin. |
| **Tracked series are never recommended** | Any catalog series currently on the user’s shelf must **never** appear in For You again — regardless of figure ownership, wishlist, or completion. |
| **Tracked series drive refresh** | `profileHash`, cache invalidation, and cloud profile sync react to **tracked catalog series** changes only — add/remove series is a taste change; owned figures and wishlist are not. |
| **Owned figures inform scoring, not refresh** | Figure `owned` state still boosts **owned IP** ranking (+30) when recommendations are computed, but does not reshuffle For You on progress alone. |
| **Wishlist is not taste** | Wishlist figure state does not score, hash, sync, or refresh recommendations — it remains for collection and Market. |
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

Three user signals — only **tracked series** represent collecting taste for For You refresh.

| Signal | Meaning | Recommendation use |
|--------|---------|-------------------|
| `trackedCatalogSeriesIds` | “I decided to collect this series.” | **Exclusion**, **readiness**, **`profileHash`**, cloud profile, refresh triggers |
| `ownedCatalogSeriesIds` / `ownedIpIds` | Progress inside tracked series | **Scoring only** (`owned_ip` +30) at compute time — **not** in `profileHash` |
| `wishlistCatalogSeriesIds` / `wishlistIpIds` | Shopping intent inside a tracked series | **None** — extracted for collection/Market; not uploaded for recommendations |

Signals are distilled from the local collection snapshot — not a mirror of shelf state.

| Field | Source | Used for |
|--------|--------|----------|
| `trackedCatalogSeriesIds` | Eligible catalog series on shelf | Exclusion, readiness, `profileHash`, profile sync |
| `ownedIpIds` | IPs with ≥1 owned figure on tracked series | Rule-engine owned IP scoring when recommendations are **computed** |
| `ownedCatalogSeriesIds` | Tracked series with owned figures | Confidence tiers (`medium` / `high`) — UI only |
| `profileHash` | SHA-256 of **tracked catalog series ids only** | Cache invalidation, session memo, cloud profile dedupe |

**Eligible catalog series** = resolvable via [`recommendationCatalogSeriesId`](../lib/features/collection/domain/collection_domain.dart): direct catalog template id, or catalog-backed Home save (`drop-{catalogSeriesId}` → bare id). Custom-local and legacy mock drops (`drop-drop-*`) are excluded.

**Important:** “On My Collection” (tracked) and “has owned figures” (owned) are **different concepts**. A user can track a series with zero owned figures; it is still excluded from For You. Marking another figure owned does **not** refresh For You — only add/remove tracked series does.

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
        └──► For You fetches recommendations for other catalog series (IP + recency rules)
```

Marking figures **owned** later deepens IP signals and confidence but does not change the exclusion rule for an already-tracked series.

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
- `ownedIpIds` (scoring snapshot at last tracked taste change)
- `profileHash` (tracked-only)

`GET /v1/for-you` returns catalog `seriesId` items with `reasonType` / optional `reasonMeta`. Client always re-applies tracked exclusion before render.

---

## 9. Change checklist

When editing recommendation behavior, verify:

- [ ] `extractSignals` — tracked vs owned vs wishlist still distinct
- [ ] `profileHash` — **tracked catalog series ids only**
- [ ] Wishlist does not score, hash, or sync
- [ ] Owned IP scoring preserved; owned progress does not invalidate cache
- [ ] `computeConfidence` — readiness still `tracked ≥ 3`
- [ ] For You visibility matrix (§4b): loading skeleton, refresh keep-previous, errors/empty hide
- [ ] Gap fill only below `forYouMinimumResultCount` (5)
- [ ] IP diversity: max `forYouMaxSeriesPerIp` (2) before exploration and during gap fill
- [ ] Gap fill random pool: newest `forYouGapFillRecentPoolSize` (20), profile-seeded shuffle
- [ ] Dart `computeLocalRecommendations` and TS `computeRecommendations` stay in sync
- [ ] `excludeTrackedCatalogSeries` used in repository and UI projection
- [ ] Tests cover shelf-only tracked series (0 owned figures)
- [ ] No recommendation logic added to widgets beyond display projection

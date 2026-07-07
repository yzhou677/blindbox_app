# Recommendation Semantics

**Shelfy For You — product rules and signal definitions**

This document is the canonical reference for what “personalized recommendations” mean in Shelfy: which user actions count as preference signals, what must never be recommended again, and how client and Cloud Functions stay aligned.

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
| **Owned figures increase confidence** | Figure `owned` state drives IP affinity scoring and confidence tiers (`medium` / `high`). It is **not** the gate for unlocking For You or excluding series. |
| **Catalog series only** | Recommendations are catalog-backed `series.id` values. Custom-local rows and Home drop-imports (`drop-*`) are excluded from signals and must not be recommended. |
| **Cloud ≡ Local** | Dart and TypeScript rule engines use the same scoring, exclusion, gap-fill, and 80/20 stable/exploration semantics. Divergence is a bug. |
| **Quality over quantity** | Target **5–10** curated picks. Gap fill only when scored results fall below 5 — never pad to 10 with weak catalog filler. |
| **Readiness waits for signal depth** | For You unlocks at **3 tracked** official catalog series — enough signal for a curated first impression. |
| **Repository owns decisions** | Widgets project results for display (`visibleForYouResult`) but do not implement recommendation logic. |

**One resolver rule:** Recommendation only cares which catalog `series.id` a `ShelfSeries` represents — via [`recommendationCatalogSeriesId()`](../lib/features/collection/domain/collection_domain.dart). UI entry points (Latest, Trending, Search, Feed) are not recommendation concepts.

---

## 2. Signal definitions

Signals are distilled from the local collection snapshot — not a mirror of shelf state.

| Signal | Source | Used for |
|--------|--------|----------|
| `trackedCatalogSeriesIds` | Eligible catalog series on shelf (`catalogTemplateId` set; not custom; not `drop-*`) | **Exclusion** from For You; **readiness** unlock; `profileHash`; cloud profile upload |
| `ownedCatalogSeriesIds` | Shelf series with ≥1 figure in `FigureCollectionState.owned` | IP affinity scoring (`ownedIpIds`); confidence `medium` / `high` |
| `wishlistCatalogSeriesIds` | Shelf series with wishlist figures and no owned figures | Wishlist IP affinity scoring |
| `ownedIpIds` / `wishlistIpIds` | Taxonomy IP ids from qualifying shelf rows | Rule-engine IP match reasons |
| `profileHash` | SHA-256 of tracked + owned + wishlist series sets and IP sets | Cache invalidation, session memo, cloud profile dedupe |

**Eligible catalog series** = resolvable via [`recommendationCatalogSeriesId`](../lib/features/collection/domain/collection_domain.dart): direct catalog template id, or catalog-backed Home save (`drop-{catalogSeriesId}` → bare id). Custom-local and legacy mock drops (`drop-drop-*`) are excluded.

**Important:** “On My Collection” (tracked) and “has owned figures” (owned) are **different concepts**. A user can track a series with zero owned figures; it is still excluded from For You.

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
- `ownedCatalogSeriesIds`, `wishlistCatalogSeriesIds`
- `ownedIpIds`, `wishlistIpIds`
- `profileHash`

`GET /v1/for-you` returns catalog `seriesId` items with `reasonType` / optional `reasonMeta`. Client always re-applies tracked exclusion before render.

---

## 9. Change checklist

When editing recommendation behavior, verify:

- [ ] `extractSignals` — tracked vs owned vs wishlist still distinct
- [ ] `computeConfidence` — readiness still `tracked ≥ 3`
- [ ] Gap fill only below `forYouMinimumResultCount` (5)
- [ ] IP diversity: max `forYouMaxSeriesPerIp` (2) before exploration and during gap fill
- [ ] Gap fill random pool: newest `forYouGapFillRecentPoolSize` (20), profile-seeded shuffle
- [ ] Dart `computeLocalRecommendations` and TS `computeRecommendations` stay in sync
- [ ] `excludeTrackedCatalogSeries` used in repository and UI projection
- [ ] Tests cover shelf-only tracked series (0 owned figures)
- [ ] No recommendation logic added to widgets beyond display projection

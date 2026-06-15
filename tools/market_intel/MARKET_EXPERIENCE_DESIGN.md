# Sprint 3A — Market Experience Design Audit

> **Date:** 2026-06-15  
> **Type:** Design only — no Flutter code, no routes, no widgets implemented.  
> **Scope:** Audit current market-related UX across all four main surfaces, then propose the next evolution of the Market experience through wireframes, a phased roadmap, and a final recommendation.

---

## Background

The Discover figure gallery now surfaces a lightweight market accordion:

```
▶ Market Information
  (tap)
▼ Market Information
  Market Value · $42 · 18 sales
  Range  $38–$48
  Updated 1h ago
```

This is intentionally minimal — catalog browsing, not market analysis. The next phase is improving the Market experience itself.

---

## Part 1 — Current State Audit

### The two-universe problem

Two separate data concepts carry the word "snapshot" in this codebase:

| Concept | Model | Source | Used in |
|---------|-------|--------|---------|
| Live listing aggregate | `CollectibleMarketSnapshot` | eBay gateway (asking prices) | Market Browse, Market Detail |
| Sold-data intelligence | `MarketSnapshot` | Firestore (admin-written, sold prices) | Discover gallery accordion only |

These two universes have never been shown side-by-side. A user in Market Detail sees an asking price of $48 with no way to know whether that is a good deal, a fair price, or 14% above what the figure actually sells for.

---

### 1A — Discover (Home + Gallery)

**What exists:**
- Home feed cards: series art, series name, brand, IP, figure count, save CTA
- Catalog browse: search, series list
- Drop detail: series hero, brand/IP meta, figure lineup strip
- Figure gallery: figure art, name, `▶ Market Information` accordion, series · rarity footer

**What is absent:**
- Prices on home cards (intentional — Discover is catalog-first)
- Release dates on home feed cards (field exists in `SeriesRelease`, not shown)
- Any link from the gallery to Market tab listings for that figure
- Loading or error feedback when gallery market data is unavailable (section hides silently)

**Assessment:** Discover is well-scoped. The gallery accordion is the right level of detail for catalog context. The main gap is the missing cross-link to Market listings when a user wants to act on the price they just saw.

---

### 1B — Collection

**What exists:**
- Summary strip: owned figure count, wishlist count
- Editorial mood copy, collector archetype reveal, memory/relationship whisper
- Series cards: cover art, progress bar, progress voice, completion atmosphere
- Insights entry point → `/collection/insights` (route exists)

**What is absent:**
- Any market or monetary signal — no estimated value per series, no total shelf value
- The summary strip (`In collection · Wishlist`) tells nothing about what the collection is worth
- `/collection/insights` screen destination not confirmed as implemented

**Assessment:** Collection is emotionally rich but financially blank. Users who are also buyers have no way to understand the value they have assembled. Collection Insights is the right venue for this — it is already in the router.

---

### 1C — Market Browse

**What exists:**
- Live eBay asking prices per snapshot (aggregated from live gateway or fixtures)
- Filter chips (brand, IP), chasers rail, price sort, signal chips (Trending / Hard to find / Secret)
- Card mood copy, relationship hint
- Data source notice (eBay disclosure)

**What is absent:**
- Sold-data `MarketSnapshot` — no market value estimate, no sold range, no confidence, no trend
- Asking-vs-sold delta per card (the most actionable single number for a buyer)
- No inline signal distinguishing a listing priced above vs below market

**Assessment:** Browse shows what is for sale at what asking price. Without sold comps, it is half a picture. A buyer cannot assess value or negotiate from this screen alone. The intel data already exists in Firestore — it just is not surfaced here.

---

### 1D — Market Listing Detail

**What exists:**
- Listing photo, title, series + figure identity, brand/IP
- Signal chips (max 1: Secret / Hard to find / Trending)
- Fact rows: condition, quantity, seller, listed date, shipping
- Price + optional % change
- "View on eBay" CTA

**What is absent:**
- `MarketSnapshot` sold intel entirely: no market value estimate, no sold range, no confidence, no trend, no freshness timestamp
- The asking-vs-market delta is never computed or shown
- No series estimate fallback when figure snapshot is missing

**This is the single most critical gap.** The user is at maximum purchase intent — one tap from spending money — with no sold-comps context whatsoever.

---

### 1E — Architecture gap summary

```
┌─────────────────────────────────────────────────────────┐
│  Asking price universe (live eBay)                      │
│                                                         │
│  MarketListing ──► CollectibleMarketSnapshot            │
│      │                    │                             │
│      ▼                    ▼                             │
│  MarketDetailScreen   MarketScreen (Browse)             │
│                                                         │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│  Sold-data intelligence (Firestore)                     │
│                                                         │
│  Firestore market_snapshots                             │
│      │                                                  │
│      ▼                                                  │
│  MarketSnapshot ──► marketSnapshotProvider              │
│      │                    │                             │
│      ▼                    ▼                             │
│  MarketSnapshotBadge  Discover gallery accordion        │
│  (dev screen only)    (production)                      │
│                                                         │
└─────────────────────────────────────────────────────────┘

         ↑ These two universes are never connected. ↑
```

**`MarketTrend`** (`rising` / `falling` / `stable` / `unknown`) is parsed from Firestore and stored on every `MarketSnapshot` but has never been rendered in any production surface.

---

## Part 2 — Market Detail Vision

### Concept

When a user opens a Market listing, they are evaluating a purchase. The screen should answer three questions:

1. What is this listing asking? (already answered — price, seller, shipping)
2. What does this figure actually sell for? (**currently unanswered**)
3. Is this listing a good deal? (**currently unanswered**)

The solution is a "Market Insights" section appended below the buy CTA, drawing from `MarketSnapshot`.

### Wireframe

```
┌─────────────────────────────────┐
│  ←  THE MONSTERS Big Into...    │
├─────────────────────────────────┤
│                                 │
│        [listing photo]          │
│                                 │
│  Big Into Energy Vinyl          │
│  Plush Pendant                  │
│  Luck  ·  Regular               │
│                                 │
│  [ Recently active ] [Trending] │
│                                 │
│  Condition:    Near Mint        │
│  Seller:       collectrz99      │
│  Shipping:     Free             │
│  Listed:       Jun 12, 2026     │
│                                 │
│  $48.00                         │
│  ▲  +14% above market value     │  ← computed delta
│                                 │
│ ┌─────────────────────────────┐ │
│ │       [ View on eBay ]      │ │
│ └─────────────────────────────┘ │
│                                 │
│  ─────  Market Insights  ─────  │
│                                 │
│  Market Value     $42           │
│  18 recent sales                │
│  Range    $38 – $48             │
│  ↑ Trending                     │
│  Updated 1h ago                 │
│                                 │
└─────────────────────────────────┘
```

**Series fallback variant** (no figure-level snapshot available):

```
│  ─────  Market Insights  ─────  │
│                                 │
│  Series Estimate   ~$37         │
│  4 recent sales*                │
│  Range   $30 – $45              │
│  Updated 1h ago                 │
│                                 │
│  * Based on series average.     │
│    Figure-level data pending.   │
└─────────────────────────────────┘
```

Never show nothing. A series estimate with a caveat is more useful than a blank section.

### Data sources

| Element | Source |
|---------|--------|
| Photo, title, seller, condition, shipping, price, CTA | `MarketListing` / `marketListingDetailProvider` (eBay) |
| Market Value, sales, range, updated | `MarketSnapshot` via `marketSnapshotProvider(figureId)` (Firestore) |
| Trend arrow (↑ / ↓ / →) | `MarketSnapshot.trend` (currently unused) |
| "▲ +14% above market" | Computed: `(listing.currentPriceUsd - snapshot.estimatedValueUsd) / snapshot.estimatedValueUsd` |
| Series fallback | `marketSnapshotProvider` series fallback (already implemented) |

### What should NOT appear here

- Bid count or watcher count (sparse and unreliable in preview/fixture data)
- Historical price chart (Phase 4 — requires schema extension)
- Catalog description copy (Market is a buying context, not a catalog reference)
- "Add to shelf" button (Market universe is browse-only per architecture; shelf add lives in Discover/Collection)

### Asking-vs-market delta copy guide

| Condition | Delta copy | Color hint |
|-----------|-----------|-----------|
| Price > 15% above market | `▲ +N% above market value` | amber / warning |
| Price within ±15% | `✓ Near market value` | neutral |
| Price > 15% below market | `▼ –N% below market value` | positive |
| No snapshot | *(delta row hidden)* | — |

---

## Part 3 — Collection Value Vision

### Concept

The Collection Insights screen (`/collection/insights`) exists in the router but its implementation is unconfirmed. This is the natural home for market-value-based collection analytics.

The experience should feel like a collector's portfolio overview — not a finance dashboard. Calm presentation, editorial tone, imagery-first.

### MVP wireframe (Phase 2)

```
┌─────────────────────────────────┐
│  ←  Collection Insights         │
├─────────────────────────────────┤
│                                 │
│  127 figures on your shelf      │
│                                 │
│  Estimated Value                │
│  $4,382                         │
│                                 │
│  Coverage                       │
│  93 valued  ·  34 no data       │
│  ████████████░░░░  73%          │
│                                 │
│  ─────  Most Valuable  ───────  │
│                                 │
│  1  [img]  Secret Figure  $210  │
│  2  [img]  Luck            $42  │
│  3  [img]  Hope            $37  │
│  4  [img]  Crybaby         $35  │
│  5  [img]  Lila            $31  │
│                                 │
└─────────────────────────────────┘
```

### Post-MVP wireframe (Phase 3 additions)

```
┌─────────────────────────────────┐
│  ←  Collection Insights         │
├─────────────────────────────────┤
│   [same header as MVP above]    │
│                                 │
│  ─────  By Series  ───────────  │
│                                 │
│  Big Into Energy       $220     │
│    ↑ +12% this month            │
│  Exciting Macaron      $183     │
│    →  Stable                    │
│  Treehouse Theatre      $94     │
│    ↓ –5% this month             │
│                                 │
│  ─────  Wishlist Value  ──────  │
│                                 │
│  12 wishlist figures            │
│  Estimated  ~$318               │
│                                 │
└─────────────────────────────────┘
```

### What belongs in MVP

| Item | Rationale |
|------|-----------|
| Total figure count | Already available from `collectionNotifierProvider` |
| Estimated total value | Sum of `estimatedValueUsd` for owned figures with snapshots |
| Coverage % | Figures with a snapshot / total owned figures |
| Top 5 most valuable owned figures | Answers the "what is my most valuable piece?" question directly |

### What belongs post-MVP

| Item | Rationale |
|------|-----------|
| Per-series value breakdown | Useful but requires more UI; do MVP first to validate interest |
| Trend arrows per series | `MarketTrend` exists in domain, never surfaced; needs series-level snapshot |
| Historical value chart | Requires snapshot history subcollection (schema extension) |
| Wishlist value estimate | Low data completeness; misleading if coverage is sparse |

### Implementation path (no schema changes needed)

`marketSnapshotProvider(figureId)` already handles figure → series fallback. A `collectionValueProvider` can:

1. Read `collectionNotifierProvider` → list of owned figure ids
2. Fan out to `marketSnapshotProvider` for each id (Riverpod family, concurrent)
3. Aggregate: sum values, count coverage, sort by value descending

No Firestore schema changes required for MVP. The challenge is N parallel provider reads — acceptable for a dedicated insights screen that is not in the hot path.

---

## Part 4 — Screen Mockups

### A. Discover Figure Gallery (current state — reference)

```
┌─────────────────────────────────┐
│  ×                    1 of 7    │
│  •  •  •  •  •  •  •            │
│                                 │
│                                 │
│         [figure art]            │
│                                 │
│                                 │
│            Luck                 │
│    ▶  Market Information        │  ← disclosure row, tap to expand
│                                 │
│  THE MONSTERS Big Into Energy   │
│  Vinyl Plush Pendant · Regular  │
│                                 │
│ ┌───────────────────────────┐   │
│ │       + Add to shelf      │   │
│ └───────────────────────────┘   │
└─────────────────────────────────┘

Expanded state:

│            Luck                 │
│    ▼  Market Information        │
│    Market Value · $42 · 18 sales│
│    Range  $38–$48               │
│    Updated 1h ago               │
```

---

### B. Market Listing Detail (proposed — Phase 1 target)

```
┌─────────────────────────────────┐
│  ←  THE MONSTERS Big Into...    │
├─────────────────────────────────┤
│                                 │
│        [listing photo]          │
│                                 │
│  Big Into Energy Vinyl          │
│  Luck  ·  Regular               │
│                                 │
│  [ Trending ]  [ Hard to find ] │
│                                 │
│  Condition:    Near Mint        │
│  Seller:       collectrz99      │
│  Shipping:     Free             │
│                                 │
│  $48.00                         │
│  ▲  +14% above market value     │
│                                 │
│ ┌─────────────────────────────┐ │
│ │       [ View on eBay ]      │ │
│ └─────────────────────────────┘ │
│                                 │
│  ─────  Market Insights  ─────  │
│                                 │
│  Market Value     $42           │
│  18 recent sales                │
│  Range    $38 – $48             │
│  ↑ Trending  ·  Updated 1h ago  │
│                                 │
│  ⚠  This listing is 14%         │
│     above typical market value. │
│                                 │
└─────────────────────────────────┘
```

---

### C. Collection Insights (proposed — Phase 2 target)

```
┌─────────────────────────────────┐
│  ←  Collection Insights         │
├─────────────────────────────────┤
│                                 │
│     127 figures on your shelf   │
│                                 │
│     Estimated Value             │
│     $4,382                      │
│                                 │
│     Coverage  73%               │
│     ████████████░░░░            │
│     93 valued  ·  34 no data    │
│                                 │
│  ─────  Most Valuable  ───────  │
│                                 │
│  1  [img]  Secret Figure  $210  │
│  2  [img]  Luck            $42  │
│  3  [img]  Hope            $37  │
│  4  [img]  Crybaby         $35  │
│  5  [img]  Lila            $31  │
│                                 │
└─────────────────────────────────┘
```

---

### D. Market Browse with Intel Overlay (proposed — Phase 3 target)

```
┌─────────────────────────────────┐
│  Market                    🔍   │
│  [ Search figures... ]          │
├─────────────────────────────────┤
│  [Chasers rail — horizontal]    │
│  ─────────────────────────────  │
│  Pop Mart   Miniso   Toycity    │  ← brand chips
│  ─────────────────────────────  │
│  Collectibles            ↕ $   │
│                                 │
│  ┌─────────────────────────┐   │
│  │  [img]   Luck           │   │
│  │          $48 · 3 listed │   │
│  │          Est. value $42 │   │  ← MarketSnapshot intel line
│  │          ▲ Above market │   │  ← computed signal
│  └─────────────────────────┘   │
│                                 │
│  ┌─────────────────────────┐   │
│  │  [img]   Hope           │   │
│  │          $35 · 7 listed │   │
│  │          Est. value $37 │   │
│  │          ✓ Near market  │   │
│  └─────────────────────────┘   │
│                                 │
│  ┌─────────────────────────┐   │
│  │  [img]   Serenity       │   │
│  │          $29 · 2 listed │   │
│  │          (no intel)     │   │  ← graceful degradation
│  └─────────────────────────┘   │
│                                 │
└─────────────────────────────────┘
```

Note on Browse intel overlay: N parallel Firestore reads per browse page is a performance concern. Prefer lazy-load (only resolve intel for visible cards) or a denormalized browse index. This is why Browse Overlay is Phase 3, not Phase 1.

---

## Part 5 — Recommended Roadmap

### Phase 1 — Market Detail Insights

**Effort:** ~1 day  
**Risk:** Low  
**Value:** Very high (purchase-intent intercept)

Changes:
- Add "Market Insights" section to `MarketDetailScreen` below the CTA
- Wire `marketSnapshotProvider(figureId)` — figure id resolved from `MarketListing.collectible` or catalog match
- Reuse `MarketSnapshotBadge` or inline format from `market_snapshot_format.dart`
- Compute and show asking-vs-market delta
- Handle series fallback (already works in provider)
- Handle null gracefully (hide section)

Files touched:
- `lib/features/market/market_detail_screen.dart`
- `lib/features/market_intel/widgets/market_snapshot_badge.dart` (possible light edit for context)
- `test/market_detail_market_insights_test.dart` (new)

**Why first:** Zero infrastructure cost. The data, the widget, and the provider all exist. The user at purchase intent is the highest-value moment to add market context.

**Implemented (Sprint 3C / 3C.1 / 3D):** Market Detail shows price delta + **Market Insights >** navigation row; full intelligence lives on `/market/insights`. Current UI copy, layout, offline behavior, and screenshots: see [`MARKET_DETAIL_INSIGHTS_DESIGN.md`](MARKET_DETAIL_INSIGHTS_DESIGN.md).

---

### Phase 2 — Collection Value

**Effort:** ~2 days  
**Risk:** Low–Medium (N async providers; test coverage important)  
**Value:** High (emotional + informational resonance for serious collectors)

Changes:
- Confirm or implement `CollectionInsightsScreen` at `/collection/insights`
- Add `collectionValueProvider` (fan-out over owned figure ids → aggregate)
- Total estimated value, coverage %, top-5 list
- Entry point from collection summary strip (tap → insights)

Files touched:
- `lib/features/collection/presentation/collection_insights_screen.dart` (create or confirm)
- `lib/features/collection/application/collection_value_providers.dart` (new)
- `test/collection_value_provider_test.dart` (new)

**Why second:** No schema changes. Route already exists. Aggregation logic is pure Dart over existing providers. Delivers a "wow" moment for users who have been collecting for a while.

---

### Phase 3 — Browse Intel Overlay

**Effort:** ~3 days (including perf validation)  
**Risk:** Medium (performance; N Firestore reads per browse page)  
**Value:** Medium (improves browse quality; increases session time)

Changes:
- Add optional intel line to `CollectibleMarketCard`
- Lazy-load: only resolve `marketSnapshotProvider` for cards currently in viewport
- Add asking-vs-market signal chip

**Why third:** Requires performance work. Browse has many cards; naively adding N providers per page could create Firestore read spikes. The impact per-user is also lower than Phase 1 (exploring vs buying).

---

### Phase 4 — Trend, History, Availability

**Effort:** 1–2 weeks  
**Risk:** High (schema extension required)  
**Value:** High for power users; low for casual collectors

Changes:
- Surface `MarketTrend` on Market Detail and Collection Insights (field exists, never shown)
- Price history chart (new snapshot history subcollection in Firestore)
- Availability metric (active listing count vs 30-day average)
- Wishlist estimated value on Collection Insights

**Why last:** All of these require either schema work, pipeline work, or both. They are the right endgame for a serious market intelligence product but should not block the earlier phases that can ship on existing infrastructure.

---

### Roadmap summary

| Phase | Feature | Effort | Infrastructure needed |
|-------|---------|--------|-----------------------|
| 1 | Market Detail Insights | ~1 day | Nothing new |
| 2 | Collection Value | ~2 days | New provider + screen |
| 3 | Browse Intel Overlay | ~3 days | Perf work, lazy load |
| 4 | Trend + History | 1–2 weeks | Firestore schema extension |

---

## Part 6 — Final Recommendation

**The single highest-value next Market feature is Phase 1: Market Insights on the Listing Detail screen.**

### Why

The user who has navigated to `/market/listing/:id` has already:
1. Browsed the Market feed
2. Filtered or searched to a figure they want
3. Opened a specific listing
4. Is one tap from "View on eBay"

This is the highest purchase-intent moment in the entire app. At this moment, the app shows the user an asking price — but nothing about whether that price is fair, high, or a steal.

Adding "Market Value $42 · 18 recent sales · Range $38–$48 · ↑ Trending" below the CTA directly answers the question the user is silently asking: *Is this worth buying at this price?*

### Why not the others first

- **Collection Value** is emotionally satisfying but does not intercept an active decision.
- **Browse Intel Overlay** reaches users who are still exploring, not committing.
- **Trend / History** requires infrastructure work before it can ship.

### What makes Phase 1 fast

All the ingredients already exist:
- `marketSnapshotProvider(figureId)` — figure → series fallback, live Firestore read
- `MarketSnapshotBadge` — renders value, sales, range, freshness, series chip
- `market_snapshot_format.dart` — all formatting helpers
- `MarketDetailScreen` — just needs a new section below the CTA

The only new work is: resolve the figure id from the listing, add the section, compute the delta, write tests. Estimated one engineer-day.

### The compounding benefit

Once Phase 1 ships, the app has proven that the two universes (asking prices + sold intel) can coexist in a single view. That unlocks user trust, sets the expectation for intel data, and makes Phases 2 and 3 feel like natural extensions rather than new concepts.

---

## Appendix — Reusable components inventory

| Component | Location | Current use | Proposed reuse |
|-----------|----------|-------------|----------------|
| `MarketSnapshotBadge` | `lib/features/market_intel/widgets/market_snapshot_badge.dart` | Dev screen only | Market Detail Insights section |
| `marketSnapshotProvider` | `lib/features/market_intel/application/market_snapshot_providers.dart` | Discover gallery | Market Detail, Collection Value, Browse overlay |
| `formatMarketSnapshotDiscoverSummaryLine` | `market_snapshot_format.dart` | Gallery accordion | Market Detail summary line |
| `formatMarketSnapshotDiscoverPriceRangeValue` | `market_snapshot_format.dart` | Gallery expand panel | Market Insights section |
| `formatMarketSnapshotUpdatedLine` | `market_snapshot_format.dart` | Gallery expand panel | Market Insights, Collection Insights |
| `MarketTrend` | `lib/features/market_intel/domain/market_snapshot.dart` | Parsed, never rendered | Phase 1 trend arrow, Phase 3 history |
| `CollectionInsightsScreen` route | `lib/core/router/app_router.dart` | Route exists | Phase 2 — populate screen |
| `collectionNotifierProvider` | `lib/features/collection/application/` | Collection shelf | Phase 2 — owned figure id source |

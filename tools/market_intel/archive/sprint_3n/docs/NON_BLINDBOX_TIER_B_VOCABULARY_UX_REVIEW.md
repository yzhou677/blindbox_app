# Sprint 3N-E.1 — Non-Blind-Box Tier B Vocabulary Review & Final UX Proposal

**Date:** 2026-06-16  
**Type:** UX / language review only — **no code, no implementation.**  
**Inputs:** Sprint 3N-E plan, Sprint 3I trust vocabulary, `market_snapshot_format.dart`, product principles (calm, collector-native, trust > coverage).

---

## Executive recommendation

Adopt **Market Estimate** (not **Estimated Value**) as the non-blind-box Tier B value label. Pair it with **market estimate** delta phrasing and **About this market estimate** as the info sheet title.

This keeps a clear three-term system aligned with existing **Market Value** / **Series Avg.** vocabulary, avoids implying Tier B non-blind-box is a “guess” while Tier A is “real,” and does **not** require a new `market_snapshot_vocabulary.dart` file.

---

## Part 1 — Naming review

### Options evaluated

| Option | Clarity | Trust | Consistency w/ Market Value | AI/arbitrary risk | Mobile |
|--------|---------|-------|----------------------------|-------------------|--------|
| **Market Estimate** | High — marketplace-grounded | High — “estimate” signals tier without abandoning “market” | **Strong** — shared *Market* prefix, distinct noun | Low | **Good** (~15 chars) |
| Estimated Value | Medium — “value” overlaps Tier A | **Risk** — reads weaker than Market Value | Weak — different grammar (adj + noun) | Medium — generic “estimated” | Good |
| Estimated Market Value | High | Medium-high | Strong but redundant | Low | **Poor** — long for Discover row |
| Market-Based Estimate | Medium | Medium | Moderate | **High** — spreadsheet / policy tone | Poor |
| Recent Sales Estimate | High (accurate) | High | Moderate | Low | Poor — long; wrong when sales are series-scoped |

### Trust problem: Market Value vs Estimated Value

Collectors will reasonably read:

- **Market Value** → “this figure’s real recent market price”
- **Estimated Value** → “a softer guess”

That **is** a trust problem — not because Tier B should pretend to be Tier A, but because **Estimated Value** drops the *market* anchor that justifies the number (eBay sold activity). Users may think Shelfy is inferring MSRP or interpolating, rather than showing a marketplace-derived figure with limited specificity.

Tier B **should** feel less definitive than Tier A. The right signal is **method + scope**, not **confidence collapse**:

| Tier | What to communicate |
|------|---------------------|
| A | Figure-specific market value |
| B blind-box | Series pool average |
| B non-blind-box | Product-level market estimate (not figure-specific, not a blind-box average) |

**Market Estimate** communicates “market-derived, but not figure-precise” without sounding like random guesswork.

### Winner — value label (primary)

**Market Estimate**

Use everywhere the 3N-E plan proposed **Estimated Value**:

- Discover summary head: `Market Estimate · $1,240 · 6 sales`
- Insights value column label
- Badge heading (dev): `Market Estimate` (drop “Series Avg. Value” pattern; use plain label + optional chip)

### Winner — banner / chip (secondary)

| Role | Blind-box Tier B (unchanged) | Non-blind-box Tier B |
|------|------------------------------|----------------------|
| Insights banner | Series-Level Estimate | **Market Estimate** |
| Badge chip | ≈ Series Estimate | **≈ Market Estimate** |

Using **Market Estimate** for both banner and value column on standalone Tier B is intentional: one term, one concept. Banner can be omitted if redundant with column label (implementation detail).

---

## Part 2 — Delta line wording

### Tier A reference (keep)

| Direction | Copy |
|-----------|------|
| Above | `▲ N% above market` |
| Below | `Below market` |
| Near | `≈ At market` |

### Blind-box Tier B (keep)

| Direction | Copy |
|-----------|------|
| Above | `▲ N% above series avg.` |
| Below | `Below series avg.` |
| Near | `≈ Near series avg.` |

### Non-blind-box Tier B — options

| Option | Collector feel | Verdict |
|--------|----------------|---------|
| above / below / near **estimate** | Too vague | Reject |
| above / below / near **estimated value** | Noun-heavy, financial | Reject |
| above / below / near **market estimate** | Parallel to “above market” | **Winner** |
| above / below / near **recent sales estimate** | Accurate but clinical | Reject for UI (ok in sheet body) |

### Final delta wording — non-blind-box Tier B

| Direction | Final copy |
|-----------|------------|
| Above (>5%) | `▲ N% above market estimate` |
| Below (<−5%) | `Below market estimate` |
| Near (±5%) | `≈ Near market estimate` |

**Rationale:** Mirrors Tier A (`above market`) and blind-box Tier B (`above series avg.`) — **[direction] + [reference noun phrase]**. Reads like a marketplace comparison, not a spreadsheet. No ✓ on below (consistent with blind-box Tier B).

---

## Part 3 — Info sheet title

### Options

| Title | Answers “what am I looking at?” | Verdict |
|-------|----------------------------------|---------|
| About this estimate | Weak — any estimate | Reject |
| About market estimates | General education | Ok for shelf; too broad for listing ⓘ |
| About estimated market value | Financial, long | Reject |
| Understanding this estimate | Tutorial tone | Reject |
| **About this market estimate** | **Ties to on-screen label + listing context** | **Winner** |

### Final sheet title

**About this market estimate**

Semantics label: same string.

### Body copy direction (for implementation sprint, not this review)

Standalone sheet should **not** reuse blind-box paragraphs (“Within a blind-box series…”). Proposed body theme:

1. This comparison uses a **market estimate** for this product when sales for this exact figure are limited.
2. For standalone items (MEGA, statues, etc.), the estimate reflects **marketplace activity for this product**, not an average across blind-box pulls.
3. Use as a reference, not a guaranteed price.

Blind-box sheet: **unchanged**.

---

## Part 4 — Long-term vocabulary system

### Recommended three-term system

| Tier | Condition | Value label | Delta reference | Disclosure |
|------|-----------|-------------|-----------------|------------|
| **A** | Figure snapshot | **Market Value** | market | — |
| **B1** | Series estimate + `isBlindBox` | **Series Avg.** | series avg. | About series average pricing |
| **B2** | Series estimate + `!isBlindBox` | **Market Estimate** | market estimate | About this market estimate |

### Why not Estimated Value

- Breaks the **Market** family established in Sprint 3I.
- Creates a false Tier A > Tier B2 trust cliff (“Value” vs “Estimated Value”).
- **Market Estimate** correctly positions B2 between A (figure-specific value) and B1 (series pool average).

### Visual / trust tier (unchanged from 3I)

- Tier A: full weight, Market Insights available.
- Tier B: tertiary accent, `~` on shelf, no Market Insights nav (policy unchanged).
- Wording fork does not change trust mechanics — only semantics.

---

## Part 5 — Implementation simplification

### Is `market_snapshot_vocabulary.dart` needed?

**No.** Prefer extending the existing formatter layer.

### Sufficient architecture

```
MarketSnapshot + CatalogBundleCache.lookup(seriesId).isBlindBox
  → market_snapshot_format.dart branches on (isSeriesEstimate, isBlindBox)
  → widgets unchanged except passing snapshot (already do)
```

Concrete approach:

1. Add **one** catalog helper in `market_snapshot_format.dart` (or adjacent private function):

   `bool resolveIsBlindBoxSeries(String seriesId)` → reads `CatalogBundleCache.current`; default `true` if unknown (preserves blind-box copy).

2. Extend formatters to accept `MarketSnapshot` (or add optional `isBlindBoxSeries` resolved once at widget boundary).

3. Add label/delta **private functions** inside `market_snapshot_format.dart`:

   `String snapshotValueLabel(MarketSnapshot s)`  
   `String? formatListingPriceDeltaLine(..., MarketSnapshot snapshot)` — resolves mode internally.

4. Parameterize `MarketSeriesAverageInfoSheet(isBlindBoxSeries: bool)` for title + body only.

**Avoid:** new enum file, new abstraction layer, or duplicating lookup in every widget.

**When a separate file would be justified:** if shelf info sheet, collection copy, and market formatters all need shared vocabulary in 5+ modules — not the case today (2 modules + formatters).

---

## Deliverable 1 — Final vocabulary table

| Surface | Tier A | Tier B blind-box | Tier B non-blind-box |
|---------|--------|------------------|----------------------|
| Value label | Market Value | Series Avg. | **Market Estimate** |
| Discover summary | Market Value · $X · N sales | Series Avg. · $X · N sales | **Market Estimate · $X · N sales** |
| Insights banner | — | Series-Level Estimate | **Market Estimate** |
| Insights value column | Market Value | Series Avg. | **Market Estimate** |
| Badge heading (dev) | Market Value | Series Avg. Value | **Market Estimate** |
| Badge chip (dev) | — | ≈ Series Estimate | **≈ Market Estimate** |
| Shelf row prefix | — | ~ (unchanged) | ~ (unchanged) |
| Coverage footnote | — | includes estimates (unchanged) | includes estimates (unchanged) |

---

## Deliverable 2 — Final delta wording table

| Direction | Tier A | Tier B blind-box | Tier B non-blind-box |
|-----------|--------|------------------|----------------------|
| Above | `▲ N% above market` | `▲ N% above series avg.` | `▲ N% above market estimate` |
| Below | `✓ Below market` | `Below series avg.` | `Below market estimate` |
| Near | `≈ At market` | `≈ Near series avg.` | `≈ Near market estimate` |

---

## Deliverable 3 — Final sheet title

| Context | Title |
|---------|-------|
| Market Detail ⓘ (non-blind-box Tier B) | **About this market estimate** |
| Market Detail ⓘ (blind-box Tier B) | **About series average pricing** *(unchanged)* |

---

## Deliverable 4 — Should `market_snapshot_vocabulary.dart` exist?

**No.** Implement branching in **`market_snapshot_format.dart`** with a small `resolveIsBlindBoxSeries(seriesId)` helper. Parameterize the info sheet only.

---

## Deliverable 5 — Updated implementation plan (3N-E revised)

### Scope (unchanged)

Copy only. No providers, repositories, Firestore, routing, math, fallback.

### Tasks (~1.5 days, down from ~2)

| # | Task | File(s) |
|---|------|---------|
| 1 | Add `resolveIsBlindBoxSeries(seriesId)` + label/delta helpers | `market_snapshot_format.dart` |
| 2 | Update `formatMarketSnapshotDiscoverSummaryLine`, `formatMarketListingPriceDeltaLine` to branch on `(isSeriesEstimate, isBlindBox)` | same |
| 3 | Replace inline constants in insights / badge with formatter helpers | `market_insights_screen.dart`, `market_snapshot_badge.dart` |
| 4 | Parameterize info sheet title + body | `market_series_average_info_sheet.dart` |
| 5 | Pass `isBlindBoxSeries` from delta widget | `market_detail_insights_section.dart` |
| 6 | Tests: blind-box regression (Hope strings identical) + standalone fixtures | `market_snapshot_format_test.dart`, widget tests |
| 7 | **Optional P2:** shelf info sheet bullet for standalone products | `shelf_value_info_sheet.dart` |

### Acceptance criteria

- [ ] Hope / Big Into Energy strings **unchanged**
- [ ] No non-blind-box Tier B string contains `series avg` or `Series Avg.`
- [ ] Non-blind-box uses **Market Estimate** / **market estimate** consistently
- [ ] No new vocabulary module file

---

## Deliverable 6 — Screens affected

| Screen | Changes when |
|--------|----------------|
| Market Detail | Tier B + `!isBlindBox` — delta + ⓘ sheet |
| Discover gallery | Tier B + `!isBlindBox` — summary line |
| Market Insights | Tier B + `!isBlindBox` — labels (dev/direct entry only) |
| Dev badge screen | Consistency |

### Unchanged

Tier A all surfaces; Tier B blind-box all surfaces; Tier C; Market Insights nav policy; shelf `~` and totals; `Market Information` heading.

---

## Deliverable 7 — Risk assessment

| Risk | Level | Notes |
|------|-------|-------|
| Production impact today | **None** | 0 non-blind-box Tier B snapshots |
| Hope regression | **Medium** | Must lock blind-box strings in tests |
| “Market Estimate” vs Tier A “Market Value” confusion | **Low** | Distinct nouns; delta + sheet explain scope |
| Catalog cache miss → default blind-box | **Low** | Wrong copy only if standalone misclassified as blind-box in cache |
| Copy length on small screens | **Low** | “Market Estimate” shorter than “Estimated Market Value” |
| Shelf “includes estimates” generality | **Low** | Optional P2 clarification |

---

## Summary decision record

| Question | Decision |
|----------|----------|
| Value label for non-blind-box Tier B | **Market Estimate** (not Estimated Value) |
| Delta phrasing | **above / below / near market estimate** |
| Info sheet title | **About this market estimate** |
| New vocabulary file | **No** — extend `market_snapshot_format.dart` |
| Long-term system | Market Value · Series Avg. · Market Estimate |

This completes UX review for Sprint 3N-E implementation.

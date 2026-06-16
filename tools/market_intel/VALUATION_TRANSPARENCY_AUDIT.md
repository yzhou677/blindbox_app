# Valuation Transparency Audit — Sprint 3M-A

**Date:** June 2026  
**Scope:** All valuation-related UI surfaces. Read-only audit. No code changes.  
**Method:** Review of current copy, widgets, and trust-tier behavior after Sprints 3I–3L remediation.

---

## Executive Summary

Shelfy’s trust-tier vocabulary (Figure Snapshot vs Series Estimate) is a meaningful improvement, but **first-time collectors still lack a single place that explains the valuation system**. The app uses visual shorthand (`~`, `Est.`, `includes estimates`, `Series Avg.`) without defining what those mean or how confidence differs between tiers.

**No informational (ⓘ) disclosure exists anywhere in the app today.**

The highest-value disclosures cluster around two moments:

1. **Purchase context** — when a listing price is compared to a benchmark (Market Detail delta line).
2. **Portfolio context** — when owned figures are summed into a shelf total (Collection Insights overview).

Tier B (series estimate) surfaces need disclosure more than Tier A: the label changes are honest, but a collector can still read `▲ 8% above series avg.` or `Series Avg. · $37` as if it were figure-specific market data—especially because Market Insights navigation is hidden for Tier B listings (Sprint 3J).

---

## Trust Tier Reference (for this audit)

| Tier | User-facing label | Meaning | Accuracy signal today |
|------|-------------------|---------|------------------------|
| **A — Figure Snapshot** | `Market Value` | Derived from sales matched to **this exact figure** | Sales count, range, freshness (Discover expand / Insights screen) |
| **B — Series Estimate** | `Series Avg.` / `Series Estimate` | Derived from sales across **the series**, not this figure | `Series Avg.` label, `~` on shelf rows, `includes estimates`, tertiary styling on badge |
| **C — No data** | (hidden / unavailable) | No snapshot | Figure excluded from totals; delta hidden |

---

## Surface-by-Surface Audit

### 1. Collection Home

**Widget:** `_ShelfValueGlance` in `collection_summary_section.dart`  
**Labels:** `Est. shelf value` · `~$612` · `Based on 12 of 15 figures` · optional `· includes estimates`

#### Q1 — Can a first-time collector understand the number without external help?

| Dimension | Assessment |
|-----------|------------|
| **What the number means** | **Partial.** `Est.` and `~` signal approximation, but neither is defined in-app. A user may assume the total is exact or that `~` only means “we’re not sure of the cents.” |
| **Where it comes from** | **Weak.** No mention of eBay, sold listings, or figure vs series methodology at this glance. `includes estimates` hints at mixed tiers but does not explain what an “estimate” is. |
| **How accurate it is** | **Partial.** `Based on X of Y figures` communicates partial coverage. It does not explain that unvalued figures are **excluded** (not counted as $0), or that some valued figures may be series-level guesses. |

#### Q2 — Would an optional ⓘ improve comprehension?

**Yes** — especially when `includesSeriesEstimates` is true, but useful even for all-snapshot shelves because `~` is always shown on the total regardless of tier mix.

#### Q3 — Recommended placement (if yes)

| Field | Detail |
|-------|--------|
| **Screen** | Collection Home |
| **Widget** | `_ShelfValueGlance` row |
| **Label** | `Est. shelf value` (ⓘ inline, trailing the label text) |
| **Location** | Left side of the glance row, adjacent to `Est. shelf value` — not on the dollar amount |
| **Why** | This is the first portfolio valuation touchpoint. Space is tight; an icon avoids cluttering the headline number while making methodology discoverable for curious users. |

**Proposed disclosure content:**

> **Estimated shelf value**  
> A rough total of what your owned figures may be worth based on recent marketplace sales.  
>  
> · Figures without market data are left out — not counted as zero.  
> · **~** means approximate.  
> · When some figures use a **series average** instead of figure-specific sales, you’ll see **includes estimates**.  
>  
> Open Collection Insights for a full breakdown.

---

### 2. Collection Insights — Shelf Value (overview)

**Widget:** `_ValueOverview` in `shelf_value_card.dart`  
**Labels:** Section header `Shelf Value` · `~$612` · `Based on X of Y figures · includes estimates` · `N% coverage` bar

#### Q1

| Dimension | Assessment |
|-----------|------------|
| **What the number means** | **Partial.** Same as Collection Home, with more visual weight on `~$612`. |
| **Where it comes from** | **Weak–partial.** Coverage sub-label helps; coverage bar reinforces completeness. Still no data-source or tier explanation. |
| **How accurate it is** | **Partial.** `includes estimates` is the strongest accuracy cue in the collection universe, but undefined. Coverage % does not distinguish figure snapshots from series estimates within the valued set. |

#### Q2

**Yes** — this is the **canonical shelf valuation surface** and the best place to teach the full model once.

#### Q3

| Field | Detail |
|-------|--------|
| **Screen** | Collection Insights |
| **Widget** | `_SectionHeader` / `_ValueOverview` |
| **Label** | `Shelf Value` (ⓘ on section header) |
| **Location** | Trailing `Shelf Value` section title, above `~$612` |
| **Why** | Users who open Insights are explicitly seeking value context. One disclosure here can explain `~`, coverage, exclusions, and mixed tiers for the entire card below (Most Valuable, By Series). |

**Proposed disclosure content:**

> **How shelf value is calculated**  
> We add up market estimates for figures you own.  
>  
> **Figure snapshot** — based on recent sales of that exact figure. Shown without **~**.  
> **Series estimate** — when we don’t have enough sales for a specific figure, we use the average for other figures in the same series. Shown with **~** and noted as **includes estimates** when mixed into your total.  
>  
> Figures with no market data are omitted. Your total only reflects figures we could value.  
>  
> Data is estimated from eBay marketplace activity.

---

### 3. Collection Insights — Most Valuable

**Widget:** `_FigureValueRow` in `shelf_value_card.dart`  
**Labels:** Rank · figure name · `$37` or `~$37`

#### Q1

| Dimension | Assessment |
|-----------|------------|
| **What the number means** | **Partial for Tier B.** `~` differentiates series estimates when users notice it; many will scan names and dollar amounts only. |
| **Where it comes from** | **Weak.** No per-row provenance. |
| **How accurate it is** | **Weak for Tier B.** A `~$37` secret figure valued from a series average could be wildly wrong; nothing warns about within-series price spread. |

#### Q2

**Marginally** — a row-level ⓘ would be noisy. A **section-level** ⓘ is sufficient if Shelf Value header disclosure exists.

#### Q3 (section-level only)

| Field | Detail |
|-------|--------|
| **Screen** | Collection Insights |
| **Widget** | `_SectionHeader` for `Most Valuable` |
| **Label** | `Most Valuable` |
| **Location** | Trailing section title |
| **Why** | Clarifies that ranking uses the same figure/series rules as the total; explains why some rows show `~`. Lower priority if Shelf Value header disclosure is implemented. |

**Proposed disclosure content:**

> **Most valuable figures**  
> Ranked by estimated resale value. A **~** prefix means that figure’s value comes from a **series average**, not sales of that specific figure — so rank order may not reflect true rarity or demand.

---

### 4. Collection Insights — By Series

**Widget:** `_SeriesSection` / `_SeriesValueRow` in `shelf_value_card.dart`  
**Labels:** `By Series` (collapsible) · series name · `3 of 5 figures valued` · `$183` or `~$183`

#### Q1

| Dimension | Assessment |
|-----------|------------|
| **What the number means** | **Partial.** Series subtotal is interpretable as “my investment in this series.” `~` on row (Sprint 3L) signals series-estimate mix within that series. |
| **Where it comes from** | **Weak.** Subtext counts valued figures but not tier mix. |
| **How accurate it is** | **Partial.** `X of Y figures valued` is helpful; user may not connect `~` on the dollar amount to estimate tier. |

#### Q2

**Yes** when any row has `hasSeriesEstimates` — otherwise optional.

#### Q3

| Field | Detail |
|-------|--------|
| **Screen** | Collection Insights |
| **Widget** | `_SeriesSection` header row |
| **Label** | `By Series` |
| **Location** | Trailing `By Series` title (when expanded section is available) |
| **Why** | Series totals are a common mental model for collectors (“how much is my SKULLPANDA shelf worth?”). The `~` on a series row is subtle; users need to know it means at least one figure in that series used a series-level fallback. |

**Proposed disclosure content:**

> **By series**  
> Total estimated value for figures you own in each series.  
>  
> **~** on a series total means one or more figures in that series were valued using a **series average** rather than figure-specific sales.

---

### 5. Discover — Figure Detail (Market Information accordion)

**Widget:** `_GalleryMarketInformationAccordion` in `catalog_figure_gallery_sheet.dart`  
**Labels:** `▶ Market Information` · expanded `Market Value · $42 · 18 sales` or `Series Avg. · $37 · 4 sales` · range · `Updated …`

#### Q1

| Dimension | Assessment |
|-----------|------------|
| **What the number means** | **Good for Tier A, partial for Tier B.** Post–Sprint 3I labels are clear when read carefully. Accordion is collapsed by default — many users never expand. |
| **Where it comes from** | **Partial.** Sales count and freshness appear on expand. eBay-only source is not stated here (only on Market Insights footer). |
| **How accurate it is** | **Weak for Tier B.** `4 sales` reads as figure evidence but reflects **series-wide** activity. No sample-size caveat. Series price range can span 10× within a blind-box line (per trust audit). |

#### Q2

**Yes** — especially for **Tier B** (`Series Avg.`). Tier A benefits less but still gains from a light methodology note.

#### Q3 — Tier B (primary)

| Field | Detail |
|-------|--------|
| **Screen** | Discover Figure Detail (catalog gallery sheet) |
| **Widget** | `_GalleryMarketInformationAccordion` expanded summary line |
| **Label** | `Series Avg. · $37 · N sales` |
| **Location** | ⓘ inline at end of summary line, or on `Market Information` heading when `snapshot.isSeriesEstimate` |
| **Why** | Catalog browsing is where users form price expectations before marketplace search. Tier B is most likely to be mistaken for a figure-specific market value because the layout mirrors Tier A. |

**Proposed disclosure content (Tier B):**

> **Series average**  
> We don’t have enough recent sales for this specific figure, so this value is based on sales of **other figures in the same series**.  
>  
> Within a blind-box series, individual figures can sell for very different prices (regular, popular, secret). Treat this as a rough guide, not this figure’s true market price.

#### Q3 — Tier A (secondary)

| Field | Detail |
|-------|--------|
| **Screen** | Discover Figure Detail |
| **Widget** | `_GalleryMarketInformationAccordion` |
| **Label** | `Market Value · $42 · N sales` |
| **Location** | On `Market Information` heading or summary line |
| **Why** | Connects the accordion to sold-listing methodology and eBay-only scope for users who never open Market Insights. |

**Proposed disclosure content (Tier A):**

> **Market value**  
> Estimated from recent eBay sales matched to this figure. Sales count and update time reflect how much data we have. Other marketplaces are not included.

---

### 6. Market Detail

**Widget:** `MarketListingPriceDeltaLine` in `market_detail_insights_section.dart`  
**Labels:** Listing price · `▲ 14% above market` / `▲ 8% above series avg.` / `✓ Below market` / `≈ At market` / `Below series avg.` / `≈ Near series avg.`  
**Related:** `MarketInsightsNavigationEntry` hidden when `isSeriesEstimate` (Sprint 3J)

#### Q1

| Dimension | Assessment |
|-----------|------------|
| **What the number means** | **Good for Tier A** after Sprint 3I wording. **Risky for Tier B** — delta reads like a purchase recommendation tied to “market,” but denominator is series average. |
| **Where it comes from** | **Weak on this screen.** No sales count, range, or data source adjacent to delta. Tier B users cannot drill into Market Insights from here. |
| **How accurate it is** | **Not communicated.** User sees a confident percentage with color emphasis (tertiary for above series avg.) but no uncertainty framing. |

#### Q2

**Yes — strongest candidate in the marketplace universe**, especially Tier B.

#### Q3 — Tier B (primary)

| Field | Detail |
|-------|--------|
| **Screen** | Market Detail |
| **Widget** | `MarketListingPriceDeltaLine` |
| **Label** | `▲ N% above series avg.` (and sibling Tier B delta strings) |
| **Location** | Trailing inline ⓘ on the delta line, baseline-aligned with label text |
| **Why** | Highest-stakes moment: user is evaluating a real listing price. Tier B comparison can materially mislead (e.g., secret figure vs series average). No downstream Insights screen for Tier B to self-educate. |

**Proposed disclosure content (Tier B):**

> **Compared to series average**  
> This listing is compared to the **average price of other figures in the series**, not sales of this specific figure.  
>  
> In blind-box series, rare figures often sell for much more than the series average. Use this as context only — not as a buy/sell signal for this figure.

#### Q3 — Tier A (secondary)

| Field | Detail |
|-------|--------|
| **Screen** | Market Detail |
| **Widget** | `MarketListingPriceDeltaLine` |
| **Label** | `▲ N% above market` |
| **Location** | Trailing ⓘ on delta line |
| **Why** | Tier A users can open Market Insights, but many won’t. Brief methodology note near the comparison reinforces trust without requiring navigation. |

**Proposed disclosure content (Tier A):**

> **Compared to market value**  
> Based on recent eBay sales for this figure. Tap **Market Insights** below for sales count, price range, and update time.

---

### 7. Market Insights

**Widget:** `MarketInsightsScreen` / `_MarketInsightsContent`  
**Labels:** `Series-Level Estimate` (Tier B banner) · `Market Value` / `Series Avg.` · `Current Listing` · delta · `Data Source` · footer (`eBay listings…`)

#### Q1

| Dimension | Assessment |
|-----------|------------|
| **What the number means** | **Good.** Dedicated screen with clear column labels. |
| **Where it comes from** | **Good for Tier A.** `Data Source` section + footer state eBay-only scope. |
| **How accurate it is** | **Partial.** Activity and range lines help Tier A. Tier B banner `Series-Level Estimate` is honest but does not explain blind-box price variance. |

#### Q2

**Low for Tier A** — footer and structured layout already disclose source. **Moderate for Tier B** if user deep-links (navigation from Market Detail is hidden, but route may still be reachable).

#### Q3 — Tier B only (optional)

| Field | Detail |
|-------|--------|
| **Screen** | Market Insights |
| **Widget** | `Series-Level Estimate` banner |
| **Label** | `Series-Level Estimate` |
| **Location** | Trailing ⓘ on banner text |
| **Why** | Reinforces tier semantics on the one screen that still renders Tier B content. Lower priority because this screen is no longer linked from Tier B listings. |

**Proposed disclosure content:**

> Same as Discover Tier B series-average disclosure (reuse single copy block).

---

## Recommended Info Icons (Ranked)

### P0 — Strongest user benefit

| # | Screen | Widget | Label | Location | Reason |
|---|--------|--------|-------|----------|--------|
| **P0-1** | Market Detail | `MarketListingPriceDeltaLine` | `▲ N% above series avg.` (all Tier B delta variants) | Inline ⓘ on delta line | Purchase decision point; Tier B denominator is easy to misread as figure market value; Insights drill-down blocked (3J). Highest financial trust risk. |
| **P0-2** | Collection Insights | `_SectionHeader` / `_ValueOverview` | `Shelf Value` | ⓘ on section header | Canonical explanation for portfolio total, `~`, coverage, exclusions, and mixed tiers — educates users for Home glance and subsections. **Implemented — Sprint 3M-B.** |
| **P0-3** | Discover Figure Detail | `_GalleryMarketInformationAccordion` | `Series Avg. · $…` / `Market Information` | ⓘ on heading when Tier B, or on summary line | Forms price expectations during catalog browse; Tier B structurally mirrors Tier A; sales count misattributed to figure. |

### P1 — Useful

| # | Screen | Widget | Label | Location | Reason |
|---|--------|--------|-------|----------|--------|
| **P1-1** | Collection Home | `_ShelfValueGlance` | `Est. shelf value` | ⓘ on label | First touchpoint for shelf value; many users never open Insights. |
| **P1-2** | Market Detail | `MarketListingPriceDeltaLine` | `▲ N% above market` (Tier A) | Inline ⓘ on delta line | Reinforces methodology without requiring Insights navigation. |
| **P1-3** | Collection Insights | `_SeriesSection` | `By Series` | ⓘ on section header (when any `hasSeriesEstimates`) | Explains subtle `~` on series row totals. |
| **P1-4** | Discover Figure Detail | `_GalleryMarketInformationAccordion` | `Market Value · $…` (Tier A) | ⓘ on heading or summary | States eBay sold-data basis for users who never open Insights. |

### P2 — Optional

| # | Screen | Widget | Label | Location | Reason |
|---|--------|--------|-------|----------|--------|
| **P2-1** | Collection Insights | `_SectionHeader` | `Most Valuable` | ⓘ on section header | Redundant if Shelf Value disclosure exists; helps `~` on ranked rows. |
| **P2-2** | Collection Insights | `_CoverageBar` | `N% coverage` | ⓘ next to coverage label | Clarifies exclusion semantics; partially covered by Shelf Value disclosure. |
| **P2-3** | Market Insights | Tier B banner | `Series-Level Estimate` | ⓘ on banner | Niche deep-link path; screen already has Data Source footer. |
| **P2-4** | Market Insights | Tier A value card | `Market Value` | ⓘ on label | Redundant with Data Source section and footer below the fold. |

---

## Cross-Cutting Observations

1. **`~` is always shown on shelf totals** even when every valued figure is a figure snapshot. First-time users may learn the wrong rule (“tilde always means series estimate”). Shelf Value disclosure should clarify that `~` means approximate at the aggregate level, while per-figure `~` specifically marks series estimates.

2. **Tier B has no drill-down from Market Detail** (Sprint 3J). Any disclosure on the delta line is not optional polish — it is the only in-flow education for that journey.

3. **Reuse one copy module** for series-average education (Discover Tier B, Market Detail Tier B delta, optional Market Insights Tier B). Wording should stay consistent across surfaces.

4. **Prefer bottom sheet over tooltip** for P0/P1 disclosures: content is 3–5 sentences; tooltips are easy to miss on mobile; bottom sheet matches existing sheet patterns in the app.

5. **Do not add warning icons** (per sprint constraints). ⓘ is strictly informational; tone should be calm and educational.

---

## Final Question

**If only ONE info icon were added in the entire app, where should it be placed for maximum user trust gain?**

**Place it on Market Detail → `MarketListingPriceDeltaLine` → Tier B delta text**  
(e.g. `▲ 8% above series avg.`), inline trailing ⓘ.

**Rationale:**

- This is the moment the user interprets a **real listing price** against a benchmark — a decision with immediate financial consequences.
- Tier B wording is improved but still easy to scan as “above/below market” for **this** figure.
- Sprint 3J removed the Market Insights navigation path for series estimates, so users **cannot self-correct** by drilling deeper.
- A single disclosure here prevents the most harmful misread in the product: treating a series average as figure-specific market proof.

If the product team prefers optimizing for **collection trust** over **marketplace trust**, the runner-up is **Collection Insights → `Shelf Value` section header** — it explains the broadest valuation model once and benefits every downstream row (`Most Valuable`, `By Series`). For maximum *user trust gain* across the whole app, however, the Market Detail Tier B delta line wins because it guards the highest-risk interpretation at the point of action.

---

## References

- `lib/features/collection/widgets/collection_summary_section.dart` — Collection Home glance
- `lib/features/collection/insights/widgets/shelf_value_card.dart` — Collection Insights card
- `lib/features/collection/insights/domain/shelf_value_summary.dart` — `coverageLabel`, `includesSeriesEstimates`
- `lib/features/catalog/presentation/figure_gallery/catalog_figure_gallery_sheet.dart` — Discover accordion
- `lib/features/market/market_detail_screen.dart` — listing price + delta
- `lib/features/market_intel/widgets/market_detail_insights_section.dart` — delta line, Insights nav gating
- `lib/features/market_intel/presentation/market_insights_screen.dart` — Insights detail + Data Source
- `lib/features/market_intel/widgets/market_snapshot_format.dart` — tier copy constants and formatters
- `tools/market_intel/MARKET_TRUST_AUDIT.md` — tier definitions and prior risk findings
- `tools/market_intel/MARKET_TRUST_REMEDIATION_PLAN.md` — Sprints 3I–3L remediation status

# Sprint 3B — Collection Value Design

> **Date:** 2026-06-15  
> **Type:** Design only — no Flutter code.  
> **Prerequisite reading:** [`MARKET_EXPERIENCE_DESIGN.md`](./MARKET_EXPERIENCE_DESIGN.md) (Phase 2 outline)

---

## What exists today

**`CollectionSummarySection`** — the glance card at the top of Collection home:

```
┌─────────────────────────────────────┐
│     127  in collection  ·  12  wishlist     │
│                                             │
│  "A shelf built with intention…"           │  ← mood line
│  "You added 3 figures this week."          │  ← memory whisper
│                                             │
│  ✦  Your type: The Completionist  ›        │  ← archetype entry
└─────────────────────────────────────┘
```

**`/collection/insights`** — already exists, fully implemented:
- `CollectorTypeRevealCard` — archetype reveal (personality, not finances)
- `CollectorJourneyCard` — IPs explored, series completed, first series added

**What is absent:** estimated monetary value anywhere in the Collection experience.

---

## Design principles for this sprint

1. **Shelf feeling, not portfolio manager.** Value is a quiet signal, not a finance dashboard. No ticker fonts, no bold green/red, no charts on home.
2. **Always show the caveat inline, never hidden.** If coverage is 73%, the number $4,382 must appear together with its basis — not as a standalone headline that implies false precision.
3. **Value as one facet of the collection, not the centerpiece.** The archetype reveal and editorial mood lines are the emotional core. Value enriches without displacing them.
4. **Don't require user action to see the number.** Partial value is still useful — show it by default with appropriate framing, not behind a "tap to see" wall.

---

## Question 1 — Collection home: how to show total value

### The problem

The summary card currently shows `In collection · Wishlist`. Adding estimated value as a third stat (`· $4,382`) inside the same strip would work mechanically but the three-item strip becomes crowded, and the dollar number is categorically different from counts — it deserves a different visual weight.

### Recommended approach: value accent line

Add one line below the existing stat strip, above the mood line:

```
┌─────────────────────────────────────────────┐
│   127  in collection  ·  12  wishlist        │
│                                              │
│   Est. shelf value  ~$4,382                  │  ← new line
│   Based on 93 of 127 figures                 │  ← inline caveat
│                                              │
│   "A shelf built with intention…"            │
│   "You added 3 figures this week."           │
│                                              │
│   Collection insights  ›                     │  ← single entry row
└─────────────────────────────────────────────┘
```

**Copy rules:**
- Lead with `~` (tilde): communicates "approximate" without requiring a footnote
- `Est. shelf value` not `Market value` — this is their personal collection, not a market asset
- Coverage caveat on the same line, not a separate section: `Based on 93 of 127 figures`
- The tilde absorbs the uncertainty — no asterisks, no footnotes on the home glance
- **One navigation row:** `Collection insights ›` opens `/collection/insights` (Collector Type reveal + Journey + Shelf Value live on that screen — no separate Home entry for collector type)

**When to show / not show:**
- Show value glance when at least 1 figure in collection has a snapshot
- Hide the value line (not the entire summary card) when coverage is 0%
- Do not show `$0` — too discouraging; show nothing instead
- Show `Collection insights ›` whenever the shelf has tracked series (same card, below value or stats)

---

## Question 2 — Collection Insights: how to design the value section

### What exists in /collection/insights

The current screen is the **Collector Type** experience — archetype reveal, glow animation, journey stats. This is emotional and identity-focused. Market value would feel tonally jarring injected into that screen.

### Recommended approach: separate card on the same screen

Add a third card below `CollectorJourneyCard`, titled **Shelf Value**. The screen flow becomes:

```
/collection/insights
│
├── CollectorTypeRevealCard     (archetype — identity, emotion)
├── CollectorJourneyCard        (journey — IPs, completion, time)
└── ShelfValueCard  [NEW]       (value — estimated total, top figures)
```

Keeping it on the same screen (not a new route) keeps navigation shallow and the insights experience unified. The collector sees their archetype, their journey, and their value in one scroll.

### `ShelfValueCard` layout

```
┌───────────────────────────────────────────┐
│  Shelf Value                              │
│                                           │
│  Estimated total                          │
│  ~$4,382                                  │
│  Based on 93 of 127 figures               │
│                                           │
│  ──────────────────────────────────────   │
│                                           │
│  Most Valuable                            │
│                                           │
│  [img]  Secret Figure       $210          │
│  [img]  Luck                 $42          │
│  [img]  Hope                 $37          │
│  [img]  Crybaby              $35          │
│  [img]  Lila                 $31          │
│                                           │
└───────────────────────────────────────────┘
```

---

## Question 3 — Series value: how to show it

### Where it belongs

Series value is a secondary detail — interesting but not urgent. It belongs in the **Shelf Value** card as a collapsible section, not on series cards in the main shelf list (that would clutter the main feed).

### Layout inside ShelfValueCard

```
┌───────────────────────────────────────────┐
│  Shelf Value                              │
│                                           │
│  ~$4,382                                  │
│  Based on 93 of 127 figures               │
│                                           │
│  Most Valuable                            │
│  [five figure rows — see Q4]              │
│                                           │
│  ▶  By Series                             │  ← collapsed by default
│                                           │
└───────────────────────────────────────────┘

Expanded "By Series":

│  ▼  By Series                             │
│                                           │
│  Big Into Energy              $220        │
│    5 of 7 valued                          │
│  Exciting Macaron             $183        │
│    4 of 6 valued                          │
│  Treehouse Theatre             $94        │
│    8 of 10 valued                         │
│  Wild Grass                    $47        │
│    2 of 4 valued                          │
│                                           │
```

**Series row design rules:**
- Series name + total estimated value for owned figures in that series
- `N of M valued` subline (not a percentage — concrete numbers feel more trustworthy)
- Sort by total estimated value descending
- Do not show series with zero valued figures
- No trend arrows on series rows at this stage (Phase 4)

### Series value on the series card (main shelf — not recommended for MVP)

Adding a value line to each `SeriesShelfCard` in the main feed is tempting but:
- It requires N Firestore reads on Collection home load (same perf concern as Market Browse overlay)
- The main shelf is an emotional surface — prices on every card edges toward dashboard density
- Value belongs in Insights, not the browsing feed

Recommendation: **keep series value inside the Insights screen only** for MVP. Revisit adding value to series cards in Phase 3 alongside the browse intel overlay work.

---

## Question 4 — Top Valuable Figures: how to show them

### List design

Each row in the "Most Valuable" list shows:
- Rank number (1–5)
- Figure thumbnail (catalog `imageKey` via `CatalogImageFromKey`)
- Figure name
- Estimated value (right-aligned)

```
┌────────────────────────────────────────────┐
│  Most Valuable                             │
│                                            │
│  1   [□]  Secret Figure            $210   │
│  2   [□]  Luck                      $42   │
│  3   [□]  Hope                      $37   │
│  4   [□]  Crybaby                   $35   │
│  5   [□]  Lila                      $31   │
│                                            │
│  + See all 93 valued figures  ›           │  ← optional expand, Phase 3
└────────────────────────────────────────────┘
```

**Rules:**
- Show top 5 in MVP. Top 10 is a Phase 3 option.
- Only include figures where `isOwned == true` and a `MarketSnapshot` exists
- Use `estimatedValueUsd` from `marketSnapshotProvider(figureId)` — figure-level preferred, series fallback acceptable
- Mark series-estimate figures with `~` prefix: `~$37` (same tilde convention as the total)
- Tapping a row opens the figure gallery (same as tapping a figure in `SeriesFiguresSheet`) — no new screen
- Secret figures: show figure name, include in list, do not suppress (the user owns them; the value is theirs)

### What NOT to show in this list

- Figures the user does not own (wishlist, untracked)
- Figures with series-estimate-only data labelled as if they are figure-specific comps
- Market listings or asking prices — this is sold-data intel only
- Trend arrows (Phase 4)

---

## Question 5 — How to explain 73% coverage to users

### The problem

If the app says "Estimated value: $4,382" without context, the user may believe this is a precise valuation. If coverage is 73%, the true value could be 30%+ higher. Misrepresenting this erodes trust when users do their own research.

### Copy strategy: transparency without alarm

**Three-layer approach:**

**Layer 1 — Home glance (lowest precision, least alarming)**
```
Est. shelf value  ~$4,382
Based on 93 of 127 figures
```
The `~` does the work. `Based on N of M figures` is factual and specific, not a warning.

**Layer 2 — Insights card (moderate detail)**
```
~$4,382
Based on 93 of 127 figures

██████████████░░░░  73% of your figures have market data.
34 figures have no data yet — they are not included in this estimate.
```

**Layer 3 — Tooltip / expand (full transparency, on demand)**
```
About this estimate

This estimate is based on recent sold listing data from eBay
for 93 of your 127 figures.

34 figures have no market data yet. As more data becomes
available, your estimate will update automatically.

Estimates use sold listing prices, not current asking prices.
Series-level estimates (marked ~) are less precise than
figure-level data.
```

Show Layer 3 only when user taps a `ⓘ` icon next to the value headline. Do not show it by default.

### What to avoid

| Copy | Why to avoid |
|------|-------------|
| "Your collection is worth $4,382" | Implies precision and ownership claim; legally ambiguous |
| "Value: $4,382 (73% coverage)" | Technical jargon in parentheses; users skip it |
| "⚠ Incomplete data" | Alarmist; makes the feature feel broken |
| "Estimated value: unknown" | Useless when partial data exists |
| Not showing the value because coverage is <100% | Wastes useful data; frustrates users who want a rough number |

### Coverage threshold guidance

| Coverage | Recommendation |
|----------|----------------|
| 0% | Hide the value line on home; show "No market data for your collection yet" on Insights |
| 1–30% | Show estimate with strong caveat: "Based on N of M figures — early estimate" |
| 31–69% | Show with standard caveat: "Based on N of M figures" |
| 70–99% | Show with light caveat: "Based on N of M figures" (same copy, less visually prominent) |
| 100% | Show without caveat: "Estimated value $4,382" (no tilde needed when full coverage) |

---

## Full screen mockups

### Mockup A — Collection Home (populated shelf with value)

```
┌─────────────────────────────────────────────┐
│  My collection                              │
├─────────────────────────────────────────────┤
│                                             │
│  ┌──────────────────────────────────────┐  │
│  │  127  in collection  ·  12  wishlist │  │
│  │                                      │  │
│  │  Est. shelf value  ~$4,382           │  │
│  │  Based on 93 of 127 figures          │  │
│  │                                      │  │
│  │  Collection insights  ›             │  │
│  └──────────────────────────────────────┘  │
│                                             │
│  "A shelf built with intention…"            │
│  "You added 3 figures this week."           │
│                                             │
│  My collection          [+ Add series]      │
│  Collected across 4 brands                  │
│                                             │
│  Brand  ──────────────────────────────────  │
│  [ All ]  [ Pop Mart ]  [ Miniso ]          │
│                                             │
│  IP  ──────────────────────────────────────  │
│  [ All ]  [ THE MONSTERS ]  [ Hirono ]      │
│                                             │
│  ┌───────────────────────────────────────┐  │
│  │  [img]  Big Into Energy               │  │
│  │         THE MONSTERS                  │  │
│  │         ████████░░  5/7 owned         │  │
│  │         "Almost complete—"            │  │
│  └───────────────────────────────────────┘  │
│                                             │
│  ┌───────────────────────────────────────┐  │
│  │  [img]  Exciting Macaron              │  │
│  │         THE MONSTERS                  │  │
│  │         ████████████  6/6 owned       │  │
│  │         "Full set."                   │  │
│  └───────────────────────────────────────┘  │
└─────────────────────────────────────────────┘
```

**Notes:**
- `Collection insights ›` is the single entry row inside the summary card; navigates to `/collection/insights` (Collector Type + Journey + Shelf Value)
- Series cards do NOT show individual series values on the home feed (see Q3)
- The `~$4,382` / `Based on 93 of 127 figures` two-line block sits between the stat strip and the mood line

---

### Mockup B — Collection Insights screen (with ShelfValueCard added)

```
┌─────────────────────────────────────────────┐
│  ←  Collection Insights                     │
├─────────────────────────────────────────────┤
│  Collection Insights                        │
│  Your collection, analyzed.                 │
│                                             │
│  ┌──────────────────────────────────────┐  │
│  │  ✦  The Completionist               │  │  ← CollectorTypeRevealCard
│  │                                      │  │
│  │  "You chase completion over          │  │
│  │   novelty. Every gap is a quest."    │  │
│  │                                      │  │
│  │  [glyph]                             │  │
│  └──────────────────────────────────────┘  │
│                                             │
│  ┌──────────────────────────────────────┐  │
│  │  Your Journey                        │  │  ← CollectorJourneyCard (unchanged)
│  │  How you collect over time           │  │
│  │                                      │  │
│  │  IPs explored       12               │  │
│  │  Series completed    3               │  │
│  │  First added   Jan 4, 2025           │  │
│  └──────────────────────────────────────┘  │
│                                             │
│  ┌──────────────────────────────────────┐  │  ← NEW ShelfValueCard
│  │  Shelf Value                    ⓘ   │  │
│  │                                      │  │
│  │  Estimated total                     │  │
│  │  ~$4,382                             │  │
│  │  Based on 93 of 127 figures          │  │
│  │                                      │  │
│  │  ████████████████░░░░  73%           │  │
│  │                                      │  │
│  │  ─────  Most Valuable  ───────────── │  │
│  │                                      │  │
│  │  1  [□]  Secret Figure      $210    │  │
│  │  2  [□]  Luck                 $42   │  │
│  │  3  [□]  Hope                ~$37   │  │  ← ~ = series estimate
│  │  4  [□]  Crybaby              $35   │  │
│  │  5  [□]  Lila                 $31   │  │
│  │                                      │  │
│  │  ▶  By Series                        │  │  ← collapsed by default
│  └──────────────────────────────────────┘  │
│                                             │
└─────────────────────────────────────────────┘
```

---

### Mockup C — ShelfValueCard with "By Series" expanded

```
│  ┌──────────────────────────────────────┐  │
│  │  Shelf Value                    ⓘ   │  │
│  │                                      │  │
│  │  ~$4,382                             │  │
│  │  Based on 93 of 127 figures          │  │
│  │  ████████████████░░░░  73%           │  │
│  │                                      │  │
│  │  ─────  Most Valuable  ───────────── │  │
│  │  1  [□]  Secret Figure      $210    │  │
│  │  2  [□]  Luck                 $42   │  │
│  │  3  [□]  Hope                ~$37   │  │
│  │  4  [□]  Crybaby              $35   │  │
│  │  5  [□]  Lila                 $31   │  │
│  │                                      │  │
│  │  ▼  By Series                        │  │
│  │                                      │  │
│  │  Big Into Energy         $220        │  │
│  │    5 of 7 figures valued             │  │
│  │  Exciting Macaron        $183        │  │
│  │    4 of 6 figures valued             │  │
│  │  Treehouse Theatre        $94        │  │
│  │    8 of 10 figures valued            │  │
│  │  Wild Grass               $47        │  │
│  │    2 of 4 figures valued             │  │
│  │                                      │  │
│  └──────────────────────────────────────┘  │
```

---

### Mockup D — Coverage tooltip (tapping ⓘ)

```
┌─────────────────────────────────────────────┐
│  ╔══════════════════════════════════════╗   │
│  ║  About this estimate                 ║   │
│  ║                                      ║   │
│  ║  Based on sold listing data from     ║   │
│  ║  eBay for 93 of your 127 figures.    ║   │
│  ║                                      ║   │
│  ║  34 figures have no market data yet  ║   │
│  ║  and are not included. The estimate  ║   │
│  ║  will update as more data becomes    ║   │
│  ║  available.                          ║   │
│  ║                                      ║   │
│  ║  Figures marked ~ use series-level   ║   │
│  ║  data and are less precise.          ║   │
│  ║                                      ║   │
│  ║           [ Got it ]                 ║   │
│  ╚══════════════════════════════════════╝   │
└─────────────────────────────────────────────┘
```

This is a simple `AlertDialog` or bottom sheet — no new screen, no navigation.

---

### Mockup E — Zero coverage state (new collection, no snapshots)

```
│  ┌──────────────────────────────────────┐  │
│  │  Shelf Value                         │  │
│  │                                      │  │
│  │  Market data for your figures        │  │
│  │  isn't available yet.                │  │
│  │                                      │  │
│  │  As sold listing data is collected   │  │
│  │  for your figures, your estimated    │  │
│  │  shelf value will appear here.       │  │
│  └──────────────────────────────────────┘  │
```

---

### Mockup F — Dark mode (Collection home glance)

```
┌─────────────────────────────────────────────┐
│  My collection                              │  ← white text on dark
├─────────────────────────────────────────────┤
│                                             │
│  ┌──────────────────────────────────────┐  │
│  │  127 in collection · 12 wishlist     │  │  ← on dark surface card
│  │                                      │  │
│  │  Est. shelf value  ~$4,382           │  │  ← body text color
│  │  Based on 93 of 127 figures          │  │  ← onSurfaceVariant alpha
│  │                                      │  │
│  │  "A shelf built with intention…"     │  │  ← italic, secondary text
│  │                                      │  │
│  │  ✦  The Completionist  ›            │  │  ← primary accent
│  │  Collection insights  ›             │  │  ← same style, different icon
│  └──────────────────────────────────────┘  │
└─────────────────────────────────────────────┘
```

Dark mode note: the `$4,382` should use `onSurface` (not a green/gold color). Tonal coloring on a monetary value would make the summary feel like a brokerage app. Neutral text color, editorial weight.

---

## Implementation notes (design constraints only — no code)

### Navigation

- Home summary `Collection insights ›` → `/collection/insights` (existing route)
- On arriving at insights, scroll to `ShelfValueCard` (or just let user scroll — card is third, not far)
- No new routes required for MVP
- `ⓘ` → `AlertDialog` (no route)
- Top-5 row tap → `showCatalogFigureGallery(...)` (existing shared gallery; no new screen)

### Data contract

| Value | Source |
|-------|--------|
| `~$4,382` total | Sum `marketSnapshotProvider(figureId).estimatedValueUsd` for all owned figures |
| `93 of 127 figures` | Count of owned figures with a non-null snapshot result |
| Top-5 list | Sort owned figures by estimated value descending, take first 5 |
| Series breakdown | Group by `seriesId`, sum per group |
| `~` prefix on individual values | When `snapshot.isSeriesEstimate == true` |

`marketSnapshotProvider` already resolves figure → series fallback. No schema changes needed. The only new work is a `collectionValueProvider` that fans out over owned figure ids and aggregates.

### What NOT to build in MVP

- Historical value over time (no history schema)
- Trend arrows (Phase 4)
- Value per figure on the main shelf cards (Phase 3 performance work)
- Wishlist value (too sparse to be useful early)
- Export / share value (nice-to-have, lower priority)

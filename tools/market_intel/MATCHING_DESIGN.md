# Market Intelligence — Matching Design

> Source of truth for the V2 matching pipeline. Sprint 2 implementation begins after this document is complete.
> No section should remain ambiguous before coding starts.

---

## 1. Matching Philosophy

Core principle: **Trust is more important than data volume.**

V1 Market Browse tolerates low-confidence matches — a false match produces a slightly off listing card that the user can dismiss. V2 Market Intelligence writes a persisted `estimatedValueUsd` for a catalog figure. A false match in V2 corrupts the price estimate for every future user who sees that figure.

Therefore:

- A **false negative** (missing a valid sale) is always preferable to a **false positive** (attributing a wrong sale to a figure).
- Every sale that enters the aggregation must survive a chain of filters. A sale that fails any filter is rejected, not degraded to a lower confidence tier.
- Coverage is a product goal, not a correctness goal. Accuracy is non-negotiable. Coverage can grow as the matching pipeline matures.

The three questions a sale must answer before it enters the price aggregate:

1. Does the eBay search query scope this sale to the correct figure?
2. Does the sale title, after normalization, confirm this is the right item?
3. Does nothing about the sale (price, quantity, condition language, seller pattern) suggest it is not a real single-unit transaction?

All three must be yes.

---

## 2. Search Term Strategy

Search terms are curated in `tools/market_intel/market_metadata.json` under `figures.{figureId}.searchTerms`. They are the primary mechanism for retrieving candidate sales from eBay's completed listings API.

**Goal:** Retrieve all real single-unit sales for this specific figure, and as few sales for other figures as possible.

**Required specificity rules:**

- Every term must include the **brand** (`POP MART` or `POPMART`), the **series name** or a distinctive subset, and the **figure name**.
- Terms that match multiple figures in the same series are too broad. Example: `POP MART Big Into Energy` retrieves Lucky, Hope, Serenity, and all others. Use as a series-level search term only, not a figure search term.
- Short or generic figure names (Lucky, Angel, Star, Hope, Secret, Chaser) must be accompanied by the full series name to disambiguate. `POP MART Lucky` is too broad. `POP MART Lucky Big Into Energy` is acceptable.

**Minimum term set per figure:**

- At least one term with the canonical brand prefix (`POP MART`).
- One term with the alternate brand spelling (`POPMART`) if eBay sellers commonly use it.
- Series name tokens must appear in every term.

**When a figure cannot be safely scoped with search terms:**

- If no search term can reliably isolate this figure from others in the same series (e.g., a figure named `Secret` in a series where multiple figures have "secret" in their names), leave `searchTerms` empty and add a `notes` field explaining why. No snapshot will be computed.

**`marketAliases` extension:**

- Marketplace sellers often use shorthand not in the catalog's `aliases` field (e.g., `LUCKY 1000%` for the MEGA version, `LABUBU` for The Monsters IP).
- Add these to `marketAliases` for the figure or series entry. The pipeline uses them to build additional search queries without widening the canonical catalog data.

---

## 3. Exclude Term Strategy

Exclusions filter out specific listing types that would corrupt the price estimate. They operate at two levels.

**Global excludes (applied to every query, in `_title_normalizer.mjs`):**

These are listings that are structurally incompatible with a single-unit completed sale of an authentic figure.

- `lot` — multi-unit listings
- `bundle` — grouped sales
- `set of` — another multi-unit signal
- `full case` / `display case` / `case of` — case-quantity sales
- `custom` — fan-made or altered items
- `bootleg` / `fake` / `replica` / `inspired` — inauthentic items
- `3d print` / `digital file` — non-physical items
- `for parts` / `not working` / `broken` — damaged items
- `wholesale` — trade-quantity signals

Source reference: `MarketListingTitleSignals.noiseTerms` and `MarketListingTitleSignals.lotTerms` in V1.

**Accessory excludes (global, but context-dependent):**

These are physical items that use a figure's name but are not the figure itself. Apply globally unless the figure is specifically a keychain or charm series.

- `keychain` / `key chain`
- `charm`
- `phone strap` / `phone case`
- `badge` / `pin only`
- `pendant` / `lanyard` / `bag charm`

Source reference: `MarketListingTitleSignals.accessoryTerms` in V1.

Note: for series like `the_monsters_big_into_energy_vinyl_plush_pendant` the word "pendant" appears in the series name itself. Per-figure `excludeTerms` in `market_metadata.json` should override the global pendant exclusion for these figures.

**Per-figure excludes (`market_metadata.json` → `excludeTerms`):**

Used when a figure's name or series name creates false positives specific to that figure. Examples:

- A figure named `Angel` in a Halloween series may attract listings for unrelated angel figures from different brands. Add `sanrio`, `lol`, or competing brand names as per-figure excludes.
- A figure whose series name contains `star` may attract Star Wars merchandise.

**Matching rules for excludes:**

- Exclusion is based on case-insensitive **word boundary** matching, not simple substring. Reason: `lot` as a substring would incorrectly exclude `Charlotte` or `Ocelot`. Use `\blot\b` regex semantics.
- Exception: multi-word excludes (`full case`, `set of`) use substring matching since they are unambiguous phrases.

---

## 4. Title Normalization

Normalization happens before any matching or scoring. Its purpose is to eliminate irrelevant variation between listing titles that describe the same item.

**Step 1 — Structural normalization (apply to all titles):**

- Lowercase the entire string.
- Replace separators (hyphens, underscores, slashes, pipes, middle dots, bullets) with spaces.
- Collapse multiple whitespace characters to a single space.
- Trim leading and trailing whitespace.

Reference: `TaxonomyTitleNormalizer.normalize()` in V1 (uppercases instead of lowercases; the pipeline can use either, provided it is consistent).

**Step 2 — Remove condition and shipping noise tokens:**

Remove these exact tokens (whole-word match after Step 1):

- Condition: `new`, `sealed`, `bnib`, `nib`, `misb`, `mib`, `nrfb`, `mint`, `unopened`
- Shipping/provenance: `free shipping`, `us seller`, `fast ship`, `authentic`, `official`, `genuine`
- Marketing copy: `rare`, `htf`, `hard to find`, `limited`, `exclusive`
- Version markers that do not identify the figure: `v1`, `v2`, `v3`, `ver`, `version` (when not part of the figure name itself)

Reference: `MarketListingTitleNormalizer._noiseTokens` in V1.

**Step 3 — Preserve what matters:**

Do not strip brand names, series names, figure names, size designators that identify a specific product line (e.g., `1000%`, `400%`), or rarity indicators that map to `isSecret` in the catalog (`secret`, `chase`, `hidden`, `隐藏`).

**Principle:** After normalization, two titles describing the same figure sold in different conditions and with different shipping terms should produce identical or nearly identical strings.

---

## 5. Match Scoring System

After normalization and exclusion filtering, each sale is scored against the target figure's catalog entry. The score determines whether the sale is accepted into the aggregate.

**Score inputs (signals):**

- `brandMatch` — normalized title contains the brand name or a known brand alias (`POP MART`, `POPMART`, `POPMART.COM`)
- `seriesMatch` — normalized title contains the series name or a series alias from the catalog
- `figureNameMatch` — normalized title contains the figure's `displayName` or a catalog `alias`
- `marketAliasMatch` — normalized title contains an entry from `marketAliases` in `market_metadata.json`
- `secretSignalConsistent` — if the catalog figure has `isSecret == true`, the title contains a secret indicator (`secret`, `chase`, `hidden`, `隐藏`, `1/144`); if `isSecret == false`, the title does NOT contain those tokens
- `crossFigureContamination` — title contains the name of a different figure in the same series (negative signal)

**Weighting philosophy:**

- `figureNameMatch` is the strongest positive signal. A sale title that contains the figure's name within the correct brand and series context is almost certainly the right item.
- `seriesMatch` alone is insufficient for figure-level matching. It may produce a score above zero but below the acceptance threshold.
- `secretSignalConsistent` acts as a quality multiplier, not a primary score component. A mismatch (secret signal in a non-secret figure's title) is a strong negative signal.
- `crossFigureContamination` is a hard reject signal when confident. If a title contains `Lucky` and `Hope` both (two different figures from the same series), the sale is ambiguous and should be rejected.

**Score range:** 0.0 (no match) to 1.0 (exact match on all signals).

The score is not a machine learning probability. It is a deterministic weighted sum of binary signals. Every score is explainable and auditable.

Reference: `MarketIdentityMatcher._scoreForConfidence()` in V1 maps confidence tiers to scores: `exact → 1.0`, `high → 0.85`, `medium → 0.6`, `low → 0.4`. V2 uses the same numeric anchors.

---

## 6. Acceptance Threshold

**Default threshold: 0.75**

A sale is accepted into the aggregate if and only if its score is ≥ 0.75.

This requires at minimum: brand match + series match + figure name match. A sale that has brand and series but no figure name match scores approximately 0.6 and is rejected.

**Per-figure threshold override:**

`market_metadata.json` supports `matchThreshold: <number>` per figure. Use cases:

- **Raise the threshold (e.g., 0.85)** for figures with common or ambiguous names (`Lucky`, `Angel`, `Star`) where a normal figure-name match is insufficient because many unrelated items share that name. Require additional signals.
- **Lower the threshold (e.g., 0.65)** for figures with highly unique names where the figure name alone is nearly sufficient and search query specificity is already very high.

**Why stricter thresholds are preferred:**

A threshold that accepts a borderline sale adds one data point to the aggregate. If that data point is wrong (wrong figure, wrong product, lot mislabeled as single), it corrupts `estimatedValueUsd` in a way that every future user of that figure's badge will see. The cost of a false positive compounds with every app open. The cost of a false negative is zero user-visible impact.

**No "low confidence acceptance":**

V1 Market Browse accepts matches at `MarketMatchConfidence.low` (score 0.4) because it only affects which catalog entry a listing card is associated with. V2 Market Intelligence does not have a low-confidence acceptance tier. Any sale below 0.75 is rejected outright.

---

## 7. Manual Review Strategy

Not every rejected sale is wrong. Some are rejected due to unusual but legitimate listing styles. The pipeline handles this without blocking the solo maintainer.

**Default behavior: silent rejection.**

Rejected sales are not written to Firestore. They do not affect the snapshot. The maintainer is not notified for every rejection.

**Review log:**

The pipeline writes a local `_review_log.json` after each run containing:

- Sales that passed normalization and query filtering but scored between 0.60 and 0.74 (just below threshold)
- Sales that were excluded by global or per-figure exclude terms (sample, not exhaustive)
- Count of total rejected sales per figure
- `SnapshotSkipReason` for each figure that produced no snapshot (see Section 10)

The maintainer reviews this log manually before deciding whether to:

1. Add a `marketAlias` to capture a legitimate missed term.
2. Adjust a per-figure `matchThreshold`.
3. Add a per-figure `excludeTerms` entry to suppress a recurring false match pattern.
4. Accept the current result and proceed.

**No automated threshold adjustment:**

The maintainer makes all metadata decisions. The pipeline applies them deterministically. This keeps decisions auditable and reversible.

**When sales are too few to produce a snapshot:**

If fewer than 3 sales pass all filters for a figure in the 30-day window, no snapshot is written. This is not a review item — it is expected for newly released or low-liquidity figures. The maintainer may add more `searchTerms` or `marketAliases` over time.

---

## 8. Figure Snapshot Strategy

A figure snapshot represents the current market intelligence for one specific catalog figure.

**Pipeline flow:**

1. For each `figureId` in `market_metadata.json` where `disabled != true` and `searchTerms` is non-empty:
   - Query eBay completed/sold listings using each `searchTerm`
   - Apply global and per-figure `excludeTerms`
   - Normalize each sale title
   - Score each sale against the figure
   - Reject sales below the acceptance threshold
   - Reject outliers (IQR filter: exclude prices outside `Q1 - 1.5×IQR` to `Q3 + 1.5×IQR`)
   - If fewer than 3 sales remain: record `INSUFFICIENT_SALES` skip reason and stop — no snapshot
   - Compute `estimatedValueUsd` = median of remaining sale prices
   - Compute `trend` from two 15-day windows (see Section F below)
   - Assign `confidence`: `high` if 8+ qualifying sales and IQR spread < 50% of median; `low` if 3–7 qualifying sales or high spread
2. Write to `market_snapshots/{figureId}` with `level == "figure"`

**Minimum sale count: 3.** This is a hard floor, not a guideline. Below 3 qualifying sales, the median is meaningless and the IQR filter cannot operate reliably.

**Secret figures:**

Figures with `isSecret == true` in the catalog are tracked separately. They are never pooled into a series average. Secret figures use the **same acceptance threshold** as normal figures.

Rationale: secret figures command the highest prices in any series (often 5–20× a common figure). A false positive on a secret figure — attributing a mismatched sale to it — produces the most visible and most damaging price error in the entire system. The `secretSignalConsistent` signal already rewards correct matches with a higher score; it does not justify loosening the gate that determines whether a sale enters the aggregate at all. Coverage for secrets may be lower than for common figures due to lower sales volume, and that is the correct tradeoff. Missing data is preferable to wrong data.

---

## 9. Series Fallback Strategy

A series snapshot exists as a fallback for figures with insufficient individual sale data. It is always labeled as such in the UI — it is never presented as figure-level intelligence.

**When a series snapshot is appropriate:**

- No figure snapshot exists for a specific figure, AND
- A series snapshot exists for that figure's series

A series snapshot is NOT a fallback for poor matching. It is a fallback for low liquidity. If a figure has plenty of sales but matching quality is too low, the correct response is to improve `searchTerms` or `matchThreshold`, not to fall back to series-level.

**Series snapshot computation:**

- Pool qualifying sales across all non-secret figures in the series (each figure using its own search terms and thresholds)
- Exclude secret figures entirely from the pool (their price distribution would skew the series median significantly)
- Apply the same IQR filter and minimum sale count (3) to the pooled set
- `estimatedValueUsd` = median of the pooled non-secret qualifying sales
- Assign `confidence` using the **same rules as figure snapshots**: `high` if 8+ qualifying sales and IQR spread < 50% of median; `low` if 3–7 qualifying sales or high spread

Rationale: confidence reflects data quality (how reliable is this estimate?). Level (`figure` vs `series`) reflects data granularity (how specific is this estimate?). These are separate concepts and must not be coupled. A series snapshot with 120 pooled qualifying sales is high-confidence data; treating it as inherently low-confidence would mislead the UI and the user. Conversely, a series snapshot with 4 pooled sales is correctly low-confidence regardless of level. The `isSeriesEstimate` flag already communicates granularity; `confidence` communicates reliability independently.

**UI communication requirements:**

Any UI surface displaying a series snapshot must make the fallback status explicit. The existing `MarketSnapshot.isSeriesEstimate` getter exists for this purpose. The badge should add a contextual label such as "Series estimate" when `isSeriesEstimate == true`, not just the price. The confidence-based asterisk on sales count (`4 sales*`) already implemented in `MarketSnapshotBadge` signals data reliability independently of level.

**Secret figures and series averages:**

A secret figure can sell for 5–20× the common figure price in the same series. Including secrets in the series median would produce a misleading high estimate for every non-secret figure falling back to the series snapshot. Secrets must never enter the series pool.

---

## 10. Snapshot Skip Reasons

When a snapshot is not generated for a figure or series, the pipeline should record why. This supports future debugging, tooling, and maintainer visibility.

**Design concept: `SnapshotSkipReason`**

This is not implemented in Sprint 2. It is defined here as a design contract so that when the review log (Section 7) and any future skip-reporting tooling are built, they use consistent terminology.

Initial values:

- `INSUFFICIENT_SALES` — Fewer than 3 qualifying sales remained after all filters. The figure exists in `market_metadata.json` and had real search results, but the data did not meet the minimum threshold.
  - Example: a newly released figure with only 2 completed sales in the 30-day window.
- `LOW_MATCH_CONFIDENCE` — Enough sales were retrieved, but none scored above the acceptance threshold after normalization and scoring. The search terms likely returned results for the wrong figure or for inauthentic items.
  - Example: a figure named `Lucky` whose search terms returned mostly unrelated listings, all scoring < 0.75.
- `NO_SEARCH_TERMS` — The figure has an entry in `market_metadata.json` but `searchTerms` is empty. This is an explicit maintainer decision: the figure cannot be safely scoped with keyword search at this time.
  - Example: a figure named `Secret` in a series where all figures have secret variants, making the term too ambiguous to use alone.
- `DISABLED` — The figure entry has `disabled: true` in `market_metadata.json`. The maintainer has explicitly paused snapshot computation for this figure, typically while investigating data quality issues.
  - Example: a figure whose previous snapshot was suspected to contain false-positive sales.

**In the review log (Section 7):** Each figure that produced no snapshot should have its skip reason recorded. This gives the maintainer the information needed to decide whether to act (add terms, raise threshold, fix metadata) or accept the absence.

**Not an error state:** A missing snapshot with a recorded skip reason is a valid and expected pipeline outcome. It means the system is working correctly by refusing to publish uncertain data.

---

## 11. Market Value Display Rules

These rules define the expected UI behavior for all surfaces that display market intelligence. They are a contract between the pipeline (which writes `MarketSnapshot` documents) and the UI (which reads them via `marketSnapshotProvider`).

**Figure snapshot:**

Display when `snapshot.level == SnapshotLevel.figure`.

```
~$42
Based on 18 sales
Rising
```

- Price: `~$` prefix + rounded integer value.
- Sales count: "Based on N sales". Append `*` when `confidence == low`.
- Trend: display only when `trend != unknown`. Omit entirely when `unknown`.

**Series snapshot:**

Display when `snapshot.isSeriesEstimate == true`.

```
~$37
Series Estimate
Based on 12 sales
```

- Price: same format as figure snapshot.
- Always show "Series Estimate" label directly below the price. This is not optional — it communicates data granularity.
- Sales count: "Based on N sales". Apply the same `*` suffix for low confidence.
- Trend: display when `trend != unknown`, same as figure.

**No snapshot:**

Display when the provider returns `null`.

```
No Market Data Yet
```

Do **not** display `$0`, `Unknown`, or `N/A`.

Rationale: `$0` implies the item has no value. `Unknown` and `N/A` suggest data exists but is unavailable. "No Market Data Yet" correctly communicates that the pipeline has not produced intelligence for this figure — either because the figure is new, has low sales volume, or has not yet been added to `market_metadata.json`. It sets accurate expectations and avoids misleading the user.

**Implementation note:** `MarketSnapshotBadge` currently handles the figure and series cases. The "No Market Data Yet" state is handled by the calling widget, which receives `null` from `marketSnapshotProvider` and renders no badge. When this text is shown explicitly (e.g., in a detail sheet), the calling widget is responsible for the copy — not `MarketSnapshotBadge` itself.

---

## Note: Non-figure accessory listings (matcher concern)

Sprint 2 Step 1 review surfaced **validly normalized titles that still describe non-figure products**. These are **not** normalizer exclusions. The title normalizer's job is machine-friendly, human-readable cleanup — not product-type classification.

The matcher (`_catalog_matcher.mjs`) should eventually treat listings whose primary product is one of the following as rejections or manual-review candidates (exact rules TBD in matcher design):

- storage bag
- poster
- sticker
- card
- mouse pad
- towel
- notebook
- wallet
- coin purse

Do **not** add these terms to global exclude lists in `_title_normalizer.mjs` without an explicit matcher design decision. Premature exclusion here would hide data-quality issues from the review log and reduce matcher visibility.

---

## 12. Future Expansion

These are design considerations, not current requirements. They do not require any Sprint 2 changes.

**Additional marketplaces:**

The pipeline is structured around `searchTerms` in `market_metadata.json`. Adding a second marketplace (e.g., Mercari, StockX) means adding a second query function in the pipeline that reads the same metadata. The `market_metadata.json` schema does not need to change — terms are marketplace-agnostic strings. The only new infrastructure is a second API client.

**Improved matching:**

As the catalog grows, some figure names become more common and harder to disambiguate with keyword search alone. Future improvements do not require architectural changes:

- More granular `marketAliases` entries in `market_metadata.json`
- Tighter `searchTerms` with more context tokens
- Raising per-figure `matchThreshold` for problem figures

No machine learning, embeddings, or vector search is needed. The matching problem for designer toys is well-constrained: the brand and series name combination is already highly specific.

**Richer catalog metadata:**

If `retailPrice` is added to `CatalogFigure` in the future, it enables a new sanity-check filter: reject sales priced below 30% of retail (likely damaged or mislabeled) and above 2000% of retail (likely a listing error or speculation that inflates the median).

**Price history:**

When validated as useful, a `price_history/{YYYY-MM-DD}` subcollection can be appended per-run without any model migration. The pipeline computes today's snapshot and writes it to both the top-level document and the subcollection date entry. The `FIRESTORE_MARKET_SNAPSHOTS_SCHEMA.md` documents this reserved path.

---

## F. Trend Detection Algorithm

`MarketTrend` compares two equal time windows within the data set. Default: two 15-day windows within a 30-day query.

- Compute median price for sales in days 1–15 (older window)
- Compute median price for sales in days 16–30 (recent window)
- Require at least 3 qualifying sales in each window to compute a trend; otherwise emit `unknown`
- `rising`: recent median > older median by more than 15%
- `falling`: recent median < older median by more than 15%
- `stable`: difference is within ±15%
- `unknown`: insufficient data in either window, or total qualifying sales < 6

The 15% threshold avoids false rising/falling signals from normal price noise. It can be tuned per-figure via future `market_metadata.json` fields without pipeline changes.

---

## Sprint 2 Implementation Order

1. `_title_normalizer.mjs` — Steps 1–2 of Section 4, plus global/per-figure exclude matching from Section 3
2. `_catalog_matcher.mjs` — scoring signals from Section 5 against catalog JSON
3. `_sales_aggregator.mjs` — IQR filter, median, shared confidence rules (Section 8), and trend detection (Section F)
4. `compute_snapshots.mjs` — orchestrates 1–3 per figure using `market_metadata.json`; records `SnapshotSkipReason` (Section 10) in the review log
5. `push_snapshots.mjs` — writes results to Firestore

Confidence rules are identical for figure and series snapshots. Level and confidence are computed and stored independently. Market value display rules (Section 11) govern how the UI consumes the resulting `MarketSnapshot` documents.

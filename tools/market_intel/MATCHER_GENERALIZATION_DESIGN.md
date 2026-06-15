# Matcher Generalization Design

> **Sprint 2 Step 3E deliverable.** Design review only — no implementation in this document.
>
> Prerequisite audit: [`CATALOG_COVERAGE_REPORT.md`](./CATALOG_COVERAGE_REPORT.md)
>
> Parent spec: [`MATCHING_DESIGN.md`](./MATCHING_DESIGN.md)
>
> Prior review: [`MATCHER_DESIGN_REVIEW.md`](./MATCHER_DESIGN_REVIEW.md)

---

## Problem Statement

Sprint 2 Step 3D catalog coverage audit found:

| Classification | Count | % |
|----------------|------:|--:|
| MATCHABLE | 7 | 0.6% |
| MATCHER_RISK | 1,130 | 98.8% |
| NO_SEARCH_TERMS | 7 | 0.6% |

All 7 matchable figures belong to one series: **THE MONSTERS Big into Energy** (`the_monsters_big_into_energy_vinyl_plush_pendant`).

Root cause: the current matcher's series detection is hardcoded to the literal phrase `"big into energy"`. No listing title for any other series contains this phrase. The `gate:fullSeriesRequired` acceptance gate therefore fails for every non–Big Into Energy figure, regardless of score.

Goal of this document: design a catalog-driven generalized series gate that preserves Big Into Energy behavior and scales to the full 1,144-figure catalog.

---

## Section 1 — Current Architecture Analysis

### 1.1 Matcher decision flow

```
normalizeMarketTitle(rawTitle)
       ↓
matchCatalogFigure(normalizedTitle, context, metadataOverrides?)
       ↓
  [1] detectHardReject(title, tokens, context, ...)
          ├─ seriesMismatch        → score=0, immediate reject
          ├─ crossFigureContamination → score=0, immediate reject
          ├─ wrongFigureName       → score=0, immediate reject
          ├─ secretMismatch        → score=0, immediate reject
          └─ productTypeReject     → score=0, immediate reject
       ↓ (no hard reject)
  [2] computeSignals(title, tokens, context, marketAliasTokens)
          → brandMatch, seriesMatchFull, seriesMatchPartial,
            figureNameMatch, marketAliasMatch, figureIdentityMatch,
            secretSignalConsistent, matchedTokens
       ↓
  [3] computeScore(signals) → weighted sum, capped at 1.0
       ↓
  [4] evaluateAcceptanceGates(signals) → gate failures list
          ├─ gate:brandRequired        if !signals.brandMatch
          ├─ gate:fullSeriesRequired   if !signals.seriesMatchFull
          └─ gate:figureIdentityRequired if !signals.figureIdentityMatch
       ↓
  Accept iff gateFailures.length === 0 AND score >= effectiveThreshold
```

### 1.2 Scoring weights

| Signal | Weight |
|--------|-------:|
| `brandMatch` | 0.15 |
| `seriesMatchFull` | 0.30 |
| `seriesMatchPartial` | 0.15 |
| `figureIdentity` | 0.40 |
| `marketAliasBonus` | 0.10 |
| `secretConsistentBonus` | 0.05 |

Score is capped at 1.0. Default acceptance threshold: **0.75**.

### 1.3 Hard reject conditions

| Code | Condition |
|------|-----------|
| `seriesMismatch` | A conflicting-series distinctive phrase (≥ 3 chars) appears in the title via `hasPhrase` |
| `crossFigureContamination` | Target figure tokens matched AND sibling figure tokens matched |
| `wrongFigureName` | Target figure tokens NOT matched AND sibling figure tokens matched |
| `secretMismatch` | Secret figure without secret indicator, or non-secret figure with secret indicator |
| `productTypeReject` | Tier 1 accessory phrase unconditionally; Tier 2 when figure identity is weak |

### 1.4 `detectSeriesMatchFull` — the Big Into Energy anchor

```javascript
// _catalog_matcher.mjs (current)
const TARGET_SERIES_PHRASE = 'big into energy';       // ← HARDCODED

function detectSeriesMatchFull(title, tokens, context, targetFigureMatched) {
  if (!hasPhrase(title, TARGET_SERIES_PHRASE)) {      // ← CONSTANT CHECK
    return false;                                     // ← blocks every other series
  }

  const hasIpAnchor = context.ipAnchorTokens.some(anchor => ...);
  const hasDistinctSeriesAlias = context.seriesAliasPhrases.some(phrase => ...);

  if (hasIpAnchor || hasDistinctSeriesAlias) return true;
  return targetFigureMatched;
}
```

`TARGET_SERIES_PHRASE` is also injected into **every** `MatcherContext.seriesAliasPhrases[]`
via `buildMatcherContext`, regardless of which series is being matched.

### 1.5 `SERIES_IP_ANCHORS` — hardcoded The Monsters tokens

```javascript
// _catalog_matcher.mjs (current)
const SERIES_IP_ANCHORS = Object.freeze([
  'the monsters',   // ← The Monsters IP-specific
  'monsters',       // ← The Monsters IP-specific
  'labubu',         // ← The Monsters IP-specific (The Monsters character)
]);
```

These tokens are injected into **every** `MatcherContext.ipAnchorTokens[]` for every figure from
every IP, so a Skullpanda listing containing the word `"monsters"` would count as an IP anchor.

### 1.6 Why Big Into Energy works

1. The series `displayName` is *"THE MONSTERS Big into Energy Series-Vinyl Plush Pendant Blind Box"*.
2. Real eBay sellers write titles like *"POP MART THE MONSTERS Big Into Energy Lucky Vinyl Plush Figure"* — containing `"Big Into Energy"`.
3. `detectSeriesMatchFull` checks for `"big into energy"` → passes.
4. IP anchor `"the monsters"` or `"labubu"` also present → `seriesMatchFull = true`.
5. Brand `"pop mart"` or `"popmart"` present → `brandMatch = true`.
6. Figure name token (`"luck"`, `"hope"`, etc.) present → `figureIdentityMatch = true`.
7. All three gates pass → accepted.

### 1.7 Why Have a Seat fails

Real eBay titles for Have a Seat look like:
*"POP MART Labubu Have a Seat SISI Vinyl Plush"*

1. `detectSeriesMatchFull` checks for `"big into energy"` → **not present → returns false**.
2. `seriesMatchFull = false` → `gate:fullSeriesRequired` fires.
3. Score is 0.60 (brand 0.15 + figureIdentity 0.40 + secretBonus 0.05) — below threshold anyway, but moot.
4. **Result: rejected regardless of score, brand match, or figure identity.**

The same logic applies to all 107 other non–Big Into Energy series.

### 1.8 What is reusable

| Component | Status |
|-----------|--------|
| `brandRequired` gate | Catalog-wide safe — keep as-is |
| `figureIdentityRequired` gate | Catalog-wide safe — keep as-is |
| Scoring weights | Catalog-wide appropriate — keep as-is |
| `DEFAULT_MATCH_THRESHOLD` (0.75) | Appropriate — keep as-is |
| Hard rejects (product type, secret, sibling, seriesMismatch) | Catalog-wide safe — keep as-is |
| `normalizeMarketTitle` pipeline | Catalog-wide — keep as-is |
| `extractSeriesDistinctive` | Already catalog-generic — **use as input to fix** |
| `resolveMatcherConflictSeries` (IP-scoped) | Correct design — keep as-is |
| `seriesAliasPhrases[]` field on `MatcherContext` | Keep field; remove BIE injection |
| `ipAnchorTokens[]` field on `MatcherContext` | Keep field; remove hardcoded tokens |

### 1.9 What is Big Into Energy-specific

| Component | Issue |
|-----------|-------|
| `TARGET_SERIES_PHRASE = 'big into energy'` | Hardcoded constant |
| `SERIES_IP_ANCHORS` (`the monsters`, `monsters`, `labubu`) | Hardcoded The Monsters IP tokens |
| `detectSeriesMatchFull` gate check on `TARGET_SERIES_PHRASE` | Single-series anchor |
| BIE phrase injection into all `seriesAliasPhrases[]` | Forces BIE context into every figure |
| `seriesMatchPartial` awards 0.15 only when BIE phrase is present | Non-BIE titles cannot earn partial score |

---

## Section 2 — Target Generalized Architecture

### 2.1 Core substitution

The minimal change that unlocks catalog-wide coverage:

```
Current:
  TARGET_SERIES_PHRASE = 'big into energy'   (hardcoded constant)
  detectSeriesMatchFull requires TARGET_SERIES_PHRASE in title
  ipAnchorTokens always includes 'the monsters', 'monsters', 'labubu'

Target:
  context.seriesDistinctivePhrase = extractSeriesDistinctive(series, ip)
                                    (derived at buildMatcherContext time)
  detectSeriesMatchFull requires context.seriesDistinctivePhrase in title
  context.ipAnchorTokens = [ip.displayName, ...ip.aliases]  (catalog-derived)
```

Everything else stays identical.

### 2.2 `MatcherContext` additions

Add one new field to the existing `MatcherContext` typedef:

```
MatcherContext {
  figureId: string
  seriesId: string
  brandId: string
  isSecret: boolean
  brandTokens: string[]
  figureNameTokens: string[]
  catalogFigureAliasTokens: string[]
  seriesAliasPhrases: string[]          (existing — cleaned of BIE injection)
  ipAnchorTokens: string[]              (existing — cleaned of hardcoded tokens)
  siblingFigureTokens: string[]
  conflictingSeries: { seriesId, phrases[] }[]
  // ↓ NEW
  seriesDistinctivePhrase: string       (from extractSeriesDistinctive; may be empty)
}
```

### 2.3 `buildMatcherContext` changes (design only)

```
BEFORE:
  seriesAliasPhrases = [series.displayName, ...series.aliases, TARGET_SERIES_PHRASE]
  ipAnchorTokens     = [ip.displayName, ...ip.aliases, ...SERIES_IP_ANCHORS]

AFTER:
  seriesDistinctivePhrase = extractSeriesDistinctive(series, ip)
  seriesAliasPhrases      = [series.displayName, ...series.aliases]
                            // TARGET_SERIES_PHRASE injection removed
  ipAnchorTokens          = [ip.displayName, ...ip.aliases]
                            // SERIES_IP_ANCHORS removed
```

### 2.4 `detectSeriesMatchFull` changes (design only)

```
BEFORE:
  function detectSeriesMatchFull(title, tokens, context, targetFigureMatched) {
    if (!hasPhrase(title, TARGET_SERIES_PHRASE)) return false;
    ...
  }

AFTER:
  function detectSeriesMatchFull(title, tokens, context, targetFigureMatched) {
    const phrase = context.seriesDistinctivePhrase;
    // Short or empty distinctive → cannot require it → return false (no series match)
    if (!phrase || phrase.length < 4) return false;
    if (!hasPhrase(title, phrase.toLowerCase())) return false;
    ...
    // remaining IP anchor / alias / figure logic unchanged
  }
```

`seriesMatchPartial` should also be updated:

```
BEFORE:
  seriesMatchPartial = !seriesMatchFull && hasPhrase(title, TARGET_SERIES_PHRASE)

AFTER:
  seriesMatchPartial = !seriesMatchFull
                       && context.seriesDistinctivePhrase.length >= 4
                       && hasPhrase(title, context.seriesDistinctivePhrase.toLowerCase())
```

### 2.5 Acceptance criterion summary

Accept a listing when all of:

1. No hard reject triggered
2. `brandMatch` — brand token present in normalized title
3. `seriesMatchFull` — series distinctive phrase present in title (when phrase ≥ 4 chars)
4. `figureIdentityMatch` — figure name or alias token present in title
5. `score >= 0.75` (default threshold)

For series with empty or very short distinctive (`len < 4`), the `gate:fullSeriesRequired`
cannot be satisfied and the figure will remain `MATCHER_RISK` under the new design as well.
Those series require a separate resolution (Section 3.5).

### 2.6 Big Into Energy backward compatibility

Big Into Energy's distinctive is `"big into energy"` (14 chars, well above the threshold). The
generalized `detectSeriesMatchFull` produces identical behavior for BIE:

```
context.seriesDistinctivePhrase = "big into energy"     (extractSeriesDistinctive)
hasPhrase(title, "big into energy")  === same check as before
```

All existing Big Into Energy tests pass without modification. No regression.

---

## Section 3 — Series Gate Strategy

### 3.1 The core question

Should every series require its distinctive phrase to pass `gate:fullSeriesRequired`?

**Answer: yes, when the phrase is long enough; no when it is too short or empty.**

The full series gate exists to prevent a listing from a different series being credited to the wrong
figure. Without the gate, a listing for *"POP MART Skullpanda Petals in Four Acts 2025"* could
match a figure from *"Skullpanda Everyday Wonderland"* if both figure names were short and no
series phrase was required.

### 3.2 Catalog examples

| Series | `extractSeriesDistinctive` output | Gate strategy |
|--------|-----------------------------------|---------------|
| THE MONSTERS Big into Energy | `"Big into Energy"` (14) | Full phrase required |
| THE MONSTERS Have a Seat | `"Have a Seat"` (11) | Full phrase required |
| THE MONSTERS Exciting Macaron | `"Exciting Macaron"` (16) | Full phrase required |
| Baby Molly Pocket Friends | `"Pocket Friends"` (14) | Full phrase required |
| Baby Molly My Huggable Discovery | `"My Huggable Discovery"` (20) | Full phrase required |
| SKULLPANDA Petals in Four Acts | `"Petals in Four Acts"` (18) | Full phrase required |
| SKULLPANDA Everyday Wonderland | `"Everyday Wonderland"` (18) | Full phrase required |
| DIMOO Moments in Bloom | `"Moments in Bloom"` (16) | Full phrase required |
| aespa Fluffy Club | `"Fluffy Club"` (10) | Full phrase required |
| Twinkle Twinkle Be a Little Star | `"Be a Little Star"` (14) | Full phrase required |
| Zsiga Under the Sun | `"Under the Sun"` (12) | Full phrase required |
| Sonny Angel Animal 1 | `"Animal 1"` (8) | Borderline — risky |
| Sonny Angel Marine | `"Marine"` (6) | Too short — gate risk |
| SMISKI Series 2 | `""` (0) | No gate possible |
| Bikini Bottom Buddies Whimsical Plush Series 2 | `"Whimsical Plush 2"` (17) | Full phrase required |

### 3.3 Length threshold recommendation

| `len(seriesDistinctivePhrase)` | Gate behavior |
|-------------------------------|---------------|
| ≥ 8 chars | `fullSeriesRequired` — phrase must appear in title |
| 4–7 chars | `fullSeriesRequired` — allowed but noted as at-risk in coverage audit |
| < 4 chars | Gate not applicable — series cannot be verified via phrase |
| 0 (empty) | Gate not applicable — `NO_SEARCH_TERMS` or fall back to brand + IP + figure only |

A minimum of 8 is recommended for safe series gate operation. The coverage audit should flag
`shortSeriesDistinctive` for any series below this threshold.

### 3.4 Series aliases

`series.aliases[]` contains alternate ways to refer to the same series. These should participate
as **OR alternatives** in the full series gate:

```
seriesMatchFull = true
  if (hasPhrase(title, seriesDistinctivePhrase))
  OR any(hasPhrase(title, derive(alias, ip)) for alias in series.aliases
         where derivedAlias.length >= 8)
```

This allows e.g. a listing using the shorter alias form (e.g. `"THE MONSTERS Big into Energy Series-"`)
to still pass the gate.

### 3.5 Series without viable distinctive

Series in this category currently:

- `smiski_series_2` — distinctive collapses to empty
- Sonny Angel `animal_series_1`, `marine_series`, etc. — distinctive is a single generic word

**Options (not implementation):**

A. Add a `seriesDistinctiveOverride` field to `series.json` or a market-metadata analog for series.
B. Fall back to brand + IP + figure identity triple without series gate for these specific series.
C. Accept that these series are low-confidence matches and mark them as requiring manual review.

Recommended option B for Sonny Angel/Smiski (they have strong brand signals: "Sonny Angel", "SMISKI")
with the trade-off that they will require very tight figure-identity matching to avoid cross-series hits.

### 3.6 Tradeoffs summary

| Approach | Pro | Con |
|----------|-----|-----|
| Always require phrase | Maximum precision; prevents cross-series false positives | Blocks short-distinctive series |
| Only require when phrase >= 8 chars | Covers 95%+ of catalog with good precision | Short-distinctive series remain at risk |
| Never require phrase (drop gate) | Maximum coverage | High false-positive rate for same-IP figures with similar names |
| Phrase OR alias (OR logic) | Tolerates alternate listing patterns | More surface area for accidental alias matches |

Recommended: **require phrase when >= 8 chars; OR alias when >= 8 chars; no gate when < 4; warn 4–7.**

---

## Section 4 — Cross-Series Contamination

### 4.1 Current mechanism

`detectSeriesMismatch` fires when any phrase from `conflictingSeries` (other series in the
IP-scoped `allSeries`) appears in the listing title. Phrases are derived via
`deriveDistinctiveSeriesPhrases` (existing matcher-internal function).

The snapshot pipeline scopes conflict series to the same IP via `resolveMatcherConflictSeries`,
preventing cross-IP false fires (e.g. `"monsters"` token from a different IP brand).

### 4.2 Catalog contamination examples

| Target series | Same-IP sibling | Contamination risk |
|---------------|-----------------|--------------------|
| Have a Seat | Big Into Energy | Low — titles never mix phrases |
| Have a Seat | Exciting Macaron | Low — phrases are distinct |
| Exciting Macaron | Macaron (hypothetical) | **High** — "Macaron" substring |
| Baby Molly Pocket Friends | Baby Molly My Huggable Discovery | Low |
| Baby Molly Pocket Friends | Baby Molly & Baby Tabby | Low |
| Nanci's Flower Stories | Nanci's Museum of Fantasy | Low — "Flower Stories" vs "Museum" |
| SKULLPANDA Petals in Four Acts | SKULLPANDA Everyday Wonderland | Low |
| Twinkle Twinkle Be a Little Star | Twinkle Twinkle Savor the Moment | Low |
| Twinkle Twinkle Be a Little Star | We are Twinkle Twinkle | Low |
| CRYBABY Cry Me An Ocean | CRYBABY Crying Again | Low — "Ocean" vs "Again" |

Real contamination risk is most likely between series with shared substring tokens
(e.g. a series called "Macaron" vs "Exciting Macaron"). There is no confirmed case of this
in the current 109-series catalog, but it is a structural risk as the catalog grows.

### 4.3 Generalized conflict phrase derivation (design only)

After generalization, `deriveDistinctiveSeriesPhrases` should align with
`extractSeriesDistinctive` so conflict detection uses the same phrase derivation
as the series gate. Currently they may diverge (one uses the boilerplate-strip algorithm,
the other may not).

Aligned approach:

```
For each sibling series in same IP:
  conflictPhrase = extractSeriesDistinctive(siblingSeriesRow, ip)
  if conflictPhrase.length >= 5:
    add to conflict phrase list
```

Minimum length **5** for conflict phrases (slightly lower than series gate at 8) because
precision in rejection is preferable to precision in acceptance.

### 4.4 Hard reject aggressiveness

Current behavior: if ANY conflict phrase appears in the title, hard-reject immediately (score = 0).

This is correct. The presence of another series' distinctive phrase in a listing almost certainly
means the listing is for the other series, not the target. False fires from this hard reject
should be rare with proper phrase length thresholds.

Exception: if the conflict phrase is a substring of the target phrase (e.g. `"Macaron"` within
`"Exciting Macaron"`), the conflict detection must use `hasPhrase` (exact phrase match), not
substring. This is already the case in the current implementation.

### 4.5 IP anchor contamination

Current `SERIES_IP_ANCHORS` injects The Monsters tokens into every figure's `ipAnchorTokens[]`.
After generalization this becomes catalog-derived, which fixes a secondary contamination risk:

- A Skullpanda listing containing the word `"monsters"` would no longer count as an IP anchor match.
- IP anchors for Skullpanda will be `["Skullpanda"]` only.
- IP anchors for The Monsters will be `["The Monsters", "Labubu", ...]` (from catalog).

### 4.6 Recommendations

1. Keep IP-scoped conflict detection — already correct.
2. Align `deriveDistinctiveSeriesPhrases` with `extractSeriesDistinctive`.
3. Minimum phrase length 5 for conflict phrases.
4. Hard reject remains unconditional when conflict phrase fires.
5. After generalization, run contamination test for all The Monsters sub-series
   (Have a Seat / Exciting Macaron / Big Into Energy / Classic / Mischief Diary / etc.)
   to confirm cross-series hard-reject correctness.

---

## Section 5 — Figure Identity Strategy

### 5.1 Current state

Figure identity is derived from:

1. `figureNameTokens` — tokenized `figure.displayName`
2. `catalogFigureAliasTokens` — from `figure.aliases[]` in seed catalog
3. `marketAliasTokens` — from `metadata.marketAliases` in `market_metadata.json`

`figureIdentityMatch = figureNameMatch OR marketAliasMatch`

Gate `gate:figureIdentityRequired` fires when neither is found.

### 5.2 Short-name figure inventory

The coverage audit identified 109 figures with `ambiguousFigureName` warning:
single token, ≤ 5 chars, no `marketAliases`, no `figure.aliases[]`.

Examples from Big Into Energy (all 7 are in this category):

| Figure | `displayName` | Token count | Length |
|--------|---------------|-------------|--------|
| Luck | `"Luck"` | 1 | 4 |
| Hope | `"Hope"` | 1 | 4 |
| Love | `"Love"` | 1 | 4 |
| Id | `"Id"` | 1 | 2 |
| Serenity | `"Serenity"` | 1 | 8 |
| Loyalty | `"Loyalty"` | 1 | 7 |
| Happiness | `"Happiness"` | 1 | 9 |

`"Luck"`, `"Hope"`, `"Love"`, `"Id"` are the critical short-name cases. eBay sellers write
`"Lucky"` (not `"Luck"`), which is why the current Big Into Energy matcher requires
`marketAliases: ["lucky"]` in `market_metadata.json` to pass `figureIdentityMatch`.

### 5.3 Short-name handling recommendation

**The figure identity gate must remain required.** Dropping it would create a two-gate system
(brand + series) that is insufficient for catalog-scale matching — too many figures per series
would produce false positives.

Extension hierarchy (preferred first):

1. **`figure.aliases[]` in seed catalog** — permanent identity aliases; maintained with the catalog.
   Preferred for common marketplace name variants (e.g. `"Lucky"` for `"Luck"`).
2. **`metadata.marketAliases` in `market_metadata.json`** — exception overrides for
   marketplace-specific variants not appropriate for the catalog.
3. **Token length special-casing** — not recommended; adds unpredictable edge cases.

The current `"Lucky"` alias for `"Luck"` is in `metadata.marketAliases` (per Luck's existing
metadata entry). After metadata migration, these should move to `figure.aliases[]` in the seed.

### 5.4 Secret figures

121 figures carry `isSecret: true`. The `secretConsistency` mechanism is catalog-wide appropriate:

- Secret figures reject listings without `secret`, `chase`, `hidden`, `隐藏`, `1/144`, or `1:72`.
- Non-secret figures reject listings with those indicators.

This protects against pricing a standard figure using secret/chase sold prices (which are
substantially higher). No change recommended.

### 5.5 Threshold recommendation

Keep `DEFAULT_MATCH_THRESHOLD = 0.75`. The audit's 109 `ambiguousFigureName` warnings are
at the warning level (not a structural blocker); they will still pass the gate when a market alias
or catalog alias resolves figure identity.

---

## Section 6 — Coverage Projection

### 6.1 Methodology

Coverage projection uses the following inputs:

- 1,144 total figures across 109 series
- `extractSeriesDistinctive` output distribution (known from audit)
- 7 `NO_SEARCH_TERMS` figures (Smiski Series 2) — remain blocked regardless
- 109 `ambiguousFigureName` figures — remain MATCHABLE with warnings after generalization
- 121 `isSecret` figures — remain MATCHABLE with secretConsistency warning after generalization

### 6.2 Scenarios

**Current baseline:** 7 / 1,144 = **0.6%**

**Best case** — all series with `extractSeriesDistinctive >= 4` chars become matchable:

Estimation: approximately 100 of 109 series have a distinctive phrase of at least 4 chars.
That covers ~1,050–1,080 figures.

Remaining blockers: 7 Smiski Series 2 (empty distinctive) + ~10–15 Sonny Angel figures
with short distinctives (6 chars) + a small number with incomplete catalog context.

Projected: **~1,040–1,080 / 1,144 (91–94%)**

**Expected case** — phrase >= 8 chars threshold applied; partial passes with warnings:

Estimation: ~95 series have distinctive >= 8 chars; 5–8 series (Sonny Angel, Smiski Bath/Toilet/Yoga,
Bikini Bottom Buddies) fall in the 4–7 char borderline range. Those remain MATCHER_RISK under
the stricter threshold.

Projected: **~920–980 / 1,144 (80–86%)**

**Conservative case** — phrase >= 8 + figure identity warning figures require human review:

Figures with `ambiguousFigureName` warning (109) without any marketAliases will
fail `gate:figureIdentityRequired` even after series gate generalization. They are still
MATCHABLE per the audit classification, but may fail the gate at runtime with real listings.

Projected matchable at production quality: **~750–870 / 1,144 (65–76%)**

| Scenario | Projected matchable | % |
|----------|--------------------:|--:|
| Current | 7 | 0.6% |
| Best case (>= 4 chars) | ~1,040–1,080 | 91–94% |
| Expected (>= 8 chars) | ~920–980 | 80–86% |
| Conservative (8 chars + alias coverage) | ~750–870 | 65–76% |

### 6.3 Remaining structural blockers after generalization

| Blocker | Figures | Resolution path |
|---------|--------:|-----------------|
| Smiski Series 2 empty distinctive | 7 | Add `series.aliases[]` with explicit distinctive; or brand-level fallback design |
| Sonny Angel short distinctives ("Marine", "Animal 1") | ~60 | Accept lower confidence; add brand-level series fallback term |
| Figures with no market aliases for short names | ~109 | Add `figure.aliases[]` in seed catalog or `marketAliases` in metadata |
| Non-POP MART brands (Rolife, Dreams Inc.) without brand aliases | varies | Verify `brand.aliases[]` populated; Rolife has no aliases currently |

---

## Section 7 — Migration Plan

### Overview

The migration path is designed to be incremental and regression-safe. No sprint should break
the existing Big Into Energy test suite.

### Step A — Prepare `MatcherContext` for per-series phrase

Modify `buildMatcherContext` to:

1. Accept `extractSeriesDistinctive(series, ip)` output as `seriesDistinctivePhrase`.
2. Remove `TARGET_SERIES_PHRASE` from `seriesAliasPhrases[]` injection.
3. Remove `SERIES_IP_ANCHORS` from `ipAnchorTokens[]` injection.
4. Derive `ipAnchorTokens` from `[ip.displayName, ...ip.aliases]` only.

**Regression gate:** `_catalog_matcher.test.mjs` must pass 100%. Since Big Into Energy's
`extractSeriesDistinctive` returns `"Big into Energy"`, context shape changes but BIE behavior
is identical.

### Step B — Generalize `detectSeriesMatchFull`

Replace the hardcoded `TARGET_SERIES_PHRASE` check with `context.seriesDistinctivePhrase`:

```
if (!phrase || phrase.length < 4) return false
if (!hasPhrase(title, phrase)) return false
// remaining IP anchor / alias / figure logic unchanged
```

Update `seriesMatchPartial` to use the same phrase.

**Regression gate:** All existing matcher tests pass. BIE behavior identical.

### Step C — Re-run catalog coverage audit

Run `node tools/market_intel/catalog_coverage_audit.mjs` and compare:

- Expected: MATCHABLE count jumps from 7 to ~920–980
- MATCHER_RISK count should drop proportionally
- `NO_SEARCH_TERMS` (7 Smiski) unchanged
- New audit warnings: series with short distinctive (4–7 chars) flagged

Document delta in an updated `CATALOG_COVERAGE_REPORT.md`.

### Step D — Validate Big Into Energy regression suite

Run the full matcher test suite (`_catalog_matcher.test.mjs`). All 30+ cases must pass with
identical classification, scores, and reject reasons as before generalization.

If any Big Into Energy test regresses: stop. Revert. Investigate context injection differences.

### Step E — Expand fixture coverage

Add realistic fixture listing titles for newly matchable series:

- The Monsters Have a Seat — `"POP MART Labubu Have a Seat SISI Vinyl Plush"` (already in fixture, needs matcher to pass)
- Skullpanda Petals in Four Acts — `"POP MART SKULLPANDA Petals in Four Acts [FigureName]"`
- Baby Molly Pocket Friends — `"POP MART Baby Molly Pocket Friends [FigureName]"`
- DIMOO Moments in Bloom — `"POP MART DIMOO Moments in Bloom [FigureName]"`

Run `compute_snapshots.mjs --snapshot-debug` for these figures to confirm end-to-end pipeline.

### Step F — Cross-series contamination review

For The Monsters IP (highest sibling-series density in catalog):

Run the debug matcher against a set of Have a Seat listing titles and confirm they do not
accidentally match Big Into Energy figures, and vice versa. Same test for:

- Exciting Macaron vs Have a Seat
- Baby Molly Pocket Friends vs My Huggable Discovery vs Baby Tabby

Confirm `detectSeriesMismatch` correctly fires for wrong-series titles.

### Step G — Update catalog coverage tooling

Update `_catalog_coverage_audit.mjs`:

1. Remove `BIG_INTO_ENERGY_SERIES_ID` exemption from `fullSeriesPhraseBias` detection.
2. Replace with a general `shortSeriesDistinctive` structural risk check (phrase < 8 chars).
3. Re-run full audit and update `CATALOG_COVERAGE_REPORT.md`.

### Step H — Document and commit

Update `docs/TECH_DEBT.md` Matcher Coverage Validation entry to reflect post-generalization
coverage numbers and clear the "primarily validated against Big Into Energy" flag.

---

## Section 8 — Risks

### 8.1 Big Into Energy regression

**Severity: High**

The Big Into Energy test suite is the only validated baseline. Any change to `detectSeriesMatchFull`
or `buildMatcherContext` could inadvertently shift BIE behavior.

**Mitigation:**
- Run `_catalog_matcher.test.mjs` as the first gate in every step.
- Explicitly assert that BIE `seriesDistinctivePhrase` equals `"big into energy"` (a new test).
- Roll back immediately on any BIE regression; do not proceed until resolved.

### 8.2 False positives from short series distinctives

**Severity: High**

Series with a very short distinctive (e.g. `"Marine"` for Sonny Angel Marine Series) may match
listings for entirely unrelated items containing that word. A listing for *"POP MART Space Molly
series marine diver figure"* could pass the series gate for a Sonny Angel Marine figure.

**Mitigation:**
- Apply minimum phrase length of 8 characters for mandatory series gate.
- For phrases 4–7 chars, emit a structural audit warning but do not classify as MATCHABLE — require
  explicit per-series review before enabling.
- For phrases < 4 chars or empty, leave series gate unenforced; rely on brand + figure identity
  matching only (lower precision, higher recall).

### 8.3 Cross-series contamination within same IP

**Severity: High for The Monsters IP; Medium elsewhere**

The Monsters catalog has 8+ series. After generalization, each series will derive its own phrase
from `extractSeriesDistinctive`. Conflict detection between sibling series depends on the extracted
phrases being sufficiently distinct from each other.

**Mitigation:**
- Run Steps F (cross-series review) before any production deployment.
- Add integration tests confirming that Have a Seat titles do not match BIE figures and vice versa.
- Validate that `extractSeriesDistinctive` output for all The Monsters series is distinct (no
  overlapping phrases in conflict list).

### 8.4 Alias inflation

**Severity: Medium**

`series.aliases[]` may contain overly broad aliases that create false phrase matches. For example,
if a series alias is simply `"Series"`, the phrase gate would be satisfied by almost any listing.

**Mitigation:**
- Only use aliases where `len(extractSeriesDistinctive(alias, ip)) >= 8`.
- Audit `series.aliases[]` for any generic or very short alias values before enabling them as
  fallback series phrases.
- The catalog's current aliases are generally specific (e.g. `"THE MONSTERS Big into Energy Series-"`)
  and unlikely to cause inflation, but this should be verified during Step C.

### 8.5 Non-POP MART brand coverage

**Severity: Medium**

Dreams Inc. (Sonny Angel, Smiski), Rolife, tntspace, and toptoy are in the catalog. Brand token
derivation is already catalog-driven, but non-POP MART brands may have weaker marketplace presence
under the brand name — sellers may not write `"Dreams Inc."` in eBay titles.

**Mitigation:**
- Verify `brand.aliases[]` for all non-POP MART brands.
- Rolife currently has no `aliases[]` — this should be flagged as a coverage risk.
- Smiski and Sonny Angel carry strong brand recognition independently of `"Dreams Inc."`;
  their brand representation in titles (`"Smiski"`, `"Sonny Angel"`) should be in
  `brand.aliases[]` for the brand gate to fire.

### 8.6 Smiski Series 2 — empty distinctive

**Severity: Low-Medium**

Smiski Series 2 (`smiski_series_2`) has 7 figures with `NO_SEARCH_TERMS` because
`extractSeriesDistinctive` collapses `"SMISKI Series 2"` to empty. This is a search-term
derivation issue, not a matcher issue, but it affects coverage.

**Mitigation:**
- Add `series.aliases[]` for Smiski Series 2 with an explicit distinctive value, e.g.
  `["Smiski Series 2", "SMISKI Series 2"]`.
- The derivation function will then find the alias and return `"Smiski Series 2"` as the
  distinctive phrase (it already tries aliases when the primary name strips to < 3 chars).
- This fix belongs in the search-term derivation sprint (not the matcher generalization sprint),
  but should be noted here as a downstream blocker.

### 8.7 IP token scope after SERIES_IP_ANCHORS removal

**Severity: Low**

Removing `SERIES_IP_ANCHORS` means that The Monsters figures will no longer automatically benefit
from `"monsters"` and `"labubu"` as bonus IP anchors — they will only see what is in
`ip.displayName` and `ip.aliases[]` for `the_monsters` IP.

**Mitigation:**
- Verify `ip.aliases[]` for `the_monsters` contains `"Labubu"` (and optionally `"Monsters"`).
- If these are missing from the seed, add them to `ips.json`.
- BIE tests will catch regressions immediately if IP anchors are lost.

---

## Summary — Design Decisions

| Decision | Recommendation |
|----------|----------------|
| Replace `TARGET_SERIES_PHRASE` with `context.seriesDistinctivePhrase` | Yes |
| Remove `SERIES_IP_ANCHORS`; use catalog IP aliases | Yes |
| Minimum phrase length for full series gate | 8 chars (warn at 4–7) |
| Series aliases as OR alternatives in gate | Yes, with same 8-char minimum |
| Short-distinctive fallback (brand + IP + figure only) | Yes, for series < 4 chars |
| Keep `gate:fullSeriesRequired` as mandatory acceptance gate | Yes |
| Keep `gate:brandRequired` | Yes |
| Keep `gate:figureIdentityRequired` | Yes |
| Keep scoring weights | Yes |
| Keep `DEFAULT_MATCH_THRESHOLD = 0.75` | Yes |
| Keep IP-scoped conflict detection (`resolveMatcherConflictSeries`) | Yes |
| Align `deriveDistinctiveSeriesPhrases` with `extractSeriesDistinctive` | Yes |
| Drop `figureIdentityRequired` gate for short-name figures | No |
| Change threshold | No |
| Add new hard rejects | No |
| Migration gated by BIE regression suite | Yes — mandatory |

**Expected post-generalization coverage:** ~80–86% of catalog (expected case, phrase >= 8 chars)
with a path to 91–94% when short-distinctive series receive catalog aliases.

---

## Pre-implementation checklist

Before any code is written for Sprint 2 Step 3E implementation:

- [ ] Verify `ip.aliases[]` for `the_monsters` includes `"Labubu"` and other marketplace tokens
- [ ] Verify `brand.aliases[]` for `dreams_inc` includes `"Smiski"` and `"Sonny Angel"`
- [ ] Verify `brand.aliases[]` for `rolife` — add if empty
- [ ] Confirm `extractSeriesDistinctive` output for all The Monsters sibling series is distinct
- [ ] Add one new matcher test: assert `seriesDistinctivePhrase` for BIE = `"big into energy"`
- [ ] Decide minimum phrase length threshold (recommend 8) and document in test
- [ ] Review Smiski Series 2 catalog fix (aliases) before or concurrent with matcher change
- [ ] Review Sonny Angel short-distinctive strategy before production deployment

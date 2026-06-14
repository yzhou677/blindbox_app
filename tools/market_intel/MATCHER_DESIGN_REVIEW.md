# Market Intelligence — Matcher Design Review

> **Sprint 2 Step 2 deliverable.** Design and test matrix only — **no implementation**.
>
> Parent spec: [`MATCHING_DESIGN.md`](./MATCHING_DESIGN.md) Sections 5–6.
>
> Prerequisite (frozen): [`_title_normalizer.mjs`](./_title_normalizer.mjs) Step 1 + Step 1.1.

---

## Design stance

The matcher is the highest-risk component in Market Intelligence. A false positive writes a wrong price into `estimatedValueUsd` for every future user. A false negative simply omits a sale from the aggregate.

**Priority: FALSE NEGATIVE > FALSE POSITIVE**

| Outcome | Acceptable? |
|---------|-------------|
| Reject a legitimate but oddly worded sale | Yes |
| Accept a sale for the wrong figure | No |
| Reject a storage bag, poster, or multi-figure bundle mislabeled as single Lucky | Yes (required) |
| Miss coverage on a low-liquidity figure | Yes |

Coverage is secondary. Accuracy is primary.

---

## Section 1 — Inputs

The matcher runs **after** title normalization and **after** global/per-figure exclude detection (`findExcludeTerm`). Listings that are already excluded never reach scoring.

### Input A — Normalized title string

A single lowercase string produced by `normalizeMarketTitle(rawTitle)`.

**Properties:**

- Structural separators unified to spaces; marketing/shipping noise stripped
- Brand, series, figure, secret/chase, and size tokens preserved
- Non-Latin script preserved (CJK, kana, hangul)

**Examples:**

```
pop mart the monsters lucky big into energy figure
pop mart labubu have a seat lucky secret figure
pop mart twinkle twinkle wonderful journey storage bag
pop mart the monsters lucky 幸运 secret chase 隐藏
```

**Not passed to matcher:** raw eBay title, HTML, price, quantity, sale date (those belong to downstream aggregation filters).

---

### Input B — Catalog figure (target)

One figure record from the catalog bundle (`tools/seed/figures.json` + related brand/IP/series docs). The matcher scores a normalized title **against a specific target figure** chosen by the pipeline (the figure whose `searchTerms` retrieved this sale).

**Fields used by matcher:**

| Field | Source | Matcher use |
|-------|--------|-------------|
| `figureId` | `CatalogFigure.id` | Identity of target; sibling lookup key |
| `displayName` | `CatalogFigure.displayName` | Primary figure-name token(s) after normalization |
| `aliases` | Catalog figure aliases (when present) | Additional figure-name tokens; **note:** seed figures currently have no per-figure `aliases` — matcher must also read series/IP/brand aliases and `marketAliases` |
| `seriesId` | `CatalogFigure.seriesId` | Sibling figure enumeration; series mismatch detection |
| `seriesName` | `CatalogSeries.displayName` + `CatalogSeries.aliases` | Series token set for `seriesMatch` |
| `brandId` | `CatalogFigure.brandId` | Brand token set via `CatalogBrand.displayName` + `aliases` |
| `isSecret` | `CatalogFigure.isSecret` | Gates `secretSignalConsistent` |

**Reference target for this review — Lucky (Big Into Energy):**

| Field | Value |
|-------|-------|
| `figureId` | `the_monsters_big_into_energy_vinyl_plush_pendant_luck` |
| `market_metadata` key | `lucky_big_into_energy_popmart` |
| `displayName` | `Luck` → normalized token **`luck`** |
| `seriesId` | `the_monsters_big_into_energy_vinyl_plush_pendant` |
| `seriesName` | `THE MONSTERS Big into Energy Series-Vinyl Plush Pendant Blind Box` |
| `series aliases` | `the monsters big into energy vinyl plush pendant`, … |
| `brandId` | `pop_mart` → tokens **`pop mart`**, **`popmart`** |
| `isSecret` | `false` |
| **Sibling figures (same series)** | Hope, Serenity, Loyalty, Happiness, Love, **Id** (`isSecret: true`) |

**Critical catalog/market naming gap:** eBay sellers overwhelmingly write **Lucky**, not catalog **Luck**. The matcher **must** treat `marketAliases` (and proposed catalog alias `lucky`) as first-class figure-name tokens. Without this, figure-level matching for this SKU will false-negative on most real titles.

---

### Input C — `market_metadata.json`

Per-figure admin overrides loaded alongside the catalog entry for the target figure.

**Fields used:**

| Field | Type | Matcher use |
|-------|------|-------------|
| `marketAliases` | `string[]` | Extra figure/series search tokens not in catalog (`lucky`, `labubu lucky`, CJK shorthand) |
| `matchThreshold` | `number \| null` | Per-figure acceptance cutoff; falls back to global default when `null` |
| `excludeTerms` | `string[]` | Applied **before** matcher (normalizer pipeline); not re-scored |
| `searchTerms` | `string[]` | Not used inside matcher — only determines which sales are fetched |
| `disabled` | `boolean` | Skips entire figure before matcher runs |

**Current seed entry (`lucky_big_into_energy_popmart`):**

```json
{
  "searchTerms": ["POP MART Lucky Big Into Energy", "POPMART LUCKY BIG ENERGY"],
  "excludeTerms": ["custom", "lot", "bootleg", "replica"],
  "marketAliases": [],
  "matchThreshold": null
}
```

**Pre-implementation action:** populate `marketAliases` with at least `lucky`, and consider `labubu`, `ラッキー`, `幸运` before running production snapshots.

---

### Matcher output (design contract)

For each `(normalizedTitle, targetFigure, metadata)` tuple:

```typescript
{
  score: number,           // 0.0 – 1.0, deterministic
  accepted: boolean,       // score >= effectiveThreshold && !hardRejected
  hardRejected: boolean,
  hardRejectReason?: string,
  signals: { ... },        // auditable booleans per signal
  effectiveThreshold: number
}
```

Every rejection must be explainable from signal booleans — no opaque scoring.

---

## Section 2 — Scoring Signals

Scoring is a **deterministic weighted sum of binary signals**, not ML. Weights below sum to **1.0** at full match.

### Positive signals

| Signal | Weight | Purpose | Match rule | Examples (target: Lucky) |
|--------|--------|---------|------------|--------------------------|
| `brandMatch` | **0.15** | Confirm listing is for the expected brand | Whole-token or contiguous phrase match on normalized brand tokens: `pop mart`, `popmart` | `pop mart … lucky` ✓ · `popmart …` ✓ · `dreams inc …` ✗ |
| `seriesMatch` | **0.30** | Confirm listing belongs to target series, not another IP/line | **Full match (0.30):** title contains **`big into energy`** AND at least one IP/series anchor: **`the monsters`**, **`monsters`**, **`labubu`**, or a series alias token set. **Partial (0.15):** only `big into energy` without IP anchor — insufficient alone for acceptance | `… big into energy … labubu … lucky` ✓ full · `… big into energy lucky` ✓ full (IP implied by search scope) · `… have a seat lucky` ✗ series mismatch (hard reject, see §3) |
| `figureNameMatch` | **0.40** | Strongest positive — confirms the specific figure | Whole-token match on normalized `displayName` (`luck`) **or** catalog figure alias tokens | `… luck vinyl` ✓ · `… lucky …` ✓ only if `lucky` registered as alias/marketAlias |
| `marketAliasMatch` | **0.10** | Captures marketplace shorthand absent from catalog | Whole-token match on any `marketAliases` entry not already counted by `figureNameMatch`; capped — does not stack duplicate credit for the same token | `… labubu lucky …` when `labubu` is market alias ✓ · adds +0.10 only when alias token matched |
| `secretSignalConsistent` | **+0.05** bonus | Quality multiplier when secret language aligns with catalog | If `isSecret == false`: title must **not** contain secret indicators (`secret`, `chase`, `hidden`, `隐藏`, `1/144`, `1:72`). If `isSecret == true`: title **must** contain at least one secret indicator. Bonus applied only when consistent | Lucky (`isSecret: false`) + `… lucky figure` → +0.05 · Lucky + `… secret chase` → **hard reject** (not a penalty score) |

**Maximum score:** `0.15 + 0.30 + 0.40 + 0.10 + 0.05 = 1.00`

**Minimum score for a valid single-figure sale:** requires **`brandMatch` + `seriesMatch` (≥0.15 partial) + (`figureNameMatch` OR `marketAliasMatch`)**. A title with brand + series but **no** figure name caps at **0.45** → reject.

### Signal interaction rules

1. **`figureNameMatch` is mandatory for acceptance** — even if total score could theoretically reach 0.75 via aliases alone, do not accept without a confirmed target-figure token.
2. **`seriesMatch` partial (0.15) alone is never sufficient** — prevents series-level sales from entering a figure aggregate.
3. **`marketAliasMatch` does not compensate for series mismatch** — if hard series reject fires, score is irrelevant.
4. **IP token alone (`labubu`) is not a figure match** — Labubu appears across many series; it supports `seriesMatch` context only unless paired with figure token.

---

## Section 3 — Hard Reject Signals

Hard rejects fire **before or instead of** threshold comparison. When triggered: `hardRejected: true`, `score: 0`, `accepted: false`.

### Hard reject catalog

| Signal | Trigger | Example | Rationale |
|--------|---------|---------|-----------|
| **`crossFigureContamination`** | Title contains whole-token match for **≥2 distinct figure names** within the target series sibling set (including target) | `lucky hope serenity bundle` targeting **Luck** | Ambiguous multi-figure sale — cannot attribute price to one figure |
| **`crossFigureContamination`** (variant) | Title contains target figure token **and** any **other** sibling figure token | `… lucky hope …` targeting **Luck** | Same — even two names is enough |
| **`wrongFigureName`** | Title contains a **different** sibling figure name as the **primary** sold item without target token | `pop mart big into energy hope figure` targeting **Luck** | Wrong SKU |
| **`seriesMismatch`** | Title contains a **conflicting series token set** from catalog (different `seriesId`) with confidence | `… have a seat lucky secret …` targeting **Luck / Big Into Energy** | Different product line |
| **`secretMismatch`** | `isSecret == false` and title contains secret indicator tokens | `… lucky secret chase 隐藏` targeting **Luck** | Would inflate common figure with secret pricing |
| **`secretMismatch`** | `isSecret == true` and title lacks any secret indicator | `… id vinyl plush` targeting **Id** (secret) without `secret`/`1:72` | Likely common mislabel or wrong variant |
| **`productTypeReject`** | Title matches non-figure product-type lexicon (§4) as primary product | `… storage bag` · `… poster print` | Not a figure sale — see §4 |
| **`preExcluded`** | `findExcludeTerm` already matched | `… lot of 6` · `… pin only` | Handled upstream; matcher returns early |

### Hard reject vs score penalty

| Condition | Verdict | Why |
|-----------|---------|-----|
| Multiple sibling figure names | **Hard reject** | No score band is safe — ambiguity is structural |
| Wrong sibling figure, sole name | **Hard reject** | Accepting would assign Hope's sale to Luck |
| Series mismatch (distinct series tokens) | **Hard reject** | Keyword overlap on `lucky` across series is common |
| Secret language on non-secret target | **Hard reject** | Price corruption risk dominates |
| Missing secret language on secret target | **Hard reject** | Same |
| Brand missing (`brandMatch == false`) | **Score penalty only** | Score capped ~0.70 — fails threshold, not hard reject |
| Series partial without figure | **Score penalty only** | 0.45 — fails threshold |
| Unusual but single-figure wording | **Score penalty only** | Review log candidate, not auto-accept |

**Do not downgrade hard rejects to penalties** to improve coverage. The review log (MATCHING_DESIGN §7) is the path for legit edge cases.

---

## Section 4 — Accessory / Product-Type Rejection

Step 1 review confirmed: titles like `… wonderful journey storage bag` normalize cleanly but describe **non-figure products**. This is **matcher responsibility**, not normalizer responsibility (see MATCHING_DESIGN note).

### Strategy

**Two-tier lexicon — word-boundary matching on normalized title.**

#### Tier 1 — Hard reject (high confidence non-figure)

Already partially covered by normalizer global excludes; matcher repeats as defense-in-depth for titles that slip through.

| Term / phrase | Notes |
|---------------|-------|
| `storage bag` | Observed in audit corpus |
| `pin only` | Normalizer exclude + matcher |
| `keychain` / `key chain` | Normalizer exclude + matcher |
| `phone strap` | Normalizer exclude |
| `bag charm` | Normalizer exclude |
| `lanyard` | Normalizer exclude |
| `display case` | Normalizer exclude — case with figure is still not a figure sale |
| `poster` | Print merchandise |
| `sticker` | |
| `mouse pad` | |
| `notebook` | |
| `wallet` | |
| `coin purse` | |

#### Tier 2 — Hard reject when paired with weak figure signal

Terms that sometimes appear innocuously but usually indicate accessories when **figureNameMatch is weak or absent**:

| Term | Example |
|------|---------|
| `badge` | `… macaron lanyard badge holder` |
| `pin` (without `figure`) | `… enamel pin` — reject if no `figure`/`plush`/`vinyl` product noun |
| `card` | `… art card` |
| `folder` | |
| `towel` | |

**Implementation rule:** Tier 1 → unconditional hard reject when term matches. Tier 2 → hard reject when term matches **and** `figureNameMatch == false`.

### Explicit non-goals

- We do **not** need exhaustive product-type coverage.
- Missing an unusual accessory listing is **acceptable**.
- Accepting a storage bag sale as a Lucky figure sale is **not acceptable**.
- Do **not** move these terms into `_title_normalizer.mjs` global excludes without matcher telemetry — keep normalized titles visible in review log.

### Corpus evidence (Step 1 normalized output)

| Normalized title fragment | Matcher action |
|---------------------------|----------------|
| `… storage bag` | Hard reject `productTypeReject` |
| `… bag charm key ring` | Hard reject (Tier 1) |
| `… phone strap charm accessory` | Hard reject |
| `… pin only enamel badge no figure` | Pre-excluded + hard reject |
| `… lanyard badge holder` | Hard reject |

---

## Section 5 — Example Matrix

**Target figure:** Luck (`displayName`) / marketplace **Lucky** — Big Into Energy series  
**Effective threshold for matrix:** **0.80** (recommended per-figure override for ambiguous short name; see §6)  
**Global default:** 0.75

Scoring uses §2 weights. `HR` = hard reject (score 0).

| # | Normalized title (representative) | Score | Accepted @0.80 | Explanation |
|---|----------------------------------|-------|----------------|-------------|
| 1 | `pop mart the monsters lucky big into energy figure` | 1.00 | ✓ | Full brand + series + figure (`lucky` via market alias) + secret consistent bonus |
| 2 | `pop mart lucky big into energy figure` | 0.95 | ✓ | Brand + full series + figure + bonus; no separate marketAlias increment |
| 3 | `popmart the monsters lucky big into energy figure` | 1.00 | ✓ | `popmart` brand alias |
| 4 | `pop mart labubu big into energy lucky confirmed` | 1.00 | ✓ | Labubu supports series; lucky matches figure |
| 5 | `pop mart the monsters luck big into energy vinyl plush` | 0.95 | ✓ | Catalog token `luck` (displayName) |
| 6 | `pop mart the monsters lucky big into energy vinyl plush pendant open box` | 0.95 | ✓ | Strong single-figure sale despite open box language |
| 7 | `pop mart × モンスターズ ラブブ ラッキー big into energy` | 0.95 | ✓ | CJK market aliases + series + brand |
| 8 | `pop mart the monsters ラッキー big into energy vinyl plush` | 0.95 | ✓ | Japanese alias for Lucky |
| 9 | `pop mart 大能量 系列 lucky 盲盒 确认款` | 0.90 | ✓ | Mixed CN/EN; series + figure present |
| 10 | `pop mart the monsters lucky 幸运 big into energy` | 0.95 | ✓ | CN lucky glyph as market alias |
| 11 | `the monsters labubu lucky big into energy figure` | 0.70 | ✗ | Missing brand token — fails threshold & mandatory brand gate |
| 12 | `pop mart big into energy figure` | 0.45 | ✗ | Series-only — no figure name |
| 13 | `pop mart the monsters big into energy vinyl plush pendant` | 0.45 | ✗ | Series-only blind box listing |
| 14 | `pop mart the monsters vinyl plush pendant` | 0.15 | ✗ | Brand only |
| 15 | `pop mart lucky figure` | 0.55 | ✗ | Figure + brand, no series anchor |
| 16 | `lucky big into energy pop mart figure` | 0.95 | ✓ | Token order irrelevant |
| 17 | `pop mart big into energy hope figure` | HR | ✗ | `wrongFigureName` — Hope sibling, no Luck token |
| 18 | `pop mart big into energy lucky hope serenity bundle` | HR | ✗ | `crossFigureContamination` — three sibling names |
| 19 | `pop mart big into energy lucky hope` | HR | ✗ | `crossFigureContamination` — two sibling names |
| 20 | `pop mart labubu have a seat lucky secret figure` | HR | ✗ | `seriesMismatch` — Have a Seat ≠ Big Into Energy |
| 21 | `pop mart the monsters lucky secret chase 隐藏` | HR | ✗ | `secretMismatch` — Luck is not secret |
| 22 | `pop mart 幸运 big into energy labubu secret` | HR | ✗ | Secret indicators on non-secret target |
| 23 | `pop mart the monsters id secret big into energy 1/72` | HR | ✗ | `wrongFigureName` — Id secret chaser, not Luck |
| 24 | `pop mart macaron series labubu figure` | HR | ✗ | `seriesMismatch` — Exciting Macaron series |
| 25 | `pop mart twinkle twinkle wonderful journey storage bag` | HR | ✗ | `productTypeReject` — storage bag; also series mismatch |
| 26 | `pop mart the monsters lucky big into energy storage bag` | HR | ✗ | `productTypeReject` — storage bag with Lucky name |
| 27 | `pop mart the monsters lucky bag charm key ring` | HR | ✗ | Tier 1 accessory product type |
| 28 | `pop mart skullpanda pin only enamel badge no figure` | HR | ✗ | Pre-excluded `pin only` |
| 29 | `pop mart the monsters big into energy display case with lucky figure` | HR | ✗ | Pre-excluded `display case` |
| 30 | `pop mart lucky big into energy poster art print` | HR | ✗ | `productTypeReject` — poster |
| 31 | `pop mart lucky big into energy sticker sheet` | HR | ✗ | `productTypeReject` — sticker |
| 32 | `pop mart big into energy lucky wholesale lot` | HR | ✗ | Pre-excluded `lot` / `wholesale` |
| 33 | `pop mart lucky big into energy custom repaint figure` | HR | ✗ | Pre-excluded `custom` |
| 34 | `pop mart lucky big into energy fake bootleg knockoff` | HR | ✗ | Pre-excluded `fake` / `bootleg` |
| 35 | `pop mart the monsters lucky big into energy not working missing accessory` | HR | ✗ | Pre-excluded `not working` |
| 36 | `pop mart sweet bean animals series furry fuzzy cheese mouse no cheese nice` | HR | ✗ | `seriesMismatch` — unrelated series (mouse is figure name there, not accessory) |
| 37 | `pop mart the monsters lucky charm strap accessory` | HR | ✗ | Tier 1 `charm` / accessory |
| 38 | `pop mart big into energy complete set bundle all common figures` | HR | ✗ | Pre-excluded `bundle` / `set` |
| 39 | `pop mart the monsters big into energy figure` | 0.45 | ✗ | Series-level title retrieved by broad search — must not enter Luck aggregate |
| 40 | `pop mart charlotte series figure` | HR | ✗ | `seriesMismatch` for Lucky target |

### Matrix summary

| Outcome | Count (of 40) |
|---------|---------------|
| Accepted | 10 |
| Rejected (score below threshold) | 6 |
| Hard rejected | 24 |

This ratio is **intentional** for a short-name figure in a multi-figure series. The matcher should reject generously.

---

## Section 6 — Threshold Validation

### Candidates

| Threshold | Effect |
|-----------|--------|
| **0.75** | Accepts any title scoring ≥0.75 with mandatory gates satisfied |
| **0.80** | Requires fuller signal agreement; rejects 0.75–0.79 band |
| **0.85** | Effectively requires brand + full series + figure (0.85 before bonus) — minimal bonus headroom |

### Score bands (with §2 weights)

| Composition | Score |
|-------------|-------|
| brand + full series + figure + consistent secret bonus | **1.00** |
| brand + full series + figure (no bonus) | **0.85** |
| brand + partial series + figure | **0.70** |
| brand + full series (no figure) | **0.45** |
| brand + figure (no series) | **0.55** |
| full series + figure (no brand) | **0.70** |

**There is no legitimate Lucky sale in the matrix that scores between 0.75 and 0.79.** The ambiguous band is empty for this figure when mandatory gates are enforced.

### Recommendation

| Scope | Threshold | Reasoning |
|-------|-----------|-----------|
| **Global default** | **0.75** (keep) | Matches MATCHING_DESIGN §6; any true single-figure sale with brand + series + figure scores **0.85** |
| **Luck / Lucky (`lucky_big_into_energy_popmart`)** | **0.80** per-figure override | Short marketplace name with cross-series `lucky` collisions; adds margin without blocking 0.85+ titles |
| **Do not adopt 0.85 as default** | — | Would reject nothing extra in the matrix while giving false confidence; real protection comes from hard rejects + mandatory figure gate |

**Additional mandatory gates (stronger than threshold alone):**

1. `figureNameMatch || marketAliasMatch` required
2. `brandMatch` required
3. `seriesMatch >= 0.30` (full series) required for acceptance
4. Any hard reject → fail regardless of score

With these gates, **0.75 global default is safe**. Per-figure **0.80** for Lucky is optional insurance, not a substitute for hard rejects.

---

## Section 7 — Matcher Test Plan

Future file: **`tools/market_intel/_catalog_matcher_test.mjs`**

Run: `node --test tools/market_intel/_catalog_matcher_test.mjs`

### Test harness design

```javascript
// Fixtures:
//   _matcher_fixtures/catalog_lucky.json   — minimal catalog slice (brand, IP, series, siblings)
//   _matcher_fixtures/metadata_lucky.json  — marketAliases + matchThreshold
// Imports:
//   normalizeMarketTitle (optional pre-step in tests)
//   scoreCatalogMatch(normalizedTitle, targetFigure, metadata, catalogContext)
```

### Group 1 — Input contract

| Test | Scenario |
|------|----------|
| `requires normalized lowercase input` | Raw title passed → throw or document undefined behavior |
| `reads marketThreshold override` | `matchThreshold: 0.80` respected |
| `falls back to 0.75 default` | `matchThreshold: null` |

### Group 2 — Positive scoring (`describe: scoring signals`)

| Test | Scenario |
|------|----------|
| `brandMatch pop mart` | `pop mart …` → signal true |
| `brandMatch popmart` | alternate spelling |
| `seriesMatch full` | big into energy + monsters/labubu |
| `seriesMatch partial insufficient alone` | big into energy only → score ≤0.70, rejected |
| `figureNameMatch luck` | catalog displayName |
| `figureNameMatch lucky via marketAlias` | requires metadata |
| `marketAliasMatch CJK` | `ラッキー`, `幸运` |
| `secretSignalConsistent bonus` | non-secret clean title +0.05 |
| `max score 1.0` | all signals |

### Group 3 — Hard rejects (`describe: hard rejects`)

| Test | Scenario |
|------|----------|
| `crossFigureContamination bundle` | lucky + hope + serenity |
| `crossFigureContamination pair` | lucky + hope |
| `wrongFigureName` | hope only, targeting luck |
| `seriesMismatch` | have a seat vs big into energy |
| `secretMismatch on common figure` | secret chase on Luck |
| `secretMismatch on secret figure` | Id without secret tokens |
| `productType storage bag` | Tier 1 |
| `productType poster` | Tier 1 |
| `preExcluded skipped` | mock findExcludeTerm hit → matcher not invoked |

### Group 4 — Accessory / product type (`describe: product type rejection`)

| Test | Scenario |
|------|----------|
| Tier 1 terms | storage bag, poster, sticker, keychain, … |
| Tier 2 badge without figure | reject |
| Tier 2 badge with strong figure match | document expected behavior (likely still reject for `badge holder`) |

### Group 5 — Threshold & gates (`describe: acceptance gates`)

| Test | Scenario |
|------|----------|
| `accepts at 0.85 composition` | canonical Lucky title |
| `rejects series-only 0.45` | |
| `rejects missing brand 0.70` | |
| `rejects without figureNameMatch even if score high` | gate enforcement |
| `per-figure 0.80 rejects 0.75` | if such fixture exists |
| `hard reject ignores score 1.0` | contamination case |

### Group 6 — Regression corpus (`describe: edge_case_titles matcher expectations`)

Extend `edge_case_titles.txt` with optional directives:

```
# @matchTarget=lucky_big_into_energy_popmart @matchAccepted=true
# @matchTarget=lucky_big_into_energy_popmart @matchHardReject=crossFigureContamination
```

Minimum regression cases (from Step 1 corpus):

| Title | Expected |
|-------|----------|
| `POP MART THE MONSTERS Big Into Energy Lucky …` | accept |
| `POP MART Big Into Energy Lucky Hope Serenity Bundle` | hard reject |
| `… Storage Bag …` | hard reject product type |
| `POP MART Labubu Have A Seat Lucky Secret` | hard reject series |
| `… Lucky Secret Chase 隐藏` | hard reject secret |
| `pop mart big into energy figure` (series-only) | reject low score |

### Group 7 — Sibling enumeration

| Test | Scenario |
|------|----------|
| `loads all series siblings from catalog` | Hope, Serenity, … Id detected |
| `does not contaminate on IP token labubu alone` | labubu + lucky + series OK |
| `id secret figure not matched as luck` | |

### Group 8 — Explainability

| Test | Scenario |
|------|----------|
| `returns signal breakdown` | every boolean exposed |
| `hardRejectReason enum stable` | snapshot for review log |

---

## Maintenance and Automation Principles

Future maintenance burden is a **first-class architectural concern** for Market Intelligence. These principles apply to matcher design, metadata ownership, and any tooling built on top of the pipeline — not only to post-Sprint 2 automation.

When evaluating new matcher, metadata, or market intelligence features, prefer solutions that:

- derive information from existing catalog data
- automate repetitive maintenance tasks
- fail visibly when coverage is missing
- avoid requiring routine manual synchronization across multiple files

Avoid workflows that require remembering to update several independent systems whenever catalog content changes.

---

### Single-engineer sustainability

Shelfy is maintained by a **single engineer**. Architecture decisions should prioritize minimizing recurring maintenance work.

A solution that saves a small amount of implementation effort but creates recurring manual maintenance should generally be **avoided**. Preference should be given to designs that reduce ongoing operational work for one maintainer — even when that means slightly more upfront implementation (e.g. a metadata generator, a coverage report, or catalog-derived defaults).

Sprint 2 accepts a hand-maintained `market_metadata.json` seed as a **bootstrap**, not as the permanent operating model.

---

### Metadata ownership

`market_metadata.json` is intended to be an **override layer**, not a second catalog.

The catalog remains the single source of truth for:

- brands
- series
- figures
- hierarchy relationships (brand → IP → series → figure)

Metadata should exist only for **marketplace-specific knowledge that cannot be derived from the catalog**.

| Override field | Legitimate use |
|----------------|----------------|
| `marketAliases` | Marketplace shorthand (`Lucky` for catalog `Luck`; CJK variants) |
| `excludeTerms` | Per-figure false-positive suppression beyond global excludes |
| `matchThreshold` | Ambiguous short names needing stricter acceptance |
| `searchTerms` | **Today:** manual eBay queries. **Future:** auto-generated baseline with optional override |
| `disabled` / `notes` | Maintainer pause / investigation notes |

It must **not** duplicate or drift from catalog identity — no parallel figure names, series membership, or hierarchy stored only in JSON. If a field can be computed deterministically from the catalog, it belongs in a generator — not in permanent manual metadata.

**It should not require routine manual maintenance for every new catalog figure.**

---

### Future automation goal

Long-term objective:

```
Catalog
  → Generate baseline matcher metadata
  → Apply optional manual overrides
  → Matcher + snapshot pipeline
```

Adding a new catalog figure should ideally produce **usable baseline matching behavior** without manual metadata authoring — derived from brand + IP + series + figure `displayName`, sibling-aware disambiguation, default `matchThreshold`, and conservative scoped `searchTerms`.

Manual work should be limited to **exceptional cases**, such as:

- **Luck ↔ Lucky** — catalog vs marketplace naming gap
- Marketplace abbreviations and common misspellings
- Special exclusion overrides for recurring false positives
- Marketplace-specific matching overrides (e.g. per-figure threshold for ambiguous names)

**Not in scope for Sprint 2:** implement the metadata generator or `coverage_report.mjs`. Document here so matcher implementation does not encode assumptions that metadata will always be hand-written.

---

### Coverage visibility

Future tooling should make missing coverage **obvious** — detect gaps automatically rather than relying on manual review or memory.

**Example utility:** `coverage_report.mjs` (read-only, on demand or post-pipeline run)

| Output section | Purpose |
|----------------|---------|
| Catalog figures | Full figure set from catalog bundle (optionally filtered by brand/IP) |
| Figures with metadata | Entries present in `market_metadata.json` (or generated baseline + overrides) |
| Figures missing metadata | Catalog figures with no metadata row — candidates for auto-generation |
| Figures with snapshots | Figures with a current `market_snapshots/{figureId}` (or local run output) |
| Figures missing snapshots | Pipeline ran but no snapshot — investigate skip reasons |

**Skip-reason cross-reference:** join missing snapshots with `SnapshotSkipReason` from the review log (`INSUFFICIENT_SALES`, `LOW_MATCH_CONFIDENCE`, `NO_SEARCH_TERMS`, `DISABLED`) so the maintainer can distinguish *not configured yet* from *configured but no qualifying sales*.

The report should **fail visibly** (non-zero exit code or prominent summary counts) when catalog figures lack baseline metadata or expected snapshots — not silently pass with partial coverage.

---

### Design principle (summary)

| Prefer | Avoid |
|--------|-------|
| Catalog-derived defaults | Duplicating catalog fields in metadata |
| Auto-generated baselines + small override files | Hand-authoring every figure entry |
| Coverage reports and skip reasons | Remembering to sync multiple files after catalog edits |
| Visible gaps (missing metadata / snapshots) | Silent partial coverage |
| One source of truth | Parallel maintenance of catalog + metadata identity |

Matcher scoring rules, hard rejects, and thresholds should be **stable and catalog-aware** (e.g. sibling lists from `seriesId`) so they scale when figure count grows without per-figure code changes.

---

## Pre-implementation checklist

Before writing `_catalog_matcher.mjs`:

- [ ] Approve §2 weights and §3 hard reject list
- [ ] Approve §4 product-type lexicon (Tier 1 + Tier 2)
- [ ] Populate `marketAliases` for Lucky (`lucky`, CJK variants)
- [ ] Confirm per-figure `matchThreshold: 0.80` for `lucky_big_into_energy_popmart`
- [ ] Approve mandatory acceptance gates (§6)
- [ ] Approve test plan groups (§7)

**After approval:** implement `_catalog_matcher.mjs` → `_catalog_matcher.test.mjs` → wire into `compute_snapshots.mjs` (Sprint 2 Step 3+).

---

## Related documents

| Document | Role |
|----------|------|
| [`MATCHING_DESIGN.md`](./MATCHING_DESIGN.md) | Parent pipeline spec |
| [`_title_normalizer.mjs`](./_title_normalizer.mjs) | Frozen Step 1 output (Input A) |
| [`market_metadata.json`](./market_metadata.json) | Input C seed |
| [`edge_case_titles.txt`](./edge_case_titles.txt) | Normalizer + future matcher corpus |
| `coverage_report.mjs` (future) | Metadata + snapshot gap report for maintainers |

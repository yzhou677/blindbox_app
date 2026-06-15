# Market Intelligence — Search Term Derivation Design

> **Sprint 2 Step 3A deliverable.** Design review only — **no implementation**.
>
> Parent specs: [`MATCHING_DESIGN.md`](./MATCHING_DESIGN.md) Section 2, [`METADATA_AUTOGEN_DESIGN.md`](./METADATA_AUTOGEN_DESIGN.md)
>
> Prerequisite (frozen): [`_catalog_matcher.mjs`](./_catalog_matcher.mjs), [`_title_normalizer.mjs`](./_title_normalizer.mjs)

---

## Purpose

Define exactly how marketplace search terms are derived from catalog data at snapshot runtime — before any implementation begins.

Prior review decisions established:

- `searchTerms` are **not stored** in metadata files.
- The catalog is the primary source of truth.
- Metadata holds only exceptions and overrides (`marketAliases`, `excludeTerms`, etc.).
- Future catalog growth should require minimal maintenance.

This document specifies the derivation contract: inputs, tiers, alias interaction, query limits, failure modes, and worked examples.

---

## Section 1 — Inputs

Search term derivation runs per target figure (or per series for series-level fallback queries). It reads the catalog bundle and optionally merges metadata overrides.

### Catalog sources

| Source | Field | Required / Optional | Role in search terms |
|--------|-------|---------------------|----------------------|
| `brands.json` | `displayName` | **Required** | Primary brand prefix (e.g. `POP MART`) |
| `brands.json` | `aliases` | Optional (empty allowed) | Alternate brand spellings (e.g. `POPMART`); generates one term per distinct spelling |
| `ips.json` | `displayName` | **Required** (via series `ipId`) | Fallback IP token when `aliases` is empty |
| `ips.json` | `aliases` | Optional (empty allowed) | Preferred marketplace IP shorthand (e.g. `Labubu` for The Monsters); **first alias used** as IP token |
| `series.json` | `displayName` | **Required** | Raw input for `seriesDistinctive` extraction (see Section 3) |
| `series.json` | `aliases` | Optional | Not used directly in term strings; informs `seriesDistinctive` fallback if displayName stripping fails |
| `figures.json` | `displayName` | **Required** | Primary figure name token in all tiers |
| `figures.json` | `aliases` | Optional (currently empty in seed) | Additional figure-name variants; each distinct alias may produce Tier 1 variants (same rules as displayName) |
| `figures.json` | `isSecret` | **Required** (boolean) | Gates optional secret-modifier terms for short secret names (Section 3) |
| `figures.json` | `brandId`, `seriesId`, `ipId` | **Required** | Join keys; not emitted as search tokens directly |

### Metadata sources (override layer)

| Source | Field | Required / Optional | Role in search terms |
|--------|-------|---------------------|----------------------|
| `market_metadata.json` (merged) | `marketAliases` | Optional (default `[]`) | Marketplace figure names not in catalog; generate **additional** Tier 3 terms (Section 4) |
| `market_metadata.json` (merged) | `searchTerms` | Optional override only | **Replaces** auto-derived terms entirely when present (unscopable / hand-crafted cases) |
| `market_metadata.json` (merged) | `disabled` | Optional | If `true`, derivation skipped — no queries run |

### Inputs explicitly excluded

| Source | Why excluded |
|--------|--------------|
| `figure.imageKey`, `sortOrder`, `rarityLabel` | No marketplace search value |
| `series.releaseDate`, `isBlindBox` | Not used in eBay keyword queries |
| Catalog `figure.aliases` duplicated into `marketAliases` | Catalog-first: use catalog field directly; do not copy into metadata |
| Normalized / lowercased forms | eBay queries use seller-facing casing; normalization happens after fetch |

### Resolution order

For each figure:

1. Load figure → series → brand → IP from catalog bundle.
2. Load merged metadata entry by catalog `figureId` (or legacy metadata key mapping if still in use during migration).
3. If `metadata.searchTerms` is non-empty → return override list (deduped, capped); **stop**.
4. If `metadata.disabled === true` → return `[]`; **stop**.
5. Otherwise derive terms from catalog + `marketAliases` using the algorithm in Section 3.

---

## Section 2 — Search Term Objectives

### What search terms do

Search terms are the **fetch layer** of Market Intelligence. They determine which completed marketplace listings enter the pipeline. Every fetched listing is still filtered by the normalizer, scored by the matcher, and subject to aggregation rules.

Search terms optimize for **recall at fetch time** within a bounded query budget. **Precision is enforced downstream** by the matcher (design stance: false negative > false positive).

### Precision vs recall

| Strategy | Example | Effect |
|----------|---------|--------|
| **High precision** | `POP MART Labubu Big into Energy Luck` | Few irrelevant listings; may miss titles that omit brand or IP |
| **Medium precision** | `Labubu Big into Energy Luck` | Catches titles without `POP MART`; more cross-brand noise |
| **Alias-driven recall** | `POP MART Labubu Big into Energy Lucky` | Catches marketplace spelling drift (`Luck` → `Lucky`); still scoped by series |
| **Low precision (reject for figure queries)** | `POP MART Lucky` or `POP MART Big Into Energy` | Retrieves sibling figures or unrelated SKUs — **too broad for figure-level fetch** |

### Tradeoffs

- **More terms → higher recall, higher API cost, more matcher work.** Duplicates across tiers are deduped after fetch; the matcher still runs on every unique listing.
- **Broader terms → more false-positive candidates.** Acceptable only if the matcher reliably rejects them; increases noise in debug review.
- **Missing alias terms → false negatives.** A catalog `displayName` of `Luck` will not fetch listings titled `Lucky` unless a Tier 3 alias term exists.

### Recommended target strategy

**Default: precision-first tiers with controlled alias expansion.**

1. Always emit Tier 1 (brand + IP token + series distinctive + figure name) — two brand spellings when available.
2. Emit Tier 3 for each `marketAlias` that differs from `displayName` — closes the catalog–marketplace naming gap.
3. Emit Tier 2 (no brand prefix) **only** for multi-word figure names where the series distinctive phrase is unambiguous — not for short or ambiguous single-token names.
4. Do **not** emit series-only or figure-only broad terms at figure level.
5. Rely on the matcher as the correctness gate; search terms should err slightly toward recall **within** the per-figure query cap, not toward global breadth.

This balances the project's accuracy priority with the need to find real sales whose titles omit brand prefixes or use marketplace nicknames.

---

## Section 3 — Candidate Generation Strategy

### Intermediate tokens

Before assembling tiers, derive these tokens once per figure:

**`brandTokens`** — `[brand.displayName]` plus each entry in `brand.aliases` (deduped, order preserved).  
Example: `["POP MART", "POPMART"]`

**`ipToken`** — `ip.aliases[0]` if present, else `ip.displayName`.  
Example: `Labubu` (not `The Monsters`)

**`seriesDistinctive`** — extract from `series.displayName`:

```
1. Remove leading IP name tokens (THE MONSTERS, SKULLPANDA, PUCKY, DIMOO, etc.)
2. Remove trailing boilerplate: "Series", "Blind Box", "Vinyl Plush", "Pendant",
   "Figures", "Doll", "Plush", trailing hyphens
3. Trim whitespace and punctuation
4. If result is empty or shorter than 3 characters, fall back to the longest
   series.aliases entry with the same stripping applied
```

Examples:

| Series displayName | seriesDistinctive |
|------------------|-------------------|
| `THE MONSTERS Big into Energy Series-Vinyl Plush Pendant Blind Box` | `Big into Energy` |
| `THE MONSTERS - Have a Seat Vinyl Plush Blind Box` | `Have a Seat` |
| `SKULLPANDA Petals in Four Acts Series Figures` | `Petals in Four Acts` |

**`figureNames`** — ordered list: `[figure.displayName]`, then each catalog `figure.aliases` entry, then each `metadata.marketAliases` entry (deduped case-insensitively; catalog names before metadata names).

**`primaryFigureName`** — `figureNames[0]` (always catalog `displayName`).

**`aliasFigureNames`** — all entries in `figureNames` after the first (marketplace-only variants).

### Tier definitions

Terms are assembled as space-separated strings using the tokens above. No lowercasing at derivation time (eBay accepts mixed case; manual seed terms used uppercase variants intentionally).

#### Tier 1 — High precision (always generated)

```
{brandToken} {ipToken} {seriesDistinctive} {primaryFigureName}
```

One term per `brandToken`.  
**Count:** 1–2 terms (depends on brand aliases).

#### Tier 2 — Medium precision (conditional)

```
{ipToken} {seriesDistinctive} {primaryFigureName}
```

**Generate only when all of:**

- `primaryFigureName` has ≥ 2 whitespace-separated tokens **or** length ≥ 10 characters (multi-word or long unambiguous name)
- `seriesDistinctive` length ≥ 8 characters
- Tier 1 + Tier 3 count is below the per-figure cap (Section 6)

**Do not generate** for short single-token names (`Luck`, `Id`, `SISI`, `Hope`) — dropping brand prefix on ambiguous names increases cross-listing noise without sufficient disambiguation.

**Count:** 0–1 terms.

#### Tier 3 — Market alias (conditional)

For each entry in `aliasFigureNames` (from catalog aliases or `marketAliases`):

```
{brandToken} {ipToken} {seriesDistinctive} {aliasFigureName}
```

Use the **first** `brandToken` only (`brand.displayName`) to limit volume — do not multiply aliases across both brand spellings unless total count remains under cap.

**Generate only when** `aliasFigureName` is not case-insensitively equal to `primaryFigureName`.

**Count:** 0–2 terms (max 2 alias-driven terms; see Section 6).

#### Tier S — Secret modifier (conditional)

For figures where `isSecret === true` **and** `primaryFigureName` length ≤ 4:

```
{brandToken} {ipToken} {seriesDistinctive} {primaryFigureName} secret
```

Use first `brandToken` only. The word `secret` reflects common seller language (`Id secret`, `chase`, `hidden`) while keeping series scope.

**Do not add** a bare `{brand} {ip} {series} secret` term — it retrieves every secret in the series.

**Count:** 0–1 terms.

### Generation order and assembly

```
1. Tier 1 terms (all brand tokens × primary figure name)
2. Tier 3 terms (first brand token × each alias, up to alias cap)
3. Tier S term (if eligible)
4. Tier 2 term (if eligible and cap allows)
5. Deduplicate case-insensitively; preserve first-seen order
6. Truncate to max per-figure cap (Section 6)
```

### Override path

If `metadata.searchTerms` is a non-empty array → return that array (deduped, truncated to cap). Auto-derivation is skipped. Used for figures that cannot be scoped safely by rules alone (document in `notes`).

---

## Section 4 — Market Alias Interaction

### Question: Should aliases generate additional search terms?

**Yes.** When `marketAliases` contains a name that differs from catalog `displayName`, the alias must produce Tier 3 search terms. This is the primary mechanism for closing gaps like `Luck` → `Lucky`.

Example:

- Tier 1 uses `Luck` (catalog truth).
- Tier 3 uses `Lucky` (marketplace truth).
- Both share the same series scope and IP token.

### Question: Should aliases replace display names?

**No — not globally.**

| Layer | Uses catalog `displayName` | Uses `marketAliases` |
|-------|---------------------------|----------------------|
| Search term Tier 1 | Yes — always | No |
| Search term Tier 3 | No | Yes — additional terms only |
| Matcher figure-name matching | Yes | Yes — via `marketAliasMatch` signal |

Replacing `displayName` with aliases in Tier 1 would hide catalog drift and make debugging harder. Tier 1 always reflects catalog identity; Tier 3 reflects marketplace exceptions.

### Question: Should aliases only affect matcher behavior?

**No.** Aliases affect **both** fetch and match:

- **Fetch:** Tier 3 terms retrieve listings that never mention `Luck`.
- **Match:** `marketAliasMatch` scores titles that contain `lucky` but not `luck`.

If aliases only affected the matcher, listings titled `POP MART Labubu Big Into Energy Lucky` would never be fetched unless a Tier 1 term accidentally matched (it would not — `Luck` ≠ `Lucky`).

### Alias policy summary

| Rule | Recommendation |
|------|----------------|
| Catalog `displayName` in Tier 1 | Always |
| `marketAliases` in Tier 3 | When alias ≠ displayName |
| Catalog `figure.aliases` | Same as Tier 3 (when populated) |
| IP-wide shorthand (`Labubu`) | Catalog `ip.aliases` — used as `ipToken`, not repeated in `marketAliases` |
| Max alias-driven search terms | 2 per figure (Section 6) |

---

## Section 5 — Catalog-First Rules

Metadata must not duplicate information the catalog already provides.

### Rules

1. **If an alias applies to an entire IP**, add it to `ips.json` `aliases` — not to every figure's `marketAliases`. The derivation uses `ip.aliases[0]` as `ipToken` automatically.

2. **If a series abbreviation applies to all figures in a series**, add it to `series.json` `aliases` — used for `seriesDistinctive` fallback extraction, not copied into per-figure metadata.

3. **If a figure name variant is canonical product identity**, add it to `figures.json` `aliases` when that field is populated — derivation picks it up without metadata.

4. **`marketAliases` is for marketplace-only names** that cannot live in the catalog: spelling drift (`Lucky`), CJK seller tokens, community nicknames (`Lucky BIE`).

5. **`searchTerms` override is last resort** — only when auto-derivation cannot safely scope the figure (generic name, unresolvable ambiguity). Document in `notes`.

6. **Do not store derived terms in metadata** — the formula in Section 3 is the single source of truth for default terms.

### Examples

| Situation | Wrong | Right |
|-----------|-------|-------|
| Every Monsters figure needs `Labubu` in query | Add `"labubu"` to each figure's `marketAliases` | `the_monsters.aliases` already includes `Labubu`; used as `ipToken` |
| Series sellers say "Big Energy" | Add to every figure's `marketAliases` | Add `"Big Energy"` to `series.aliases`; improves `seriesDistinctive` fallback |
| eBay lists `Lucky` not `Luck` | Change catalog `displayName` to `Lucky` | Keep catalog `Luck`; add `"lucky"` to figure `marketAliases` override |
| Auto term is `POP MART Labubu Big into Energy Luck` | Store that string in metadata | Derive at runtime; zero storage |
| Figure named `Angel` pulls Sanrio listings | Add broad excludes preemptively | Add `excludeTerms` reactively after debug tool confirms false positives |

---

## Section 6 — Query Budget

### Goals

- Avoid query explosion as catalog grows (1,144+ figures today).
- Keep per-figure API volume predictable for a single maintainer running batch snapshots.
- Prefer fewer, well-scoped terms over exhaustive combinatorics.

### Default limits

| Limit | Value | Rationale |
|-------|-------|-----------|
| Max search terms per figure (auto-derived) | **4** | Covers 2× Tier 1 + 1–2× Tier 3; room for Tier S or Tier 2 |
| Max alias-driven terms (Tier 3) | **2** | Most figures need 0–1 aliases; caps combinatorial growth |
| Max Tier 2 terms per figure | **1** | Brand-dropped queries are optional recall boost |
| Max Tier S terms per figure | **1** | Secret modifier for short secret names only |
| Max explicit override terms | **6** | Hand-crafted sets for edge cases; still bounded |
| Max series-level search terms | **1** | Series fallback snapshot only; intentionally broad |

### Series-level queries (separate from figure derivation)

Series-level terms support **series fallback snapshots** when figure-level liquidity is low (`MATCHING_DESIGN.md` Section 7). They are broader by design:

```
{brand.displayName} {seriesDistinctive}
```

Example: `POP MART Big into Energy`

**Not used** for figure-level fetch. One term per series maximum. Figure queries must never degrade to series-only scope.

### Expected API volume (planning estimate)

| Scope | Terms per entity | Entities (today) | Queries per full run |
|-------|------------------|------------------|----------------------|
| Figure snapshots | ≤ 4 | ~1,144 | ≤ ~4,576 |
| Series fallbacks | ≤ 1 | ~109 | ≤ ~109 |

A full-catalog snapshot run is expensive. Operational expectation:

- **Default:** run figure snapshots for enabled / prioritized figures only — not all 1,144 on every cron tick.
- **Future:** `coverage_report.mjs` tracks which figures have snapshots vs gaps.
- **Implementation note (out of scope here):** dedupe listings across overlapping terms before matcher scoring; cache completed-listing responses by query string within a run.

### When to use override `searchTerms`

Only when auto-derivation cannot produce safe terms:

- Figure name is a generic English word and series distinctive phrase is still ambiguous.
- Auto terms retrieve predominantly wrong-figure listings despite matcher gates.
- Maintainer documents reason in `notes`; override replaces auto list.

---

## Section 7 — Example Walkthroughs

### Example A — Big Into Energy — Luck

**Catalog inputs:**

| Field | Value |
|-------|-------|
| Brand | `POP MART` / alias `POPMART` |
| IP | `The Monsters` / alias `Labubu` |
| Series | `THE MONSTERS Big into Energy Series-Vinyl Plush Pendant Blind Box` |
| Figure | `Luck` (`isSecret: false`) |

**Metadata override:**

```json
{
  "marketAliases": ["lucky"],
  "searchTerms": [],
  "disabled": false
}
```

**Derived tokens:**

- `brandTokens`: `POP MART`, `POPMART`
- `ipToken`: `Labubu`
- `seriesDistinctive`: `Big into Energy`
- `primaryFigureName`: `Luck`
- `aliasFigureNames`: `["lucky"]`

**Generated search terms (in order):**

| # | Tier | Term |
|---|------|------|
| 1 | Tier 1 | `POP MART Labubu Big into Energy Luck` |
| 2 | Tier 1 | `POPMART Labubu Big into Energy Luck` |
| 3 | Tier 3 | `POP MART Labubu Big into Energy Lucky` |
| 4 | Tier 3 | *(cap reached — only first alias term emitted; second brand spelling for alias omitted by policy)* |

Tier 2 skipped (`Luck` is single-token, length ≤ 4).  
Tier S skipped (`isSecret: false`).

**Total: 3 terms** (3 of 4 cap used).

*Note:* If policy allows a second Tier 3 term with `POPMART` for the alias, total becomes 4 — still within cap. Implementation should prefer `POP MART` + alias before spending cap on `POPMART` + alias.

**Comparison to current hand-authored seed:**

| Hand-authored (stored today) | Derived |
|------------------------------|---------|
| `POP MART Lucky Big Into Energy` | `POP MART Labubu Big into Energy Lucky` (Tier 3) |
| `POPMART LUCKY BIG ENERGY` | `POPMART Labubu Big into Energy Luck` (Tier 1) |

Derived terms are **more scoped** (include IP token `Labubu`) and **split catalog vs marketplace naming** across tiers. The matcher still requires `lucky` in metadata for titles that omit `luck`.

---

### Example B — Have a Seat — SISI

**Catalog inputs:**

| Field | Value |
|-------|-------|
| Brand | `POP MART` / alias `POPMART` |
| IP | `The Monsters` / alias `Labubu` |
| Series | `THE MONSTERS - Have a Seat Vinyl Plush Blind Box` |
| Figure | `SISI` (`isSecret: false`) |

**Metadata override:** none (empty defaults)

**Derived tokens:**

- `seriesDistinctive`: `Have a Seat`
- `primaryFigureName`: `SISI`
- `aliasFigureNames`: `[]`

**Generated search terms:**

| # | Tier | Term |
|---|------|------|
| 1 | Tier 1 | `POP MART Labubu Have a Seat SISI` |
| 2 | Tier 1 | `POPMART Labubu Have a Seat SISI` |

Tier 2 skipped (single-token figure name, length ≤ 4).  
Tier 3 skipped (no aliases).

**Total: 2 terms.**

All-caps `SISI` matches how sellers list Have a Seat figures. No `marketAliases` needed unless marketplace uses a variant form (e.g. `Sisi`) confirmed by review.

---

### Example C — Big Into Energy — Id (secret)

**Catalog inputs:**

| Field | Value |
|-------|-------|
| Brand | `POP MART` / alias `POPMART` |
| IP | `The Monsters` / alias `Labubu` |
| Series | Big into Energy (same as Example A) |
| Figure | `Id` (`isSecret: true`, `rarityLabel: 1:72`) |

**Metadata override:** none initially; may later add `marketAliases` if sellers use a stable nickname not equal to `Id`.

**Generated search terms:**

| # | Tier | Term |
|---|------|------|
| 1 | Tier 1 | `POP MART Labubu Big into Energy Id` |
| 2 | Tier 1 | `POPMART Labubu Big into Energy Id` |
| 3 | Tier S | `POP MART Labubu Big into Energy Id secret` |

Tier 2 skipped (`Id` length ≤ 4).  
Tier 3 skipped (no aliases).

**Total: 3 terms.**

**Why secrets receive Tier S but not special otherwise:**

- Sellers often include `secret`, `chase`, or `hidden` for chase figures; `Id` alone is too short and ambiguous.
- A series-wide `secret` term would fetch every chase in the series — rejected.
- The matcher enforces `secretSignalConsistent` (secret listings must match target `isSecret`).
- CJK secret tokens (`隐藏`) are **not** auto-added to search terms — they are matcher/`marketAliases` concerns; adding them to queries explodes volume across all figures.

If `Id` produces too many false-positive fetches in practice, mitigation is `excludeTerms` and optional `searchTerms` override — not broader auto terms.

---

## Section 8 — Failure Modes

| Failure mode | Impact | Mitigation |
|--------------|--------|------------|
| **Short figure names** (`Luck`, `Id`, `SISI`) | Tier 2 disabled; fetch relies on series + IP scope | Ensure `ip.aliases` populated; add `marketAliases` for marketplace spellings; matcher disambiguates siblings |
| **Ambiguous figure names** (`Angel`, `Star`, `Magic`) | Queries retrieve unrelated products | Do not drop brand prefix (no Tier 2); add reactive `excludeTerms`; override `searchTerms` or `disabled` if unscopable |
| **Missing IP aliases** | `ipToken` falls back to `displayName` (e.g. `The Monsters` instead of `Labubu`); lower recall on seller titles using shorthand | Add `ip.aliases` in catalog (catalog-first); generator logs warning |
| **Marketplace nickname drift** (`Luck` → `Lucky`) | Tier 1 misses listings with no catalog name | `marketAliases` → Tier 3 terms; matcher `marketAliasMatch` |
| **Multilingual listings** (CJK in title) | ASCII-only search terms may miss some sales | Add confirmed CJK tokens to `marketAliases` (matcher); optional future: language-specific Tier 3 override — not auto-generated |
| **Empty / failed `seriesDistinctive` extraction** | Terms too broad or empty | Fall back to longest `series.aliases` entry; if still empty → no auto terms; `NO_SEARCH_TERMS` skip reason |
| **Override `searchTerms` stale after catalog rename** | Override may reference old series/figure strings | Overrides are manual and rare; catalog rename triggers maintainer review; prefer auto-derivation default |
| **Query cap truncates needed alias terms** | Miss listings for secondary aliases | Cap at 2 alias terms; prioritize first alias; add second only if within cap |
| **Duplicate listings across tiers** | Same listing fetched multiple times | Dedupe by listing ID within pipeline run before matcher (implementation concern) |

---

## Section 9 — Recommendation

### Search-term generation algorithm (summary)

```
deriveSearchTerms(figure, catalog, metadata):
  if metadata.disabled → return []
  if metadata.searchTerms non-empty → return dedupe(metadata.searchTerms)[:cap]

  brandTokens ← brand.displayName + brand.aliases
  ipToken ← ip.aliases[0] ?? ip.displayName
  seriesDistinctive ← extract(series.displayName, series.aliases)
  primary ← figure.displayName
  aliases ← unique(catalog figure.aliases + metadata.marketAliases) \ {primary}

  terms ← []
  terms += Tier1: brandTokens × primary
  terms += Tier3: brand.displayName × aliases[:2]
  if figure.isSecret and len(primary) ≤ 4:
    terms += TierS: brand.displayName + ipToken + seriesDistinctive + primary + "secret"
  if multiWordOrLong(primary) and len(seriesDistinctive) ≥ 8 and len(terms) < cap:
    terms += Tier2: ipToken + seriesDistinctive + primary

  return dedupeCaseInsensitive(terms)[:4]
```

### Query count limits

| Entity | Default max |
|--------|-------------|
| Figure (auto) | 4 |
| Figure (override) | 6 |
| Series fallback | 1 |

### Alias policy

- Tier 1 always uses catalog `displayName`.
- `marketAliases` and catalog `figure.aliases` produce **additional** Tier 3 terms only.
- IP-wide names belong in catalog `ip.aliases`, not per-figure metadata.

### Maintenance expectations

| Event | Maintainer action |
|-------|-------------------|
| New standard figure in well-aliased IP/series | None |
| New figure with marketplace spelling drift | Add `marketAliases` override (~2 min) |
| IP missing marketplace shorthand | Add `ip.aliases` in catalog once |
| Observed false-positive fetch pattern | Add `excludeTerms`; optionally tighten override `searchTerms` |
| Figure unscopable by rules | `disabled: true` + `notes`; or explicit `searchTerms` override |
| Catalog series/figure rename | Re-run snapshot; auto terms update automatically |

**Target: 90–95% of figures require zero ongoing search-term maintenance.**

### Design principles (recap)

- Catalog-driven generation at runtime — no stored duplicate truth.
- Precision-first tiers; matcher enforces correctness.
- Bounded query volume per figure.
- Metadata minimalism — overrides for exceptions only.
- Optimized for single-maintainer, low operational burden, future catalog growth.

---

## Appendix — Relationship to Other Docs

| Document | Relationship |
|----------|----------------|
| [`MATCHING_DESIGN.md`](./MATCHING_DESIGN.md) Section 2 | Supersedes stored `searchTerms` model when implementation lands; Section 2 should be updated in a later sprint |
| [`METADATA_AUTOGEN_DESIGN.md`](./METADATA_AUTOGEN_DESIGN.md) | Metadata schema excludes stored search terms; override path defined here |
| [`MATCHER_DESIGN_REVIEW.md`](./MATCHER_DESIGN_REVIEW.md) | Matcher receives listings fetched by these terms; `marketAliases` affect scoring separately |

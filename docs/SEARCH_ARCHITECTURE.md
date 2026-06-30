# Search architecture

**Catalog context:** [`CATALOG_ARCHITECTURE.md`](CATALOG_ARCHITECTURE.md) — full catalog runtime, provider graph, and alias policy. This document goes deeper on search behavior only.

## Philosophy

> **Search is token-based, deterministic, and shared across all local Shelfy surfaces.**

Search is designed to help collectors find **known** collectibles, not discover approximate matches.

When in doubt, the implementation prefers **predictable** behavior over **clever** behavior.

### Aliases vs search normalization

**Catalog aliases** (maintained in the Catalog project) represent **alternate identities** that normalization cannot recover — e.g. THE MONSTERS → Labubu, Demon Slayer → Kimetsu no Yaiba.

**Search normalization** (owned by Shelfy) recovers **mechanical formatting** — spacing compaction, symbols, boilerplate product words, separator folding. These must **not** be stored as catalog aliases.

| Concern | Owner |
|---------|--------|
| `popmart` ↔ POP MART, `sonnyangel` ↔ Sonny Angel | `SearchNormalizer` |
| `Labubu` ↔ THE MONSTERS IP | Catalog `aliases` |
| Token AND, ranking, haystack gate | `CatalogSearchService` (unchanged) |

Shelfy search is **local-first**: pure Dart matchers over in-memory catalog bundles, shelf rows, and offline market listings. There is no fuzzy matching, typo correction, stemming, or remote search engine in the local path.

We intentionally avoid Elasticsearch, Algolia, Meilisearch, SQLite FTS, and similar systems because:

- The catalog and shelf datasets are small enough to scan synchronously on device.
- Collectors benefit from **predictable** behavior (same query → same results).
- Offline reliability is a product requirement; local search must work without network.
- A single shared semantic is easier to test, document, and evolve than per-screen matchers.

**Remote Market search** (eBay gateway) is a separate path: keyword composition and relevance are owned by the gateway and provider. Search V2 does not change that boundary.

---

## Supported surfaces

| Surface | Data | Matcher |
|--------|------|---------|
| Discover → Catalog browse (`/home/catalog`) | Catalog bundle | `CatalogSearchService` |
| Add Series sheet | Catalog bundle | `buildCatalogSeriesSearchRows` → `CatalogSearchService` |
| Collection shelf | Owned shelf + optional catalog | `filterShelfSeriesBySearch` |
| Market offline filter | Listings / snapshots | `marketListingMatchesFreeText` / `collectibleMarketSnapshotVisible` |
| Market gateway (live) | eBay API | Unchanged — `MarketBrowseQueryComposer` / gateway |

**Not search:** Collection brand/IP facet chips (equality filters), Home feed rails (release-date picker), Add Figure dialog (form only).

---

## Shared primitives (`lib/core/search/`)

### `SearchNormalizer`

Pipeline (deterministic, pure Dart):

1. Trim whitespace
2. Lowercase ASCII letters
3. Fold separators to spaces: `×`, `-`, `_`, `/`, `.`, `|`, `·`, `•`, en/em dash
4. Strip decorative symbols: `®`, `™`, `©`, `°`, `!`, `?`, parentheses, brackets
5. Collapse repeated whitespace
6. Strip product-title **boilerplate** phrases (e.g. `Series Figures`, `Blind Box`, `Vinyl Plush Pendant`) from both queries and haystacks

**API:**

- `normalize(raw)` — spaced canonical form (history, tokenization, exact-name tier checks)
- `compact(normalized)` — remove spaces (`pop mart` → `popmart`)
- `normalizeForMatch(raw)` — haystack segment: spaced + compact twin when they differ

Examples:

- `THE MONSTERS × HELLO KITTY` → `the monsters hello kitty`
- `POP MART` → `pop mart`; `normalizeForMatch` → `pop mart popmart`
- `THE MONSTERS - Exciting Macaron Vinyl Face Blind Box` → `the monsters exciting macaron`
- `ZERO°` → `zero`

**Not implemented** (by design): fuzzy matching, typo correction (`haikyuu` ↔ `haikyu!!`), stemming, query expansion (`V1` → series name), stopwords.

### `SearchTokenizer`

- Tokenize normalized query on whitespace
- Example: `the monsters hello kitty` → `["the", "monsters", "hello", "kitty"]`

### `SearchMatcher`

- **Token AND:** every token must appear as a substring in the haystack
- `earliestTokenIndex` supports catalog relevance tiers

### `SearchPlaceholders`

Shared hint copy for surfaces with the same local searchable fields.

---

## Matching semantics (Search V2)

1. Normalize query → tokens
2. Empty tokens → no filter (catalog search returns `[]`; shelf returns full list; market free-text matches all)
3. Build a **normalized haystack** from searchable fields (`normalizeForMatch` per field)
4. Match iff `SearchMatcher.allTokensMatch(haystack, tokens)`

### Catalog: combined haystack gate

For each figure, `CatalogSearchService` builds one **combined haystack** from:

- Figure display name
- Series display name + series aliases
- IP display name + IP aliases
- Brand display name + brand aliases

All parts are normalized and joined into a single string. **Every query token must appear somewhere in this combined haystack** — this is the match gate. A figure is excluded if any token is missing.

```
Figure + Series + IP + Brand (+ aliases)
        ↓
   normalize & join
        ↓
   combined haystack
        ↓
   token AND  ← match gate (all tokens required)
        ↓
   per-field tier ranking  ← relevance only, not a second filter
```

This is **not** per-field OR matching (`series token AND` OR `figure token AND`). Cross-field queries such as `THE MONSTERS` + `HELLO KITTY` work because tokens can land in different fields while still satisfying the combined haystack.

Ranking then picks the best tier among individual fields where all tokens match that field alone (exact figure → figure → series → IP → aliases).

**Collection shelf:** catalog-backed rows use `CatalogSearchService.matchingSeriesIds`; custom/drop rows use the same token AND haystack over series name, brand, and IP label.

**Market offline:** listing name, series, brand, IP line, taxonomy labels, and id slugs — normalized and joined.

---

## Ranking (catalog only)

Tiers unchanged from Search V1:

1. Exact figure name (normalized full query equals figure name)
2. Figure name (all tokens in figure name)
3. Series name
4. IP name
5. Aliases / brand text

Tie-breakers: tier → earliest token index in field → figure `sortOrder` → `figureId`.

**Collection shelf** does not rank by search relevance. Pipeline: filter → user-selected sort mode (Recently Added, Alphabetical, etc.).

---

## Search history

- Uses `SearchNormalizer` (same as live search)
- Deduplication is case-insensitive after normalization
- Separate prefs keys for catalog vs market; shared rules in `CatalogSearchHistoryRules`
- UI unchanged; stored queries display in normalized lowercase form
- **No migration** for legacy mixed-case entries on disk — re-searching naturally rewrites them in normalized form

---

## Empty query behavior

| Surface | Empty query |
|---------|-------------|
| Catalog browse | History / suggestions; no result list |
| Add Series | Latest recommendations rail |
| Collection shelf | Full shelf (after brand/IP facets) |
| Market search overlay | History / suggestions; uncommitted → feed query preserved |
| Market offline filter | All listings passing taxonomy facets |

---

## Product rules

- Do not block UI on search; keep matchers pure and synchronous.
- Do not add search relevance as a Collection sort mode unless product explicitly requests it.
- Gateway search remains provider-owned.
- Extend `lib/core/search/` before adding screen-local matchers.

---

## Future extension guidance

- **New local surface:** compose a haystack → `SearchTokenizer.tokenize` → `SearchMatcher.allTokensMatch`.
- **Catalog fields:** extend `CatalogSearchService._combinedHaystack` and tier evaluation only.
- **Stopwords:** if added, implement once in `SearchTokenizer` and document behavior change.
- **Remote catalog:** load a bundle, reuse `CatalogSearchService` — do not fork matching rules in widgets.
- **`normalizeForMatch` at scale (not needed now):** At current catalog size (~few thousand figures), per-search `normalizeForMatch(field)` cost is negligible — do not pre-optimize. If the catalog grows to tens or hundreds of thousands of figures and profiling shows search latency matters, prefer **precomputing** match segments at bundle load time (store normalized haystack fragments on brand/IP/series models) over per-query memoization maps. Revisit only when real-device profiling justifies it.

See also: `.cursor/ARCHITECTURE.md` (catalog vs shelf vs market boundaries).

---

## Non-goals

Search V2 intentionally does **not** implement:

- Fuzzy search
- Typo correction
- Phonetic matching
- Stemming
- Background indexing
- Full-text search engines
- Elasticsearch / Algolia / Meilisearch

The current catalog size does not justify the additional complexity.

Search remains deterministic, local-first, and optimized for collectible browsing.

---

## Mechanical normalization vs catalog aliases

Quick reference for contributors and future tooling (including Cursor).

| Variation | Search normalization (`SearchNormalizer`) | Catalog alias |
|-----------|------------------------------------------|-----------------|
| Case (`POP MART` / `pop mart`) | ✅ `normalize()` | ❌ |
| Spaces / compaction (`popmart` ↔ `pop mart`) | ✅ `normalizeForMatch()` on **haystack**; query token stays `popmart` via `normalize()` | ❌ |
| Punctuation / separators (`×`, `-`, `/`, …) | ✅ `normalize()` | ❌ |
| Decorative symbols (`®`, `™`, `°`, `!`, `?`, parens) | ✅ `normalize()` | ❌ |
| Product-title boilerplate (`Blind Box`, `Series Figures`, …) | ✅ `normalize()` (`_boilerplatePhrases` list) | ❌ |
| Official alternate title (`Kimetsu no Yaiba` for Demon Slayer) | ❌ | ✅ |
| Community alternate identity (`Labubu` for THE MONSTERS) | ❌ | ✅ |
| Query expansion (`V1` → Exciting Macaron, `BIE`, …) | ❌ (future: Shelfy query map, not catalog) | ❌ |

**Query path:** `SearchTokenizer` → `normalize(query)` → tokens (e.g. `popmart`).

**Haystack path:** each searchable field → `normalizeForMatch(field)` → spaced + compact twin (e.g. `pop mart popmart`) → joined → `SearchMatcher.allTokensMatch`.

Identity belongs in the Catalog. Mechanical formatting belongs in `SearchNormalizer`.

---

## Search V2 Status

Current implementation is considered complete for local search.

Future improvements should extend this architecture rather than introducing screen-specific search logic.

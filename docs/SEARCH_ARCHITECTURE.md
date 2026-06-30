# Search architecture

## Philosophy

> **Search is token-based, deterministic, and shared across all local Shelfy surfaces.**

Search is designed to help collectors find **known** collectibles, not discover approximate matches.

When in doubt, the implementation prefers **predictable** behavior over **clever** behavior.

### Aliases

Aliases represent **alternative names** that collectors naturally use to refer to the **same entity**.

Aliases are **not** search keywords, tags, descriptions, or marketing phrases.

Search treats aliases as equivalent names for matching purposes only.

**Good aliases**

- THE MONSTERS → Labubu
- Exciting Macaron → Macaron
- SKULLPANDA → Skull Panda

**Not aliases**

- Cute
- Pink
- Vinyl
- Rare
- Blind Box

Those are product attributes or keywords, not alternative names.

> Search is designed to recognize the names collectors actually use, not to approximate intent through arbitrary keywords.

Keeping aliases limited to genuine alternative names keeps search predictable, explainable, and easy to maintain.

**Catalog ownership:** Alias values are maintained by the Catalog project. The Shelfy app only consumes aliases as catalog metadata — the app should never generate or invent aliases at runtime.

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

- Trim whitespace
- Lowercase ASCII letters
- Fold separators to spaces: `×`, `-`, `_`, `/`, `.`, `|`, `·`, `•`
- Collapse repeated whitespace

Example: `THE MONSTERS × HELLO KITTY` → `the monsters hello kitty`

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
3. Build a **normalized haystack** from searchable fields
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

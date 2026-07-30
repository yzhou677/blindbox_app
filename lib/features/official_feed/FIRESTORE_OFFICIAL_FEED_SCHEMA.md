# Firestore official feed schema

Editorial official posts (news, campaigns, storefront links) — **not** the Home
**Latest drops** commerce rail (catalog `releaseDate`), market, or shelf.

App feature: [`lib/features/official_feed/`](../../lib/features/official_feed/).
Maintainer seeds / push: [`tools/official_feed/README.md`](../../tools/official_feed/README.md).

## Collection

`official_feed_items/{itemId}`

## Document fields

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `id` | string | yes | Same as document id |
| `sourceId` | string | yes | Stable source key: `popmart_us`, `tntspace_us`, `toptoy_us`, `sonnyangel_us` |
| `sourceLabel` | string | yes | UI label, e.g. `POP MART` |
| `title` | string | yes | Headline |
| `imageUrl` | string | yes | HTTPS image URL (official CDN or hosted mirror) |
| `officialUrl` | string | yes | Preferred card tap destination (product/storefront, or Instagram when no page) |
| `instagramUrl` | string | no | Exact official Instagram `/p` `/reel` `/tv` post for `via IG` provenance link |
| `publishedAt` | Timestamp | yes | Instagram announcement instant (UTC); also feed sort key |
| `ingestedAt` | Timestamp | yes | Set on write (ingestion / push script) |
| `status` | string | yes | `active` \| `archived` |
| `contentHash` | string | yes | Dedup key (`sourceId` + `officialUrl` recommended) |
| `locale` | string | no | e.g. `us` |
| `releaseType` | string | no | Optional curator hint (`product`, `pop_now`, …). UI infers 1–2 deck tags automatically; only `pop_now` is an explicit tag signal. **No** stored `contentType` / tag field. |
| `productId` | string | no | POP MART / brand product id when URL is a product page |

There is **no** separate provenance field. Curation policy requires every
`publishedAt` to come from the corresponding official Instagram post (shortcode
UTC). The schema does not model non-Instagram announcement times.

## Curated Home sources (fixed order)

1. `popmart_us` → **POP MART**
2. `tntspace_us` → **TNT SPACE**
3. `toptoy_us` → **TOP TOY**
4. `sonnyangel_us` → **Sonny Angel**

Catalog map order and chip order always follow this list — never request
completion order (`OfficialFeedSources.curatedHomeSources`,
`OfficialFeedRepository.loadCuratedHomeCatalog`).

## Query (app)

Per curated brand:

```text
official_feed_items
  .where('sourceId', ==, '<sourceId>')
  .where('status', ==, 'active')
  .orderBy('publishedAt', descending: true)
  .limit(12)
```

Home loads all three in parallel via `officialFeedCatalogProvider`.

**Composite index:** `sourceId` ASC, `status` ASC, `publishedAt` DESC.

## Source availability and brand filters

A source is **available** when its final catalog list is non-empty. That list may be:

- Fresh active items from a successful Firestore load; or
- Non-empty **last-good** returned after a request failure

A source is **unavailable** when:

- A successful request returns no active / valid items (authoritative empty)
- Mapped docs are only inactive or invalid (skipped → empty list)
- The request fails and there is no last-good for that source

Rendering (`OfficialFeedCatalog` + `OfficialFeedSources`):

| Available sources | Chips | Content |
|-------------------|-------|---------|
| 0 | Hidden | Existing empty state |
| 1 | Hidden | That source’s items |
| ≥ 2 | Only available sources, fixed order | Selected source’s items |

Empty / unavailable brands never get selectable chips.

## Selection (session-only)

`officialFeedSelectedSourceProvider` is an in-memory Riverpod notifier — **not**
persisted across process restarts.

`OfficialFeedSources.resolveSelection`:

- Keep the preferred selection while that source remains available
- Otherwise the first available source in curated order
- Never force POP MART (or any brand) when it has no displayable content
- Return `null` when no source is available (UI shows empty, not a forced brand)

Availability transitions (`1→2`, `3→2`, `2→1`, `2→0`) must not leave chips for
missing brands, a preferred selection that is empty, or a blank deck while
another brand still has items.

## Per-source last-good cache and refresh

`OfficialFeedRepository` keeps process-local last-good **per `sourceId`**:

| Outcome | Cache | Returned list |
|---------|-------|---------------|
| Successful non-empty | Replaces that source’s last-good | New items |
| Successful empty | **Clears** that source’s last-good | Empty (source unavailable) |
| Failure with last-good | Unchanged | Last-good |
| Failure with no last-good | Unchanged | Empty (source unavailable) |

Additional safeguards:

- Per-source generation tokens ignore stale overlapping completions so an older
  request cannot overwrite newer last-good
- One source failing does not erase or block successful sibling sources in
  `loadCuratedHomeCatalog`
- Invalid mapped rows are skipped one-by-one (`mapOfficialFeedDocuments`); they
  do not fail the whole source
- Runtime dedupe is **within each source list** by stable item `id`

### Refresh triggers (verified)

- **Pull-to-refresh** on Discover runs `HomeDiscoverRefreshNotifier.refresh()`,
  which awaits `officialFeedCatalogProvider` again (all curated sources).
- **Offline → online / resume recovery** (`AppNetworkRecoveryNotifier`) debounces
  into the **same** `HomeDiscoverRefreshNotifier.refresh()`, so Official feeds
  re-fetch with catalog refresh and IP soft-revalidation. Connectivity is a
  retry signal, not proof of reachability.

## Deck tags (automatic)

Card tag pills are **inferred in the app** from `releaseType`, title, summary,
and validated `officialUrl` path — never stored as a Firestore field.

- Collect all matches → rank by specificity → drop secondary/path labels when a
  more specific tag applies → show **at most 2** pills
- Explicit signal: `releaseType == pop_now` (or `/pop-now/` path) → `POP NOW`
- Path product cues: `/products/`, `/collections/`, `/collection/` →
  `Product Spotlight` when nothing more specific matches
- Coming-soon / reminder language → `Coming Soon` (replaces former
  `Launch Reminder`); ambiguous `Campaign` is not used
- Fallbacks: `Announcement`, then `Official Update` — never padded onto a more
  specific tag just to fill a second slot

Implementation: `inferOfficialFeedContentTypeLabels` in
`presentation/official_feed_content_type.dart`.

## `publishedAt` vs destination

| Concern | Rule |
|---------|------|
| `publishedAt` | Instant of the corresponding official Instagram announcement (UTC, full ISO — not midnight truncation) |
| Card metadata | Two lines: `{sourceLabel} · via IG` then local `{Mon D}` (`OfficialFeedCopy.announcedOnInstagramPhrase`) |
| Deck tags | 1–2 automatic pills (see above); not a seed/Firestore field |
| `officialUrl` | Preferred card body destination: product / storefront when available; else the Instagram post |
| `instagramUrl` | Optional exact Instagram announcement post for provenance |
| Destination ≠ provenance | Card body opens `officialUrl`. `via IG` opens `instagramUrl` only when `officialUrl` is a product/storefront (not IG); when the body already opens IG, `via IG` is visible but not tappable |
| Release / sale time | Belongs in `summary` only; must not replace `publishedAt` |

Fallback copy `{sourceLabel} · Announced · {date}` is **not** implemented: curation
and seed policy require Instagram-sourced `publishedAt` for every item. There is
no runtime provenance field.

## Validation boundaries

**Runtime (mapper / loader):**

- Unknown `sourceId` values are rejected
- Destination URLs are allowlisted per supported source (plus official Instagram
  `/p` / `/reel` / `/tv` paths)
- Only `status: active` docs are queried; invalid rows are skipped individually

**Seed / push tooling:**

- Rejects duplicate ids within a seed and across brand seeds
  (`validateOfficialFeedSeedsNoDuplicateIds`)
- Rejects duplicate `officialUrl` / `imageUrl` within a seed when that rule applies
- Unknown `sourceId` is an ERROR

## Security

- Client: read-only
- Writes: Admin SDK only (`tools/official_feed/push_official_feed.mjs` or future Functions job)

## Do not

- Store catalog `imageKey` or shelf fields here
- Merge into `brands` / `ips` / `series` / `figures`
- Drive Market filter chips or listing bodies from this collection

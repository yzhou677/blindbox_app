# Official feed — curated ingestion

Manual posts for the Home **Official feeds** section (news / campaign / link
layer — **not** the catalog **Latest drops** release rail). No scraper.

**Maintainer tooling only** — nothing under `tools/official_feed/` ships in the
APK. `productIdConfirmed` and `curationOverride` are **seed-only** and are
**not** written to Firestore. Changing validation rules does **not** change app
code paths; only the quality of what you push to `official_feed_items`.

**App runtime behavior** (availability, chips, last-good, refresh, card dates):
see [`lib/features/official_feed/FIRESTORE_OFFICIAL_FEED_SCHEMA.md`](../../lib/features/official_feed/FIRESTORE_OFFICIAL_FEED_SCHEMA.md).

## Curated brands (fixed order)

| `sourceId` | Label | Seed |
|---|---|---|
| `popmart_us` | POP MART | `popmart_us.seed.json` |
| `tntspace_us` | TNT SPACE | `tntspace_us.seed.json` |
| `toptoy_us` | TOP TOY | `toptoy_us.seed.json` |

Push one seed file at a time, e.g.
`node tools/official_feed/push_official_feed.mjs tools/official_feed/tntspace_us.seed.json`.

## Data sources (allowed)

Per brand, discover announcements on that brand’s **official Instagram**, then
prefer a validated official **product / storefront** URL when one exists:

1. **POP MART** — `popmart.com/us` product / POP NOW / collection, or `@popmart_us` / `@popmart` IG
2. **TNT SPACE** — `tntspace.com` US product paths, or official IG
3. **TOP TOY** — `gotoptoy.com` / `toptoyglobal.com` product paths, or official IG

`productId` is **optional** — include it when you have a verified product id in
the official URL; skip it for Instagram-only announcements.

**Do not set deck tags in the seed.** The app infers 1–2 pills automatically from
`releaseType` (only `pop_now` is an explicit signal), title, summary, and URL
path. There is no `contentType` / tag field in Firestore.

**Do not use Facebook** (or Dealmoon, Reddit, reseller sites) to discover
products, product IDs, release dates, summaries, or `publishedAt`.

## What you do (human)

Scripts **cannot** discover drops, read hydrated product pages, or verify
announcement times. Before every push:

1. **Discover** — scan the brand’s official Instagram for US announcements; skip restocks /
   non-US noise when curating for the US feed.
2. **Match each candidate** to an `officialUrl` — official product/storefront when
   available, otherwise the official Instagram post link.
3. **Open product links in a browser** when present — wait for the page to hydrate.
4. **Copy from the live page or post**
   - `officialUrl` — brand product path **or**
     `https://www.instagram.com/p/{shortcode}/`
   - `productId` — optional; from the product URL when verified
   - `imageUrl` — single-product art (official CDN, store CDN, or mirrored Storage)
   - `summary` — see **Summary policy** below
   - `publishedAt` — see **publishedAt policy** below
5. **Set** `productIdConfirmed: true` on product rows when you copied the id from a
   hydrated browser session (skip for Instagram-only rows; POP MART convention).
6. **Edit** the brand’s `*.seed.json`; retire old ids via `retiredItemIds` when
   correcting an `id` (document id changes).
7. **Run** `node tools/official_feed/curate_check.mjs tools/official_feed/<seed>.json` — fix ERRORS.
8. **Push** `node tools/official_feed/push_official_feed.mjs tools/official_feed/<seed>.json`.

**Prefer skipping an item** over publishing a wrong product ID or invented date.

Optional image mirror:
`node tools/official_feed/upload_official_feed_image.mjs <httpsImageUrl> official_feed/<sourceId>/<file>`.

## publishedAt policy

`publishedAt` = **official Instagram post instant** for every Official feed
item. Official feeds are curated from brand Instagram announcements.

- Copy the full UTC timestamp from the post shortcode:
  `node tools/official_feed/_ig_shortcode_date.mjs DZbgLVcDIDW` → use the `utc`
  field (e.g. `2026-07-03T08:52:21.758Z`). **Do not** truncate to
  `T00:00:00Z` — midnight UTC becomes the previous calendar evening in US
  timezones and the app will show the wrong day.
- Product rows announced in the same IG carousel share that post's `utc`
  timestamp.
- **Do not** use product-page create/update time, release/sale start, Firestore
  create time, seed import time, or PT→UTC release conversions for
  `publishedAt`.
- Card metadata (app) shows two lines so the date stays fully visible:
  `{sourceLabel} · via IG` then `{local month+day}` — this
  describes date provenance, not whether `officialUrl` opens Instagram or a
  product page.

The app shows the **local** month+day from `publishedAt` in the card header
(`Jul 3`). It is not the product release time.

## Summary policy

Fact-based only. **Correct and boring beats detailed and wrong.**

### When the official product page shows Online Release

After the page hydrates, if it explicitly contains an **Online Release** date
and time, use this format:

```text
<short product description>. Online <Month Day>, <Time> PT.
```

Examples:

- `New Haikyu!! Off-Court Vibes blind box figures. Online June 4, 7:00 PM PT.`
- `New Peach Riot Fruit Punch plush pendants. Online June 4, 7:00 PM PT.`

Copy month, day, and time from the product page — do not infer from Instagram,
Facebook, Dealmoon, Reddit, or reseller sites.

### When Online Release cannot be verified

Use a short descriptive summary only. **Do not invent dates or times.**

Examples:

- `New SKULLPANDA figure release.`
- `Official POP NOW launch.`

`summary` release dates and `publishedAt` **announcement dates** are independent —
scripts do not cross-check them.

## What scripts validate (and what they do not)

| Checked automatically | Not checked (you verify) |
| --- | --- |
| URL / image format; reseller & A_/B_/C_ images | Correct **product ID** after browser hydration |
| `productId` ↔ `officialUrl` ↔ `id` suffix consistency | Title / summary copy accuracy |
| Phantom product id (HTTP 200 is meaningless on US SPA) | Whether the drop is still for sale |
| Image reachable | Instagram announcement date |
| ISO `publishedAt`; duplicate urls / images | POP NOW set id correctness (soft WARNING) |

## Workflow

| Step | Command |
| --- | --- |
| Curate check | `node tools/official_feed/curate_check.mjs tools/official_feed/<seed>.json` |
| Push | `node tools/official_feed/push_official_feed.mjs tools/official_feed/<seed>.json` |

Optional: `node tools/official_feed/check_url.mjs "<officialUrl>"` — shows
`spaShell` / `phantomAccepted` (do not treat HTTP 200 as proof).

## Seed fields

| Field | Rule |
| --- | --- |
| `officialUrl` | Brand-allowed product/storefront path **or** official Instagram post URL. |
| `imageUrl` | Per-item product art. No reseller hosts unless `curationOverride: "reseller_image_ok"`. No `A_`/`B_`/`C_` carousel filenames. |
| `productId` | Optional. When set, must match `officialUrl` and (for POP MART) `id` suffix `…_{productId}`. |
| `productIdConfirmed` | Seed only. `true` after copying id from a hydrated browser session. |
| `summary` | ≤ ~80 chars. Descriptive only, or `… Online June 4, 7:00 PM PT.` when copied from official product page Online Release block. |
| `publishedAt` | ISO-8601 UTC — full Instagram post instant from shortcode `utc` field. |
| `retiredItemIds` | Archives removed doc ids in Firestore on push. |

### Curation severity

| Level | Effect |
| --- | --- |
| **ERROR** | Blocks check and push |
| **WARNING** | Printed; blocks only with `--strict` |
| **INFO** | Audit notes (e.g. redirects) |

## Push to Firestore

```bash
cd functions && npm install && cd ..
gcloud auth application-default login   # or: firebase login
node tools/official_feed/curate_check.mjs
node tools/official_feed/push_official_feed.mjs
```

The app reads `official_feed_items` from Firestore — not the JSON file. Cold
restart after push to refresh Home.

See `lib/features/official_feed/FIRESTORE_OFFICIAL_FEED_SCHEMA.md`.

## App fetch limit (V1)

`loadPopMartUs(limit: 12)` — hand-curated seed of ~5–8 items is enough for Home
density without extra query cost.

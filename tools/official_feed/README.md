# Official feed — curated ingestion (Phase 1)

Manual **POP MART US** posts for the Home **Official updates** section (news /
campaign / link layer — **not** the catalog **Latest drops** release rail). No
scraper, no multi-brand engine.

**Maintainer tooling only** — nothing under `tools/official_feed/` ships in the
APK. `productIdConfirmed` and `curationOverride` are **seed-only** and are
**not** written to Firestore. Changing validation rules does **not** change app
code paths; only the quality of what you push to `official_feed_items`.

## Data sources (allowed)

1. **POP MART US official website** — `popmart.com/us` product and POP NOW pages
   (when a numeric product URL exists, include it)
2. **POP MART official Instagram** — `@popmart_us` or global `@popmart` posts

**`officialUrl` destinations:** POP MART US product / POP NOW / collection pages
**or** an official Instagram post URL (`instagram.com/p/…`, `/reel/…`) when no
product or campaign page exists (e.g. FIFA collabs announced on IG only).

`productId` is **optional** — include it when you have a verified
`/us/products/{id}/` link; skip it for Instagram-only announcements.

**Do not use Facebook** (or Dealmoon, Reddit, reseller sites) to discover
products, product IDs, release dates, summaries, or `publishedAt`.

## What you do (human)

Scripts **cannot** discover drops, read hydrated product pages, or verify
announcement times. Before every push:

1. **Discover** — scan `@popmart_us` for US announcements; skip restocks /
   non-US.
2. **Match each candidate** to an `officialUrl` — POP MART US product/POP NOW when
   available, otherwise the official Instagram post link.
3. **Open product links in a browser** when present — wait for the page to hydrate.
4. **Copy from the live page or post**
   - `officialUrl` — `/us/products/{id}/{slug}`, `/us/pop-now/set/…`, or
     `https://www.instagram.com/p/{shortcode}/`
   - `productId` — optional; the `{id}` in a product URL when you have one
   - `imageUrl` — single-product art (official CDN, Shopify store, or IG post art)
   - `summary` — see **Summary policy** below
   - `publishedAt` — see **publishedAt policy** below
5. **Set** `productIdConfirmed: true` on product rows when you copied the id from a
   hydrated browser session (skip for Instagram-only rows).
6. **Edit** `popmart_us.seed.json`; retire old ids via `retiredItemIds` (required when
   correcting `productId` — the document `id` changes, so the old id must be
   listed or push will auto-archive stale actives).
7. **Run** `node tools/official_feed/curate_check.mjs` — fix ERRORS.
8. **Push** `node tools/official_feed/push_official_feed.mjs`.

**Prefer skipping an item** over publishing a wrong product ID or invented date.

## publishedAt policy

`publishedAt` = **official announcement calendar day** (Instagram post date, or
official POP MART announcement when no IG post exists).

- Day-level accuracy is enough — use midnight UTC: `2026-05-29T00:00:00Z`
- For Instagram posts, derive the calendar day from the post shortcode:
  `node tools/official_feed/_ig_shortcode_date.mjs DZbgLVcDIDW`
  (decodes media id → UTC post day; no browser or embed scrape needed)
- **Do not** use release-day sort buckets, manual hour stagger, or PT→UTC release
  conversions

The app shows month+day from `publishedAt` in the card header (`May 29`). It is
not the product release time.

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
| Curate check | `node tools/official_feed/curate_check.mjs` |
| Push | `node tools/official_feed/push_official_feed.mjs` |

Optional: `node tools/official_feed/check_url.mjs "<officialUrl>"` — shows
`spaShell` / `phantomAccepted` (do not treat HTTP 200 as proof).

## Seed fields

| Field | Rule |
| --- | --- |
| `officialUrl` | POP MART US product/POP NOW/collection **or** official Instagram post URL. |
| `imageUrl` | Per-item product art. No reseller hosts unless `curationOverride: "reseller_image_ok"`. No `A_`/`B_`/`C_` carousel filenames. |
| `productId` | Optional. When set, must match `officialUrl` and `id` suffix `…_{productId}`. |
| `productIdConfirmed` | Seed only. `true` after copying id from a hydrated browser session. |
| `summary` | ≤ ~80 chars. Descriptive only, or `… Online June 4, 7:00 PM PT.` when copied from official product page Online Release block. |
| `publishedAt` | ISO-8601 UTC — **Instagram / official announcement day** at `T00:00:00Z`. |
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

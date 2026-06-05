# Official feed — curated ingestion (Phase 1)

Manual **POP MART US** posts for the Home **Official updates** section (news /
campaign / link layer — **not** the catalog **Latest drops** release rail). No
scraper, no multi-brand engine.

**Maintainer tooling only** — nothing under `tools/official_feed/` ships in the
APK. `productIdConfirmed` and `curationOverride` are **seed-only** and are
**not** written to Firestore. Changing validation rules does **not** change app
code paths; only the quality of what you push to `official_feed_items`.

## What you do (human)

Scripts **cannot** discover drops, prove US release dates, or read hydrated
product pages. Before every push:

1. **Discover** — @popmart_us / popmartusa / popmart.com/us (US only; skip
   restocks / non-US).
2. **Open each link in a browser** — wait for the product page to hydrate.
3. **Copy from the live page**
   - `officialUrl` — numeric `/us/products/{id}/{slug}` or `/us/pop-now/set/…`
   - `productId` — the `{id}` in that URL (products only)
   - `imageUrl` — single-product art (official CDN or POP MART Shopify store)
   - `summary` — one line with the **US online date** if you know it
   - `publishedAt` — UTC timestamp for **feed sort order** (usually the
     announcement / online day; 7 PM PT often = next UTC calendar day)
4. **Set** `productIdConfirmed: true` on product rows after step 3.
5. **Edit** `popmart_us.seed.json`; retire old ids via `retiredItemIds`.
6. **Run** `node tools/official_feed/curate_check.mjs` — fix ERRORS.
7. **Push** `node tools/official_feed/push_official_feed.mjs`.

## What scripts validate (and what they do not)

| Checked automatically | Not checked (you verify) |
| --- | --- |
| URL / image format; reseller & A_/B_/C_ images | Correct **US release date & time** |
| `productId` ↔ `officialUrl` ↔ `id` suffix consistency | Title / summary copy accuracy |
| Phantom product id (HTTP 200 is meaningless on US SPA) | Whether the drop is still for sale |
| Image reachable; summary ↔ `publishedAt` day drift (soft WARNING) | Non-US announcements mislabeled as US |
| ISO `publishedAt`; duplicate urls / images | POP NOW set id correctness (soft WARNING) |

`publishedAt` is the **feed ordering timestamp**, not a guaranteed “official
online at this instant” field. When `summary` mentions a month/day, keep
`publishedAt` on the same day or ±1 day (7 PM PT → next UTC day is normal).

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
| `officialUrl` | Canonical POP MART US link from the browser. Products: `/us/products/{numericId}/{slug}`. POP NOW: `/us/pop-now/set/…`. |
| `imageUrl` | Per-item product art. No reseller hosts unless `curationOverride: "reseller_image_ok"`. No `A_`/`B_`/`C_` carousel filenames. |
| `productId` | Required for `releaseType: "product"`. Must match `officialUrl` and `id` suffix `…_{productId}`. |
| `productIdConfirmed` | Seed only. `true` after copying id from a hydrated browser session. |
| `summary` | ≤ ~80 chars. If it mentions a date, align `publishedAt` (see above). |
| `publishedAt` | ISO-8601 UTC — **sort key** for the Official updates feed. |
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

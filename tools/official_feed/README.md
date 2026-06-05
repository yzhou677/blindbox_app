# Official feed — curated ingestion (Phase 1)

Manual **POP MART US** posts for the Home **Official updates** section (news /
campaign / link layer — **not** the catalog **Latest drops** release rail). No
scraper, no multi-brand engine.

**Does not affect app releases.** Scripts under `tools/official_feed/` are
maintainer-only (not bundled in the APK). Changing seed or pushing Firestore
updates users on existing installs after they cold-restart the app — no new
APK required.

## Workflow (discover → check → push)

| Step | What | Command / who |
| --- | --- | --- |
| **1. Discover** | Pick real POP MART US links (browser, popmart.com/us, or ask an agent). Copy **numeric** `/us/products/{id}/…` URLs. | Manual / Cursor — **no auto-discovery script** |
| **2. Edit seed** | Add or update rows in `popmart_us.seed.json`; use `retiredItemIds` to archive old doc ids. | Editor |
| **3. Curate check** | Schema validation + live `officialUrl` / `imageUrl` probes. | `node tools/official_feed/curate_check.mjs` |
| **4. Push** | Write `official_feed_items` in Firestore (runs validation again). | `node tools/official_feed/push_official_feed.mjs` |

`fetch_popmart_meta.mjs` is optional; POP MART product pages are SPAs and usually
do not expose `og:image`. Prefer browser DevTools or a trusted product image CDN.

Early bad rows were mostly **bad `officialUrl` / placeholder images** — caught
now by `seed_validation.mjs` and `curate_check.mjs` before push.

## Seed file

- `popmart_us.seed.json` — one row per editorial drop

Each item needs:

| Field | Rule |
| --- | --- |
| `officialUrl` | **Canonical** POP MART US link copied from the live site. Product pages must be `/us/products/{numericId}/{slug}` (e.g. `6278`, `5820`) — **never** slug-only `/us/products/{title-slug}` (breaks in-app routing). POP NOW: `/us/pop-now/set/…`. Never `https://www.popmart.com/us` alone. |
| `imageUrl` | **Per-item** product/release art (`https`). Never `cdn-global.popmart.com/images/192.png` (site logo). Prefer art from the product page; Shopify/reseller CDN is OK for V1 when POP MART SSR has no `og:image`. |
| `productId` | Optional. Numeric id from the URL (`6278`) — must match `officialUrl` when set; helps future curation. |
| `releaseType` | Optional. `product` or `pop_now` — stored in Firestore for maintainability only. |
| `retiredItemIds` | Optional top-level array. Push marks these doc ids `archived` so broken rows disappear from the app feed. |
| `summary` | Optional one-line deck under the title (≤ ~80 chars). |
| `publishedAt` | ISO-8601 UTC |

Validate only (no network probes):

```bash
node tools/official_feed/validate_seed.mjs
```

Recommended before every push (validation + URL probes):

```bash
node tools/official_feed/curate_check.mjs
```

Optional helpers (manual curation only):

```bash
node tools/official_feed/fetch_popmart_meta.mjs "https://www.popmart.com/us/products/6278/..."
```

POP MART product pages are SPA shells; `fetch_popmart_meta.mjs` rarely finds `og:image`. Use browser DevTools on the live product page when you need official CDN URLs.

## Push to Firestore

From repo root:

```bash
cd functions
npm install
cd ..
```

Authenticate (pick one):

```bash
gcloud auth application-default login
# or
firebase login
```

Project id is read from `.firebaserc` (`blindbox-collection`). Override if needed:

```powershell
$env:FIREBASE_PROJECT_ID = "blindbox-collection"
```

Push (runs seed validation first; run `curate_check` before this in practice):

```bash
node tools/official_feed/push_official_feed.mjs
```

After changing the seed, **re-push** so Firestore matches — the app reads `official_feed_items`, not the JSON file.

## Firestore index

Composite index on `official_feed_items`:

- `sourceId` Ascending
- `status` Ascending
- `publishedAt` Descending

See `lib/features/official_feed/FIRESTORE_OFFICIAL_FEED_SCHEMA.md`.

## Curation bar (V1)

- **Quality over quantity** — only add rows after you open the link in a browser and confirm the product page loads (no POP MART error / `strconv.ParseUint` slug bug).
- Drop items you cannot verify on **popmart.com/us** with a numeric product id; do not fabricate URLs from titles.
- Re-push after seed edits; use `retiredItemIds` to archive removed rows in Firestore.

## App fetch limit (V1)

The app requests **12** active items (`loadPopMartUs(limit: 12)`). With a hand-curated seed of ~5 items, that is enough for Home density and freshness without extra scroll or query cost. Increase only when you routinely publish more than ~10 verified drops between pushes.

# eBay Browse via market gateway

Official eBay Browse API runs in Firebase Functions only. Flutter calls `GET {gateway}/v1/browse` — no eBay secrets in the app.

## Credentials (gitignored)

Copy `functions/env.ebay.example` into `functions/.env.blindbox-collection`:

```env
MARKET_GATEWAY_PROVIDER=ebay
MARKET_GATEWAY_MODE=live
EBAY_ENV=sandbox
EBAY_CLIENT_ID=your-sandbox-app-id
EBAY_CLIENT_SECRET=your-sandbox-cert-id
```

Never commit real Client ID / Cert ID. Redeploy after updating env:

```bash
cd functions && npm run deploy
```

## Flutter (local / internal)

```bash
flutter run \
  --dart-define=MARKET_GATEWAY_EBAY=true \
  --dart-define=MARKET_GATEWAY_BASE_URL=https://us-central1-blindbox-collection.cloudfunctions.net/market
```

With those flags, the Market **Chasers** rail probes automatically (no extra define). Disable with `--dart-define=MARKET_CHASERS_SCORING=false`.

Emulator:

```bash
adb reverse tcp:5001 tcp:5001
flutter run \
  --dart-define=MARKET_GATEWAY_EBAY=true \
  --dart-define=MARKET_GATEWAY_BASE_URL=http://127.0.0.1:5001/blindbox-collection/us-central1/market
```

Without flags, Market uses bundled asset feed only. Gateway failure falls back to asset rows (and optional stale eBay cache).

Live gateway browse skips catalog identity matching (listing-level cards use eBay titles directly). Catalog matching remains available for offline/mock paths only. See [`ARCHITECTURE_NOTES.md`](ARCHITECTURE_NOTES.md) § Market Identity Architecture for runtime audit details and retention rationale.

## Probe

```bash
curl.exe "https://us-central1-blindbox-collection.cloudfunctions.net/market/v1/browse?limit=3&q=pop+mart"
```

Expect `meta.provider: "ebay"`. Without credentials, `meta.mode: "fixture"`.

## Gateway query facets

`GET /v1/browse` accepts provider-neutral facets (gateway composes eBay `q`):

| Param | Role |
|-------|------|
| `brandId` | Maps to eBay item aspect **Brand** (e.g. `pop_mart` → `POP MART`) |
| `ipId` | Maps to eBay **Character** / **Franchise** aspects (e.g. `the_monsters` → LABUBU / THE MONSTERS) |
| `searchText` | User search terms (after submit in app) |
| `sort` | Reserved (`relevance` default) |
| `limit` | Page size (default 12) |
| `cursor` | Pagination continuation |

Legacy `q` still works as override. Example:

```bash
curl.exe "https://us-central1-blindbox-collection.cloudfunctions.net/market/v1/browse?brandId=pop_mart&ipId=the_monsters&limit=12"
```

With `brandId` / `ipId`, the gateway uses eBay **aspect_filter** (not keyword stuffing):

- **Brand** → item aspect `Brand:{POP MART}`
- **IP** → item aspect `Character:{LABUBU|THE MONSTERS|…}` with **Franchise** fallback when Character returns no rows
- **searchText** → keyword `q` only (optional)
- Category defaults to `261068` (live-calibrated blind box collectibles); override with `EBAY_BROWSE_CATEGORY_ID`
- **Tier 2:** when strict aspect rows &lt; 6, supplement with Brand aspect + IP keywords in `q`
- **Tier 3:** gateway drops rows whose titles contradict selected brand/IP
- **Cureplaneta:** in-app brand `dpl` maps to eBay aspect `Cureplaneta`; filter rail shows only `baby_three` (no “Any IP”)

## eBay Browse wire (integration notes)

Upstream `item_summary` rows use `itemId` (`v1|{legacyId}|0`), `itemWebUrl`, `price.value` (string or number), and optional `thumbnailImages` / `image`. The gateway:

- Never exposes `itemHref` (API URL) to the app
- Builds listing URLs from `itemWebUrl` or `legacyItemId`
- Uses eBay `total` + `offset` for pagination (not page size alone)
- Normalizes titles to NFC; missing images become empty `imageUrl` (app placeholder)
- Upgrades eBay CDN thumbs to `s-l500` on browse rows (detail uses `s-l1600`)

## Item detail

`GET /v1/item?itemId=v1|{legacyId}|0` returns condition, seller, shipping summary, short description, high-res image, and listing URL. The app loads this lazily on the market detail screen (live eBay only).

Flutter maps stable eBay ids (`legacyItemId`) for dedupe keys (`mkt-ebay-{id}`).

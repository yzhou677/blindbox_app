# Mercari live provider sandbox (Phase 3A)

Experimental gateway-first Mercari integration. **Default off** — no network until explicitly enabled.

## Architecture boundary

The gateway returns **provider-shaped listing JSON only** (title, price, image URL, listing URL). It must **not** send canonical collectible identity (`figureId`, `seriesId`, catalog `imageKey`, taxonomy ids).

The app maps wire → [`MarketListing`](../lib/models/market_listing.dart), then [`MarketIdentityMatcher`](../lib/features/market/application/market_identity_matcher.dart) attaches [`MarketIdentityMatch`](../lib/features/market/domain/market_identity_match.dart) using the offline catalog index.

## Enable locally

```bash
flutter run \
  --dart-define=MARKET_SANDBOX_MERCARI=true \
  --dart-define=MERCARI_GATEWAY_BASE_URL=https://your-gateway.example
```

**Android emulator** (with `firebase emulators:start --only functions` on the host):

```bash
adb reverse tcp:5001 tcp:5001
flutter run \
  --dart-define=MARKET_SANDBOX_MERCARI=true \
  --dart-define=MERCARI_GATEWAY_BASE_URL=http://127.0.0.1:5001/<project>/us-central1/market
```

After **pull to refresh** on Market, a SnackBar reports success or the error (e.g. `0 listings` / connection refused). Fixture titles look like `pop mart — cozy vinyl figure` (often as separate cards, not LABUBU catalog names).

Without both flags, the app behaves as before (asset feed only at startup).

## Gateway contract

`GET {baseUrl}/v1/browse?limit=24&cursor={token}`

Optional pagination fields:

- `nextCursor` (or `cursor`) — continuation token for the next page
- `hasMore` — boolean; inferred when `nextCursor` is present if omitted

Response:

```json
{
  "nextCursor": "opaque-token",
  "hasMore": true,
  "items": [
    {
      "id": "provider-native-id",
      "title": "Listing title as shown on marketplace",
      "price": { "value": "88.00", "currency": "USD" },
      "image": { "imageUrl": "https://..." },
      "listingUrl": "https://..."
    }
  ]
}
```

## App behavior

| When | Behavior |
|------|----------|
| Startup | [`AssetMarketSource`](../lib/features/market/data/source/asset_market_source.dart) only — never blocks on gateway |
| Pull to refresh (Market tab) | If sandbox active: reset Mercari pagination, fetch first page, merge with asset session |
| Load more | Calm **Load more sightings** button (max 72 live rows); appends next gateway page |
| Gateway failure | Retries with backoff; then returns cached rows if available; asset rows unchanged |
| Malformed items | Skipped per-row during DTO parse (schema drift tolerance) |
| UI | No provider badges; no error banners on failure |

## Risks (document findings here)

- ToS / scraping: **no client-side scraping** in the Flutter app
- Rate limits, anti-bot, regional blocks
- Image URL hotlink stability
- Response schema drift

## Firebase Functions gateway

Thin Mercari browse lives in-repo under `functions/` — see [`MERCARI_GATEWAY_FUNCTIONS.md`](MERCARI_GATEWAY_FUNCTIONS.md).

Default emulator mode is **fixture** (no Mercari auth). Set `MERCARI_GATEWAY_MODE=live` on the function for upstream attempts.

## Manual probe (optional)

```bash
dart run tools/mercari_sandbox/probe_gateway.dart --url=https://your-gateway.example
# emulator example:
# --url=http://127.0.0.1:5001/<project>/us-central1/market
```

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

Emulator:

```bash
adb reverse tcp:5001 tcp:5001
flutter run \
  --dart-define=MARKET_GATEWAY_EBAY=true \
  --dart-define=MARKET_GATEWAY_BASE_URL=http://127.0.0.1:5001/blindbox-collection/us-central1/market
```

Without flags, Market uses bundled asset feed only. Gateway failure falls back to asset rows (and optional stale eBay cache).

## Probe

```bash
curl.exe "https://us-central1-blindbox-collection.cloudfunctions.net/market/v1/browse?limit=3&q=pop+mart"
```

Expect `meta.provider: "ebay"`. Without credentials, `meta.mode: "fixture"`.

## eBay Browse wire (integration notes)

Upstream `item_summary` rows use `itemId` (`v1|{legacyId}|0`), `itemWebUrl`, `price.value` (string or number), and optional `thumbnailImages` / `image`. The gateway:

- Never exposes `itemHref` (API URL) to the app
- Builds listing URLs from `itemWebUrl` or `legacyItemId`
- Uses eBay `total` + `offset` for pagination (not page size alone)
- Normalizes titles to NFC; missing images become empty `imageUrl` (app placeholder)

Flutter maps stable eBay ids (`legacyItemId`) for dedupe keys (`mkt-ebay-{id}`).

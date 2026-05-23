# Mercari gateway (Firebase Functions)

Thin **provider stabilization layer** only. The Flutter app remains the intelligence authority (identity matching, shelf, relationships, emotional interpretation).

## Layout

```
functions/
  src/
    index.ts                 # HTTPS entry (`market`)
    providers/mercari/
      mercariBrowse.ts       # GET /v1/browse handler
      mercariNormalize.ts    # stable DTO mapping
      mercariParser.ts       # upstream schema tolerance
      mercariTypes.ts
    shared/
      http/                  # fetch + retry
      cache/                 # brief in-memory TTL cache
```

## Wire contract

Matches [`docs/MERCARI_SANDBOX.md`](MERCARI_SANDBOX.md):

`GET {baseUrl}/v1/browse?limit=24&cursor={token}&q={search}`

- `q` / `query` — optional search text (defaults to `pop mart blind box`)
- `cursor` — opaque gateway token (not Mercari-native)
- `limit` — page size (1–48, default 24)

## Modes

| Env | Default | Behavior |
|-----|---------|----------|
| `MERCARI_GATEWAY_MODE` | `fixture` | Deterministic sample listings (emulator / CI) |
| `MERCARI_GATEWAY_MODE=live` | — | Calls Mercari US search APQ; degrades to fixture rows if upstream blocks |

Optional live tuning:

- `MERCARI_DEFAULT_QUERY` — default `q` when omitted
- `MERCARI_USER_AGENT` — upstream user agent
- `MERCARI_EXTRA_HEADERS_JSON` — JSON object merged into upstream headers (session cookies, etc.)

## Local setup

```bash
cp firebase.json.example firebase.json
cd functions && npm install && npm run serve
```

`npm run serve` builds TypeScript then starts the emulator with the **project-local** `firebase-tools` (via `npx`). Use this instead of a broken or outdated global `firebase` install.

Probe (PowerShell: use `curl.exe`):

```bash
curl.exe "http://127.0.0.1:5001/blindbox-collection/us-central1/market/v1/browse?limit=5&q=pop+mart"
```

You should see `Loaded functions definitions from source: market` in the emulator log. If the log says `Function us-central1-market does not exist`, the gateway did not load.

### Emulator: `Failed to parse build specification`

Usually one of:

1. **`firebase.json` missing `runtime`** — copy from `firebase.json.example` (`nodejs22`).
2. **Stale global CLI** — `firebase-functions` v6 needs recent `firebase-tools` (v13.16+). Prefer `cd functions && npm run serve`, or reinstall: `npm install -g firebase-tools@latest`.
3. **No compiled output** — run `npm run build` in `functions/` so `lib/index.js` exists before starting the emulator.
4. **Node mismatch** — `functions/package.json` `engines.node` should be `22` (matches `runtime` and current Firebase support).

Stop any old emulator on port 5001 before restarting (`Ctrl+C` in the terminal running `firebase emulators:start`).

## Flutter sandbox

```bash
flutter run \
  --dart-define=MARKET_SANDBOX_MERCARI=true \
  --dart-define=MERCARI_GATEWAY_BASE_URL=http://127.0.0.1:5001/<project>/us-central1/market
```

Production:

```bash
--dart-define=MERCARI_GATEWAY_BASE_URL=https://us-central1-<project>.cloudfunctions.net/market
```

## Deploy

Prerequisites: Firebase CLI logged in, project `blindbox-collection`, `firebase.json` copied from `firebase.json.example`.

```bash
cd functions && npm run build && npm run deploy
```

Production base URL (Gen2 HTTPS):

`https://us-central1-blindbox-collection.cloudfunctions.net/market`

Probe:

```bash
curl.exe "https://us-central1-blindbox-collection.cloudfunctions.net/market/v1/browse?limit=3&q=pop+mart"
```

### Deploy blocked: Cloud Build service account

If deploy fails with *missing permission on the build service account*, in [Google Cloud Console](https://console.cloud.google.com/iam-admin/iam?project=blindbox-collection) grant the **Cloud Build** service account (`1094225908408@cloudbuild.gserviceaccount.com`) at least:

- Cloud Functions Developer
- Service Account User
- Artifact Registry Writer

Then retry deploy. Optional: `firebase functions:artifacts:setpolicy --force` for Artifact Registry cleanup policy.

**Production default:** `MERCARI_GATEWAY_MODE` unset → **fixture** (safe). Set `live` only when intentionally testing upstream.

## Controlled live testing (internal only)

1. Do **not** change Flutter release defaults (`MARKET_SANDBOX_MERCARI` stays off for production users).
2. On the `market` function, set env:
   - `MERCARI_GATEWAY_MODE=live`
   - Optional: `MERCARI_EXTRA_HEADERS_JSON` (session headers if Mercari blocks bare requests)
   - Optional: `MERCARI_GATEWAY_DEBUG=1` for sparse `console.warn` diagnostics in Cloud Logs
3. Probe production:

```bash
curl.exe "https://us-central1-blindbox-collection.cloudfunctions.net/market/v1/browse?limit=3&q=pop+mart"
```

Check response `meta`:

| Field | Meaning |
|-------|---------|
| `mode` | `live` or `fixture` |
| `upstreamDegraded` | Live path fell back to fixture rows |
| `diagnostics.upstreamBlocked` | 403 / hard block |
| `diagnostics.rateLimited` | 429 |
| `diagnostics.timedOut` | 408 / abort |
| `diagnostics.parseEmpty` | Upstream 200 but no rows extracted |
| `diagnostics.usedFixtureFallback` | Serving fixture slice under live mode |
| `diagnostics.rowsDropped` | Malformed/duplicate rows removed at normalize |

Live failure behavior (no app changes required):

- Upstream errors, empty parse, or zero normalized rows → **fixture fallback** with `upstreamDegraded: true`
- Malformed/duplicate provider rows → dropped silently at gateway
- Invalid image URLs → empty `imageUrl` (app placeholder)
- Bad listing URLs → rebuilt from Mercari item id when possible

## Boundaries (intentional)

**Gateway does:** fetch, parse, normalize, retry, short cache, graceful failure.

**Gateway does not:** collectible identity, taxonomy, emotional copy, shelf state, Firestore persistence, queues, auth product.

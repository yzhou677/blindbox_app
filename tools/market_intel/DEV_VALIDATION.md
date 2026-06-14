# Market Intelligence — Dev Validation (DEV ONLY)

Temporary end-to-end validation for the Sprint 1 read path:

`Firestore → Repository → Provider → UI`

No marketplace integration. Remove this flow before production release.

## Example ID mapping

Architecture docs use simplified example ids. Dev validation uses **canonical catalog ids** so provider series fallback resolves against the loaded catalog bundle.

| Architecture example | Canonical catalog id |
|---|---|
| `lucky_big_into_energy_popmart` | `the_monsters_big_into_energy_vinyl_plush_pendant_luck` |
| `hope_big_into_energy_popmart` | `the_monsters_big_into_energy_vinyl_plush_pendant_hope` |
| `big_into_energy_popmart` | `the_monsters_big_into_energy_vinyl_plush_pendant` |

## Step 1 — Seed mock Firestore documents

### Option A — Push script (recommended)

From repo root (Firebase CLI login or service account):

```bash
node tools/market_intel/push_market_snapshots_dev.mjs
```

Writes:

| Document | Purpose |
|---|---|
| `market_snapshots/the_monsters_big_into_energy_vinyl_plush_pendant_luck` | Case A — figure snapshot |
| `market_snapshots/the_monsters_big_into_energy_vinyl_plush_pendant` | Case B — series fallback |

**Intentionally not seeded:**

- `the_monsters_big_into_energy_vinyl_plush_pendant_hope` — Case B figure (missing doc)
- `the_monsters_big_into_energy_vinyl_plush_pendant_serenity` — Case C (missing docs)

### Option B — Manual Firestore console

Create documents manually using the shapes in `market_snapshots_dev.seed.json`. Set `computedAt` to a Timestamp (now).

### Architecture example JSON (documentation only)

Figure snapshot (`lucky_big_into_energy_popmart`):

```json
{
  "level": "figure",
  "figureId": "lucky_big_into_energy_popmart",
  "seriesId": "big_into_energy_popmart",
  "estimatedValueUsd": 42,
  "trend": "rising",
  "confidence": "high",
  "recentSalesCount": 18,
  "priceRangeMinUsd": 38,
  "priceRangeMaxUsd": 48,
  "computedAt": "<Timestamp>"
}
```

Series snapshot (`big_into_energy_popmart`):

```json
{
  "level": "series",
  "seriesId": "big_into_energy_popmart",
  "estimatedValueUsd": 37,
  "trend": "stable",
  "confidence": "low",
  "recentSalesCount": 4,
  "priceRangeMinUsd": 30,
  "priceRangeMaxUsd": 45,
  "computedAt": "<Timestamp>"
}
```

Use canonical ids when validating provider fallback against the real catalog.

## Step 2 — Launch dev validation screen

The app can boot directly into `MarketSnapshotDevScreen` via dart-define:

```bash
flutter run --dart-define=MARKET_SNAPSHOT_DEV=true
```

Reads **live Firestore** by default. For offline mock UI only:

```bash
flutter run --dart-define=MARKET_SNAPSHOT_DEV=true --dart-define=MARKET_SNAPSHOT_DEV_LIVE=false
```

Requires Firebase configured on the device/emulator (same as catalog Firestore reads).

## Step 3 — Manual verification checklist

### Case A — Figure snapshot exists

- Figure id: `the_monsters_big_into_energy_vinyl_plush_pendant_luck`
- Expected: snapshot found, `level == figure`, badge `~$42 · Rising · 18 sales`
- Expected: `isSeriesEstimate == false`

### Case B — Series fallback

- Figure id: `the_monsters_big_into_energy_vinyl_plush_pendant_hope`
- Expected: snapshot found via series doc, `level == series`, badge `~$37 · Stable · 4 sales*`
- Expected: `isSeriesEstimate == true`

### Case C — Missing data

- Figure id: `the_monsters_big_into_energy_vinyl_plush_pendant_serenity`
- Expected: snapshot not found (null), no badge

### Repository sanity (optional)

On the dev screen, each case shows provider state (`loading` / `data` / `error`). Pull to refresh re-runs Firestore reads.

## Step 4 — Cleanup

When validation is complete:

1. Remove `MARKET_SNAPSHOT_DEV` launch path from `main.dart`
2. Delete `lib/features/market_intel/dev/`
3. Optionally delete dev seed docs from Firestore
4. Keep or remove `tools/market_intel/push_market_snapshots_dev.mjs` (maintainer-only)

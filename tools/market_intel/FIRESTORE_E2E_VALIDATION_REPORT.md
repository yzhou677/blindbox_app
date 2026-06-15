# Firestore End-to-End Validation Report

> Sprint 2 Step 4B/4C follow-up — validation only. No production code changes.

**Date:** 2026-06-15  
**Project:** `blindbox-collection`  
**Mode:** Live Firestore + dev seed data

---

## Result

**PASS** (with one dev-screen expectation note — see below)

---

## Step 1 — Firestore Rules

**Status: PASS**

- `firestore.rules` includes read-only `market_snapshots/{snapshotId}` rule.
- Deployed via `npx firebase-tools@latest deploy --only firestore:rules`.
- Output: `firestore: released rules firestore.rules to cloud.firestore` — deploy complete.

---

## Step 2 — Dev Seed Data

**Status: PASS**

Command:

```bash
node tools/market_intel/push_market_snapshots_dev.mjs
```

**Documents written:**

| Document ID | Level |
|-------------|-------|
| `the_monsters_big_into_energy_vinyl_plush_pendant_luck` | figure |
| `the_monsters_big_into_energy_vinyl_plush_pendant` | series |

**Example payload** (`…_luck`):

```json
{
  "level": "figure",
  "figureId": "the_monsters_big_into_energy_vinyl_plush_pendant_luck",
  "seriesId": "the_monsters_big_into_energy_vinyl_plush_pendant",
  "estimatedValueUsd": 42,
  "trend": "rising",
  "confidence": "high",
  "recentSalesCount": 18,
  "priceRangeMinUsd": 38,
  "priceRangeMaxUsd": 48,
  "computedAt": "2026-06-15T18:07:12.541Z"
}
```

Verified via Admin SDK read and anonymous Firestore REST API (confirms rules allow client reads).

---

## Step 3 — Flutter App

**Status: PASS**

```bash
flutter run -d emulator-5554 \
  --dart-define=MARKET_SNAPSHOT_DEV=true \
  --dart-define=MARKET_SNAPSHOT_DEV_LIVE=true
```

- App launched on `emulator-5554` (`app.shelfy.collector`).
- Dev screen is app `home` when `MARKET_SNAPSHOT_DEV=true`.
- **No `PERMISSION_DENIED` / `permission-denied` errors** in Flutter logs (prior blocker resolved).
- Google Play Services `NetworkCapability 37` emulator noise observed — did not affect Flutter/Firestore reads.

---

## Step 4 — Validation Cases

Validated via anonymous Firestore REST reads + provider logic from `market_snapshot_providers.dart`.

### Case A — Existing figure (`…_luck`)

**PASS**

| Check | Result |
|-------|--------|
| Firestore document found | Yes |
| `estimatedValueUsd` | 42 |
| `confidence` | high |
| `recentSalesCount` | 18 |
| `trend` | rising |
| Exceptions | None |

Expected UI: `~$42 · Rising · 18 sales` (high confidence, no `*`)

### Case B — Missing figure (`does_not_exist`)

**PASS**

| Check | Result |
|-------|--------|
| Figure doc | Not found |
| Catalog lookup | Not in bundle → no series fallback |
| Provider result | `null` |
| Exceptions | None (repository returns null on miss) |

Expected UI: "Not found" / no badge. No crash.

### Case C — Series fallback (`…_hope`)

**PASS**

| Check | Result |
|-------|--------|
| Figure ID | `the_monsters_big_into_energy_vinyl_plush_pendant_hope` |
| Figure doc | Missing |
| Series ID | `the_monsters_big_into_energy_vinyl_plush_pendant` |
| Series doc | Found |
| `estimatedValueUsd` | 37 |
| `confidence` | low |
| `recentSalesCount` | 4 |
| `trend` | stable |
| `isSeriesEstimate` | true (level = series) |

Expected UI: `~$37 · Stable · 4 sales*` (low confidence asterisk)

---

## Step 5 — Firestore Schema

**Status: PASS**

### Figure document (`…_luck`)

All fields present: `level`, `figureId`, `seriesId`, `estimatedValueUsd`, `trend`, `confidence`, `recentSalesCount`, `priceRangeMinUsd`, `priceRangeMaxUsd`, `computedAt`.

### Series document (`…_big_into_energy_vinyl_plush_pendant`)

`figureId` intentionally absent — correct per schema (`level == "series"`). All other required fields present.

---

## Dev Screen Note (not a blocker)

Built-in **Dev Case C** (`…_serenity`) expects `Null — no badge`, but a **series-level** document exists for the same series. Per current provider design, Serenity will **series-fallback** to `~$37` (same as Hope), not null. Update dev case copy/seed notes if null is the intended demo for Serenity.

---

## Screenshots

Not captured in this automated run. App was running on emulator with dev screen as home.

---

## Remaining Blockers

1. **Marketplace Insights API approval** — only blocker for live sold-listing pipeline (unchanged).
2. **Dev Case C expectation** — seed has series doc; serenity will show series estimate unless seed/docs change (documentation only).
3. **`firestore.rules` change** — deployed to Firebase; ensure committed to git when ready (local file already updated).

---

## Summary Table

| Area | Result |
|------|--------|
| **Overall** | **PASS** |
| Case A | PASS |
| Case B | PASS |
| Case C | PASS |
| Firestore Rules | PASS |
| Firestore Schema | PASS |

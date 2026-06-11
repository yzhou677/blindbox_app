# Known Runtime Notes

Recurring logcat / debug console output that is **not** an actionable bug until user-visible failure is confirmed.

**Rule of thumb:** prioritize **user-visible failures** over **diagnostic noise**. An error-level Android log does not automatically imply a product issue.

**Architecture context:** [`ARCHITECTURE_NOTES.md`](ARCHITECTURE_NOTES.md) (catalog sync, market identity, collection scope).  
**Firebase setup:** [`FIREBASE_LOCAL_SETUP.md`](FIREBASE_LOCAL_SETUP.md).

---

## Firebase / Google Play Services

### Common patterns

| Log | Level |
|-----|-------|
| `E/GoogleApiManager: Failed to get service from broker` | Error |
| `java.lang.SecurityException: Unknown calling package name 'com.google.android.gms'` | Error |
| `W/GoogleApiManager: … statusCode=DEVELOPER_ERROR` | Warning |

### Current understanding (verified on device)

- **Firestore catalog refresh and Storage may still function normally** while these appear.
- Observed: `CatalogBundleCache: refresh source=firestore` succeeds alongside `DEVELOPER_ERROR`.
- Likely causes: debug SHA-1 not registered in Firebase Console, `app.shelfy.collector` package vs production signing, or partial Play Services API registration — not necessarily broken Firestore reads.

### How to treat

| Situation | Action |
|-----------|--------|
| Catalog loads, images resolve, features under test work | **Non-blocking** — document and move on |
| Firestore refresh fails, Auth/Analytics broken, user-visible Firebase errors | **Investigate** — SHA, `google-services.json`, [`FIREBASE_LOCAL_SETUP.md`](FIREBASE_LOCAL_SETUP.md) |

**Always verify Firestore behavior** (startup source, refresh log, catalog content) before treating this log noise as a product bug.

### Dev checklist (before release)

- Production application id: `app.shelfy.collector` (Play Store / Firebase Android app **Shelfy Android**)
- Run `tools/android/sync_firebase_android_sha.ps1`; confirm debug/release SHA in Firebase Console
- Local `google-services.json` matches project (gitignored locally)

---

## Catalog Image Resolution

### Debug traces (kDebugMode only)

| Log | Meaning |
|-----|---------|
| `CatalogImageResolver[bundled] … outcome=bundled_miss` | `imageKey` not in bundled assets under `assets/catalog/`. **Expected** for most Firestore-only keys. |
| `CatalogImageResolver[disk_cache] … outcome=disk_cache_hit` | Previously fetched image served from on-device LRU cache. Healthy. |
| `CatalogImageFromKey: provider=disk_cache` | UI consuming cached bytes — no network required. |

### `bundled_miss` alone is not a bug

Typical resolution chain ([`CatalogImageResolver`](../lib/features/catalog/catalog_image_resolver.dart)):

```
bundled asset
  → disk cache (LRU + TTL)
  → Firebase Storage (extension probe: .webp, .png, …)
  → placeholder
```

A `bundled_miss` followed by `disk_cache_hit` or successful Storage load is **correct behavior**.

Release builds do not emit bundled-phase debug traces.

### Catalog bundle logs (informational)

| Log | Meaning |
|-----|---------|
| `CatalogBundleCache: startup source=persisted` | Cold start from last Firestore snapshot on disk — see [`ARCHITECTURE_NOTES.md`](ARCHITECTURE_NOTES.md) |
| `CatalogBundleCache: startup source=seed` | First install or never synced |
| `CatalogBundleCache: refresh source=firestore` | Background refresh succeeded |

---

## Storage Missing Asset Logs

### Pattern

```
CatalogImageResolver: missing Storage asset for {series|figure} imageKey="…" (all extensions probed).
```

- Logged **once per key per session** in debug (`_debugLogMissingKeyOnce`).
- Usually means **missing catalog image content** in Firebase Storage (or wrong key/path) — **not** resolver logic failure.

### Maintenance workflow

1. Reproduce in debug build; browse catalog until placeholders appear on a **fresh device** (no disk cache).
2. Call `CatalogImageResolver.debugDumpMissingKeys()` (debug only) for a grouped snapshot.
3. Compare keys against Storage bucket layout ([`FIREBASE_STORAGE_CATALOG.md`](../lib/features/catalog/firestore/FIREBASE_STORAGE_CATALOG.md)) and `tools/seed/`.
4. Backfill Storage objects or seed/bundled assets for truly missing keys.

**Ignore if:** disk cache or bundled asset eventually serves the image and UI looks correct.

---

## Flutter / Android Runtime Noise

Generally **informational** unless tied to visible jank, crashes, or broken UI.

| Log | Notes |
|-----|-------|
| `D/FlutterRenderer: Width is zero` | Transient before first layout frame |
| `I/Choreographer: Skipped N frames` | Startup catalog hydrate + first paint; investigate only if user-visible jank persists |
| `userfaultfd: MOVE ioctl seems unsupported` | Samsung / kernel noise |
| `E/Kumiho-Kumiho: failed to retrieve policy` | Samsung system component |
| `W/InteractionJankMonitor: without READ_DEVICE_CONFIG` | System jank monitor permission |
| `V/NativeCrypto: … Broken pipe` / `Read error: … Software caused connection abort` | App backgrounded, adb wireless disconnect, gRPC teardown |
| `W/ManagedChannelImpl: Failed to resolve name` | Often follows backgrounding or lost network during wireless debugging |
| `CollectibleThumbImage: local shelf media unavailable — file missing` | Stale `localImageUri` on custom shelf figure — placeholder expected |

### Impeller (monitor only)

```
E/flutter: … ImpellerValidationBreak: Contents::SetInheritedOpacity
```

Flutter engine validation during opacity/sheet animations. Investigate only if visible flicker or missing content.

---

## Action Required

Treat as real product issues:

| Symptom | Likely cause |
|---------|--------------|
| `CatalogBundleCache: Firestore refresh skipped:` (repeated) | Network, rules, or Firebase init |
| `Firebase init skipped:` at startup | Invalid/missing Firebase platform config |
| `CatalogBundleCache: startup source=empty` after prior sync | Corrupt/missing persisted file |
| Catalog images blank on **fresh install** | No bundled + no disk cache + no Storage object |
| User-visible rendering defects | Reproduce; may relate to Impeller or widget opacity |
| App crash / ANR | Always actionable |
| Market browse empty with gateway errors | `MARKET_GATEWAY_EBAY`, gateway URL, network — separate from catalog |

---

## Future Developers

1. **Read this doc first** before filing bugs for `flutter run` logcat warnings.
2. **Confirm user impact** — broken screen, wrong data, or crash?
3. **Distinguish debug vs release** — many catalog traces are `kDebugMode` only.
4. **Separate universes** — Catalog (Firestore + Storage), Collection shelf (local prefs), Market (gateway) — different failure modes. See [`ARCHITECTURE_NOTES.md`](ARCHITECTURE_NOTES.md).
5. **Update this file** when new expected diagnostics are added.

---

*Last verified: Android debug run on physical device (wireless adb); catalog `startup source=persisted` + `refresh source=firestore` succeeding.*

# Firebase local setup

Client config files are **gitignored** so API keys are not pushed to GitHub. Each developer (and CI, if needed) supplies their own copies.

**Project:** `blindbox-collection` · **Android app id:** `app.shelfy.collector`

---

## Firebase services in Shelfy

| Service | Used? | Role |
|---------|-------|------|
| **Firebase Core** | Yes | `ensureFirebaseInitialized()` in `main.dart` |
| **Cloud Firestore** | Yes | Catalog (`brands`, `ips`, `series`, `figures`); Discover official feed (`official_feed_items`) |
| **Cloud Storage** | Yes | Catalog art at `catalog/series/*`, `catalog/figures/*` via `getDownloadURL()` |
| **Cloud Functions (market)** | Yes (HTTPS) | Client calls `GET …/market/v1/browse` via `http` — **not** `firebase_functions` SDK |
| Firebase Authentication | No | — |
| Google Sign-In / Phone Auth | No | — |
| App Check | Yes, locator only | Play Integrity / Apple App Attest protects `subjectLocatorV1` |
| Analytics / Crashlytics / FCM / Remote Config / Dynamic Links | No | — |

Collection shelf state is **local-only** (`SharedPreferences`); it does not use Firestore.

---

## Firebase CLI config (`firebase.json`)

Copy the tracked template (rules + indexes + market functions codebase):

```bash
cp firebase.json.example firebase.json
```

Edit `firebase.json` locally if your project needs extra emulators or deploy targets — do not commit it (see `.gitignore`).

---

## Android (required for Firestore on device)

### Config files

1. Firebase console → Project settings → Your apps → Android (`app.shelfy.collector`).
2. Download **`google-services.json`** into:

   `android/app/google-services.json`

   Or copy the example and fill values:

   `cp android/app/google-services.json.example android/app/google-services.json`

3. Ensure `lib/firebase_options.dart` exists (copy from example or run FlutterFire):

   `cp lib/firebase_options.example.dart lib/firebase_options.dart`

   Then paste Android `apiKey`, `appId`, `messagingSenderId`, `projectId`, and `storageBucket` from the console, or run:

   ```bash
   dart pub global activate flutterfire_cli
   npx firebase-tools@14.11.0 login
   dart pub global run flutterfire_cli:flutterfire configure
   ```

   On Windows, prefer `npx firebase-tools@14.11.0` if the global `firebase` command fails with missing `hosting/init.js`.

### SHA fingerprints and App Check

Catalog Firestore and Storage use public read rules and do not require
certificate fingerprints. The subject-locator callable uses App Check, so its
production rollout requires the signing/app registration expected by the
selected attestation provider. See
[`FIGURE_SUBJECT_LOCATOR_ENDPOINT.md`](FIGURE_SUBJECT_LOCATOR_ENDPOINT.md).

Unregistered signing SHA-1/SHA-256 can still produce `GoogleApiManager` / `DEVELOPER_ERROR` log noise on some devices while Firestore and Storage continue to work — see [`KNOWN_RUNTIME_NOTES.md`](KNOWN_RUNTIME_NOTES.md).

Optional: register local debug/release SHA to reduce logcat noise:

```powershell
nvm use 22.21.1   # global firebase-tools may be broken on Node 24
.\tools\android\sync_firebase_android_sha.ps1
```

Manual: `cd android && .\gradlew signingReport` → add debug + release SHA-1/SHA-256 in Firebase console if desired.

For Play-distributed builds, register the Play App Signing certificate rather
than only the upload keystore. Debug App Check tokens belong only in
development environments.

---

## iOS (optional)

- Add `ios/Runner/GoogleService-Info.plist` from the console (gitignored).
- Run `flutterfire configure` with iOS selected, or fill `ios` in `firebase_options.dart`.

Required only if shipping an iOS build that uses Firestore/Storage.

---

## Already in the repo

- Gradle: `com.google.gms.google-services` on the Android app module.
- Dart: `firebase_core`, `cloud_firestore`, `firebase_storage`.
- `ensureFirebaseInitialized()` in `main.dart` (app still runs if init fails; catalog stays on `bootstrapPlaceholder` / persisted cache until Firestore succeeds — no APK metadata seed).

---

## If `google-services.json` was committed before gitignore

Remove it from Git history tracking (keeps your local file):

```bash
git rm --cached android/app/google-services.json
git rm --cached lib/firebase_options.dart
```

Then commit the `.gitignore` update. Rotate API keys in Google Cloud Console if the repo was public.

---

## Admin / server credentials

Never commit `*-firebase-adminsdk-*.json` or service account keys — patterns are in `.gitignore`.

---

## Security rules (draft in repo)

Baseline rules live at repo root: `firestore.rules`, `storage.rules` (wired via `firebase.json.example` → local `firebase.json`).

- **Client:** read-only `brands` / `ips` / `series` / `figures` / `official_feed_items`; read-only `catalog/**` Storage; no client writes.
- **Ingestion:** `tools/official_feed/push_official_feed.mjs` and external catalog pipelines must use **Admin SDK** or service account (bypass client rules).

Deploy only after staging validation (from repo root; local `firebase.json` required — see above):

```bash
npx --prefix functions firebase deploy --only firestore:rules,storage --project blindbox-collection
```

Use `storage`, not `storage:rules`: with a single default bucket in `firebase.json` (no named targets), `storage:rules` fails with *Could not find rules for the following storage targets: rules*.

Do not deploy rules as part of routine app releases until the release hardening checklist is signed off.

---

## Firebase release checklist (v1.0.0)

Use this before tagging a production Android release. **Do not treat generic Firebase SHA checklists as Shelfy release blockers** — they apply to Auth/OAuth flows this app does not use.

### Client build environment

- [ ] `android/app/google-services.json` present at build time (gitignored; package `app.shelfy.collector`, project `blindbox-collection`)
- [ ] `lib/firebase_options.dart` matches the Firebase Android app (committed in repo)
- [ ] iOS only: `ios/Runner/GoogleService-Info.plist` if shipping iOS

### Verify Firebase backend deployment

Confirm live in Firebase Console / deploy logs — **not** merely present in git:

- [ ] **Firestore rules** deployed (`firestore.rules` — public read on catalog + `official_feed_items`)
- [ ] **Storage rules** deployed (`storage.rules` — public read on `catalog/**`)
- [ ] **Firestore indexes** deployed (`firestore.indexes.json` — composite index for `official_feed_items` query)
- [ ] **Market Cloud Function** deployed (`functions:market`) with live eBay credentials if Market tab should show live listings — see [`EBAY_GATEWAY.md`](EBAY_GATEWAY.md)

Deploy commands (from repo root; local `firebase.json` required):

```bash
npx --prefix functions firebase deploy --only firestore:rules,storage --project blindbox-collection
npx --prefix functions firebase deploy --only firestore:indexes --project blindbox-collection
npx --prefix functions firebase deploy --only functions:market --project blindbox-collection
npx --prefix functions firebase deploy --only functions:market:subjectLocatorV1 --project blindbox-collection
```

### Post-deploy smoke (device or staging build)

- [ ] Cold launch online: catalog loads or persisted cache + background refresh (`CatalogBundleCache: refresh source=firestore`)
- [ ] Discover official feed: loads or empty gracefully (no `permission-denied`; index missing shows as empty feed, not crash)
- [ ] Catalog images: Storage objects resolve or placeholder after bundled/disk miss
- [ ] Market tab (if gateway enabled): listings load or empty state with gateway errors only in logs

### SHA certificates and protected callable rollout

Release SHA registration remains unnecessary for unauthenticated Catalog
Firestore/Storage reads. It is part of the production App Check setup for the
subject locator where required by the selected attestation provider.

Optional: run `tools/android/sync_firebase_android_sha.ps1` to reduce `DEVELOPER_ERROR` log noise during development.

Configure Release SHA and Play App Signing SHA before enabling production App
Check enforcement for the locator.

Manual verification history: [`archive/2026-07/release_candidate_test_plan.md`](archive/2026-07/release_candidate_test_plan.md) §6.

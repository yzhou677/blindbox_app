# Firebase local setup

Client config files are **gitignored** so API keys are not pushed to GitHub. Each developer (and CI, if needed) supplies their own copies.

## Firebase CLI config (`firebase.json`)

Copy the tracked template (rules + indexes + market functions codebase):

```bash
cp firebase.json.example firebase.json
```

Edit `firebase.json` locally if your project needs extra emulators or deploy targets — do not commit it (see `.gitignore`).

## Android (required for Firestore on device)

### SHA fingerprints (fixes `GoogleApiManager` / `DEVELOPER_ERROR` on device)

Debug/release builds must register signing SHA-1 **and** SHA-256 in Firebase. Without them, Play Services logs `DEVELOPER_ERROR` even when `google-services.json` exists.

Automated (logged into Firebase CLI):

```powershell
nvm use 22.21.1   # global firebase-tools may be broken on Node 24
.\tools\android\sync_firebase_android_sha.ps1
```

Manual: `cd android && .\gradlew signingReport` → add **debug** + **release** SHA-1/SHA-256 in Firebase console → re-download `google-services.json` → `flutter clean && flutter run` (reinstall on device).

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

## iOS (optional)

- Add `ios/Runner/GoogleService-Info.plist` from the console (also gitignored).
- Run `flutterfire configure` with iOS selected, or fill `ios` in `firebase_options.dart`.

## Already in the repo

- Gradle: `com.google.gms.google-services` on the Android app module.
- Dart: `firebase_core`, `cloud_firestore`, `firebase_storage`.
- `ensureFirebaseInitialized()` in `main.dart` (app still runs if init fails; catalog stays on `bootstrapPlaceholder` / persisted cache until Firestore succeeds — no APK metadata seed).

## If `google-services.json` was committed before gitignore

Remove it from Git history tracking (keeps your local file):

```bash
git rm --cached android/app/google-services.json
git rm --cached lib/firebase_options.dart
```

Then commit the `.gitignore` update. Rotate API keys in Google Cloud Console if the repo was public.

## Admin / server credentials

Never commit `*-firebase-adminsdk-*.json` or service account keys — patterns are in `.gitignore`.

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

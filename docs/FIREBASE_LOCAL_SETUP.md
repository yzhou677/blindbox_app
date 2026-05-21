# Firebase local setup

Client config files are **gitignored** so API keys are not pushed to GitHub. Each developer (and CI, if needed) supplies their own copies.

## Android (required for Firestore on device)

1. Firebase console → Project settings → Your apps → Android (`com.example.blindbox_app`).
2. Download **`google-services.json`** into:

   `android/app/google-services.json`

   Or copy the example and fill values:

   `cp android/app/google-services.json.example android/app/google-services.json`

3. Ensure `lib/firebase_options.dart` exists (copy from example or run FlutterFire):

   `cp lib/firebase_options.example.dart lib/firebase_options.dart`

   Then paste Android `apiKey`, `appId`, `messagingSenderId`, `projectId`, and `storageBucket` from the console, or run:

   ```bash
   dart pub global activate flutterfire_cli
   firebase login
   flutterfire configure
   ```

## iOS (optional)

- Add `ios/Runner/GoogleService-Info.plist` from the console (also gitignored).
- Run `flutterfire configure` with iOS selected, or fill `ios` in `firebase_options.dart`.

## Already in the repo

- Gradle: `com.google.gms.google-services` on the Android app module.
- Dart: `firebase_core`, `cloud_firestore`, `firebase_storage`.
- `ensureFirebaseInitialized()` in `main.dart` (app still runs if init fails; catalog uses seed JSON by default).

## If `google-services.json` was committed before gitignore

Remove it from Git history tracking (keeps your local file):

```bash
git rm --cached android/app/google-services.json
git rm --cached lib/firebase_options.dart
```

Then commit the `.gitignore` update. Rotate API keys in Google Cloud Console if the repo was public.

## Admin / server credentials

Never commit `*-firebase-adminsdk-*.json` or service account keys — patterns are in `.gitignore`.

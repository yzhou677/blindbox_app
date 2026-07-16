# Shelfy (blindbox_app)

Shelfy is a Flutter app for designer toy and blind box collectors.  
It focuses on an image-first, calm browsing experience with local-first collection tracking.

## Demo

<p align="center">
  <a href="https://youtu.be/1BNYPqDCTv4?si=V4nwskF9iDZ1AzTG">
    <img
      src="https://img.youtube.com/vi/1BNYPqDCTv4/hqdefault.jpg"
      alt="Shelfy Preview"
      width="480">
  </a>
</p>

<p align="center">
  <a href="https://youtu.be/1BNYPqDCTv4?si=V4nwskF9iDZ1AzTG">
    <strong>▶ Watch Shelfy Preview on YouTube</strong>
  </a>
</p>

## What The App Includes

- `Collection` tab: local-first shelf, custom series, wishlist/owned states, completion tiers (`Completed Series`, `Master Complete`), collapsible **Collection Insights** dashboard, and Insights screen (Collector Type reveal — **10** types, resolver **6.1**; see `docs/COLLECTION_ARCHITECTURE_NOTES.md`)
- `Discover` tab: Firestore-backed catalog browse, release rails, and shared token-based search (Search V2)
- `Market` tab: live eBay browse/search via Firebase gateway (separate from catalog content)

Bottom tab order and cold start are currently:

1. Collection
2. Discover
3. Market

## Product And Architecture Boundaries

The app intentionally separates three universes:

- `Catalog universe` (`lib/features/catalog/`): read-only reference data (brands, IPs, series, figures)
- `Collection universe` (`lib/features/collection/`): user-private, local-first shelf state
- `Market/Home universe` (`lib/features/market/`, `lib/features/home/`): browse/discovery surfaces

Do not mix these data paths unless a task explicitly requires it.

For full details, read:

- [Agent instructions (Codex / shared)](./AGENTS.md)
- [Durable decisions](./docs/decisions/)
- [Architecture reference](./.cursor/ARCHITECTURE.md)

## Tech Stack

- Flutter / Dart
- Riverpod (`flutter_riverpod`) for state
- `go_router` for navigation
- `shared_preferences` for collection persistence
- Firebase (catalog-only): `firebase_core`, `cloud_firestore`, `firebase_storage`

## Project Structure

```text
lib/
  core/              # app bootstrap, router, theme, layout rhythm
  features/
    catalog/         # read-only catalog universe
    collection/      # local-first shelf universe
    home/            # discovery feed
    market/          # listing browse/search universe
  models/            # legacy presentation models (frozen; no new additions)
  shared/widgets/    # cross-feature widgets
```

## Getting Started

### 1) Prerequisites

- Flutter SDK (matching `pubspec.yaml` constraints)
- Dart SDK (bundled with Flutter)
- Android Studio / Xcode (as needed)
- Firebase CLI (for rules/functions workflows)

### 2) Install dependencies

```bash
flutter pub get
```

### 3) Run app

```bash
flutter run
```

## Firebase Local Setup

Shelfy uses **Firebase Core**, **Cloud Firestore**, and **Cloud Storage** for read-only catalog and official feed. Market browse calls the **HTTPS market Cloud Function** via the `http` package (not `firebase_functions`). Collection shelf data stays local.

Use the full setup guide:

- [docs/FIREBASE_LOCAL_SETUP.md](./docs/FIREBASE_LOCAL_SETUP.md) — local dev setup and **[Firebase release checklist](./docs/FIREBASE_LOCAL_SETUP.md#firebase-release-checklist-v100)**

Quick notes:

- `firebase.json` is local and gitignored (copy from `firebase.json.example`)
- `android/app/google-services.json` is gitignored; `lib/firebase_options.dart` is committed for project `blindbox-collection`
- Collection data is local-first and not synced to Firestore
- **Release SHA registration is not required** for the current feature set (no Firebase Auth, Sign-In, Phone Auth, or App Check). See the release checklist in `FIREBASE_LOCAL_SETUP.md`.

### Backend deployment (release)

Verify before shipping — not client code changes:

```bash
npx --prefix functions firebase deploy --only firestore:rules,storage --project blindbox-collection
npx --prefix functions firebase deploy --only functions:market --project blindbox-collection
```

Deploy Firestore indexes from `firestore.indexes.json` (required for Discover official feed). Use `storage`, not `storage:rules`, for single-bucket config. See [FIREBASE_LOCAL_SETUP.md](./docs/FIREBASE_LOCAL_SETUP.md#firebase-release-checklist-v100).

## Common Commands

Run analyzer:

```bash
flutter analyze
```

Run all tests:

```bash
flutter test
```

Run a specific test file:

```bash
flutter test test/collection_shelf_brand_facets_test.dart
```

## Branding Assets

Launcher icon and splash derive from `assets/images/app_icon.png` via `pubspec.yaml`:

```bash
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

## Additional Docs

**Architecture & testing**

- [Catalog architecture](./docs/CATALOG_ARCHITECTURE.md)
- [Search architecture](./docs/SEARCH_ARCHITECTURE.md)
- [Testing notes](./docs/TESTING.md)
- [Project overview](./docs/PROJECT_OVERVIEW.md)

**Product & release**

- [Durable decisions](./docs/decisions/)
- [Project overview](./docs/PROJECT_OVERVIEW.md)
- [Privacy policy](./docs/PRIVACY_POLICY.md)
- [Documentation archive](./docs/archive/)

## Notes For Contributors

- Keep diffs small and feature-local.
- Prefer existing shared primitives over screen-specific one-offs.
- Add or update tests for behavior changes.
- Avoid architecture rewrites during stabilization work.

# Shelfy (blindbox_app)

Shelfy is a Flutter app for designer toy and blind box collectors.  
It focuses on an image-first, calm browsing experience with local-first collection tracking.

## Demo

<p align="center">
  <a href="https://youtube.com/shorts/iEzrFSuXeew">
    <img src="https://img.youtube.com/vi/iEzrFSuXeew/hqdefault.jpg" alt="Shelfy app demo" width="480">
  </a>
</p>

<p align="center">
  <a href="https://youtube.com/shorts/iEzrFSuXeew"><strong>▶ Watch demo on YouTube</strong></a>
</p>

## What The App Includes

- `Collection` tab: your private shelf, custom series, figure status tracking
- `Discover` tab: catalog browsing and release-style exploration
- `Market` tab: listing browse/search (separate from catalog content)

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

Use the full setup guide:

- [docs/FIREBASE_LOCAL_SETUP.md](./docs/FIREBASE_LOCAL_SETUP.md)

Quick notes:

- `firebase.json` is local and gitignored (copy from `firebase.json.example`)
- `google-services.json` and `firebase_options.dart` are local/env-specific
- Collection data is local-first and not synced to Firestore

### Rules deployment

From repo root:

```bash
npx --prefix functions firebase deploy --only firestore:rules,storage --project blindbox-collection
```

For single-bucket config, use `storage` (not `storage:rules`).

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

- [Project overview](./docs/PROJECT_OVERVIEW.md)
- [Release candidate test plan](./docs/release_candidate_test_plan.md)
- [Collectible immersive presentation](./docs/COLLECTIBLE_IMMERSIVE_PRESENTATION.md)
- [Collectible market intelligence](./docs/COLLECTIBLE_MARKET_INTELLIGENCE.md)
- [Collection emotional intelligence](./docs/COLLECTION_EMOTIONAL_INTELLIGENCE.md)

## Notes For Contributors

- Keep diffs small and feature-local.
- Prefer existing shared primitives over screen-specific one-offs.
- Add or update tests for behavior changes.
- Avoid architecture rewrites during stabilization work.

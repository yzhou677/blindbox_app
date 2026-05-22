# Cursor rules and architecture — where things live

**Do not add long agent rule blocks here.** This file is an index for humans browsing `docs/`. Cursor agents load rules from `.cursor/` automatically.

## Canonical sources (for agents and implementation)

| What | Path |
|------|------|
| **Architecture** (three universes, data flow, Firebase, naming) | [`.cursor/ARCHITECTURE.md`](../.cursor/ARCHITECTURE.md) |
| **Agent rules** (always-on and scoped snippets) | [`.cursor/rules/`](../.cursor/rules/) |
| **Conformity checklist** | [`.cursor/CONFORMITY_AUDIT.md`](../.cursor/CONFORMITY_AUDIT.md) |

### Rule files in `.cursor/rules/`

- `product-principles.mdc` — collectible lifestyle direction, calm UX, maintainability (always apply)
- `offline-async-media.mdc` — offline-first, optimistic UI, imageKey, shared mutations/modals (always apply)
- `project-architecture.mdc` — catalog / shelf / market boundaries (always apply)
- `catalog-collection-boundary.mdc` — when editing catalog or collection
- `firebase-catalog.mdc` — Firestore + Storage catalog paths
- `flutter-ui-ux.mdc` — collectible UI tone and spacing

## Human docs in `docs/`

| Doc | Purpose |
|-----|---------|
| [`PROJECT_OVERVIEW.md`](PROJECT_OVERVIEW.md) | Product vision and feature goals |
| [`FIREBASE_LOCAL_SETUP.md`](FIREBASE_LOCAL_SETUP.md) | Local Firebase / emulator setup |

See also [`README.md`](README.md) in this folder.

## Quick habits (summary only)

- Follow existing feature boundaries; extend before inventing new layers
- Riverpod + `collectionNotifier` for shelf writes; no HTTP in widgets
- Cozy, imagery-first UI; use `FeedRhythm` spacing
- MVP: focused diffs; no mass refactors unless asked

For full detail, use [`.cursor/ARCHITECTURE.md`](../.cursor/ARCHITECTURE.md).

# Cursor rules and architecture — where things live

**Do not add long agent rule blocks here.** This file is an index for humans browsing `docs/`.

## Dual agent entry points

| Audience | Entry |
|----------|--------|
| **Codex** (and any AGENTS.md-aware tool) | Root [`AGENTS.md`](../AGENTS.md); Insights scope [`lib/features/collection/insights/AGENTS.md`](../lib/features/collection/insights/AGENTS.md) |
| **Cursor** | [`.cursor/rules/`](../.cursor/rules/) + [`.cursor/ARCHITECTURE.md`](../.cursor/ARCHITECTURE.md) |

Keep durable meaning aligned across both. Prefer architecture docs for deep
product history; keep agent instruction files short.

## Canonical sources (for agents and implementation)

| What | Path |
|------|------|
| **Shared agent contract** | [`AGENTS.md`](../AGENTS.md) |
| **Architecture** (three universes, data flow, Firebase, naming) | [`.cursor/ARCHITECTURE.md`](../.cursor/ARCHITECTURE.md) |
| **Catalog spec** (runtime cache, providers, Search V2, availability) | [`CATALOG_ARCHITECTURE.md`](CATALOG_ARCHITECTURE.md) |
| **Search spec** (normalization, token AND, haystack) | [`SEARCH_ARCHITECTURE.md`](SEARCH_ARCHITECTURE.md) |
| **Testing / RC workflow** | [`TESTING.md`](TESTING.md) |
| **Cursor agent rules** (always-on and scoped snippets) | [`.cursor/rules/`](../.cursor/rules/) |
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
| [`CATALOG_ARCHITECTURE.md`](CATALOG_ARCHITECTURE.md) | Catalog runtime: Firestore, persisted cache, provider graph, availability |
| [`SEARCH_ARCHITECTURE.md`](SEARCH_ARCHITECTURE.md) | Search V2: normalizer, tokenizer, matcher, haystack |
| [`TESTING.md`](TESTING.md) | RC automated gate, emulator ADB notes |
| [`PROJECT_OVERVIEW.md`](PROJECT_OVERVIEW.md) | Product vision and feature goals |
| [`FIREBASE_LOCAL_SETUP.md`](FIREBASE_LOCAL_SETUP.md) | Local Firebase / emulator setup |

See also [`README.md`](README.md) in this folder.

## Quick habits (summary only)

- Follow existing feature boundaries; extend before inventing new layers
- Riverpod + `collectionNotifier` for shelf writes; no HTTP in widgets
- Cozy, imagery-first UI; use `FeedRhythm` spacing
- MVP: focused diffs; no mass refactors unless asked

For full detail, use [`.cursor/ARCHITECTURE.md`](../.cursor/ARCHITECTURE.md).

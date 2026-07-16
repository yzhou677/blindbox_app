# Cursor Rules And Architecture

This file is an index for humans browsing `docs/`. Do not add long agent rule
blocks here.

## Entry Points

| Audience | Entry |
| --- | --- |
| Codex and AGENTS-aware tools | [`AGENTS.md`](../AGENTS.md) |
| Cursor | [`.cursor/rules/`](../.cursor/rules/) and [`.cursor/ARCHITECTURE.md`](../.cursor/ARCHITECTURE.md) |
| Durable decisions | [`decisions/`](decisions/) |

Keep durable meaning aligned across Codex and Cursor. Prefer ADRs/PDRs for
long-lived decisions, architecture docs for implementation detail, and agent
files for short operational instructions.

## Canonical Sources

| What | Path |
| --- | --- |
| Shared agent contract | [`AGENTS.md`](../AGENTS.md) |
| Durable ADRs/PDRs | [`decisions/`](decisions/) |
| Architecture reference | [`.cursor/ARCHITECTURE.md`](../.cursor/ARCHITECTURE.md) |
| Catalog spec | [`CATALOG_ARCHITECTURE.md`](CATALOG_ARCHITECTURE.md) |
| Search spec | [`SEARCH_ARCHITECTURE.md`](SEARCH_ARCHITECTURE.md) |
| Testing | [`TESTING.md`](TESTING.md) |
| Cursor agent rules | [`.cursor/rules/`](../.cursor/rules/) |
| Historical conformity audit | [`archive/2026-07/CONFORMITY_AUDIT.md`](archive/2026-07/CONFORMITY_AUDIT.md) |

## Rule Files

- `product-principles.mdc` - collectible lifestyle direction and truthful copy
- `offline-async-media.mdc` - offline-first, optimistic UI, media boundaries
- `project-architecture.mdc` - catalog / shelf / market boundaries
- `catalog-collection-boundary.mdc` - scoped catalog and collection reminders
- `firebase-catalog.mdc` - Firestore and Storage catalog paths
- `flutter-ui-ux.mdc` - collector UI tone and spacing

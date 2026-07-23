# Shelfy Agent Guide

Shelfy is a Flutter app for designer-toy collectors. Product behavior and
collector trust take priority over implementation convenience.

This file is the repository entry point for Codex and other AGENTS-aware tools.
It should introduce where decisions live; it should not become a second
architecture or product documentation system.

Cursor continues to load `.cursor/rules/`. Keep those rules aligned with this
guide and the decision records.

---

## Repository Philosophy

- Prefer product outcomes and explicit contracts over accidental historical
  behavior.
- Keep diffs small, feature-local, and easy to review.
- Do not change production behavior during audit-only or documentation-only
  tasks.
- Do not invent thresholds, formulas, or product semantics.
- Preserve backward compatibility for persisted user data unless a migration is
  explicitly requested.
- A feature can be removed; a durable decision should still stand. Put those
  durable decisions in ADRs or PDRs, not in chat context.

---

## Architecture

Architecture Decision Records live in
[`docs/decisions/architecture/`](docs/decisions/architecture/).

Read these first when touching the relevant area:

| Area | Authoritative source |
| ---- | -------------------- |
| Recommendations / For You | [`ADR-001: Recommendation Semantics`](docs/decisions/architecture/ADR-001-recommendation-semantics.md) |
| Catalog runtime / Search V2 | [`docs/CATALOG_ARCHITECTURE.md`](docs/CATALOG_ARCHITECTURE.md), [`docs/SEARCH_ARCHITECTURE.md`](docs/SEARCH_ARCHITECTURE.md) |
| Figure Recognition | [`docs/figure-recognition.md`](docs/figure-recognition.md), [`ADR-003`](docs/decisions/architecture/ADR-003-ai-figure-recognition-retrieval-architecture.md), [`PDR-001`](docs/decisions/product/PDR-001-figure-recognition-principles.md) |
| App-wide architecture notes | [`docs/ARCHITECTURE_NOTES.md`](docs/ARCHITECTURE_NOTES.md) |
| Three universes, Firebase, folder layout | [`.cursor/ARCHITECTURE.md`](.cursor/ARCHITECTURE.md) |

Current high-level boundaries:

- **Catalog** (`lib/features/catalog/`): read-only reference data, catalog
  identity, Firestore/Storage catalog paths.
- **Collection** (`lib/features/collection/`): local-first private shelf,
  `CollectionSnapshot`, `CollectionNotifier`, persisted user state.
- **Market / Home**: discovery and marketplace listings through `MarketSource`
  and related feature-owned data paths.

Do not mix these boundaries unless the task explicitly asks for an architecture
change and the relevant ADR is updated or created.

---

## Product

Product Decision Records live in
[`docs/decisions/product/`](docs/decisions/product/).

Read these before changing collector-facing semantics:

| Area | Authoritative source |
| ---- | -------------------- |
| Collector Type product meaning | [`PDR-001: Collector Type Semantics`](docs/decisions/product/PDR-001-collector-type-semantics.md) |
| Complete / Master Complete meaning | [`PDR-002: Completion Semantics`](docs/decisions/product/PDR-002-completion-semantics.md) |
| Dreamer product meaning | [`PDR-003: Dreamer Semantics`](docs/decisions/product/PDR-003-dreamer-semantics.md) |
| On Display daily rotation | [`PDR-004: On Display Daily Rotation`](docs/decisions/product/PDR-004-on-display-daily-rotation.md) |
| On Display information hierarchy | [`PDR-005: On Display Information Hierarchy`](docs/decisions/product/PDR-005-on-display-information-hierarchy.md) |
| Collection / Insights implementation contract | [`docs/COLLECTION_ARCHITECTURE_NOTES.md`](docs/COLLECTION_ARCHITECTURE_NOTES.md) |
| Product outline | [`docs/PROJECT_OVERVIEW.md`](docs/PROJECT_OVERVIEW.md) |

When working under `lib/features/collection/insights/`, also follow
[`lib/features/collection/insights/AGENTS.md`](lib/features/collection/insights/AGENTS.md).

---

## Development Workflow

1. Identify whether the request is audit-only, documentation-only, or an
   implementation change.
2. Read the relevant ADR, PDR, architecture note, and scoped `AGENTS.md`.
3. Respect existing feature ownership and Riverpod/provider patterns.
4. Keep behavior changes intentional and covered by focused tests.
5. Avoid drive-by refactors, mass migrations, and unrelated cleanup.
6. Update ADRs/PDRs only when the durable decision changes; update
   implementation docs when only the implementation changes.

Do not commit, push, auto-merge, or update `git config` unless explicitly
requested.

---

## Verification Expectations

For relevant code changes, run:

```text
flutter analyze
flutter test <targeted tests>
```

Use [`docs/TESTING.md`](docs/TESTING.md) for current test guidance and release
candidate workflow.

Before handing off, report:

- commands run
- pass/fail totals when tests are run
- files changed
- remaining risks
- anything not verified

Documentation-only changes do not require Flutter tests unless they alter code,
configuration, generated artifacts, or examples that are executed.

---

## Documentation Rules

- Durable architecture decisions belong in ADRs.
- Durable product semantics belong in PDRs.
- Implementation details belong in focused architecture or feature docs.
- Agent files should link to decisions and specs rather than copying them.
- Historical audits and temporary reports should not be presented as current
  authority.
- When moving a decision into ADR/PDR form, replace old duplicated sections with
  summaries and links instead of abruptly deleting useful context.


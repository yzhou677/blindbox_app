# Shelfy — agent instructions

Shelfy is a Flutter app for designer-toy collectors. Product behavior and
collector trust take priority over implementation convenience. Prefer product
outcomes and explicit contracts over accidental historical behavior.

This file is the shared, Codex-readable repository contract. Cursor continues
to load `.cursor/rules/`; keep both aligned — do not invent contradictory rules.

`AGENTS.md` tells the agent **how to work**. Architecture docs explain **how
Shelfy works** — read them; do not paste them here.

---

## Required reading before changing sensitive areas

| Area | Read first |
| ---- | ---------- |
| Collection / Insights / Collector Type | [`docs/COLLECTION_ARCHITECTURE_NOTES.md`](docs/COLLECTION_ARCHITECTURE_NOTES.md) |
| App-wide decisions, performance baselines | [`docs/ARCHITECTURE_NOTES.md`](docs/ARCHITECTURE_NOTES.md) |
| Product outline | [`docs/PROJECT_OVERVIEW.md`](docs/PROJECT_OVERVIEW.md) |
| Three universes, Firebase, folder layout | [`.cursor/ARCHITECTURE.md`](.cursor/ARCHITECTURE.md) |
| Catalog runtime / Search V2 | [`docs/CATALOG_ARCHITECTURE.md`](docs/CATALOG_ARCHITECTURE.md), [`docs/SEARCH_ARCHITECTURE.md`](docs/SEARCH_ARCHITECTURE.md) |
| Recommendations (“For You”) | [`docs/RECOMMENDATION_SEMANTICS.md`](docs/RECOMMENDATION_SEMANTICS.md) |
| Test / RC commands | [`docs/TESTING.md`](docs/TESTING.md) |

When working under `lib/features/collection/insights/`, also follow the nested
[`lib/features/collection/insights/AGENTS.md`](lib/features/collection/insights/AGENTS.md).

---

## Architecture boundaries (do not mix)

1. **Catalog** (`lib/features/catalog/`) — read-only reference; Firestore + Storage;
   `imageKey` + `CatalogImageResolver`. No shelf state.
2. **Collection** (`lib/features/collection/`) — local-first private shelf;
   `CollectionSnapshot` + `CollectionNotifier`. No cloud sync unless tasked.
3. **Market / Home** — marketplace listings via `MarketSource`; not catalog
   bundle / `imageKey` for listing content. Save to shelf only through
   collection notifier APIs.

Details, legacy freezes (`lib/models/` locked; no new `lib/services/`), Riverpod,
and media rules live in `.cursor/ARCHITECTURE.md` and `.cursor/rules/`.

---

## Change discipline

- Distinguish **audit-only** from **implementation**. Audits must not change
  product behavior.
- Do not invent thresholds, formulas, or product semantics.
- Every Collector Type threshold needs a plain-language product explanation
  (see Collection architecture notes).
- Prefer minimal, targeted diffs. No drive-by refactors or mass migrations.
- Preserve backward compatibility for persisted user data unless migration is
  explicit in the task.
- Do not silently rewrite Collector Type reveal identity or history.
- Do not duplicate canonical completion mathematics — use
  `resolveSeriesCompletion` / `aggregateShelfCompletion`.
- Remove temporary traces, debug instrumentation, and audit artifacts before
  merge.
- Never claim a fix without reporting verification evidence.
- Behavior changes: add or update tests in the same change.
- UI: collectible lifestyle feel — image-first, calm, reuse shared sheets /
  `FeedRhythm`; see `.cursor/rules/product-principles.mdc` and
  `flutter-ui-ux.mdc`.
- Offline-first / optimistic collection mutations / `imageKey`-only catalog UI —
  see `.cursor/rules/offline-async-media.mdc`.

---

## Key Collection / Insights invariants

- Collector Type answers: **what clearly defines the current shelf?**
- Pipeline: **Signals → Eligibility → Strength → soft-capped scale → Winner**.
- Signal presence is not identity.
- **Wanderer** is the intentional fallback when no specialized type qualifies.
- Journey and Reveal History do **not** score Collector Type.
- Identity is **reveal-based**, not a live scoreboard.
- Snapshot invalidation (`needsReveal`) decides **when** to reveal; the
  Resolver decides **what** the identity is.
- **Complete** and **Master Complete** are distinct tiers.
- **Regular Progress** is Regular-weighted series progress (Secrets do not
  reduce a Regular-complete series below 100%).
- **Master Completion** denominator is Secret-bearing series only.
- My Collection is a **flat Series browser** per progress bucket; hidden IP
  grouping must not affect sorting. IP may remain a domain signal without being
  a presentation grouping.

Full eligibility contract, reveal lifecycle, and scoring notes:
[`docs/COLLECTION_ARCHITECTURE_NOTES.md`](docs/COLLECTION_ARCHITECTURE_NOTES.md).

---

## Verification

For relevant changes:

```text
flutter analyze
flutter test <targeted tests>
```

Feature suites already documented in [`docs/TESTING.md`](docs/TESTING.md).
Examples:

```text
flutter test test/widget_test.dart
flutter test test/catalog_search_service_test.dart
flutter test test/collector_type_behavior_contract_test.dart
flutter test test/collector_type_resolver_test.dart
flutter test test/collector_type_needs_reveal_test.dart
flutter test test/collector_type_reveal_lifecycle_contract_test.dart
```

Release / broad confidence (when appropriate):

```text
flutter analyze
flutter test
```

Before handing off, report:

- commands run
- pass/fail totals
- files changed
- remaining risks
- anything not verified

---

## Git and PR conventions

Commit style (existing repo):

```text
feat(collection): ...
fix(insights): ...
test(collection): ...
chore: ...
docs: ...
```

PR descriptions must follow [`.github/PULL_REQUEST_TEMPLATE.md`](.github/PULL_REQUEST_TEMPLATE.md)
and lead with **product outcome**, not implementation laundry lists.

Do **not** auto-merge unless explicitly requested.
Do **not** commit or push unless the user asks.
Do **not** update `git config`.

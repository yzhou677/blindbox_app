# Collection Insights — scoped agent instructions

Applies when editing `lib/features/collection/insights/` or Collector Type /
Shelf Progress / reveal behavior that depends on it.

Parent: repository root [`AGENTS.md`](../../../../AGENTS.md).
Product semantics:
[`PDR-001 Collector Type`](../../../../docs/decisions/product/PDR-001-collector-type-semantics.md),
[`PDR-002 Completion`](../../../../docs/decisions/product/PDR-002-completion-semantics.md).
Contract detail: [`docs/COLLECTION_ARCHITECTURE_NOTES.md`](../../../../docs/COLLECTION_ARCHITECTURE_NOTES.md).

---

## Canonical completion (do not fork)

Use only:

- `resolveSeriesCompletion` — per-series Regular / Secret slots and progress
- `aggregateShelfCompletion` — shelf Regular Progress % and Master tier counts

These live in
`lib/features/collection/domain/series_completion_resolution.dart`.

- **Regular Progress** (UI): mean of per-series `progressRatio` across all
  shelf series.
- **Master Completion**: `masterCompleteSeriesCount / masterEligibleSeriesCount`
  (Secret-bearing series only). Do not show Master row before the first Master
  Complete series (progressive disclosure).

Do not invent parallel completion percentages in Insights widgets.

---

## Collector Type versioning

- Policy version: `kCollectorTypeResolverVersion` on
  `CollectorTypeRevealRecord` — bump when the same shelf could resolve to a
  different identity or explanation.
- Stats schema: `kCollectorTypeStatsVersion` — bump when reveal-frozen stats
  display math or required keys change.
- Old reveals must trigger `needsReveal` via version / signature invalidation —
  **never** silently rewrite persisted identity on launch.

---

## Reveal lifecycle invariants

- Hero shows **last revealed** identity (persisted).
- Live candidate resolves continuously; it is **not** auto-persisted.
- `needsReveal` answers **when** (signature drift, resolver version, outdated
  stats schema). Signature is not identity inference.
- A reveal while `needsReveal` **always** persists the current resolver
  candidate.
- `shouldEvolve` (margin / cooldown / sameSignature) applies only to repeated
  reveals on an **unchanged** shelf.
- Journey is live exploration metrics — not frozen into Identity / RevealRecord.
- Journey / Reveal History must **not** feed scoring.

Pipeline reminder: Signals → Eligibility → Strength → soft-capped scale →
Winner. Presence alone never assigns personality. Wanderer is fallback only.

Structural exclusions: Hunter ⊥ Lucky One; Loyalist ⊥ Curator.

---

## Persistence compatibility

- Collection shelf codec and reveal prefs are user data — treat as durable.
- Prefer derive-live-stats / version gates over rewriting old prefs in place.
- No mass codec migrations unless the task explicitly requires them.

---

## Required regression when changing identity math or reveal gates

At minimum (see also [`docs/TESTING.md`](../../../../docs/TESTING.md)):

```text
flutter analyze
flutter test test/collector_type_behavior_contract_test.dart
flutter test test/collector_type_resolver_test.dart
flutter test test/collector_type_needs_reveal_test.dart
flutter test test/collector_type_reveal_lifecycle_contract_test.dart
```

When editing eligibility broadly, also run:

```text
flutter test test/collector_type_6_0_smoke_matrix_test.dart
flutter test test/collector_type_signal_ownership_test.dart
```

When editing Shelf Progress presentation only:

```text
flutter test test/collector_type_shelf_progress_card_test.dart
```

Report commands, pass/fail, risks, and what was not verified.

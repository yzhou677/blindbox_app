# Collection emotional intelligence (Phase 4)

Derived shelf interpretation over `CollectionSnapshot` — calm, editorial, offline-first.

## Boundaries

| Layer | Role |
|-------|------|
| `CollectionSnapshot` | Source of truth (shelf rows + figure states) |
| `ShelfEmotionalProfile` | Derived shelf mood and themes |
| `CollectionProgressVoice` | Per-series headline/subline (unchanged) |

Shelf interpretation is **not** a collector profile, recommendation engine, or gamification system.
Per [`PDR-001`](decisions/product/PDR-001-collector-type-semantics.md) and
[`PDR-003`](decisions/product/PDR-003-dreamer-semantics.md), future collecting
intent may inform Dreamer, but shelf editorial interprets only the current
owned collection.

## Signals

- **Taxonomy coverage** — `taxonomyBrandId` / `taxonomyIpId` on series rows
- **Completion** — `resolveSeriesCompletion` / `aggregateShelfCompletion` (Regular-weighted `progressRatio`; Near Complete = `isNearComplete`)
- **Secrets** — `ShelfFigure.isSecret` × `FigureCollectionState.owned`
- **Relationships** — co-occurring IPs on shelf (max 2 insights)

Wishlist state is intentionally not a shelf editorial signal.

## Memory foundation (`collection_memory_v1`)

Optional SharedPreferences milestones (written on `CollectionNotifier` commit):

- `firstSecretOwnedAtMs` — set once
- `lastCompletedSeriesId` / `lastCompletedAtMs` — updated when a series becomes complete

No timeline UI in Phase 4.

## UI

- Summary card: interpretation line + optional memory whisper
- Section header: optional subtitle from relationships
- Series cards: atmosphere borders (near-complete, missing secret, complete)
- IP group labels when 2+ series share a universe

## Non-goals

Scores, streaks, social feeds, predictive AI, investment framing, codec changes.

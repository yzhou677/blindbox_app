# Collectible relationship surfaces (Phase 5)

Calm, taxonomy-grounded adjacency between catalog worlds, the user shelf, and market sightings. Not a recommendation engine.

## Principles

- **Derived & deterministic** — rules over shared IP, brand, shelf co-occurrence, and catalog lineup order
- **Explainable** — one short editorial line per focal view
- **Offline-first** — uses `CollectionSnapshot` + optional `CatalogSeedBundle`; no ML or opaque scores
- **Universe boundaries** — relationships never own canonical identity; they reference taxonomy ids and shelf rows

## Location

`lib/features/collectible_relationship/`

| Piece | Role |
|-------|------|
| `domain/collectible_relationship_hint.dart` | Single hint + focal keys |
| `application/collectible_relationship_index.dart` | Shelf + catalog adjacency index |
| `application/collectible_affinity_resolver.dart` | Picks at most one hint per focal |
| `application/collectible_shelf_relationship_bridge.dart` | Shelf pairwise insights (Phase 4 shape) |
| `application/shelf_harmony_interpreter.dart` | Optional shelf-level harmony line |
| `presentation/collectible_relationship_copy.dart` | Editorial strings |
| `application/collectible_relationship_providers.dart` | Riverpod wiring |
| `widgets/collectible_relationship_line.dart` | Shared UI line |

Phase 4 shelf analysis (`analyzeShelfRelationships`) delegates to the bridge to avoid duplicate rules.

## Surfaces

- **Collection summary** — `shelfRelationshipWhisperProvider` when no memory whisper
- **Series figures sheet** — hint under chrome
- **Catalog series preview** — hint before lineup
- **Market browse card / sheet / detail** — one line beside mood/signals

## Non-goals

- “Recommended for you”, carousels, engagement scoring
- Vector search, embeddings, social ranking
- Persistent recommendation profiles

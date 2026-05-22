# Personal collectible memory (Phase 7)

Calm remembrance of the collecting journey — not a social feed or achievement system.

## Principles

- **Offline-first** — small `SharedPreferences` payload (`collection_memory_v2`)
- **Derived** — moments from snapshot + milestones, not cloud timelines
- **One whisper** — collection summary shows a single thoughtful line
- **No engagement loops** — no streaks, push campaigns, or “on this day” spam

## Model

| Type | Role |
|------|------|
| `CollectionMemoryMoment` | Displayable memory kinds (completion, secrets, universes, evolution, growth) |
| `ShelfEra` | Mood / universe / secret snapshot at a point in time |
| `CollectionEvolution` | Interpreted shift between prior and current shelf character |
| `CollectionMemoryData` | Persisted milestones + IP depth + era baselines |

## Persistence (`CollectionMemoryStore`)

Records on each shelf commit via `CollectionNotifier`:

- First secret owned (once)
- Last completed series + timestamp
- First series added timestamp
- Per-IP series depth (series added over time)
- `lastRecordedEra` + `priorEraForEvolution` when shelf character changes

## Surfaces

- **Collection summary** — `shelfMemoryWhisperProvider` → `resolveCollectionMemoryWhisper`
- **Series figures sheet** — `collectionMemoryReflectionForSeriesProvider` when complete / recently completed

## Editorial

[`CollectionMemoryEditorial`](../lib/features/collection/presentation/collection_memory_editorial.dart) — all memory copy; [`ShelfEditorialVoice.memoryWhisper`](../lib/features/collection/presentation/shelf_editorial_voice.dart) delegates here.

## Non-goals

Social timelines, streaks, collector scores, cloud memory, daily resurfacing notifications.

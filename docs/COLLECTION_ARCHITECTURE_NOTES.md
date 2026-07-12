# Collection Architecture Notes

Last updated: 2026-07

This document records intentional Collection architecture decisions, tradeoffs, and future scaling considerations.

The purpose is to preserve design intent and prevent future contributors from accidentally "fixing" behavior that is currently working as designed.

---

## Current Status

Collection is considered:

**Stable / Maintenance Mode**

Core functionality is complete (see also [`ARCHITECTURE_NOTES.md`](ARCHITECTURE_NOTES.md) § Collection Feature Status for the current feature matrix and low-priority deferrals):

* Collection shelf
* Ownership tracking
* Wishlist tracking
* Custom series
* Custom figure support (create, edit, **add figure** from edit sheet)
* Brand filter
* IP filter
* Shelf browse (search, sort, collapsible buckets)
* Collection insights
* Collector identity
* Journey system
* Canonicalized custom taxonomy
* Edit custom series
* Input hardening

Future work should prioritize:

* Bug fixes
* UX polish
* Catalog expansion
* Performance profiling

Avoid major architectural rewrites unless real-world usage demonstrates a need.

---

## Intentional Architecture Decisions

### Single Snapshot Persistence

Collection data is stored as a single serialized snapshot in SharedPreferences.

Reasons:

* Simplicity
* Reliability
* Offline-first behavior
* Small expected data volume

Current architecture is considered appropriate for:

* Typical collectors
* Hundreds of figures
* Low-frequency edits

Future scaling should be evaluated using real-world collection sizes rather than theoretical limits.

---

### Collector Identity Is A Snapshot

Collector identity is intentionally not recomputed continuously.

Behavior:

* User explicitly reveals identity
* Identity is cached
* Metadata edits do not automatically overwrite the revealed identity

Reason:

The feature is intended to feel like a collectible personality reveal, not a constantly fluctuating dashboard.

Evolution is surfaced separately through Evolution Hints.

See **Collector Type Architecture** below for the full Live vs Snapshot contract.

---

### Journey History Is Historical

Collector Journey metrics are **historical by design**. The Journey card is
recomputed live from memory, but values represent the collector’s path — not
current shelf composition.

| Metric | Meaning |
| ------ | ------- |
| **Started** | First series added (`firstSeriesAddedAt`) |
| **Explored IP universes** | Unique IPs ever explored (`ipSeriesDepth.length`) — **append-only**; does **not** decrease when series are removed |
| **Identity** (Collector Type) | Snapshot at last reveal — separate from Journey |

Do **not** “fix” Explored to equal unique IPs currently on the shelf.

Journey **taxonomy depth** (`ipSeriesDepth`) records what happened when series
were added. Editing metadata later does not rewrite those events.

Separately: the **Collector Journey UI** on Insights is intentionally **LIVE**
(rebuilt from current memory + snapshot) and is **not** part of the Collector
Type reveal snapshot. Do not freeze Journey into Identity or RevealRecord.

See **Collector Type Architecture** below.

Example:

Series added under:

Baby Three

may later be edited to:

THE MONSTERS

Current shelf:

* Shows THE MONSTERS

Historical journey depth:

* May still reference Baby Three exploration

This is intentional.

Journey depth reflects collection history, not current taxonomy state.

---

## Collector Type Architecture

Canonical code: `lib/features/collection/insights/`.

This section exists so future maintainers do **not** “fix” Journey into a
reveal snapshot or re-derive Because copy from archetype switches.

### Live state vs reveal snapshot

| Kind | Object | Behavior |
| ---- | ------ | -------- |
| **Live (Hero)** | `CollectorTypeIdentity` | Frozen until the user reveals again. Drives Hero, ceremony, At a Glance / Shelf Progress / Brand Distribution. |
| **Live (Journey)** | Collector Journey summary | Always current. **Not** archived with reveal. Updates as the shelf evolves. |
| **Historical replay** | `CollectorTypeRevealRecord` | Append-only resolve snapshot for Timeline / Personality Memory. No 1.0 UI yet. |

**Do not:**

* Make Journey a reveal-frozen field
* Recompute Collector Type continuously on every shelf edit
* Drive Because text from `switch (archetype)` in widgets

### Resolve pipeline

```
Shelf Snapshot
      ↓
Resolver (`resolveCollectorType`)
      ↓
CollectorTypeResolution  (scoreboard + reasonKey + confidence)
      ↓
shouldEvolve (evolution gate)
      ↓
CollectorTypeIdentity    (what the Hero shows)
      +
CollectorTypeRevealRecord (what History can replay)
      ↓
CollectorTypeCopy.becauseLineFor / becauseLineForRecord
      ↓
Hero / Reveal ceremony / (future) Timeline / Personality Memory
```

### Historical replay

```
RevealRecord (archetype, reasonKey, score, confidence, signature, resolverVersion, …)
      ↓
Timeline / Personality Memory
```

Replay answers “why were you The Loyalist then?” from the stored record — **never**
by re-running today’s Resolver over an old shelf.

### Product rules (intentional)

1. **Journey is intentionally LIVE as a card, HISTORICAL as metrics.** Recomputed from memory each build, but Explored / Started describe the collector’s path over time (append-only IP depth) — not current shelf composition. Do not freeze Journey into the reveal archive, and do not shrink Explored on series remove.
2. **Identity is intentionally SNAPSHOTTED.** Explicit reveal; Evolution Hints nudge re-reveal; `shouldEvolve` gates type changes (Still keeps title, refreshes stats/signature/reason).
3. **UI never switches on archetype for causal copy.** Title/accent/flavor may read archetype catalog metadata; **Because** must not.
4. **`reasonKey` is the only explanation source** for Because. Map via `CollectorTypeCopy` only (`becauseLineFor` / `becauseLineForRecord`).
5. **`resolverVersion` protects historical semantics.** Stamped on every `CollectorTypeRevealRecord`. Policy and bump rules live on `kCollectorTypeResolverVersion` — schema/policy version, not app version. Bump only when the same shelf could resolve to a different identity or explanation.

Related: evolution constants in `collector_type_evolution_gate.dart`; scoring thresholds in `collector_type_resolver.dart`; prefs key `collection_memory_v3`.

---

### ipSeriesDepth Is Add-Time History

`ipSeriesDepth`

tracks the IP associated with a series when it was first introduced into the collection.

It is **append-only**: series removal does not decrement counts or drop IP keys.
**Explored IP universes** = `ipSeriesDepth.length` (unique IPs ever explored).

It is not currently migrated when a user edits taxonomy metadata.

Reason:

Depth measures exploration history rather than current categorization / shelf
composition.

Future migration support may be added if user feedback indicates confusion.

---

### Custom Metadata Ownership

Custom series belong to the user.

Users are allowed to:

* Edit series name
* Edit brand
* Edit IP
* Edit notes
* Change cover image

The application should not attempt to second-guess or override user intent.

Catalog data remains authoritative.

Custom data remains user-controlled.

---

### Hierarchical shelf sorting

Collection sorting is hierarchical.

The Collection page is organized as:

```
Collection
    ↓
Bucket (In Progress / Completed)
        ↓
IP
            ↓
Series
```

All sort modes preserve this hierarchy: determine the order of **IP groups** first, then the order of **series within each IP**. The feed builder renders that order; it does not re-rank.

This is a deliberate product decision. A global flat series ranking would fight the grouped shelf UI and can make on-screen order disagree with the selected sort.

#### Collection sorting reference

| Sort | IP aggregate | Series aggregate | Tie-breakers |
| ---- | ------------ | ---------------- | ------------ |
| Recently Added | Most recent addition (encounter order in bucket) | Recently added (shelf order within IP) | N/A (no comparator) |
| Alphabetical (A–Z) | IP label | Series name | IP group key → shelf `id` |
| Figure Count | `Σ figureCount` per IP (desc) | `figureCount` (desc) | IP label → IP key; series name → shelf `id` |
| Completion | `Σ owned ÷ Σ slots` per IP (desc) — **weighted**, not average of series % | `owned ÷ slots` per series (desc) | IP label → IP key; series name → shelf `id` |

**Product rule:** Collection sorting is hierarchical. New sort modes (Market Value, Estimated Value, Release Date, Last Updated, Rarity, etc.) should define an **IP aggregate** and a **series aggregate** — not introduce flat global ranking — unless Product explicitly chooses a flat ranked list.

Implementation: [`sortShelfSeriesForDisplay`](../lib/features/collection/presentation/collection_shelf_browse.dart) in `collection_shelf_browse.dart`.

**The Collection page is a hierarchical browser, not a flat ranked list.**

---

## Known Tradeoffs

### Journey vs Current Shelf

Possible:

Current Shelf ≠ Historical Journey

This is expected.

---

### Collector Identity vs Live Shelf

Possible:

Live Shelf ≠ Cached Identity

This is expected.

Revealing again updates identity.

---

### Snapshot Size Growth

Current storage is optimized for simplicity rather than extreme scale.

Monitor:

* cold start time
* snapshot size
* save latency

before introducing:

* local databases
* split persistence
* paging
* isolate serialization

---

## Future Evaluation Triggers

Consider architecture review if any of the following become common:

* > 200 series
* > 1000 figures
* snapshot size > 1 MB
* noticeable startup delay
* noticeable save delay
* user requests journey history migration
* user confusion around collector identity caching

Until then:

**Prefer simplicity over infrastructure complexity.**

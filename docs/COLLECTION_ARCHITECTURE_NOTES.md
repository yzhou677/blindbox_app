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

### ADR: Snapshot invalidation is not identity inference

1. Signature exists only to determine whether a reveal is needed.
2. Resolver is the sole authority for interpreting the current shelf.
3. Identity stability applies only when no new reveal is required.
4. A reveal triggered by `needsReveal` must always persist the resolver's current interpretation.

Do not reintroduce `sameSignature` (or any other evolution gate) into the
`needsReveal` → Reveal path. Evolution answers *how* to present change on an
unchanged shelf only.

### Live state vs reveal snapshot

| Kind | Object | Behavior |
| ---- | ------ | -------- |
| **Live (Hero)** | `CollectorTypeIdentity` | Frozen until the user reveals again. Drives Hero, ceremony, At a Glance / Shelf Progress / Brand Distribution. |
| **Live (Journey)** | Collector Journey summary | Always current. **Not** archived with reveal. Updates as the shelf evolves. |
| **Historical replay** | `CollectorTypeRevealRecord` | Append-only resolve snapshot for Timeline / Personality Memory. No 1.0 UI yet. |

### Collection Summary vs Insights “At a glance”

Both surfaces show counts, but they answer different questions. Labels must name
what is counted — never bare “Figures”, “Series”, or “Wishlist”.

| Surface | Intent | Metrics |
| ------- | ------ | ------- |
| **Collection Summary** (Collection tab) | Shelf activity — what you own and what you are aiming for | Owned Figures · Wishlisted Figures · Completed Series · Master Complete |
| **Insights — At a glance** | Achievement snapshot at last reveal — collector identity | Owned Figures · Completed Series · Master Complete · Secrets Collected |

Same completion tiers (`countShelfCompletionTiers` / `resolveSeriesCompletion`);
At a glance omits wishlist and uses secrets collected instead. Values in At a
glance come from `CollectorTypeStats` frozen at reveal.

### Collector Journey as a diary

Journey highlights memorable collector moments — not another stats panel.
**Open today’s collection diary** — not a dashboard of every signal.

| Beat | Source | Notes |
| ---- | ------ | ----- |
| Started | `firstSeriesAddedAt` | Stable slot |
| Explored | `ipSeriesDepth` | Stable slot |
| Latest Memory | Existing memory only | Omit when none |

**Latest Memory priority** (no new persistence):

1. Master Complete — latest completed series is still Master Complete on shelf
2. Completed Series — `lastCompletedSeriesId` + `lastCompletedAtMs`
3. First Secret — `firstSecretOwnedAtMs`

**Diary principle (permanent):** surface at most **one or two** memorable
moments at a time. Journey can grow (First Master Complete, First New Universe,
Type Evolution) but must stay curated — never a six-row stats dump.

### Shelf Progress progressive disclosure

Shelf Progress answers **collection progression** (Regular Complete → Master Complete).

| Stage | Condition | Rows |
| ----- | --------- | ---- |
| 1 | Always | **Regular Completion** — mean of canonical `progressRatio` across **all** shelf series |
| 2 | `masterCompleteSeriesCount > 0` | **👑 Master Completion** — Master Complete / **Secret-bearing** series only |

**Formulas (canonical):**

```text
Regular Completion:
  mean over all shelf series of resolveSeriesCompletion(...).progressRatio
  (Secrets do not reduce a Regular-complete series below 100%)

Master Completion:
  masterCompleteSeriesCount / masterEligibleSeriesCount
  where masterEligibleSeriesCount = series with secretSlotCount > 0
  (no-Secret series are excluded from the denominator)

Near Complete:
  !isCompleted && progressRatio >= 0.85
  (same definition for Completion sort, atmosphere, and interpretShelf)
```

If `masterEligibleSeriesCount == 0`, do not show the Master Completion row.
Do **not** show Master Completion at `0%` before the first Master Complete —
progressive disclosure until `masterCompleteSeriesCount > 0`.

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
6. **Identity scores the current shelf only (2.0+).** Resolver must not read Journey memory (`ipSeriesDepth`, `firstSeriesAddedAt`, …) or Reveal History. Prior Identity is allowed only inside `shouldEvolve`. Catalog metadata may join shelf items (Trend Chaser freshness). Scoring signal table lives as a comment on `collector_type_resolver.dart` and below.
7. **Identity requires defining behavior (5.0).** Signals are evidence, not identity. Eligibility uses ratio / share / density / composition before strength and soft-capped scale. Presence alone does not assign personality.
8. **Reveal lifecycle (5.2):** Hero shows **last revealed** identity (persisted). Live shelf continuously resolves a **candidate** (`collectorTypeLiveResolutionProvider`) that is never auto-persisted. `needsReveal` is true when **signature** drifts or **resolverVersion** changed — signature answers **When** only. A reveal while `needsReveal` always persists the resolver candidate (no `sameSignature` Still override). `shouldEvolve` (margin / cooldown / sameSignature) applies only to repeated reveals on an unchanged shelf. Persist only on explicit Reveal.
9. **Evolution:** On unchanged-shelf reveals, `shouldEvolve` answers whether the challenger earned the title. Confidence remains on `CollectorTypeResolution` for analytics only. Ceremony reflects whether the persisted archetype changed.

Related: evolution constants in `collector_type_evolution_gate.dart`; scoring thresholds in `collector_type_resolver.dart`; prefs key `collection_memory_v3`. Canonical registry: `CollectorTypeArchetypes` (**10 types**).

### Collector Types (resolver 5.0) — 10 archetypes

Each type is a collecting **verb** on the current shelf. Pipeline: Signals → Behavior eligibility → Strength → Soft-capped scale. Winner = highest scoreboard score (ties use `tieBreakPriority`).

| Type | Verb | Defining behavior | Eligibility then strength |
| ---- | ---- | ----------------- | ------------------------- |
| **Completionist** | Finish | Finishing defines the shelf | `finishRatio` / `nearRatio` ≥ 0.4 + avg / near gates; soft-capped complete count |
| **Hunter** | Chase | Hunting rarity defines shelf | Secret density ≥ 0.35 (+ ≥2 secrets or secrets theme); soft-capped secret count |
| **Lucky One** | Fortune | Compact high hit-rate fortune | Secret ratio + small shelf; **not** when Hunter eligible |
| **Loyalist** | Commit | One universe dominates | Dominant brand/IP share ≥ 0.6 |
| **Curator** | Curate | Multi-world gallery | Spread ≥ 2 brands/IPs **and** not Loyalist-dominant; soft-capped spreads |
| **Wanderer** | Explore | Curious unfinished spread / empty fallback | Brand spread + low completion; empty shelf fallback |
| **Minimalist** | Refine | Small carefully finished shelf | Few series + few owned + high completion |
| **Worldbuilder** | Create | Authorship of custom worlds | ≥1 custom **and** `customRatio ≥ 0.3`; notes/covers/photos deepen custom rows only |
| **Dreamer** | Imagine | Wishlist-forward collecting | `wishlistRatio ≥ 0.45` + wishlist count |
| **Trend Chaser** | Chase now | Chasing fresh drops defines shelf | `recentRatio ≥ 0.4` and ≥2 recent catalog series; soft-capped recent count |

**Not Identity signals:** Journey `ipSeriesDepth` / `firstSeriesAddedAt`; Reveal History / prior Identity (except `shouldEvolve`).

**Legacy id migration (persist load):** `archivist` → Worldbuilder; `daydreamCollector` → Dreamer. Stylist removed (no successor mapping).

**Tie-break order (high → low):** Completionist → Hunter → Loyalist → Curator → Worldbuilder → Minimalist → Trend Chaser → Dreamer → Lucky One → Wanderer.

**Tie-break role (5.3):** Insurance, not the primary identity mechanism. Behavior
eligibility usually separates the scoreboard. Structural exclusions never both
score: Hunter ⊥ Lucky One; Loyalist ⊥ Curator. Prefer keeping the table short
and product-ordered (authorship / long-horizon verbs above shelf-shape verbs
such as Minimalist).

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
* Attach local figure photos

**Product boundary:** series notes, custom covers, and local figure photos are
available on **custom series only**. Official catalog series tracked onto the
shelf do not expose those editors — do not document or test catalog rows as if
they carried user notes/covers.

The application should not attempt to second-guess or override user intent.

Catalog data remains authoritative.

Custom data remains user-controlled.

---

### Series figures sheet progress (Regular ≠ Secret)

**Product decision:** The Series figures sheet presents collection progress from
the collector’s perspective, not the database’s.

Regular Figures and Secret Figures are **two different collection goals**. Do
**not** summarize them into a single `X of Y Figures` value.

The UI should consistently answer **“What am I still collecting?”** instead of
exposing how many figure rows exist in the database.

| Surface | Behavior |
| ------- | -------- |
| Sheet header | `Regular Figures N of M Collected`; show `Secret Figures A of B Collected` **only if** `ownedSecretCount > 0` (never `0 of N` in the header) |
| Section headers | Same Regular / Secret split; progress `(owned of total)` — including `0 of N` when secrets exist but none owned |
| No secrets | Omit Secret lines and Secret section entirely |
| Complete / Master Complete | Unchanged — still from `resolveSeriesCompletion` |

Presentation only — do not change completion calculation or Collector Type logic. Header Secret summary is ownership-gated; the Secret figures section body is not.

---

### Flat shelf sorting

Collection sorting operates on a **flat** series list per bucket.

The Collection page is organized as:

```
Collection
    ↓
Bucket (In Progress / Completed)
        ↓
Flat List<ShelfSeries>
        ↓
One global comparator
        ↓
Render (series rail)
```

Sort modes do **not** group by IP. IP filters remain available as a filter facet only — they do not affect display order after the list is built.

#### Collection sorting reference

| Sort | Series comparator | Tie-breakers |
| ---- | ----------------- | ------------ |
| Recently Added | Preserve shelf / bucket encounter order | N/A |
| Alphabetical (A–Z) | Series name (case-insensitive) | shelf `id` |
| Figure Count | `figureCount` (desc) | series name → shelf `id` |
| Completion | **Tier first:** Master Complete → Complete → Near Complete (`!isCompleted && progressRatio ≥ 0.85`) → In Progress; then progress ratio (desc) | series name → shelf `id` |

**Product rule:** Collection sorting is flat. New sort modes should define a **series-level** comparator — not reintroduce hidden IP aggregates.

Implementation: [`sortShelfSeriesForDisplay`](../lib/features/collection/presentation/collection_shelf_browse.dart) in `collection_shelf_browse.dart`.

**The Collection page is a flat series browser within each progress bucket.**

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

---

## Collector Type 5.3

Status: Active policy version. Scoring remains 5.0 behavior inference;
reveal lifecycle remains 5.2; tie-break order is 5.3.

See **ADR: Snapshot invalidation is not identity inference** above.

**Reveal lifecycle (5.2):** Signature / `needsReveal` answer **When** only. A
reveal while `needsReveal` always persists the resolver candidate.
`shouldEvolve` (margin / cooldown / sameSignature) applies only to repeated
reveals on an unchanged shelf.

**Tie-break (5.3):** Worldbuilder ranks above Minimalist when scores tie —
authorship over compact shelf size. Tie-break is insurance; structural pairs
Hunter/Lucky and Loyalist/Curator never both score.

**Evolution (unchanged-shelf):** `shouldEvolve` compares candidate vs previous
identity via scoreboard margin (and cooldown-scaled margin). Resolution.confidence
is analytics-only.

**Behavior inference (5.0):** Identity answers “does this behavior define how I
collect today?” Eligibility (ratio / share / density / composition) precedes
strength and soft-capped scale.

**Worldbuilder (4.0):** authorship-first — custom series ratio is the gate and
primary signal. Notes/covers/photos deepen score only on custom series.

Do not adjust scoring without product evidence from real collectors. Prefer
eligibility / composition fixes over arbitrary weight nerfs.

Future work should build on this architecture rather than expand the resolver.

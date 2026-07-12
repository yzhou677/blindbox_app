# Architecture Decision Records (ADR)

Shelfy uses ADRs to preserve **why** we made important product and architecture choices — decisions we expect to outlive any single release or refactor.

An ADR is not a substitute for code comments, API docs, or feature guides. It is a durable record of intentional reasoning.

---

## Philosophy

ADRs capture:

> Why we intentionally made an architectural or product decision.

They are **not**:

- Implementation documentation (how the code works today)
- API or schema reference
- Feature walkthroughs or user-facing copy
- Living documents that track every tweak

They exist so future contributors — including future us — do not “fix” or “simplify” something that was deliberately chosen.

---

## When to create an ADR

Create an ADR when a decision **generally satisfies all** of the following:

1. **Long-lived** — expected to survive multiple releases
2. **Product or architecture** — shapes how the app is structured or behaves at a boundary
3. **Easy to misread** — someone might otherwise optimize or refactor it incorrectly without context
4. **Reasoning over implementation** — the *why* matters more than the current *how*

If something is expected to change frequently (UI polish, sort labels, chip layout), keep it in normal feature docs or code-adjacent notes instead.

---

## When not to create an ADR

Do **not** use an ADR for:

- Bug fixes or one-off tradeoffs
- Temporary experiments or MVPs likely to be replaced
- Duplicating content that already lives in another doc (link instead, when an ADR is eventually extracted)
- Decisions that are obvious from code with no meaningful product debate

When in doubt, wait. ADRs should emerge when a decision has **proven** stable, not at first sketch.

---

## Template

Each ADR is a single markdown file. Keep it short.

```text
# ADR-NNN: Title

## Status
Proposed | Accepted | Superseded by ADR-XXX

## Context
What problem or constraint led to this decision?

## Decision
What we chose — stated clearly.

## Consequences
Tradeoffs, what we gain, what we give up, what we will not do.

## Implementation Links
Pointers to code, tests, or existing docs (not a full spec).
```

---

## Numbering

Use sequential IDs:

```text
ADR-001-short-slug.md
ADR-002-short-slug.md
ADR-003-short-slug.md
```

- One decision per ADR
- Slug is lowercase, hyphen-separated
- Do not reserve category ranges yet; add structure only when the set grows

Superseded ADRs stay in the repo with status updated — do not reuse numbers.

---

## Relationship to existing documentation

These remain the **current source of truth** until a topic is explicitly extracted into an ADR:

- [`RECOMMENDATION_SEMANTICS.md`](../RECOMMENDATION_SEMANTICS.md) — **Accepted ADR** for For You taste semantics (tracked-only taste, stability, wishlist/owned exclusions). **Read before any recommendation change.**
- [`COLLECTION_ARCHITECTURE_NOTES.md`](../COLLECTION_ARCHITECTURE_NOTES.md)
- [`.cursor/ARCHITECTURE.md`](../../.cursor/ARCHITECTURE.md)
- Market, catalog, and feature docs under `docs/`

Do not migrate or duplicate them as part of introducing this folder. When a decision is mature and long-lived, add a new ADR that **summarizes the decision** and links back to detailed notes — then optionally slim the original doc over time in a separate change.

---

## Potential future ADRs

Examples only — **not created yet**:

| Topic | Why it might become an ADR |
| ----- | -------------------------- |
| Recommendation taste semantics | Tracked-only taste; stable For You; wishlist/owned out of pipeline — [`RECOMMENDATION_SEMANTICS.md`](../RECOMMENDATION_SEMANTICS.md) (**Accepted ADR**) |
| Collection Hierarchy | Progress buckets (In Progress / Completed); flat series rail; local shelf vs catalog |
| Collection Sorting | Flat series list per bucket; one global comparator; no hidden IP ordering |
| Series figures progress | Regular and Secret shown separately; header Secret line only if owned ≥ 1 — never combined “X of Y Figures” |
| Catalog Identity | `imageKey`, Firestore catalog universe, persisted cache offline baseline |
| Market Intelligence | Market universe separate from shelf and catalog |
| Offline-first / Local-first | Collection local persistence; progressive hydration |

New ADRs should be added when the team agrees a decision is stable enough to canonize — not by bulk migration.

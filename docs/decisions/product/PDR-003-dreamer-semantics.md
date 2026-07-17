# PDR-003: Dreamer Semantics

## Status

Accepted.

## Product Principle

Dreamer represents a collector whose shelf identity is driven by future
collecting intent.

Dreamer is not simply "a collector with many wishlist items." It describes a
collector whose clearest current signal is what they are planning, imagining, or
trying to start next.

Collector identity may incorporate future collecting intent. Shelf editorial
describes only the current owned collection. At a Glance reports objective
owned-collection facts.

## Why

Wishlist used to mean wishlisted figures inside owned Collection series. With
Series Wishlist, Shelfy now records two different future-intent signals:

- **Wishlist Series**: "I want to start collecting this series."
- **Wishlist Figures**: "I still want this specific figure."

Both signals can matter to Dreamer, but they do not mean the same thing. A
wishlisted series points to a collecting direction. A wishlisted figure points
to a specific desired object inside an existing collection context.

Dreamer should compare future collecting intent against collections that have
actually started. A Series is **Started** only when it contains at least one
owned Figure. A Series in My Collection with zero owned Figures is tracked, but
it should not count as started collecting progress for Dreamer. It may still
count as future collecting intent because the collector has saved the direction
without beginning ownership.

Because those signals have different product meanings, Dreamer changes should
stay deliberate and narrow. The archetype should represent future-directed
collecting, not an accidental count of saved items.

## User Impact

Collectors should understand Dreamer as a valid identity, not a failure to own
enough figures. Dreamer should feel like a recognition of planning, curiosity,
and future collecting direction.

The Dreamer explanation may refer to future collecting intent when Dreamer wins.
For example:

> Because your future collecting plans are the strongest signal in this reveal.

Future copy may evolve as Wishlist and planning language becomes part of the
product voice, but it should continue to explain future collecting intent calmly
and specifically.

## Non-goals

This PDR does not define:

- resolver thresholds
- scoring formulas
- Series-vs-Figure wishlist weights
- migration behavior
- UI layout
- persistence fields

It also does not require all future-intent surfaces to use the same display
language. Dreamer can use future intent without making Shelf Editorial or At a
Glance reflect wishlist state.

## Open Product Questions

- What exactly should Dreamer measure: desire volume, future direction, or
  planning intensity?
- How should Wishlist Series and Wishlist Figures differ in semantic weight?
- How should Dreamer remain distinct from Curator, Hunter, Completionist, and
  Trend Chaser?
- When should future intent be strong enough to define identity rather than
  remain secondary context?

## Related Decisions

- [`PDR-001: Collector Type Semantics`](PDR-001-collector-type-semantics.md)
- [`PDR-002: Completion Semantics`](PDR-002-completion-semantics.md)
- [`docs/COLLECTION_ARCHITECTURE_NOTES.md`](../../COLLECTION_ARCHITECTURE_NOTES.md)

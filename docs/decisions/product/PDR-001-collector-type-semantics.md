# PDR-001: Collector Type Semantics

## Status

Accepted.

## Product Principle

Collector Type answers:

> What most clearly defines this shelf today?

Collector Type is a reveal of shelf identity, not a live score, rank, dashboard,
or behavioral judgment. It should help a collector recognize the character of
their collection without turning the shelf into a contest.

## Why

Shelfy is a collector app built around trust, identity, and personal attachment.
A collector's shelf can change often as they add, remove, wishlist, or complete
figures. If identity changed automatically with every edit, the feature would
feel noisy and arbitrary.

The reveal model makes Collector Type feel intentional. The collector sees a
moment of interpretation, not a constantly flickering label.

Journey context can explain how the collection has grown, but journey history is
not the identity itself. Collector Type should describe the current shelf's
clearest defining pattern, not invent a life story or reward old behavior.

Wanderer is an intentional fallback. It is not a failure state. It protects the
collector from being over-classified when no specialized identity honestly fits.

## User Impact

Collectors get a stable, emotionally legible identity that respects their shelf.
They can evolve over time without feeling punished for experimenting, and they
are not asked to treat every figure toggle as a personality update.

The copy should stay factual and shelf-grounded. Shelfy may celebrate verified
patterns, but it must not invent motivation, struggle, luck, or personal history
that the app cannot know.

## Non-goals

Collector Type is not:

- a live scoreboard
- a rank or achievement ladder
- a completion calculator
- a recommendation engine
- a journey-history summary
- a user personality diagnosis
- a reason to infer facts Shelfy has not recorded

This PDR does not define resolver thresholds, scoring formulas, eligibility
rules, or implementation gates. Those belong in implementation documentation
and tests.

## Related Decisions

- [`PDR-002: Completion Semantics`](PDR-002-completion-semantics.md)
- [`docs/COLLECTION_ARCHITECTURE_NOTES.md`](../../COLLECTION_ARCHITECTURE_NOTES.md)
- [`lib/features/collection/insights/AGENTS.md`](../../../lib/features/collection/insights/AGENTS.md)


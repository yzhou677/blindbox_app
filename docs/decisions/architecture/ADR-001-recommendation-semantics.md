# ADR-001: Recommendation Semantics

## Status

Accepted.

## Decision

Shelfy recommendations answer: **what should this collector consider collecting
next based on the catalog series they have deliberately tracked?**

For You uses tracked catalog series as the durable taste signal. Owned figures,
wishlist marks, completion progress, and Master Complete status remain collection
progress or shopping intent; they do not drive recommendation refresh, profile
hashing, cloud sync, or ranking.

Recommendations are intentionally stable. They refresh when long-term collecting
taste changes, such as adding or removing a tracked catalog series, not when the
collector toggles individual figure states.

## Context

Collectors express intent at several depths:

- adding a catalog series to the shelf
- marking figures owned
- wishlisting figures for later
- completing Regular or Secret goals

If every figure-level change reshuffled For You, the rail would feel noisy and
untrustworthy. If Add Series did not affect recommendations, the rail would feel
blind to deliberate collecting intent.

Shelfy treats tracked catalog series as the clearest durable taste signal.

## Rationale

Tracked series represent a collector's explicit choice to follow a world, IP, or
series. That signal is more durable than momentary owned/wishlist state and is
less likely to produce surprising churn.

This separates:

- **Taste**: tracked catalog series and their derived IPs
- **Progress**: owned figures, completion, Master Complete
- **Shopping**: wishlist intent inside tracked series

Repository and rule-engine layers own recommendation decisions. Widgets display
results; they do not implement recommendation semantics.

## Consequences

We gain a calmer For You rail, fewer unnecessary profile syncs, better cache
stability, and a supportable mental model: tracking a series tells Shelfy what
the collector is interested in.

We give up real-time reshuffling when a collector marks figures owned or toggles
wishlist. Wishlist-based or owned-figure-based discovery may become a separate
feature later, but it is not For You.

Do not reintroduce any of the following without revising or superseding this ADR:

- wishlist scoring
- owned-IP affinity as the primary taste signal
- figure-level profile hashes
- widget-owned recommendation logic
- backend-driven UI decisions that bypass the repository contract

## Alternatives Considered

**Owned figures as taste.** Rejected because ownership is progress inside an
already tracked collection goal, and it would make the rail churn during normal
shelf maintenance.

**Wishlist as taste.** Rejected because wishlist is shopping intent inside a
tracked series; it belongs to collection and market workflows, not For You
ranking.

**Refresh on every collection mutation.** Rejected because it increases network
and cache churn while making recommendations feel unstable.

## Implementation Links

- [`lib/features/recommendations/`](../../../lib/features/recommendations/)
- [`functions/src/recommendations/`](../../../functions/src/recommendations/)
- [`docs/CATALOG_ARCHITECTURE.md`](../../CATALOG_ARCHITECTURE.md)
- [`docs/decisions/product/PDR-002-completion-semantics.md`](../product/PDR-002-completion-semantics.md)


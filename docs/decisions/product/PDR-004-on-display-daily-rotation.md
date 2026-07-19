# PDR-004: On Display Daily Rotation

- Status: Accepted
- Date: 2026-07-18

## Context

On Display presents one active shelf series as a daily museum-style display.
Random or hash-like selection can repeat a series before other eligible series
have appeared. That feels unpredictable and does not give each shelf series
equal exposure.

## Decision

On Display uses a fair, deterministic daily rotation:

1. Build candidates from the current active shelf-series payload.
2. Treat every candidate equally.
3. Sort candidates by the permanent `ShelfSeries.id` value.
4. Compute `index = daysSinceEpoch % candidateCount`.
5. Display the candidate at that index.

Selection is derived again whenever the widget updates. It is not pinned to a
previously stored choice and does not use `Random`, a date hash, or any other
non-deterministic selection.

With an unchanged candidate set, the displayed series is stable throughout a
local calendar day, advances the next day, and every series appears once before
the rotation repeats. Consecutive days cannot show the same series unless only
one candidate exists.

Adding or removing a shelf series changes the sorted candidate set and
naturally remaps the current day's index. If the displayed series is deleted,
the widget immediately resolves the correct candidate for the same day from
the updated list.

## Scope

This decision governs only On Display candidate selection. It does not change:

- shelf or wishlist eligibility semantics
- collection completion semantics
- widget payload fields
- widget navigation, synchronization, layout, or update scheduling

## Consequences

- Every active shelf series receives equal exposure while the candidate set is
  unchanged.
- Selection is reproducible from the local date and current candidates without
  stored rotation state.
- Candidate-list changes may alter the series shown for the current day, which
  is intentional.

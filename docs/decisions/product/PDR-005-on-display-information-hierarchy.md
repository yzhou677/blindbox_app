# PDR-005: On Display Information Hierarchy

- Status: Accepted
- Date: 2026-07-18

## Context

On Display must communicate more than catalog metadata. As a Shelfy collection
surface, it needs to explain both which series is featured today and how that
series relates to the user's collection.

## Decision

Populated Medium and Large widgets use two clear information regions:

1. The featured-series region identifies today's display with its cover,
   series name, IP, and brand.
2. The `IN THIS SERIES` region summarizes the user's relationship with that
   series using existing exported collection values.

The collection summary shows owned figure count and regular completion
percentage as structured statistics. Large preserves that structure for a
series with no owned figures by showing `0 Figures` and `0% Complete` rather
than replacing the statistics with an editorial status. The third Large stat
shows the derived owned Secret count by default. When the series is Master
Complete, that cell changes to the Master Complete state.

Small remains an at-a-glance image-first layout and does not add collection
statistics.

## Constraints

- Completion values continue to come from the existing completion resolver.
- This decision does not add payload fields or change eligibility, rotation,
  synchronization, navigation, or collection-screen semantics.
- Catalog identity is not repeated in the collection-summary region.

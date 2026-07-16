# PDR-002: Completion Semantics

## Status

Accepted.

## Product Principle

Completion in Shelfy is collector-facing. It describes what collecting goal has
been achieved, not merely how many database rows exist.

**Complete** means every Regular figure in a series is collected.

**Master Complete** means every Regular figure and every Secret figure in a
Secret-enabled series is collected.

Master Complete is a stronger form of Complete. A Master Complete series is also
a Completed Series, but the two labels should not be flattened into one generic
"complete" message.

## Why

Regular figures and Secret figures represent different collector goals. Regular
completion should feel achievable and should not be lowered just because a
series includes Secrets. Secret completion is a higher tier, not a penalty
against Regular progress.

This distinction preserves trust. A collector who completed every Regular figure
should see that achievement clearly, while a collector who also found every
Secret should receive the stronger Master Complete recognition.

## User Impact

Collectors can understand their shelf at a glance:

- Completed Series includes series that are Complete or Master Complete.
- Master Complete should be called out distinctly when it applies.
- Regular Progress should reflect Regular collecting progress and should not be
  reduced by missing Secrets once Regular completion is achieved.
- Master Completion should only consider series that actually have Secret
  figures.
- Shelfy should never imply a Secret goal exists for a series with no Secret
  figures.

## Non-goals

This PDR does not define algorithms, function names, data structures, UI layout,
or scoring formulas.

It also does not require every surface to show every tier at all times. Product
surfaces may use progressive disclosure, as long as they preserve the meaning of
Complete and Master Complete.

## Related Decisions

- [`PDR-001: Collector Type Semantics`](PDR-001-collector-type-semantics.md)
- [`docs/COLLECTION_ARCHITECTURE_NOTES.md`](../../COLLECTION_ARCHITECTURE_NOTES.md)
- [`lib/features/collection/domain/series_completion_resolution.dart`](../../../lib/features/collection/domain/series_completion_resolution.dart)


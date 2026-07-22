# Figure Recognition PR7: Whole-Image Quality Precheck

PR7 adds a device-local quality precheck immediately after photo acquisition
and before subject suggestion. It follows
[`PDR-001: Figure Recognition Principles`](decisions/product/PDR-001-figure-recognition-principles.md):
guidance should happen before failure, while recognition remains focused on one
intended collectible.

## Responsibility boundary

> **Whole Image Gate is an experience optimization, not a recognition decision.**

The gate does not decide whether a collectible can be recognized. It prevents
only an obviously unusable photograph from entering the more expensive scan
flow. Uncertain photographs pass.

This narrow responsibility is intentional:

- It runs locally, without upload, network access, Cloud Functions, or AI.
- It uses one deterministic, low-cost, conservatively configured image metric.
- It does not locate a collectible or evaluate the selected subject.
- It does not predict retrieval quality, recognition confidence, or identity.
- It does not replace the selected-subject quality gate or later retrieval
  safeguards.

Adding AI, Gemini, or multiple quality metrics would not make this precheck a
better recognition system because recognition is not its job. Complexity
belongs in the later stages that evaluate the collector's intended subject and
the evidence for a Catalog match.

## Pipeline position

```text
local photo acquisition
-> whole-image quality precheck
-> local verification and recovery
-> future subject suggestion and manual adjustment
-> selected-subject quality evaluation
-> recognition and retrieval safeguards
```

Only the first three stages belong to this part of PR7. A passing result means
only that the complete photograph is not obviously unusable. It is not a claim
that any visible collectible is sufficiently sharp, large, isolated, or
recognizable.

## Ownership

The application-level evaluator owns deterministic preprocessing, the
versioned conservative policy, and the simple pass/recovery result. Flutter
owns preview, guidance, and recovery actions. Backend recognition components
remain unaware of this precheck, and the precheck remains unaware of subject
selection, embeddings, retrieval, ranking, and recognition decisions.


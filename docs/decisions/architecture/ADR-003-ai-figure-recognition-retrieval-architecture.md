# ADR-003: AI Figure Recognition Uses Catalog-Constrained Multimodal Retrieval

## Status

Accepted.

## Current production implementation

See [`docs/figure-recognition.md`](../../figure-recognition.md) for the live
pipeline. Production `recognizeFigureV1` uses
`CandidateRetrievalDecisionResolver` (`retrieval-policy-candidate-v1`) with
absolute Top-1 distance `0.240` and minimum Top-1/Top-2 gap `0.025`. Hydration
runs only for presentable candidates. Shadow decision tooling remains
evaluation-only.

Current presentation path:

```text
Confirmed subject crop
-> embedding + Top-K retrieval
-> CandidateRetrievalDecisionResolver
-> hydrate when presentable
-> candidate UI or no-match UI
-> Series navigation (no auto-add)
```

## Decision

Shelfy Figure Recognition uses a catalog-constrained multimodal retrieval
pipeline:

```text
Input image
-> image normalization / confirmed subject crop
-> Gemini image embedding
-> Firestore nearest-neighbor search
-> Top-K Catalog candidates
-> confidence resolution (candidate policy)
-> optional reranking (future)
-> user confirmation via Series / Custom
```

### Recognition is closed-world

Shelfy recognizes only figures and series represented in its curated official
Catalog. It must not invent figure names, series names, IDs, or taxonomy
relationships. When no candidate is sufficiently trustworthy, the result is
`No confident catalog match`; the collector may retry or use Custom Series for
content outside the Catalog.

### Retrieval precedes classification

The input image is embedded first. Firestore Vector Search retrieves a bounded
Top-K candidate set from the active Catalog embedding space. Any later reasoning
or reranking operates only on those verified Catalog candidates. A generative
vision model is not asked to classify directly across the entire Catalog.

### One active embedding space

Recognition queries use the same embedding model, location, dimension, pipeline
version, and embedding-space identifier as stored Catalog embeddings. The
current active space is `gemini-embedding-2_us_1024_image-v1`.

Queries must constrain retrieval to the active space. Embeddings from different
spaces must never participate in the same similarity comparison. A model
migration rebuilds the derived Catalog embedding collection and updates the
central active-space configuration.

### Retrieval returns actionable metadata

Embedding documents include `figureId`, `seriesId`, `brandId`, `ipId`, and
`isSecret`. Retrieval can therefore identify the relevant Series and product
context before a Catalog join. Canonical display names and complete metadata
remain owned by the Catalog source of truth.

### Confidence is a product decision

Raw vector distance or similarity does not directly determine user-facing
certainty. Confidence resolution may consider the Top-1 score, the Top-1 versus
Top-2 margin, consistency across inputs, embedding-space calibration data,
candidate conflicts, and optional reranker agreement.

User-facing outcomes are bounded to:

- High confidence
- Review
- No confident match

A high-confidence result may be preselected, but recognition never mutates the
Collection without user confirmation.

### Reranking is optional and downstream

A future vision reranker may compare an input crop with a small Top-K candidate
set. It must receive only verified Catalog candidates, return only IDs from that
set, remain replaceable, pass through confidence resolution, and never write
Collection state directly. Reranking is not required for initial retrieval.

### Recognition is separate from Collection mutation

Recognition answers which Catalog entity most likely appears in an image.
Collection logic separately determines what that result means for the collector:

- Figure already owned
- Series exists, figure not owned
- Series not yet in Collection
- No confident Catalog match

Recognition infrastructure does not own Collection persistence.

### Input scope can evolve independently

The initial workflow expects one clear, front-facing figure image. Future
detection, cropping, grouping, and deduplication layers may produce regions from
single-figure, multi-figure, multi-Series, or shelf photos. Each region reuses
the same Catalog retrieval pipeline, which remains independent of capture UI and
multi-object detection.

## Context

Shelfy wants to identify figures from collector photos, connect matches to the
official Catalog, and then offer Collection-aware actions. Shelfy already has
canonical Catalog entities, official images in Firebase Storage, Gemini
multimodal embedding generation, native Firestore vector persistence, and an
idempotent Catalog embedding indexing workflow.

The first product workflow does not need open-world recognition or full shelf
segmentation. It needs a trustworthy way to retrieve real Catalog identities
from a clear figure photo while preserving explicit user control over Collection
changes.

## Consequences

- Successful results are constrained to real Catalog entities, reducing
  hallucinated names and guaranteeing actionable IDs.
- Catalog growth automatically expands recognition coverage, while Catalog
  embeddings are generated once and reused.
- The retrieval core can evolve from one figure to multiple detected regions
  without replacement.
- Collection-aware actions remain explicit and independently testable.
- Top-1, Top-K, rejection, latency, and cost can be measured and calibrated.
- Collectibles outside the Catalog cannot be identified automatically.
- Official Catalog images and collector photos may have a visual domain gap.
- Similar figures may require calibrated confidence thresholds or reranking.
- Model changes require rebuilding Catalog embeddings.
- Multi-figure photos require separate detection, cropping, grouping, and
  deduplication layers.

## Alternatives Considered

### Direct generative vision classification

Rejected as the primary architecture because it may invent names, cannot
guarantee Catalog IDs, grows expensive with large candidate sets, and is harder
to make deterministic.

### Training a custom end-to-end classifier now

Rejected because Shelfy does not yet have a sufficiently large labeled dataset
of real-world collector photos.

### Open-world product recognition

Rejected because Shelfy's product contract is Catalog-first. Unsupported
collectibles use Custom Series rather than receiving speculative matches.

### Full shelf scan as the first release

Rejected because segmentation, occlusion, grouping, and deduplication introduce
substantially more product and technical risk than single-figure retrieval.

## Invariants

- Every successful recognition result references an existing Catalog `figureId`.
- Every comparison uses one compatible active embedding space.
- Raw vector scores are not presented as unquestioned truth.
- Low-confidence inputs may return no match.
- Recognition never writes Collection state without user confirmation.
- Custom Series remains the fallback for unsupported content.
- Catalog documents remain the source of truth; embeddings remain derived and
  rebuildable infrastructure.

## Initial Implementation Sequence

1. Catalog embedding generation
2. Native vector persistence
3. Firestore nearest-neighbor retrieval
4. CLI evaluation against real figure photos
5. Confidence calibration
6. Recognition API
7. Flutter scan and confirmation workflow
8. Optional reranking
9. Future multi-figure detection and grouping

## Scope

This ADR records the durable architecture. It does not itself implement vector
index creation, nearest-neighbor search, recognition APIs, Flutter UI,
Collection mutation, multi-object detection, or reranking.

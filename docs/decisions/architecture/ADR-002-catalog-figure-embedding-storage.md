# ADR-002: Catalog Figure Embedding Storage

## Status

Accepted.

## Decision

Shelfy stores precomputed image embeddings in `catalogFigureEmbeddings`.

**Primary (required):** one document per figure at `catalogFigureEmbeddings/{figureId}`
for `figure.imageKey`. This ID scheme is frozen so existing production primaries
are not invalidated.

**Optional alternatives (recognition-only):** when a figure declares
`alternativeImages[]`, each supplemental image is stored at
`catalogFigureEmbeddings/{figureId}__alt__{imageKey}`. Alternatives share the
same `figureId` / `embeddingSpace` and carry `imageRole: "alternative"` plus a
non-empty `variant` string. They are not a gallery and are not shown in Catalog
UI.

Each record is a native Firestore vector (not a numeric array) with catalog
identity, Storage object path, SHA-256 content hash, explicit embedding-space
identity, timestamps, and when written by current tooling: `imageKey`,
`imageRole`, and `variant`. Display or merchandising fields are not duplicated.

The active space is `gemini-embedding-2_us_1024_image-v1`. Model, location,
dimension, version, and derived space identifier are centralized. A record is
reusable only when its byte hash and every embedding-space field match and its
native vector has exactly 1024 finite values. Catalog identity-only changes are
updated without regenerating the vector. Stale alternative docs are deleted only
when the embedding CLI is run with `--prune-stale-alternatives` (optional
`--prune-dry-run`); primaries are never deleted by that path.

## Context

Milestone 1 proved that the backend can embed one Storage image. Milestone 2
needs a deterministic and resumable catalog bootstrap while preserving a clean
boundary for future recognition and search work.

## Consequences

- Repeated runs are idempotent and content changes are detectable independently
  of filenames or download URLs.
- Native vector storage prevents an incompatible array representation from
  becoming accidental schema.
- A later embedding-space change requires an explicit migration decision.
- Model migrations regenerate and overwrite this derived collection.
- Vector indexes, nearest-neighbor search, user-photo recognition, and runtime
  production endpoints remain outside this milestone.

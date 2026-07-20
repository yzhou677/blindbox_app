# ADR-002: Catalog Figure Embedding Storage

## Status

Accepted.

## Decision

Shelfy stores one active image embedding per canonical catalog figure at
`catalogFigureEmbeddings/{figureId}`. The embedding is a native Firestore vector,
not a numeric array. The record contains catalog identity, Storage object path,
SHA-256 content hash, explicit embedding-space identity, and timestamps; it does
not duplicate display or merchandising fields.

The active space is `gemini-embedding-2_us_1024_image-v1`. Model, location,
dimension, version, and derived space identifier are centralized. A record is
reusable only when its byte hash and every embedding-space field match and its
native vector has exactly 1024 finite values. Catalog identity-only changes are
updated without regenerating the vector.

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

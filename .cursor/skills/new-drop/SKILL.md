---
name: new-drop
description: >-
  Runs a new official drop in order: local catalog files, production catalog
  upload, then the Home Official feed. Use when the user says a new drop or
  asks to add a series and publish the feed.
---

# New drop

> **WARNING:** `publish-series` and `publish-official-feed` write production. Catalog documents are never deleted. A feed push has no dry-run. `add-series-local` only edits files in `D:\blindbox-catalog`.

## Steps

1. Follow `add-series-local` (matching-table confirmation only; no upload).
2. When the user says it can go live, follow `publish-series` (one approval for Storage + Firestore + embed list, then run).
3. Ask whether to publish the Home Official feed. If yes, follow `publish-official-feed` (approve before image upload when needed; approve before push; verify Instagram `publishedAt` in that confirm list).

Catalog series and Official feed posts stay different records. Skipping step 3 is valid when the user only wanted the catalog.

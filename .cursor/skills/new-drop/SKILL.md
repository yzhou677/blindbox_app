---
name: new-drop
description: >-
  Runs a new official drop in order: local catalog files, production catalog
  upload, then the Home Official feed. Use when the user says a new drop or
  asks to add a series and publish the feed. Stop and wait between steps.
---

# New drop

> **WARNING:** `publish-series` and `publish-official-feed` write production. Catalog documents are never deleted. A feed push has no dry-run. `add-series-local` only edits files in `D:\blindbox-catalog`. Wait for the user to approve each step.

## Steps

1. Follow `add-series-local`. It does not upload. It stops with a git diff of `D:\blindbox-catalog`.
2. Stop. Wait until the user has checked that diff and says it can go live.
3. Follow `publish-series`. It stops before each Storage, Firestore, and embedding write.
4. Stop. Ask whether to publish the Home Official feed. If yes, verify the Instagram `publishedAt` before the push.
5. After approval, follow `publish-official-feed`. Do not run `push_official_feed.mjs` until the user approves that push.

Catalog series and Official feed posts stay different records. Skipping step 5 is valid when the user only wanted the catalog.

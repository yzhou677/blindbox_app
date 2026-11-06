---
name: new-drop
description: >-
  Runs a new official drop in order: catalog series first, then the Home
  Official feed. Use when the user says a new drop, a new series launch, or
  asks to add a series and publish the feed. Stop and wait for approval
  between steps.
---

# New drop

> **WARNING:** Both steps below can write production. Catalog documents are never deleted. A feed push has no dry-run. Confirm ids, `imageKey` values, links, and `publishedAt`, then wait for the user to approve each write.

Do catalog first. Publish the feed second. Stop between them.

## Steps

1. Discover the drop with the user. Name the brand, the series, and the official link. Do not write.
2. Verify the link and, if a feed post is planned, the Instagram `publishedAt`. Stop.
3. Follow "Input: pasted images" in `add-official-series`. Do not download art from the official page. Stop until the user confirms the table, then run `catalog-image-qa`. Stop until the user accepts the files.
4. After approval, continue `add-official-series` at "Write order". That skill stops before each Storage, Firestore, `meta/catalog`, and embedding write. Do not start the feed yet.
5. Stop. Ask whether to publish the Home Official feed.
6. After approval, follow `publish-official-feed`. Do not run `push_official_feed.mjs` until the user approves that push.

Catalog series and Official feed posts stay different records. Skipping step 6 is valid when the user only wanted the catalog.

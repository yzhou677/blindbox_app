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

1. The user gives one official product URL and pastes images. They do not write names. Do not write.
2. Follow "Input: pasted images" in `add-official-series`. Read the page for names. Do not save a page image as the catalog file. Stop for the one confirmation table, then run `catalog-image-qa`. Stop until the user accepts the files.
3. If a feed post is planned, verify the Instagram `publishedAt` before that later step. Stop.
4. After the user accepts the catalog files, continue `add-official-series` at "Write order". That skill stops before each Storage, Firestore, `meta/catalog`, and embedding write. Do not start the feed yet.
5. Stop. Ask whether to publish the Home Official feed.
6. After approval, follow `publish-official-feed`. Do not run `push_official_feed.mjs` until the user approves that push.

Catalog series and Official feed posts stay different records. Skipping step 6 is valid when the user only wanted the catalog.

---
name: add-official-series
description: >-
  Adds a catalog series, its figures, and their images to production Storage
  and Firestore. Use when the user adds an official series from a product
  URL and pasted images, or runs catalog delta sync. Stop and wait for
  approval before every write.
---

# Add an official series

> **WARNING:** A write here is production. Catalog documents are never deleted. A wrong write cannot be undone. Confirm every id, `imageKey`, and payload, then wait for the user to approve before any write.

Contract: [docs/CATALOG_DELTA_SYNC_INGEST.md](../../../docs/CATALOG_DELTA_SYNC_INGEST.md). Ids and "never delete" stay in [`.cursor/rules/firebase-catalog.mdc`](../../rules/firebase-catalog.mdc). Do not copy that rule here.

Upload scripts stay in `D:\blindbox-catalog`. Do not copy them into this repo. This repo does not document their CLI flags. Before you run either script, read that repo's README and the script `--help`. Do not guess flags.

## Input: pasted images

This is the default input. The user gives one official product URL and pastes images in chat. They do not write names or other facts. The pasted images have no captions.

Read the page for the series name, brand, IP, release date, whether it is a blind box, every figure name, and which figure is Secret. If a name is only inside a page image, such as a Figure Styles image, read that image. Do not skip it.

Do not download a page image and use it as the catalog file. The catalog file is only a pasted image.

1. Match brand and IP to rows that already exist in `D:\blindbox-catalog\data\brands.json` and `ips.json`. Use that row's `id`. Do not invent a brand id or an IP id. Series and figure ids follow the shape already used in `series.json` and `figures.json`: `imageKey` equals the document id.
2. Save each pasted image, in paste order, under `%TEMP%\shelfy_new_series\<seriesId>\`. That folder is outside this repo. Do not add the files to the repo. Do not commit them.
3. If you cannot save a pasted image as a file, stop. Tell the user to drop the files into that folder. Do not use a different image.
4. Match each saved image to a figure by looking at the picture and the styles on the page. Mark confidence `high` or `low`. Do not use any other scale.
5. Show one table and wait. Ask every uncertain field in that same message. Do not guess. Do not ask one field at a time.

```text
image number → figure name → figureId → imageKey → pixel size → Secret → confidence
```

Open each saved file and record its width and height. Do not invent a size. If the pasted count does not match the figure count on the page, say so in that message.
6. After the user confirms the table, rename each file so the stem equals the confirmed `imageKey`. Keep the original extension. Then run `catalog-image-qa`.

## Manual steps

1. Follow "Input: pasted images". Do not ask the user to name the series, the brand, or the figures.
2. Run `catalog-image-qa` only after the user confirms the table. Fix failures before upload.
3. Show the canonical ids, `imageKey` values, and which docs will change. Wait for approval.

## Write order

1. Upload bytes with `D:\blindbox-catalog\scripts\upload_storage.js`. After a real upload, `imageVersion` is that object's Storage `md5Hash`. Also set that doc's `updatedAt`. A `[skip_unchanged]` upload does not bump `updatedAt` or `meta/catalog`.
2. Write Firestore with `D:\blindbox-catalog\scripts\upload_firestore.js`. Load the existing doc. Write only when the payload changed. Set `updatedAt` on those docs. Skip equal docs and do not bump `updatedAt`. Keep the existing `imageVersion` unless the Storage step already set it. Do not store a download URL. Do not change `imageKey` when only the bytes changed.
3. If this round wrote anything, set `meta/catalog.lastUpdatedAt`. If nothing changed, do not touch `meta/catalog`.
4. Embed the new figures. From `functions/`, with `GOOGLE_CLOUD_PROJECT` and `FIREBASE_STORAGE_BUCKET` set (see [docs/FIGURE_RECOGNITION_M2.md](../../../docs/FIGURE_RECOGNITION_M2.md)):

```text
npm run embed:catalog-figures -- --figure-id <figureId>
```

Run once per new figure. The script prints a plan, then waits for `y` before paid calls and `catalogFigureEmbeddings` writes. Any other answer writes nothing. Do not run it with no `--figure-id` unless the user asked for a full catalog scan. Do not pass `--prune-stale-alternatives` for a new drop.

Stop after each of the four write steps and wait for approval.

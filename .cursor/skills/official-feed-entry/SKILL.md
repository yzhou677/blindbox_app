---
name: official-feed-entry
description: >-
  Adds a catalog series or figure, or an Official feed post, using the
  contracts already in this repo. Use when the user adds a series, a figure,
  catalog art, imageKey, imageVersion, delta sync, or an official_feed_items
  post.
---

# Official catalog and feed entry

Catalog series/figures and Home Official feeds are different. Do not write a feed post when the task is a catalog series, or the reverse.

Catalog identity and Firebase boundaries stay in [`.cursor/rules/firebase-catalog.mdc`](../../rules/firebase-catalog.mdc) and [AGENTS.md](../../../AGENTS.md). This skill only lists the entry steps those files do not spell out.

## Catalog series or figure

This repo does not contain the ingest uploader. Field and path rules live here:

- [lib/features/catalog/firestore/FIRESTORE_CATALOG_SCHEMA.md](../../../lib/features/catalog/firestore/FIRESTORE_CATALOG_SCHEMA.md)
- [lib/features/catalog/firestore/FIREBASE_STORAGE_CATALOG.md](../../../lib/features/catalog/firestore/FIREBASE_STORAGE_CATALOG.md)
- [docs/CATALOG_DELTA_SYNC_INGEST.md](../../../docs/CATALOG_DELTA_SYNC_INGEST.md)

Check before you call the external ingest done:

1. Do not delete catalog documents. Do not add `deleted` or tombstones.
2. Document id, `id`, `brandId` / `ipId` / `seriesId`, and `imageKey` match. `imageKey` equals the Storage filename stem.
3. Storage path is `catalog/series/<imageKey>.<ext>` or `catalog/figures/<imageKey>.<ext>`. Extensions probed: `.webp`, `.png`, `.jpg`, `.jpeg`, `.avif`. Do not store a download URL on the Firestore doc.
4. After a real upload, set `imageVersion` to the Storage object `md5Hash` and set `updatedAt`. Do not change `imageKey` when only the bytes change.
5. Bump `meta/catalog.lastUpdatedAt` only if this round wrote something. A no-op round must not touch it.
6. To backfill `imageVersion` / `updatedAt` without re-uploading, from this repo:

```text
node tools/catalog/backfill_catalog_sync_fields.mjs --dry-run
```

Run without `--dry-run` only after the dry-run looks right. It needs an Admin SDK service account.

`scripts/upload_storage.js` and `scripts/upload_firestore.js` are specified for `D:\blindbox-catalog`. They are not in this repo.

## Official feed post

Feed posts are `official_feed_items`. They are not Latest drops.

Follow [tools/official_feed/README.md](../../../tools/official_feed/README.md) and [lib/features/official_feed/FIRESTORE_OFFICIAL_FEED_SCHEMA.md](../../../lib/features/official_feed/FIRESTORE_OFFICIAL_FEED_SCHEMA.md).

1. Edit one seed: `tools/official_feed/<sourceId>.seed.json`. Sources: `popmart_us`, `tntspace_us`, `toptoy_us`, `sonnyangel_us`.
2. Required Firestore fields: `id`, `sourceId`, `sourceLabel`, `title`, `imageUrl`, `officialUrl`, `publishedAt`, `ingestedAt`, `status`, `contentHash`.
3. `publishedAt` is the Instagram post UTC instant. Get it with:

```text
node tools/official_feed/_ig_shortcode_date.mjs <shortcode>
```

Use the `utc` field. Do not truncate to midnight.
4. `imageUrl` is one product image (png, jpg, jpeg, or webp). No `A_` / `B_` / `C_` carousel names. No reseller host unless `curationOverride` is `reseller_image_ok`.
5. Check, then push:

```text
node tools/official_feed/curate_check.mjs tools/official_feed/<seed>.json
node tools/official_feed/push_official_feed.mjs tools/official_feed/<seed>.json
```

Optional: `node tools/official_feed/check_url.mjs "<officialUrl>"`. HTTP 200 is not proof the product exists.

`productIdConfirmed` and `curationOverride` stay in the seed. They are not written to Firestore.

---
name: publish-official-feed
description: >-
  Publishes one Official feed seed to production Firestore. Use when the user
  edits tools/official_feed seeds, checks a post, or pushes official_feed_items.
  Stop and wait for approval before push. Push has no dry-run.
---

# Publish an Official feed

> **WARNING:** Push writes production immediately. There is no dry-run. Home reads `official_feed_items` from Firestore, not the JSON file. `upload_official_feed_image.mjs` writes production Storage. Confirm every id, link, image, and `publishedAt`, then wait for the user to approve before `push_official_feed.mjs` or `upload_official_feed_image.mjs`.

Feed posts are not catalog series. Follow [tools/official_feed/README.md](../../../tools/official_feed/README.md).

## Manual steps

1. Discover the drop on that brand's official Instagram. Skip restocks and non-US posts when the seed is a US feed.
2. Open the product link in a browser when one exists. Copy `officialUrl` and optional `instagramUrl` from the live page or post. Do not invent a product id.
3. Set `publishedAt` from the Instagram post instant:

```text
node tools/official_feed/_ig_shortcode_date.mjs <shortcode>
```

Use the `utc` field. Do not truncate it to midnight. Do not use the sale start time.
4. Pick one product image (`imageUrl`). https, and png, jpg, jpeg, or webp. No `A_` / `B_` / `C_` carousel names. No reseller host unless `curationOverride` is `reseller_image_ok`.
5. Show the seed diff. Wait for approval.

## Commands

Edit one seed: `popmart_us`, `tntspace_us`, `toptoy_us`, or `sonnyangel_us`.

```text
node tools/official_feed/validate_seed.mjs tools/official_feed/<seed>.json
node tools/official_feed/curate_check.mjs tools/official_feed/<seed>.json
node tools/official_feed/push_official_feed.mjs tools/official_feed/<seed>.json
```

`validate_seed` does not write. `curate_check` does not write. ERROR blocks the push. WARNING blocks only with `--strict`.

Optional: `node tools/official_feed/check_url.mjs "<officialUrl>"`. HTTP 200 is not proof the product exists.

## Ids

The seed is the full active set for that `sourceId`. Push writes those items, then archives any other active doc for the same `sourceId` that is not in the seed.

To change an `id`, add the old id to `retiredItemIds`. Push sets that doc to `status: archived`. It does not delete the document.

`productIdConfirmed` and `curationOverride` stay in the seed. They are not written to Firestore.

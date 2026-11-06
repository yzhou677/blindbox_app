---
name: publish-official-feed
description: >-
  Publishes one Official feed post from an Instagram URL into a brand seed,
  then pushes that seed. Use when the user pastes an Instagram post, edits
  tools/official_feed seeds, or asks to push official_feed_items. Stop before
  every production write. Push has no dry-run.
---

# Publish an Official feed

> **WARNING:** Push writes production immediately. There is no dry-run. Home reads `official_feed_items` from Firestore, not the JSON file. One push puts the post on Home. `upload_official_feed_image.mjs` writes production Storage. The seed must be that brand's full active list. Push archives every active doc for that `sourceId` that is not in the seed. Confirm the new fields, `publishedAt`, and the retire list, then wait for the user to approve before `upload_official_feed_image.mjs` or `push_official_feed.mjs`.

Feed posts are not catalog series. Field rules: [tools/official_feed/README.md](../../../tools/official_feed/README.md) and [lib/features/official_feed/FIRESTORE_OFFICIAL_FEED_SCHEMA.md](../../../lib/features/official_feed/FIRESTORE_OFFICIAL_FEED_SCHEMA.md).

## Input

The user gives one Instagram post URL. They may also attach an image. They do not write the other fields.

Seeds: `popmart_us`, `tntspace_us`, `toptoy_us`, `sonnyangel_us`. Match the post to one of those accounts. If it is not one of them, stop and ask. Do not guess the brand.

## Read the post and the product page

1. Take the title and the brand from the post. Take `publishedAt` from the shortcode, not from the page text:

```text
node tools/official_feed/_ig_shortcode_date.mjs <shortcode>
```

Store the `utc` field. It is ISO-8601 UTC and ends in `Z`, with milliseconds, like `2026-10-29T13:00:59.388Z`. Do not truncate it to midnight. Do not use a relative string such as "2 days ago". This script does not return a source timezone. Do not scrape one.

2. Look for that brand's product page. These scripts take a URL you already have. They do not search:

```text
node tools/official_feed/fetch_popmart_meta.mjs <productUrl>
node tools/official_feed/check_url.mjs <url>
node tools/official_feed/fetch_og.mjs <url>
node tools/official_feed/fetch_product_images.mjs <url>
```

`fetch_popmart_meta.mjs` is for POP MART pages. `check_url.mjs` prints `spaShell` and `phantomAccepted`. HTTP 200 is not proof the product exists. `probe_page.mjs` and `find_images.mjs` only read a `__NEXT_DATA__` page.

3. If the product page is the same item:
   - `officialUrl` is the product page.
   - `imageUrl` is one image from that page (`ogImage` or a single product image). https, and png, jpg, jpeg, or webp. No `A_` / `B_` / `C_` carousel names.
   - `instagramUrl` is the post URL.
   - `productId` comes from the product URL. For POP MART the id suffix must be `_<productId>`, matching the existing seed.
   - Set `productIdConfirmed` to true only after the id is copied from a hydrated page. A SPA shell is not enough. It stays in the seed and is not written to Firestore.
4. If there is no product page:
   - `officialUrl` and `instagramUrl` are both the Instagram post URL.
   - Do not invent a `productId`.
   - If the user pasted an image in chat, save it outside the repo first, under `%TEMP%\shelfy_official_feed\`. Do not commit it. Wait for the user to approve, then upload that local path. An https URL is still a valid first argument. `http:` is not accepted. Do not send the file to another image host.

```text
node tools/official_feed/upload_official_feed_image.mjs <httpsImageUrl-or-localFile> official_feed/<sourceId>/<file>
```

   The command writes production Storage and prints the download URL. Use that URL as `imageUrl`. It checks the PNG, JPEG, or WebP file header. It does not detect every corrupt image.
5. If you are not sure the page is the same product, list the candidates and ask. Do not guess.

Copy the id shape already used in that brand's seed. A product row uses `releaseType` `product`. An Instagram-only row uses `releaseType` `announcement`. Do not add deck tags.

`summary` is a short fact. If the product page prints an Online Release, copy that date, time, and timezone as printed. Existing examples end in `PT`. Do not convert that clock time into `publishedAt`.

## Retire

Adding N new active items retires N active items. Updating an existing id is not a new item. Retire the oldest `publishedAt` values in that seed. Put those ids in `retiredItemIds`. Remove those objects from `items`, so the active count stays the same. Push sets them to `status: archived`. It does not delete them. If there are not enough old items to retire, stop and ask. If two items tie for oldest, list both and ask. Do not pick.

## Confirm, then push

Edit the seed first. These two commands do not write:

```text
node tools/official_feed/validate_seed.mjs tools/official_feed/<seed>.json
node tools/official_feed/curate_check.mjs tools/official_feed/<seed>.json
```

ERROR blocks the push. WARNING blocks only with `--strict`.

Then show one list and wait:

- Every field of each new item.
- `publishedAt`: the `utc` value that will be stored. Also show that same instant in `America/Chicago`. Do not store the Chicago time.
- The ids to retire.
- The `validate_seed` and `curate_check` output.

Only after the user approves:

```text
node tools/official_feed/push_official_feed.mjs tools/official_feed/<seed>.json
```

## Read back

There is no read script in `tools/official_feed/`. Open `official_feed_items/<id>` in project `blindbox-collection`. Check that each new id is `active` and each retired id is `archived`. Other kept items keep the same business fields and stay `active`. `ingestedAt` may change, because every written item sets it (`push_official_feed.mjs`). Confirm there is no unexpected archive. The push log is not this check. Do not add a script.

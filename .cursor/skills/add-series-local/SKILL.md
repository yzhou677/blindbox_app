---
name: add-series-local
description: >-
  Prepares a new catalog series on disk in D:\blindbox-catalog. Use when the
  user gives an official product URL and pastes images, or asks to add a
  series locally. Do not upload to Storage or write Firestore.
---

# Add a series locally

This skill writes files only. Do not upload Storage. Do not write Firestore. Do not run embeddings.

## Input

The user gives one official product URL and pastes images. They do not write names. The pasted images have no captions.

Read the page for the series name, brand, IP, release date, whether it is a blind box, every figure name, and which figure is Secret. If a name is only inside a page image, such as a Figure Styles image, read that image.

Do not save a page image as the catalog file. The catalog file is only a pasted image.

1. Match brand and IP to existing rows in `D:\blindbox-catalog\data\brands.json` and `ips.json`. Use that row's `id`. Do not invent a brand id or an IP id.
2. Save each pasted image, in paste order, under `%TEMP%\shelfy_new_series\<seriesId>\`. That folder is outside both repos. Do not commit it.
3. If you cannot save a pasted image as a file, stop. Tell the user to drop the files into that folder. Do not use a different image.
4. Match each saved image to a figure by looking at the picture and the styles on the page. Mark confidence `high` or `low`. Do not use any other scale.
5. Show one table and wait. Ask every uncertain field in that same message. Do not guess. Do not ask one field at a time.

```text
image number → figure name → figureId → imageKey → pixel size → Secret → confidence
```

Open each saved file and record its width and height. Do not invent a size. If the pasted count does not match the figure count on the page, say so in that message.

## After confirmation

1. Copy the files into the folders `scripts/upload_storage.js` actually reads:

- `D:\blindbox-catalog\assets\catalog\series\<seriesId>.<ext>`
- `D:\blindbox-catalog\assets\catalog\figures\<figureId>.<ext>`

The filename stem equals `imageKey`, which equals the id. Keep the original extension. An `alternativeImages` file uses the same figures folder and its own `imageKey`. Do not use `images/series` or `images/figures`. Those folders are not uploaded.

2. Add rows to `D:\blindbox-catalog\data\series.json` and `figures.json`. Copy the keys of an existing object in that file. Series rows use `id`, `brandId`, `ipId`, `displayName`, `releaseDate`, `isBlindBox`, `imageKey`, `aliases`. Figure rows use `id`, `seriesId`, `brandId`, `ipId`, `displayName`, `isSecret`, `rarityLabel`, `sortOrder`, `imageKey`. Add `alternativeImages` only when the user confirmed an extra image. Each entry is `imageKey` plus `variant`, as in the existing rows.
3. Edit `brands.json` or `ips.json` only when the confirmation approved an id that is not already in the file. Match the existing keys: brands are `id`, `displayName`, `aliases`; ips are `id`, `brandId`, `displayName`, `aliases`.
4. Do not run `npm run normalize`. `D:\blindbox-catalog\README.md` says `data/` is regenerated from `raw/`. Normalize would drop this hand edit.
5. Run `catalog-image-qa` on those files. If it fails, stop. Do not call the result ready.
6. In `D:\blindbox-catalog`, show `git status` and `git diff` as a short summary: new files, and which JSON rows changed. Do not commit. Tell the user the next step is `publish-series`.

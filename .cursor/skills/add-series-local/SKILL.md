---
name: add-series-local
description: >-
  Prepares a new catalog series on disk in D:\blindbox-catalog. Use when the
  user gives an official product URL and pastes images, or asks to add a
  series locally. Do not upload to Storage or write Firestore.
---

# Add a series locally

This skill writes files only. Do not upload Storage. Do not write Firestore. Do not run embeddings.

`D:\blindbox-catalog` is **not** a git repo. Do not run `git status` / `git diff` there. Do not invent git reports.

Catalog scripts and flags live in that repo (`package.json`, README, script Usage, `uploader.mdc`). Prefer those over inventing flags. Do not copy default flags into this skill.

## Input

The user gives one official product URL and pastes images. They do not write names. The pasted images have no captions.

Read the page for the series name, brand, IP, release date, whether it is a blind box, every figure name, and which figure is Secret. If a name is only inside a page image, such as a Figure Styles image, read that image.

Do not save a page image as the catalog file. The catalog file is only a pasted image.

1. Match brand and IP to existing ids already present in that catalog repo (read generated `data/` or existing `raw/` bundles only to look up ids). Use that row's `id`. Do not invent a brand id or an IP id.
2. Save each pasted image, in paste order, under `%TEMP%\shelfy_new_series\<seriesId>\`. That folder is outside both repos. Do not commit it.
3. If you cannot save a pasted image as a file, stop. Tell the user to drop the files into that folder. Do not use a different image.
4. Match each saved image to a figure by looking at the picture and the styles on the page. Mark confidence `high` or `low`. Do not use any other scale.
5. Show one table and wait. Ask every uncertain field in that same message. Do not guess. Do not ask one field at a time.

```text
image number → figure name → figureId → imageKey → pixel size → Secret → confidence
```

Open each saved file and record its width and height. Do not invent a size. If the pasted count does not match the figure count on the page, say so in that message.

This matching-table confirmation is the only production-safety stop in this skill. Do not add other waits.

After the table, decide the run mode yourself:

- **New series** (ids not already in catalog) → **metadata + art**. Do not ask.
- **Existing series, art replace only** → **art only**. Do not ask.
- **Ambiguous** (existing ids but metadata may also change) → ask once: metadata + art, or art only.

Do not ask the user to pick a mode when the case is already clear.

## After confirmation

### Catalog art

Write into the folders `scripts/upload_storage.js` actually reads:

- `D:\blindbox-catalog\assets\catalog\series\<seriesId>.<ext>`
- `D:\blindbox-catalog\assets\catalog\figures\<figureId>.<ext>`

**Prefer `.webp`.** `.png` / `.jpg` / `.jpeg` are allowed. `.avif` is allowed but not recommended (large files hurt app performance).

1. Copy each confirmed paste into the matching catalog path (stem = `imageKey` = id). If the paste is already `.webp`, copy it as `.webp`.
2. Convert every non-WebP paste with `npm run convert:webp` from that catalog repo. Pass only documented file arguments. Do not invent a `sharp` / `cwebp` / ImageMagick one-liner.
3. If conversion fails for a file, keep that original on disk, note it as `NON_WEBP` in the summary, and continue. Do not delete the original until a `.webp` replacement for that stem is confirmed on disk.
4. After a successful convert for a stem, remove other same-stem leftovers (`.png`, `.jpg`, `.jpeg`, `.avif`) if the convert command did not already remove the source.

The filename stem equals `imageKey`, which equals the id. An `alternativeImages` file uses the same figures folder and its own `imageKey`. Do not use `images/series` or `images/figures`. Those folders are not uploaded.

### Metadata vs art-only

`raw/` is the source of truth. **`data/` is generated.** Do not hand-edit `data/brands.json`, `ips.json`, `series.json`, or `figures.json`.

**Art only** (series and figures already in catalog; metadata unchanged):

1. Do **not** edit `raw/`. Do **not** create a `*.bak`.
2. Do **not** edit `data/`.
3. Do **not** run normalize.
4. Write / convert catalog art as above.
5. Optionally run `npm run qa:images` in that catalog repo (or a quick eye check for missing stems / wrong stem / obvious collage). Do not block on warnings.
6. Short summary of changed art (and any kept non-WebP). Tell the user the next step is `publish-series`.

**Metadata + art** (new series, or any metadata change):

1. Before editing any `raw/*.json`, copy each file you will change to a sibling `*.bak` once (for example `starter_catalog.json.bak`). Do not backup when you are not editing `raw/`.
2. Add or update the series in `raw/` using the bundle shape from that catalog README / `uploader.mdc`. Copy keys from an existing bundle. Do not invent a parallel schema.
3. Run `npm run normalize`. If it fails or expected series/figure ids are missing from `data/`, stop and show the normalize output.
4. Write / convert catalog art as above.
5. Optionally run `npm run qa:images` (same as art-only). Do not block on warnings.
6. Short summary of the series/figure ids written and art outcomes. Tell the user the next step is `publish-series`.

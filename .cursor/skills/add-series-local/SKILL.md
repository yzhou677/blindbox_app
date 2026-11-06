---
name: add-series-local
description: >-
  Prepares a new catalog series on disk in D:\blindbox-catalog. Use when the
  user gives an official product URL and pastes images, or asks to add a
  series locally. Do not upload to Storage or write Firestore.
---

# Add a series locally

This skill writes files only. Do not upload Storage. Do not write Firestore. Do not run embeddings.

Before you use `D:\blindbox-catalog` paths such as `assets/catalog/` or `raw/`, or any npm script in that repo, read `D:\blindbox-catalog\.cursor\rules\uploader.mdc`, its `package.json`, README, and the script header / documented Usage. If they disagree with this skill, stop. Do not copy flags or defaults into this skill — read them from that repo each time.

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

After the table, also ask whether this run is **metadata + art** (new series or changed metadata) or **art only** (series and figures already in catalog; metadata unchanged). Do not guess.

## After confirmation

### Catalog art

Write into the folders `scripts/upload_storage.js` actually reads:

- `D:\blindbox-catalog\assets\catalog\series\<seriesId>.<ext>`
- `D:\blindbox-catalog\assets\catalog\figures\<figureId>.<ext>`

**Prefer `.webp`.** `.png` / `.jpg` / `.jpeg` are allowed. `.avif` is allowed but not recommended (large files hurt app performance).

1. Copy each confirmed paste into the matching catalog path (stem = `imageKey` = id). If the paste is already `.webp`, copy it as `.webp`.
2. After the files are under `assets/catalog/`, convert every non-WebP paste (`.png`, `.jpg`, `.jpeg`, `.avif`) with that catalog repo's `npm run convert:webp`. Read its README section and `npm run convert:webp -- --help` (or the script Usage) each time. Pass only flags and arguments documented there. Do not invent a `sharp`, `cwebp`, or ImageMagick one-liner. Do not copy flags or defaults into this skill.
3. If conversion fails for a file, keep that original on disk, list it as `NON_WEBP` in the summary, and continue. Do not stop the drop for conversion failure alone. Do not delete the original until a `.webp` replacement for that stem is confirmed on disk.
4. After a successful convert for a stem, remove other same-stem leftovers (`.png`, `.jpg`, `.jpeg`, `.avif`) if the convert command did not already remove the source.

The filename stem equals `imageKey`, which equals the id. An `alternativeImages` file uses the same figures folder and its own `imageKey`. Do not use `images/series` or `images/figures`. Those folders are not uploaded.

### Metadata vs art-only

`raw/` is the source of truth. **`data/` is generated.** Do not hand-edit `data/brands.json`, `ips.json`, `series.json`, or `figures.json`.

**Art only** (series and figures already in catalog; metadata unchanged):

1. Do **not** edit `raw/`.
2. Do **not** edit `data/`.
3. Do **not** run normalize.
4. Still write / convert catalog art as above.
5. Run `catalog-image-qa` on the art files. Print **Failures** and **Warnings**. Failures stop this flow before you call the drop ready. Warnings (including `LOW_RES` and `NON_WEBP`, including AVIF) do not. Spec: [tools/seed/CATALOG_FIGURE_ART_REEXPORT_GUIDE.md](../../../tools/seed/CATALOG_FIGURE_ART_REEXPORT_GUIDE.md).
6. Show a short summary of which art files changed, conversion outcomes (including any kept as non-WebP with why), and the QA lists. If that catalog tree is a git repo, also show `git status` / `git diff` for the art paths. Do not commit. Tell the user the next step is `publish-series`.

**Metadata + art** (new series, or any metadata change):

1. Before editing any `raw/*.json`, copy each file you will change to a sibling `*.bak` (for example `starter_catalog.json.bak`).
2. Add or update the series in `raw/` using the bundle shape documented in that catalog README / `uploader.mdc`. Copy keys from an existing bundle in `raw/`. Do not invent a parallel schema.
3. Run normalize with the command documented there (see README Normalization / `package.json`). Do not invent flags. Do not paste default flags into this skill.
4. After normalize, check that `data/` contains the expected series and figure rows and ids. If it does not, stop and show the normalize output.
5. Write / convert catalog art as above (same WebP rules).
6. Run `catalog-image-qa` on the art files. Print **Failures** and **Warnings**. Failures stop this flow before you call the drop ready. Warnings (including `LOW_RES` and `NON_WEBP`, including AVIF) do not. Spec: [tools/seed/CATALOG_FIGURE_ART_REEXPORT_GUIDE.md](../../../tools/seed/CATALOG_FIGURE_ART_REEXPORT_GUIDE.md).
7. Show a short before/after summary for the `raw/` files you touched and the matching `data/` rows, plus any files kept as non-WebP with why. If that catalog tree is a git repo, also show `git status` / `git diff`. Do not commit. Tell the user the next step is `publish-series`.

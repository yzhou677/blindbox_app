---
name: catalog-image-qa
description: >-
  Checks catalog series and figure art on disk: imageKey stems, preferred
  WebP, and optional visual flags. Use when the user adds or replaces catalog
  images, or asks whether the files are ready to publish.
---

# Catalog image QA

Manual checklist for files under `D:\blindbox-catalog\assets\catalog\`. This repo has no script that measures pixels or grades Secret art. Do not invent one.

Names and Secret come from the confirmed `add-series-local` table. Do not download a replacement from the web.

Spec: [tools/seed/CATALOG_FIGURE_ART_REEXPORT_GUIDE.md](../../../tools/seed/CATALOG_FIGURE_ART_REEXPORT_GUIDE.md). Severity helper: [tools/seed/catalog_image_qa_severity.mjs](../../../tools/seed/catalog_image_qa_severity.mjs). Ids: [`.cursor/rules/firebase-catalog.mdc`](../../rules/firebase-catalog.mdc). Paths: [lib/features/catalog/firestore/FIREBASE_STORAGE_CATALOG.md](../../../lib/features/catalog/firestore/FIREBASE_STORAGE_CATALOG.md).

## Figure file

Path: `catalog/figures/<imageKey>.<ext>` (prefer `.webp`).

1. Prefer `.webp`. A `.png` / `.jpg` / `.jpeg` / `.avif` file for that stem is `NON_WEBP` — **warning** only. Do not block publish. Do not remove png/jpg support.
2. Filename stem equals `imageKey`. `imageKey` equals the Firestore document id stem. Mismatch is a **failure** (`IMAGEKEY_MISMATCH`).
3. No supported file for a required key is a **failure** (`MISSING_ASSET`).
4. Suggested long edge ≥ 1200px. Long edge under 800px is `LOW_RES` — **warning** only.
5. `PROMO_COMPOSITE` is a **failure** only when the file is a full marketing poster or collage, not a single figure. On-image title, logo, rarity, or SECRET text on a single figure is allowed. Do not report those as `PROMO_COMPOSITE`.
6. Other guide reason codes keep their meaning. Put each finding in **failures** or **warnings** as the guide lists.

## Series cover

Path: `catalog/series/<imageKey>.<ext>` (prefer `.webp`). A cover may be an editorial collage. Do not use the series cover as a figure image. The filename stem still equals `imageKey`. Non-WebP covers are `NON_WEBP` warnings.

## Result

Print two lists: **Failures** and **Warnings**.

- **Failures** stop `publish-series`. Fix or get an explicit user override before upload.
- **Warnings** are listed only. They do not stop the publish flow.

Do not upload from this skill.

---
name: catalog-image-qa
description: >-
  Manually checks catalog figure and series art before a Storage upload. Use
  when the user adds or replaces catalog images, imageKey files, or asks
  whether a figure picture meets the re-export guide.
---

# Catalog image QA

This is a human checklist. This repo has no script that checks pixel size, background, or filename. Do not invent one.

Check the files the user confirmed in `add-official-series` ("Input: pasted images"). Names and Secret come from that table. The pasted images have no captions. Do not download a replacement from the web.

Spec: [tools/seed/CATALOG_FIGURE_ART_REEXPORT_GUIDE.md](../../../tools/seed/CATALOG_FIGURE_ART_REEXPORT_GUIDE.md). Ids: [`.cursor/rules/firebase-catalog.mdc`](../../rules/firebase-catalog.mdc). Paths: [lib/features/catalog/firestore/FIREBASE_STORAGE_CATALOG.md](../../../lib/features/catalog/firestore/FIREBASE_STORAGE_CATALOG.md).

## Figure file

Path: `catalog/figures/<imageKey>.<ext>`.

1. Long edge is at least 1200px. Long edge under 800px is `LOW_RES`.
2. Background is transparent, or a clean soft neutral. Not a cream or beige poster page.
3. Format is `.webp` or `.png`. Keep alpha on cutouts.
4. Filename stem equals `imageKey`. `imageKey` equals the Firestore document id stem.
5. Id is canonical. Example: `the_monsters`, not a display label. The same id is the document id, `imageKey`, and Storage stem.
6. One figure, centered, about 70–85% of the frame height. Aspect is 1:1 or 4:5 portrait. No baked title, logo, rarity text, frame, or collage.
7. Secret (`isSecret: true`) is a silhouette on a transparent or dark-friendly background. Not a light beige card.

## Series cover

Path: `catalog/series/<imageKey>.<ext>`. A cover may be an editorial collage. Do not use the series cover as a figure image. The filename stem still equals `imageKey`.

## Result

List failures with the guide's reason codes (`LOW_RES`, `LIGHT_SOLID_BG`, `IMAGEKEY_MISMATCH`, and the others in that file). Stop. Do not upload.

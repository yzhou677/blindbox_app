---
name: image-qa
description: >-
  Checks catalog figure art, series covers, and Official feed image URLs
  against the rules in this repo. Use when the user reviews image size,
  format, thumbnails, naming, or a bad catalog picture.
---

# Image QA

Use the written specs. Do not invent a compressor, a quality percent, or a pixel tool. None of those exist in this repo.

Catalog art rules: [tools/seed/CATALOG_FIGURE_ART_REEXPORT_GUIDE.md](../../../tools/seed/CATALOG_FIGURE_ART_REEXPORT_GUIDE.md) and [lib/features/catalog/firestore/FIREBASE_STORAGE_CATALOG.md](../../../lib/features/catalog/firestore/FIREBASE_STORAGE_CATALOG.md).

Prefer WebP for catalog thumbnails. AVIF is allowed by the resolver but is slow to decode on Android ([docs/ARCHITECTURE_NOTES.md](../../../docs/ARCHITECTURE_NOTES.md), "Catalog image format").

## Figure art

Path: `catalog/figures/<imageKey>.<ext>`. `imageKey` is the Firestore document id stem.

1. One figure, centered. Subject about 70–85% of the height. Flag if the figure is under half the frame.
2. Aspect is 1:1 or 4:5 portrait. Flag landscape when width is about 20% greater than height, and 16:9 posters.
3. Long edge at least 1200px. The same guide also flags long edge under 800px as `LOW_RES`.
4. Format `.webp` or `.png`. Keep alpha for cutouts. Resolver also accepts `.jpg`, `.jpeg`, and `.avif`.
5. No baked series title, logo, rarity text, frame, or multi-figure collage.
6. Secret figures: silhouette on a transparent or dark-friendly background, not a light beige card.
7. Do not use the series cover as the figure image.

## Series cover

Path: `catalog/series/<imageKey>.<ext>`. A cover may be an editorial collage. Do not apply the figure cutout rules to it.

## Naming

1. Filename stem equals `imageKey`.
2. Do not put a download URL on the Firestore document.
3. When bytes change, bump `imageVersion` (Storage `md5Hash`). Do not change `imageKey`.

## Official feed images

`imageUrl` must be https and end in png, jpg, jpeg, or webp. Reject `A_` / `B_` / `C_` carousel filenames. See [tools/official_feed/README.md](../../../tools/official_feed/README.md).

There is no thumbnail generator in this repo. `thumbnailAsset` without a Storage object can 404.

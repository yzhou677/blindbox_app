---
name: catalog-image-qa
description: >-
  Optional art check for D:\blindbox-catalog assets. Prefer that repo's
  npm run qa:images. Use for a quick eye pass on missing stems, wrong stems,
  or obvious collage art — not as a publish gate.
---

# Catalog image QA

Optional. Prefer `npm run qa:images` from `D:\blindbox-catalog` (see that repo's README). Do not invent a pixel-grading script.

When you spot-check by eye:

- Stem equals `imageKey` / id under `assets/catalog/series/` or `assets/catalog/figures/`
- Missing required file → note it; fix before publish
- Prefer `.webp`; non-WebP is fine to note, not a publish blocker
- Series cover may be a collage; do not use the cover as a figure file
- Full marketing poster used as a **figure** file is bad; on-image title / logo / SECRET text on a single figure is fine

Do not upload from this skill. Do not require Failures/Warnings lists as a hard gate when `add-series-local` / `publish-series` already ran.

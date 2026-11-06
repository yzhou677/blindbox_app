---
name: publish-series
description: >-
  Uploads a local catalog series to production Storage and Firestore, then
  embeds the new figures. Use only after add-series-local, when the user says
  the D:\blindbox-catalog changes can go live. Stop before every write.
---

# Publish a series

> **WARNING:** A write here is production. Catalog documents are never deleted. A wrong write cannot be undone. Confirm every id, `imageKey`, and payload, then wait for the user to approve before any write.

Start only when `D:\blindbox-catalog` already has the `add-series-local` changes and the user has said they can go live.

New series and figure art must be `.webp` under `assets/catalog/series/` and `assets/catalog/figures/`. Run `catalog-image-qa` first. **Failures** block this publish. **Warnings** (`LOW_RES`, `NON_WEBP`, and any other warning codes in the guide) do not. Do not treat suggested long edge ≥ 1200px or on-image SECRET text as a publish blocker. Spec: [tools/seed/CATALOG_FIGURE_ART_REEXPORT_GUIDE.md](../../../tools/seed/CATALOG_FIGURE_ART_REEXPORT_GUIDE.md).

Scripts stay in that repo. Before you run `npm run upload:storage`, `npm run upload`, or any path such as `assets/catalog/`, read `D:\blindbox-catalog\package.json`, its README, and the script. If they disagree with this skill, stop. Then read the Usage comment at the top of the script, or run it with `--help`. Pass only flags printed there. Do not pass `--prune-remote`. That flag deletes remote objects that are missing locally.

## Order

1. From `D:\blindbox-catalog`, upload with `npm run upload:storage` (`scripts/upload_storage.js`). After a real upload the script also sets `imageVersion` to the Storage `md5Hash` and `updatedAt` on the matching series, figure, or `alternativeImages` entry. A hash skip does not write. If it wrote an `imageVersion`, it sets `meta/catalog.lastUpdatedAt`. Wait for approval before you run it.
2. Then `npm run upload` (`scripts/upload_firestore.js`). It writes a catalog doc only when the payload changed, sets `updatedAt`, and does not send `imageVersion`. If it wrote a catalog doc, it sets `meta/catalog.lastUpdatedAt`. `ip_profiles` does not bump `meta/catalog`. There is no separate meta command. Wait for approval before you run it.
3. Embed each new figure, including Secret figures. From this app's `functions/` directory, with `GOOGLE_CLOUD_PROJECT` and `FIREBASE_STORAGE_BUCKET` set (see [docs/FIGURE_RECOGNITION_M2.md](../../../docs/FIGURE_RECOGNITION_M2.md)):

```text
npm run embed:catalog-figures -- --figure-id <figureId>
```

One command per new `figureId`. The same command embeds that figure's `alternativeImages`. Do not pass an alternative `imageKey` as `--figure-id`. The script prints a plan and waits for `y`. Any other answer writes nothing. Do not run it with no `--figure-id`. Do not pass `--prune-stale-alternatives`. Wait for approval before the first figure, then run the rest of the approved ids.

4. Script logs are not the check. This repo has no read-only verify command for this publish. Do not invent a verify flag. Ask the user to open Firebase Console for project `blindbox-collection` and check the new series and figure docs, `imageVersion`, `updatedAt`, `meta/catalog.lastUpdatedAt`, and `catalogFigureEmbeddings/<figureId>` (plus each `…__alt__<imageKey>` the embed run created). List every `figureId` you passed to embed. If that Console check was not done, say "not verified".

---
name: publish-series
description: >-
  Uploads a local catalog series to production Storage and Firestore, then
  embeds the new figures. Use only after add-series-local, when the user says
  the D:\blindbox-catalog changes can go live. Stop before every write.
---

# Publish a series

> **WARNING:** A write here is production. Catalog documents are never deleted. A wrong write cannot be undone. Confirm every id, `imageKey`, and payload, then wait for the user to approve before any write.

Start only when `D:\blindbox-catalog` already has the `add-series-local` changes (`raw/` edited, normalize run, `data/` checked) and the user has said they can go live. Do not hand-edit `data/` here. `raw/` is the source of truth; see that catalog repo's `uploader.mdc` and README.

Prefer `.webp` under `assets/catalog/series/` and `assets/catalog/figures/`. `.png` / `.jpg` / `.jpeg` remain allowed. `.avif` is supported but not recommended. Run `catalog-image-qa` first. **Failures** block this publish. **Warnings** (`LOW_RES`, `NON_WEBP`, and any other warning codes in the guide) do not. Do not treat a soft “under 1200px” note, non-WebP format, or on-image SECRET text as a publish blocker. Spec: [tools/seed/CATALOG_FIGURE_ART_REEXPORT_GUIDE.md](../../../tools/seed/CATALOG_FIGURE_ART_REEXPORT_GUIDE.md).

Scripts stay in that repo. Before you run `npm run upload:storage`, `npm run upload`, or any path such as `assets/catalog/`, read `D:\blindbox-catalog\package.json`, its README, and the script. If they disagree with this skill, stop. Then read the Usage comment at the top of the script. Pass only flags printed there. Do not invent `--help` behavior. Do not pass `--prune-remote`. That flag deletes remote objects that are missing locally.

## Order

0. **Read-only Storage format check (before any upload).** For every `imageKey` you are about to publish (series cover and each figure, including confirmed `alternativeImages`), compare the local file extension under `assets/catalog/` with what already exists in production Storage under `catalog/series/` and `catalog/figures/`.

   This catalog repo and `functions/` have **no documented read-only command** that lists every remote extension for one `imageKey`. `upload_storage.js` can upload or prune; it is not a list tool. Do **not** invent `gsutil`, Admin SDK one-liners, or `--prune-remote` (including dry-run) for this step.

   Ask the user to open Firebase Console → Storage for project `blindbox-collection` and, for each stem, list every object that matches `catalog/series/<imageKey>.*` and `catalog/figures/<imageKey>.*`. Record those extensions next to the local extension.

   If any remote object uses a **different extension** than the local file for the same stem, **stop**. Show the table (imageKey, local ext, remote exts found). Wait for the user to say whether to delete the old remote object(s). This skill does **not** delete Storage objects and must not run `--prune-remote`.

1. From `D:\blindbox-catalog`, upload with `npm run upload:storage` (`scripts/upload_storage.js`). After a real upload the script also sets `imageVersion` to the Storage `md5Hash` and `updatedAt` on the matching series, figure, or `alternativeImages` entry. A hash skip does not write. If it wrote an `imageVersion`, it sets `meta/catalog.lastUpdatedAt`. Wait for approval before you run it.
2. Then `npm run upload` (`scripts/upload_firestore.js`). It writes a catalog doc only when the payload changed, sets `updatedAt`, and does not send `imageVersion`. If it wrote a catalog doc, it sets `meta/catalog.lastUpdatedAt`. `ip_profiles` does not bump `meta/catalog`. There is no separate meta command. Wait for approval before you run it.
3. Embed each new figure, including Secret figures. From this app's `functions/` directory, with `GOOGLE_CLOUD_PROJECT` and `FIREBASE_STORAGE_BUCKET` set (see [docs/FIGURE_RECOGNITION_M2.md](../../../docs/FIGURE_RECOGNITION_M2.md)):

```text
npm run embed:catalog-figures -- --figure-id <figureId>
```

One command per new `figureId`. The same command embeds that figure's `alternativeImages`. Do not pass an alternative `imageKey` as `--figure-id`. The script prints a plan and waits for `y`. Any other answer writes nothing. Do not run it with no `--figure-id`. Do not pass `--prune-stale-alternatives`. Wait for approval before the first figure, then run the rest of the approved ids.

**Embedding MIME types:** Official docs disagree on whether `gemini-embedding-2` accepts WebP/AVIF (Gemini API embeddings list PNG/JPEG only; some Vertex Embedding 2 pages list WebP/AVIF). Links are in [docs/FIGURE_RECOGNITION_M2.md](../../../docs/FIGURE_RECOGNITION_M2.md). If the Storage object you are about to embed is `.webp` or `.avif` (or any type other than PNG/JPEG), **stop and ask** the user whether to convert a temporary PNG/JPEG for the API call, try the stored bytes as-is, or skip. Do not convert, skip, or invent a workaround without approval.

4. Script logs are not the check. This repo has no read-only verify command for this publish. Do not invent a verify flag. Ask the user to open Firebase Console for project `blindbox-collection` and check:

- the new series and figure docs, `imageVersion`, `updatedAt`, `meta/catalog.lastUpdatedAt`
- `catalogFigureEmbeddings/<figureId>` (plus each `…__alt__<imageKey>` the embed run created)
- that each embedding doc's `imageObjectPath` is exactly the Storage object uploaded for that `imageKey` (same stem **and** extension / format)

List every `figureId` you passed to embed. If that Console check was not done, say "not verified".

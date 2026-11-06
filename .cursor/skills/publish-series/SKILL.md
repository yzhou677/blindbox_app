---
name: publish-series
description: >-
  Uploads a local catalog series to production Storage and Firestore, then
  embeds figures whose art was uploaded (and re-embeds when an embedding is
  missing or imageObjectPath does not match). Use only after add-series-local,
  when the user says the D:\blindbox-catalog changes can go live. Stop before
  every write.
---

# Publish a series

> **WARNING:** A write here is production. Catalog documents are never deleted. A wrong write cannot be undone. Confirm every id, `imageKey`, and payload, then wait for the user to approve before any write.

Start only when `D:\blindbox-catalog` already has the `add-series-local` changes and the user has said they can go live.

- **Metadata + art:** `raw/` was edited, normalize was run, and `data/` was checked.
- **Art only:** catalog art under `assets/catalog/` was replaced (and converted / QA'd). Do not require a `raw/` edit or normalize for that path. Do not hand-edit `data/` here.

`raw/` remains the source of truth when metadata changes; see that catalog repo's `uploader.mdc` and README.

Prefer `.webp` under `assets/catalog/series/` and `assets/catalog/figures/`. `.png` / `.jpg` / `.jpeg` remain allowed. `.avif` is supported but not recommended. Run `catalog-image-qa` first. **Failures** block this publish. **Warnings** (`LOW_RES`, `NON_WEBP`, and any other warning codes in the guide) do not. Do not treat a soft “under 1200px” note, non-WebP format, or on-image SECRET text as a publish blocker. Spec: [tools/seed/CATALOG_FIGURE_ART_REEXPORT_GUIDE.md](../../../tools/seed/CATALOG_FIGURE_ART_REEXPORT_GUIDE.md).

Scripts stay in that repo. Before you run `npm run upload:storage`, `npm run upload`, or any path such as `assets/catalog/`, read `D:\blindbox-catalog\package.json`, its README, and the script. If they disagree with this skill, stop. Then read the Usage comment at the top of the script. Pass only flags printed there. Do not invent `--help` behavior. Do not pass `--prune-remote`. That flag deletes remote objects that are missing locally.

## Order

0. **Read-only Storage format check (before any upload).** For every `imageKey` you are about to publish (series cover and each figure, including confirmed `alternativeImages`), compare the local file extension under `assets/catalog/` with what already exists in production Storage under `catalog/series/` and `catalog/figures/`.

   This catalog repo and `functions/` have **no documented read-only command** that lists every remote extension for one `imageKey`. `upload_storage.js` can upload or prune; it is not a list tool. Do **not** invent `gsutil`, Admin SDK one-liners, or `--prune-remote` (including dry-run) for this step.

   Ask the user to open Firebase Console → Storage for project `blindbox-collection` and, for each stem, list every object that matches `catalog/series/<imageKey>.*` and `catalog/figures/<imageKey>.*`. Record those extensions next to the local extension.

   If any remote object uses a **different extension** than the local file for the same stem, **stop**. Show the table (imageKey, local ext, remote exts found). Wait for the user to say whether to delete the old remote object(s). This skill does **not** delete Storage objects and must not run `--prune-remote`.

1. From `D:\blindbox-catalog`, upload with `npm run upload:storage` (`scripts/upload_storage.js`). After a real upload the script also sets `imageVersion` to the Storage `md5Hash` and `updatedAt` on the matching series, figure, or `alternativeImages` entry. A hash skip does not write. If it wrote an `imageVersion`, it sets `meta/catalog.lastUpdatedAt`. Wait for approval before you run it.
2. Then `npm run upload` (`scripts/upload_firestore.js`). It writes a catalog doc only when the payload changed, sets `updatedAt`, and does not send `imageVersion`. If it wrote a catalog doc, it sets `meta/catalog.lastUpdatedAt`. `ip_profiles` does not bump `meta/catalog`. There is no separate meta command. Wait for approval before you run it. For an **art-only** publish where Firestore catalog docs are unchanged, still wait for approval; if the user confirms there is nothing new to upload for docs, you may skip a no-op `upload` only when they say so.
3. **Embed figures that need embeddings.** Build the candidate list from two sources. Deduplicate by `figureId`. Do not invent a verify or list command for either source — use script logs for uploads, and ask the user for Firebase Console read-only checks where noted.

   **A. Real Storage uploads this run.** After `upload:storage`, collect every `imageKey` that received a **real** Storage upload (not a hash skip). Map those keys to `figureId`s:

   - A figure primary art upload → that figure's `figureId`
   - An `alternativeImages` upload → the parent figure's `figureId` (do not pass the alternative `imageKey` as `--figure-id`)
   - A series cover upload alone does **not** add a figure embed target

   Include Secret figures when their art uploaded. Include figures that already existed when their art was **replaced**.

   **B. Hash-skip exception (missing or stale embedding).** A hash skip alone is **not** enough to skip embedding. For figures in this publish scope whose art was **hash-skipped** (primary and confirmed `alternativeImages`), ask the user to open Firebase Console for project `blindbox-collection` and check `catalogFigureEmbeddings/<figureId>` (and each `…__alt__<imageKey>` that applies) against the current Storage object under `catalog/figures/<imageKey>.*`.

   Add that `figureId` to the embed list when the Console check shows either:

   - the embedding doc is **missing**, or
   - the embedding doc's `imageObjectPath` does **not** match the current Storage object for that `imageKey` (stem **and** extension / format)

   Do **not** invent `gsutil`, Admin SDK, Firestore query one-liners, or a verify flag for this check. List every hash-skipped figure that failed the check, with the reason (`missing` or `imageObjectPath` mismatch), and wait for confirmation with the upload-driven list.

   Figures outside this publish scope, and hash-skipped figures whose Console check shows a matching embedding, stay off the list.

   List every candidate `figureId` (and for each: uploaded `imageKey`s and/or hash-skip embedding reason) and wait for the user to confirm. Then embed from this app's `functions/` directory, with `GOOGLE_CLOUD_PROJECT` and `FIREBASE_STORAGE_BUCKET` set (see [docs/FIGURE_RECOGNITION_M2.md](../../../docs/FIGURE_RECOGNITION_M2.md)):

```text
npm run embed:catalog-figures -- --figure-id <figureId>
```

   One command per confirmed `figureId`. The same command embeds that figure's `alternativeImages`. Do not pass an alternative `imageKey` as `--figure-id`. The script prints a plan and waits for `y`. Any other answer writes nothing. Do not run it with no `--figure-id`. Do not pass `--prune-stale-alternatives`. Wait for approval before the first figure, then run the rest of the approved ids.

**Embedding MIME types:** This app embeds through Vertex (`vertexai: true`). Send stored catalog bytes as-is, including **WebP**, with no pre-conversion and no pre-flight format question. Details and source links: [docs/FIGURE_RECOGNITION_M2.md](../../../docs/FIGURE_RECOGNITION_M2.md). Only if the API returns a real format / MIME error: **stop**, show the user the raw error text, and wait. Do not invent a conversion path without approval.

4. Script logs are not the check. This repo has no read-only verify command for this publish. Do not invent a verify flag. Ask the user to open Firebase Console for project `blindbox-collection` and check:

- the series and figure docs touched by this publish, `imageVersion`, `updatedAt`, `meta/catalog.lastUpdatedAt`
- `catalogFigureEmbeddings/<figureId>` (plus each `…__alt__<imageKey>` the embed run created)
- that each embedding doc's `imageObjectPath` is exactly the current confirmed Storage object for that `imageKey` (same stem **and** extension / format)

List every `figureId` you passed to embed. If that Console check was not done, say "not verified".

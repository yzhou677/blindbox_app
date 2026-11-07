---
name: publish-series
description: >-
  Uploads a local catalog series to production Storage and Firestore, then
  embeds figures whose art actually uploaded. Re-embed only when a prior
  embed failed or the user asks. Use only after add-series-local, when the
  user says the D:\blindbox-catalog changes can go live.
---

# Publish a series

> **WARNING:** A write here is production. Catalog documents are never deleted. A wrong write cannot be undone.

Start only when `D:\blindbox-catalog` already has the `add-series-local` changes and the user has said they can go live.

- **Metadata + art:** `raw/` was edited and normalize was run.
- **Art only:** catalog art under `assets/catalog/` was replaced. Do not require a `raw/` edit or normalize. Do not hand-edit `data/` here.

`D:\blindbox-catalog` is **not** a git repo. Do not run git reports there.

Prefer `.webp` under `assets/catalog/series/` and `assets/catalog/figures/`. `.png` / `.jpg` / `.jpeg` remain allowed. `.avif` is supported but not recommended.

Catalog scripts and flags live in that repo (`package.json`, README, script Usage). Prefer those over inventing flags. Do not pass `--prune-remote` (it deletes remote objects missing locally).

## One approval, then run

Show one plan and wait **once**:

- series id / figure ids / `imageKey`s to upload
- Storage command (`npm run upload:storage`, with `--prefix` when scoped)
- Firestore command (`npm run upload`)
- embed candidate `figureId`s (see below)

After the user approves that plan, run Storage → Firestore → embeds without further confirmation. Do not stop between those steps. Do not ask again per figure.

For an **art-only** publish where Firestore docs are unchanged, still include `upload` in the plan unless the user already said to skip the no-op docs upload.

## Order (after approval)

1. `npm run upload:storage` from `D:\blindbox-catalog` (`scripts/upload_storage.js`). A real upload sets `imageVersion` (Storage `md5Hash`) and `updatedAt` on the matching series/figure/`alternativeImages` entry; a hash skip does not. If any `imageVersion` was written, the script sets `meta/catalog.lastUpdatedAt`.

   If Firestore docs did not exist yet during Storage (new series), `imageVersion` may miss. After `upload`, run Storage again with `--force` and the same prefix so `imageVersion` is written. Do not ask again for that follow-up when it is part of the approved publish.

2. `npm run upload` (`scripts/upload_firestore.js`). Writes a catalog doc only when the payload changed; sets `updatedAt`; does not send `imageVersion`. If it wrote a catalog doc, it sets `meta/catalog.lastUpdatedAt`.

3. **Embed** figures that need embeddings. Default list = figures whose art received a **real** Storage upload this run (not a hash skip). Deduplicate by `figureId`:

   - figure primary art → that `figureId`
   - `alternativeImages` upload → parent figure's `figureId` (never pass the alt `imageKey` as `--figure-id`)
   - series cover alone → no embed target

   Include Secrets when their art uploaded. Include replaced-art figures. Add extra ids only when a prior embed in this publish failed, or the user asked to re-run specific ids.

   From this app's `functions/` directory, with `GOOGLE_CLOUD_PROJECT` and `FIREBASE_STORAGE_BUCKET` set (see [docs/FIGURE_RECOGNITION_M2.md](../../../docs/FIGURE_RECOGNITION_M2.md)):

```text
npm run embed:catalog-figures -- --figure-id <figureId>
```

   One command per approved `figureId`. The script prints a plan and waits for `y` — **pipe `y` yourself**; do not ask the user per figure. Do not run with no `--figure-id`. Do not pass `--prune-stale-alternatives`.

   Send stored catalog bytes as-is on Vertex (`vertexai: true`), including **WebP**. No pre-conversion. No pre-flight format question. Only if the API returns a real format / MIME error: **stop**, show the raw error text, and wait. Do not invent a conversion path without approval.

4. Summarize from script logs (uploaded keys, docs written, embed ok/fail counts). Do **not** ask the user to open Firebase Console. Do not invent a verify command.

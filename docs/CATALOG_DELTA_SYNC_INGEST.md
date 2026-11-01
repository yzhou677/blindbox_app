# Catalog delta sync — ingest & backfill (external repo)

**Audience:** maintainers of `D:\blindbox-catalog` (Admin SDK upload scripts).  
**App contract:** [`lib/features/catalog/firestore/FIRESTORE_CATALOG_SCHEMA.md`](../lib/features/catalog/firestore/FIRESTORE_CATALOG_SCHEMA.md).  
**This PR (PR2a):** schema + rules + this guide + a backfill script template.  
**Not in this PR:** Flutter incremental client (PR2b), image disk-cache busting (PR2c).

## Goals

1. Every catalog entity doc can carry `updatedAt` (Timestamp).
2. Series/figures (and each `alternativeImages[]` entry) can carry `imageVersion`
   = Firebase Storage object **`md5Hash`** (base64 string as returned by GCS).
3. `meta/catalog.lastUpdatedAt` is bumped when an ingest/backfill round actually
   changed something.
4. **Never delete** catalog documents (discontinued products stay forever).
5. **Additive only** — old apps that ignore these fields keep working.

## Non-goals

- No soft-delete / `deleted` / tombstones.
- No Storage Cloud Function in v1 (ingest scripts own the writes).
- No rewriting `imageKey` or Storage folder layout.
- No storing download URLs on Firestore docs.

---

## A) `scripts/upload_storage.js`

After a **real upload** (not `[skip_unchanged]`), read the uploaded object’s
metadata and write Firestore:

1. `const [meta] = await file.getMetadata()` → use `meta.md5Hash` (required).
2. Map Storage path → Firestore doc:
   - `catalog/series/<stem>.<ext>` → `series/<stem>` field `imageVersion`
   - `catalog/figures/<stem>.<ext>` → usually `figures/<stem>` primary
     `imageVersion`, **or** the matching `alternativeImages[]` entry whose
     `imageKey === stem` (set that entry’s `imageVersion`)
3. Also set that document’s `updatedAt = FieldValue.serverTimestamp()` (or
   `Timestamp.now()`).
4. Mark the ingest round as dirty so step C can bump `meta/catalog`.

**Skip path:** if the script skips because hash already matches, do **not** bump
`updatedAt` / `meta` unless you are fixing missing `imageVersion` (backfill
script covers that).

**Suggested helper sketch:**

```js
async function writeImageVersionAfterUpload(db, storagePath, md5Hash) {
  // storagePath e.g. catalog/figures/foo.webp
  const parts = storagePath.split("/");
  const kind = parts[1]; // series | figures
  const stem = path.parse(parts[2]).name;
  const now = admin.firestore.FieldValue.serverTimestamp();

  if (kind === "series") {
    await db.collection("series").doc(stem).set(
      { imageVersion: md5Hash, updatedAt: now },
      { merge: true },
    );
    return;
  }

  // figures: primary doc id often === imageKey; else patch alternativeImages
  const figRef = db.collection("figures").doc(stem);
  const snap = await figRef.get();
  if (snap.exists) {
    await figRef.set(
      { imageVersion: md5Hash, updatedAt: now },
      { merge: true },
    );
    return;
  }

  // Find figure whose alternativeImages[].imageKey === stem (or primary imageKey)
  // and merge imageVersion onto that array element + updatedAt on the parent.
}
```

Wire this only on the success path of `uploadOne` (after `bucket.upload`).

---

## B) `scripts/upload_firestore.js`

When writing `brands` / `ips` / `series` / `figures`:

1. Load existing Firestore doc (if any) before `set(merge: true)`.
2. Compare **payload fields that matter** (ignore `updatedAt` / `imageVersion`
   when comparing, unless this pass is intentionally setting them).
3. If equal → **skip write** (or write nothing). Do not bump `updatedAt`.
4. If different → `set(merge: true)` with payload + `updatedAt: serverTimestamp()`.
5. Preserve existing `imageVersion` on series/figures unless Storage upload
   already updated it in the same pipeline run.
6. Track whether any doc was written → step C.

`ip_profiles` is editorial, not part of the catalog bundle sync cursor. Optionally
leave it out of `meta/catalog` bumps unless you deliberately want profile edits
to wake catalog clients (default: **do not**).

**Equality tip:** canonicalize JSON (sorted keys, stable array order) or
field-wise compare known schema keys from
`FIRESTORE_CATALOG_SCHEMA.md`.

---

## C) End of ingest round → `meta/catalog`

If **any** catalog entity write happened in this round (Storage-driven
`imageVersion` updates and/or Firestore payload updates):

```js
await db.collection("meta").doc("catalog").set(
  { lastUpdatedAt: admin.firestore.FieldValue.serverTimestamp() },
  { merge: true },
);
```

If the round was a complete no-op, **do not** touch `meta/catalog`.

---

## D) One-time backfill (no re-upload)

Use the template in this app repo:

[`tools/catalog/backfill_catalog_sync_fields.mjs`](../tools/catalog/backfill_catalog_sync_fields.mjs)

Or copy it into `D:\blindbox-catalog\scripts\` and point `SERVICE_ACCOUNT_PATH`
at that repo’s `service-account.json`.

**Behavior:**

1. List Storage under `catalog/series/**` and `catalog/figures/**`.
2. For each object with `md5Hash`, merge `imageVersion` onto the matching
   series/figure (or `alternativeImages[]` entry).
3. For every `brands` / `ips` / `series` / `figures` document missing
   `updatedAt`, set `updatedAt` to `serverTimestamp()` (or object `updated`
   time when available).
4. Set `meta/catalog.lastUpdatedAt` once at the end.

Dry-run flag should print planned writes without mutating.

---

## Deploy order (safe for old apps)

1. Deploy **`firestore.rules`** from this app repo (allows public read of
   `meta/catalog`).
2. Run **backfill** (fields appear; old apps ignore them).
3. Ship updated **`upload_storage.js` / `upload_firestore.js`** in
   `blindbox-catalog`.
4. Then ship Flutter PR2b / PR2c.

Until step 4, production behavior stays “full collection get + 5 min TTL”.

## Manual checklist for you

- [ ] Deploy updated `firestore.rules` to project `blindbox-collection`
- [ ] Copy/adapt backfill script; run `--dry-run`, then live once
- [ ] Patch `upload_storage.js` / `upload_firestore.js` per A–C
- [ ] Verify one series image overwrite updates `imageVersion`, `updatedAt`, and
      `meta/catalog.lastUpdatedAt` in console

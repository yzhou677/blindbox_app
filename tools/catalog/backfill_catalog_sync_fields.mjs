#!/usr/bin/env node
/**
 * One-time backfill for catalog delta-sync fields (PR2a).
 *
 * - Reads Storage md5Hash for catalog/series/* and catalog/figures/*
 * - Writes imageVersion onto matching series/figures (or alternativeImages[])
 * - Ensures every brands/ips/series/figures doc has updatedAt
 * - Creates/updates meta/catalog.lastUpdatedAt
 *
 * Does NOT re-upload images. Does NOT delete catalog docs.
 *
 * Usage (from repo root or after copying into D:\\blindbox-catalog\\scripts):
 *   node tools/catalog/backfill_catalog_sync_fields.mjs --dry-run
 *   node tools/catalog/backfill_catalog_sync_fields.mjs
 *   node tools/catalog/backfill_catalog_sync_fields.mjs --service-account path/to/sa.json
 *   node tools/catalog/backfill_catalog_sync_fields.mjs --bucket my.appspot.com
 *
 * Prefer running with the catalog ingest service account (Admin SDK).
 */
import { createRequire } from 'node:module';
import { existsSync, readFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const require = createRequire(import.meta.url);
const __dirname = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(__dirname, '../..');

function parseArgs(argv) {
  /** @type {{ dryRun: boolean, serviceAccount: string | null, bucket: string | null }} */
  const opts = { dryRun: false, serviceAccount: null, bucket: null };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--dry-run') opts.dryRun = true;
    else if (a === '--service-account') opts.serviceAccount = argv[++i] ?? null;
    else if (a === '--bucket') opts.bucket = argv[++i] ?? null;
    else if (a === '--help' || a === '-h') {
      console.log(`Usage:
  node tools/catalog/backfill_catalog_sync_fields.mjs [--dry-run]
      [--service-account <path>] [--bucket <name>]`);
      process.exit(0);
    } else if (a.startsWith('-')) {
      console.error(`Unknown flag: ${a}`);
      process.exit(1);
    }
  }
  return opts;
}

function resolveServiceAccountPath(explicit) {
  const candidates = [
    explicit,
    process.env.GOOGLE_APPLICATION_CREDENTIALS,
    path.join(REPO_ROOT, 'service-account.json'),
    path.join('D:', 'blindbox-catalog', 'service-account.json'),
  ].filter(Boolean);
  for (const p of candidates) {
    if (p && existsSync(p)) return p;
  }
  throw new Error(
    'No service-account.json found. Pass --service-account or set GOOGLE_APPLICATION_CREDENTIALS.',
  );
}

function stemFromObjectName(name) {
  // catalog/figures/foo.webp → foo
  const base = name.split('/').pop() ?? name;
  const dot = base.lastIndexOf('.');
  return dot > 0 ? base.slice(0, dot) : base;
}

/**
 * @param {import('firebase-admin')} admin
 * @param {FirebaseFirestore.Firestore} db
 * @param {string} kind series|figures
 * @param {string} stem
 * @param {string} md5Hash
 * @param {boolean} dryRun
 */
async function applyImageVersion(admin, db, kind, stem, md5Hash, dryRun) {
  const now = admin.firestore.FieldValue.serverTimestamp();

  if (kind === 'series') {
    const ref = db.collection('series').doc(stem);
    const snap = await ref.get();
    if (!snap.exists) {
      console.warn(`[miss] series/${stem} (storage stem has no doc)`);
      return false;
    }
    const cur = snap.get('imageVersion');
    if (cur === md5Hash && snap.get('updatedAt') != null) {
      return false;
    }
    console.log(
      `[series] ${stem} imageVersion ${cur ?? '(none)'} → ${md5Hash}`,
    );
    if (!dryRun) {
      await ref.set({ imageVersion: md5Hash, updatedAt: now }, { merge: true });
    }
    return true;
  }

  // figures: prefer doc id === stem; else scan for alternativeImages.imageKey
  const primaryRef = db.collection('figures').doc(stem);
  const primarySnap = await primaryRef.get();
  if (primarySnap.exists) {
    const data = primarySnap.data() ?? {};
    const primaryKey = String(data.imageKey ?? stem);
    if (primaryKey === stem) {
      const cur = data.imageVersion;
      if (cur === md5Hash && data.updatedAt != null) return false;
      console.log(
        `[figures] ${stem} primary imageVersion ${cur ?? '(none)'} → ${md5Hash}`,
      );
      if (!dryRun) {
        await primaryRef.set(
          { imageVersion: md5Hash, updatedAt: now },
          { merge: true },
        );
      }
      return true;
    }
  }

  // Slow path: find figure with alternativeImages entry (or primary imageKey)
  const figures = await db.collection('figures').get();
  for (const doc of figures.docs) {
    const data = doc.data() ?? {};
    if (String(data.imageKey ?? '') === stem) {
      const cur = data.imageVersion;
      if (cur === md5Hash && data.updatedAt != null) return false;
      console.log(
        `[figures] ${doc.id} primary(imageKey=${stem}) imageVersion → ${md5Hash}`,
      );
      if (!dryRun) {
        await doc.ref.set(
          { imageVersion: md5Hash, updatedAt: now },
          { merge: true },
        );
      }
      return true;
    }
    const alts = Array.isArray(data.alternativeImages)
      ? data.alternativeImages
      : [];
    let changed = false;
    const nextAlts = alts.map((row) => {
      if (!row || typeof row !== 'object') return row;
      if (String(row.imageKey ?? '') !== stem) return row;
      if (row.imageVersion === md5Hash) return row;
      changed = true;
      return { ...row, imageVersion: md5Hash };
    });
    if (!changed) continue;
    console.log(
      `[figures] ${doc.id} alternativeImages[${stem}] imageVersion → ${md5Hash}`,
    );
    if (!dryRun) {
      await doc.ref.set(
        { alternativeImages: nextAlts, updatedAt: now },
        { merge: true },
      );
    }
    return true;
  }

  console.warn(`[miss] figures imageKey/stem=${stem} (no matching doc)`);
  return false;
}

/**
 * @param {import('firebase-admin')} admin
 * @param {FirebaseFirestore.Firestore} db
 * @param {string} collection
 * @param {boolean} dryRun
 */
async function ensureUpdatedAt(admin, db, collection, dryRun) {
  const now = admin.firestore.FieldValue.serverTimestamp();
  const snap = await db.collection(collection).get();
  let patched = 0;
  for (const doc of snap.docs) {
    if (doc.get('updatedAt') != null) continue;
    console.log(`[${collection}] ${doc.id} set updatedAt`);
    if (!dryRun) {
      await doc.ref.set({ updatedAt: now }, { merge: true });
    }
    patched += 1;
  }
  return patched;
}

async function main() {
  const opts = parseArgs(process.argv.slice(2));
  let admin;
  try {
    admin = require('firebase-admin');
  } catch {
    console.error(
      'firebase-admin is not installed in this repo.\n' +
        'Run from D:\\blindbox-catalog (has firebase-admin), or:\n' +
        '  npm install firebase-admin --no-save\n' +
        'in a temp dir / copy this script into blindbox-catalog/scripts/.',
    );
    process.exit(1);
  }

  const saPath = resolveServiceAccountPath(opts.serviceAccount);
  const sa = JSON.parse(readFileSync(saPath, 'utf8'));
  const projectId = sa.project_id;
  if (!projectId) throw new Error('service account missing project_id');

  if (admin.apps.length === 0) {
    admin.initializeApp({
      credential: admin.credential.cert(sa),
      storageBucket:
        opts.bucket ||
        sa.storageBucket ||
        `${projectId}.firebasestorage.app`,
    });
  }

  const db = admin.firestore();
  const bucket = admin.storage().bucket(opts.bucket || undefined);

  console.log(`Project: ${projectId}`);
  console.log(`Bucket:  ${bucket.name}`);
  console.log(`Mode:    ${opts.dryRun ? 'dry-run' : 'LIVE WRITE'}`);

  let imageWrites = 0;
  for (const prefix of ['catalog/series/', 'catalog/figures/']) {
    const kind = prefix.includes('/series/') ? 'series' : 'figures';
    const [files] = await bucket.getFiles({ prefix });
    console.log(`\nStorage ${prefix}: ${files.length} objects`);
    for (const file of files) {
      if (file.name.endsWith('/')) continue;
      const [metadata] = await file.getMetadata();
      const md5 = metadata.md5Hash;
      if (!md5) {
        console.warn(`[no-md5] ${file.name}`);
        continue;
      }
      const stem = stemFromObjectName(file.name);
      const changed = await applyImageVersion(
        admin,
        db,
        kind,
        stem,
        md5,
        opts.dryRun,
      );
      if (changed) imageWrites += 1;
    }
  }

  console.log('\nEnsuring updatedAt on entity collections...');
  let updatedAtWrites = 0;
  for (const col of ['brands', 'ips', 'series', 'figures']) {
    updatedAtWrites += await ensureUpdatedAt(admin, db, col, opts.dryRun);
  }

  const dirty = imageWrites + updatedAtWrites > 0;
  if (dirty) {
    console.log(
      `\nmeta/catalog lastUpdatedAt (${opts.dryRun ? 'would set' : 'set'})`,
    );
    if (!opts.dryRun) {
      await db
        .collection('meta')
        .doc('catalog')
        .set(
          {
            lastUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true },
        );
    }
  } else {
    console.log('\nNo field changes; leaving meta/catalog untouched.');
  }

  console.log('\n--- Summary ---');
  console.log(`imageVersion writes: ${imageWrites}`);
  console.log(`updatedAt backfills: ${updatedAtWrites}`);
  console.log(opts.dryRun ? 'Dry-run complete.' : 'Backfill complete.');
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});

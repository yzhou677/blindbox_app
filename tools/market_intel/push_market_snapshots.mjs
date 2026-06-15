#!/usr/bin/env node
/**
 * Market Intelligence — production Firestore snapshot writer.
 *
 * Reads SnapshotDocuments (in-memory or from a JSON file) and writes
 * conforming documents to `market_snapshots` in Firestore.
 *
 * Export:
 *   buildFirestoreDocument(snapshot) — pure mapping; returns null when skipped
 *   pushSnapshotsToFirestore(snapshots, options) — batch write via Admin SDK
 *
 * CLI usage (from repo root):
 *   node tools/market_intel/push_market_snapshots.mjs --input path/to/snapshots.json
 *   node tools/market_intel/push_market_snapshots.mjs --input path/to/snapshots.json --dry-run
 *
 * Auth: Firebase CLI login or ADC (same as push_market_snapshots_dev.mjs).
 *
 * Schema reference:
 *   lib/features/market_intel/data/firestore/FIRESTORE_MARKET_SNAPSHOTS_SCHEMA.md
 */

import { readFileSync, mkdtempSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createRequire } from 'node:module';

const __dirname = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(__dirname, '../..');

const COLLECTION = 'market_snapshots';

// ---------------------------------------------------------------------------
// Pure mapping — exported for tests; no Admin SDK dependency
// ---------------------------------------------------------------------------

/**
 * @typedef {import('./_snapshot_document.mjs').SnapshotDocument} SnapshotDocument
 */

/**
 * @typedef {Object} FirestoreSnapshotDoc
 * @property {string} docId
 * @property {Object} fields
 */

/**
 * Maps a SnapshotDocument to the Firestore document shape expected by the
 * Flutter client (FirestoreMarketSnapshotMapper).
 *
 * Returns null when the document should be skipped:
 *   - medianPrice is null
 *   - medianPrice is <= 0
 *
 * trend is always "unknown" for MVP — historical comparison is deferred
 * until at least two production snapshots exist.
 *
 * computedAt is intentionally left as the ISO string from the snapshot; the
 * caller (pushSnapshotsToFirestore) replaces it with serverTimestamp() before
 * writing to Firestore. This keeps the mapping pure and testable.
 *
 * @param {SnapshotDocument} snapshot
 * @returns {FirestoreSnapshotDoc | null}
 */
export function buildFirestoreDocument(snapshot) {
  if (snapshot.medianPrice == null || snapshot.medianPrice <= 0) {
    return null;
  }

  if (!snapshot.seriesId) {
    return null;
  }

  /** @type {Record<string, unknown>} */
  const fields = {
    level: 'figure',
    figureId: snapshot.figureId,
    seriesId: snapshot.seriesId,
    estimatedValueUsd: snapshot.medianPrice,
    trend: 'unknown',
    confidence: snapshot.confidence,
    recentSalesCount: snapshot.sampleSize,
    computedAt: snapshot.snapshotAt,  // replaced with serverTimestamp() on write
  };

  if (snapshot.minPrice != null) {
    fields.priceRangeMinUsd = snapshot.minPrice;
  }

  if (snapshot.maxPrice != null) {
    fields.priceRangeMaxUsd = snapshot.maxPrice;
  }

  return { docId: snapshot.figureId, fields };
}

// ---------------------------------------------------------------------------
// Admin SDK write — requires Firebase auth
// ---------------------------------------------------------------------------

const require = createRequire(join(repoRoot, 'functions/package.json'));

function resolveProjectId() {
  const fromEnv =
    process.env.FIREBASE_PROJECT_ID?.trim() ||
    process.env.GCLOUD_PROJECT?.trim() ||
    process.env.GOOGLE_CLOUD_PROJECT?.trim();
  if (fromEnv) return fromEnv;

  try {
    const rcPath = join(repoRoot, '.firebaserc');
    const rc = JSON.parse(readFileSync(rcPath, 'utf8'));
    const id = rc?.projects?.default?.trim();
    if (id) return id;
  } catch (_) {
    // fall through
  }

  return null;
}

const FIREBASE_CLI_CLIENT_ID =
  '563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com';
const FIREBASE_CLI_CLIENT_SECRET = 'j9iVZfS8kkCEFUPaAeJV0sAi';

function firebaseToolsConfigCandidates() {
  const candidates = [];
  const home = process.env.HOME || process.env.USERPROFILE;
  if (home) {
    candidates.push(join(home, '.config', 'configstore', 'firebase-tools.json'));
  }
  if (process.env.APPDATA) {
    candidates.push(join(process.env.APPDATA, 'configstore', 'firebase-tools.json'));
  }
  return candidates;
}

function loadFirebaseCliRefreshToken() {
  for (const configPath of firebaseToolsConfigCandidates()) {
    try {
      const cfg = JSON.parse(readFileSync(configPath, 'utf8'));
      const token = cfg?.tokens?.refresh_token?.trim();
      if (token) return token;
    } catch (_) {
      // try next path
    }
  }
  return null;
}

let _adminInitialized = false;

function initAdmin() {
  if (_adminInitialized) return;
  _adminInitialized = true;

  const admin = require('firebase-admin');
  if (admin.apps.length > 0) return;

  const projectId = resolveProjectId();
  if (!projectId) {
    throw new Error(
      'Could not resolve Firebase project id.\n' +
        'Set FIREBASE_PROJECT_ID or run: firebase use <project>',
    );
  }

  if (!process.env.GOOGLE_APPLICATION_CREDENTIALS) {
    const refreshToken = loadFirebaseCliRefreshToken();
    if (refreshToken) {
      const dir = mkdtempSync(join(tmpdir(), 'firebase-adc-'));
      const adcPath = join(dir, 'application_default_credentials.json');
      writeFileSync(
        adcPath,
        JSON.stringify({
          type: 'authorized_user',
          client_id: FIREBASE_CLI_CLIENT_ID,
          client_secret: FIREBASE_CLI_CLIENT_SECRET,
          refresh_token: refreshToken,
        }),
      );
      process.env.GOOGLE_APPLICATION_CREDENTIALS = adcPath;
    }
  }

  const authNote = process.env.GOOGLE_APPLICATION_CREDENTIALS?.includes('firebase-adc-')
    ? 'Firebase CLI credentials'
    : process.env.GOOGLE_APPLICATION_CREDENTIALS
      ? 'GOOGLE_APPLICATION_CREDENTIALS'
      : 'application default credentials';
  console.log(`Using Firebase project: ${projectId} (${authNote})`);
  admin.initializeApp({ projectId });
}

/**
 * @typedef {Object} PushOptions
 * @property {boolean} [dryRun]
 */

/**
 * Writes snapshot documents to Firestore in batches of 500 (Firestore limit).
 *
 * Each document is written with set() (no merge) to ensure stale fields from
 * prior matcher versions do not persist. computedAt is set by serverTimestamp().
 *
 * @param {SnapshotDocument[]} snapshots
 * @param {PushOptions} [options]
 * @returns {Promise<{ written: number, skipped: number, failed: number }>}
 */
export async function pushSnapshotsToFirestore(snapshots, options = {}) {
  const { dryRun = false } = options;

  const admin = require('firebase-admin');
  initAdmin();

  const db = admin.firestore();

  let written = 0;
  let skipped = 0;
  let failed = 0;

  /** @type {FirestoreSnapshotDoc[]} */
  const docs = [];

  for (const snapshot of snapshots) {
    const mapped = buildFirestoreDocument(snapshot);
    if (mapped == null) {
      const reason =
        snapshot.medianPrice == null
          ? 'medianPrice null'
          : !snapshot.seriesId
            ? 'seriesId missing'
            : `medianPrice <= 0 (${snapshot.medianPrice})`;
      console.log(`SKIP ${snapshot.figureId}: ${reason}`);
      skipped += 1;
      continue;
    }
    docs.push(mapped);
  }

  if (dryRun) {
    console.log('');
    console.log(`DRY RUN — would write ${docs.length} document(s), skip ${skipped}`);
    for (const { docId, fields } of docs) {
      console.log('');
      console.log(`  ${COLLECTION}/${docId}`);
      console.log(JSON.stringify({ ...fields, computedAt: '<serverTimestamp()>' }, null, 4)
        .split('\n').map((line) => `    ${line}`).join('\n'));
    }
    return { written: 0, skipped, failed };
  }

  // Write in batches of 500 (Firestore max per batch)
  const BATCH_SIZE = 500;
  for (let start = 0; start < docs.length; start += BATCH_SIZE) {
    const slice = docs.slice(start, start + BATCH_SIZE);
    const batch = db.batch();

    for (const { docId, fields } of slice) {
      const ref = db.collection(COLLECTION).doc(docId);
      batch.set(ref, {
        ...fields,
        computedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      console.log(`Queued ${COLLECTION}/${docId}`);
    }

    try {
      await batch.commit();
      written += slice.length;
    } catch (err) {
      console.error(`Batch commit failed (start=${start}): ${err.message}`);
      failed += slice.length;
    }
  }

  console.log('');
  console.log(
    `Wrote ${written} document(s) to ${COLLECTION}` +
      (skipped > 0 ? ` (${skipped} skipped)` : '') +
      (failed > 0 ? ` (${failed} FAILED)` : ''),
  );

  return { written, skipped, failed };
}

// ---------------------------------------------------------------------------
// CLI entrypoint
// ---------------------------------------------------------------------------

async function main() {
  const args = process.argv.slice(2);

  let inputPath = null;
  let dryRun = false;

  for (let i = 0; i < args.length; i += 1) {
    if (args[i] === '--input') {
      inputPath = args[i + 1]?.trim();
      if (!inputPath) {
        console.error('Expected a path after --input');
        process.exit(1);
      }
      i += 1;
      continue;
    }

    if (args[i] === '--dry-run') {
      dryRun = true;
      continue;
    }

    console.error(`Unknown argument: ${args[i]}`);
    process.exit(1);
  }

  if (!inputPath) {
    console.error(
      'Usage: node push_market_snapshots.mjs --input <path/to/snapshots.json> [--dry-run]',
    );
    process.exit(1);
  }

  const raw = readFileSync(resolve(inputPath), 'utf8');
  const parsed = JSON.parse(raw);

  const snapshots = Array.isArray(parsed)
    ? parsed
    : (parsed.snapshots ?? []);

  if (!Array.isArray(snapshots) || snapshots.length === 0) {
    console.error('No snapshots found in input file.');
    process.exit(1);
  }

  console.log(`Loaded ${snapshots.length} snapshot(s) from ${inputPath}`);

  const result = await pushSnapshotsToFirestore(snapshots, { dryRun });
  if (result.failed > 0) process.exit(1);
}

// Run only when executed directly (not when imported as a module)
if (process.argv[1] && resolve(process.argv[1]) === resolve(fileURLToPath(import.meta.url))) {
  main().catch((err) => {
    console.error(err);
    process.exit(1);
  });
}

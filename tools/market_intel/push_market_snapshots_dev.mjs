#!/usr/bin/env node
/**
 * DEV ONLY — Push mock market snapshot documents to Firestore.
 *
 * Usage (from repo root):
 *   node tools/market_intel/push_market_snapshots_dev.mjs
 *   node tools/market_intel/push_market_snapshots_dev.mjs tools/market_intel/market_snapshots_dev.seed.json
 *
 * Auth: same as tools/official_feed/push_official_feed.mjs (Firebase CLI login or ADC).
 */

import { readFileSync, mkdtempSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createRequire } from 'node:module';

const __dirname = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(__dirname, '../..');
const require = createRequire(join(repoRoot, 'functions/package.json'));
const admin = require('firebase-admin');

const COLLECTION = 'market_snapshots';

function loadSeed(path) {
  const raw = readFileSync(path, 'utf8');
  return JSON.parse(raw);
}

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

/** Firebase CLI OAuth (public; same as firebase-tools). */
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

function initAdmin() {
  if (admin.apps.length > 0) return;

  const projectId = resolveProjectId();
  if (!projectId) {
    console.error(
      'Could not resolve Firebase project id.\n' +
        'Set FIREBASE_PROJECT_ID or run: firebase use <project>',
    );
    process.exit(1);
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

function buildDoc(snapshot) {
  const id = snapshot.id?.trim();
  const level = snapshot.level?.trim();
  const seriesId = snapshot.seriesId?.trim();

  if (!id || !level || !seriesId) {
    throw new Error(`Invalid snapshot (missing id/level/seriesId): ${JSON.stringify(snapshot)}`);
  }

  const estimatedValueUsd = Number(snapshot.estimatedValueUsd);
  const recentSalesCount = Number(snapshot.recentSalesCount);
  const confidence = snapshot.confidence?.trim();
  const trend = snapshot.trend?.trim() ?? 'unknown';

  if (!Number.isFinite(estimatedValueUsd) || estimatedValueUsd <= 0) {
    throw new Error(`Invalid estimatedValueUsd for ${id}`);
  }
  if (!Number.isFinite(recentSalesCount) || recentSalesCount < 0) {
    throw new Error(`Invalid recentSalesCount for ${id}`);
  }
  if (confidence !== 'high' && confidence !== 'low') {
    throw new Error(`Invalid confidence for ${id}: ${confidence}`);
  }

  const doc = {
    level,
    seriesId,
    estimatedValueUsd,
    trend,
    confidence,
    recentSalesCount,
    computedAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  if (level === 'figure') {
    const figureId = snapshot.figureId?.trim() || id;
    doc.figureId = figureId;
  }

  const min = snapshot.priceRangeMinUsd;
  const max = snapshot.priceRangeMaxUsd;
  if (min != null) doc.priceRangeMinUsd = Number(min);
  if (max != null) doc.priceRangeMaxUsd = Number(max);

  return { id, doc };
}

async function main() {
  const seedPath = resolve(
    process.argv[2] ?? join(__dirname, 'market_snapshots_dev.seed.json'),
  );
  const seed = loadSeed(seedPath);
  const snapshots = seed.snapshots ?? [];

  if (!Array.isArray(snapshots) || snapshots.length === 0) {
    console.error('No snapshots in seed file.');
    process.exit(1);
  }

  initAdmin();
  const db = admin.firestore();
  const batch = db.batch();

  for (const snapshot of snapshots) {
    const { id, doc } = buildDoc(snapshot);
    batch.set(db.collection(COLLECTION).doc(id), doc, { merge: true });
    console.log(`Queued ${COLLECTION}/${id} (${doc.level})`);
  }

  await batch.commit();
  console.log(`Wrote ${snapshots.length} DEV snapshot document(s) to ${COLLECTION}.`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});

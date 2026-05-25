#!/usr/bin/env node
/**
 * Push curated official feed items to Firestore.
 *
 * Usage (from repo root):
 *   node tools/official_feed/push_official_feed.mjs
 *   node tools/official_feed/push_official_feed.mjs tools/official_feed/popmart_us.seed.json
 *
 * Auth (first match):
 *   - GOOGLE_APPLICATION_CREDENTIALS / gcloud ADC
 *   - Firebase CLI login (`firebase login`) via configstore refresh token
 *
 * Project id: .firebaserc default, or FIREBASE_PROJECT_ID / GCLOUD_PROJECT env.
 *
 * Requires: `cd functions && npm install` once (firebase-admin).
 */

import { createHash } from 'node:crypto';
import { mkdtempSync, readFileSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createRequire } from 'node:module';
import { validateOfficialFeedSeed } from './seed_validation.mjs';

const __dirname = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(__dirname, '../..');
const require = createRequire(join(repoRoot, 'functions/package.json'));
const admin = require('firebase-admin');

const COLLECTION = 'official_feed_items';

function contentHash(sourceId, officialUrl) {
  return createHash('sha256')
    .update(`${sourceId}|${officialUrl}`)
    .digest('hex')
    .slice(0, 24);
}

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
        'Set FIREBASE_PROJECT_ID (this repo uses blindbox-collection in .firebaserc),\n' +
        'or run: firebase use blindbox-collection',
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
    : 'application default credentials';
  console.log(`Using Firebase project: ${projectId} (${authNote})`);
  admin.initializeApp({ projectId });
}

async function main() {
  const seedPath = resolve(process.argv[2] ?? join(__dirname, 'popmart_us.seed.json'));
  const seed = loadSeed(seedPath);
  const sourceId = seed.sourceId ?? 'popmart_us';
  const sourceLabel = seed.sourceLabel ?? 'POP MART';
  const locale = seed.locale ?? 'us';
  const items = seed.items ?? [];
  const retiredItemIds = Array.isArray(seed.retiredItemIds)
    ? seed.retiredItemIds.map((id) => id?.trim()).filter(Boolean)
    : [];

  if (!Array.isArray(items) || items.length === 0) {
    console.error('No items in seed file.');
    process.exit(1);
  }

  const validation = validateOfficialFeedSeed(seed);
  for (const w of validation.warnings) console.warn(`warn: ${w}`);
  if (!validation.ok) {
    console.error('Seed validation failed:');
    for (const e of validation.errors) console.error(`  - ${e}`);
    console.error('Fix popmart_us.seed.json (per-item officialUrl + imageUrl) then retry.');
    process.exit(1);
  }

  initAdmin();
  const db = admin.firestore();
  const batch = db.batch();
  const now = admin.firestore.FieldValue.serverTimestamp();

  for (const item of items) {
    const id = item.id?.trim();
    const title = item.title?.trim();
    const imageUrl = item.imageUrl?.trim();
    const officialUrl = item.officialUrl?.trim();
    const publishedAtRaw = item.publishedAt?.trim();
    const status = item.status?.trim() ?? 'active';
    const summary = item.summary?.trim();

    if (!id || !title || !imageUrl || !officialUrl || !publishedAtRaw) {
      console.error('Skipping incomplete item (should have been caught by validation):', item);
      process.exit(1);
    }

    const publishedAt = admin.firestore.Timestamp.fromDate(new Date(publishedAtRaw));
    const ref = db.collection(COLLECTION).doc(id);

    const doc = {
      id,
      sourceId,
      sourceLabel,
      title,
      imageUrl,
      officialUrl,
      publishedAt,
      ingestedAt: now,
      status,
      contentHash: contentHash(sourceId, officialUrl),
      locale,
    };
    if (summary) doc.summary = summary;
    const releaseType = item.releaseType?.trim();
    const productId = item.productId?.trim();
    if (releaseType) doc.releaseType = releaseType;
    if (productId) doc.productId = productId;

    batch.set(ref, doc, { merge: true });
  }

  for (const retiredId of retiredItemIds) {
    const ref = db.collection(COLLECTION).doc(retiredId);
    batch.set(
      ref,
      {
        status: 'archived',
        ingestedAt: now,
      },
      { merge: true },
    );
  }

  await batch.commit();
  console.log(
    `Wrote ${items.length} active documents to ${COLLECTION} (source=${sourceId}).` +
      (retiredItemIds.length > 0
        ? ` Archived ${retiredItemIds.length} retired id(s).`
        : ''),
  );
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});

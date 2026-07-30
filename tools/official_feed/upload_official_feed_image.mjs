#!/usr/bin/env node
/**
 * Download an image and upload to Firebase Storage under official_feed/.
 *
 * Usage:
 *   node tools/official_feed/upload_official_feed_image.mjs <httpsImageUrl> <objectPath>
 *
 * Prints the public Firebase download URL.
 */
import { createRequire } from 'node:module';
import { randomUUID } from 'node:crypto';
import { readFileSync, writeFileSync, mkdtempSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(__dirname, '../..');
const require = createRequire(join(repoRoot, 'functions/package.json'));
const admin = require('firebase-admin');

const FIREBASE_CLI_CLIENT_ID =
  '563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com';
const FIREBASE_CLI_CLIENT_SECRET = 'j9iVZfS8kkCEFUPaAeJV0sAi';

function resolveProjectId() {
  const fromEnv =
    process.env.FIREBASE_PROJECT_ID?.trim() ||
    process.env.GCLOUD_PROJECT?.trim();
  if (fromEnv) return fromEnv;
  const rc = JSON.parse(readFileSync(join(repoRoot, '.firebaserc'), 'utf8'));
  return rc?.projects?.default;
}

function loadFirebaseCliRefreshToken() {
  const home = process.env.HOME || process.env.USERPROFILE;
  const candidates = [];
  if (home) {
    candidates.push(join(home, '.config', 'configstore', 'firebase-tools.json'));
  }
  if (process.env.APPDATA) {
    candidates.push(
      join(process.env.APPDATA, 'configstore', 'firebase-tools.json'),
    );
  }
  for (const p of candidates) {
    try {
      const cfg = JSON.parse(readFileSync(p, 'utf8'));
      const token = cfg?.tokens?.refresh_token?.trim();
      if (token) return token;
    } catch {
      // try next
    }
  }
  return null;
}

function initAdmin(projectId) {
  if (admin.apps.length) return;
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
  admin.initializeApp({
    projectId,
    storageBucket: `${projectId}.firebasestorage.app`,
  });
}

const src = process.argv[2];
const objectPath = process.argv[3];
if (!src || !objectPath) {
  console.error(
    'Usage: node tools/official_feed/upload_official_feed_image.mjs <httpsImageUrl> <objectPath>',
  );
  process.exit(1);
}

const projectId = resolveProjectId();
initAdmin(projectId);
const imgRes = await fetch(src, { headers: { 'User-Agent': 'Mozilla/5.0' } });
if (!imgRes.ok) throw new Error(`download failed ${imgRes.status}`);
const buf = Buffer.from(await imgRes.arrayBuffer());
const bucket = admin.storage().bucket();
const file = bucket.file(objectPath);
const token = randomUUID();
await file.save(buf, {
  contentType: imgRes.headers.get('content-type') || 'image/jpeg',
  resumable: false,
  metadata: {
    cacheControl: 'public,max-age=31536000',
    metadata: { firebaseStorageDownloadTokens: token },
  },
});
const url =
  `https://firebasestorage.googleapis.com/v0/b/${bucket.name}/o/` +
  `${encodeURIComponent(objectPath)}?alt=media&token=${token}`;
console.log(url);

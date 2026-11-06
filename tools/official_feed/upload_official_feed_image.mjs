#!/usr/bin/env node
/**
 * Download an image and upload to Firebase Storage under official_feed/.
 *
 * Usage:
 *   node tools/official_feed/upload_official_feed_image.mjs <httpsImageUrl-or-localFile> <objectPath>
 *
 * Prints the public Firebase download URL.
 */
import { createRequire } from 'node:module';
import { randomUUID } from 'node:crypto';
import { existsSync, readFileSync, statSync, writeFileSync, mkdtempSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, dirname, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(__dirname, '../..');

const FIREBASE_CLI_CLIENT_ID =
  '563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com';
const FIREBASE_CLI_CLIENT_SECRET = 'j9iVZfS8kkCEFUPaAeJV0sAi';

export function sniffImageContentType(buf) {
  if (!Buffer.isBuffer(buf) || buf.length < 12) return null;
  if (buf[0] === 0x89 && buf[1] === 0x50 && buf[2] === 0x4e && buf[3] === 0x47) {
    return 'image/png';
  }
  if (buf[0] === 0xff && buf[1] === 0xd8 && buf[2] === 0xff) return 'image/jpeg';
  if (buf.toString('ascii', 0, 4) === 'RIFF' && buf.toString('ascii', 8, 12) === 'WEBP') {
    return 'image/webp';
  }
  return null;
}

export function officialFeedDownloadUrl(bucketName, objectPath, token) {
  return (
    `https://firebasestorage.googleapis.com/v0/b/${bucketName}/o/` +
    `${encodeURIComponent(objectPath)}?alt=media&token=${token}`
  );
}

function isRemoteUrl(src) {
  try {
    const protocol = new URL(src).protocol;
    return protocol === 'https:' || protocol === 'http:';
  } catch {
    return false;
  }
}

/**
 * Read image bytes from an https URL or a local file path.
 * Does not upload.
 *
 * @param {string} src
 * @param {{ fetchImpl?: typeof fetch }} [options]
 */
export async function loadOfficialFeedImageBytes(src, options = {}) {
  const fetchImpl = options.fetchImpl ?? fetch;
  const trimmed = src?.trim();
  if (!trimmed) throw new Error('Image source is required.');

  if (isRemoteUrl(trimmed)) {
    const imgRes = await fetchImpl(trimmed, { headers: { 'User-Agent': 'Mozilla/5.0' } });
    if (!imgRes.ok) throw new Error(`download failed ${imgRes.status}`);
    const buf = Buffer.from(await imgRes.arrayBuffer());
    const sniffed = sniffImageContentType(buf);
    if (!sniffed) throw new Error(`Not an image: ${trimmed}`);
    return { bytes: buf, contentType: sniffed };
  }

  const filePath = resolve(trimmed);
  if (!existsSync(filePath) || !statSync(filePath).isFile()) {
    throw new Error(`Image file not found: ${filePath}`);
  }
  const buf = readFileSync(filePath);
  const sniffed = sniffImageContentType(buf);
  if (!sniffed) throw new Error(`Not an image: ${filePath}`);
  return { bytes: buf, contentType: sniffed };
}

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
  const require = createRequire(join(repoRoot, 'functions/package.json'));
  const admin = require('firebase-admin');
  if (admin.apps.length) return admin;
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
  return admin;
}

async function main() {
  const src = process.argv[2];
  const objectPath = process.argv[3];
  if (!src || !objectPath) {
    console.error(
      'Usage: node tools/official_feed/upload_official_feed_image.mjs <httpsImageUrl-or-localFile> <objectPath>',
    );
    process.exit(1);
  }

  const projectId = resolveProjectId();
  const admin = initAdmin(projectId);
  const { bytes, contentType } = await loadOfficialFeedImageBytes(src);
  const bucket = admin.storage().bucket();
  const file = bucket.file(objectPath);
  const token = randomUUID();
  await file.save(bytes, {
    contentType,
    resumable: false,
    metadata: {
      cacheControl: 'public,max-age=31536000',
      metadata: { firebaseStorageDownloadTokens: token },
    },
  });
  console.log(officialFeedDownloadUrl(bucket.name, objectPath, token));
}

const isDirectRun =
  process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href;

if (isDirectRun) {
  main().catch((err) => {
    console.error(err instanceof Error ? err.message : String(err));
    process.exit(1);
  });
}

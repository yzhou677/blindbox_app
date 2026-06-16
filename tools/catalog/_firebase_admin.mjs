/**
 * Firebase Admin bootstrap for catalog tooling.
 * Reuses the same auth pattern as push_market_snapshots.mjs.
 */

import { readFileSync, mkdtempSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createRequire } from 'node:module';

const __dirname = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(__dirname, '../..');

const require = createRequire(join(repoRoot, 'functions/package.json'));

const FIREBASE_CLI_CLIENT_ID =
  '563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com';
const FIREBASE_CLI_CLIENT_SECRET = 'j9iVZfS8kkCEFUPaAeJV0sAi';

let _adminInitialized = false;

/**
 * @returns {string | null}
 */
export function resolveProjectId() {
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

function firebaseToolsConfigCandidates() {
  /** @type {string[]} */
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

/**
 * @param {{ quiet?: boolean }} [options]
 */
export function initFirebaseAdmin(options = {}) {
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

  if (!options.quiet) {
    const authNote = process.env.GOOGLE_APPLICATION_CREDENTIALS?.includes(
      'firebase-adc-',
    )
      ? 'Firebase CLI credentials'
      : process.env.GOOGLE_APPLICATION_CREDENTIALS
        ? 'GOOGLE_APPLICATION_CREDENTIALS'
        : 'application default credentials';
    console.error(`Using Firebase project: ${projectId} (${authNote})`);
  }

  admin.initializeApp({ projectId });
}

/**
 * @param {{ quiet?: boolean }} [options]
 * @returns {import('firebase-admin').firestore.Firestore}
 */
export function getFirestore(options = {}) {
  initFirebaseAdmin(options);
  const admin = require('firebase-admin');
  return admin.firestore();
}

/** @visibleForTesting */
export function resetFirebaseAdminForTest() {
  _adminInitialized = false;
  const admin = require('firebase-admin');
  if (admin.apps.length > 0) {
    return admin.app().delete();
  }
  return Promise.resolve();
}

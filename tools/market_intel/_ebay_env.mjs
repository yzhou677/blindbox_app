/**
 * Market Intelligence — eBay environment loading for admin tools.
 */

import { existsSync, readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const repoRoot = join(__dirname, '..', '..');

const DEFAULT_OAUTH_SCOPE = 'https://api.ebay.com/oauth/api_scope';

/**
 * @param {string} filePath
 */
export function loadEnvFile(filePath) {
  if (!existsSync(filePath)) {
    return false;
  }

  for (const line of readFileSync(filePath, 'utf8').split('\n')) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) {
      continue;
    }

    const eq = trimmed.indexOf('=');
    if (eq <= 0) {
      continue;
    }

    const key = trimmed.slice(0, eq).trim();
    const value = trimmed.slice(eq + 1).trim();
    if (!process.env[key]) {
      process.env[key] = value;
    }
  }

  return true;
}

/**
 * Loads eBay credentials from functions/.env.blindbox-collection when present.
 */
export function loadEbayEnvFromRepo() {
  loadEnvFile(join(repoRoot, 'functions', '.env.blindbox-collection'));
  loadEnvFile(join(repoRoot, 'tools', 'market_intel', '.env.ebay'));
}

/**
 * @returns {'sandbox' | 'production'}
 */
export function resolveEbayEnv() {
  const raw = (process.env.EBAY_ENV ?? 'sandbox').trim().toLowerCase();
  return raw === 'production' ? 'production' : 'sandbox';
}

/**
 * @returns {string}
 */
export function resolveFindingApiBase() {
  return resolveEbayEnv() === 'production'
    ? 'https://svcs.ebay.com/services/search/FindingService/v1'
    : 'https://svcs.sandbox.ebay.com/services/search/FindingService/v1';
}

/**
 * @returns {string}
 */
export function resolveOAuthApiBase() {
  return resolveEbayEnv() === 'production'
    ? 'https://api.ebay.com'
    : 'https://api.sandbox.ebay.com';
}

/**
 * @returns {boolean}
 */
export function ebayClientIdConfigured() {
  return Boolean(process.env.EBAY_CLIENT_ID?.trim());
}

/**
 * @returns {boolean}
 */
export function ebayOAuthConfigured() {
  return Boolean(
    process.env.EBAY_CLIENT_ID?.trim() && process.env.EBAY_CLIENT_SECRET?.trim(),
  );
}

/**
 * @returns {{
 *   clientId: string,
 *   clientSecret: string,
 *   oauthScope: string,
 *   marketplaceId: string,
 *   fetchMode: 'live' | 'fixture',
 * }}
 */
export function readEbayConfig() {
  loadEbayEnvFromRepo();

  const fetchMode =
    process.env.EBAY_FETCH_MODE?.trim().toLowerCase() === 'fixture'
      ? 'fixture'
      : 'live';

  return {
    clientId: process.env.EBAY_CLIENT_ID?.trim() ?? '',
    clientSecret: process.env.EBAY_CLIENT_SECRET?.trim() ?? '',
    oauthScope: process.env.EBAY_OAUTH_SCOPE?.trim() || DEFAULT_OAUTH_SCOPE,
    marketplaceId: process.env.EBAY_MARKETPLACE_ID?.trim() || 'EBAY_US',
    fetchMode,
  };
}

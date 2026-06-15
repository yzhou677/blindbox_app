#!/usr/bin/env node
/**
 * Sprint 2 Step 3B.1 — live eBay fetch diagnostics (investigation only).
 *
 * Usage:
 *   node tools/market_intel/debug_ebay_live_probe.mjs
 *   node tools/market_intel/debug_ebay_live_probe.mjs --env production
 */

import { existsSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

import {
  buildFindCompletedItemsParams,
  parseFindCompletedItemsResponse,
} from './_ebay_completed_sales.mjs';
import {
  ebayClientIdConfigured,
  ebayOAuthConfigured,
  loadEbayEnvFromRepo,
  readEbayConfig,
  resolveEbayEnv,
  resolveFindingApiBase,
  resolveOAuthApiBase,
} from './_ebay_env.mjs';

const __dirname = dirname(fileURLToPath(import.meta.url));
const repoRoot = join(__dirname, '..', '..');
const QUERY = 'POP MART Labubu Have a Seat SISI';

/**
 * @param {string | undefined} value
 */
function maskCredential(value) {
  const trimmed = value?.trim() ?? '';
  if (!trimmed) {
    return '(missing)';
  }

  if (trimmed.length <= 8) {
    return `${trimmed.slice(0, 2)}…(${trimmed.length} chars)`;
  }

  return `${trimmed.slice(0, 6)}…${trimmed.slice(-4)} (${trimmed.length} chars)`;
}

/**
 * @param {string | undefined} clientId
 */
function describeClientIdType(clientId) {
  const id = clientId?.trim() ?? '';
  if (!id) {
    return 'missing';
  }

  if (id.startsWith('SBX-')) {
    return 'sandbox App ID (SBX- prefix)';
  }

  if (/^PRD-|^Prod-|^PROD-/i.test(id)) {
    return 'production App ID (PRD- prefix)';
  }

  return 'App ID without SBX-/PRD- prefix (likely production or legacy format)';
}

function printSection(title) {
  console.log('');
  console.log('='.repeat(60));
  console.log(title);
  console.log('='.repeat(60));
}

async function probeFindingApi(clientId, envOverride) {
  if (envOverride) {
    process.env.EBAY_ENV = envOverride;
  }

  const base = resolveFindingApiBase();
  const params = buildFindCompletedItemsParams(QUERY, { pageSize: 10 });
  params.set('SECURITY-APPNAME', clientId);

  const url = `${base}?${params.toString()}`;
  const headers = {
    Accept: 'application/json',
  };

  printSection(`FINDING API PROBE (${resolveEbayEnv()})`);
  console.log('ENDPOINT BASE:');
  console.log(base);
  console.log('');
  console.log('FULL URL (App ID masked in query string):');
  const maskedUrl = url.replace(
    /SECURITY-APPNAME=[^&]+/,
    `SECURITY-APPNAME=${maskCredential(clientId)}`,
  );
  console.log(maskedUrl);
  console.log('');
  console.log('QUERY PARAMETERS:');
  for (const [key, value] of params.entries()) {
    const display =
      key === 'SECURITY-APPNAME' ? maskCredential(value) : value;
    console.log(`  ${key} = ${display}`);
  }
  console.log('');
  console.log('REQUEST HEADERS:');
  for (const [key, value] of Object.entries(headers)) {
    console.log(`  ${key}: ${value}`);
  }
  console.log('');
  console.log('AUTH METHOD:');
  console.log('  Finding API legacy — SECURITY-APPNAME query param (App ID only, no OAuth Bearer)');

  const startedAt = Date.now();
  const response = await fetch(url, { method: 'GET', headers });
  const bodyText = await response.text();
  const durationMs = Date.now() - startedAt;

  console.log('');
  console.log('RESPONSE STATUS:');
  console.log(`  ${response.status} ${response.statusText}`);
  console.log('');
  console.log('RESPONSE HEADERS:');
  for (const [key, value] of response.headers.entries()) {
    console.log(`  ${key}: ${value}`);
  }
  console.log('');
  console.log('BODY (first 500 chars):');
  console.log(bodyText.slice(0, 500));
  console.log('');
  console.log(`DURATION MS: ${durationMs}`);

  let parsed = null;
  let parseError = null;
  try {
    parsed = JSON.parse(bodyText);
  } catch (error) {
    parseError = error instanceof Error ? error.message : String(error);
  }

  if (parsed) {
    const listings = parseFindCompletedItemsResponse(parsed);
    console.log('');
    console.log('PARSED LISTINGS:');
    console.log(`  count: ${listings.length}`);
    if (listings.length > 0) {
      console.log(`  first title: ${listings[0].title}`);
    }
  } else {
    console.log('');
    console.log('JSON PARSE:');
    console.log(`  failed: ${parseError}`);
  }

  return {
    env: resolveEbayEnv(),
    status: response.status,
    contentType: response.headers.get('content-type'),
    isJson: parsed != null,
    listingCount: parsed ? parseFindCompletedItemsResponse(parsed).length : 0,
    bodyPrefix: bodyText.slice(0, 500),
  };
}

async function probeOAuthToken(scopeOverride) {
  const config = readEbayConfig();
  if (!ebayOAuthConfigured()) {
    return { ok: false, error: 'OAuth credentials missing' };
  }

  const scope = scopeOverride ?? config.oauthScope;
  const tokenUrl = `${resolveOAuthApiBase()}/identity/v1/oauth2/token`;
  const basic = Buffer.from(`${config.clientId}:${config.clientSecret}`).toString('base64');

  const response = await fetch(tokenUrl, {
    method: 'POST',
    headers: {
      Authorization: `Basic ${basic}`,
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: new URLSearchParams({
      grant_type: 'client_credentials',
      scope,
    }),
  });

  const bodyText = await response.text();
  let payload;
  try {
    payload = JSON.parse(bodyText);
  } catch {
    payload = null;
  }

  return {
    scope,
    ok: response.ok,
    status: response.status,
    accessToken: payload?.access_token ?? null,
    tokenType: payload?.token_type ?? null,
    expiresIn: payload?.expires_in ?? null,
    error: payload?.error_description ?? payload?.error ?? (response.ok ? null : bodyText.slice(0, 200)),
  };
}

/**
 * @param {string} name
 * @param {string} url
 * @param {string} accessToken
 * @param {string} marketplaceId
 */
async function probeRestApi(name, url, accessToken, marketplaceId) {
  const response = await fetch(url, {
    headers: {
      Authorization: `Bearer ${accessToken}`,
      'X-EBAY-C-MARKETPLACE-ID': marketplaceId,
      Accept: 'application/json',
    },
  });

  const bodyText = await response.text();

  printSection(name);
  console.log('URL:');
  console.log(url);
  console.log('');
  console.log('AUTH METHOD:');
  console.log('  OAuth 2.0 client_credentials Bearer token');
  console.log('');
  console.log('RESPONSE STATUS:');
  console.log(`  ${response.status} ${response.statusText}`);
  console.log('');
  console.log('RESPONSE HEADERS:');
  for (const [key, value] of response.headers.entries()) {
    console.log(`  ${key}: ${value}`);
  }
  console.log('');
  console.log('BODY (first 500 chars):');
  console.log(bodyText.slice(0, 500));

  let listingCount = 0;
  try {
    const payload = JSON.parse(bodyText);
    listingCount =
      payload?.itemSummaries?.length ??
      payload?.itemSales?.length ??
      0;
  } catch {
    listingCount = 0;
  }

  return {
    status: response.status,
    listingCount,
    isJson: bodyText.trim().startsWith('{') || bodyText.trim().startsWith('['),
  };
}

async function main() {
  const envOverride = process.argv.includes('--env')
    ? process.argv[process.argv.indexOf('--env') + 1]
    : null;

  if (envOverride) {
    process.env.EBAY_ENV = envOverride;
  }

  loadEbayEnvFromRepo();
  const config = readEbayConfig();

  printSection('CREDENTIAL AUDIT');
  console.log('ENV FILES:');
  console.log(
    `  functions/.env.blindbox-collection: ${existsSync(join(repoRoot, 'functions', '.env.blindbox-collection')) ? 'present' : 'missing'}`,
  );
  console.log(
    `  tools/market_intel/.env.ebay: ${existsSync(join(repoRoot, 'tools', 'market_intel', '.env.ebay')) ? 'present' : 'missing'}`,
  );
  console.log('');
  console.log('EBAY_ENV:');
  console.log(`  resolved: ${resolveEbayEnv()}`);
  console.log(`  raw process.env.EBAY_ENV: ${process.env.EBAY_ENV ?? '(unset, defaults sandbox)'}`);
  console.log('');
  console.log('CREDENTIALS:');
  console.log(`  EBAY_CLIENT_ID present: ${ebayClientIdConfigured()}`);
  console.log(`  EBAY_CLIENT_ID type: ${describeClientIdType(config.clientId)}`);
  console.log(`  EBAY_CLIENT_ID masked: ${maskCredential(config.clientId)}`);
  console.log(`  EBAY_CLIENT_SECRET present: ${Boolean(config.clientSecret)}`);
  console.log(`  EBAY_CLIENT_SECRET masked: ${maskCredential(config.clientSecret)}`);
  console.log(`  EBAY_OAUTH_SCOPE: ${config.oauthScope}`);
  console.log(`  EBAY_MARKETPLACE_ID: ${config.marketplaceId}`);
  console.log('');
  console.log('COMPATIBILITY NOTES:');
  console.log('  Finding API expects App ID via SECURITY-APPNAME (legacy, no OAuth Bearer)');
  console.log('  Browse/Marketplace Insights expect OAuth client_credentials Bearer token');
  console.log('  Repo Browse tools use OAuth — same Client ID + Secret pair');

  printSection('OAUTH TOKEN PROBE (Browse-class credentials)');
  const oauth = await probeOAuthToken();
  console.log(`  scope: ${oauth.scope}`);
  console.log(`  status: ${oauth.status ?? 'n/a'}`);
  console.log(`  ok: ${oauth.ok}`);
  if (oauth.tokenType) {
    console.log(`  token_type: ${oauth.tokenType}`);
    console.log(`  expires_in: ${oauth.expiresIn}`);
  }
  if (oauth.error) {
    console.log(`  error: ${oauth.error}`);
  }

  /** @type {Record<string, { status: number, listingCount: number, isJson: boolean }>} */
  const restProbes = {};

  if (oauth.ok && oauth.accessToken) {
    const apiBase = resolveOAuthApiBase();
    const encodedQuery = encodeURIComponent(QUERY);

    restProbes.browse = await probeRestApi(
      'BROWSE API PROBE (active listings only)',
      `${apiBase}/buy/browse/v1/item_summary/search?q=${encodedQuery}&limit=3`,
      oauth.accessToken,
      config.marketplaceId,
    );

    restProbes.insightsDefaultScope = await probeRestApi(
      'MARKETPLACE INSIGHTS PROBE (default oauth scope)',
      `${apiBase}/buy/marketplace/insights/v1_beta/item_sales/search?q=${encodedQuery}&category_ids=261068&limit=3`,
      oauth.accessToken,
      config.marketplaceId,
    );
  }

  const insightsScope = 'https://api.ebay.com/oauth/api_scope/buy.marketplace.insights';
  const insightsOAuth = await probeOAuthToken(insightsScope);

  printSection('OAUTH TOKEN PROBE (Marketplace Insights scope)');
  console.log(`  scope: ${insightsOAuth.scope}`);
  console.log(`  status: ${insightsOAuth.status ?? 'n/a'}`);
  console.log(`  ok: ${insightsOAuth.ok}`);
  if (insightsOAuth.error) {
    console.log(`  error: ${insightsOAuth.error}`);
  }

  if (insightsOAuth.ok && insightsOAuth.accessToken) {
    const apiBase = resolveOAuthApiBase();
    const encodedQuery = encodeURIComponent(QUERY);

    restProbes.insightsDedicatedScope = await probeRestApi(
      'MARKETPLACE INSIGHTS PROBE (buy.marketplace.insights scope)',
      `${apiBase}/buy/marketplace/insights/v1_beta/item_sales/search?q=${encodedQuery}&category_ids=261068&limit=3`,
      insightsOAuth.accessToken,
      config.marketplaceId,
    );
  }

  if (!ebayClientIdConfigured()) {
    console.error('\nEBAY_CLIENT_ID missing — cannot probe Finding API.');
    process.exit(1);
  }

  const primary = await probeFindingApi(config.clientId, envOverride);

  let alternate = null;
  const otherEnv = resolveEbayEnv() === 'sandbox' ? 'production' : 'sandbox';
  if (!envOverride) {
    alternate = await probeFindingApi(config.clientId, otherEnv);
  }

  printSection('PROBE SUMMARY');
  console.log(`Query: ${QUERY}`);
  console.log(`Primary (${primary.env}): HTTP ${primary.status}, JSON=${primary.isJson}, listings=${primary.listingCount}`);
  if (alternate) {
    console.log(
      `Alternate (${alternate.env}): HTTP ${alternate.status}, JSON=${alternate.isJson}, listings=${alternate.listingCount}`,
    );
  }
  console.log(`OAuth token (default scope): ${oauth.ok ? 'ok' : 'failed'}`);
  if (restProbes.browse) {
    console.log(
      `Browse API: HTTP ${restProbes.browse.status}, listings=${restProbes.browse.listingCount}`,
    );
  }
  if (restProbes.insightsDefaultScope) {
    console.log(
      `Marketplace Insights (default scope): HTTP ${restProbes.insightsDefaultScope.status}, listings=${restProbes.insightsDefaultScope.listingCount}`,
    );
  }
  if (restProbes.insightsDedicatedScope) {
    console.log(
      `Marketplace Insights (insights scope): HTTP ${restProbes.insightsDedicatedScope.status}, listings=${restProbes.insightsDedicatedScope.listingCount}`,
    );
  }
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});

/**
 * Live eBay browse coverage audit — all Brand × IP combinations.
 *
 * Usage (from functions/):
 *   npm run build
 *   node tools/audit-browse-coverage.mjs
 *   node tools/audit-browse-coverage.mjs --probe-failures
 *
 * Requires .env.blindbox-collection with eBay credentials.
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

function loadEnv() {
  const envPath = path.join(__dirname, '..', '.env.blindbox-collection');
  if (!fs.existsSync(envPath)) return;
  for (const line of fs.readFileSync(envPath, 'utf8').split('\n')) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;
    const eq = trimmed.indexOf('=');
    if (eq <= 0) continue;
    const key = trimmed.slice(0, eq).trim();
    const val = trimmed.slice(eq + 1).trim();
    if (!process.env[key]) process.env[key] = val;
  }
}

loadEnv();

import {
  ANY_BRAND,
  ANY_IP,
  MARKET_TAXONOMY_BRANDS,
  MARKET_TAXONOMY_IPS,
  MARKET_HIDDEN_BROWSE_BRAND_IDS,
  composeBrowseUpstreamQ,
  ipHasVerifiedCharacterAspect,
} from '../lib/providers/gateway/composeBrowseQuery.js';
import { composeBrowseAspectPlan, resolveBrowseCategoryId } from '../lib/providers/gateway/composeBrowseAspectFilter.js';
import {
  filterRawItemsByTaxonomy,
  listingTitleMatchesTaxonomy,
} from '../lib/providers/gateway/titleTaxonomyFilter.js';

const SPARSE_THRESHOLD = 6;
const probeFailures = process.argv.includes('--probe-failures');

async function getToken() {
  const clientId = process.env.EBAY_CLIENT_ID?.trim();
  const clientSecret = process.env.EBAY_CLIENT_SECRET?.trim();
  if (!clientId || !clientSecret) {
    throw new Error('EBAY_CLIENT_ID / EBAY_CLIENT_SECRET missing');
  }
  const base =
    (process.env.EBAY_ENV ?? '').trim().toLowerCase() === 'production'
      ? 'https://api.ebay.com'
      : 'https://api.sandbox.ebay.com';
  const credentials = Buffer.from(`${clientId}:${clientSecret}`, 'utf8').toString(
    'base64',
  );
  const res = await fetch(`${base}/identity/v1/oauth2/token`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
      Authorization: `Basic ${credentials}`,
    },
    body: new URLSearchParams({
      grant_type: 'client_credentials',
      scope:
        process.env.EBAY_OAUTH_SCOPE?.trim() ||
        'https://api.ebay.com/oauth/api_scope',
    }),
  });
  if (!res.ok) throw new Error(`OAuth ${res.status}`);
  const { access_token } = await res.json();
  return { token: access_token, base };
}

async function searchEbay(base, token, { q, categoryIds, aspectFilter, limit = 12 }) {
  const params = new URLSearchParams({ q, limit: String(limit), category_ids: categoryIds });
  if (aspectFilter) params.set('aspect_filter', aspectFilter);
  const marketplace = process.env.EBAY_MARKETPLACE_ID?.trim() || 'EBAY_US';
  const res = await fetch(
    `${base}/buy/browse/v1/item_summary/search?${params.toString()}`,
    {
      headers: {
        Authorization: `Bearer ${token}`,
        'X-EBAY-C-MARKETPLACE-ID': marketplace,
        Accept: 'application/json',
      },
    },
  );
  const payload = await res.json();
  if (!res.ok) {
    return {
      ok: false,
      total: 0,
      items: [],
      error: payload.errors?.[0]?.message ?? `HTTP ${res.status}`,
    };
  }
  const items = (payload.itemSummaries ?? []).map((row) => ({
    itemId: row.itemId,
    title: row.title ?? '',
  }));
  return { ok: true, total: payload.total ?? items.length, items, error: null };
}

function buildCombinations() {
  const combos = [];
  const visibleBrands = MARKET_TAXONOMY_BRANDS.filter(
    (b) => !MARKET_HIDDEN_BROWSE_BRAND_IDS.has(b.id),
  );

  combos.push({
    brandId: ANY_BRAND,
    ipId: ANY_IP,
    brand: 'Any Brand',
    ip: 'Any IP',
  });

  for (const brand of visibleBrands) {
    combos.push({
      brandId: brand.id,
      ipId: ANY_IP,
      brand: brand.displayName,
      ip: 'Any IP',
    });
    const ips = MARKET_TAXONOMY_IPS.filter((ip) => ip.brandId === brand.id);
    for (const ip of ips) {
      combos.push({
        brandId: brand.id,
        ipId: ip.id,
        brand: brand.displayName,
        ip: ip.displayName,
      });
    }
  }
  return combos;
}

function retrievalMode(brandId, ipId) {
  if (brandId === ANY_BRAND && ipId === ANY_IP) return 'discover';
  if (ipHasVerifiedCharacterAspect(ipId)) return 'q_and_verified_character';
  return 'q_only';
}

function statusFromCounts(upstreamTotal, afterTitleFilter) {
  if (afterTitleFilter === 0 && upstreamTotal === 0) return 'empty';
  if (afterTitleFilter === 0 && upstreamTotal > 0) return 'title_filtered_empty';
  if (afterTitleFilter < SPARSE_THRESHOLD) return 'sparse';
  return 'healthy';
}

async function auditCombo(base, token, combo) {
  const { brandId, ipId } = combo;
  const q = composeBrowseUpstreamQ({ brandId, ipId });
  const plan = composeBrowseAspectPlan({ brandId, ipId });
  const categoryIds = plan.categoryIds ?? resolveBrowseCategoryId();
  const aspectFilter = plan.active ? plan.aspectFilter : null;

  const page = await searchEbay(base, token, {
    q,
    categoryIds,
    aspectFilter: aspectFilter ?? undefined,
  });

  const rawItems = page.items.map((row) => ({ itemId: row.itemId, title: row.title }));
  const filtered =
    brandId === ANY_BRAND && ipId === ANY_IP
      ? rawItems
      : filterRawItemsByTaxonomy(rawItems, { brandId, ipId });

  const verifiedFacet = ipHasVerifiedCharacterAspect(ipId);
  const afterTitle = filtered.length;
  const status = statusFromCounts(page.total, afterTitle);

  return {
    brand: combo.brand,
    ip: combo.ip,
    brandId,
    ipId,
    query: q,
    categoryIds,
    aspect_filter: aspectFilter,
    verifiedFacet,
    retrievalMode: retrievalMode(brandId, ipId),
    upstreamTotal: page.total,
    rawSampleCount: rawItems.length,
    afterTitleFilter: afterTitle,
    status,
    recommendedRetrievalMode: retrievalMode(brandId, ipId),
    sampleTitles: filtered.slice(0, 3).map((r) => r.title),
    upstreamSampleTitles: rawItems.slice(0, 3).map((r) => r.title),
    error: page.error,
    taxonomyIpKnown: MARKET_TAXONOMY_IPS.some((row) => row.id === ipId) || ipId === ANY_IP,
  };
}

async function probeAlternateQueries(base, token, combo, seeds) {
  const categoryIds = resolveBrowseCategoryId();
  const out = [];
  for (const q of seeds) {
    const page = await searchEbay(base, token, { q, categoryIds, limit: 5 });
    const titles = page.items.map((r) => r.title);
    const matched = titles.filter((title) =>
      listingTitleMatchesTaxonomy(title, {
        brandId: combo.brandId,
        ipId: combo.ipId,
      }),
    );
    out.push({ q, total: page.total, sampleTitles: titles.slice(0, 5), titleMatches: matched.length });
    await sleep(180);
  }
  return out;
}

function sleep(ms) {
  return new Promise((r) => setTimeout(r, ms));
}

async function main() {
  const { token, base } = await getToken();
  const combos = buildCombinations();
  const results = [];

  console.log(`Auditing ${combos.length} Brand × IP combinations…\n`);

  for (const combo of combos) {
    const row = await auditCombo(base, token, combo);
    results.push(row);
    const flag = row.status === 'healthy' ? '✓' : row.status === 'sparse' ? '~' : '✗';
    console.log(
      `${flag} ${row.brand} + ${row.ip} | q="${row.query}" | up=${row.upstreamTotal} post=${row.afterTitleFilter} | ${row.status}${!row.taxonomyIpKnown && row.ipId !== ANY_IP ? ' [IP missing in gateway taxonomy]' : ''}`,
    );
    await sleep(220);
  }

  const failures = results.filter(
    (r) => r.status === 'empty' || r.status === 'title_filtered_empty' || r.status === 'sparse',
  );

  if (probeFailures && failures.length > 0) {
    console.log('\n--- Probing alternate queries for failures ---\n');
    for (const row of failures) {
      const seeds = buildProbeSeeds(row);
      row.alternateQueries = await probeAlternateQueries(base, token, row, seeds);
      console.log(`\n${row.brand} + ${row.ip}:`);
      for (const alt of row.alternateQueries) {
        console.log(`  q="${alt.q}" total=${alt.total} titleMatches=${alt.titleMatches}`);
        if (alt.sampleTitles[0]) console.log(`    e.g. ${alt.sampleTitles[0].slice(0, 70)}`);
      }
    }
  }

  const outPath = path.join(__dirname, 'browse-coverage-audit.json');
  fs.writeFileSync(
    outPath,
    JSON.stringify(
      {
        fetchedAt: new Date().toISOString(),
        categoryId: resolveBrowseCategoryId(),
        sparseThreshold: SPARSE_THRESHOLD,
        summary: {
          total: results.length,
          healthy: results.filter((r) => r.status === 'healthy').length,
          sparse: results.filter((r) => r.status === 'sparse').length,
          empty: results.filter((r) => r.status === 'empty').length,
          titleFilteredEmpty: results.filter((r) => r.status === 'title_filtered_empty').length,
          missingGatewayIp: results.filter((r) => !r.taxonomyIpKnown && r.ipId !== ANY_IP).length,
        },
        results,
      },
      null,
      2,
    ),
  );
  console.log(`\nWrote ${outPath}`);
}

function buildProbeSeeds(row) {
  const seeds = new Set([row.query]);
  const ip = MARKET_TAXONOMY_IPS.find((r) => r.id === row.ipId);
  const brand = MARKET_TAXONOMY_BRANDS.find((b) => b.id === row.brandId);

  if (brand?.ebayBrandQuery) {
    seeds.add(brand.ebayBrandQuery);
    seeds.add(`${brand.ebayBrandQuery} blind box`);
  }
  if (ip) {
    seeds.add(ip.displayName);
    for (const a of ip.aliases ?? []) seeds.add(a);
    if (brand?.ebayBrandQuery) {
      seeds.add(`${brand.ebayBrandQuery} ${ip.displayName}`);
      for (const a of ip.aliases ?? []) seeds.add(`${brand.ebayBrandQuery} ${a}`);
    }
    seeds.add(`${ip.displayName} blind box`);
    // spacing variants
    if (ip.displayName.toLowerCase().includes('mei')) {
      seeds.add('may mei');
      seeds.add('top toy may mei');
    }
  }
  if (row.brandId === 'dreams_inc') {
    seeds.add('sonny angel blind box');
    seeds.add('smiski');
  }
  if (row.brandId === 'tntspace') {
    seeds.add('tntspace dora');
    seeds.add('tnt space dora blind box');
  }
  if (row.brandId === 'toptoy') {
    seeds.add('top toy maymei');
    seeds.add('toptoy may mei');
  }
  return [...seeds].slice(0, 12);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});

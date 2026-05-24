/**
 * Full taxonomy × marketplace calibration audit.
 *
 * Validates every supported Brand × IP against live eBay browse,
 * inspects listing quality, and emits structured recommendations.
 *
 * Usage (from functions/):
 *   npm run audit:ecosystem
 *
 * Outputs:
 *   tools/ecosystem-calibration-audit.json
 *   tools/ecosystem-calibration-report.md
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
  CANONICAL_EBAY_BROWSE_CATEGORY_ID,
  MARKET_TAXONOMY_BRANDS,
  MARKET_TAXONOMY_IPS,
  composeBrowseUpstreamQ,
  ipHasVerifiedCharacterAspect,
} from '../lib/providers/gateway/composeBrowseQuery.js';
import { composeBrowseAspectPlan, resolveBrowseCategoryId } from '../lib/providers/gateway/composeBrowseAspectFilter.js';
import {
  filterRawItemsByTaxonomy,
  listingTitleMatchesTaxonomy,
} from '../lib/providers/gateway/titleTaxonomyFilter.js';
import {
  clusterMarketTitles,
  sellerDiversityReport,
} from './lib/market-title-cluster.mjs';

const SAMPLE_LIMIT = 12;
const SPARSE_THRESHOLD = 6;
const NOISE_TERMS = [
  'custom',
  'inspired',
  'bootleg',
  'fake',
  'replica',
  '3d print',
  'digital file',
  'stl',
  'pattern only',
  'wholesale lot',
  'stickers only',
  'decal',
];
const ACCESSORY_TERMS = ['keychain', 'key chain', 'charm', 'phone strap', 'badge', 'pin only'];
const CATEGORY_DRIFT_IDS = new Set(['19007']); // legacy; live listings often 261068

function sleep(ms) {
  return new Promise((r) => setTimeout(r, ms));
}

async function getToken() {
  const clientId = process.env.EBAY_CLIENT_ID?.trim();
  const clientSecret = process.env.EBAY_CLIENT_SECRET?.trim();
  if (!clientId || !clientSecret) throw new Error('EBAY credentials missing');
  const base =
    (process.env.EBAY_ENV ?? '').trim().toLowerCase() === 'production'
      ? 'https://api.ebay.com'
      : 'https://api.sandbox.ebay.com';
  const credentials = Buffer.from(`${clientId}:${clientSecret}`, 'utf8').toString('base64');
  const res = await fetch(`${base}/identity/v1/oauth2/token`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
      Authorization: `Basic ${credentials}`,
    },
    body: new URLSearchParams({
      grant_type: 'client_credentials',
      scope: process.env.EBAY_OAUTH_SCOPE?.trim() || 'https://api.ebay.com/oauth/api_scope',
    }),
  });
  if (!res.ok) throw new Error(`OAuth ${res.status}`);
  const { access_token } = await res.json();
  return { token: access_token, base };
}

async function searchEbay(base, token, { q, categoryIds, aspectFilter, limit = SAMPLE_LIMIT }) {
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
    return { ok: false, total: 0, items: [], error: payload.errors?.[0]?.message ?? `HTTP ${res.status}` };
  }
  const items = (payload.itemSummaries ?? []).map(normalizeListing);
  return { ok: true, total: payload.total ?? items.length, items, error: null };
}

function normalizeListing(row) {
  const cat = row.categories?.[0]?.categoryId ?? row.leafCategoryIds?.[0] ?? null;
  const priceRaw = row.price?.value ?? row.price;
  const priceUsd =
    typeof priceRaw === 'number'
      ? priceRaw
      : typeof priceRaw === 'string'
        ? Number.parseFloat(priceRaw)
        : null;
  return {
    itemId: row.itemId ?? '',
    title: row.title ?? '',
    categoryId: cat ? String(cat) : null,
    imageUrl: row.image?.imageUrl ?? row.thumbnailImages?.[0]?.imageUrl ?? null,
    condition: row.condition ?? null,
    sellerUsername: row.seller?.username ?? null,
    itemCreationDate: row.itemCreationDate ?? null,
    priceUsd: Number.isFinite(priceUsd) ? priceUsd : null,
  };
}

function buildFullMatrix() {
  const combos = [];
  combos.push({ brandId: ANY_BRAND, ipId: ANY_IP, brand: 'Any Brand', ip: 'Any IP', uiVisible: true });

  for (const brand of MARKET_TAXONOMY_BRANDS) {
    combos.push({
      brandId: brand.id,
      ipId: ANY_IP,
      brand: brand.displayName,
      ip: 'Any IP',
      uiVisible: brand.id !== 'finding_unicorn',
    });
    for (const ip of MARKET_TAXONOMY_IPS.filter((r) => r.brandId === brand.id)) {
      combos.push({
        brandId: brand.id,
        ipId: ip.id,
        brand: brand.displayName,
        ip: ip.displayName,
        uiVisible: brand.id !== 'finding_unicorn',
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

function countNoise(title) {
  const t = title.toLowerCase();
  let noise = 0;
  let accessory = 0;
  for (const term of NOISE_TERMS) if (t.includes(term)) noise++;
  for (const term of ACCESSORY_TERMS) if (t.includes(term)) accessory++;
  return { noise, accessory };
}

function extractTitleTokens(title) {
  return title
    .replace(/[^\w\s]/g, ' ')
    .split(/\s+/)
    .map((w) => w.trim())
    .filter((w) => w.length > 2);
}

function observedNamingPatterns(titles) {
  const freq = new Map();
  for (const title of titles) {
    for (const token of extractTitleTokens(title)) {
      const key = token.toLowerCase();
      if (key.length < 3) continue;
      freq.set(key, (freq.get(key) ?? 0) + 1);
    }
  }
  return [...freq.entries()]
    .sort((a, b) => b[1] - a[1])
    .slice(0, 12)
    .map(([token, count]) => ({ token, count }));
}

function hintTokensForCombo(combo) {
  const ip = MARKET_TAXONOMY_IPS.find((row) => row.id === combo.ipId);
  const tokens = [];
  if (ip?.displayName) tokens.push(ip.displayName);
  for (const alias of ip?.aliases ?? []) tokens.push(alias);
  const brand = MARKET_TAXONOMY_BRANDS.find((row) => row.id === combo.brandId);
  if (brand?.displayName) tokens.push(brand.displayName);
  return tokens;
}

function inspectTitleClusters(filtered, combo) {
  const rows = filtered.map((r) => ({
    title: r.title,
    sellerUsername: r.sellerUsername,
    priceUsd: r.priceUsd,
  }));
  const hintTokens = hintTokensForCombo(combo);
  const clusters = clusterMarketTitles(rows, { hintTokens, minClusterSize: 2 });
  const diversity = sellerDiversityReport(rows);
  const singletonCount = rows.length - clusters.reduce((n, c) => n + c.listingCount, 0);
  return {
    sellerDiversity: diversity,
    singletonListingCount: singletonCount,
    multiListingClusters: clusters.length,
    topClusters: clusters.slice(0, 5),
    clusterQuality:
      clusters.length === 0
        ? 'no_multi_listing_clusters'
        : clusters.some((c) => !c.likelyNoisy && !c.likelyAccessoryHeavy && c.uniqueSellerCount >= 2)
          ? 'believable'
          : clusters.some((c) => !c.likelyNoisy && !c.likelyAccessoryHeavy)
            ? 'mixed'
            : 'noisy',
  };
}

function classifyQuality(input) {
  const {
    brandId,
    ipId,
    upstreamTotal,
    afterTitle,
    rawSample,
    filteredSample,
    titlePassRate,
    noiseRate,
    categoryDriftRate,
    contaminationRate,
  } = input;

  if (upstreamTotal === 0) {
    return { status: 'broken', why: 'eBay returned zero upstream results for composed query' };
  }
  if (afterTitle === 0 && upstreamTotal > 0) {
    return {
      status: 'broken',
      why: 'Upstream results exist but title verification removed all rows — query/title mismatch',
    };
  }
  if (afterTitle < SPARSE_THRESHOLD) {
    return {
      status: 'sparse',
      why: `Only ${afterTitle}/${SAMPLE_LIMIT} sample rows passed title filter (threshold ${SPARSE_THRESHOLD})`,
    };
  }
  if (brandId !== ANY_BRAND && ipId !== ANY_IP && titlePassRate < 0.45) {
    return {
      status: 'ambiguous',
      why: `Low title pass rate (${Math.round(titlePassRate * 100)}%) — query pulls cross-IP or generic inventory`,
    };
  }
  if (noiseRate >= 0.35 || contaminationRate >= 0.5) {
    return {
      status: 'noisy',
      why: `High noise/contamination (noise ${Math.round(noiseRate * 100)}%, filtered-out ${Math.round(contaminationRate * 100)}% of sample)`,
    };
  }
  if (categoryDriftRate > 0.25) {
    return {
      status: 'ambiguous',
      why: `${Math.round(categoryDriftRate * 100)}% of listings outside dominant category ${CANONICAL_EBAY_BROWSE_CATEGORY_ID}`,
    };
  }
  return { status: 'healthy', why: 'Good upstream volume, title pass rate, and sample quality' };
}

function recommendFixes(row) {
  const recs = [];
  if (row.status === 'broken' && row.upstreamTotal === 0) {
    recs.push('Try ebayPreferredQuery / ebayQueryAliases with observed seller tokens');
    recs.push('Verify gateway taxonomy IP row exists and matches Flutter registry');
  }
  if (row.status === 'broken' && row.upstreamTotal > 0 && row.afterTitleFilter === 0) {
    recs.push('Add titleMatchAliases from observedSellerNaming');
    recs.push('Relax or fix title verification tokens — sellers omit brand name');
  }
  if (row.status === 'sparse' && row.verifiedFacet) {
    recs.push('Keep Character facet; supplement q with IP display name (precision-safe)');
    recs.push('Ensure Tier 2 q-only path activates on sparse pages');
  }
  if (row.status === 'sparse' && !row.verifiedFacet) {
    recs.push('Calibrate ebayPreferredQuery casing/spacing from top titles');
  }
  if (row.status === 'noisy') {
    recs.push('Tighten title verification; add titleNoiseRisk metadata');
    recs.push('Avoid broadening q — filter accessory/custom keywords in title tier');
  }
  if (row.status === 'ambiguous') {
    recs.push('Use more specific q (brand + IP preferred query); do not add Brand aspect OR');
  }
  if (row.brandId === 'dreams_inc' && row.ipId === ANY_IP) {
    recs.push('Any IP shows Sonny-heavy feed — Smiski requires explicit IP chip (by design)');
  }
  return recs;
}

async function auditCombo(base, token, combo) {
  const { brandId, ipId } = combo;
  const q = composeBrowseUpstreamQ({ brandId, ipId });
  const plan = composeBrowseAspectPlan({ brandId, ipId });
  const categoryIds = plan.categoryIds ?? resolveBrowseCategoryId();
  const aspectFilter = plan.active ? plan.aspectFilter : null;
  const verifiedFacet = ipHasVerifiedCharacterAspect(ipId);

  const page = await searchEbay(base, token, {
    q,
    categoryIds,
    aspectFilter: aspectFilter ?? undefined,
  });

  const rawItems = page.items;
  const filtered =
    brandId === ANY_BRAND && ipId === ANY_IP
      ? rawItems
      : filterRawItemsByTaxonomy(
          rawItems.map((r) => ({ itemId: r.itemId, title: r.title })),
          { brandId, ipId },
        ).map((r) => rawItems.find((x) => x.itemId === r.itemId) ?? { ...r, imageUrl: null, categoryId: null });

  const titleChecks = rawItems.map((r) =>
    brandId === ANY_BRAND && ipId === ANY_IP
      ? true
      : listingTitleMatchesTaxonomy(r.title, { brandId, ipId }),
  );
  const titlePassRate =
    rawItems.length === 0 ? 0 : titleChecks.filter(Boolean).length / rawItems.length;

  let noiseHits = 0;
  let accessoryHits = 0;
  for (const item of filtered) {
    const { noise, accessory } = countNoise(item.title);
    if (noise > 0) noiseHits++;
    if (accessory > 0) accessoryHits++;
  }
  const noiseRate = filtered.length === 0 ? 0 : noiseHits / filtered.length;

  const categoryIdsSeen = [...new Set(rawItems.map((r) => r.categoryId).filter(Boolean))];
  const inCanonical = rawItems.filter((r) => r.categoryId === CANONICAL_EBAY_BROWSE_CATEGORY_ID).length;
  const categoryDriftRate = rawItems.length === 0 ? 0 : 1 - inCanonical / rawItems.length;
  const contaminationRate =
    rawItems.length === 0 ? 0 : (rawItems.length - titleChecks.filter(Boolean).length) / rawItems.length;

  const afterTitle = filtered.length;
  const quality = classifyQuality({
    brandId,
    ipId,
    upstreamTotal: page.total,
    afterTitle,
    rawSample: rawItems,
    filteredSample: filtered,
    titlePassRate,
    noiseRate,
    categoryDriftRate,
    contaminationRate,
  });

  const observedSellerNaming = observedNamingPatterns(filtered.map((r) => r.title));
  const titleClustering = inspectTitleClusters(filtered, combo);

  return {
    brand: combo.brand,
    ip: combo.ip,
    brandId,
    ipId,
    uiVisible: combo.uiVisible,
    query: q,
    categoryIds,
    aspect_filter: aspectFilter,
    verifiedFacet,
    retrievalMode: retrievalMode(brandId, ipId),
    upstreamTotal: page.total,
    rawSampleCount: rawItems.length,
    afterTitleFilter: afterTitle,
    titlePassRate: round(titlePassRate),
    noiseRate: round(noiseRate),
    accessoryRate: filtered.length ? round(accessoryHits / filtered.length) : 0,
    categoryDriftRate: round(categoryDriftRate),
    categoriesSeen: categoryIdsSeen,
    status: quality.status,
    why: quality.why,
    observedSellerNaming,
    titleClustering,
    listings: filtered.slice(0, 5).map((r) => ({
      title: r.title,
      categoryId: r.categoryId,
      hasImage: Boolean(r.imageUrl),
      condition: r.condition,
      sellerUsername: r.sellerUsername,
      itemCreationDate: r.itemCreationDate,
    })),
    upstreamRejectedTitles: rawItems
      .filter((r, i) => !titleChecks[i])
      .slice(0, 3)
      .map((r) => r.title),
    recommendations: recommendFixes({
      status: quality.status,
      upstreamTotal: page.total,
      afterTitleFilter: afterTitle,
      verifiedFacet,
      brandId,
      ipId,
    }),
    error: page.error,
  };
}

function round(n) {
  return Math.round(n * 1000) / 1000;
}

function buildMarkdownReport(payload) {
  const lines = [];
  lines.push('# Ecosystem Marketplace Calibration Report');
  lines.push('');
  lines.push(`Generated: ${payload.fetchedAt}`);
  lines.push(`Category universe: ${payload.categoryId}`);
  lines.push('');
  lines.push('## Summary');
  lines.push('');
  lines.push(`| Metric | Count |`);
  lines.push(`|--------|------:|`);
  for (const [k, v] of Object.entries(payload.summary)) {
    lines.push(`| ${k} | ${v} |`);
  }
  lines.push('');
  lines.push('## Problem combinations');
  lines.push('');
  const problems = payload.results.filter((r) => r.status !== 'healthy');
  if (problems.length === 0) {
    lines.push('None — all combinations healthy in sample.');
  } else {
    for (const row of problems) {
      lines.push(`### ${row.brand} + ${row.ip} (${row.status})`);
      lines.push('');
      lines.push(`- **Why:** ${row.why}`);
      lines.push(`- **Query:** \`${row.query}\``);
      lines.push(`- **Aspect:** ${row.aspect_filter ?? '(none)'}`);
      lines.push(`- **Upstream / post-filter:** ${row.upstreamTotal} / ${row.afterTitleFilter}`);
      lines.push(`- **Title pass rate:** ${Math.round(row.titlePassRate * 100)}%`);
      if (row.observedSellerNaming.length) {
        lines.push(`- **Top title tokens:** ${row.observedSellerNaming.map((t) => t.token).join(', ')}`);
      }
      if (row.recommendations.length) {
        lines.push(`- **Recommendations:**`);
        for (const rec of row.recommendations) lines.push(`  - ${rec}`);
      }
      lines.push('');
    }
  }
  lines.push('## Observed seller naming (aggregate)');
  lines.push('');
  const tokenAgg = new Map();
  for (const row of payload.results) {
    for (const { token, count } of row.observedSellerNaming) {
      tokenAgg.set(token, (tokenAgg.get(token) ?? 0) + count);
    }
  }
  const top = [...tokenAgg.entries()].sort((a, b) => b[1] - a[1]).slice(0, 30);
  for (const [token, count] of top) {
    lines.push(`- ${token} (${count})`);
  }
  lines.push('');
  lines.push('## Title clustering (aggregate)');
  lines.push('');
  const clusterQualityCounts = {};
  let believableCombos = 0;
  for (const row of payload.results) {
    const q = row.titleClustering?.clusterQuality ?? 'unknown';
    clusterQualityCounts[q] = (clusterQualityCounts[q] ?? 0) + 1;
    if (q === 'believable') believableCombos++;
  }
  lines.push(`- Combos with believable multi-listing clusters: ${believableCombos}/${payload.results.length}`);
  for (const [k, v] of Object.entries(clusterQualityCounts).sort((a, b) => b[1] - a[1])) {
    lines.push(`- ${k}: ${v}`);
  }
  lines.push('');
  lines.push('## Sample clusters (first healthy IP-specific combo with clusters)');
  lines.push('');
  const sample = payload.results.find(
    (r) =>
      r.status === 'healthy' &&
      r.ipId !== ANY_IP &&
      (r.titleClustering?.topClusters?.length ?? 0) > 0,
  );
  if (!sample) {
    lines.push('None in sample.');
  } else {
    lines.push(`### ${sample.brand} + ${sample.ip}`);
    for (const cluster of sample.titleClustering.topClusters.slice(0, 3)) {
      lines.push(
        `- **${cluster.label}** (${cluster.listingCount} listings, ${cluster.uniqueSellerCount} sellers, quality: ${cluster.likelyNoisy ? 'noisy' : cluster.likelyAccessoryHeavy ? 'accessory' : 'ok'})`,
      );
      for (const t of cluster.sampleTitles) lines.push(`  - ${t}`);
    }
  }
  return lines.join('\n');
}

async function main() {
  const { token, base } = await getToken();
  const combos = buildFullMatrix();
  const results = [];

  console.log(`Ecosystem audit: ${combos.length} combinations\n`);

  for (const combo of combos) {
    const row = await auditCombo(base, token, combo);
    results.push(row);
    const flag =
      row.status === 'healthy' ? '✓' : row.status === 'sparse' ? '~' : row.status === 'noisy' ? '!' : '✗';
    console.log(
      `${flag} [${row.status}] ${row.brand} + ${row.ip} | q="${row.query}" | up=${row.upstreamTotal} post=${row.afterTitleFilter} pass=${Math.round(row.titlePassRate * 100)}%`,
    );
    await sleep(240);
  }

  const summary = {
    total: results.length,
    healthy: results.filter((r) => r.status === 'healthy').length,
    sparse: results.filter((r) => r.status === 'sparse').length,
    noisy: results.filter((r) => r.status === 'noisy').length,
    ambiguous: results.filter((r) => r.status === 'ambiguous').length,
    broken: results.filter((r) => r.status === 'broken').length,
    uiVisible: results.filter((r) => r.uiVisible).length,
  };

  const payload = {
    fetchedAt: new Date().toISOString(),
    categoryId: resolveBrowseCategoryId(),
    sparseThreshold: SPARSE_THRESHOLD,
    summary,
    results,
  };

  const jsonPath = path.join(__dirname, 'ecosystem-calibration-audit.json');
  const mdPath = path.join(__dirname, 'ecosystem-calibration-report.md');
  fs.writeFileSync(jsonPath, JSON.stringify(payload, null, 2));
  fs.writeFileSync(mdPath, buildMarkdownReport(payload));
  console.log(`\nWrote ${jsonPath}`);
  console.log(`Wrote ${mdPath}`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});

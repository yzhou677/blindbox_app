/**
 * Live probe for catalog POP MART IPs missing from gateway taxonomy.
 * Usage: npm run build && node tools/probe-sparse-popmart-ips.mjs
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

import { CANONICAL_EBAY_BROWSE_CATEGORY_ID } from '../lib/providers/gateway/composeBrowseQuery.js';

const TARGETS = [
  {
    id: 'twinkle_twinkle',
    displayName: 'Twinkle Twinkle',
    aliases: ['Twinkle'],
    seriesHints: [
      'Twinkle Twinkle',
      'MOON GELATO',
      'Be a Little Star',
      'Sweet Dreams Forecast',
      'We are Twinkle Twinkle',
    ],
  },
  {
    id: 'bikini_bottom_buddies',
    displayName: 'Bikini Bottom Buddies',
    aliases: ['SpongeBob'],
    seriesHints: [
      'Bikini Bottom Buddies',
      'Whimsical Plush',
      'SpongeBob SquarePants',
      'SpongeBob',
    ],
  },
  {
    id: 'aespa',
    displayName: 'aespa',
    aliases: [],
    seriesHints: ['aespa', 'Fluffy Club', 'fluffy club vinyl plush'],
  },
  {
    id: 'polar',
    displayName: 'Polar',
    aliases: [],
    seriesHints: ['Polar In Monster Village', 'Polar in Monster Village', 'Monster Village'],
  },
  {
    id: 'baby_molly',
    displayName: 'Baby Molly',
    aliases: [],
    seriesHints: ['Baby Molly', 'Pocket Friends', 'My Huggable Discovery', 'Baby Tabby'],
  },
  {
    id: 'space_molly',
    displayName: 'Space Molly',
    aliases: ['Mega Space Molly'],
    seriesHints: ['Space Molly', 'Mega Space Molly', 'MEGA 100'],
  },
];

const CHARACTER_CANDIDATES = {
  twinkle_twinkle: [],
  bikini_bottom_buddies: ['SpongeBob SquarePants'],
  aespa: [],
  polar: [],
  baby_molly: [],
  space_molly: ['Space Molly'],
};

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

async function searchEbay(base, token, { q, aspectFilter, limit = 12 }) {
  const params = new URLSearchParams({
    q,
    limit: String(limit),
    category_ids: CANONICAL_EBAY_BROWSE_CATEGORY_ID,
  });
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
    return { ok: false, total: 0, titles: [], error: payload.errors?.[0]?.message ?? `HTTP ${res.status}` };
  }
  const titles = (payload.itemSummaries ?? []).map((r) => r.title ?? '').filter(Boolean);
  return { ok: true, total: payload.total ?? titles.length, titles };
}

function norm(s) {
  return s.trim().toUpperCase().replace(/\s+/g, ' ');
}

function titleHits(title, tokens) {
  const t = norm(title);
  return tokens.filter((tok) => tok && t.includes(norm(tok)));
}

function buildQueries(target) {
  const seeds = new Set();
  const brand = 'pop mart';
  seeds.add(`${brand} ${target.displayName}`);
  seeds.add(`${brand} ${target.displayName} blind box`);
  for (const alias of target.aliases) {
    seeds.add(`${brand} ${alias}`);
    seeds.add(`${brand} ${alias} blind box`);
  }
  for (const hint of target.seriesHints) {
    seeds.add(`${brand} ${hint}`);
    seeds.add(hint);
    seeds.add(`${hint} blind box`);
    seeds.add(`${hint} pop mart`);
  }
  seeds.add(target.displayName);
  seeds.add(`${target.displayName} blind box`);
  return [...seeds];
}

function buildTitleTokens(target) {
  const tokens = new Set([target.displayName, ...target.aliases, ...target.seriesHints]);
  return [...tokens];
}

async function main() {
  const { token, base } = await getToken();
  const report = [];

  for (const target of TARGETS) {
    console.log(`\n=== ${target.displayName} (${target.id}) ===`);
    const titleTokens = buildTitleTokens(target);
    const queries = buildQueries(target);
    const queryResults = [];

    for (const q of queries) {
      const page = await searchEbay(base, token, { q });
      const hits = page.titles.map((title) => ({
        title,
        matched: titleHits(title, titleTokens),
      }));
      const strongHits = hits.filter((h) => h.matched.length >= 1);
      queryResults.push({
        q,
        total: page.total,
        strongMatchCount: strongHits.length,
        sampleTitles: page.titles.slice(0, 5),
        topMatchedTitles: strongHits.slice(0, 3).map((h) => h.title),
      });
      if (page.total > 0 && strongHits.length >= 4) {
        console.log(`  ✓ q="${q}" total=${page.total} matches=${strongHits.length}`);
        if (strongHits[0]) console.log(`    e.g. ${strongHits[0].title.slice(0, 85)}`);
      }
      await sleep(200);
    }

    const characterTests = [];
    for (const character of CHARACTER_CANDIDATES[target.id] ?? []) {
      const q = `pop mart ${target.displayName}`;
      const aspectFilter = `categoryId:${CANONICAL_EBAY_BROWSE_CATEGORY_ID},Character:{${character}}`;
      const page = await searchEbay(base, token, { q, aspectFilter });
      const strong = page.titles.filter((t) => titleHits(t, titleTokens).length > 0).length;
      characterTests.push({ character, q, aspectFilter, total: page.total, strongMatchCount: strong, sampleTitles: page.titles.slice(0, 3) });
      console.log(`  facet Character=${character} total=${page.total} strong=${strong}`);
      await sleep(200);
    }

    const ranked = [...queryResults].sort(
      (a, b) => b.strongMatchCount - a.strongMatchCount || b.total - a.total,
    );
    const best = ranked.find((r) => r.strongMatchCount >= 4) ?? ranked.find((r) => r.total >= 6) ?? ranked[0];

    report.push({
      ipId: target.id,
      appTaxonomyName: target.displayName,
      bestQuery: best?.q,
      bestTotal: best?.total,
      bestStrongMatches: best?.strongMatchCount,
      topQueries: ranked.slice(0, 8),
      characterTests,
      recommendedTitleTokens: titleTokens,
    });
  }

  const out = path.join(__dirname, 'sparse-popmart-ip-probe.json');
  fs.writeFileSync(out, JSON.stringify({ fetchedAt: new Date().toISOString(), report }, null, 2));
  console.log(`\nWrote ${out}`);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});

/**
 * One-off / maintenance: fetch eBay Browse ASPECT_REFINEMENTS for category 19007
 * and compare with gateway taxonomy mappings.
 *
 * Usage (from functions/):
 *   node tools/fetch-ebay-aspect-refinements.mjs
 *
 * Loads env from .env.blindbox-collection (gitignored).
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const envPath = path.join(__dirname, '..', '.env.blindbox-collection');
if (fs.existsSync(envPath)) {
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

const CATEGORY_ID = process.env.EBAY_BROWSE_CATEGORY_ID?.trim() || '261068';
const DISCOVER_Q =
  process.env.EBAY_DISCOVER_QUERY?.trim() || 'blind box vinyl figure';

const PROBE_QUERIES = [
  { label: 'discover', q: DISCOVER_Q },
  { label: 'pop_mart', q: 'pop mart blind box' },
  { label: 'labubu', q: 'labubu pop mart' },
  { label: 'sonny_angel', q: 'sonny angel blind box' },
  { label: 'smiski', q: 'smiski figure' },
  { label: 'cureplaneta', q: 'cureplaneta baby three' },
  { label: 'rolife', q: 'rolife nanci blind box' },
  { label: 'toptoy', q: 'toptoy blind box' },
  { label: 'tntspace', q: 'tnt space blind box' },
  { label: 'finding_unicorn', q: 'finding unicorn farmer bob' },
  { label: 'skullpanda', q: 'skullpanda pop mart' },
  { label: 'hirono', q: 'hirono pop mart' },
];

async function getToken() {
  const clientId = process.env.EBAY_CLIENT_ID?.trim();
  const clientSecret = process.env.EBAY_CLIENT_SECRET?.trim();
  if (!clientId || !clientSecret) {
    throw new Error('EBAY_CLIENT_ID / EBAY_CLIENT_SECRET missing');
  }
  const env = (process.env.EBAY_ENV ?? 'sandbox').trim().toLowerCase();
  const base =
    env === 'production'
      ? 'https://api.ebay.com'
      : 'https://api.sandbox.ebay.com';
  const credentials = Buffer.from(`${clientId}:${clientSecret}`, 'utf8').toString(
    'base64',
  );
  const body = new URLSearchParams({
    grant_type: 'client_credentials',
    scope:
      process.env.EBAY_OAUTH_SCOPE?.trim() ||
      'https://api.ebay.com/oauth/api_scope',
  });
  const res = await fetch(`${base}/identity/v1/oauth2/token`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
      Authorization: `Basic ${credentials}`,
    },
    body: body.toString(),
  });
  if (!res.ok) throw new Error(`OAuth ${res.status}: ${await res.text()}`);
  const payload = await res.json();
  return { token: payload.access_token, base };
}

async function fetchAspectRefinements(base, token, q) {
  const params = new URLSearchParams({
    q,
    category_ids: CATEGORY_ID,
    limit: '1',
    fieldgroups: 'ASPECT_REFINEMENTS',
  });
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
  const text = await res.text();
  if (!res.ok) {
    return { ok: false, status: res.status, body: text, q };
  }
  return { ok: true, payload: JSON.parse(text), q };
}

function normalizeName(s) {
  return String(s ?? '')
    .trim()
    .toLowerCase()
    .replace(/\s+/g, ' ');
}

function collectAspectMap(refinement) {
  const map = new Map();
  const distributions = refinement?.aspectDistributions;
  if (!Array.isArray(distributions)) return map;
  for (const aspect of distributions) {
    const name = aspect.localizedAspectName?.trim();
    if (!name) continue;
    const values = [];
    for (const row of aspect.aspectValueDistributions ?? []) {
      const v = row.localizedAspectValue?.trim();
      const count = row.matchCount ?? 0;
      if (v) values.push({ value: v, matchCount: count });
    }
    values.sort((a, b) => b.matchCount - a.matchCount);
    map.set(name, values);
  }
  return map;
}

function mergeAspectMaps(target, source) {
  for (const [name, values] of source) {
    const existing = target.get(name) ?? [];
    const byNorm = new Map(existing.map((v) => [normalizeName(v.value), v]));
    for (const row of values) {
      const key = normalizeName(row.value);
      const prev = byNorm.get(key);
      if (!prev || row.matchCount > prev.matchCount) {
        byNorm.set(key, row);
      }
    }
    target.set(name, [...byNorm.values()].sort((a, b) => b.matchCount - a.matchCount));
  }
}

function findMatch(values, needle) {
  const n = normalizeName(needle);
  const exact = values.find((v) => normalizeName(v.value) === n);
  if (exact) return { kind: 'exact', ...exact };
  const contains = values.find(
    (v) =>
      normalizeName(v.value).includes(n) || n.includes(normalizeName(v.value)),
  );
  if (contains) return { kind: 'fuzzy', ...contains };
  return null;
}

// Taxonomy mirrors composeBrowseQuery.ts
const TAXONOMY_BRANDS = [
  { id: 'pop_mart', displayName: 'POP MART', ebayAspectBrand: 'POP MART' },
  {
    id: 'dreams_inc',
    displayName: 'Dreams Inc.',
    ebayAspectBrands: ['Sonny Angel', 'Smiski'],
  },
  { id: 'rolife', displayName: 'Rolife', ebayAspectBrand: 'Rolife' },
  {
    id: 'finding_unicorn',
    displayName: 'Finding Unicorn',
    ebayAspectBrand: 'Finding Unicorn',
  },
  { id: 'tntspace', displayName: 'TNT SPACE', ebayAspectBrand: 'TNT SPACE' },
  { id: 'toptoy', displayName: 'TOPTOY', ebayAspectBrand: 'TOPTOY' },
  { id: 'dpl', displayName: 'DPL', ebayAspectBrand: 'Cureplaneta' },
];

const TAXONOMY_IPS = [
  { id: 'the_monsters', brandId: 'pop_mart', displayName: 'THE MONSTERS', aliases: ['LABUBU'], aspect: 'Character', token: 'LABUBU' },
  { id: 'hirono', brandId: 'pop_mart', displayName: 'Hirono', aliases: ['HIRONO'], aspect: 'Character', token: 'HIRONO' },
  { id: 'skullpanda', brandId: 'pop_mart', displayName: 'Skullpanda', aliases: ['SKULLPANDA'], aspect: 'Character', token: 'SKULLPANDA' },
  { id: 'crybaby', brandId: 'pop_mart', displayName: 'Crybaby', aliases: ['CRYBABY'], aspect: 'Character', token: 'CRYBABY' },
  { id: 'dimoo', brandId: 'pop_mart', displayName: 'Dimoo', aliases: ['DIMOO'], aspect: 'Character', token: 'DIMOO' },
  { id: 'molly', brandId: 'pop_mart', displayName: 'Molly', aliases: ['MOLLY'], aspect: 'Character', token: 'MOLLY' },
  { id: 'peach_riot', brandId: 'pop_mart', displayName: 'Peach Riot', aliases: ['PEACH RIOT'], aspect: 'Character', token: 'PEACH RIOT' },
  { id: 'nyota', brandId: 'pop_mart', displayName: 'Nyota', aliases: ['NYOTA'], aspect: 'Character', token: 'NYOTA' },
  { id: 'pucky', brandId: 'pop_mart', displayName: 'Pucky', aliases: ['PUCKY'], aspect: 'Character', token: 'PUCKY' },
  { id: 'hacipupu', brandId: 'pop_mart', displayName: 'Hacipupu', aliases: ['HACIPUPU'], aspect: 'Character', token: 'HACIPUPU' },
  { id: 'sweet_bean', brandId: 'pop_mart', displayName: 'Sweet Bean', aliases: ['SWEET BEAN'], aspect: 'Character', token: 'SWEET BEAN' },
  { id: 'azura', brandId: 'pop_mart', displayName: 'Azura', aliases: ['AZURA'], aspect: 'Character', token: 'AZURA' },
  { id: 'duckoo', brandId: 'pop_mart', displayName: 'Duckoo', aliases: ['DUCKOO'], aspect: 'Character', token: 'DUCKOO' },
  { id: 'zsiga', brandId: 'pop_mart', displayName: 'Zsiga', aliases: ['ZSIGA'], aspect: 'Character', token: 'ZSIGA' },
  { id: 'sonny_angel', brandId: 'dreams_inc', displayName: 'Sonny Angel', aspect: 'Brand', token: 'Sonny Angel' },
  { id: 'smiski', brandId: 'dreams_inc', displayName: 'Smiski', aspect: 'Brand', token: 'Smiski' },
  { id: 'nanci', brandId: 'rolife', displayName: 'Nanci', aliases: ['NANCI'], aspect: 'Character', token: 'NANCI' },
  { id: 'zzoton', brandId: 'finding_unicorn', displayName: 'Zzoton', aliases: ['ZZOTON'], aspect: 'Character', token: 'ZZOTON' },
  { id: 'farmer_bob', brandId: 'finding_unicorn', displayName: 'Farmer Bob', aliases: ['FARMER BOB'], aspect: 'Character', token: 'FARMER BOB' },
  { id: 'rayan', brandId: 'tntspace', displayName: 'Rayan', aliases: ['RAYAN'], aspect: 'Character', token: 'RAYAN' },
  { id: 'nommi', brandId: 'toptoy', displayName: 'Nommi', aliases: ['NOMMI'], aspect: 'Character', token: 'NOMMI' },
  { id: 'baby_three', brandId: 'dpl', displayName: 'Baby Three', aliases: ['BABY THREE'], aspect: 'Character', token: 'BABY THREE' },
];

async function main() {
  const { token, base } = await getToken();
  const merged = new Map();
  const probeResults = [];

  for (const probe of PROBE_QUERIES) {
    const result = await fetchAspectRefinements(base, token, probe.q);
    probeResults.push({ label: probe.label, ...result });
    if (result.ok) {
      mergeAspectMaps(merged, collectAspectMap(result.payload.refinement));
    }
    await new Promise((r) => setTimeout(r, 200));
  }

  const aspectNames = [...merged.keys()].sort();
  const outPath = path.join(__dirname, 'ebay-aspect-refinements-19007.json');
  const exportData = {
    fetchedAt: new Date().toISOString(),
    categoryId: CATEGORY_ID,
    marketplace: process.env.EBAY_MARKETPLACE_ID?.trim() || 'EBAY_US',
    probes: PROBE_QUERIES.map((p) => p.label),
    aspectNames,
    aspects: Object.fromEntries(
      [...merged.entries()].map(([k, v]) => [
        k,
        v.map((row) => ({ value: row.value, matchCount: row.matchCount })),
      ]),
    ),
  };
  fs.writeFileSync(outPath, JSON.stringify(exportData, null, 2));

  console.log('=== eBay ASPECT_REFINEMENTS (merged, category', CATEGORY_ID, ') ===\n');
  console.log('Aspect names:', aspectNames.join(', ') || '(none)');
  console.log('Saved:', outPath, '\n');

  for (const name of ['Brand', 'Character', 'Franchise', 'Series', 'Type', 'Material']) {
    const rows = merged.get(name);
    if (!rows?.length) continue;
    console.log(`--- ${name} (top 40 by matchCount) ---`);
    for (const row of rows.slice(0, 40)) {
      console.log(`  ${row.matchCount}\t${row.value}`);
    }
    console.log('');
  }

  const brandValues = merged.get('Brand') ?? [];
  const characterValues = merged.get('Character') ?? [];
  const franchiseValues = merged.get('Franchise') ?? [];

  console.log('=== TAXONOMY vs eBay Brand ===\n');
  console.log('brandId\tourValue\tstatus\teBayMatch\tmatchCount');
  for (const brand of TAXONOMY_BRANDS) {
    const values = brand.ebayAspectBrands ?? [brand.ebayAspectBrand ?? brand.displayName];
    for (const v of values) {
      const m = findMatch(brandValues, v);
      console.log(
        `${brand.id}\t${v}\t${m ? m.kind : 'MISSING'}\t${m?.value ?? '-'}\t${m?.matchCount ?? 0}`,
      );
    }
  }

  console.log('\n=== TAXONOMY IP vs eBay Character/Brand/Franchise ===\n');
  console.log('ipId\texpectedAspect\ttoken\tstatus\tbestMatch\tmatchCount');
  for (const ip of TAXONOMY_IPS) {
    const pool =
      ip.aspect === 'Brand'
        ? brandValues
        : [...characterValues, ...franchiseValues];
    const m = findMatch(pool, ip.token);
    console.log(
      `${ip.id}\t${ip.aspect}\t${ip.token}\t${m ? m.kind : 'MISSING'}\t${m?.value ?? '-'}\t${m?.matchCount ?? 0}`,
    );
    if (ip.displayName !== ip.token) {
      const line = findMatch(franchiseValues, ip.displayName);
      if (line) {
        console.log(
          `${ip.id}\tFranchise\t${ip.displayName}\t${line.kind}\t${line.value}\t${line.matchCount}`,
        );
      }
    }
  }

  const failed = probeResults.filter((p) => !p.ok);
  if (failed.length) {
    console.log('\n=== Failed probes ===');
    for (const f of failed) {
      console.log(f.label, f.status, f.body?.slice(0, 200));
    }
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});

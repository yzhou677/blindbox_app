#!/usr/bin/env node
/**
 * Pre-push curation gate: seed validation + live URL probes.
 *
 * Does NOT discover new drops (no scraper). Use after editing popmart_us.seed.json.
 *
 * Usage (repo root):
 *   node tools/official_feed/curate_check.mjs
 *   node tools/official_feed/curate_check.mjs tools/official_feed/popmart_us.seed.json
 *
 * Exit 0 — validation OK and all probes passed (warnings may still print).
 * Exit 1 — validation errors and/or failed probes (do not push until fixed).
 */
import { readFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  isPopMartUsNumericProductUrl,
  parseHttpsUrl,
  validateOfficialFeedSeed,
} from './seed_validation.mjs';

const __dirname = dirname(fileURLToPath(import.meta.url));
const REQUEST_TIMEOUT_MS = 15_000;
const USER_AGENT = 'Mozilla/5.0 (compatible; ShelfyOfficialFeedCurateCheck/1.0)';

/**
 * @param {string} url
 * @returns {Promise<{ ok: boolean, status?: number, redirect?: string|null, numericId?: boolean, spaShell?: boolean, error?: string }>}
 */
async function probeOfficialUrl(url) {
  try {
    const res = await fetch(url, {
      method: 'GET',
      redirect: 'manual',
      headers: { 'User-Agent': USER_AGENT },
      signal: AbortSignal.timeout(REQUEST_TIMEOUT_MS),
    });
    const loc = res.headers.get('location');
    const body = await res.text();
    const parsed = parseHttpsUrl(url);
    const numericId =
      parsed != null &&
      parsed.pathname.startsWith('/us/products/') &&
      isPopMartUsNumericProductUrl(parsed);
    const spaShell = body.length < 8000;
    const badCopy =
      body.includes('not available') ||
      body.includes('BACK TO HOMEPAGE') ||
      body.includes('strconv.ParseUint');

    const ok =
      (res.status === 200 || res.status === 304) &&
      !badCopy &&
      (numericId || !parsed?.pathname.startsWith('/us/products/'));

    return {
      ok,
      status: res.status,
      redirect: loc,
      numericId,
      spaShell,
      ...(badCopy ? { error: 'page body suggests error or invalid product id' } : {}),
    };
  } catch (e) {
    return { ok: false, error: e instanceof Error ? e.message : String(e) };
  }
}

/**
 * @param {string} url
 */
async function probeImageUrl(url) {
  try {
    const res = await fetch(url, {
      method: 'HEAD',
      redirect: 'follow',
      headers: { 'User-Agent': USER_AGENT },
      signal: AbortSignal.timeout(REQUEST_TIMEOUT_MS),
    });
    return { ok: res.status >= 200 && res.status < 400, status: res.status };
  } catch (e) {
    return { ok: false, error: e instanceof Error ? e.message : String(e) };
  }
}

async function main() {
  const seedPath = resolve(process.argv[2] ?? join(__dirname, 'popmart_us.seed.json'));
  const seed = JSON.parse(readFileSync(seedPath, 'utf8'));

  console.log(`\nOfficial feed curate check — ${seedPath}\n`);

  const validation = validateOfficialFeedSeed(seed);
  for (const w of validation.warnings) console.warn(`warn: ${w}`);
  if (!validation.ok) {
    console.error('Seed validation failed:');
    for (const e of validation.errors) console.error(`  error: ${e}`);
    console.error('\nFix seed JSON before push. See tools/official_feed/README.md\n');
    process.exit(1);
  }
  console.log(`OK: seed validation (${seed.items?.length ?? 0} items)\n`);

  const items = seed.items ?? [];
  let probeFailures = 0;

  for (let i = 0; i < items.length; i++) {
    const item = items[i];
    const label = item.id?.trim() ?? `items[${i}]`;
    const status = item.status?.trim() ?? 'active';
    if (status !== 'active') {
      console.log(`[skip] ${label} — status="${status}"`);
      continue;
    }

    const officialUrl = item.officialUrl?.trim();
    const imageUrl = item.imageUrl?.trim();

    console.log(`--- ${label} ---`);
    console.log(`  title: ${item.title?.trim() ?? '(missing)'}`);

    if (officialUrl) {
      const official = await probeOfficialUrl(officialUrl);
      if (official.ok) {
        const hints = [
          official.status != null ? `HTTP ${official.status}` : null,
          official.numericId === false ? 'non-numeric /us/products/ path' : null,
          official.spaShell ? 'short HTML (SPA shell — open in browser)' : null,
        ].filter(Boolean);
        console.log(`  officialUrl: OK ${officialUrl}`);
        if (hints.length) console.log(`    note: ${hints.join('; ')}`);
      } else {
        probeFailures++;
        console.error(`  officialUrl: FAIL ${officialUrl}`);
        if (official.status != null) console.error(`    status: ${official.status}`);
        if (official.redirect) console.error(`    redirect: ${official.redirect}`);
        if (official.error) console.error(`    ${official.error}`);
      }
    }

    if (imageUrl) {
      const image = await probeImageUrl(imageUrl);
      if (image.ok) {
        console.log(`  imageUrl: OK (${image.status ?? 'HEAD'})`);
      } else {
        probeFailures++;
        console.error(`  imageUrl: FAIL ${imageUrl}`);
        if (image.status != null) console.error(`    status: ${image.status}`);
        if (image.error) console.error(`    ${image.error}`);
      }
    }
  }

  const retired = Array.isArray(seed.retiredItemIds) ? seed.retiredItemIds : [];
  if (retired.length > 0) {
    console.log(`\nretiredItemIds (${retired.length}): will archive on push`);
    for (const id of retired) console.log(`  - ${id}`);
  }

  console.log('');
  if (probeFailures > 0) {
    console.error(
      `Curate check failed: ${probeFailures} probe(s). Fix URLs/images, re-run curate_check, then push.\n`,
    );
    process.exit(1);
  }

  console.log('Curate check passed. Safe to run:');
  console.log('  node tools/official_feed/push_official_feed.mjs\n');
  console.log(
    'Note: this does not ship a new APK — Firestore push only. Users see updates after app restart.\n',
  );
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});

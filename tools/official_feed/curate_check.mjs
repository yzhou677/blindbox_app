#!/usr/bin/env node
/**
 * Pre-push curation gate: schema validation + live URL/image probes.
 *
 * Does NOT discover new drops (no scraper). Use after editing popmart_us.seed.json.
 *
 * Usage (repo root):
 *   node tools/official_feed/curate_check.mjs
 *   node tools/official_feed/curate_check.mjs tools/official_feed/popmart_us.seed.json
 *   node tools/official_feed/curate_check.mjs --strict
 *
 * Exit 0 — no ERRORS (WARNINGS fail only with --strict).
 * Exit 1 — ERRORS and/or --strict warnings (do not push until fixed).
 */
import { readFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  partitionCurationIssues,
  printCurationReport,
  validateOfficialFeedCuration,
} from './official_feed_curation.mjs';
import { validateOfficialFeedSeed } from './seed_validation.mjs';

const __dirname = dirname(fileURLToPath(import.meta.url));

function parseArgs(argv) {
  const strict = argv.includes('--strict');
  const seedPath = resolve(
    argv.find((a) => !a.startsWith('--')) ?? join(__dirname, 'popmart_us.seed.json'),
  );
  return { strict, seedPath };
}

async function main() {
  const { strict, seedPath } = parseArgs(process.argv.slice(2));
  const seed = JSON.parse(readFileSync(seedPath, 'utf8'));

  console.log(`\nOfficial feed curate check — ${seedPath}${strict ? ' (--strict)' : ''}\n`);

  const schema = validateOfficialFeedSeed(seed);
  const schemaErrors = schema.errors.map((message) => ({ level: 'error', message }));
  const schemaWarnings = schema.warnings.map((message) => ({ level: 'warning', message }));

  if (schema.ok) {
    console.log(`OK: schema validation (${seed.items?.length ?? 0} items)\n`);
  } else {
    console.log(`Schema validation: ${schema.errors.length} error(s)\n`);
  }

  console.log('Running live curation probes…\n');

  const curation = await validateOfficialFeedCuration(seed, { strict });

  const merged = partitionCurationIssues([
    ...schemaErrors,
    ...schemaWarnings,
    ...curation.issues,
  ]);

  printCurationReport(merged);

  const retired = Array.isArray(seed.retiredItemIds) ? seed.retiredItemIds : [];
  if (retired.length > 0) {
    console.log(`retiredItemIds (${retired.length}): will archive on push`);
    for (const id of retired) console.log(`  - ${id}`);
    console.log('');
  }

  const failed =
    !schema.ok ||
    !curation.ok ||
    merged.errors.length > 0 ||
    (strict && merged.warnings.length > 0);

  if (failed) {
    if (strict && merged.errors.length === 0 && merged.warnings.length > 0) {
      console.error('Curate check failed (--strict): resolve WARNINGS or fix seed.\n');
    } else {
      console.error('Curate check failed: resolve ERRORS before push.\n');
    }
    process.exit(1);
  }

  console.log('Curate check passed. Safe to run:');
  console.log('  node tools/official_feed/push_official_feed.mjs\n');
  console.log(
    'Note: push runs the same curation gates. No new APK — Firestore only.\n',
  );
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});

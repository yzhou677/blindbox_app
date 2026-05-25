#!/usr/bin/env node
/**
 * Validate official feed seed without pushing.
 * Usage: node tools/official_feed/validate_seed.mjs [seed.json]
 */
import { readFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { validateOfficialFeedSeed } from './seed_validation.mjs';

const __dirname = dirname(fileURLToPath(import.meta.url));
const seedPath = resolve(process.argv[2] ?? join(__dirname, 'popmart_us.seed.json'));
const seed = JSON.parse(readFileSync(seedPath, 'utf8'));
const result = validateOfficialFeedSeed(seed);

for (const w of result.warnings) console.warn(`warn: ${w}`);
if (result.ok) {
  console.log(`OK: ${seed.items.length} items in ${seedPath}`);
  process.exit(0);
}
for (const e of result.errors) console.error(`error: ${e}`);
process.exit(1);

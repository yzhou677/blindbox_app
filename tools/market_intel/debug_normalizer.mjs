#!/usr/bin/env node
/**
 * DEV ONLY — Debug title normalization and exclude detection.
 *
 * Usage (from repo root):
 *   node tools/market_intel/debug_normalizer.mjs
 *   node tools/market_intel/debug_normalizer.mjs path/to/titles.txt
 *
 * Reads one listing title per line. Blank lines and # comments are skipped.
 */

import { readFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

import {
  findExcludeTerm,
  normalizeMarketTitle,
} from './_title_normalizer.mjs';

const __dirname = dirname(fileURLToPath(import.meta.url));
const defaultTitlesPath = join(__dirname, 'sample_titles.txt');

function loadTitles(path) {
  const raw = readFileSync(path, 'utf8');
  return raw
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter((line) => line.length > 0 && !line.startsWith('#'));
}

function printTitleReport(title) {
  const normalized = normalizeMarketTitle(title);
  const excludeMatch = findExcludeTerm(title);
  const excluded = excludeMatch !== null;
  const excludeTerm = excludeMatch?.term ?? '(none)';

  console.log('--------------------------------');
  console.log(`RAW: ${title}`);
  console.log(`NORMALIZED: ${normalized}`);
  console.log(`EXCLUDED: ${excluded}`);
  console.log(`EXCLUDE_TERM: ${excludeTerm}`);
}

function main() {
  const titlesPath = resolve(process.argv[2] ?? defaultTitlesPath);
  const titles = loadTitles(titlesPath);

  if (titles.length === 0) {
    console.error(`No titles found in ${titlesPath}`);
    process.exit(1);
  }

  for (const title of titles) {
    printTitleReport(title);
  }
}

main();

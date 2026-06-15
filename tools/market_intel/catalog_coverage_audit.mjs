#!/usr/bin/env node
/**
 * Market Intelligence — full catalog coverage audit (Sprint 2 Step 3D).
 *
 * Usage (from repo root):
 *   node tools/market_intel/catalog_coverage_audit.mjs
 *   node tools/market_intel/catalog_coverage_audit.mjs --json-only
 *
 * Writes:
 *   tools/market_intel/CATALOG_COVERAGE_REPORT.md
 *   tools/market_intel/catalog_coverage_report.json
 */

import { writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

import {
  auditCatalogCoverage,
  formatCoverageReportMarkdown,
} from './_catalog_coverage_audit.mjs';

const __dirname = dirname(fileURLToPath(import.meta.url));
const jsonOnly = process.argv.includes('--json-only');

const audit = auditCatalogCoverage();
const markdown = formatCoverageReportMarkdown(audit);
const jsonPath = join(__dirname, 'catalog_coverage_report.json');
const markdownPath = join(__dirname, 'CATALOG_COVERAGE_REPORT.md');

writeFileSync(jsonPath, `${JSON.stringify(audit, null, 2)}\n`, 'utf8');

if (!jsonOnly) {
  writeFileSync(markdownPath, `${markdown}\n`, 'utf8');
}

console.error('CATALOG COVERAGE AUDIT');
console.error('');
console.error(`Total figures: ${audit.totalFigures}`);
console.error(`Matchable: ${audit.distribution.MATCHABLE} (${audit.percentages.MATCHABLE}%)`);
console.error(
  `Matcher risk: ${audit.distribution.MATCHER_RISK} (${audit.percentages.MATCHER_RISK}%)`,
);
console.error(
  `No search terms: ${audit.distribution.NO_SEARCH_TERMS} (${audit.percentages.NO_SEARCH_TERMS}%)`,
);
console.error(`Disabled: ${audit.distribution.DISABLED}`);
console.error(`Unknown: ${audit.distribution.UNKNOWN}`);
console.error('');
console.error(`Wrote ${jsonPath}`);
if (!jsonOnly) {
  console.error(`Wrote ${markdownPath}`);
}

if (!jsonOnly) {
  console.log('');
  console.log(markdown);
}

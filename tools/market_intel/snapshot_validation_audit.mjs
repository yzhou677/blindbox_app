#!/usr/bin/env node
/**
 * Market Intelligence — snapshot validation audit runner (Sprint 2 Step 4C).
 *
 * Usage (from repo root):
 *   node tools/market_intel/snapshot_validation_audit.mjs
 *   node tools/market_intel/snapshot_validation_audit.mjs --json-only
 *
 * Writes:
 *   tools/market_intel/SNAPSHOT_VALIDATION_REPORT.md
 *   tools/market_intel/snapshot_validation_report.json
 */

import { writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

import {
  formatValidationReportMarkdown,
  runSnapshotValidationAudit,
  serializeValidationAuditJson,
} from './_snapshot_validation_audit.mjs';

const __dirname = dirname(fileURLToPath(import.meta.url));
const jsonOnly = process.argv.includes('--json-only');

process.env.EBAY_FETCH_MODE = 'fixture';

const audit = await runSnapshotValidationAudit({ fetchMode: 'fixture' });
const markdown = formatValidationReportMarkdown(audit);
const json = serializeValidationAuditJson(audit);

const jsonPath = join(__dirname, 'snapshot_validation_report.json');
const markdownPath = join(__dirname, 'SNAPSHOT_VALIDATION_REPORT.md');

writeFileSync(jsonPath, `${JSON.stringify(json, null, 2)}\n`, 'utf8');

if (!jsonOnly) {
  writeFileSync(markdownPath, `${markdown}\n`, 'utf8');
}

console.error('SNAPSHOT VALIDATION AUDIT');
console.error('');
console.error(`Figures reviewed: ${audit.sampleSize}`);
console.error(`Status: ${audit.status}`);
console.error(`PASS: ${audit.counts.PASS}`);
console.error(`WARNING: ${audit.counts.WARNING}`);
console.error(`FAIL: ${audit.counts.FAIL}`);
console.error(`Production readiness: ${audit.productionReadiness}`);
console.error('');
console.error(`Wrote ${jsonPath}`);
if (!jsonOnly) {
  console.error(`Wrote ${markdownPath}`);
}

if (!jsonOnly) {
  console.log('');
  console.log(markdown);
}

#!/usr/bin/env node
/**
 * Market Intelligence — Matcher Generalization Simulation Audit (Sprint 2 Step 3E.1).
 *
 * Simulation ONLY. Does NOT modify production matcher behavior.
 *
 * Usage (from repo root):
 *   node tools/market_intel/matcher_generalization_simulation_audit.mjs
 *   node tools/market_intel/matcher_generalization_simulation_audit.mjs --json-only
 *
 * Writes:
 *   tools/market_intel/MATCHER_GENERALIZATION_SIMULATION_REPORT.md
 *   tools/market_intel/matcher_generalization_simulation.json
 */

import { writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

import {
  runGeneralizationSimulation,
  formatSimulationReportMarkdown,
} from './_matcher_generalization_simulation.mjs';

const __dirname = dirname(fileURLToPath(import.meta.url));
const jsonOnly = process.argv.includes('--json-only');

const simulation = runGeneralizationSimulation();
const markdown = formatSimulationReportMarkdown(simulation);

const jsonPath = join(__dirname, 'matcher_generalization_simulation.json');
const reportPath = join(__dirname, 'MATCHER_GENERALIZATION_SIMULATION_REPORT.md');

// Write JSON (always)
writeFileSync(jsonPath, `${JSON.stringify(simulation, null, 2)}\n`, 'utf8');

// Write markdown report
if (!jsonOnly) {
  writeFileSync(reportPath, `${markdown}\n`, 'utf8');
}

const total = simulation.baseline.totalFigures;
const baseMatchable = simulation.baseline.distribution.MATCHABLE;
const simMatchable =
  simulation.simulated.distribution.MATCHABLE +
  simulation.simulated.distribution.MATCHABLE_BORDERLINE;
const simMatchablePct = Math.round((simMatchable / total) * 1000) / 10;
const baseMatchablePct = simulation.baseline.percentages.MATCHABLE;

console.error('MATCHER GENERALIZATION SIMULATION');
console.error('');
console.error(`Total figures: ${total}`);
console.error('');
console.error('--- BASELINE (current matcher) ---');
console.error(`  Matchable:     ${baseMatchable} (${baseMatchablePct}%)`);
console.error(
  `  Matcher risk:  ${simulation.baseline.distribution.MATCHER_RISK} (${simulation.baseline.percentages.MATCHER_RISK}%)`,
);
console.error(
  `  No search terms: ${simulation.baseline.distribution.NO_SEARCH_TERMS} (${simulation.baseline.percentages.NO_SEARCH_TERMS}%)`,
);
console.error('');
console.error('--- SIMULATED (generalized series gate) ---');
console.error(
  `  Matchable (safe, ≥8):      ${simulation.simulated.distribution.MATCHABLE} (${simulation.simulated.percentages.MATCHABLE}%)`,
);
console.error(
  `  Matchable (borderline 4-7): ${simulation.simulated.distribution.MATCHABLE_BORDERLINE} (${simulation.simulated.percentages.MATCHABLE_BORDERLINE}%)`,
);
console.error(
  `  Combined matchable:         ${simMatchable} (${simMatchablePct}%)`,
);
console.error(
  `  Matcher risk:               ${simulation.simulated.distribution.MATCHER_RISK} (${simulation.simulated.percentages.MATCHER_RISK}%)`,
);
console.error('');
console.error('--- DELTA ---');
console.error(`  Figures upgraded: +${simulation.delta.upgradedFigures}`);
console.error(
  `  Matchable improvement: ${baseMatchable} → ${simMatchable} (+${simulation.delta.matchableAbsolute})`,
);
console.error('');
console.error(`--- RECOMMENDATION: ${simulation.recommendation.value} ---`);
console.error('');
console.error(`Wrote ${jsonPath}`);
if (!jsonOnly) {
  console.error(`Wrote ${reportPath}`);
}

if (!jsonOnly) {
  console.log('');
  console.log(markdown);
}

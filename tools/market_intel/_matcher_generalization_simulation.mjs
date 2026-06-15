/**
 * Market Intelligence — Matcher Generalization Simulation (Sprint 2 Step 3E.1).
 *
 * Simulation ONLY. Does NOT modify production matcher behavior.
 * Computes expected coverage improvement if fullSeriesRequired becomes
 * catalog-driven (extractSeriesDistinctive) instead of Big Into Energy-specific.
 *
 * Pure functions only — no I/O, network, or side effects.
 */

import { loadCatalogBundle } from './_catalog_bundle.mjs';
import { extractSeriesDistinctive } from './_search_term_derivation.mjs';
import {
  auditCatalogCoverage,
  CoverageClass,
} from './_catalog_coverage_audit.mjs';

/** Minimum phrase length for the safe series gate (no false-positive risk). */
export const SAFE_DISTINCTIVE_MIN_LENGTH = 8;

/** Minimum phrase length for borderline use (allowed with quality warning). */
export const BORDERLINE_DISTINCTIVE_MIN_LENGTH = 4;

/**
 * @typedef {'safe' | 'borderline' | 'too_short'} DistinctiveQuality
 */

/**
 * Classify the quality of a series distinctive phrase for simulation purposes.
 *
 * @param {string} phrase
 * @returns {DistinctiveQuality}
 */
export function classifyDistinctiveQuality(phrase) {
  if (!phrase || phrase.length < BORDERLINE_DISTINCTIVE_MIN_LENGTH) {
    return 'too_short';
  }
  if (phrase.length < SAFE_DISTINCTIVE_MIN_LENGTH) {
    return 'borderline';
  }
  return 'safe';
}

/**
 * @typedef {'MATCHABLE' | 'MATCHABLE_BORDERLINE' | 'MATCHER_RISK' | 'NO_SEARCH_TERMS' | 'DISABLED'} SimulatedClass
 */

/**
 * @typedef {Object} SimulatedFigureRecord
 * @property {string} figureId
 * @property {string} displayName
 * @property {string} seriesId
 * @property {string} seriesDisplayName
 * @property {string} currentClassification
 * @property {SimulatedClass} simulatedClassification
 * @property {string} simulatedPrimaryReason
 * @property {boolean} isUpgrade
 * @property {string} seriesDistinctivePhrase
 * @property {DistinctiveQuality | null} distinctiveQuality
 * @property {import('./_catalog_coverage_audit.mjs').MatcherRisk[]} remainingRisks
 */

/**
 * Simulate the coverage classification for a single figure under generalized matcher assumptions.
 *
 * @param {import('./_catalog_coverage_audit.mjs').FigureCoverageRecord} currentRecord
 * @param {ReturnType<typeof loadCatalogBundle>} bundle
 * @returns {SimulatedFigureRecord}
 */
export function simulateFigureCoverage(currentRecord, bundle) {
  const base = {
    figureId: currentRecord.figureId,
    displayName: currentRecord.displayName,
    seriesId: currentRecord.seriesId,
    seriesDisplayName: currentRecord.seriesDisplayName,
    currentClassification: currentRecord.classification,
  };

  if (
    currentRecord.classification === CoverageClass.MATCHABLE ||
    currentRecord.classification === CoverageClass.DISABLED
  ) {
    return {
      ...base,
      simulatedClassification: currentRecord.classification,
      simulatedPrimaryReason: 'unchanged — already resolved',
      isUpgrade: false,
      seriesDistinctivePhrase: '',
      distinctiveQuality: null,
      remainingRisks: [],
    };
  }

  if (currentRecord.classification === CoverageClass.NO_SEARCH_TERMS) {
    return {
      ...base,
      simulatedClassification: 'NO_SEARCH_TERMS',
      simulatedPrimaryReason: currentRecord.primaryReason,
      isUpgrade: false,
      seriesDistinctivePhrase: '',
      distinctiveQuality: null,
      remainingRisks: [],
    };
  }

  // MATCHER_RISK — simulate what happens after generalization
  const figure = bundle.figures.find((f) => f.id === currentRecord.figureId);
  const series = bundle.seriesById.get(figure?.seriesId ?? '');
  const ip = bundle.ipById.get(series?.ipId ?? figure?.ipId ?? '');

  const distinctive = extractSeriesDistinctive(series, ip);
  const quality = classifyDistinctiveQuality(distinctive);

  // Separate phrase-bias risk from other structural risks
  const phraseBiasRisks = currentRecord.matcherRisks.filter(
    (r) => r.code === 'fullSeriesPhraseBias',
  );
  const otherStructuralRisks = currentRecord.matcherRisks.filter(
    (r) => r.code !== 'fullSeriesPhraseBias',
  );

  if (phraseBiasRisks.length === 0) {
    // No phrase bias was blocking this figure; other structural risk remains
    return {
      ...base,
      simulatedClassification: 'MATCHER_RISK',
      simulatedPrimaryReason:
        currentRecord.matcherRisks[0]?.reason ?? 'unresolved structural risk',
      isUpgrade: false,
      seriesDistinctivePhrase: distinctive,
      distinctiveQuality: quality,
      remainingRisks: currentRecord.matcherRisks,
    };
  }

  if (otherStructuralRisks.length > 0) {
    // Phrase bias would be fixed, but other structural blockers remain
    return {
      ...base,
      simulatedClassification: 'MATCHER_RISK',
      simulatedPrimaryReason: otherStructuralRisks[0].reason,
      isUpgrade: false,
      seriesDistinctivePhrase: distinctive,
      distinctiveQuality: quality,
      remainingRisks: otherStructuralRisks,
    };
  }

  // Only structural blocker was fullSeriesPhraseBias — resolve based on distinctive quality
  if (quality === 'safe') {
    return {
      ...base,
      simulatedClassification: 'MATCHABLE',
      simulatedPrimaryReason: `"${distinctive}" (${distinctive.length} chars) — safe series gate`,
      isUpgrade: true,
      seriesDistinctivePhrase: distinctive,
      distinctiveQuality: quality,
      remainingRisks: currentRecord.matcherWarnings,
    };
  }

  if (quality === 'borderline') {
    return {
      ...base,
      simulatedClassification: 'MATCHABLE_BORDERLINE',
      simulatedPrimaryReason: `"${distinctive}" (${distinctive.length} chars) — borderline, needs validation`,
      isUpgrade: true,
      seriesDistinctivePhrase: distinctive,
      distinctiveQuality: quality,
      remainingRisks: [
        {
          code: 'shortSeriesDistinctive',
          reason: `distinctive phrase is only ${distinctive.length} chars — false-positive risk`,
        },
        ...currentRecord.matcherWarnings,
      ],
    };
  }

  // too_short — distinctive exists (>= 3 chars from search-term path) but < 4 chars
  return {
    ...base,
    simulatedClassification: 'MATCHER_RISK',
    simulatedPrimaryReason: `series distinctive "${distinctive}" (${distinctive.length} chars) too short for gate`,
    isUpgrade: false,
    seriesDistinctivePhrase: distinctive,
    distinctiveQuality: quality,
    remainingRisks: [
      {
        code: 'tooShortSeriesDistinctive',
        reason: `series distinctive "${distinctive}" is only ${distinctive.length} chars`,
      },
      ...currentRecord.matcherWarnings,
    ],
  };
}

/**
 * @typedef {Object} SeriesQualityRecord
 * @property {string} seriesId
 * @property {string} displayName
 * @property {string | null} ipDisplayName
 * @property {string} distinctivePhrase
 * @property {number} distinctiveLength
 * @property {DistinctiveQuality} quality
 * @property {number} figureCount
 */

/**
 * Build per-series quality analysis (series with figures only).
 *
 * @param {ReturnType<typeof loadCatalogBundle>} bundle
 * @returns {{ safe: SeriesQualityRecord[], borderline: SeriesQualityRecord[], tooShort: SeriesQualityRecord[] }}
 */
export function buildSeriesQualityAnalysis(bundle) {
  /** @type {Map<string, SeriesQualityRecord>} */
  const bySeries = new Map();

  for (const figure of bundle.figures) {
    const series = bundle.seriesById.get(figure.seriesId);
    if (!series) continue;
    const ip = bundle.ipById.get(series.ipId ?? figure.ipId ?? '');
    const distinctive = extractSeriesDistinctive(series, ip);
    const quality = classifyDistinctiveQuality(distinctive);

    if (!bySeries.has(series.id)) {
      bySeries.set(series.id, {
        seriesId: series.id,
        displayName: series.displayName ?? series.id,
        ipDisplayName: ip?.displayName ?? null,
        distinctivePhrase: distinctive,
        distinctiveLength: distinctive.length,
        quality,
        figureCount: 0,
      });
    }
    bySeries.get(series.id).figureCount += 1;
  }

  const safe = [];
  const borderline = [];
  const tooShort = [];

  for (const record of bySeries.values()) {
    if (record.quality === 'safe') {
      safe.push(record);
    } else if (record.quality === 'borderline') {
      borderline.push(record);
    } else {
      tooShort.push(record);
    }
  }

  const byLength = (a, b) => b.distinctiveLength - a.distinctiveLength;
  safe.sort(byLength);
  borderline.sort(byLength);
  tooShort.sort(byLength);

  return { safe, borderline, tooShort };
}

/**
 * @typedef {Object} RemainingRiskCategory
 * @property {string} code
 * @property {string} description
 * @property {number} figureCount
 * @property {number} seriesCount
 */

/**
 * Group remaining MATCHER_RISK figures after simulation by their primary risk code.
 *
 * @param {SimulatedFigureRecord[]} simulatedFigures
 * @returns {RemainingRiskCategory[]}
 */
export function buildRemainingRiskCategories(simulatedFigures) {
  /** @type {Map<string, { figureCount: number, seriesIds: Set<string> }>} */
  const byCode = new Map();

  const riskDescriptions = {
    tooShortSeriesDistinctive: 'Series distinctive phrase < 4 chars — cannot drive series gate',
    shortSeriesDistinctive: 'Series distinctive 4–7 chars — borderline false-positive risk',
    incompleteCatalogContext: 'Catalog joins missing brand or series row',
    ambiguousFigureName: 'Single-token figure name ≤ 5 chars with no market aliases',
    secretConsistency: 'Secret figures require chase/secret indicator in listing titles',
    siblingCollision: 'Series has many short single-token sibling names',
    limitedBrandTokens: 'Non-POP MART brand with no alias expansion',
    fullSeriesPhraseBias: 'Residual Big Into Energy phrase bias (should be 0 after generalization)',
  };

  for (const record of simulatedFigures) {
    if (
      record.simulatedClassification !== 'MATCHER_RISK' &&
      record.simulatedClassification !== 'MATCHABLE_BORDERLINE'
    ) {
      continue;
    }

    for (const risk of record.remainingRisks) {
      if (!byCode.has(risk.code)) {
        byCode.set(risk.code, { figureCount: 0, seriesIds: new Set() });
      }
      byCode.get(risk.code).figureCount += 1;
      byCode.get(risk.code).seriesIds.add(record.seriesId);
    }
  }

  return [...byCode.entries()]
    .map(([code, { figureCount, seriesIds }]) => ({
      code,
      description: riskDescriptions[code] ?? code,
      figureCount,
      seriesCount: seriesIds.size,
    }))
    .sort((a, b) => b.figureCount - a.figureCount);
}

/**
 * @typedef {Object} MatcherGeneralizationSimulation
 * @property {string} generatedAt
 * @property {object} baseline
 * @property {object} simulated
 * @property {object} delta
 * @property {object} seriesQuality
 * @property {RemainingRiskCategory[]} remainingRiskCategories
 * @property {object} recommendation
 * @property {SimulatedFigureRecord[]} figures
 */

/**
 * Run the full generalization simulation.
 *
 * @param {ReturnType<typeof loadCatalogBundle>} [bundle]
 * @returns {MatcherGeneralizationSimulation}
 */
export function runGeneralizationSimulation(bundle = loadCatalogBundle()) {
  const baselineAudit = auditCatalogCoverage(bundle);

  const simulatedFigures = baselineAudit.figures.map((record) =>
    simulateFigureCoverage(record, bundle),
  );

  const simulatedDistribution = {
    MATCHABLE: 0,
    MATCHABLE_BORDERLINE: 0,
    MATCHER_RISK: 0,
    NO_SEARCH_TERMS: 0,
    DISABLED: 0,
    UNKNOWN: 0,
  };

  for (const record of simulatedFigures) {
    const cls = record.simulatedClassification;
    if (cls in simulatedDistribution) {
      simulatedDistribution[cls] += 1;
    } else {
      simulatedDistribution.UNKNOWN += 1;
    }
  }

  const total = baselineAudit.totalFigures;

  const simulatedPercentages = {};
  for (const [key, count] of Object.entries(simulatedDistribution)) {
    simulatedPercentages[key] = total > 0 ? Math.round((count / total) * 1000) / 10 : 0;
  }

  const baseMatchable = baselineAudit.distribution.MATCHABLE;
  const simMatchable =
    simulatedDistribution.MATCHABLE + simulatedDistribution.MATCHABLE_BORDERLINE;
  const baseRisk = baselineAudit.distribution.MATCHER_RISK;
  const simRisk = simulatedDistribution.MATCHER_RISK;

  const delta = {
    matchableAbsolute: simMatchable - baseMatchable,
    matchablePercentagePts:
      Math.round((simMatchable / total - baseMatchable / total) * 1000) / 10,
    matcherRiskAbsolute: simRisk - baseRisk,
    matcherRiskPercentagePts:
      Math.round((simRisk / total - baseRisk / total) * 1000) / 10,
    upgradedFigures: simulatedFigures.filter((r) => r.isUpgrade).length,
  };

  const seriesQuality = buildSeriesQualityAnalysis(bundle);
  const remainingRiskCategories = buildRemainingRiskCategories(simulatedFigures);

  // Recommendation based on simulated matchable percentage
  const simMatchablePct = (simMatchable / total) * 100;
  let recommendationValue;
  if (simMatchablePct >= 70) {
    recommendationValue = 'HIGH VALUE';
  } else if (simMatchablePct >= 40) {
    recommendationValue = 'MEDIUM VALUE';
  } else {
    recommendationValue = 'LOW VALUE';
  }

  const recommendation = {
    value: recommendationValue,
    simulatedMatchablePct: Math.round(simMatchablePct * 10) / 10,
    baselineMatchablePct: Math.round((baseMatchable / total) * 1000) / 10,
    rationale: buildRecommendationRationale(recommendationValue, simMatchable, total, delta),
  };

  return {
    generatedAt: new Date().toISOString(),
    baseline: {
      totalFigures: total,
      distribution: baselineAudit.distribution,
      percentages: baselineAudit.percentages,
    },
    simulated: {
      totalFigures: total,
      distribution: simulatedDistribution,
      percentages: simulatedPercentages,
    },
    delta,
    seriesQuality: {
      safe: seriesQuality.safe,
      borderline: seriesQuality.borderline,
      tooShort: seriesQuality.tooShort,
    },
    remainingRiskCategories,
    recommendation,
    figures: simulatedFigures,
  };
}

/**
 * @param {string} value
 * @param {number} simMatchable
 * @param {number} total
 * @param {object} delta
 * @returns {string}
 */
function buildRecommendationRationale(value, simMatchable, total, delta) {
  const pct = Math.round((simMatchable / total) * 1000) / 10;
  const upgrade = delta.upgradedFigures;

  if (value === 'HIGH VALUE') {
    return (
      `Generalization would upgrade ${upgrade} figures and unlock ${pct}% of the catalog. ` +
      `The improvement is substantial. Implement matcher generalization as the next sprint.`
    );
  }
  if (value === 'MEDIUM VALUE') {
    return (
      `Generalization would upgrade ${upgrade} figures and unlock ${pct}% of the catalog. ` +
      `Coverage gain is meaningful but significant risk categories remain. ` +
      `Implement generalization and follow up with catalog metadata enrichment.`
    );
  }
  return (
    `Generalization would upgrade ${upgrade} figures but only reach ${pct}% matchable. ` +
    `Remaining blockers (empty/short distinctives, catalog gaps) limit the benefit. ` +
    `Address catalog metadata quality before implementing matcher generalization.`
  );
}

/**
 * Format the simulation results as a Markdown report.
 *
 * @param {MatcherGeneralizationSimulation} simulation
 * @returns {string}
 */
export function formatSimulationReportMarkdown(simulation) {
  const lines = [];
  const { baseline, simulated, delta, seriesQuality, remainingRiskCategories, recommendation } =
    simulation;

  const total = baseline.totalFigures;

  lines.push('# Matcher Generalization Simulation Report');
  lines.push('');
  lines.push(`> Generated: ${simulation.generatedAt}`);
  lines.push('> Sprint 2 Step 3E.1 — simulation only. No matcher code was changed.');
  lines.push(
    '> Simulates: `fullSeriesRequired` driven by `extractSeriesDistinctive(series, ip)` instead of hardcoded `"big into energy"` phrase.',
  );
  lines.push('');

  // --- Section 1: Current Baseline ---
  lines.push('## 1. Current Baseline');
  lines.push('');
  lines.push(`**Total catalog figures:** ${total}`);
  lines.push('');
  lines.push('| Classification | Count | % |');
  lines.push('|----------------|------:|--:|');
  for (const [key, count] of Object.entries(baseline.distribution)) {
    lines.push(`| ${key} | ${count} | ${baseline.percentages[key]}% |`);
  }
  lines.push('');
  lines.push(
    `Root cause: \`TARGET_SERIES_PHRASE = 'big into energy'\` blocks \`gate:fullSeriesRequired\` for every non–Big Into Energy figure. Only 7 figures (0.6%) are currently matchable.`,
  );
  lines.push('');

  // --- Section 2: Simulated Coverage ---
  lines.push('## 2. Simulated Coverage');
  lines.push('');
  lines.push(
    '_Simulation assumption: series gate requires `extractSeriesDistinctive(series, ip)` instead of the hardcoded phrase._',
  );
  lines.push('');
  lines.push('| Classification | Count | % |');
  lines.push('|----------------|------:|--:|');

  const simOrder = [
    'MATCHABLE',
    'MATCHABLE_BORDERLINE',
    'MATCHER_RISK',
    'NO_SEARCH_TERMS',
    'DISABLED',
    'UNKNOWN',
  ];
  for (const key of simOrder) {
    const count = simulated.distribution[key] ?? 0;
    if (count === 0) continue;
    lines.push(`| ${key} | ${count} | ${simulated.percentages[key] ?? 0}% |`);
  }
  lines.push('');
  lines.push(
    `**MATCHABLE** (safe, phrase ≥ ${simulation.figures[0] !== undefined ? 8 : 8} chars): ${simulated.distribution.MATCHABLE} figures`,
  );
  lines.push(
    `**MATCHABLE_BORDERLINE** (phrase 4–7 chars, needs validation): ${simulated.distribution.MATCHABLE_BORDERLINE} figures`,
  );
  lines.push(
    `**Combined simulated matchable:** ${simulated.distribution.MATCHABLE + simulated.distribution.MATCHABLE_BORDERLINE} / ${total} (${Math.round(((simulated.distribution.MATCHABLE + simulated.distribution.MATCHABLE_BORDERLINE) / total) * 1000) / 10}%)`,
  );
  lines.push('');

  // --- Section 3: Coverage Delta ---
  lines.push('## 3. Coverage Delta');
  lines.push('');
  lines.push('| Metric | Before | After | Change |');
  lines.push('|--------|-------:|------:|-------:|');

  const simMatchable = simulated.distribution.MATCHABLE + simulated.distribution.MATCHABLE_BORDERLINE;
  const basePct = baseline.percentages.MATCHABLE ?? 0;
  const simPct = Math.round((simMatchable / total) * 1000) / 10;
  const simMatchablePct = simPct;
  const matchableDeltaPct = Math.round((simMatchablePct - basePct) * 10) / 10;

  lines.push(
    `| MATCHABLE (combined) | ${baseline.distribution.MATCHABLE} (${basePct}%) | ${simMatchable} (${simPct}%) | **+${delta.upgradedFigures} figures** |`,
  );
  lines.push(
    `| MATCHER_RISK | ${baseline.distribution.MATCHER_RISK} (${baseline.percentages.MATCHER_RISK}%) | ${simulated.distribution.MATCHER_RISK} (${simulated.percentages.MATCHER_RISK}%) | ${delta.matcherRiskAbsolute} |`,
  );
  lines.push(
    `| NO_SEARCH_TERMS | ${baseline.distribution.NO_SEARCH_TERMS} (${baseline.percentages.NO_SEARCH_TERMS}%) | ${simulated.distribution.NO_SEARCH_TERMS} (${simulated.percentages.NO_SEARCH_TERMS ?? 0}%) | 0 |`,
  );
  lines.push('');
  lines.push(
    `**Absolute improvement:** +${delta.matchableAbsolute} matchable figures (+${matchableDeltaPct} percentage points)`,
  );
  lines.push(`**Figures upgraded by generalization:** ${delta.upgradedFigures}`);
  lines.push('');

  // --- Section 4: Top Remaining Risk Categories ---
  lines.push('## 4. Top Remaining Risk Categories');
  lines.push('');
  lines.push(
    'Figures remaining in MATCHER_RISK or MATCHABLE_BORDERLINE after simulation, grouped by primary risk code:',
  );
  lines.push('');
  lines.push('| Risk Code | Description | Figures | Series |');
  lines.push('|-----------|-------------|--------:|-------:|');
  for (const cat of remainingRiskCategories) {
    lines.push(`| \`${cat.code}\` | ${cat.description} | ${cat.figureCount} | ${cat.seriesCount} |`);
  }
  if (remainingRiskCategories.length === 0) {
    lines.push('| — | No remaining risks | 0 | 0 |');
  }
  lines.push('');

  // --- Section 5: Series Quality Analysis ---
  lines.push('## 5. Series Quality Analysis');
  lines.push('');
  lines.push(
    `Based on \`extractSeriesDistinctive\` output across all ${
      seriesQuality.safe.length + seriesQuality.borderline.length + seriesQuality.tooShort.length
    } series:`,
  );
  lines.push('');
  lines.push(
    `| Quality | Series count | Figures covered | Phrase length |`,
  );
  lines.push('|---------|----------:|----------:|---------------|');
  const safeCount = seriesQuality.safe.reduce((s, r) => s + r.figureCount, 0);
  const borderlineCount = seriesQuality.borderline.reduce((s, r) => s + r.figureCount, 0);
  const tooShortCount = seriesQuality.tooShort.reduce((s, r) => s + r.figureCount, 0);
  lines.push(`| Safe (≥ 8 chars) | ${seriesQuality.safe.length} | ${safeCount} | ≥ 8 |`);
  lines.push(`| Borderline (4–7 chars) | ${seriesQuality.borderline.length} | ${borderlineCount} | 4–7 |`);
  lines.push(`| Too Short (< 4 chars) | ${seriesQuality.tooShort.length} | ${tooShortCount} | < 4 |`);
  lines.push('');

  lines.push('### Safe Distinctive Series (phrase ≥ 8 chars)');
  lines.push('');
  lines.push('These series would satisfy `gate:fullSeriesRequired` after generalization.');
  lines.push('');
  lines.push('| Series | Distinctive Phrase | Length | Figures |');
  lines.push('|--------|--------------------|-------:|--------:|');
  for (const s of seriesQuality.safe.slice(0, 30)) {
    lines.push(
      `| ${s.displayName} | \`${s.distinctivePhrase}\` | ${s.distinctiveLength} | ${s.figureCount} |`,
    );
  }
  if (seriesQuality.safe.length > 30) {
    lines.push(`| _…and ${seriesQuality.safe.length - 30} more safe series_ | | | |`);
  }
  lines.push('');

  if (seriesQuality.borderline.length > 0) {
    lines.push('### Borderline Distinctive Series (phrase 4–7 chars)');
    lines.push('');
    lines.push(
      'These series would be classified MATCHABLE_BORDERLINE — simulated matchable with a `shortSeriesDistinctive` warning.',
    );
    lines.push('');
    lines.push('| Series | Distinctive Phrase | Length | Figures |');
    lines.push('|--------|--------------------|-------:|--------:|');
    for (const s of seriesQuality.borderline) {
      lines.push(
        `| ${s.displayName} | \`${s.distinctivePhrase}\` | ${s.distinctiveLength} | ${s.figureCount} |`,
      );
    }
    lines.push('');
  }

  if (seriesQuality.tooShort.length > 0) {
    lines.push('### Too-Short Distinctive Series (phrase < 4 chars)');
    lines.push('');
    lines.push(
      'These series cannot satisfy the series gate even after generalization. They require catalog metadata enrichment (aliases) or a brand-level fallback design.',
    );
    lines.push('');
    lines.push('| Series | Distinctive Phrase | Length | Figures |');
    lines.push('|--------|--------------------|-------:|--------:|');
    for (const s of seriesQuality.tooShort) {
      lines.push(
        `| ${s.displayName} | \`${s.distinctivePhrase || '(empty)'}\` | ${s.distinctiveLength} | ${s.figureCount} |`,
      );
    }
    lines.push('');
  }

  // --- Section 6: Recommendation ---
  lines.push('## 6. Recommendation');
  lines.push('');
  lines.push(`### ${recommendation.value}`);
  lines.push('');
  lines.push(recommendation.rationale);
  lines.push('');
  lines.push('| Metric | Value |');
  lines.push('|--------|------:|');
  lines.push(`| Baseline matchable | ${recommendation.baselineMatchablePct}% |`);
  lines.push(`| Simulated matchable (safe) | ${simulated.percentages.MATCHABLE}% |`);
  lines.push(
    `| Simulated matchable (safe + borderline) | ${Math.round(((simulated.distribution.MATCHABLE + simulated.distribution.MATCHABLE_BORDERLINE) / total) * 1000) / 10}% |`,
  );
  lines.push(`| Figures upgraded | ${delta.upgradedFigures} |`);
  lines.push(`| Remaining MATCHER_RISK | ${simulated.distribution.MATCHER_RISK} |`);
  lines.push('');
  lines.push(
    '_Note: MATCHABLE_BORDERLINE figures are included in "simulated matchable" counts above. They require production validation before relying on match quality._',
  );
  lines.push('');
  lines.push('---');
  lines.push('');
  lines.push(
    'Re-run: `node tools/market_intel/matcher_generalization_simulation_audit.mjs`',
  );

  return lines.join('\n');
}

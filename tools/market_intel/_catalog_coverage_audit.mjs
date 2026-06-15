/**
 * Market Intelligence — catalog coverage audit (Sprint 2 Step 3D).
 *
 * Diagnostics only — does not modify matcher, scoring, or thresholds.
 */

import {
  buildCatalogContextForFigure,
  getMetadataRecord,
  loadCatalogBundle,
  normalizeMetadataEntry,
} from './_catalog_bundle.mjs';
import { extractSeriesDistinctive } from './_search_term_derivation.mjs';
import {
  buildMatcherContextForFigure,
  resolveMatcherConflictSeries,
} from './_snapshot_match.mjs';
import { buildFigureSearchPlan } from './_snapshot_search.mjs';

/**
 * Minimum distinctive phrase length for safe series gate (no false-positive risk).
 * Matches the threshold used in detectSeriesMatchFull.
 */
export const SAFE_DISTINCTIVE_MIN_LENGTH = 8;

/**
 * Minimum distinctive phrase length for borderline use (allowed with quality warning).
 * Phrases 4–7 chars: series gate can fire but with elevated false-positive risk.
 */
export const BORDERLINE_DISTINCTIVE_MIN_LENGTH = 4;

export const BIG_INTO_ENERGY_SERIES_ID =
  'the_monsters_big_into_energy_vinyl_plush_pendant';

export const CoverageClass = Object.freeze({
  MATCHABLE: 'MATCHABLE',
  NO_SEARCH_TERMS: 'NO_SEARCH_TERMS',
  MATCHER_RISK: 'MATCHER_RISK',
  DISABLED: 'DISABLED',
  UNKNOWN: 'UNKNOWN',
});

/**
 * @typedef {'MATCHABLE' | 'NO_SEARCH_TERMS' | 'MATCHER_RISK' | 'DISABLED' | 'UNKNOWN'} CoverageClassification
 */

/**
 * @typedef {Object} MatcherRisk
 * @property {string} code
 * @property {string} reason
 */

/**
 * @typedef {Object} FigureCoverageRecord
 * @property {string} figureId
 * @property {string} displayName
 * @property {string} seriesId
 * @property {string} seriesDisplayName
 * @property {string | null} brandId
 * @property {string | null} ipId
 * @property {CoverageClassification} classification
 * @property {string} primaryReason
 * @property {string[]} searchTerms
 * @property {MatcherRisk[]} matcherRisks
 * @property {MatcherRisk[]} matcherWarnings
 * @property {string | null} error
 */

/**
 * @typedef {Object} SeriesCoverageRecord
 * @property {string} seriesId
 * @property {string} seriesDisplayName
 * @property {string | null} ipDisplayName
 * @property {number} figures
 * @property {number} matchable
 * @property {number} matcherRisk
 * @property {number} noSearchTerms
 * @property {number} disabled
 * @property {number} unknown
 * @property {string} primarySeriesReason
 */

/**
 * @typedef {Object} CatalogCoverageAudit
 * @property {string} generatedAt
 * @property {number} totalFigures
 * @property {Record<CoverageClassification, number>} distribution
 * @property {Record<CoverageClassification, number>} percentages
 * @property {FigureCoverageRecord[]} figures
 * @property {SeriesCoverageRecord[]} series
 * @property {object} matcherAssumptions
 * @property {{ noSearchTerms: FigureCoverageRecord[], matcherRisk: FigureCoverageRecord[] }} topRisks
 */

/**
 * @param {object} figure
 * @param {ReturnType<typeof loadCatalogBundle>} bundle
 * @param {ReturnType<typeof normalizeMetadataEntry>} metadata
 * @returns {string | null}
 */
export function explainNoSearchTerms(figure, bundle, metadata) {
  if (metadata.disabled) {
    return 'metadata disabled';
  }

  const catalogContext = buildCatalogContextForFigure(figure, bundle);
  const { brand, ip, series } = catalogContext;

  if (!brand?.displayName) {
    return 'missing brand context';
  }

  if (!series?.displayName) {
    return 'missing series context';
  }

  const distinctive = extractSeriesDistinctive(series, ip);
  if (!distinctive || distinctive.length < 3) {
    return `series distinctive extraction collapses to "${distinctive || '(empty)'}"`;
  }

  if (/^\d+$/.test(distinctive)) {
    return `series distinctive is numeric only ("${distinctive}")`;
  }

  if (!resolveIpTokenForAudit(ip)) {
    return 'missing IP token';
  }

  return 'deriveSearchTerms returned empty array';
}

/**
 * @param {{ displayName?: string, aliases?: string[] } | null | undefined} ip
 */
function resolveIpTokenForAudit(ip) {
  if (!ip) {
    return '';
  }

  const firstAlias = ip.aliases?.[0];
  if (firstAlias?.trim()) {
    return firstAlias.trim();
  }

  return ip.displayName?.trim() ?? '';
}

/**
 * @typedef {Object} MatcherRiskAssessment
 * @property {MatcherRisk[]} structural
 * @property {MatcherRisk[]} warnings
 */

/**
 * @param {object} figure
 * @param {ReturnType<typeof loadCatalogBundle>} bundle
 * @param {ReturnType<typeof normalizeMetadataEntry>} metadata
 * @param {ReturnType<typeof buildFigureSearchPlan>} plan
 * @returns {MatcherRiskAssessment}
 */
export function detectMatcherRisks(figure, bundle, metadata, plan) {
  /** @type {MatcherRisk[]} */
  const structural = [];
  /** @type {MatcherRisk[]} */
  const warnings = [];
  const series = bundle.seriesById.get(figure.seriesId);
  const ip = bundle.ipById.get(series?.ipId ?? figure.ipId);
  const brand = bundle.brandById.get(figure.brandId);
  const distinctive = extractSeriesDistinctive(series, ip);

  if (distinctive.length > 0 && distinctive.length < BORDERLINE_DISTINCTIVE_MIN_LENGTH) {
    structural.push({
      code: 'tooShortSeriesDistinctive',
      reason: `series distinctive "${distinctive}" (${distinctive.length} chars) too short for generalized gate`,
    });
  }

  if (
    distinctive.length >= BORDERLINE_DISTINCTIVE_MIN_LENGTH &&
    distinctive.length < SAFE_DISTINCTIVE_MIN_LENGTH
  ) {
    warnings.push({
      code: 'shortSeriesDistinctive',
      reason: `series distinctive "${distinctive}" (${distinctive.length} chars) — borderline false-positive risk`,
    });
  }

  if (!plan.catalogContext.brand?.displayName || !plan.catalogContext.series?.displayName) {
    structural.push({
      code: 'incompleteCatalogContext',
      reason: 'catalog joins missing brand or series row',
    });
  }

  if (brand && brand.id !== 'pop_mart' && (brand.aliases ?? []).length === 0) {
    warnings.push({
      code: 'limitedBrandTokens',
      reason: `brand "${brand.displayName}" has no POP MART-style alias expansion`,
    });
  }

  const displayName = figure.displayName?.trim() ?? '';
  const tokenCount = displayName.split(/\s+/).filter(Boolean).length;
  if (
    tokenCount === 1 &&
    displayName.length <= 5 &&
    metadata.marketAliases.length === 0 &&
    (figure.aliases ?? []).length === 0
  ) {
    warnings.push({
      code: 'ambiguousFigureName',
      reason: 'single-token figure name with no marketAliases or catalog aliases',
    });
  }

  if (figure.isSecret) {
    warnings.push({
      code: 'secretConsistency',
      reason: 'secret figures require secret/chase indicator in listing titles',
    });
  }

  const siblings = bundle.figures.filter(
    (row) => row.seriesId === figure.seriesId && row.id !== figure.id,
  );
  const shortSiblingNames = siblings.filter((row) => {
    const name = row.displayName?.trim() ?? '';
    return name.length > 0 && name.length <= 5 && !name.includes(' ');
  });
  if (shortSiblingNames.length >= 3 && tokenCount === 1) {
    warnings.push({
      code: 'siblingCollision',
      reason: `series has ${shortSiblingNames.length} short single-token sibling names`,
    });
  }

  return {
    structural: dedupeRisks(structural),
    warnings: dedupeRisks(warnings),
  };
}

/**
 * @param {MatcherRisk[]} risks
 * @returns {MatcherRisk[]}
 */
function dedupeRisks(risks) {
  const seen = new Set();
  return risks.filter((risk) => {
    if (seen.has(risk.code)) {
      return false;
    }

    seen.add(risk.code);
    return true;
  });
}

/**
 * @param {object} figure
 * @param {ReturnType<typeof loadCatalogBundle>} bundle
 * @returns {FigureCoverageRecord}
 */
export function auditFigureCoverage(figure, bundle) {
  const series = bundle.seriesById.get(figure.seriesId);
  const plan = buildFigureSearchPlan(figure, bundle);
  const { entry: metadataEntry } = getMetadataRecord(bundle, figure.id);
  const metadata = normalizeMetadataEntry(metadataEntry);

  /** @type {FigureCoverageRecord} */
  const record = {
    figureId: figure.id,
    displayName: figure.displayName,
    seriesId: figure.seriesId,
    seriesDisplayName: series?.displayName ?? figure.seriesId,
    brandId: figure.brandId ?? null,
    ipId: series?.ipId ?? figure.ipId ?? null,
    classification: CoverageClass.UNKNOWN,
    primaryReason: '',
    searchTerms: plan?.searchTerms ?? [],
    matcherRisks: [],
    matcherWarnings: [],
    error: null,
  };

  if (!plan) {
    record.classification = CoverageClass.UNKNOWN;
    record.primaryReason = 'figure search plan could not be built';
    return record;
  }

  if (metadata.disabled) {
    record.classification = CoverageClass.DISABLED;
    record.primaryReason = 'metadata disabled';
    return record;
  }

  if (plan.searchTerms.length === 0) {
    record.classification = CoverageClass.NO_SEARCH_TERMS;
    record.primaryReason = explainNoSearchTerms(figure, bundle, metadata);
    return record;
  }

  try {
    buildMatcherContextForFigure(figure, bundle);
  } catch (error) {
    record.classification = CoverageClass.UNKNOWN;
    record.primaryReason = 'matcher context build failed';
    record.error = error instanceof Error ? error.message : String(error);
    return record;
  }

  const riskAssessment = detectMatcherRisks(figure, bundle, metadata, plan);
  record.matcherRisks = riskAssessment.structural;
  record.matcherWarnings = riskAssessment.warnings;

  if (record.matcherRisks.length > 0) {
    record.classification = CoverageClass.MATCHER_RISK;
    record.primaryReason = record.matcherRisks[0].reason;
    return record;
  }

  record.classification = CoverageClass.MATCHABLE;
  record.primaryReason =
    record.matcherWarnings.length > 0
      ? `matchable with warnings: ${record.matcherWarnings[0].reason}`
      : 'search terms and matcher context ready';
  return record;
}

/**
 * @param {ReturnType<typeof loadCatalogBundle>} [bundle]
 * @returns {CatalogCoverageAudit}
 */
export function auditCatalogCoverage(bundle = loadCatalogBundle()) {
  const figures = bundle.figures
    .map((figure) => auditFigureCoverage(figure, bundle))
    .sort((left, right) => {
      if (left.seriesId !== right.seriesId) {
        return left.seriesId.localeCompare(right.seriesId);
      }

      return left.displayName.localeCompare(right.displayName);
    });

  /** @type {Record<CoverageClassification, number>} */
  const distribution = {
    MATCHABLE: 0,
    NO_SEARCH_TERMS: 0,
    MATCHER_RISK: 0,
    DISABLED: 0,
    UNKNOWN: 0,
  };

  for (const record of figures) {
    distribution[record.classification] += 1;
  }

  const totalFigures = figures.length;
  /** @type {Record<CoverageClassification, number>} */
  const percentages = {};
  for (const [key, count] of Object.entries(distribution)) {
    percentages[key] =
      totalFigures > 0 ? Math.round((count / totalFigures) * 1000) / 10 : 0;
  }

  const series = buildSeriesCoverage(figures, bundle);

  return {
    generatedAt: new Date().toISOString(),
    totalFigures,
    distribution,
    percentages,
    figures,
    series,
    matcherAssumptions: buildMatcherAssumptionAudit(bundle, figures),
    topRisks: {
      noSearchTerms: figures
        .filter((record) => record.classification === CoverageClass.NO_SEARCH_TERMS)
        .slice(0, 25),
      matcherRisk: figures
        .filter((record) => record.classification === CoverageClass.MATCHER_RISK)
        .slice(0, 25),
    },
  };
}

/**
 * @param {FigureCoverageRecord[]} figures
 * @param {ReturnType<typeof loadCatalogBundle>} bundle
 * @returns {SeriesCoverageRecord[]}
 */
export function buildSeriesCoverage(figures, bundle) {
  /** @type {Map<string, SeriesCoverageRecord>} */
  const bySeries = new Map();

  for (const record of figures) {
    const existing = bySeries.get(record.seriesId) ?? {
      seriesId: record.seriesId,
      seriesDisplayName: record.seriesDisplayName,
      ipDisplayName:
        bundle.ipById.get(record.ipId ?? '')?.displayName ?? null,
      figures: 0,
      matchable: 0,
      matcherRisk: 0,
      noSearchTerms: 0,
      disabled: 0,
      unknown: 0,
      primarySeriesReason: '',
    };

    existing.figures += 1;

    switch (record.classification) {
      case CoverageClass.MATCHABLE:
        existing.matchable += 1;
        break;
      case CoverageClass.MATCHER_RISK:
        existing.matcherRisk += 1;
        break;
      case CoverageClass.NO_SEARCH_TERMS:
        existing.noSearchTerms += 1;
        break;
      case CoverageClass.DISABLED:
        existing.disabled += 1;
        break;
      default:
        existing.unknown += 1;
        break;
    }

    bySeries.set(record.seriesId, existing);
  }

  for (const seriesRecord of bySeries.values()) {
    if (seriesRecord.noSearchTerms === seriesRecord.figures) {
      const sample = figures.find(
        (record) =>
          record.seriesId === seriesRecord.seriesId &&
          record.classification === CoverageClass.NO_SEARCH_TERMS,
      );
      seriesRecord.primarySeriesReason =
        sample?.primaryReason ?? 'all figures lack search terms';
    } else if (seriesRecord.matcherRisk === seriesRecord.figures) {
      const sample = figures.find(
        (record) =>
          record.seriesId === seriesRecord.seriesId &&
          record.classification === CoverageClass.MATCHER_RISK,
      );
      seriesRecord.primarySeriesReason =
        sample?.primaryReason ??
        'all figures flagged for matcher architecture risk';
    } else if (seriesRecord.matchable === seriesRecord.figures) {
      seriesRecord.primarySeriesReason = 'all figures matchable';
    } else if (seriesRecord.matchable > 0 && seriesRecord.matcherRisk > 0) {
      seriesRecord.primarySeriesReason =
        'mixed matchable and matcher-risk figures';
    } else {
      seriesRecord.primarySeriesReason = 'mixed coverage classifications';
    }
  }

  return [...bySeries.values()].sort((left, right) => {
    if (right.matcherRisk !== left.matcherRisk) {
      return right.matcherRisk - left.matcherRisk;
    }

    if (right.noSearchTerms !== left.noSearchTerms) {
      return right.noSearchTerms - left.noSearchTerms;
    }

    return left.seriesDisplayName.localeCompare(right.seriesDisplayName);
  });
}

/**
 * @param {ReturnType<typeof loadCatalogBundle>} bundle
 * @param {FigureCoverageRecord[]} figures
 */
export function buildMatcherAssumptionAudit(bundle, figures) {
  const bigIntoEnergy = figures.filter(
    (record) => record.seriesId === BIG_INTO_ENERGY_SERIES_ID,
  );
  const nonBigIntoEnergy = figures.filter(
    (record) => record.seriesId !== BIG_INTO_ENERGY_SERIES_ID,
  );

  const shortDistinctiveRisk = figures.filter((record) =>
    record.matcherWarnings.some((risk) => risk.code === 'shortSeriesDistinctive'),
  ).length;

  const ambiguousNameRisk = figures.filter((record) =>
    record.matcherWarnings.some((risk) => risk.code === 'ambiguousFigureName'),
  ).length;

  const secretRisk = figures.filter((record) =>
    record.matcherWarnings.some((risk) => risk.code === 'secretConsistency'),
  ).length;

  return {
    documentedAssumptions: [
      {
        id: 'brandRequired',
        description: 'Acceptance gate requires brand token in listing title',
        catalogWideSafe: true,
        bigIntoEnergySpecific: false,
        falseNegativeRisk: 'low',
      },
      {
        id: 'fullSeriesRequired',
        description:
          'Acceptance gate requires full series match; detectSeriesMatchFull uses context.seriesDistinctivePhrase (catalog-derived, from extractSeriesDistinctive)',
        catalogWideSafe: true,
        bigIntoEnergySpecific: false,
        falseNegativeRisk: 'low',
        note: 'Series with distinctive < 4 chars fall back to IP anchor + figure identity (no phrase gate)',
      },
      {
        id: 'figureIdentityRequired',
        description: 'Acceptance gate requires figure name or market alias token',
        catalogWideSafe: true,
        bigIntoEnergySpecific: false,
        falseNegativeRisk: 'medium',
        affectedFigures: ambiguousNameRisk,
      },
      {
        id: 'secretConsistency',
        description: 'Secret figures reject listings without secret/chase indicators',
        catalogWideSafe: true,
        bigIntoEnergySpecific: false,
        falseNegativeRisk: 'medium',
        affectedFigures: secretRisk,
      },
      {
        id: 'seriesMismatchHardReject',
        description:
          'Conflicting series phrases in title hard-reject (scoped to same IP in snapshot pipeline)',
        catalogWideSafe: 'partial',
        bigIntoEnergySpecific: false,
        falseNegativeRisk: 'medium',
        note: `Snapshot pipeline limits conflict series to IP universe (${resolveMatcherConflictSeries.name})`,
      },
      {
        id: 'crossFigureContamination',
        description: 'Sibling figure tokens in title hard-reject',
        catalogWideSafe: true,
        bigIntoEnergySpecific: false,
        falseNegativeRisk: 'medium',
      },
      {
        id: 'productTypeTierRejects',
        description: 'Accessory/product-type phrases hard-reject (keychain, pin only, etc.)',
        catalogWideSafe: true,
        bigIntoEnergySpecific: false,
        falseNegativeRisk: 'low',
      },
    ],
    bigIntoEnergySeries: {
      seriesId: BIG_INTO_ENERGY_SERIES_ID,
      figures: bigIntoEnergy.length,
      matchable: bigIntoEnergy.filter(
        (record) => record.classification === CoverageClass.MATCHABLE,
      ).length,
      matcherRisk: bigIntoEnergy.filter(
        (record) => record.classification === CoverageClass.MATCHER_RISK,
      ).length,
    },
    nonBigIntoEnergy: {
      figures: nonBigIntoEnergy.length,
      matchable: nonBigIntoEnergy.filter(
        (record) => record.classification === CoverageClass.MATCHABLE,
      ).length,
      matcherRisk: nonBigIntoEnergy.filter(
        (record) => record.classification === CoverageClass.MATCHER_RISK,
      ).length,
      shortDistinctiveRisk,
    },
  };
}

/**
 * @param {CatalogCoverageAudit} audit
 * @returns {string}
 */
export function formatCoverageReportMarkdown(audit) {
  const lines = [];

  lines.push('# Catalog Coverage Report — Market Intelligence');
  lines.push('');
  lines.push(`> Generated: ${audit.generatedAt}`);
  lines.push('> Sprint 2 Step 3E.2 — generalized matcher (catalog-driven series gate).');
  lines.push('');
  lines.push('## Executive Summary');
  lines.push('');
  lines.push(`- **Total catalog figures:** ${audit.totalFigures}`);
  lines.push(
    `- **Matchable:** ${audit.distribution.MATCHABLE} (${audit.percentages.MATCHABLE}%)`,
  );
  lines.push(
    `- **Matcher risk:** ${audit.distribution.MATCHER_RISK} (${audit.percentages.MATCHER_RISK}%)`,
  );
  lines.push(
    `- **No search terms:** ${audit.distribution.NO_SEARCH_TERMS} (${audit.percentages.NO_SEARCH_TERMS}%)`,
  );
  lines.push(
    `- **Disabled:** ${audit.distribution.DISABLED} (${audit.percentages.DISABLED}%)`,
  );
  lines.push(
    `- **Unknown:** ${audit.distribution.UNKNOWN} (${audit.percentages.UNKNOWN}%)`,
  );
  const warningCount = audit.figures.filter(
    (record) =>
      record.classification === CoverageClass.MATCHABLE &&
      record.matcherWarnings?.length > 0,
  ).length;
  lines.push(
    `- **Matchable figures with metadata warnings:** ${warningCount}`,
  );
  lines.push('');
  lines.push(
    `**Production-ready estimate (matchable):** ${audit.percentages.MATCHABLE}% of catalog can flow through the current matcher architecture today.`,
  );
  lines.push('');
  lines.push('## Failure Distribution');
  lines.push('');
  lines.push('| Classification | Count | % |');
  lines.push('|----------------|------:|--:|');
  for (const key of Object.keys(audit.distribution)) {
    lines.push(
      `| ${key} | ${audit.distribution[key]} | ${audit.percentages[key]}% |`,
    );
  }
  lines.push('');
  lines.push('## Matcher Assumption Audit');
  lines.push('');
  lines.push('Current matcher assumptions (report-only):');
  lines.push('');
  for (const assumption of audit.matcherAssumptions.documentedAssumptions) {
    lines.push(`### ${assumption.id}`);
    lines.push('');
    lines.push(`- **Description:** ${assumption.description}`);
    lines.push(`- **Catalog-wide safe:** ${assumption.catalogWideSafe}`);
    lines.push(
      `- **Big Into Energy-specific:** ${assumption.bigIntoEnergySpecific}`,
    );
    lines.push(`- **False-negative risk:** ${assumption.falseNegativeRisk}`);
    if (assumption.affectedFigures != null) {
      lines.push(`- **Affected figures (audit heuristic):** ${assumption.affectedFigures}`);
    }
    if (assumption.note) {
      lines.push(`- **Note:** ${assumption.note}`);
    }
    lines.push('');
  }
  lines.push('### Big Into Energy vs Rest of Catalog');
  lines.push('');
  lines.push(
    `- Big Into Energy: ${audit.matcherAssumptions.bigIntoEnergySeries.matchable}/${audit.matcherAssumptions.bigIntoEnergySeries.figures} matchable`,
  );
  lines.push(
    `- Non–Big Into Energy: ${audit.matcherAssumptions.nonBigIntoEnergy.matchable}/${audit.matcherAssumptions.nonBigIntoEnergy.figures} matchable`,
  );
  lines.push(
    `- Non–Big Into Energy short-distinctive warnings: ${audit.matcherAssumptions.nonBigIntoEnergy.shortDistinctiveRisk}`,
  );
  lines.push('');
  lines.push('## Series Coverage (structural failures first)');
  lines.push('');
  const structuralSeries = audit.series.filter(
    (series) =>
      series.matcherRisk === series.figures ||
      series.noSearchTerms === series.figures ||
      series.unknown > 0,
  );

  for (const series of structuralSeries.slice(0, 40)) {
    lines.push(`### ${series.seriesDisplayName}`);
    lines.push('');
    lines.push(`- **Series ID:** \`${series.seriesId}\``);
    lines.push(`- **Figures:** ${series.figures}`);
    lines.push(`- **Matchable:** ${series.matchable}`);
    lines.push(`- **Matcher risk:** ${series.matcherRisk}`);
    lines.push(`- **No search terms:** ${series.noSearchTerms}`);
    lines.push(`- **Disabled:** ${series.disabled}`);
    lines.push(`- **Reason:** ${series.primarySeriesReason}`);
    lines.push('');
  }

  if (structuralSeries.length > 40) {
    lines.push(`_…and ${structuralSeries.length - 40} more structural series._`);
    lines.push('');
  }

  lines.push('## Top Risk Lists');
  lines.push('');
  lines.push('### Top 25 NO_SEARCH_TERMS');
  lines.push('');
  lines.push('| figureId | displayName | series | reason |');
  lines.push('|----------|-------------|--------|--------|');
  for (const record of audit.topRisks.noSearchTerms) {
    lines.push(
      `| \`${record.figureId}\` | ${record.displayName} | ${record.seriesDisplayName} | ${record.primaryReason} |`,
    );
  }
  lines.push('');
  lines.push('### Top 25 MATCHER_RISK');
  lines.push('');
  lines.push('| figureId | displayName | series | reason |');
  lines.push('|----------|-------------|--------|--------|');
  for (const record of audit.topRisks.matcherRisk) {
    lines.push(
      `| \`${record.figureId}\` | ${record.displayName} | ${record.seriesDisplayName} | ${record.primaryReason} |`,
    );
  }
  lines.push('');
  lines.push('## Answers');
  lines.push('');
  lines.push(
    `1. **How many figures are matchable?** ${audit.distribution.MATCHABLE} (${audit.percentages.MATCHABLE}%).`,
  );
  lines.push(
    '2. **Which series are blocked?** See structural series section — full-series phrase bias blocks most non–Big Into Energy IPs; numeric series distinctive blocks Smiski Series 2.',
  );
  lines.push(
    '3. **Which matcher assumptions cause risk?** shortSeriesDistinctive (4–7 char phrase) series require production validation; tooShortSeriesDistinctive (< 4 chars) cannot use phrase gate.',
  );
  lines.push(
    `4. **Production-ready percentage?** ${audit.percentages.MATCHABLE}% matchable under generalized matcher architecture.`,
  );
  lines.push('');
  lines.push('---');
  lines.push('');
  lines.push('Re-run: `node tools/market_intel/catalog_coverage_audit.mjs`');

  return lines.join('\n');
}

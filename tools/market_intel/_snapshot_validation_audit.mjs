/**
 * Market Intelligence — snapshot validation audit (Sprint 2 Step 4C).
 *
 * Validation only. Runs the full fixture-backed pipeline for a human-review
 * sample and reports per-figure diagnostics. No production behavior changes.
 */

import {
  buildCatalogContextForFigure,
  findFigureById,
  loadCatalogBundle,
} from './_catalog_bundle.mjs';
import { fetchFigureCompletedSales } from './_snapshot_fetch.mjs';
import { buildFigureSearchPlanById } from './_snapshot_search.mjs';
import { buildFigureSnapshot } from './_snapshot_document.mjs';
import { buildFirestoreDocument } from './push_market_snapshots.mjs';

export const ValidationStatus = Object.freeze({
  PASS: 'PASS',
  WARNING: 'WARNING',
  FAIL: 'FAIL',
});

export const ProductionReadiness = Object.freeze({
  READY_FOR_LIVE_DATA_SOURCE: 'READY_FOR_LIVE_DATA_SOURCE',
  READY_WITH_WARNINGS: 'READY_WITH_WARNINGS',
  NOT_READY: 'NOT_READY',
});

/** Required Firestore fields for a writable figure-level snapshot. */
export const REQUIRED_FIRESTORE_FIELDS = Object.freeze([
  'level',
  'figureId',
  'seriesId',
  'estimatedValueUsd',
  'confidence',
  'recentSalesCount',
  'computedAt',
]);

/** Required SnapshotDocument fields. */
export const REQUIRED_SNAPSHOT_FIELDS = Object.freeze([
  'figureId',
  'seriesId',
  'snapshotAt',
  'sampleSize',
  'medianPrice',
  'averagePrice',
  'minPrice',
  'maxPrice',
  'confidence',
  'dataSource',
]);

/**
 * Human-review sample — 15 figures across catalog types.
 * Fixture mode only; not full catalog.
 */
export const DEFAULT_VALIDATION_SAMPLE = Object.freeze([
  // Big Into Energy
  'the_monsters_big_into_energy_vinyl_plush_pendant_luck',
  'the_monsters_big_into_energy_vinyl_plush_pendant_hope',
  'the_monsters_big_into_energy_vinyl_plush_pendant_love',
  'the_monsters_big_into_energy_vinyl_plush_pendant_id',
  'the_monsters_big_into_energy_vinyl_plush_pendant_serenity',
  'the_monsters_big_into_energy_vinyl_plush_pendant_loyalty',
  'the_monsters_big_into_energy_vinyl_plush_pendant_happiness',
  // Have a Seat
  'the_monsters_have_a_seat_vinyl_plush_sisi',
  'the_monsters_have_a_seat_vinyl_plush_duoduo',
  // Exciting Macaron
  'the_monsters_exciting_macaron_vinyl_face_soymilk',
  // Skullpanda
  'skullpanda_petals_in_four_acts_the_fairys_trick',
  // Baby Molly
  'baby_molly_pocket_friends_series_whos_the_good_girl',
  // Sonny Angel
  'sonny_angel_animal_series_1_rabbit',
  // Smiski
  'smiski_series_2_kneeling',
  // Non-Pop-Mart (Rolife / Nanci)
  'nanci_poetic_beauty_shy_lotus',
]);

/** @type {Record<string, string>} */
const FIGURE_CATEGORY_BY_ID = Object.freeze({
  the_monsters_big_into_energy_vinyl_plush_pendant_luck: 'Big Into Energy',
  the_monsters_big_into_energy_vinyl_plush_pendant_hope: 'Big Into Energy',
  the_monsters_big_into_energy_vinyl_plush_pendant_love: 'Big Into Energy',
  the_monsters_big_into_energy_vinyl_plush_pendant_id: 'Big Into Energy',
  the_monsters_big_into_energy_vinyl_plush_pendant_serenity: 'Big Into Energy',
  the_monsters_big_into_energy_vinyl_plush_pendant_loyalty: 'Big Into Energy',
  the_monsters_big_into_energy_vinyl_plush_pendant_happiness: 'Big Into Energy',
  the_monsters_have_a_seat_vinyl_plush_sisi: 'Have a Seat',
  the_monsters_have_a_seat_vinyl_plush_duoduo: 'Have a Seat',
  the_monsters_exciting_macaron_vinyl_face_soymilk: 'Exciting Macaron',
  skullpanda_petals_in_four_acts_the_fairys_trick: 'Skullpanda',
  baby_molly_pocket_friends_series_whos_the_good_girl: 'Baby Molly',
  sonny_angel_animal_series_1_rabbit: 'Sonny Angel',
  smiski_series_2_kneeling: 'Smiski',
  nanci_poetic_beauty_shy_lotus: 'Non-Pop-Mart (Rolife)',
});

/**
 * @typedef {'PASS' | 'WARNING' | 'FAIL'} ValidationStatusValue
 * @typedef {'READY_FOR_LIVE_DATA_SOURCE' | 'READY_WITH_WARNINGS' | 'NOT_READY'} ProductionReadinessValue
 */

/**
 * @typedef {Object} SearchTermIssue
 * @property {string} code
 * @property {string} message
 */

/**
 * @typedef {Object} RejectReasonCount
 * @property {string} reason
 * @property {number} count
 */

/**
 * @typedef {Object} FigureValidationRecord
 * @property {string} figureId
 * @property {string} displayName
 * @property {string} seriesId
 * @property {string} seriesDisplayName
 * @property {string} brandId
 * @property {string} brandDisplayName
 * @property {string} category
 * @property {ValidationStatusValue} status
 * @property {string[]} warnings
 * @property {string[]} failures
 * @property {string[]} searchTerms
 * @property {boolean} usesSearchTermsOverride
 * @property {SearchTermIssue[]} searchTermIssues
 * @property {boolean} fetchSkipped
 * @property {string | null} fetchSkipReason
 * @property {number} fetchedListingCount
 * @property {string[]} fixtureListingTitles
 * @property {number} matchedCount
 * @property {number} rejectedCount
 * @property {number} excludedCount
 * @property {RejectReasonCount[]} topRejectReasons
 * @property {string[]} matchedTitles
 * @property {{ title: string, reason: string }[]} rejectedSamples
 * @property {number} sampleSize
 * @property {number | null} medianPrice
 * @property {number | null} averagePrice
 * @property {number | null} minPrice
 * @property {number | null} maxPrice
 * @property {import('./_snapshot_document.mjs').SnapshotDocument | null} snapshotDocument
 * @property {boolean} snapshotMalformed
 * @property {string[]} snapshotMissingFields
 * @property {boolean} firestoreSkipped
 * @property {string | null} firestoreSkipReason
 * @property {string | null} firestoreDocId
 * @property {Record<string, unknown> | null} firestoreFields
 * @property {boolean} firestoreMalformed
 * @property {string[]} firestoreMissingFields
 */

/**
 * @typedef {Object} SnapshotValidationAudit
 * @property {string} generatedAt
 * @property {number} sampleSize
 * @property {ValidationStatusValue} status
 * @property {ProductionReadinessValue} productionReadiness
 * @property {string} productionReadinessExplanation
 * @property {{ PASS: number, WARNING: number, FAIL: number }} counts
 * @property {FigureValidationRecord[]} figures
 * @property {string[]} warnings
 * @property {string[]} failures
 * @property {{ duplicateQueries: string[], searchTermIssueSummary: Record<string, number> }} searchTermReview
 * @property {{ figureId: string, matched: number, rejected: number, topRejectReasons: RejectReasonCount[] }[]} matcherReview
 * @property {{ writable: number, skipped: number, malformed: number }} firestoreReview
 */

/**
 * @param {readonly string[]} terms
 * @returns {SearchTermIssue[]}
 */
export function detectSearchTermIssues(terms) {
  /** @type {SearchTermIssue[]} */
  const issues = [];

  const seen = new Map();
  for (const term of terms) {
    const trimmed = term.trim();
    if (!trimmed) {
      issues.push({
        code: 'empty_query',
        message: 'Search term is empty or whitespace-only',
      });
      continue;
    }

    const key = trimmed.toLowerCase();
    if (seen.has(key)) {
      issues.push({
        code: 'duplicate_query',
        message: `Duplicate query within figure: "${trimmed}"`,
      });
    } else {
      seen.set(key, trimmed);
    }

    if (trimmed.length < 8) {
      issues.push({
        code: 'unexpected_truncation',
        message: `Query shorter than 8 characters: "${trimmed}"`,
      });
    }

    if (/\.{3}$|…$/.test(trimmed)) {
      issues.push({
        code: 'unexpected_truncation',
        message: `Query appears truncated: "${trimmed}"`,
      });
    }
  }

  return issues;
}

/**
 * @param {import('./_snapshot_match.mjs').UnmatchedSaleListing[]} unmatchedListings
 * @param {number} [limit]
 * @returns {RejectReasonCount[]}
 */
export function aggregateRejectReasons(unmatchedListings, limit = 5) {
  /** @type {Map<string, number>} */
  const counts = new Map();

  for (const entry of unmatchedListings) {
    if (entry.reason === 'excluded') {
      const key = 'excluded';
      counts.set(key, (counts.get(key) ?? 0) + 1);
      continue;
    }

    const reason = entry.rejectReason ?? 'noMatch';
    counts.set(reason, (counts.get(reason) ?? 0) + 1);
  }

  return [...counts.entries()]
    .map(([reason, count]) => ({ reason, count }))
    .sort((left, right) => right.count - left.count)
    .slice(0, limit);
}

/**
 * @param {import('./_snapshot_document.mjs').SnapshotDocument | null | undefined} snapshot
 * @returns {{ malformed: boolean, missingFields: string[] }}
 */
export function validateSnapshotDocumentShape(snapshot) {
  if (!snapshot) {
    return { malformed: true, missingFields: ['(entire document)'] };
  }

  /** @type {string[]} */
  const missingFields = [];
  for (const field of REQUIRED_SNAPSHOT_FIELDS) {
    if (!(field in snapshot)) {
      missingFields.push(field);
    }
  }

  if (!snapshot.figureId?.trim()) missingFields.push('figureId (empty)');
  if (!snapshot.seriesId?.trim()) missingFields.push('seriesId (empty)');
  if (snapshot.confidence !== 'high' && snapshot.confidence !== 'low') {
    missingFields.push('confidence (invalid)');
  }

  return {
    malformed: missingFields.length > 0,
    missingFields,
  };
}

/**
 * @param {import('./_snapshot_document.mjs').SnapshotDocument} snapshot
 * @param {ReturnType<typeof buildFirestoreDocument>} mapped
 * @returns {{
 *   skipped: boolean,
 *   skipReason: string | null,
 *   docId: string | null,
 *   fields: Record<string, unknown> | null,
 *   malformed: boolean,
 *   missingFields: string[],
 * }}
 */
export function validateFirestorePayload(snapshot, mapped) {
  if (mapped == null) {
    const skipReason =
      snapshot.medianPrice == null
        ? 'medianPrice null'
        : snapshot.medianPrice <= 0
          ? 'medianPrice <= 0'
          : !snapshot.seriesId
            ? 'seriesId missing'
            : 'mapping rejected';

    return {
      skipped: true,
      skipReason,
      docId: null,
      fields: null,
      malformed: false,
      missingFields: [],
    };
  }

  /** @type {string[]} */
  const missingFields = [];
  for (const field of REQUIRED_FIRESTORE_FIELDS) {
    if (!(field in mapped.fields)) {
      missingFields.push(field);
    }
  }

  const fields = mapped.fields;
  if (fields.level !== 'figure') missingFields.push('level (not figure)');
  if (!fields.figureId) missingFields.push('figureId (empty)');
  if (!fields.seriesId) missingFields.push('seriesId (empty)');
  if (!(Number(fields.estimatedValueUsd) > 0)) {
    missingFields.push('estimatedValueUsd (invalid)');
  }
  if (fields.confidence !== 'high' && fields.confidence !== 'low') {
    missingFields.push('confidence (invalid)');
  }
  if (!(Number(fields.recentSalesCount) >= 0)) {
    missingFields.push('recentSalesCount (invalid)');
  }
  if (!fields.computedAt) missingFields.push('computedAt (empty)');

  return {
    skipped: false,
    skipReason: null,
    docId: mapped.docId,
    fields,
    malformed: missingFields.length > 0,
    missingFields,
  };
}

/**
 * @param {FigureValidationRecord} record
 * @returns {ValidationStatusValue}
 */
export function classifyFigureValidationStatus(record) {
  if (record.failures.length > 0) {
    return ValidationStatus.FAIL;
  }
  if (record.warnings.length > 0) {
    return ValidationStatus.WARNING;
  }
  return ValidationStatus.PASS;
}

/**
 * @param {FigureValidationRecord[]} figures
 * @returns {{ PASS: number, WARNING: number, FAIL: number }}
 */
export function summarizeValidationCounts(figures) {
  return figures.reduce(
    (acc, figure) => {
      acc[figure.status] += 1;
      return acc;
    },
    { PASS: 0, WARNING: 0, FAIL: 0 },
  );
}

/**
 * @param {ValidationStatusValue} status
 * @returns {ProductionReadinessValue}
 */
export function deriveProductionReadiness(status) {
  if (status === ValidationStatus.FAIL) {
    return ProductionReadiness.NOT_READY;
  }
  if (status === ValidationStatus.WARNING) {
    return ProductionReadiness.READY_WITH_WARNINGS;
  }
  return ProductionReadiness.READY_FOR_LIVE_DATA_SOURCE;
}

/**
 * @param {SnapshotValidationAudit} audit
 * @returns {string}
 */
export function buildProductionReadinessExplanation(audit) {
  if (audit.productionReadiness === ProductionReadiness.NOT_READY) {
    return (
      `${audit.counts.FAIL} figure(s) failed validation. ` +
      'Resolve malformed snapshot or Firestore payloads and plan skips before live data.'
    );
  }

  if (audit.productionReadiness === ProductionReadiness.READY_WITH_WARNINGS) {
    return (
      `${audit.counts.WARNING} figure(s) produced warnings under fixture mode — ` +
      'typically zero matcher hits on generic fixture titles or skipped Firestore writes when median is null. ' +
      'Pipeline shape is sound; re-run against live Marketplace Insights data before production.'
    );
  }

  return (
    'All sampled figures passed validation under fixture mode. ' +
    'Pipeline is structurally ready for live data source integration.'
  );
}

/**
 * @param {FigureValidationRecord[]} figures
 * @returns {{
 *   duplicateQueries: string[],
 *   searchTermIssueSummary: Record<string, number>,
 * }}
 */
export function buildSearchTermReview(figures) {
  /** @type {Set<string>} */
  const globalQueries = new Set();
  /** @type {string[]} */
  const duplicateQueries = [];
  /** @type {Record<string, number>} */
  const searchTermIssueSummary = {};

  for (const figure of figures) {
    for (const issue of figure.searchTermIssues) {
      searchTermIssueSummary[issue.code] =
        (searchTermIssueSummary[issue.code] ?? 0) + 1;
    }

    for (const term of figure.searchTerms) {
      const key = term.trim().toLowerCase();
      if (!key) continue;
      if (globalQueries.has(key)) {
        duplicateQueries.push(term);
      } else {
        globalQueries.add(key);
      }
    }
  }

  return {
    duplicateQueries: [...new Set(duplicateQueries)],
    searchTermIssueSummary,
  };
}

/**
 * @param {ReturnType<typeof loadCatalogBundle>} bundle
 * @param {string} figureId
 * @param {{ fetchMode?: 'fixture' | 'live' }} [options]
 * @returns {Promise<FigureValidationRecord>}
 */
export async function auditFigureValidation(bundle, figureId, options = {}) {
  const fetchMode = options.fetchMode ?? 'fixture';
  const category = FIGURE_CATEGORY_BY_ID[figureId] ?? 'Other';

  /** @type {string[]} */
  const warnings = [];
  /** @type {string[]} */
  const failures = [];

  const figure = findFigureById(bundle, figureId);
  if (!figure) {
    return {
      figureId,
      displayName: '(not found)',
      seriesId: '',
      seriesDisplayName: '',
      brandId: '',
      brandDisplayName: '',
      category,
      status: ValidationStatus.FAIL,
      warnings,
      failures: [`Figure not found in catalog: ${figureId}`],
      searchTerms: [],
      usesSearchTermsOverride: false,
      searchTermIssues: [],
      fetchSkipped: true,
      fetchSkipReason: 'FIGURE_NOT_FOUND',
      fetchedListingCount: 0,
      fixtureListingTitles: [],
      matchedCount: 0,
      rejectedCount: 0,
      excludedCount: 0,
      topRejectReasons: [],
      matchedTitles: [],
      rejectedSamples: [],
      sampleSize: 0,
      medianPrice: null,
      averagePrice: null,
      minPrice: null,
      maxPrice: null,
      snapshotDocument: null,
      snapshotMalformed: true,
      snapshotMissingFields: ['(entire document)'],
      firestoreSkipped: true,
      firestoreSkipReason: 'figure not found',
      firestoreDocId: null,
      firestoreFields: null,
      firestoreMalformed: false,
      firestoreMissingFields: [],
    };
  }

  const { brand, series } = buildCatalogContextForFigure(figure, bundle);
  const plan = buildFigureSearchPlanById(bundle, figureId);

  if (!plan) {
    failures.push('Could not build search plan');
  }

  const searchTerms = plan?.searchTerms ?? [];
  const searchTermIssues = detectSearchTermIssues(searchTerms);
  for (const issue of searchTermIssues) {
    warnings.push(`searchTerm:${issue.code}: ${issue.message}`);
  }

  if (plan?.skipReason === 'NO_SEARCH_TERMS') {
    failures.push('Search plan skipped: NO_SEARCH_TERMS');
  } else if (plan?.skipReason === 'DISABLED') {
    warnings.push('Figure disabled in market metadata');
  }

  if (
    plan &&
    !plan.usesSearchTermsOverride &&
    figure.aliases?.length > 0 &&
    searchTerms.length > 0
  ) {
    const aliasUsed = figure.aliases.some((alias) =>
      searchTerms.some((term) =>
        term.toLowerCase().includes(alias.toLowerCase()),
      ),
    );
    if (!aliasUsed) {
      warnings.push('missing_alias_usage: figure has catalog aliases not reflected in search terms');
    }
  }

  let fetchResult = {
    skipped: true,
    skipReason: plan?.skipReason ?? 'NO_PLAN',
    listings: [],
  };

  if (plan && !plan.skipReason) {
    fetchResult = await fetchFigureCompletedSales(plan, { fetchMode });
  }

  if (fetchResult.skipped) {
    failures.push(`Fetch skipped: ${fetchResult.skipReason}`);
  }

  const fixtureListingTitles = fetchResult.listings.map((listing) => listing.title);

  let pipeline = null;
  if (!fetchResult.skipped && figure) {
    pipeline = buildFigureSnapshot(fetchResult.listings, figure, bundle, {
      dataSource: fetchMode === 'fixture' ? 'fixture' : 'live',
    });
  }

  const matchResult = pipeline?.matchResult;
  const aggregation = pipeline?.aggregation;
  const snapshotDocument = pipeline?.document ?? null;

  const snapshotValidation = validateSnapshotDocumentShape(snapshotDocument);
  if (snapshotDocument && snapshotValidation.malformed) {
    failures.push(
      `Malformed snapshot document: missing ${snapshotValidation.missingFields.join(', ')}`,
    );
  } else if (!snapshotDocument && !fetchResult.skipped) {
    failures.push('No snapshot document produced');
  }

  const firestoreMapped = snapshotDocument
    ? buildFirestoreDocument(snapshotDocument)
    : null;
  const firestoreValidation = snapshotDocument
    ? validateFirestorePayload(snapshotDocument, firestoreMapped)
    : {
        skipped: true,
        skipReason: 'no snapshot',
        docId: null,
        fields: null,
        malformed: false,
        missingFields: [],
      };

  if (firestoreValidation.malformed) {
    failures.push(
      `Malformed Firestore payload: missing ${firestoreValidation.missingFields.join(', ')}`,
    );
  } else if (firestoreValidation.skipped && aggregation?.medianPrice != null) {
    warnings.push(
      `Firestore write skipped unexpectedly: ${firestoreValidation.skipReason}`,
    );
  } else if (firestoreValidation.skipped && !fetchResult.skipped) {
    warnings.push(`Firestore write skipped: ${firestoreValidation.skipReason}`);
  }

  if (
    fetchResult.listings.length > 0 &&
    (matchResult?.stats.matched ?? 0) === 0
  ) {
    warnings.push(
      'Zero matcher hits on fetched listings (common with generic fixture titles)',
    );
  }

  const topRejectReasons = aggregateRejectReasons(
    matchResult?.unmatchedListings ?? [],
  );

  const rejectedSamples = (matchResult?.unmatchedListings ?? [])
    .filter((entry) => entry.reason === 'noMatch')
    .slice(0, 5)
    .map((entry) => ({
      title: entry.listing.title,
      reason: entry.rejectReason ?? 'noMatch',
    }));

  /** @type {FigureValidationRecord} */
  const record = {
    figureId: figure.id,
    displayName: figure.displayName,
    seriesId: figure.seriesId,
    seriesDisplayName: series?.displayName ?? '',
    brandId: figure.brandId ?? brand?.id ?? '',
    brandDisplayName: brand?.displayName ?? '',
    category,
    status: ValidationStatus.PASS,
    warnings,
    failures,
    searchTerms,
    usesSearchTermsOverride: plan?.usesSearchTermsOverride ?? false,
    searchTermIssues,
    fetchSkipped: fetchResult.skipped,
    fetchSkipReason: fetchResult.skipReason,
    fetchedListingCount: fetchResult.listings.length,
    fixtureListingTitles,
    matchedCount: matchResult?.stats.matched ?? 0,
    rejectedCount: matchResult?.stats.unmatched ?? 0,
    excludedCount: matchResult?.stats.excluded ?? 0,
    topRejectReasons,
    matchedTitles: (matchResult?.matchedListings ?? []).map((l) => l.title),
    rejectedSamples,
    sampleSize: aggregation?.sampleSize ?? 0,
    medianPrice: aggregation?.medianPrice ?? null,
    averagePrice: aggregation?.averagePrice ?? null,
    minPrice: aggregation?.minPrice ?? null,
    maxPrice: aggregation?.maxPrice ?? null,
    snapshotDocument,
    snapshotMalformed: snapshotValidation.malformed,
    snapshotMissingFields: snapshotValidation.missingFields,
    firestoreSkipped: firestoreValidation.skipped,
    firestoreSkipReason: firestoreValidation.skipReason,
    firestoreDocId: firestoreValidation.docId,
    firestoreFields: firestoreValidation.fields,
    firestoreMalformed: firestoreValidation.malformed,
    firestoreMissingFields: firestoreValidation.missingFields,
  };

  record.status = classifyFigureValidationStatus(record);
  return record;
}

/**
 * @param {{
 *   figureIds?: readonly string[],
 *   fetchMode?: 'fixture' | 'live',
 *   bundle?: ReturnType<typeof loadCatalogBundle>,
 *   generatedAt?: string,
 * }} [options]
 * @returns {Promise<SnapshotValidationAudit>}
 */
export async function runSnapshotValidationAudit(options = {}) {
  const bundle = options.bundle ?? loadCatalogBundle();
  const figureIds = options.figureIds ?? DEFAULT_VALIDATION_SAMPLE;
  const fetchMode = options.fetchMode ?? 'fixture';
  const generatedAt = options.generatedAt ?? new Date().toISOString();

  if (figureIds.length === 0) {
    const emptyAudit = {
      generatedAt,
      sampleSize: 0,
      status: ValidationStatus.PASS,
      productionReadiness: ProductionReadiness.READY_FOR_LIVE_DATA_SOURCE,
      productionReadinessExplanation:
        'Empty sample — no figures to validate.',
      counts: { PASS: 0, WARNING: 0, FAIL: 0 },
      figures: [],
      warnings: [],
      failures: [],
      searchTermReview: {
        duplicateQueries: [],
        searchTermIssueSummary: {},
      },
      matcherReview: [],
      firestoreReview: { writable: 0, skipped: 0, malformed: 0 },
    };
    emptyAudit.productionReadinessExplanation =
      buildProductionReadinessExplanation(emptyAudit);
    return emptyAudit;
  }

  /** @type {FigureValidationRecord[]} */
  const figures = [];
  for (const figureId of figureIds) {
    figures.push(await auditFigureValidation(bundle, figureId, { fetchMode }));
  }

  const counts = summarizeValidationCounts(figures);
  const status =
    counts.FAIL > 0
      ? ValidationStatus.FAIL
      : counts.WARNING > 0
        ? ValidationStatus.WARNING
        : ValidationStatus.PASS;

  const searchTermReview = buildSearchTermReview(figures);
  const matcherReview = figures.map((figure) => ({
    figureId: figure.figureId,
    matched: figure.matchedCount,
    rejected: figure.rejectedCount,
    topRejectReasons: figure.topRejectReasons,
  }));

  const firestoreReview = {
    writable: figures.filter((f) => !f.firestoreSkipped && !f.firestoreMalformed)
      .length,
    skipped: figures.filter((f) => f.firestoreSkipped).length,
    malformed: figures.filter((f) => f.firestoreMalformed).length,
  };

  /** @type {string[]} */
  const warnings = [];
  /** @type {string[]} */
  const failures = [];
  for (const figure of figures) {
    for (const warning of figure.warnings) {
      warnings.push(`${figure.figureId}: ${warning}`);
    }
    for (const failure of figure.failures) {
      failures.push(`${figure.figureId}: ${failure}`);
    }
  }

  const audit = {
    generatedAt,
    sampleSize: figures.length,
    status,
    productionReadiness: deriveProductionReadiness(status),
    productionReadinessExplanation: '',
    counts,
    figures,
    warnings,
    failures,
    searchTermReview,
    matcherReview,
    firestoreReview,
  };

  audit.productionReadinessExplanation =
    buildProductionReadinessExplanation(audit);

  return audit;
}

/**
 * @param {unknown} value
 * @returns {string}
 */
function formatJsonBlock(value) {
  return JSON.stringify(value, null, 2);
}

/**
 * @param {SnapshotValidationAudit} audit
 * @returns {string}
 */
export function formatValidationReportMarkdown(audit) {
  const lines = [];

  lines.push('# Snapshot Validation Report');
  lines.push('');
  lines.push(`Generated: ${audit.generatedAt}`);
  lines.push('');
  lines.push('## Section 1 — Summary');
  lines.push('');
  lines.push(`Figures Reviewed: ${audit.sampleSize}`);
  lines.push('');
  lines.push(`Validation Status: **${audit.status}**`);
  lines.push('');
  lines.push('Counts:');
  lines.push(`- PASS: ${audit.counts.PASS}`);
  lines.push(`- WARNING: ${audit.counts.WARNING}`);
  lines.push(`- FAIL: ${audit.counts.FAIL}`);
  lines.push('');
  lines.push('## Section 2 — Per Figure Review');
  lines.push('');

  for (const figure of audit.figures) {
    lines.push('---');
    lines.push('');
    lines.push(`### ${figure.displayName} (${figure.status})`);
    lines.push('');
    lines.push(`**Figure ID:** ${figure.figureId}`);
    lines.push(`**Display Name:** ${figure.displayName}`);
    lines.push(`**Series:** ${figure.seriesDisplayName} (\`${figure.seriesId}\`)`);
    lines.push(`**Brand:** ${figure.brandDisplayName} (\`${figure.brandId}\`)`);
    lines.push(`**Category:** ${figure.category}`);
    lines.push('');
    lines.push('**Search terms:**');
    if (figure.searchTerms.length === 0) {
      lines.push('(none)');
    } else {
      figure.searchTerms.forEach((term, index) => {
        lines.push(`${index + 1}. ${term}`);
      });
    }
    lines.push('');
    lines.push('**Fixture listing titles:**');
    if (figure.fixtureListingTitles.length === 0) {
      lines.push('(none)');
    } else {
      for (const title of figure.fixtureListingTitles) {
        lines.push(`- ${title}`);
      }
    }
    lines.push('');
    lines.push('**Matcher results:**');
    lines.push(`- Matched listings: ${figure.matchedCount}`);
    lines.push(`- Rejected listings: ${figure.rejectedCount}`);
    lines.push(`- Excluded listings: ${figure.excludedCount}`);
    lines.push('- Top reject reasons:');
    if (figure.topRejectReasons.length === 0) {
      lines.push('  - (none)');
    } else {
      for (const row of figure.topRejectReasons) {
        lines.push(`  - ${row.reason}: ${row.count}`);
      }
    }
    lines.push('');
    lines.push('**Aggregation:**');
    lines.push(`- Sample size: ${figure.sampleSize}`);
    lines.push(`- Median: ${figure.medianPrice ?? '(none)'}`);
    lines.push(`- Average: ${figure.averagePrice ?? '(none)'}`);
    lines.push(`- Min: ${figure.minPrice ?? '(none)'}`);
    lines.push(`- Max: ${figure.maxPrice ?? '(none)'}`);
    lines.push('');
    lines.push('**Snapshot document:**');
    lines.push('```json');
    lines.push(formatJsonBlock(figure.snapshotDocument));
    lines.push('```');
    lines.push('');
    lines.push('**Firestore payload:**');
    if (figure.firestoreSkipped) {
      lines.push(`Skipped (${figure.firestoreSkipReason})`);
    } else {
      lines.push('```json');
      lines.push(
        formatJsonBlock({
          docId: figure.firestoreDocId,
          fields: figure.firestoreFields,
        }),
      );
      lines.push('```');
    }
    if (figure.warnings.length > 0) {
      lines.push('');
      lines.push('**Warnings:**');
      for (const warning of figure.warnings) {
        lines.push(`- ${warning}`);
      }
    }
    if (figure.failures.length > 0) {
      lines.push('');
      lines.push('**Failures:**');
      for (const failure of figure.failures) {
        lines.push(`- ${failure}`);
      }
    }
    lines.push('');
  }

  lines.push('## Section 3 — Search Term Review');
  lines.push('');
  lines.push('**Duplicate queries across sample:**');
  if (audit.searchTermReview.duplicateQueries.length === 0) {
    lines.push('- (none detected)');
  } else {
    for (const query of audit.searchTermReview.duplicateQueries) {
      lines.push(`- ${query}`);
    }
  }
  lines.push('');
  lines.push('**Issue counts:**');
  const issueEntries = Object.entries(audit.searchTermReview.searchTermIssueSummary);
  if (issueEntries.length === 0) {
    lines.push('- (none)');
  } else {
    for (const [code, count] of issueEntries) {
      lines.push(`- ${code}: ${count}`);
    }
  }
  lines.push('');
  lines.push('## Section 4 — Matcher Review');
  lines.push('');
  for (const row of audit.matcherReview) {
    lines.push(`### ${row.figureId}`);
    lines.push(`- Accepted: ${row.matched}`);
    lines.push(`- Rejected: ${row.rejected}`);
    lines.push('- Top reject reasons:');
    if (row.topRejectReasons.length === 0) {
      lines.push('  - (none)');
    } else {
      for (const reason of row.topRejectReasons) {
        lines.push(`  - ${reason.reason}: ${reason.count}`);
      }
    }
    lines.push('');
  }

  lines.push('## Section 5 — Firestore Payload Review');
  lines.push('');
  lines.push(`- Writable payloads: ${audit.firestoreReview.writable}`);
  lines.push(`- Skipped (expected when median null): ${audit.firestoreReview.skipped}`);
  lines.push(`- Malformed: ${audit.firestoreReview.malformed}`);
  lines.push('');
  lines.push('Required fields checked: `figureId`, `seriesId`, `estimatedValueUsd`, `confidence`, `recentSalesCount`, `computedAt`');
  lines.push('');
  lines.push('## Section 6 — Production Readiness Recommendation');
  lines.push('');
  lines.push(`**${audit.productionReadiness}**`);
  lines.push('');
  lines.push(audit.productionReadinessExplanation);
  lines.push('');
  lines.push('## Sprint 2 Step 4D Recommendation');
  lines.push('');
  lines.push(
    'Run a **live data validation pilot** on 1–2 series (Big Into Energy + Have a Seat) once Marketplace Insights access is granted. ' +
      'Compare matcher acceptance rates and Firestore payload quality against this fixture baseline before scheduling full-catalog runs.',
  );

  return lines.join('\n');
}

/**
 * @param {SnapshotValidationAudit} audit
 * @returns {object}
 */
export function serializeValidationAuditJson(audit) {
  return {
    generatedAt: audit.generatedAt,
    sampleSize: audit.sampleSize,
    status: audit.status,
    productionReadiness: audit.productionReadiness,
    productionReadinessExplanation: audit.productionReadinessExplanation,
    counts: audit.counts,
    figures: audit.figures.map((figure) => ({
      figureId: figure.figureId,
      displayName: figure.displayName,
      seriesId: figure.seriesId,
      seriesDisplayName: figure.seriesDisplayName,
      brandId: figure.brandId,
      brandDisplayName: figure.brandDisplayName,
      category: figure.category,
      status: figure.status,
      warnings: figure.warnings,
      failures: figure.failures,
      searchTerms: figure.searchTerms,
      searchTermIssues: figure.searchTermIssues,
      fixtureListingTitles: figure.fixtureListingTitles,
      matchedCount: figure.matchedCount,
      rejectedCount: figure.rejectedCount,
      topRejectReasons: figure.topRejectReasons,
      aggregation: {
        sampleSize: figure.sampleSize,
        medianPrice: figure.medianPrice,
        averagePrice: figure.averagePrice,
        minPrice: figure.minPrice,
        maxPrice: figure.maxPrice,
      },
      snapshotDocument: figure.snapshotDocument,
      snapshotMalformed: figure.snapshotMalformed,
      snapshotMissingFields: figure.snapshotMissingFields,
      firestore: {
        skipped: figure.firestoreSkipped,
        skipReason: figure.firestoreSkipReason,
        docId: figure.firestoreDocId,
        fields: figure.firestoreFields,
        malformed: figure.firestoreMalformed,
        missingFields: figure.firestoreMissingFields,
      },
    })),
    warnings: audit.warnings,
    failures: audit.failures,
    searchTermReview: audit.searchTermReview,
    matcherReview: audit.matcherReview,
    firestoreReview: audit.firestoreReview,
  };
}

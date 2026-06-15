#!/usr/bin/env node
/**
 * DEV ONLY — Manual matcher review utility.
 *
 * Usage (from repo root):
 *   node tools/market_intel/debug_matcher.mjs
 *   node tools/market_intel/debug_matcher.mjs path/to/titles.txt
 *
 * Reads one listing title per line. Blank lines and # comments are skipped.
 * Scores each title against Pop Mart catalog figures using seed JSON +
 * market_metadata.json overrides (same buildMatcherContext path as tests).
 */

import { readFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

import {
  DEFAULT_MATCH_THRESHOLD,
  buildMatcherContext,
  matchCatalogFigure,
} from './_catalog_matcher.mjs';
import { normalizeMarketTitle, findExcludeTerm } from './_title_normalizer.mjs';

const __dirname = dirname(fileURLToPath(import.meta.url));
const repoRoot = join(__dirname, '..', '..');
const defaultTitlesPath = join(__dirname, 'edge_case_titles.txt');

/** Review defaults used only when metadata marketAliases is empty (dev inspection). */
const REVIEW_MARKET_ALIASES_BY_METADATA_KEY = Object.freeze({
  lucky_big_into_energy_popmart: ['lucky', 'ラッキー', '幸运'],
});

/**
 * Series rows used for seriesMismatch detection — aligned with matcher unit tests
 * to avoid generic single-token false positives from the full catalog (e.g. "monsters").
 *
 * @param {object[]} allSeries
 * @param {string} targetSeriesId
 * @returns {object[]}
 */
function reviewConflictSeries(allSeries, targetSeriesId) {
  const explicitConflictIds = new Set([
    'the_monsters_have_a_seat_vinyl_plush',
    'the_monsters_exciting_macaron_vinyl_face',
    targetSeriesId,
  ]);

  const selected = allSeries.filter((row) => explicitConflictIds.has(row.id));
  if (selected.some((row) => row.id === targetSeriesId)) {
    return selected;
  }

  const target = allSeries.find((row) => row.id === targetSeriesId);
  return target ? [...selected, target] : selected;
}

/**
 * @param {string | null} metadataKey
 * @param {string[]} metadataAliases
 * @returns {{ aliases: string[], usedReviewDefault: boolean }}
 */
function resolveReviewMarketAliases(metadataKey, metadataAliases) {
  if (metadataAliases.length > 0) {
    return { aliases: metadataAliases, usedReviewDefault: false };
  }

  if (metadataKey && REVIEW_MARKET_ALIASES_BY_METADATA_KEY[metadataKey]) {
    return {
      aliases: REVIEW_MARKET_ALIASES_BY_METADATA_KEY[metadataKey],
      usedReviewDefault: true,
    };
  }

  return { aliases: [], usedReviewDefault: false };
}

/** Architecture example ids → canonical catalog figure ids (DEV_VALIDATION.md). */
const METADATA_KEY_TO_CATALOG_FIGURE_ID = Object.freeze({
  lucky_big_into_energy_popmart:
    'the_monsters_big_into_energy_vinyl_plush_pendant_luck',
  hope_big_into_energy_popmart:
    'the_monsters_big_into_energy_vinyl_plush_pendant_hope',
});

const HARD_REJECT_BREAKDOWN_KEYS = [
  'crossFigureContamination',
  'seriesMismatch',
  'wrongFigureName',
  'secretMismatch',
  'productTypeReject',
];

const SEPARATOR = '==================================================';

/**
 * @typedef {Object} MatcherCandidate
 * @property {string} catalogFigureId
 * @property {string | null} metadataKey
 * @property {string} displayName
 * @property {ReturnType<typeof buildMatcherContext>} context
 * @property {{ marketAliases: string[], matchThreshold: number | null, disabled?: boolean }} metadata
 */

/**
 * @typedef {Object} TitleReview
 * @property {string} raw
 * @property {string} normalized
 * @property {ReturnType<typeof matchCatalogFigure>} result
 * @property {MatcherCandidate} candidate
 */

function loadTitles(path) {
  const raw = readFileSync(path, 'utf8');
  return raw
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter((line) => line.length > 0 && !line.startsWith('#'));
}

function loadJson(relativePath) {
  return JSON.parse(readFileSync(join(repoRoot, relativePath), 'utf8'));
}

function loadMarketMetadata() {
  return JSON.parse(
    readFileSync(join(__dirname, 'market_metadata.json'), 'utf8'),
  );
}

/**
 * @param {string} key
 * @param {object} entry
 * @param {Set<string>} catalogFigureIds
 * @returns {string | null}
 */
function resolveCatalogFigureId(key, entry, catalogFigureIds) {
  if (entry.catalogFigureId) {
    return entry.catalogFigureId;
  }
  if (METADATA_KEY_TO_CATALOG_FIGURE_ID[key]) {
    return METADATA_KEY_TO_CATALOG_FIGURE_ID[key];
  }
  if (catalogFigureIds.has(key)) {
    return key;
  }
  return null;
}

/**
 * @param {Record<string, object>} metadataFigures
 * @param {Set<string>} catalogFigureIds
 * @returns {Map<string, { key: string, entry: object }>}
 */
function buildCatalogToMetadataMap(metadataFigures, catalogFigureIds) {
  /** @type {Map<string, { key: string, entry: object }>} */
  const map = new Map();

  for (const [key, entry] of Object.entries(metadataFigures ?? {})) {
    const catalogFigureId = resolveCatalogFigureId(key, entry, catalogFigureIds);
    if (catalogFigureId) {
      map.set(catalogFigureId, { key, entry });
    }
  }

  return map;
}

/**
 * @returns {{
 *   figures: object[],
 *   series: object[],
 *   brands: object[],
 *   ips: object[],
 *   popMartSeries: object[],
 *   metadata: object,
 *   catalogToMetadata: Map<string, { key: string, entry: object }>,
 * }}
 */
function loadCatalogBundle() {
  const figures = loadJson('tools/seed/figures.json');
  const series = loadJson('tools/seed/series.json');
  const brands = loadJson('tools/seed/brands.json');
  const ips = loadJson('tools/seed/ips.json');
  const metadata = loadMarketMetadata();

  const catalogFigureIds = new Set(figures.map((figure) => figure.id));
  const catalogToMetadata = buildCatalogToMetadataMap(
    metadata.figures,
    catalogFigureIds,
  );

  return {
    figures,
    series,
    brands,
    ips,
    popMartSeries: series.filter((row) => row.brandId === 'pop_mart'),
    metadata,
    catalogToMetadata,
  };
}

/**
 * @param {ReturnType<typeof loadCatalogBundle>} bundle
 * @returns {MatcherCandidate[]}
 */
function buildMatcherCandidates(bundle) {
  const seriesById = new Map(bundle.series.map((row) => [row.id, row]));
  const brandById = new Map(bundle.brands.map((row) => [row.id, row]));
  const ipById = new Map(bundle.ips.map((row) => [row.id, row]));
  const figuresBySeries = new Map();

  for (const figure of bundle.figures) {
    if (figure.brandId !== 'pop_mart') continue;
    const bucket = figuresBySeries.get(figure.seriesId) ?? [];
    bucket.push(figure);
    figuresBySeries.set(figure.seriesId, bucket);
  }

  const metadataCatalogFigureIds = [...bundle.catalogToMetadata.keys()];
  const metadataSeriesIds = new Set(
    metadataCatalogFigureIds
      .map((figureId) =>
        bundle.figures.find((figure) => figure.id === figureId)?.seriesId,
      )
      .filter(Boolean),
  );

  /** @type {MatcherCandidate[]} */
  const candidates = [];

  for (const figure of bundle.figures) {
    if (figure.brandId !== 'pop_mart') continue;
    if (
      !metadataCatalogFigureIds.includes(figure.id) &&
      !metadataSeriesIds.has(figure.seriesId)
    ) {
      continue;
    }

    const mapped = bundle.catalogToMetadata.get(figure.id);
    const metadataEntry = mapped?.entry;
    if (metadataEntry?.disabled === true) continue;

    const resolvedAliases = resolveReviewMarketAliases(
      mapped?.key ?? null,
      metadataEntry?.marketAliases ?? [],
    );

    const targetSeries = seriesById.get(figure.seriesId);
    const brand = brandById.get(figure.brandId);
    if (!targetSeries || !brand) continue;

    const ip = ipById.get(targetSeries.ipId ?? figure.ipId);
    const siblings = (figuresBySeries.get(figure.seriesId) ?? []).filter(
      (row) => row.id !== figure.id,
    );

    candidates.push({
      catalogFigureId: figure.id,
      metadataKey: mapped?.key ?? null,
      displayName: figure.displayName,
      usedReviewDefaultAliases: resolvedAliases.usedReviewDefault,
      context: buildMatcherContext({
        targetFigure: figure,
        series: targetSeries,
        brand,
        ip,
        siblingFigures: siblings,
        allSeries: reviewConflictSeries(bundle.popMartSeries, targetSeries.id),
      }),
      metadata: {
        marketAliases: resolvedAliases.aliases,
        matchThreshold: metadataEntry?.matchThreshold ?? null,
      },
    });
  }

  return candidates;
}

/**
 * @param {string} normalizedTitle
 * @param {MatcherCandidate[]} candidates
 * @returns {{ result: ReturnType<typeof matchCatalogFigure>, candidate: MatcherCandidate }}
 */
function pickBestMatch(normalizedTitle, candidates) {
  /** @type {{ result: ReturnType<typeof matchCatalogFigure>, candidate: MatcherCandidate } | null} */
  let bestAccepted = null;
  /** @type {{ result: ReturnType<typeof matchCatalogFigure>, candidate: MatcherCandidate } | null} */
  let bestRejected = null;

  for (const candidate of candidates) {
    const result = matchCatalogFigure(
      normalizedTitle,
      candidate.context,
      candidate.metadata,
    );

    if (result.matched) {
      if (
        !bestAccepted ||
        result.score > bestAccepted.result.score ||
        (result.score === bestAccepted.result.score &&
          candidate.displayName.localeCompare(bestAccepted.candidate.displayName) <
            0)
      ) {
        bestAccepted = { result, candidate };
      }
      continue;
    }

    if (
      !bestRejected ||
      result.score > bestRejected.result.score ||
      (result.score === bestRejected.result.score &&
        preferRejectReason(result.rejectReason, bestRejected.result.rejectReason))
    ) {
      bestRejected = { result, candidate };
    }
  }

  if (bestAccepted) {
    return bestAccepted;
  }

  return bestRejected ?? {
    result: matchCatalogFigure(normalizedTitle, candidates[0].context, candidates[0].metadata),
    candidate: candidates[0],
  };
}

/**
 * @param {string | null} next
 * @param {string | null} current
 * @returns {boolean}
 */
function preferRejectReason(next, current) {
  if (!current) return true;
  if (!next) return false;
  if (next.startsWith('hardReject') || HARD_REJECT_BREAKDOWN_KEYS.includes(next)) {
    return !HARD_REJECT_BREAKDOWN_KEYS.includes(current);
  }
  return false;
}

/**
 * @param {number} score
 * @returns {string}
 */
function formatScore(score) {
  return score.toFixed(2);
}

/**
 * @param {number | null | undefined} threshold
 * @returns {string}
 */
function formatThreshold(threshold) {
  return (threshold ?? DEFAULT_MATCH_THRESHOLD).toFixed(2);
}

/**
 * @param {ReturnType<typeof matchCatalogFigure>} result
 * @returns {string[]}
 */
function formatAcceptReasonLines(result) {
  const lines = [];
  const { signals } = result;

  if (signals.brandMatch) lines.push('+ brandMatch');
  if (signals.seriesMatchFull) {
    lines.push('+ seriesMatch:full');
  } else if (signals.seriesMatchPartial) {
    lines.push('+ seriesMatch:partial');
  }
  if (signals.figureNameMatch) lines.push('+ figureNameMatch');
  if (signals.figureIdentityMatch) lines.push('+ figureIdentityMatch');
  if (signals.marketAliasMatch) {
    lines.push(
      `+ marketAliasMatch:${signals.matchedMarketAliasTokens.join(',') || 'true'}`,
    );
  }
  if (signals.secretSignalConsistent) lines.push('+ secretSignalConsistent');

  for (const reason of result.reasons) {
    if (
      reason.startsWith('gate:') ||
      reason === 'accepted' ||
      reason.startsWith('score=') ||
      reason.startsWith('threshold=')
    ) {
      continue;
    }
    if (!lines.some((line) => line.includes(reason))) {
      lines.push(`· ${reason}`);
    }
  }

  return lines;
}

/**
 * @param {TitleReview} review
 */
function printTitleReport(review) {
  const { raw, normalized, result, candidate } = review;
  const excludeMatch = findExcludeTerm(raw);
  const normalizerExcluded = excludeMatch !== null;

  console.log(SEPARATOR);
  console.log('RAW:');
  console.log(raw);
  console.log('');
  console.log('NORMALIZED:');
  console.log(normalized);
  console.log('');
  console.log('NORMALIZER_EXCLUDED:');
  console.log(normalizerExcluded ? 'yes' : 'no');
  if (normalizerExcluded) {
    console.log('');
    console.log('NORMALIZER_EXCLUDE_TERM:');
    console.log(excludeMatch.term);
  }
  console.log('');

  if (result.matched) {
    console.log('MATCHED:');
    console.log(candidate.displayName);
    console.log('');
    console.log('FIGURE_ID:');
    console.log(candidate.metadataKey ?? candidate.catalogFigureId);
    console.log('');
    console.log('SCORE:');
    console.log(formatScore(result.score));
    console.log('');
    console.log('THRESHOLD:');
    console.log(formatThreshold(result.effectiveThreshold));
    console.log('');
    console.log('RESULT:');
    console.log('ACCEPT');
    console.log('');
    console.log('REASONS:');
    for (const line of formatAcceptReasonLines(result)) {
      console.log(line);
    }
    console.log(SEPARATOR);
    return;
  }

  console.log('MATCHED:');
  console.log('(none)');
  console.log('');
  console.log('RESULT:');
  console.log('REJECT');
  console.log('');
  console.log('REJECT_REASON:');
  console.log(result.rejectReason ?? 'unknown');
  console.log('');
  console.log('REASONS:');
  for (const reason of result.reasons) {
    console.log(reason);
  }
  console.log(SEPARATOR);
}

/**
 * @param {TitleReview[]} reviews
 */
function printSummary(reviews) {
  const accepted = reviews.filter((review) => review.result.matched);
  const rejected = reviews.filter((review) => !review.result.matched);

  console.log('');
  console.log('MATCH SUMMARY');
  console.log('');
  console.log(`Accepted: ${accepted.length}`);
  console.log(`Rejected: ${rejected.length}`);
  console.log('');
  console.log('Reject Breakdown');
  console.log('');

  /** @type {Record<string, number>} */
  const breakdown = Object.fromEntries(
    HARD_REJECT_BREAKDOWN_KEYS.map((key) => [key, 0]),
  );
  breakdown.thresholdOrGate = 0;
  breakdown.other = 0;

  for (const review of rejected) {
    const reason = review.result.rejectReason ?? 'other';
    if (reason in breakdown) {
      breakdown[reason] += 1;
    } else if (reason.startsWith('gate:') || reason === 'belowThreshold') {
      breakdown.thresholdOrGate += 1;
    } else {
      breakdown.other += 1;
    }
  }

  for (const key of HARD_REJECT_BREAKDOWN_KEYS) {
    console.log(`${key}: ${breakdown[key]}`);
  }
  console.log(`thresholdOrGate: ${breakdown.thresholdOrGate}`);
  if (breakdown.other > 0) {
    console.log(`other: ${breakdown.other}`);
  }

  console.log('');
  console.log('Top Accepted Figures');
  console.log('');

  /** @type {Map<string, number>} */
  const acceptedCounts = new Map();
  for (const review of accepted) {
    const label = review.candidate.displayName;
    acceptedCounts.set(label, (acceptedCounts.get(label) ?? 0) + 1);
  }

  const sortedAccepted = [...acceptedCounts.entries()].sort((a, b) => {
    if (b[1] !== a[1]) return b[1] - a[1];
    return a[0].localeCompare(b[0]);
  });

  if (sortedAccepted.length === 0) {
    console.log('(none)');
  } else {
    for (const [name, count] of sortedAccepted.slice(0, 15)) {
      console.log(`${name}: ${count}`);
    }
  }
}

function main() {
  const titlesPath = resolve(process.argv[2] ?? defaultTitlesPath);
  const titles = loadTitles(titlesPath);

  if (titles.length === 0) {
    console.error(`No titles found in ${titlesPath}`);
    process.exit(1);
  }

  const bundle = loadCatalogBundle();
  const candidates = buildMatcherCandidates(bundle);

  if (candidates.length === 0) {
    console.error('No matcher candidates built from catalog seed.');
    process.exit(1);
  }

  console.error(
    `debug_matcher: ${candidates.length} candidate figure(s) from metadata-linked catalog series`,
  );
  const reviewAliasCount = candidates.filter(
    (candidate) => candidate.usedReviewDefaultAliases,
  ).length;
  if (reviewAliasCount > 0) {
    console.error(
      `debug_matcher: ${reviewAliasCount} figure(s) use review-default marketAliases (metadata empty)`,
    );
  }
  console.error(
    `debug_matcher: reading ${titles.length} title(s) from ${titlesPath}`,
  );
  console.error('');

  /** @type {TitleReview[]} */
  const reviews = [];

  for (const raw of titles) {
    const normalized = normalizeMarketTitle(raw);
    const { result, candidate } = pickBestMatch(normalized, candidates);
    const review = { raw, normalized, result, candidate };
    reviews.push(review);
    printTitleReport(review);
  }

  printSummary(reviews);
}

main();

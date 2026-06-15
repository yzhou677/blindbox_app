#!/usr/bin/env node
/**
 * DEV ONLY — Manual search term review utility.
 *
 * Usage (from repo root):
 *   node tools/market_intel/debug_search_terms.mjs
 *   node tools/market_intel/debug_search_terms.mjs --limit 50
 *   node tools/market_intel/debug_search_terms.mjs --series big_into_energy
 *   node tools/market_intel/debug_search_terms.mjs --figure lucky_big_into_energy_popmart
 *
 * Loads real catalog seed JSON + market_metadata.json and prints derived search terms.
 */

import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

import {
  deriveSearchTerms,
  extractSeriesDistinctive,
  resolveIpToken,
} from './_search_term_derivation.mjs';

const __dirname = dirname(fileURLToPath(import.meta.url));
const repoRoot = join(__dirname, '..', '..');
const SEPARATOR = '==================================================';

/** Architecture example ids → canonical catalog figure ids (DEV_VALIDATION.md). */
const METADATA_KEY_TO_CATALOG_FIGURE_ID = Object.freeze({
  lucky_big_into_energy_popmart:
    'the_monsters_big_into_energy_vinyl_plush_pendant_luck',
  hope_big_into_energy_popmart:
    'the_monsters_big_into_energy_vinyl_plush_pendant_hope',
});

/** Review defaults when metadata marketAliases is empty (dev inspection only). */
const REVIEW_MARKET_ALIASES_BY_METADATA_KEY = Object.freeze({
  lucky_big_into_energy_popmart: ['Lucky'],
});

const WARNING_TYPES = Object.freeze([
  'onlyOneTerm',
  'tier2Brandless',
  'noIpAlias',
  'termTooLong',
  'aliasIdenticalToPrimary',
  'noTermsGenerated',
  'duplicateTerms',
  'shortSeriesDistinctive',
]);

/**
 * @typedef {Object} CliOptions
 * @property {number | null} limit
 * @property {string | null} seriesFilter
 * @property {string | null} figureFilter
 */

/**
 * @param {string[]} argv
 * @returns {CliOptions}
 */
function parseCliOptions(argv) {
  /** @type {CliOptions} */
  const options = {
    limit: null,
    seriesFilter: null,
    figureFilter: null,
  };

  for (let index = 2; index < argv.length; index += 1) {
    const arg = argv[index];

    if (arg === '--limit') {
      const value = Number(argv[index + 1]);
      if (!Number.isFinite(value) || value <= 0) {
        console.error('Expected a positive number after --limit');
        process.exit(1);
      }
      options.limit = Math.floor(value);
      index += 1;
      continue;
    }

    if (arg === '--series') {
      const value = argv[index + 1]?.trim();
      if (!value) {
        console.error('Expected a value after --series');
        process.exit(1);
      }
      options.seriesFilter = value.toLowerCase();
      index += 1;
      continue;
    }

    if (arg === '--figure') {
      const value = argv[index + 1]?.trim();
      if (!value) {
        console.error('Expected a value after --figure');
        process.exit(1);
      }
      options.figureFilter = value.toLowerCase();
      index += 1;
      continue;
    }

    console.error(`Unknown argument: ${arg}`);
    process.exit(1);
  }

  return options;
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
 * @param {string | null} metadataKey
 * @param {string[]} metadataAliases
 * @returns {{ marketAliases: string[], usedReviewDefault: boolean }}
 */
function resolveReviewMetadataAliases(metadataKey, metadataAliases) {
  if (metadataAliases.length > 0) {
    return { marketAliases: metadataAliases, usedReviewDefault: false };
  }

  if (metadataKey && REVIEW_MARKET_ALIASES_BY_METADATA_KEY[metadataKey]) {
    return {
      marketAliases: REVIEW_MARKET_ALIASES_BY_METADATA_KEY[metadataKey],
      usedReviewDefault: true,
    };
  }

  return { marketAliases: [], usedReviewDefault: false };
}

/**
 * @param {{ displayName?: string, aliases?: string[] }} brand
 * @returns {string[]}
 */
function buildBrandPrefixes(brand) {
  const prefixes = [brand.displayName, ...(brand.aliases ?? [])]
    .map((value) => value?.trim())
    .filter(Boolean);

  return [...new Set(prefixes)];
}

/**
 * @param {string} term
 * @param {string[]} brandPrefixes
 * @returns {boolean}
 */
function isBrandedTerm(term, brandPrefixes) {
  return brandPrefixes.some(
    (prefix) => term === prefix || term.startsWith(`${prefix} `),
  );
}

/**
 * @param {object} figure
 * @param {object} metadata
 * @returns {string[]}
 */
function collectAliasFigureNames(figure, metadata) {
  const primary = figure.displayName?.trim() ?? '';
  const aliases = [];

  for (const alias of figure.aliases ?? []) {
    aliases.push(alias);
  }

  for (const alias of metadata.marketAliases ?? []) {
    aliases.push(alias);
  }

  const seen = new Set();
  const result = [];

  for (const alias of aliases) {
    const cleaned = alias.trim();
    if (!cleaned) {
      continue;
    }

    const key = cleaned.toLowerCase();
    if (seen.has(key) || key === primary.toLowerCase()) {
      continue;
    }

    seen.add(key);
    result.push(cleaned);
  }

  return result;
}

/**
 * @returns {{
 *   figures: object[],
 *   series: object[],
 *   brands: object[],
 *   ips: object[],
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

  return {
    figures,
    series,
    brands,
    ips,
    metadata,
    catalogToMetadata: buildCatalogToMetadataMap(
      metadata.figures,
      catalogFigureIds,
    ),
  };
}

/**
 * @param {ReturnType<typeof loadCatalogBundle>} bundle
 * @param {CliOptions} options
 * @returns {object[]}
 */
function selectFigures(bundle, options) {
  const seriesById = new Map(bundle.series.map((row) => [row.id, row]));
  const brandById = new Map(bundle.brands.map((row) => [row.id, row]));
  const ipById = new Map(bundle.ips.map((row) => [row.id, row]));

  let figures = [...bundle.figures];

  if (options.figureFilter) {
    figures = figures.filter((figure) => {
      const mapped = bundle.catalogToMetadata.get(figure.id);
      const metadataKey = mapped?.key?.toLowerCase() ?? '';
      return (
        figure.id.toLowerCase().includes(options.figureFilter) ||
        metadataKey.includes(options.figureFilter) ||
        figure.displayName.toLowerCase().includes(options.figureFilter)
      );
    });
  }

  if (options.seriesFilter) {
    figures = figures.filter((figure) => {
      const series = seriesById.get(figure.seriesId);
      if (!series) {
        return false;
      }

      const ip = ipById.get(series.ipId ?? figure.ipId);
      const seriesDistinctive = extractSeriesDistinctive(series, ip);

      return (
        figure.seriesId.toLowerCase().includes(options.seriesFilter) ||
        series.displayName.toLowerCase().includes(options.seriesFilter) ||
        seriesDistinctive.toLowerCase().includes(options.seriesFilter)
      );
    });
  }

  figures.sort((left, right) => {
    if (left.seriesId !== right.seriesId) {
      return left.seriesId.localeCompare(right.seriesId);
    }

    const leftOrder = left.sortOrder ?? 0;
    const rightOrder = right.sortOrder ?? 0;
    if (leftOrder !== rightOrder) {
      return leftOrder - rightOrder;
    }

    return left.displayName.localeCompare(right.displayName);
  });

  if (options.limit !== null) {
    figures = figures.slice(0, options.limit);
  }

  return figures.map((figure) => {
    const series = seriesById.get(figure.seriesId);
    const brand = brandById.get(figure.brandId);
    const ip = ipById.get(series?.ipId ?? figure.ipId);
    return { figure, series, brand, ip };
  });
}

/**
 * @param {object} params
 * @returns {object}
 */
function buildFigureReview({
  figure,
  series,
  brand,
  ip,
  catalogToMetadata,
}) {
  const mapped = catalogToMetadata.get(figure.id);
  const metadataKey = mapped?.key ?? null;
  const metadataEntry = mapped?.entry ?? {};
  const resolvedAliases = resolveReviewMetadataAliases(
    metadataKey,
    metadataEntry.marketAliases ?? [],
  );

  const metadata = {
    disabled: metadataEntry.disabled === true,
    searchTerms: metadataEntry.searchTerms ?? [],
    marketAliases: resolvedAliases.marketAliases,
    excludeTerms: metadataEntry.excludeTerms ?? [],
    matchThreshold: metadataEntry.matchThreshold ?? null,
    notes: metadataEntry.notes ?? '',
  };

  const catalogContext = { brand, ip, series };
  const terms = deriveSearchTerms(figure, catalogContext, metadata);
  const seriesDistinctive = extractSeriesDistinctive(series, ip);
  const ipToken = resolveIpToken(ip);
  const brandPrefixes = buildBrandPrefixes(brand);
  const aliasFigureNames = collectAliasFigureNames(figure, metadata);

  const warnings = [];
  const warningCounts = Object.fromEntries(
    WARNING_TYPES.map((type) => [type, 0]),
  );

  function addWarning(type, message) {
    warnings.push(message);
    warningCounts[type] += 1;
  }

  if (metadata.disabled) {
    return {
      figureId: metadataKey ?? figure.id,
      catalogFigureId: figure.id,
      displayName: figure.displayName,
      seriesLabel: seriesDistinctive,
      ipToken,
      terms,
      warnings,
      warningCounts,
      disabled: true,
      usesAliases: false,
      usesTier2: false,
      usesOverride: false,
      usedReviewDefaultAliases: false,
      aliasFigureNames,
    };
  }

  const usesOverride = (metadataEntry.searchTerms ?? []).length > 0;

  if (terms.length === 0) {
    addWarning('noTermsGenerated', 'No search terms generated');
  }

  if (terms.length === 1) {
    addWarning('onlyOneTerm', 'Figure generated only 1 search term');
  }

  const loweredTerms = terms.map((term) => term.toLowerCase());
  if (loweredTerms.length !== new Set(loweredTerms).size) {
    addWarning('duplicateTerms', 'Duplicate search terms detected');
  }

  for (const term of terms) {
    if (!isBrandedTerm(term, brandPrefixes)) {
      addWarning('tier2Brandless', 'Tier 2 brandless term generated');
    }

    if (term.length > 100) {
      addWarning('termTooLong', 'Search term exceeds 100 chars');
    }
  }

  if (!ipToken) {
    addWarning('noIpAlias', 'No IP token detected');
  }

  if (seriesDistinctive.length < 8) {
    addWarning(
      'shortSeriesDistinctive',
      'Series distinctive phrase is unusually short',
    );
  }

  for (const alias of metadata.marketAliases ?? []) {
    if (alias.trim().toLowerCase() === figure.displayName.trim().toLowerCase()) {
      addWarning(
        'aliasIdenticalToPrimary',
        'Alias term identical to primary term',
      );
    }
  }

  const usesTier2 =
    !usesOverride &&
    terms.some((term) => !isBrandedTerm(term, brandPrefixes));
  const usesAliases =
    !usesOverride &&
    aliasFigureNames.length > 0 &&
    terms.some((term) =>
      aliasFigureNames.some((alias) => term.includes(alias)),
    );

  return {
    figureId: metadataKey ?? figure.id,
    catalogFigureId: figure.id,
    displayName: figure.displayName,
    seriesLabel: seriesDistinctive,
    ipToken,
    terms,
    warnings: [...new Set(warnings)],
    warningCounts,
    disabled: false,
    usesAliases,
    usesTier2,
    usesOverride,
    usedReviewDefaultAliases: !usesOverride && resolvedAliases.usedReviewDefault,
    aliasFigureNames,
  };
}

/**
 * @param {ReturnType<typeof buildFigureReview>} review
 */
function printFigureReport(review) {
  console.log(SEPARATOR);
  console.log('FIGURE ID:');
  console.log(review.figureId);
  console.log('');
  console.log('DISPLAY NAME:');
  console.log(review.displayName);
  console.log('');
  console.log('SERIES:');
  console.log(review.seriesLabel);
  console.log('');
  console.log('IP:');
  console.log(review.ipToken || '(none)');
  console.log('');
  console.log('SEARCH TERMS:');

  if (review.terms.length === 0) {
    console.log('(none)');
  } else {
    review.terms.forEach((term, index) => {
      console.log(`${index + 1}. ${term}`);
    });
  }

  console.log('');
  console.log('TERM COUNT:');
  console.log(String(review.terms.length));

  if (review.usedReviewDefaultAliases) {
    console.log('');
    console.log('NOTE:');
    console.log('Using review-default marketAliases (metadata empty).');
  }

  if (review.usesOverride) {
    console.log('');
    console.log('NOTE:');
    console.log('Using explicit metadata searchTerms override.');
  }

  for (const warning of review.warnings) {
    console.log('');
    console.log('WARNING:');
    console.log(warning);
  }

  console.log(SEPARATOR);
}

/**
 * @param {ReturnType<typeof buildFigureReview>[]} reviews
 */
function printSummary(reviews) {
  console.log('');
  console.log('SUMMARY');
  console.log('');
  console.log(`Figures reviewed: ${reviews.length}`);
  console.log('');
  console.log('Term count distribution');
  console.log('');

  /** @type {Record<number, number>} */
  const distribution = {};
  for (const review of reviews) {
    const count = review.terms.length;
    distribution[count] = (distribution[count] ?? 0) + 1;
  }

  for (const count of Object.keys(distribution)
    .map(Number)
    .sort((left, right) => left - right)) {
    console.log(`${count} term${count === 1 ? '' : 's'}:`);
    console.log(distribution[count]);
    console.log('');
  }

  const aliasFigures = reviews.filter((review) => review.usesAliases);
  const disabledFigures = reviews.filter((review) => review.disabled);
  const tier2Figures = reviews.filter((review) => review.usesTier2);

  console.log(`Alias-generated figures: ${aliasFigures.length}`);
  console.log(`Disabled figures: ${disabledFigures.length}`);
  console.log('');

  console.log('Review Warnings');
  console.log('');

  /** @type {Record<string, number>} */
  const warningTotals = Object.fromEntries(
    WARNING_TYPES.map((type) => [type, 0]),
  );

  for (const review of reviews) {
    for (const [type, count] of Object.entries(review.warningCounts)) {
      warningTotals[type] += count;
    }
  }

  const warningMessages = {
    onlyOneTerm: 'Figure generated only 1 search term',
    tier2Brandless: 'Tier 2 brandless term generated',
    noIpAlias: 'No IP token detected',
    termTooLong: 'Search term exceeds 100 chars',
    aliasIdenticalToPrimary: 'Alias term identical to primary term',
    noTermsGenerated: 'No search terms generated',
    duplicateTerms: 'Duplicate search terms detected',
    shortSeriesDistinctive: 'Series distinctive phrase is unusually short',
  };

  let printedWarnings = false;
  for (const type of WARNING_TYPES) {
    if (warningTotals[type] === 0) {
      continue;
    }

    printedWarnings = true;
    console.log(`WARNING: ${warningMessages[type]}`);
    console.log(warningTotals[type]);
    console.log('');
  }

  if (!printedWarnings) {
    console.log('(none)');
    console.log('');
  }

  console.log('TOP FIGURES WITH MOST TERMS');
  console.log('');

  const byTermCount = [...reviews].sort((left, right) => {
    if (right.terms.length !== left.terms.length) {
      return right.terms.length - left.terms.length;
    }
    return left.figureId.localeCompare(right.figureId);
  });

  for (const review of byTermCount.slice(0, 15)) {
    console.log(`${review.figureId}: ${review.terms.length}`);
  }

  console.log('');
  console.log('FIGURES USING ALIASES');
  console.log('');

  if (aliasFigures.length === 0) {
    console.log('(none)');
  } else {
    for (const review of aliasFigures) {
      console.log(`${review.figureId} (${review.aliasFigureNames.join(', ')})`);
    }
  }

  console.log('');
  console.log('FIGURES GENERATING TIER 2 TERMS');
  console.log('');

  if (tier2Figures.length === 0) {
    console.log('(none)');
  } else {
    for (const review of tier2Figures) {
      console.log(review.figureId);
    }
  }
}

function main() {
  const options = parseCliOptions(process.argv);
  const bundle = loadCatalogBundle();
  const selected = selectFigures(bundle, options);

  if (selected.length === 0) {
    console.error('No figures matched the requested filters.');
    process.exit(1);
  }

  const reviewDefaultCount = bundle.figures.filter((figure) => {
    const mapped = bundle.catalogToMetadata.get(figure.id);
    const metadataAliases = mapped?.entry?.marketAliases ?? [];
    return (
      mapped?.key &&
      metadataAliases.length === 0 &&
      REVIEW_MARKET_ALIASES_BY_METADATA_KEY[mapped.key]
    );
  }).length;

  console.error(
    `debug_search_terms: reviewing ${selected.length} figure(s) from catalog seed`,
  );
  if (reviewDefaultCount > 0) {
    console.error(
      `debug_search_terms: ${reviewDefaultCount} metadata-linked figure(s) use review-default marketAliases when metadata is empty`,
    );
  }
  console.error('');

  const reviews = selected.map((entry) =>
    buildFigureReview({ ...entry, catalogToMetadata: bundle.catalogToMetadata }),
  );

  for (const review of reviews) {
    printFigureReport(review);
  }

  printSummary(reviews);
}

main();

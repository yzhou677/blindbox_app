/**
 * Market Intelligence — match fetched listings to a target catalog figure.
 *
 * Reuses title normalizer + catalog matcher without duplicating logic.
 */

import { buildMatcherContext, matchCatalogFigure } from './_catalog_matcher.mjs';
import {
  isExcludedTitle,
  normalizeMarketTitle,
} from './_title_normalizer.mjs';
import {
  buildCatalogContextForFigure,
  getMetadataRecord,
  normalizeMetadataEntry,
} from './_catalog_bundle.mjs';

/**
 * @typedef {import('./_snapshot_fetch.mjs').CompletedSaleListing} CompletedSaleListing
 */

/**
 * @typedef {CompletedSaleListing & {
 *   normalizedTitle: string,
 *   matchScore: number,
 * }} MatchedSaleListing
 */

/**
 * @typedef {Object} UnmatchedSaleListing
 * @property {CompletedSaleListing} listing
 * @property {string} [normalizedTitle]
 * @property {number} [matchScore]
 * @property {string} [rejectReason]
 * @property {'excluded' | 'noMatch'} reason
 */

/**
 * @typedef {Object} ListingMatchStats
 * @property {number} total
 * @property {number} matched
 * @property {number} unmatched
 * @property {number} excluded
 */

/**
 * @typedef {Object} ListingMatchResult
 * @property {MatchedSaleListing[]} matchedListings
 * @property {UnmatchedSaleListing[]} unmatchedListings
 * @property {number} matchRate
 * @property {ListingMatchStats} stats
 */

/**
 * Limits conflicting-series detection to the target IP universe.
 * Full-catalog phrases like generic "monsters" / "energy" cause false seriesMismatch.
 *
 * @param {import('./_catalog_bundle.mjs').ReturnType<typeof import('./_catalog_bundle.mjs').loadCatalogBundle>} catalogBundle
 * @param {string} targetSeriesId
 * @returns {object[]}
 */
export function resolveMatcherConflictSeries(catalogBundle, targetSeriesId) {
  const targetSeries = catalogBundle.seriesById.get(targetSeriesId);
  if (!targetSeries?.ipId) {
    return catalogBundle.series;
  }

  return catalogBundle.series.filter(
    (row) => row.id === targetSeriesId || row.ipId === targetSeries.ipId,
  );
}

/**
 * @param {object} figure
 * @param {import('./_catalog_bundle.mjs').ReturnType<typeof import('./_catalog_bundle.mjs').loadCatalogBundle>} catalogBundle
 * @returns {import('./_catalog_matcher.mjs').MatcherContext}
 */
export function buildMatcherContextForFigure(figure, catalogBundle) {
  const { brand, ip, series } = buildCatalogContextForFigure(figure, catalogBundle);

  if (!brand || !series) {
    throw new Error(`Missing catalog context for figure ${figure.id}`);
  }

  const siblingFigures = catalogBundle.figures.filter(
    (row) => row.seriesId === figure.seriesId && row.id !== figure.id,
  );

  return buildMatcherContext({
    targetFigure: figure,
    series,
    brand,
    ip,
    siblingFigures,
    allSeries: resolveMatcherConflictSeries(catalogBundle, figure.seriesId),
  });
}

/**
 * @param {readonly CompletedSaleListing[]} listings
 * @param {object} figure
 * @param {import('./_catalog_bundle.mjs').ReturnType<typeof import('./_catalog_bundle.mjs').loadCatalogBundle>} catalogBundle
 * @returns {ListingMatchResult}
 */
export function matchListingsToFigure(listings, figure, catalogBundle) {
  const context = buildMatcherContextForFigure(figure, catalogBundle);
  const { entry: metadataEntry } = getMetadataRecord(catalogBundle, figure.id);
  const metadata = normalizeMetadataEntry(metadataEntry);
  const metadataOverrides = {
    marketAliases: metadata.marketAliases,
    matchThreshold: metadata.matchThreshold,
  };

  /** @type {MatchedSaleListing[]} */
  const matchedListings = [];
  /** @type {UnmatchedSaleListing[]} */
  const unmatchedListings = [];
  let excludedCount = 0;

  for (const listing of listings) {
    if (
      isExcludedTitle(listing.title, {
        perFigureExcludes: metadata.excludeTerms,
      })
    ) {
      unmatchedListings.push({
        listing,
        reason: 'excluded',
      });
      excludedCount += 1;
      continue;
    }

    const normalizedTitle = normalizeMarketTitle(listing.title);
    const result = matchCatalogFigure(
      normalizedTitle,
      context,
      metadataOverrides,
    );

    if (result.matched && result.figureId === figure.id) {
      matchedListings.push({
        ...listing,
        normalizedTitle,
        matchScore: result.score,
      });
      continue;
    }

    unmatchedListings.push({
      listing,
      normalizedTitle,
      matchScore: result.score,
      rejectReason: result.rejectReason ?? undefined,
      reason: 'noMatch',
    });
  }

  const total = listings.length;

  return {
    matchedListings,
    unmatchedListings,
    matchRate: total > 0 ? matchedListings.length / total : 0,
    stats: {
      total,
      matched: matchedListings.length,
      unmatched: unmatchedListings.length,
      excluded: excludedCount,
    },
  };
}

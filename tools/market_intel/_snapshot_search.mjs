/**
 * Market Intelligence — snapshot search term resolution.
 *
 * Bridges catalog bundle + metadata overrides to deriveSearchTerms().
 */

import {
  buildCatalogContextForFigure,
  findFigureById,
  getMetadataRecord,
  normalizeMetadataEntry,
} from './_catalog_bundle.mjs';
import { deriveSearchTerms } from './_search_term_derivation.mjs';

export const SnapshotSkipReason = Object.freeze({
  DISABLED: 'DISABLED',
  NO_SEARCH_TERMS: 'NO_SEARCH_TERMS',
});

/**
 * @typedef {Object} FigureSearchPlan
 * @property {string} catalogFigureId
 * @property {string | null} metadataKey
 * @property {string} displayName
 * @property {string[]} searchTerms
 * @property {string | null} skipReason
 * @property {boolean} usesSearchTermsOverride
 * @property {{
 *   brand?: object,
 *   ip?: object,
 *   series?: object,
 * }} catalogContext
 */

/**
 * @param {object} figure
 * @param {ReturnType<import('./_catalog_bundle.mjs').loadCatalogBundle>} bundle
 * @returns {FigureSearchPlan | null}
 */
export function buildFigureSearchPlan(figure, bundle) {
  if (!figure) {
    return null;
  }

  const catalogContext = buildCatalogContextForFigure(figure, bundle);
  const { key: metadataKey, entry: metadataEntry } = getMetadataRecord(
    bundle,
    figure.id,
  );
  const metadata = normalizeMetadataEntry(metadataEntry);
  const usesSearchTermsOverride = metadata.searchTerms.length > 0;
  const searchTerms = deriveSearchTerms(figure, catalogContext, metadata);

  let skipReason = null;
  if (metadata.disabled) {
    skipReason = SnapshotSkipReason.DISABLED;
  } else if (searchTerms.length === 0) {
    skipReason = SnapshotSkipReason.NO_SEARCH_TERMS;
  }

  return {
    catalogFigureId: figure.id,
    metadataKey,
    displayName: figure.displayName,
    searchTerms,
    skipReason,
    usesSearchTermsOverride,
    catalogContext,
  };
}

/**
 * @param {ReturnType<import('./_catalog_bundle.mjs').loadCatalogBundle>} bundle
 * @param {string} catalogFigureId
 * @returns {FigureSearchPlan | null}
 */
export function buildFigureSearchPlanById(bundle, catalogFigureId) {
  const figure = findFigureById(bundle, catalogFigureId);
  return buildFigureSearchPlan(figure, bundle);
}

/**
 * @param {ReturnType<import('./_catalog_bundle.mjs').loadCatalogBundle>} bundle
 * @param {{
 *   brandId?: string,
 *   seriesFilter?: string,
 *   figureFilter?: string,
 *   limit?: number | null,
 * }} [options]
 * @returns {FigureSearchPlan[]}
 */
export function buildFigureSearchPlans(bundle, options = {}) {
  let figures = [...bundle.figures];

  if (options.brandId) {
    figures = figures.filter((figure) => figure.brandId === options.brandId);
  }

  if (options.figureFilter) {
    const needle = options.figureFilter.toLowerCase();
    figures = figures.filter((figure) => {
      const mapped = bundle.catalogToMetadata.get(figure.id);
      const metadataKey = mapped?.key?.toLowerCase() ?? '';
      return (
        figure.id.toLowerCase().includes(needle) ||
        metadataKey.includes(needle) ||
        figure.displayName.toLowerCase().includes(needle)
      );
    });
  }

  if (options.seriesFilter) {
    const needle = options.seriesFilter.toLowerCase();
    figures = figures.filter((figure) => {
      const series = bundle.seriesById.get(figure.seriesId);
      return (
        figure.seriesId.toLowerCase().includes(needle) ||
        series?.displayName?.toLowerCase().includes(needle)
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

  if (options.limit != null) {
    figures = figures.slice(0, options.limit);
  }

  return figures
    .map((figure) => buildFigureSearchPlan(figure, bundle))
    .filter(Boolean);
}

/**
 * @param {FigureSearchPlan[]} plans
 * @returns {{
 *   totalQueries: number,
 *   uniqueQueries: number,
 *   duplicateQueries: { query: string, figureIds: string[] }[],
 * }}
 */
export function analyzeQueryDuplication(plans) {
  /** @type {Map<string, string[]>} */
  const queryToFigures = new Map();

  for (const plan of plans) {
    if (plan.skipReason) {
      continue;
    }

    for (const query of plan.searchTerms) {
      const key = query.toLowerCase();
      const bucket = queryToFigures.get(key) ?? [];
      bucket.push(plan.catalogFigureId);
      queryToFigures.set(key, bucket);
    }
  }

  const duplicateQueries = [...queryToFigures.entries()]
    .filter(([, figureIds]) => figureIds.length > 1)
    .map(([query, figureIds]) => ({
      query,
      figureIds: [...new Set(figureIds)],
    }));

  const totalQueries = [...queryToFigures.values()].reduce(
    (sum, figureIds) => sum + figureIds.length,
    0,
  );

  return {
    totalQueries,
    uniqueQueries: queryToFigures.size,
    duplicateQueries,
  };
}

/**
 * Dry-run fetch steps for one figure plan (no network).
 *
 * @param {FigureSearchPlan} plan
 * @returns {object[]}
 */
export function buildDryRunFetchSteps(plan) {
  if (plan.skipReason) {
    return [
      {
        step: 'skip',
        catalogFigureId: plan.catalogFigureId,
        skipReason: plan.skipReason,
      },
    ];
  }

  return plan.searchTerms.map((query, index) => ({
    step: 'fetch_query',
    catalogFigureId: plan.catalogFigureId,
    metadataKey: plan.metadataKey,
    queryIndex: index + 1,
    query,
    pipeline: 'deriveSearchTerms → search query → snapshot fetch (pending)',
  }));
}

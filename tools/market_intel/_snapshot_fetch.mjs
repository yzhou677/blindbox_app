/**
 * Market Intelligence — in-memory completed sales fetch orchestration.
 *
 * search term → eBay request → raw listing response (memory only).
 */

import {
  EBAY_FETCH_DEFAULTS,
  fetchCompletedSalesForQuery,
} from './_ebay_completed_sales.mjs';

/**
 * @typedef {Object} CompletedSaleListing
 * @property {string} itemId
 * @property {string} title
 * @property {number | null} soldPriceUsd
 * @property {string | null} soldDate
 * @property {string | null} listingUrl
 * @property {string} [sourceQuery]
 */

/**
 * @typedef {Object} CompletedSalesQueryResult
 * @property {string} query
 * @property {boolean} ok
 * @property {CompletedSaleListing[]} listings
 * @property {number | null} total
 * @property {string | null} error
 * @property {number} retries
 * @property {boolean} rateLimited
 * @property {number} durationMs
 * @property {'finding_api' | 'fixture'} source
 */

/**
 * @typedef {Object} FigureCompletedSalesFetch
 * @property {import('./_snapshot_search.mjs').FigureSearchPlan} plan
 * @property {boolean} skipped
 * @property {string | null} skipReason
 * @property {CompletedSalesQueryResult[]} queryResults
 * @property {CompletedSaleListing[]} listings
 * @property {number} duplicateListingCount
 */

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

/**
 * @param {CompletedSaleListing[]} listings
 * @returns {CompletedSaleListing[]}
 */
export function dedupeListingsByItemId(listings) {
  const seen = new Set();
  const result = [];

  for (const listing of listings) {
    const key = listing.itemId.trim();
    if (!key || seen.has(key)) {
      continue;
    }

    seen.add(key);
    result.push(listing);
  }

  return result;
}

/**
 * @param {import('./_snapshot_search.mjs').FigureSearchPlan} plan
 * @param {{
 *   fetchMode?: 'live' | 'fixture',
 *   pageSize?: number,
 *   interQueryDelayMs?: number,
 *   maxRetries?: number,
 * }} [options]
 * @returns {Promise<FigureCompletedSalesFetch>}
 */
export async function fetchFigureCompletedSales(plan, options = {}) {
  if (plan.skipReason) {
    return {
      plan,
      skipped: true,
      skipReason: plan.skipReason,
      queryResults: [],
      listings: [],
      duplicateListingCount: 0,
    };
  }

  /** @type {CompletedSalesQueryResult[]} */
  const queryResults = [];
  /** @type {CompletedSaleListing[]} */
  const merged = [];

  for (let index = 0; index < plan.searchTerms.length; index += 1) {
    const query = plan.searchTerms[index];
    const result = await fetchCompletedSalesForQuery(query, {
      fetchMode: options.fetchMode,
      pageSize: options.pageSize ?? EBAY_FETCH_DEFAULTS.pageSize,
      maxRetries: options.maxRetries ?? EBAY_FETCH_DEFAULTS.maxRetries,
    });

    queryResults.push(result);

    for (const listing of result.listings) {
      merged.push({
        ...listing,
        sourceQuery: query,
      });
    }

    if (
      index < plan.searchTerms.length - 1 &&
      (options.interQueryDelayMs ?? EBAY_FETCH_DEFAULTS.interQueryDelayMs) > 0
    ) {
      await sleep(options.interQueryDelayMs ?? EBAY_FETCH_DEFAULTS.interQueryDelayMs);
    }
  }

  const listings = dedupeListingsByItemId(merged);

  return {
    plan,
    skipped: false,
    skipReason: null,
    queryResults,
    listings,
    duplicateListingCount: merged.length - listings.length,
  };
}

/**
 * @param {FigureCompletedSalesFetch[]} fetches
 * @returns {{
 *   totalQueries: number,
 *   successfulQueries: number,
 *   failedQueries: number,
 *   rateLimitedQueries: number,
 *   totalRetries: number,
 *   totalListings: number,
 *   averageListingsReturned: number,
 *   duplicateListingsAcrossQueries: number,
 * }}
 */
export function summarizeFetchResults(fetches) {
  let totalQueries = 0;
  let successfulQueries = 0;
  let failedQueries = 0;
  let rateLimitedQueries = 0;
  let totalRetries = 0;
  let totalListings = 0;
  let duplicateListingsAcrossQueries = 0;

  for (const fetchResult of fetches) {
    if (fetchResult.skipped) {
      continue;
    }

    duplicateListingsAcrossQueries += fetchResult.duplicateListingCount;

    for (const queryResult of fetchResult.queryResults) {
      totalQueries += 1;
      totalRetries += queryResult.retries;

      if (queryResult.ok) {
        successfulQueries += 1;
        totalListings += queryResult.listings.length;
      } else {
        failedQueries += 1;
      }

      if (queryResult.rateLimited) {
        rateLimitedQueries += 1;
      }
    }
  }

  return {
    totalQueries,
    successfulQueries,
    failedQueries,
    rateLimitedQueries,
    totalRetries,
    totalListings,
    averageListingsReturned:
      successfulQueries > 0 ? totalListings / successfulQueries : 0,
    duplicateListingsAcrossQueries,
  };
}

/**
 * @param {FigureCompletedSalesFetch} fetchResult
 * @param {{ sampleSize?: number }} [options]
 */
export function formatFigureFetchDebug(fetchResult, options = {}) {
  const sampleSize = options.sampleSize ?? 10;
  const lines = [];

  lines.push('==================================================');
  lines.push('CATALOG FIGURE ID:');
  lines.push(fetchResult.plan.catalogFigureId);
  lines.push('');
  lines.push('DISPLAY NAME:');
  lines.push(fetchResult.plan.displayName);
  lines.push('');

  if (fetchResult.skipped) {
    lines.push('FETCH STATUS:');
    lines.push(`SKIP (${fetchResult.skipReason})`);
    lines.push('==================================================');
    return lines.join('\n');
  }

  lines.push('COMPLETED SALES FETCH:');
  lines.push('');

  for (const queryResult of fetchResult.queryResults) {
    lines.push(`QUERY: ${queryResult.query}`);
    lines.push(`STATUS: ${queryResult.ok ? 'ok' : 'failed'}`);
    lines.push(`LISTING COUNT: ${queryResult.listings.length}`);
    if (queryResult.total != null) {
      lines.push(`REPORTED TOTAL: ${queryResult.total}`);
    }
    if (queryResult.error) {
      lines.push(`ERROR: ${queryResult.error}`);
    }
    if (queryResult.retries > 0) {
      lines.push(`RETRIES: ${queryResult.retries}`);
    }
    if (queryResult.rateLimited) {
      lines.push('RATE LIMITED: yes');
    }
    lines.push(`DURATION MS: ${queryResult.durationMs}`);
    lines.push('');
  }

  lines.push(`UNIQUE LISTINGS (deduped by itemId): ${fetchResult.listings.length}`);
  lines.push(`DUPLICATE LISTINGS ACROSS QUERIES: ${fetchResult.duplicateListingCount}`);
  lines.push('');
  lines.push(`FIRST ${Math.min(sampleSize, fetchResult.listings.length)} TITLES:`);

  const sample = fetchResult.listings.slice(0, sampleSize);
  if (sample.length === 0) {
    lines.push('(none)');
  } else {
    sample.forEach((listing, index) => {
      lines.push(`${index + 1}. ${listing.title}`);
      lines.push(`   sold: ${listing.soldDate ?? '(unknown)'}  price: $${listing.soldPriceUsd ?? '?'}`);
    });
  }

  lines.push('==================================================');
  return lines.join('\n');
}

/**
 * Market Intelligence — sold listing price aggregation (v1).
 *
 * Pure functions only — no weighting or outlier filtering.
 */

/**
 * @typedef {import('./_snapshot_fetch.mjs').CompletedSaleListing} CompletedSaleListing
 */

/**
 * @typedef {Object} SalesAggregation
 * @property {number} sampleSize
 * @property {number | null} minPrice
 * @property {number | null} maxPrice
 * @property {number | null} medianPrice
 * @property {number | null} averagePrice
 */

/**
 * @param {number[]} values
 * @returns {number | null}
 */
export function computeMedianPrice(values) {
  if (values.length === 0) {
    return null;
  }

  const sorted = [...values].sort((left, right) => left - right);
  const mid = Math.floor(sorted.length / 2);

  if (sorted.length % 2 === 1) {
    return sorted[mid];
  }

  return (sorted[mid - 1] + sorted[mid]) / 2;
}

/**
 * @param {number[]} values
 * @returns {number | null}
 */
export function computeAveragePrice(values) {
  if (values.length === 0) {
    return null;
  }

  const sum = values.reduce((total, value) => total + value, 0);
  return Math.round((sum / values.length) * 100) / 100;
}

/**
 * @param {readonly CompletedSaleListing[]} listings
 * @returns {SalesAggregation}
 */
export function aggregateSales(listings) {
  const prices = listings
    .map((listing) => listing.soldPriceUsd)
    .filter((price) => typeof price === 'number' && Number.isFinite(price));

  if (prices.length === 0) {
    return {
      sampleSize: 0,
      minPrice: null,
      maxPrice: null,
      medianPrice: null,
      averagePrice: null,
    };
  }

  return {
    sampleSize: prices.length,
    minPrice: Math.min(...prices),
    maxPrice: Math.max(...prices),
    medianPrice: computeMedianPrice(prices),
    averagePrice: computeAveragePrice(prices),
  };
}

import assert from 'node:assert/strict';
import { describe, test } from 'node:test';

import {
  aggregateSales,
  computeAveragePrice,
  computeMedianPrice,
} from './_sales_aggregator.mjs';

describe('computeMedianPrice', () => {
  test('returns null for empty input', () => {
    assert.equal(computeMedianPrice([]), null);
  });

  test('returns single value for one sale', () => {
    assert.equal(computeMedianPrice([42]), 42);
  });

  test('returns middle value for odd count', () => {
    assert.equal(computeMedianPrice([10, 30, 20]), 20);
  });

  test('returns average of middle pair for even count', () => {
    assert.equal(computeMedianPrice([10, 20, 30, 40]), 25);
  });
});

describe('computeAveragePrice', () => {
  test('returns null for empty input', () => {
    assert.equal(computeAveragePrice([]), null);
  });

  test('rounds to two decimals', () => {
    assert.equal(computeAveragePrice([10, 11]), 10.5);
    assert.equal(computeAveragePrice([10, 10, 11]), 10.33);
  });
});

describe('aggregateSales', () => {
  test('returns null metrics for empty input', () => {
    assert.deepEqual(aggregateSales([]), {
      sampleSize: 0,
      minPrice: null,
      maxPrice: null,
      medianPrice: null,
      averagePrice: null,
    });
  });

  test('ignores listings without valid sold price', () => {
    const result = aggregateSales([
      { itemId: '1', title: 'A', soldPriceUsd: 40, soldDate: null, listingUrl: null },
      { itemId: '2', title: 'B', soldPriceUsd: null, soldDate: null, listingUrl: null },
      { itemId: '3', title: 'C', soldPriceUsd: Number.NaN, soldDate: null, listingUrl: null },
    ]);

    assert.equal(result.sampleSize, 1);
    assert.equal(result.minPrice, 40);
    assert.equal(result.maxPrice, 40);
    assert.equal(result.medianPrice, 40);
    assert.equal(result.averagePrice, 40);
  });

  test('aggregates duplicate listing prices', () => {
    const listing = {
      itemId: '1',
      title: 'POP MART Labubu',
      soldPriceUsd: 38.5,
      soldDate: null,
      listingUrl: null,
    };

    const result = aggregateSales([listing, { ...listing, itemId: '2' }]);

    assert.equal(result.sampleSize, 2);
    assert.equal(result.medianPrice, 38.5);
    assert.equal(result.averagePrice, 38.5);
  });
});

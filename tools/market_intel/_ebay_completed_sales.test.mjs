import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { describe, test } from 'node:test';
import { fileURLToPath } from 'node:url';

import {
  buildFindCompletedItemsParams,
  parseFindCompletedItemsResponse,
  parseFindCompletedItemsTotal,
  parseSoldPriceUsd,
  setFetchImplementation,
} from './_ebay_completed_sales.mjs';
import {
  dedupeListingsByItemId,
  fetchFigureCompletedSales,
  summarizeFetchResults,
} from './_snapshot_fetch.mjs';
import { loadCatalogBundle } from './_catalog_bundle.mjs';
import { buildFigureSearchPlanById } from './_snapshot_search.mjs';

const __dirname = dirname(fileURLToPath(import.meta.url));
const fixturePath = join(__dirname, 'fixtures', 'finding_find_completed_items.sample.json');

describe('parseFindCompletedItemsResponse', () => {
  test('parses sold listings from Finding API sample payload', () => {
    const payload = JSON.parse(readFileSync(fixturePath, 'utf8'));
    const listings = parseFindCompletedItemsResponse(payload);

    assert.equal(listings.length, 2);
    assert.equal(listings[0].title, 'POP MART Labubu Have a Seat SISI Vinyl Plush');
    assert.equal(listings[0].soldPriceUsd, 38.5);
    assert.equal(listings[0].soldDate, '2025-05-01T18:22:00.000Z');
    assert.equal(parseFindCompletedItemsTotal(payload), 2);
  });

  test('parseSoldPriceUsd handles object and scalar nodes', () => {
    assert.equal(parseSoldPriceUsd([{ __value__: '12.50' }]), 12.5);
    assert.equal(parseSoldPriceUsd('9.99'), 9.99);
  });
});

describe('buildFindCompletedItemsParams', () => {
  test('includes sold-only filter and keywords', () => {
    const params = buildFindCompletedItemsParams('POP MART Labubu SISI');
    assert.equal(params.get('OPERATION-NAME'), 'findCompletedItems');
    assert.equal(params.get('keywords'), 'POP MART Labubu SISI');
    assert.equal(params.get('itemFilter(0).name'), 'SoldItemsOnly');
  });
});

describe('dedupeListingsByItemId', () => {
  test('removes duplicate item ids', () => {
    const deduped = dedupeListingsByItemId([
      { itemId: '1', title: 'A', soldPriceUsd: 1, soldDate: null, listingUrl: null },
      { itemId: '1', title: 'A duplicate', soldPriceUsd: 2, soldDate: null, listingUrl: null },
      { itemId: '2', title: 'B', soldPriceUsd: 3, soldDate: null, listingUrl: null },
    ]);

    assert.equal(deduped.length, 2);
  });
});

describe('fetchFigureCompletedSales — fixture mode', () => {
  const bundle = loadCatalogBundle();
  const FIGURE_SISI = 'the_monsters_have_a_seat_vinyl_plush_sisi';

  test('fetches fixture listings for SISI search terms', async () => {
    const plan = buildFigureSearchPlanById(bundle, FIGURE_SISI);
    const result = await fetchFigureCompletedSales(plan, { fetchMode: 'fixture' });

    assert.equal(result.skipped, false);
    assert.equal(result.queryResults.length, 2);
    assert.ok(result.listings.length >= 2);
    assert.equal(result.queryResults.every((row) => row.ok), true);
  });

  test('summarizeFetchResults aggregates query stats', async () => {
    const plan = buildFigureSearchPlanById(bundle, FIGURE_SISI);
    const result = await fetchFigureCompletedSales(plan, { fetchMode: 'fixture' });
    const summary = summarizeFetchResults([result]);

    assert.equal(summary.totalQueries, 2);
    assert.equal(summary.successfulQueries, 2);
    assert.equal(summary.failedQueries, 0);
    assert.ok(summary.averageListingsReturned > 0);
  });
});

describe('fetchCompletedSalesForQuery — retry behavior', () => {
  test('retries retryable HTTP failures', async () => {
    let attempts = 0;

    setFetchImplementation(async () => {
      attempts += 1;
      if (attempts < 3) {
        return {
          ok: false,
          status: 429,
          headers: { get: () => 'application/json' },
          text: async () =>
            JSON.stringify({
              errorMessage: [{ error: [{ message: 'rate limit' }] }],
            }),
        };
      }

      return {
        ok: true,
        status: 200,
        headers: { get: () => 'application/json' },
        text: async () => readFileSync(fixturePath, 'utf8'),
      };
    });

    const { fetchCompletedSalesForQuery } = await import('./_ebay_completed_sales.mjs');
    const result = await fetchCompletedSalesForQuery('POP MART Labubu SISI', {
      fetchMode: 'live',
      clientId: 'test-client-id',
      maxRetries: 3,
      retryBaseMs: 1,
    });

    assert.equal(result.ok, true);
    assert.equal(result.retries, 2);
    assert.equal(result.rateLimited, true);
    assert.equal(result.listings.length, 2);

    setFetchImplementation(fetch);
  });
});

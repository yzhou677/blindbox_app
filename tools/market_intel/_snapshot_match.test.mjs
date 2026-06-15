import assert from 'node:assert/strict';
import { describe, test } from 'node:test';

import {
  findFigureById,
  loadCatalogBundle,
} from './_catalog_bundle.mjs';
import { matchListingsToFigure } from './_snapshot_match.mjs';

const FIGURE_LUCK = 'the_monsters_big_into_energy_vinyl_plush_pendant_luck';
const FIGURE_SISI = 'the_monsters_have_a_seat_vinyl_plush_sisi';

const LUCK_ACCEPTED_TITLE =
  'POP MART THE MONSTERS Luck Big Into Energy Vinyl Plush';

/**
 * @param {Partial<import('./_snapshot_fetch.mjs').CompletedSaleListing>} overrides
 * @returns {import('./_snapshot_fetch.mjs').CompletedSaleListing}
 */
function listing(overrides) {
  return {
    itemId: 'item-1',
    title: 'listing',
    soldPriceUsd: 40,
    soldDate: null,
    listingUrl: null,
    ...overrides,
  };
}

describe('matchListingsToFigure', () => {
  const bundle = loadCatalogBundle();

  test('returns empty result for no listings', () => {
    const figure = findFigureById(bundle, FIGURE_LUCK);
    const result = matchListingsToFigure([], figure, bundle);

    assert.deepEqual(result.matchedListings, []);
    assert.deepEqual(result.unmatchedListings, []);
    assert.equal(result.matchRate, 0);
    assert.deepEqual(result.stats, {
      total: 0,
      matched: 0,
      unmatched: 0,
      excluded: 0,
    });
  });

  test('accepts canonical Luck marketplace title', () => {
    const figure = findFigureById(bundle, FIGURE_LUCK);
    const result = matchListingsToFigure(
      [
        listing({
          itemId: 'luck-1',
          title: LUCK_ACCEPTED_TITLE,
          soldPriceUsd: 38.5,
        }),
      ],
      figure,
      bundle,
    );

    assert.equal(result.matchedListings.length, 1);
    assert.equal(result.unmatchedListings.length, 0);
    assert.equal(result.matchRate, 1);
    assert.equal(result.matchedListings[0].matchScore >= 0.75, true);
  });

  test('excludes keychain accessory listing via normalizer', () => {
    const figure = findFigureById(bundle, FIGURE_SISI);
    const result = matchListingsToFigure(
      [
        listing({
          itemId: 'sisi-keychain',
          title: 'POPMART Have a Seat SISI Plush Keychain',
          soldPriceUsd: 41,
        }),
      ],
      figure,
      bundle,
    );

    assert.equal(result.matchedListings.length, 0);
    assert.equal(result.unmatchedListings.length, 1);
    assert.equal(result.unmatchedListings[0].reason, 'excluded');
    assert.equal(result.stats.excluded, 1);
  });

  test('counts matched and unmatched listings separately', () => {
    const figure = findFigureById(bundle, FIGURE_LUCK);
    const wrongTitle =
      'POP MART THE MONSTERS Big Into Energy Hope Vinyl Plush Figure';

    const result = matchListingsToFigure(
      [
        listing({ itemId: '1', title: LUCK_ACCEPTED_TITLE, soldPriceUsd: 30 }),
        listing({ itemId: '2', title: LUCK_ACCEPTED_TITLE, soldPriceUsd: 32 }),
        listing({ itemId: '3', title: wrongTitle, soldPriceUsd: 28 }),
      ],
      figure,
      bundle,
    );

    assert.equal(result.stats.total, 3);
    assert.equal(result.stats.matched, 2);
    assert.equal(result.stats.unmatched, 1);
    assert.ok(Math.abs(result.matchRate - 2 / 3) < 0.0001);
  });

  test('rejects unmatched Hope title when matching Luck', () => {
    const figure = findFigureById(bundle, FIGURE_LUCK);
    const result = matchListingsToFigure(
      [
        listing({
          itemId: 'hope-1',
          title:
            'POP MART THE MONSTERS Big Into Energy Hope Vinyl Plush Figure',
          soldPriceUsd: 35,
        }),
      ],
      figure,
      bundle,
    );

    assert.equal(result.matchedListings.length, 0);
    assert.equal(result.unmatchedListings[0].reason, 'noMatch');
  });
});

'use strict';

const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const { composeBrowseAspectPlan } = require('../lib/providers/gateway/composeBrowseAspectFilter');
const {
  listingTitleMatchesTaxonomy,
  filterRawItemsByTaxonomy,
} = require('../lib/providers/gateway/titleTaxonomyFilter');
const {
  shouldRunTier2Supplement,
  composeTier2KeywordQ,
} = require('../lib/providers/gateway/composeBrowseTier2');

describe('DPL / Baby Three eBay aspects', () => {
  it('maps DPL brand to Cureplaneta aspect', () => {
    const plan = composeBrowseAspectPlan({
      brandId: 'dpl',
      ipId: 'baby_three',
    });
    assert.match(plan.aspectFilter ?? '', /Brand:\{Cureplaneta\}/);
    assert.match(plan.aspectFilter ?? '', /Character:\{.*BABY THREE.*\}/i);
  });
});

describe('titleTaxonomyFilter', () => {
  it('keeps Baby Three titles without Cureplaneta in title', () => {
    assert.equal(
      listingTitleMatchesTaxonomy(
        'POP MART Baby Three Fairytale Plush Blind Box',
        { brandId: 'dpl', ipId: 'baby_three' },
      ),
      true,
    );
  });

  it('drops unrelated IP titles when ipId is set', () => {
    assert.equal(
      listingTitleMatchesTaxonomy('POP MART Labubu Vinyl Figure', {
        brandId: 'pop_mart',
        ipId: 'the_monsters',
      }),
      true,
    );
    assert.equal(
      listingTitleMatchesTaxonomy('POP MART Skullpanda Series', {
        brandId: 'pop_mart',
        ipId: 'the_monsters',
      }),
      false,
    );
  });

  it('filterRawItemsByTaxonomy drops mismatched rows', () => {
    const rows = filterRawItemsByTaxonomy(
      [
        { itemId: '1', title: 'POP MART Labubu Figure' },
        { itemId: '2', title: 'POP MART Skullpanda' },
      ],
      { brandId: 'pop_mart', ipId: 'the_monsters' },
    );
    assert.equal(rows.length, 1);
    assert.equal(rows[0].itemId, '1');
  });
});

describe('composeBrowseTier2', () => {
  it('runs when strict aspect rows are sparse', () => {
    assert.equal(
      shouldRunTier2Supplement(
        { brandId: 'pop_mart', ipId: 'the_monsters', aspectFilter: 'categoryId:1,Brand:{X}' },
        2,
      ),
      true,
    );
    assert.equal(
      shouldRunTier2Supplement(
        { brandId: 'pop_mart', aspectFilter: 'categoryId:1,Brand:{X}' },
        8,
      ),
      false,
    );
  });

  it('keyword q uses IP term only when facets active', () => {
    assert.equal(
      composeTier2KeywordQ({
        brandId: 'dpl',
        ipId: 'baby_three',
        searchText: 'plush',
      }),
      'BABY THREE plush',
    );
  });
});

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
  composeTier2AspectFilter,
} = require('../lib/providers/gateway/composeBrowseTier2');

describe('DPL / Baby Three (q-first, no aspect)', () => {
  it('does not apply Brand or Character aspect for Baby Three', () => {
    const plan = composeBrowseAspectPlan({
      brandId: 'dpl',
      ipId: 'baby_three',
    });
    assert.equal(plan.active, false);
    assert.equal(plan.aspectFilter, undefined);
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

  it('catalog POP MART collab IPs match seller-native title phrases', () => {
    assert.equal(
      listingTitleMatchesTaxonomy(
        'POP MART aespa Fluffy Club Series Vinyl Plush Doll Pendant Blind Box',
        { brandId: 'pop_mart', ipId: 'aespa' },
      ),
      true,
    );
    assert.equal(
      listingTitleMatchesTaxonomy(
        'Pop Mart Twinkle Twinkle MOON GELATO Series Plush Pendant Blind Box',
        { brandId: 'pop_mart', ipId: 'twinkle_twinkle' },
      ),
      true,
    );
    assert.equal(
      listingTitleMatchesTaxonomy(
        'POP MART SpongeBob Bikini Bottom Buddies Whimsical Plush Series 2 Blind Box',
        { brandId: 'pop_mart', ipId: 'bikini_bottom_buddies' },
      ),
      true,
    );
    assert.equal(
      listingTitleMatchesTaxonomy(
        'POP MART 100% Mega Space Molly Series 4 Blind Box',
        { brandId: 'pop_mart', ipId: 'space_molly' },
      ),
      true,
    );
  });

  it('Polar title tier rejects bare polar bear noise', () => {
    assert.equal(
      listingTitleMatchesTaxonomy(
        'POP MART Dimoo AQUARIUM SERIES Blind Box POLAR BEAR Vinyl Figure',
        { brandId: 'pop_mart', ipId: 'polar' },
      ),
      false,
    );
    assert.equal(
      listingTitleMatchesTaxonomy(
        'Pop Mart Polar Monster Village Villio Figure Authentic',
        { brandId: 'pop_mart', ipId: 'polar' },
      ),
      true,
    );
  });
});

describe('composeBrowseTier2', () => {
  it('runs when verified Character aspect rows are sparse', () => {
    assert.equal(
      shouldRunTier2Supplement(
        {
          brandId: 'pop_mart',
          ipId: 'the_monsters',
          aspectFilter: 'categoryId:261068,Character:{Labubu}',
        },
        2,
      ),
      true,
    );
    assert.equal(
      shouldRunTier2Supplement(
        { brandId: 'pop_mart', aspectFilter: 'categoryId:261068,Character:{Labubu}' },
        8,
      ),
      false,
    );
  });

  it('Tier 2 keyword q uses brand + non-verified IP terms (no Brand aspect)', () => {
    assert.equal(
      composeTier2KeywordQ({
        brandId: 'dpl',
        ipId: 'baby_three',
        searchText: 'plush',
      }),
      'cureplaneta BABY THREE plush',
    );
    assert.equal(composeTier2AspectFilter({ brandId: 'pop_mart' }), undefined);
  });
});

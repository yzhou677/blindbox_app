'use strict';



const { describe, it } = require('node:test');

const assert = require('node:assert/strict');

const {

  composeBrowseUpstreamQ,

  CANONICAL_EBAY_BROWSE_CATEGORY_ID,

} = require('../lib/providers/gateway/composeBrowseQuery');

const {

  composeBrowseAspectPlan,

  resolveBrowseCategoryId,

} = require('../lib/providers/gateway/composeBrowseAspectFilter');



describe('composeBrowseUpstreamQ (q-first retrieval)', () => {

  it('uses brand q + omits IP keyword when Character facet is verified', () => {

    assert.equal(

      composeBrowseUpstreamQ({

        brandId: 'pop_mart',

        ipId: 'the_monsters',

      }),

      'pop mart',

    );

  });



  it('supplements verified Character q when ebayPreferredQuery is set', () => {

    assert.equal(

      composeBrowseUpstreamQ({

        brandId: 'pop_mart',

        ipId: 'crybaby',

      }),

      'pop mart Crybaby',

    );

  });



  it('includes IP keyword for non-verified IPs', () => {

    assert.equal(

      composeBrowseUpstreamQ({

        brandId: 'pop_mart',

        ipId: 'dimoo',

      }),

      'pop mart Dimoo',

    );

  });



  it('uses studio line q for Dreams Inc Sonny Angel (no Brand aspect)', () => {

    assert.equal(

      composeBrowseUpstreamQ({

        brandId: 'dreams_inc',

        ipId: 'sonny_angel',

      }),

      'SONNY ANGEL',

    );

  });



  it('uses DPL + Baby Three q for non-verified IP', () => {

    assert.equal(

      composeBrowseUpstreamQ({

        brandId: 'dpl',

        ipId: 'baby_three',

        searchText: 'plush',

      }),

      'cureplaneta BABY THREE plush',

    );

  });



  it('keeps user search text with brand q', () => {

    assert.equal(

      composeBrowseUpstreamQ({

        brandId: 'pop_mart',

        ipId: 'the_monsters',

        searchText: 'macaron',

      }),

      'pop mart macaron',

    );

  });

});



describe('composeBrowseAspectPlan (verified Character only)', () => {

  it('uses canonical category 261068', () => {

    assert.equal(resolveBrowseCategoryId(), CANONICAL_EBAY_BROWSE_CATEGORY_ID);

    assert.equal(CANONICAL_EBAY_BROWSE_CATEGORY_ID, '261068');

  });



  it('uses discover browse for Any brand + Any IP (no aspect)', () => {

    const plan = composeBrowseAspectPlan({

      brandId: 'any_brand',

      ipId: 'any_ip',

    });

    assert.equal(plan.active, false);

    assert.equal(plan.categoryIds, '261068');

    assert.equal(plan.aspectFilter, undefined);

  });



  it('applies verified Character facet for Labubu (no Brand aspect)', () => {

    const plan = composeBrowseAspectPlan({

      brandId: 'pop_mart',

      ipId: 'the_monsters',

    });

    assert.equal(plan.active, true);

    assert.match(plan.aspectFilter ?? '', /Character:\{Labubu\}/);

    assert.doesNotMatch(plan.aspectFilter ?? '', /Brand:/);

  });



  it('does not apply aspect for non-verified Dimoo', () => {

    const plan = composeBrowseAspectPlan({

      brandId: 'pop_mart',

      ipId: 'dimoo',

    });

    assert.equal(plan.active, false);

    assert.equal(plan.aspectFilter, undefined);

  });



  it('does not apply Brand aspect for Dreams Inc', () => {

    const plan = composeBrowseAspectPlan({

      brandId: 'dreams_inc',

      ipId: 'sonny_angel',

    });

    assert.equal(plan.active, false);

    assert.equal(plan.aspectFilter, undefined);

  });



  it('does not apply Character aspect for non-verified Baby Three', () => {

    const plan = composeBrowseAspectPlan({

      brandId: 'dpl',

      ipId: 'baby_three',

    });

    assert.equal(plan.active, false);

  });

});


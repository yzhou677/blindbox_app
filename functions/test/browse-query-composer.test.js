'use strict';

const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const {
  composeBrowseUpstreamQ,
  browseQuerySignature,
} = require('../lib/providers/gateway/composeBrowseQuery');

describe('composeBrowseUpstreamQ', () => {
  it('uses aspect facets for brand/IP (q is empty without search text)', () => {
    assert.equal(
      composeBrowseUpstreamQ({
        brandId: 'pop_mart',
        ipId: 'the_monsters',
      }),
      '',
    );
  });

  it('passes search text when facets are active', () => {
    assert.equal(
      composeBrowseUpstreamQ({
        brandId: 'pop_mart',
        ipId: 'the_monsters',
        searchText: 'macaron',
      }),
      'macaron',
    );
  });

  it('uses empty q for Any brand + Any IP (curated brand OR facets)', () => {
    assert.equal(composeBrowseUpstreamQ({}), '');
  });
});

describe('browseQuerySignature', () => {
  it('is stable for identical facets', () => {
    const a = browseQuerySignature({
      brandId: 'pop_mart',
      ipId: 'the_monsters',
      searchText: 'macaron',
    });
    const b = browseQuerySignature({
      brandId: 'pop_mart',
      ipId: 'the_monsters',
      searchText: 'macaron',
    });
    assert.equal(a, b);
  });
});

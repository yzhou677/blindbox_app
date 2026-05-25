'use strict';

const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const {
  composeBrowseUpstreamQ,
  browseQuerySignature,
  DISCOVER_BROWSE_Q,
} = require('../lib/providers/gateway/composeBrowseQuery');

describe('composeBrowseUpstreamQ', () => {
  it('uses brand q for verified Character IP (Labubu)', () => {
    assert.equal(
      composeBrowseUpstreamQ({
        brandId: 'pop_mart',
        ipId: 'the_monsters',
      }),
      'pop mart',
    );
  });

  it('appends user search text to brand q', () => {
    assert.equal(
      composeBrowseUpstreamQ({
        brandId: 'pop_mart',
        ipId: 'the_monsters',
        searchText: 'macaron',
      }),
      'pop mart macaron',
    );
  });

  it('uses discover keywords for Any brand + Any IP', () => {
    assert.equal(composeBrowseUpstreamQ({}), DISCOVER_BROWSE_Q);
    assert.equal(DISCOVER_BROWSE_Q, 'blind box vinyl figure');
  });

  it('uses Dreams Inc preferred query for brand + Any IP', () => {
    assert.equal(
      composeBrowseUpstreamQ({ brandId: 'dreams_inc', ipId: 'any_ip' }),
      'sonny angel blind box',
    );
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

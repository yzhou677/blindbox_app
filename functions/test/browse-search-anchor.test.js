'use strict';

const { describe, it, beforeEach } = require('node:test');
const assert = require('node:assert/strict');
const {
  composeBrowseUpstreamQ,
  DISCOVER_BROWSE_Q,
  shouldAnchorDiscoverSearch,
  isCollectibleNativeSearch,
  resolveSearchTextForBrowse,
  resetSearchAnchorCacheForTests,
} = require('../lib/providers/gateway/composeBrowseQuery');

describe('discover search anchoring', () => {
  beforeEach(() => {
    resetSearchAnchorCacheForTests();
  });

  it('anchors generic discover search terms', () => {
    for (const term of ['baby', 'cat', 'angel', 'panda', 'doll']) {
      assert.equal(
        shouldAnchorDiscoverSearch(term, 'any_brand', 'any_ip'),
        true,
        term,
      );
      assert.equal(
        composeBrowseUpstreamQ({ searchText: term }),
        `${DISCOVER_BROWSE_Q} ${term}`,
        term,
      );
    }
  });

  it('does not anchor taxonomy-native IP and brand queries', () => {
    for (const term of [
      'labubu',
      'hirono',
      'skullpanda',
      'smiski',
      'sonny angel',
      'baby three',
      'pop mart',
      'rolife nanci',
      'tnt space',
    ]) {
      assert.equal(
        shouldAnchorDiscoverSearch(term, 'any_brand', 'any_ip'),
        false,
        term,
      );
      assert.equal(composeBrowseUpstreamQ({ searchText: term }), term, term);
    }
  });

  it('does not anchor when search already includes collectible context', () => {
    assert.equal(
      composeBrowseUpstreamQ({ searchText: 'blind box disney' }),
      'blind box disney',
    );
  });

  it('does not anchor when brand or IP chips provide context', () => {
    assert.equal(
      shouldAnchorDiscoverSearch('baby', 'pop_mart', 'any_ip'),
      false,
    );
    assert.equal(
      composeBrowseUpstreamQ({
        brandId: 'pop_mart',
        ipId: 'any_ip',
        searchText: 'baby',
      }),
      'pop mart baby',
    );
  });

  it('resolveSearchTextForBrowse is a no-op for empty input', () => {
    assert.equal(
      resolveSearchTextForBrowse({ searchText: '  ', brandId: 'any_brand' }),
      '',
    );
  });

  it('isCollectibleNativeSearch recognizes IP aliases', () => {
    assert.equal(isCollectibleNativeSearch('LABUBU chase'), true);
    assert.equal(isCollectibleNativeSearch('angel'), false);
  });
});

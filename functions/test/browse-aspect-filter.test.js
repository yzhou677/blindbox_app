'use strict';

const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const {
  composeBrowseUpstreamQ,
} = require('../lib/providers/gateway/composeBrowseQuery');
const {
  composeBrowseAspectPlan,
  composeBrowseFranchiseAspectPlan,
} = require('../lib/providers/gateway/composeBrowseAspectFilter');

describe('composeBrowseUpstreamQ with aspect facets', () => {
  it('does not repeat brand/IP in q when facets are active', () => {
    assert.equal(
      composeBrowseUpstreamQ({
        brandId: 'pop_mart',
        ipId: 'the_monsters',
      }),
      '',
    );
  });

  it('keeps user search text when facets are active', () => {
    assert.equal(
      composeBrowseUpstreamQ({
        brandId: 'pop_mart',
        ipId: 'the_monsters',
        searchText: 'macaron',
      }),
      'macaron',
    );
  });
});

describe('composeBrowseAspectPlan', () => {
  it('ORs all curated eBay brands for Any brand + Any IP', () => {
    const plan = composeBrowseAspectPlan({
      brandId: 'any_brand',
      ipId: 'any_ip',
    });
    assert.equal(plan.active, true);
    const filter = plan.aspectFilter ?? '';
    assert.match(filter, /Brand:\{/);
    assert.match(filter, /POP MART/);
    assert.match(filter, /Sonny Angel/);
    assert.match(filter, /Smiski/);
    assert.match(filter, /Cureplaneta/);
    assert.match(filter, /TOPTOY/);
    assert.doesNotMatch(filter, /Finding Unicorn/i);
    assert.doesNotMatch(filter, /Character:/);
  });

  it('maps POP MART brand + Labubu character aspects', () => {
    const plan = composeBrowseAspectPlan({
      brandId: 'pop_mart',
      ipId: 'the_monsters',
    });
    assert.equal(plan.active, true);
    assert.match(plan.aspectFilter ?? '', /Brand:\{POP MART\}/);
    assert.match(plan.aspectFilter ?? '', /Character:\{.*LABUBU.*\}/i);
  });

  it('builds franchise fallback for line-level IPs', () => {
    const plan = composeBrowseFranchiseAspectPlan({
      brandId: 'pop_mart',
      ipId: 'the_monsters',
    });
    assert.ok(plan);
    assert.match(plan.aspectFilter ?? '', /Franchise:\{THE MONSTERS\}/);
  });

  it('maps Dreams Inc. Any IP to Sonny Angel | Smiski brand aspects', () => {
    const plan = composeBrowseAspectPlan({
      brandId: 'dreams_inc',
      ipId: 'any_ip',
    });
    assert.match(plan.aspectFilter ?? '', /Brand:\{Sonny Angel\|Smiski\}/);
    assert.doesNotMatch(plan.aspectFilter ?? '', /Character:/);
  });

  it('maps Sonny Angel IP to eBay brand aspect only', () => {
    const plan = composeBrowseAspectPlan({
      brandId: 'dreams_inc',
      ipId: 'sonny_angel',
    });
    assert.match(plan.aspectFilter ?? '', /Brand:\{Sonny Angel\}/);
    assert.doesNotMatch(plan.aspectFilter ?? '', /Character:/);
  });
});

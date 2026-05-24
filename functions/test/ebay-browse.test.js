'use strict';

const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const { browseEbay } = require('../lib/providers/ebay/ebayBrowse');
const {
  resolveMarketGatewayProvider,
} = require('../lib/marketBrowseRouter');
const { ebayCredentialsConfigured } = require('../lib/providers/ebay/ebayOAuth');

describe('resolveMarketGatewayProvider', () => {
  it('defaults to ebay', () => {
    const prev = process.env.MARKET_GATEWAY_PROVIDER;
    delete process.env.MARKET_GATEWAY_PROVIDER;
    assert.equal(resolveMarketGatewayProvider(), 'ebay');
    if (prev) process.env.MARKET_GATEWAY_PROVIDER = prev;
  });
});

describe('browseEbay fixture mode', () => {
  it('returns empty rows (fixture data disabled for UX)', async () => {
    const prevMode = process.env.MARKET_GATEWAY_MODE;
    const prevId = process.env.EBAY_CLIENT_ID;
    process.env.MARKET_GATEWAY_MODE = 'fixture';
    delete process.env.EBAY_CLIENT_ID;

    const payload = await browseEbay({ q: 'pop mart', limit: 2, cursor: undefined, signature: 'x' });
    assert.equal(payload.meta?.provider, 'ebay');
    assert.equal(payload.meta?.mode, 'fixture');
    assert.equal(payload.items.length, 0);

    if (prevMode) process.env.MARKET_GATEWAY_MODE = prevMode;
    if (prevId) process.env.EBAY_CLIENT_ID = prevId;
  });
});

describe('ebayCredentialsConfigured', () => {
  it('is false when env vars missing', () => {
    const id = process.env.EBAY_CLIENT_ID;
    const secret = process.env.EBAY_CLIENT_SECRET;
    delete process.env.EBAY_CLIENT_ID;
    delete process.env.EBAY_CLIENT_SECRET;
    assert.equal(ebayCredentialsConfigured(), false);
    if (id) process.env.EBAY_CLIENT_ID = id;
    if (secret) process.env.EBAY_CLIENT_SECRET = secret;
  });
});

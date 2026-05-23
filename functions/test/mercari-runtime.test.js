'use strict';

const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const {
  createMercariRuntime,
  resolveAcquisitionStrategyId,
} = require('../lib/providers/mercari/runtime/createMercariRuntime');
const { FetchMercariRuntime } = require('../lib/providers/mercari/runtime/fetchMercariRuntime');
const { PlaywrightMercariRuntime } = require('../lib/providers/mercari/runtime/playwrightMercariRuntime');

describe('createMercariRuntime', () => {
  it('defaults to fetch runtime', () => {
    const prev = process.env.MERCARI_ACQUISITION_RUNTIME;
    delete process.env.MERCARI_ACQUISITION_RUNTIME;
    assert.equal(resolveAcquisitionStrategyId(), 'fetch');
    assert.ok(createMercariRuntime() instanceof FetchMercariRuntime);
    if (prev) process.env.MERCARI_ACQUISITION_RUNTIME = prev;
  });

  it('selects playwright stub when configured', () => {
    const prev = process.env.MERCARI_ACQUISITION_RUNTIME;
    process.env.MERCARI_ACQUISITION_RUNTIME = 'playwright';
    assert.equal(resolveAcquisitionStrategyId(), 'playwright');
    assert.ok(createMercariRuntime() instanceof PlaywrightMercariRuntime);
    if (prev) process.env.MERCARI_ACQUISITION_RUNTIME = prev;
    else delete process.env.MERCARI_ACQUISITION_RUNTIME;
  });
});

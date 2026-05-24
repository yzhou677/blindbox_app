'use strict';

const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const {
  classifyUpstreamError,
  shouldUseFixtureFallback,
  buildBrowseMeta,
} = require('../lib/providers/gateway/gatewayDiagnostics');
const { HttpError } = require('../lib/shared/http/fetchJson');
const { normalizeBrowseItems } = require('../lib/providers/gateway/normalizeBrowseItems');

describe('shouldUseFixtureFallback', () => {
  it('is disabled — live UX must not inject fixture rows', () => {
    assert.equal(
      shouldUseFixtureFallback({
        fetchFailed: true,
        rawRowCount: 0,
        normalizedCount: 0,
      }),
      false,
    );
    assert.equal(
      shouldUseFixtureFallback({
        fetchFailed: false,
        rawRowCount: 0,
        normalizedCount: 0,
        facetsActive: true,
      }),
      false,
    );
  });
});

describe('classifyUpstreamError', () => {
  it('tags 403 as blocked', () => {
    const d = classifyUpstreamError(new HttpError('forbidden', 403));
    assert.equal(d.upstreamBlocked, true);
  });

  it('tags 429 as rate limited', () => {
    const d = classifyUpstreamError(new HttpError('rate', 429));
    assert.equal(d.rateLimited, true);
  });

  it('tags timeout status', () => {
    const d = classifyUpstreamError(new HttpError('timeout', 408));
    assert.equal(d.timedOut, true);
  });
});

describe('normalizeBrowseItems', () => {
  it('drops malformed and duplicate rows quietly', () => {
    const result = normalizeBrowseItems([
      { id: 'a', title: 'One', price: { value: '1', currency: 'USD' } },
      { id: 'a', title: 'Dup', price: { value: '2', currency: 'USD' } },
      { title: 'no id' },
    ]);
    assert.equal(result.items.length, 1);
    assert.equal(result.stats.duplicateDropped, 1);
    assert.equal(result.stats.malformedDropped, 1);
  });
});

describe('buildBrowseMeta', () => {
  it('marks live fixture fallback as degraded', () => {
    const meta = buildBrowseMeta(
      { mode: 'live', query: 'pop', limit: 24 },
      { usedFixtureFallback: true, normalizedCount: 4 },
    );
    assert.equal(meta.upstreamDegraded, true);
    assert.equal(meta.diagnostics?.usedFixtureFallback, true);
  });
});

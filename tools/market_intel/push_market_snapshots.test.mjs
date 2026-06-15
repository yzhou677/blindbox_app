import assert from 'node:assert/strict';
import { describe, test } from 'node:test';

import { buildFirestoreDocument } from './push_market_snapshots.mjs';

/** @param {Partial<import('./_snapshot_document.mjs').SnapshotDocument>} overrides */
function makeSnapshot(overrides = {}) {
  return {
    figureId: 'the_monsters_big_into_energy_vinyl_plush_pendant_luck',
    seriesId: 'the_monsters_big_into_energy_vinyl_plush_pendant',
    snapshotAt: '2026-06-15T03:00:00.000Z',
    sampleSize: 18,
    averagePrice: 43.5,
    medianPrice: 42.0,
    minPrice: 35.0,
    maxPrice: 55.0,
    confidence: 'high',
    dataSource: 'fixture',
    ...overrides,
  };
}

describe('buildFirestoreDocument — field mapping', () => {
  test('maps all core fields correctly', () => {
    const result = buildFirestoreDocument(makeSnapshot());

    assert.ok(result != null, 'expected a non-null result');
    assert.equal(result.docId, 'the_monsters_big_into_energy_vinyl_plush_pendant_luck');

    const { fields } = result;
    assert.equal(fields.level, 'figure');
    assert.equal(fields.figureId, 'the_monsters_big_into_energy_vinyl_plush_pendant_luck');
    assert.equal(fields.seriesId, 'the_monsters_big_into_energy_vinyl_plush_pendant');
    assert.equal(fields.estimatedValueUsd, 42.0);
    assert.equal(fields.trend, 'unknown');
    assert.equal(fields.confidence, 'high');
    assert.equal(fields.recentSalesCount, 18);
    assert.equal(fields.priceRangeMinUsd, 35.0);
    assert.equal(fields.priceRangeMaxUsd, 55.0);
  });

  test('document id equals figureId', () => {
    const snapshot = makeSnapshot({ figureId: 'some_figure_id' });
    const result = buildFirestoreDocument(snapshot);
    assert.ok(result != null);
    assert.equal(result.docId, 'some_figure_id');
  });

  test('trend is always "unknown" for MVP', () => {
    const result = buildFirestoreDocument(makeSnapshot());
    assert.ok(result != null);
    assert.equal(result.fields.trend, 'unknown');
  });

  test('level is always "figure"', () => {
    const result = buildFirestoreDocument(makeSnapshot());
    assert.ok(result != null);
    assert.equal(result.fields.level, 'figure');
  });

  test('confidence "low" is preserved', () => {
    const result = buildFirestoreDocument(makeSnapshot({ confidence: 'low', sampleSize: 3 }));
    assert.ok(result != null);
    assert.equal(result.fields.confidence, 'low');
  });

  test('averagePrice is NOT included in Firestore fields', () => {
    const result = buildFirestoreDocument(makeSnapshot());
    assert.ok(result != null);
    assert.ok(!('averagePrice' in result.fields), 'averagePrice must not be stored');
  });

  test('dataSource is NOT included in Firestore fields', () => {
    const result = buildFirestoreDocument(makeSnapshot());
    assert.ok(result != null);
    assert.ok(!('dataSource' in result.fields), 'dataSource must not be stored');
  });

  test('priceRange fields are omitted when null', () => {
    const result = buildFirestoreDocument(
      makeSnapshot({ minPrice: null, maxPrice: null }),
    );
    assert.ok(result != null);
    assert.ok(!('priceRangeMinUsd' in result.fields));
    assert.ok(!('priceRangeMaxUsd' in result.fields));
  });

  test('computedAt is set to snapshotAt (replaced by serverTimestamp on write)', () => {
    const result = buildFirestoreDocument(makeSnapshot({ snapshotAt: '2026-06-15T03:00:00.000Z' }));
    assert.ok(result != null);
    assert.equal(result.fields.computedAt, '2026-06-15T03:00:00.000Z');
  });
});

describe('buildFirestoreDocument — skip conditions', () => {
  test('returns null when medianPrice is null', () => {
    const result = buildFirestoreDocument(makeSnapshot({ medianPrice: null }));
    assert.equal(result, null);
  });

  test('returns null when medianPrice is 0', () => {
    const result = buildFirestoreDocument(makeSnapshot({ medianPrice: 0 }));
    assert.equal(result, null);
  });

  test('returns null when medianPrice is negative', () => {
    const result = buildFirestoreDocument(makeSnapshot({ medianPrice: -5 }));
    assert.equal(result, null);
  });

  test('returns null when seriesId is empty string', () => {
    const result = buildFirestoreDocument(makeSnapshot({ seriesId: '' }));
    assert.equal(result, null);
  });

  test('accepts medianPrice of any positive value including small fractions', () => {
    const result = buildFirestoreDocument(makeSnapshot({ medianPrice: 0.01 }));
    assert.ok(result != null);
    assert.equal(result.fields.estimatedValueUsd, 0.01);
  });
});

describe('buildFirestoreDocument — sampleSize zero', () => {
  test('returns null for zero sampleSize with null medianPrice (empty aggregation)', () => {
    const result = buildFirestoreDocument(
      makeSnapshot({ sampleSize: 0, medianPrice: null, averagePrice: null }),
    );
    assert.equal(result, null);
  });
});

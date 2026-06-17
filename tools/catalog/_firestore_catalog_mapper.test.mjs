import assert from 'node:assert/strict';
import test from 'node:test';

import {
  compareSeriesSnapshotOrder,
  firestoreCatalogDocToJsonMap,
  mapFirestoreFigure,
  mapFirestoreSeries,
  mapSeriesSnapshot,
  timestampToCatalogDate,
} from './_firestore_catalog_mapper.mjs';

test('firestoreCatalogDocToJsonMap uses doc id when id missing', () => {
  const mapped = firestoreCatalogDocToJsonMap('series_a', {
    brandId: 'pop_mart',
    displayName: 'Series A',
  });
  assert.equal(mapped.id, 'series_a');
});

test('firestoreCatalogDocToJsonMap converts Firestore Timestamp releaseDate', () => {
  const mapped = firestoreCatalogDocToJsonMap('series_a', {
    id: 'series_a',
    releaseDate: {
      toDate: () => new Date('2026-04-23T15:30:00Z'),
    },
  });
  assert.equal(mapped.releaseDate, '2026-04-23');
});

test('mapFirestoreSeries rejects missing imageKey', () => {
  const mapped = mapFirestoreSeries('series_a', {
    id: 'series_a',
    brandId: 'pop_mart',
    ipId: 'labubu',
    displayName: 'Series A',
  });
  assert.equal(mapped, null);
});

test('mapFirestoreFigure keeps JSON-compatible fields', () => {
  const mapped = mapFirestoreFigure('figure_a', {
    id: 'figure_a',
    seriesId: 'series_a',
    brandId: 'pop_mart',
    ipId: 'labubu',
    displayName: 'Hope',
    imageKey: 'figure_a',
    isSecret: false,
    sortOrder: 1.0,
    rarityLabel: null,
  });

  assert.deepEqual(mapped, {
    id: 'figure_a',
    seriesId: 'series_a',
    brandId: 'pop_mart',
    ipId: 'labubu',
    displayName: 'Hope',
    imageKey: 'figure_a',
    isSecret: false,
    sortOrder: 1,
    rarityLabel: null,
    releaseDate: null,
  });
});

test('mapFirestoreFigure normalizes figure aliases', () => {
  const mapped = mapFirestoreFigure('figure_a', {
    id: 'figure_a',
    seriesId: 'series_a',
    brandId: 'pop_mart',
    ipId: 'labubu',
    displayName: 'Luck',
    imageKey: 'figure_a',
    isSecret: false,
    sortOrder: 1,
    aliases: ['Lucky', '', '  ', 'Luckster'],
  });

  assert.deepEqual(mapped?.aliases, ['Lucky', 'Luckster']);
});

test('mapSeriesSnapshot sorts by releaseDate descending', () => {
  const snap = {
    docs: [
      {
        id: 'older',
        data: () => ({
          id: 'older',
          brandId: 'b',
          ipId: 'i',
          displayName: 'Older',
          imageKey: 'older',
          releaseDate: '2025-01-01',
          isBlindBox: true,
        }),
      },
      {
        id: 'newer',
        data: () => ({
          id: 'newer',
          brandId: 'b',
          ipId: 'i',
          displayName: 'Newer',
          imageKey: 'newer',
          releaseDate: '2026-01-01',
          isBlindBox: true,
        }),
      },
    ],
  };

  const series = mapSeriesSnapshot(snap);
  assert.deepEqual(series.map((row) => row.id), ['newer', 'older']);
});

test('compareSeriesSnapshotOrder matches Dart ordering', () => {
  const newer = { id: 'newer', releaseDate: '2026-01-01' };
  const older = { id: 'older', releaseDate: '2025-01-01' };
  assert.ok(compareSeriesSnapshotOrder(newer, older, 0, 1) < 0);
  assert.ok(compareSeriesSnapshotOrder(older, newer, 1, 0) > 0);
});

test('timestampToCatalogDate formats UTC date', () => {
  assert.equal(
    timestampToCatalogDate({
      toDate: () => new Date('2026-06-15T23:59:59Z'),
    }),
    '2026-06-15',
  );
});

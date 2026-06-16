import assert from 'node:assert/strict';
import { join } from 'node:path';
import test from 'node:test';

import { assembleCatalogBundle } from '../market_intel/_catalog_bundle.mjs';
import {
  loadFirestoreCatalogBundle,
  readCatalogCollectionsFromFirestore,
} from './load_firestore_catalog_bundle.mjs';

function mockFirestore(collections) {
  return {
    collection(name) {
      return {
        async get() {
          const rows = collections[name] ?? [];
          return {
            docs: rows.map((row) => ({
              id: row.id,
              data: () => row.data,
            })),
          };
        },
      };
    },
  };
}

test('readCatalogCollectionsFromFirestore maps usable documents only', async () => {
  const db = mockFirestore({
    brands: [{ id: 'pop_mart', data: { displayName: 'POP MART' } }],
    ips: [
      {
        id: 'labubu',
        data: { brandId: 'pop_mart', displayName: 'THE MONSTERS' },
      },
    ],
    series: [
      {
        id: 'series_a',
        data: {
          brandId: 'pop_mart',
          ipId: 'labubu',
          displayName: 'Big into Energy',
          imageKey: 'series_a',
          releaseDate: '2026-01-01',
          isBlindBox: true,
        },
      },
      {
        id: 'invalid_series',
        data: { displayName: 'Missing refs' },
      },
    ],
    figures: [
      {
        id: 'figure_a',
        data: {
          seriesId: 'series_a',
          brandId: 'pop_mart',
          ipId: 'labubu',
          displayName: 'Hope',
          imageKey: 'figure_a',
          isSecret: false,
          sortOrder: 1,
        },
      },
    ],
  });

  const catalog = await readCatalogCollectionsFromFirestore(db);
  assert.equal(catalog.brands.length, 1);
  assert.equal(catalog.ips.length, 1);
  assert.equal(catalog.series.length, 1);
  assert.equal(catalog.figures.length, 1);
  assert.equal(catalog.figures[0].id, 'figure_a');
});

test('loadFirestoreCatalogBundle returns pipeline bundle shape', async () => {
  const db = mockFirestore({
    brands: [{ id: 'pop_mart', data: { displayName: 'POP MART' } }],
    ips: [
      {
        id: 'labubu',
        data: { brandId: 'pop_mart', displayName: 'THE MONSTERS' },
      },
    ],
    series: [
      {
        id: 'series_a',
        data: {
          brandId: 'pop_mart',
          ipId: 'labubu',
          displayName: 'Big into Energy',
          imageKey: 'series_a',
          releaseDate: '2026-01-01',
          isBlindBox: true,
        },
      },
    ],
    figures: [
      {
        id: 'figure_a',
        data: {
          seriesId: 'series_a',
          brandId: 'pop_mart',
          ipId: 'labubu',
          displayName: 'Hope',
          imageKey: 'figure_a',
          isSecret: false,
          sortOrder: 1,
        },
      },
    ],
  });

  const prevProject = process.env.FIREBASE_PROJECT_ID;
  process.env.FIREBASE_PROJECT_ID = 'blindbox-collection-test';

  try {
    const bundle = await loadFirestoreCatalogBundle(undefined, {
      firestore: db,
      quiet: true,
    });

    assert.equal(bundle.catalogSource, 'firestore');
    assert.equal(bundle.catalogDataDir, 'firestore://blindbox-collection-test');
    assert.equal(bundle.figures.length, 1);
    assert.equal(bundle.series.length, 1);
    assert.ok(bundle.catalogFigureIds.has('figure_a'));
    assert.ok(bundle.seriesById.get('series_a'));
    assert.ok(bundle.brandById.get('pop_mart'));
    assert.ok(bundle.ipById.get('labubu'));
    assert.ok(bundle.metadata);
    assert.ok(bundle.catalogToMetadata instanceof Map);
  } finally {
    if (prevProject) process.env.FIREBASE_PROJECT_ID = prevProject;
    else delete process.env.FIREBASE_PROJECT_ID;
  }
});

test('loadFirestoreCatalogBundle fails when zero figures exported', async () => {
  const db = mockFirestore({
    brands: [],
    ips: [],
    series: [],
    figures: [],
  });

  await assert.rejects(
    () => loadFirestoreCatalogBundle(undefined, { firestore: db, quiet: true }),
    /zero figures/,
  );
});

test('assembleCatalogBundle joins metadata like file loader', () => {
  const repoRoot = join(import.meta.dirname, '..', '..');
  const bundle = assembleCatalogBundle(repoRoot, {
    catalogDataDir: '/tmp/catalog',
    catalogSource: 'option',
    brands: [{ id: 'b', displayName: 'Brand' }],
    ips: [{ id: 'i', brandId: 'b', displayName: 'IP' }],
    series: [
      {
        id: 's',
        brandId: 'b',
        ipId: 'i',
        displayName: 'Series',
        imageKey: 's',
        isBlindBox: true,
      },
    ],
    figures: [
      {
        id: 'f',
        seriesId: 's',
        brandId: 'b',
        ipId: 'i',
        displayName: 'Figure',
        imageKey: 'f',
      },
    ],
  });

  assert.equal(bundle.catalogSource, 'option');
  assert.equal(bundle.figures[0].id, 'f');
  assert.ok(bundle.metadata.figures);
});

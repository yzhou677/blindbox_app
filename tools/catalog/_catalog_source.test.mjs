import assert from 'node:assert/strict';
import { mkdtempSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';

import {
  assertCatalogBundleAllowed,
  isCatalogStrict,
  loadCatalogBundle,
  loadCatalogBundleForSource,
  resolveCatalogSource,
} from '../market_intel/_catalog_bundle.mjs';

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

const minimalCatalog = {
  brands: [{ id: 'b', data: { displayName: 'Brand' } }],
  ips: [{ id: 'i', data: { brandId: 'b', displayName: 'IP' } }],
  series: [
    {
      id: 's',
      data: {
        brandId: 'b',
        ipId: 'i',
        displayName: 'Series',
        imageKey: 's',
        isBlindBox: true,
      },
    },
  ],
  figures: [
    {
      id: 'f',
      data: {
        seriesId: 's',
        brandId: 'b',
        ipId: 'i',
        displayName: 'Figure',
        imageKey: 'f',
        isSecret: false,
        sortOrder: 1,
      },
    },
  ],
};

test('resolveCatalogSource defaults to firestore', () => {
  const prev = process.env.CATALOG_SOURCE;
  delete process.env.CATALOG_SOURCE;
  assert.equal(resolveCatalogSource(), 'firestore');
  if (prev) process.env.CATALOG_SOURCE = prev;
});

test('resolveCatalogSource honors explicit file source', () => {
  assert.equal(resolveCatalogSource({ catalogSource: 'file' }), 'file');
});

test('resolveCatalogSource honors CATALOG_SOURCE env', () => {
  const prev = process.env.CATALOG_SOURCE;
  process.env.CATALOG_SOURCE = 'file';
  assert.equal(resolveCatalogSource(), 'file');
  if (prev) process.env.CATALOG_SOURCE = prev;
  else delete process.env.CATALOG_SOURCE;
});

test('isCatalogStrict recognizes CATALOG_STRICT=1', () => {
  const prev = process.env.CATALOG_STRICT;
  process.env.CATALOG_STRICT = '1';
  assert.equal(isCatalogStrict(), true);
  if (prev) process.env.CATALOG_STRICT = prev;
  else delete process.env.CATALOG_STRICT;
});

test('assertCatalogBundleAllowed throws for seed fallback in strict file mode', () => {
  assert.throws(
    () =>
      assertCatalogBundleAllowed(
        { catalogSource: 'seed_fallback' },
        {
          strict: true,
          catalogSource: 'file',
        },
      ),
    /CATALOG_STRICT=1/,
  );
});

test('assertCatalogBundleAllowed allows seed fallback when strict is off', () => {
  const bundle = loadCatalogBundle(join(import.meta.dirname, '..', '..'));
  assert.doesNotThrow(() =>
    assertCatalogBundleAllowed(bundle, {
      strict: false,
      catalogSource: 'file',
    }),
  );
});

test('loadCatalogBundleForSource uses file path when requested', async () => {
  const dir = mkdtempSync(join(tmpdir(), 'catalog-source-test-'));
  writeFileSync(
    join(dir, 'figures.json'),
    JSON.stringify([
      {
        id: 'f',
        seriesId: 's',
        brandId: 'b',
        ipId: 'i',
        displayName: 'Figure',
        imageKey: 'f',
      },
    ]),
  );
  writeFileSync(
    join(dir, 'series.json'),
    JSON.stringify([
      {
        id: 's',
        brandId: 'b',
        ipId: 'i',
        displayName: 'Series',
        imageKey: 's',
        isBlindBox: true,
      },
    ]),
  );
  writeFileSync(join(dir, 'brands.json'), JSON.stringify([{ id: 'b', displayName: 'Brand' }]));
  writeFileSync(join(dir, 'ips.json'), JSON.stringify([{ id: 'i', brandId: 'b', displayName: 'IP' }]));

  const bundle = await loadCatalogBundleForSource(join(import.meta.dirname, '..', '..'), {
    catalogSource: 'file',
    catalogDataDir: dir,
  });

  assert.equal(bundle.catalogSource, 'option');
  assert.equal(bundle.figures[0].id, 'f');
});

test('loadCatalogBundleForSource uses firestore when requested', async () => {
  const prevProject = process.env.FIREBASE_PROJECT_ID;
  process.env.FIREBASE_PROJECT_ID = 'blindbox-collection-test';

  try {
    const bundle = await loadCatalogBundleForSource(join(import.meta.dirname, '..', '..'), {
      catalogSource: 'firestore',
      firestore: mockFirestore(minimalCatalog),
      quiet: true,
    });
    assert.equal(bundle.catalogSource, 'firestore');
    assert.equal(bundle.figures[0].id, 'f');
  } finally {
    if (prevProject) process.env.FIREBASE_PROJECT_ID = prevProject;
    else delete process.env.FIREBASE_PROJECT_ID;
  }
});

test('loadCatalogBundleForSource fails strict file mode on seed fallback', async () => {
  const prevStrict = process.env.CATALOG_STRICT;
  const prevCatalogDir = process.env.CATALOG_DATA_DIR;
  process.env.CATALOG_STRICT = '1';
  delete process.env.CATALOG_DATA_DIR;

  try {
    await assert.rejects(
      () =>
        loadCatalogBundleForSource(join(import.meta.dirname, '..', '..'), {
          catalogSource: 'file',
          strict: true,
        }),
      /CATALOG_STRICT=1/,
    );
  } finally {
    if (prevStrict) process.env.CATALOG_STRICT = prevStrict;
    else delete process.env.CATALOG_STRICT;
    if (prevCatalogDir) process.env.CATALOG_DATA_DIR = prevCatalogDir;
  }
});

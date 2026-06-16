import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';

import {
  loadCatalogBundle,
  resolveCatalogDataDir,
  SEED_CATALOG_RELATIVE_DIR,
} from './_catalog_bundle.mjs';

test('resolveCatalogDataDir defaults to tools/seed when env unset', () => {
  const prev = process.env.CATALOG_DATA_DIR;
  delete process.env.CATALOG_DATA_DIR;

  const resolved = resolveCatalogDataDir(join(import.meta.dirname, '..', '..'));
  assert.equal(resolved.catalogSource, 'seed_fallback');
  assert.ok(resolved.catalogDataDir.endsWith(SEED_CATALOG_RELATIVE_DIR.replace(/\//g, '\\')) ||
    resolved.catalogDataDir.endsWith(SEED_CATALOG_RELATIVE_DIR));

  if (prev) process.env.CATALOG_DATA_DIR = prev;
});

test('loadCatalogBundle reads from CATALOG_DATA_DIR when set', () => {
  const dir = mkdtempSync(join(tmpdir(), 'catalog-bundle-test-'));
  const payload = [{ id: 'test_figure', seriesId: 'test_series', brandId: 'b', displayName: 'Test' }];
  writeFileSync(join(dir, 'figures.json'), JSON.stringify(payload));
  writeFileSync(join(dir, 'series.json'), JSON.stringify([{ id: 'test_series', displayName: 'Test Series', brandId: 'b', ipId: 'i' }]));
  writeFileSync(join(dir, 'brands.json'), JSON.stringify([{ id: 'b', displayName: 'Brand' }]));
  writeFileSync(join(dir, 'ips.json'), JSON.stringify([{ id: 'i', displayName: 'IP' }]));

  const bundle = loadCatalogBundle(join(import.meta.dirname, '..', '..'), {
    catalogDataDir: dir,
  });

  assert.equal(bundle.catalogSource, 'option');
  assert.equal(bundle.figures.length, 1);
  assert.equal(bundle.figures[0].id, 'test_figure');
});

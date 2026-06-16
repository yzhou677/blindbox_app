/**
 * Loads catalog collections from Firestore into the market pipeline bundle shape.
 *
 * Mirrors loadFirestoreCatalogBundle() in firestore_catalog_loader.dart.
 */

import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

import { getFirestore, resolveProjectId } from './_firebase_admin.mjs';
import {
  mapBrandSnapshot,
  mapFigureSnapshot,
  mapIpSnapshot,
  mapSeriesSnapshot,
} from './_firestore_catalog_mapper.mjs';
import { assembleCatalogBundle } from '../market_intel/_catalog_bundle.mjs';

const __dirname = dirname(fileURLToPath(import.meta.url));
const defaultRepoRoot = join(__dirname, '..', '..');

/**
 * @typedef {import('../market_intel/_catalog_bundle.mjs').CatalogBundle} CatalogBundle
 */

/**
 * @param {import('firebase-admin').firestore.Firestore} db
 * @returns {Promise<{
 *   brands: Record<string, unknown>[],
 *   ips: Record<string, unknown>[],
 *   series: Record<string, unknown>[],
 *   figures: Record<string, unknown>[],
 * }>}
 */
export async function readCatalogCollectionsFromFirestore(db) {
  const [brandsSnap, ipsSnap, seriesSnap, figuresSnap] = await Promise.all([
    db.collection('brands').get(),
    db.collection('ips').get(),
    db.collection('series').get(),
    db.collection('figures').get(),
  ]);

  return {
    brands: mapBrandSnapshot(brandsSnap),
    ips: mapIpSnapshot(ipsSnap),
    series: mapSeriesSnapshot(seriesSnap),
    figures: mapFigureSnapshot(figuresSnap),
  };
}

/**
 * @param {string} [repoRoot]
 * @param {{
 *   firestore?: import('firebase-admin').firestore.Firestore,
 *   quiet?: boolean,
 * }} [options]
 * @returns {Promise<CatalogBundle>}
 */
export async function loadFirestoreCatalogBundle(
  repoRoot = defaultRepoRoot,
  options = {},
) {
  const db = options.firestore ?? getFirestore({ quiet: options.quiet });
  const projectId = resolveProjectId() ?? 'unknown-project';
  const catalog = await readCatalogCollectionsFromFirestore(db);

  if (catalog.figures.length === 0) {
    throw new Error(
      'Firestore catalog export returned zero figures. Check project id and collection data.',
    );
  }

  return assembleCatalogBundle(repoRoot, {
    catalogDataDir: `firestore://${projectId}`,
    catalogSource: 'firestore',
    ...catalog,
  });
}

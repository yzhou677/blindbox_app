/**
 * Market Intelligence — catalog bundle loading and metadata joins.
 *
 * Shared by snapshot pipeline and dev review tools.
 * Pure I/O at load boundary; join helpers are pure.
 */

import { existsSync, readFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const defaultRepoRoot = join(__dirname, '..', '..');

/** Relative to repo root — offline dev / test fallback only. */
export const SEED_CATALOG_RELATIVE_DIR = 'tools/seed';

/**
 * Resolves catalog JSON directory for the Node market pipeline.
 *
 * Priority:
 *   1. options.catalogDataDir
 *   2. process.env.CATALOG_DATA_DIR (absolute or relative to repoRoot)
 *   3. tools/seed (offline dev fallback — NOT production source of truth)
 *
 * Shelfy architecture: Firestore catalog is canonical. Production runs should set
 * CATALOG_DATA_DIR to a Firestore export (e.g. blindbox-catalog/data).
 *
 * @param {string} [repoRoot]
 * @param {{ catalogDataDir?: string }} [options]
 * @returns {{ catalogDataDir: string, catalogSource: 'env' | 'option' | 'seed_fallback' }}
 */
export function resolveCatalogDataDir(repoRoot = defaultRepoRoot, options = {}) {
  const explicit = options.catalogDataDir?.trim();
  if (explicit) {
    return {
      catalogDataDir: resolve(explicit),
      catalogSource: 'option',
    };
  }

  const fromEnv = process.env.CATALOG_DATA_DIR?.trim();
  if (fromEnv) {
    return {
      catalogDataDir: resolve(repoRoot, fromEnv),
      catalogSource: 'env',
    };
  }

  return {
    catalogDataDir: join(repoRoot, SEED_CATALOG_RELATIVE_DIR),
    catalogSource: 'seed_fallback',
  };
}

/**
 * @param {string} catalogDataDir
 * @param {string} filename
 */
export function loadCatalogJsonFromDir(catalogDataDir, filename) {
  const path = join(catalogDataDir, filename);
  if (!existsSync(path)) {
    throw new Error(
      `Catalog file not found: ${path}\n` +
        'Set CATALOG_DATA_DIR to a Firestore export directory (brands.json, ips.json, series.json, figures.json).',
    );
  }
  return JSON.parse(readFileSync(path, 'utf8'));
}

/** Architecture example ids → canonical catalog figure ids (DEV_VALIDATION.md). */
export const METADATA_KEY_TO_CATALOG_FIGURE_ID = Object.freeze({
  lucky_big_into_energy_popmart:
    'the_monsters_big_into_energy_vinyl_plush_pendant_luck',
  hope_big_into_energy_popmart:
    'the_monsters_big_into_energy_vinyl_plush_pendant_hope',
});

/**
 * @param {string} repoRoot
 * @param {string} relativePath
 */
export function loadJsonFromRepo(repoRoot, relativePath) {
  return JSON.parse(readFileSync(join(repoRoot, relativePath), 'utf8'));
}

/**
 * @param {string} key
 * @param {object} entry
 * @param {Set<string>} catalogFigureIds
 * @returns {string | null}
 */
export function resolveCatalogFigureId(key, entry, catalogFigureIds) {
  if (entry?.catalogFigureId) {
    return entry.catalogFigureId;
  }
  if (METADATA_KEY_TO_CATALOG_FIGURE_ID[key]) {
    return METADATA_KEY_TO_CATALOG_FIGURE_ID[key];
  }
  if (catalogFigureIds.has(key)) {
    return key;
  }
  return null;
}

/**
 * @param {Record<string, object>} metadataFigures
 * @param {Set<string>} catalogFigureIds
 * @returns {Map<string, { key: string, entry: object }>}
 */
export function buildCatalogToMetadataMap(metadataFigures, catalogFigureIds) {
  /** @type {Map<string, { key: string, entry: object }>} */
  const map = new Map();

  for (const [key, entry] of Object.entries(metadataFigures ?? {})) {
    const catalogFigureId = resolveCatalogFigureId(key, entry, catalogFigureIds);
    if (catalogFigureId) {
      map.set(catalogFigureId, { key, entry });
    }
  }

  return map;
}

/**
 * @typedef {'env' | 'option' | 'seed_fallback' | 'firestore'} CatalogBundleSource
 */

/**
 * @typedef {{
 *   repoRoot: string,
 *   catalogDataDir: string,
 *   catalogSource: CatalogBundleSource,
 *   figures: object[],
 *   series: object[],
 *   brands: object[],
 *   ips: object[],
 *   metadata: object,
 *   catalogFigureIds: Set<string>,
 *   catalogToMetadata: Map<string, { key: string, entry: object }>,
 *   seriesById: Map<string, object>,
 *   brandById: Map<string, object>,
 *   ipById: Map<string, object>,
 * }} CatalogBundle
 */

/**
 * @param {string} repoRoot
 * @param {{
 *   catalogDataDir: string,
 *   catalogSource: CatalogBundleSource,
 *   figures: object[],
 *   series: object[],
 *   brands: object[],
 *   ips: object[],
 * }} input
 * @returns {CatalogBundle}
 */
export function assembleCatalogBundle(repoRoot, input) {
  const metadata = loadJsonFromRepo(
    repoRoot,
    'tools/market_intel/market_metadata.json',
  );
  const catalogFigureIds = new Set(input.figures.map((figure) => figure.id));

  return {
    repoRoot,
    catalogDataDir: input.catalogDataDir,
    catalogSource: input.catalogSource,
    figures: input.figures,
    series: input.series,
    brands: input.brands,
    ips: input.ips,
    metadata,
    catalogFigureIds,
    catalogToMetadata: buildCatalogToMetadataMap(
      metadata.figures,
      catalogFigureIds,
    ),
    seriesById: new Map(input.series.map((row) => [row.id, row])),
    brandById: new Map(input.brands.map((row) => [row.id, row])),
    ipById: new Map(input.ips.map((row) => [row.id, row])),
  };
}

/**
 * @param {{ catalogSource?: string }} [options]
 * @returns {'firestore' | 'file'}
 */
export function resolveCatalogSource(options = {}) {
  const explicit = options.catalogSource?.trim();
  if (explicit === 'file' || explicit === 'firestore') {
    return explicit;
  }

  const fromEnv = process.env.CATALOG_SOURCE?.trim();
  if (fromEnv === 'file' || fromEnv === 'firestore') {
    return fromEnv;
  }

  return 'firestore';
}

/**
 * @returns {boolean}
 */
export function isCatalogStrict() {
  const value = process.env.CATALOG_STRICT?.trim().toLowerCase();
  return value === '1' || value === 'true' || value === 'yes';
}

/**
 * @param {CatalogBundle} bundle
 * @param {{ strict?: boolean, catalogSource?: 'firestore' | 'file' }} [options]
 */
export function assertCatalogBundleAllowed(bundle, options = {}) {
  const strict = options.strict ?? isCatalogStrict();
  if (!strict) return;

  const requestedSource = options.catalogSource ?? resolveCatalogSource(options);
  if (requestedSource !== 'file') return;

  if (bundle.catalogSource === 'seed_fallback') {
    throw new Error(
      'CATALOG_STRICT=1: refused tools/seed catalog fallback.\n' +
        'Set CATALOG_DATA_DIR to a JSON export directory or use --catalog-source firestore.',
    );
  }
}

/**
 * @param {string} [repoRoot]
 * @param {{ catalogDataDir?: string, catalogSource?: 'firestore' | 'file', strict?: boolean }} [options]
 * @returns {Promise<CatalogBundle>}
 */
export async function loadCatalogBundleForSource(
  repoRoot = defaultRepoRoot,
  options = {},
) {
  const catalogSource = resolveCatalogSource(options);

  const bundle =
    catalogSource === 'firestore'
      ? await import('../catalog/load_firestore_catalog_bundle.mjs').then(
          ({ loadFirestoreCatalogBundle }) =>
            loadFirestoreCatalogBundle(repoRoot, options),
        )
      : loadCatalogBundle(repoRoot, options);

  assertCatalogBundleAllowed(bundle, { ...options, catalogSource });
  return bundle;
}

/**
 * @param {string} [repoRoot]
 * @param {{ catalogDataDir?: string }} [options]
 * @returns {CatalogBundle}
 */
export function loadCatalogBundle(repoRoot = defaultRepoRoot, options = {}) {
  const { catalogDataDir, catalogSource } = resolveCatalogDataDir(
    repoRoot,
    options,
  );

  return assembleCatalogBundle(repoRoot, {
    catalogDataDir,
    catalogSource,
    figures: loadCatalogJsonFromDir(catalogDataDir, 'figures.json'),
    series: loadCatalogJsonFromDir(catalogDataDir, 'series.json'),
    brands: loadCatalogJsonFromDir(catalogDataDir, 'brands.json'),
    ips: loadCatalogJsonFromDir(catalogDataDir, 'ips.json'),
  });
}

/**
 * @param {object} bundle
 * @param {string} catalogFigureId
 * @returns {{ key: string | null, entry: object }}
 */
export function getMetadataRecord(bundle, catalogFigureId) {
  const mapped = bundle.catalogToMetadata.get(catalogFigureId);
  return {
    key: mapped?.key ?? null,
    entry: mapped?.entry ?? {},
  };
}

/**
 * @param {object} figure
 * @param {ReturnType<typeof loadCatalogBundle>} bundle
 * @returns {{
 *   brand: object | undefined,
 *   ip: object | undefined,
 *   series: object | undefined,
 * }}
 */
export function buildCatalogContextForFigure(figure, bundle) {
  const series = bundle.seriesById.get(figure.seriesId);
  const brand = bundle.brandById.get(figure.brandId);
  const ip = bundle.ipById.get(series?.ipId ?? figure.ipId);

  return { brand, ip, series };
}

/**
 * Metadata shape passed to deriveSearchTerms / matcher.
 *
 * @param {object} metadataEntry
 * @returns {{
 *   disabled: boolean,
 *   searchTerms: string[],
 *   marketAliases: string[],
 *   excludeTerms: string[],
 *   matchThreshold: number | null,
 *   notes: string,
 * }}
 */
export function normalizeMetadataEntry(metadataEntry = {}) {
  return {
    disabled: metadataEntry.disabled === true,
    searchTerms: metadataEntry.searchTerms ?? [],
    marketAliases: metadataEntry.marketAliases ?? [],
    excludeTerms: metadataEntry.excludeTerms ?? [],
    matchThreshold: metadataEntry.matchThreshold ?? null,
    notes: metadataEntry.notes ?? '',
  };
}

/**
 * @param {ReturnType<typeof loadCatalogBundle>} bundle
 * @param {string} catalogFigureId
 * @returns {object | undefined}
 */
export function findFigureById(bundle, catalogFigureId) {
  return bundle.figures.find((figure) => figure.id === catalogFigureId);
}

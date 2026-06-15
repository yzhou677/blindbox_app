/**
 * Market Intelligence — catalog bundle loading and metadata joins.
 *
 * Shared by snapshot pipeline and dev review tools.
 * Pure I/O at load boundary; join helpers are pure.
 */

import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const defaultRepoRoot = join(__dirname, '..', '..');

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
 * @param {string} [repoRoot]
 * @returns {{
 *   repoRoot: string,
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
 * }}
 */
export function loadCatalogBundle(repoRoot = defaultRepoRoot) {
  const figures = loadJsonFromRepo(repoRoot, 'tools/seed/figures.json');
  const series = loadJsonFromRepo(repoRoot, 'tools/seed/series.json');
  const brands = loadJsonFromRepo(repoRoot, 'tools/seed/brands.json');
  const ips = loadJsonFromRepo(repoRoot, 'tools/seed/ips.json');
  const metadata = loadJsonFromRepo(
    repoRoot,
    'tools/market_intel/market_metadata.json',
  );

  const catalogFigureIds = new Set(figures.map((figure) => figure.id));

  return {
    repoRoot,
    figures,
    series,
    brands,
    ips,
    metadata,
    catalogFigureIds,
    catalogToMetadata: buildCatalogToMetadataMap(
      metadata.figures,
      catalogFigureIds,
    ),
    seriesById: new Map(series.map((row) => [row.id, row])),
    brandById: new Map(brands.map((row) => [row.id, row])),
    ipById: new Map(ips.map((row) => [row.id, row])),
  };
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

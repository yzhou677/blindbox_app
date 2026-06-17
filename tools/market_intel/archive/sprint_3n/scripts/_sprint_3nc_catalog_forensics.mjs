#!/usr/bin/env node
/** Sprint 3N-C — catalog + search plan forensics (counts only). */
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { buildFigureSearchPlans } from './_snapshot_search.mjs';
import { loadJsonFromRepo } from './_catalog_bundle.mjs';

const repoRoot = join(import.meta.dirname, '..', '..');
const prodRoot = join(repoRoot, '..', 'blindbox-catalog');

function loadProdBundle() {
  const figures = JSON.parse(
    readFileSync(join(prodRoot, 'data', 'figures.json'), 'utf8'),
  );
  const series = JSON.parse(
    readFileSync(join(prodRoot, 'data', 'series.json'), 'utf8'),
  );
  const brands = JSON.parse(
    readFileSync(join(prodRoot, 'data', 'brands.json'), 'utf8'),
  );
  const ips = JSON.parse(
    readFileSync(join(prodRoot, 'data', 'ips.json'), 'utf8'),
  );
  const metadata = loadJsonFromRepo(repoRoot, 'tools/market_intel/market_metadata.json');
  const catalogFigureIds = new Set(figures.map((f) => f.id));
  return {
    repoRoot,
    figures,
    series,
    brands,
    ips,
    metadata,
    catalogFigureIds,
    catalogToMetadata: new Map(),
    seriesById: new Map(series.map((r) => [r.id, r])),
    brandById: new Map(brands.map((r) => [r.id, r])),
    ipById: new Map(ips.map((r) => [r.id, r])),
  };
}

function loadSeedIds() {
  const figures = loadJsonFromRepo(repoRoot, 'tools/seed/figures.json');
  const series = loadJsonFromRepo(repoRoot, 'tools/seed/series.json');
  return {
    figureIds: new Set(figures.map((f) => f.id)),
    seriesIds: new Set(series.map((s) => s.id)),
    figures,
    series,
  };
}

const prod = loadProdBundle();
const seed = loadSeedIds();
import { loadCatalogBundle } from './_catalog_bundle.mjs';

const prodPlans = buildFigureSearchPlans(prod);
const seedPlans = buildFigureSearchPlans(loadCatalogBundle());

const missingFigures = prod.figures.filter((f) => !seed.figureIds.has(f.id));
const missingSeries = prod.series.filter((s) => !seed.seriesIds.has(s.id));
const nonBlindMissing = missingSeries.filter((s) => s.isBlindBox === false);

const prodSkipped = prodPlans.filter((p) => p.skipReason);
const prodActive = prodPlans.filter((p) => !p.skipReason);

const megaFigures = prod.figures.filter(
  (f) =>
    /mega|400%|1000%/i.test(f.displayName) ||
    /mega|400|1000/i.test(f.id),
);
const megaPlans = megaFigures.map((f) =>
  prodPlans.find((p) => p.catalogFigureId === f.id),
);

const nonBlindFigures = prod.figures.filter((f) => {
  const s = prod.seriesById.get(f.seriesId);
  return s?.isBlindBox === false;
});

console.log(
  JSON.stringify(
    {
      counts: {
        prodFigures: prod.figures.length,
        prodSeries: prod.series.length,
        seedFigures: seed.figures.length,
        seedSeries: seed.series.length,
        missingFromSeedFigures: missingFigures.length,
        missingFromSeedSeries: missingSeries.length,
        missingNonBlindSeries: nonBlindMissing.length,
      },
      searchPlans: {
        prod: {
          total: prodPlans.length,
          active: prodActive.length,
          disabled: prodSkipped.filter((p) => p.skipReason === 'DISABLED').length,
          noSearchTerms: prodSkipped.filter((p) => p.skipReason === 'NO_SEARCH_TERMS')
            .length,
          noSearchTermsExamples: prodSkipped
            .filter((p) => p.skipReason === 'NO_SEARCH_TERMS')
            .slice(0, 10)
            .map((p) => ({
              id: p.catalogFigureId,
              name: p.displayName,
              series: p.catalogContext.series?.displayName,
            })),
        },
        seed: {
          total: seedPlans.length,
          active: seedPlans.filter((p) => !p.skipReason).length,
          noSearchTerms: seedPlans.filter((p) => p.skipReason === 'NO_SEARCH_TERMS')
            .length,
        },
      },
      megaSample: megaPlans.slice(0, 8).map((p) => ({
        id: p?.catalogFigureId,
        skip: p?.skipReason,
        termCount: p?.searchTerms?.length ?? 0,
        terms: p?.searchTerms?.slice(0, 2),
      })),
      nonBlindBox: {
        series: nonBlindMissing.map((s) => s.id),
        figureCount: nonBlindFigures.length,
        activePlans: nonBlindFigures.filter((f) => {
          const p = prodPlans.find((x) => x.catalogFigureId === f.id);
          return p && !p.skipReason;
        }).length,
      },
      missingSeriesSample: missingSeries.slice(0, 15).map((s) => ({
        id: s.id,
        name: s.displayName,
        isBlindBox: s.isBlindBox,
      })),
      missingFigureSample: missingFigures.slice(0, 10).map((f) => ({
        id: f.id,
        name: f.displayName,
        seriesId: f.seriesId,
      })),
    },
    null,
    2,
  ),
);

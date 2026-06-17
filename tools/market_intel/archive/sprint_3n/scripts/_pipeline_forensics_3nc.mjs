#!/usr/bin/env node
/** Catalog diff + search plan stats for 3N-C audit */
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import {
  buildFigureSearchPlan,
  buildFigureSearchPlans,
  SnapshotSkipReason,
} from './_snapshot_search.mjs';
import { buildCatalogToMetadataMap } from './_catalog_bundle.mjs';

const seedFigures = JSON.parse(readFileSync('tools/seed/figures.json', 'utf8'));
const seedSeries = JSON.parse(readFileSync('tools/seed/series.json', 'utf8'));
const prodFigures = JSON.parse(readFileSync('d:/blindbox-catalog/data/figures.json', 'utf8'));
const prodSeries = JSON.parse(readFileSync('d:/blindbox-catalog/data/series.json', 'utf8'));
const metadata = JSON.parse(readFileSync('tools/market_intel/market_metadata.json', 'utf8'));

const seedFigIds = new Set(seedFigures.map((f) => f.id));
const prodFigIds = new Set(prodFigures.map((f) => f.id));
const missingFromSeed = prodFigures.filter((f) => !seedFigIds.has(f.id));
const extraInSeed = seedFigures.filter((f) => !prodFigIds.has(f.id));

const seedSeriesIds = new Set(seedSeries.map((s) => s.id));
const prodSeriesIds = new Set(prodSeries.map((s) => s.id));
const missingSeriesFromSeed = prodSeries.filter((s) => !seedSeriesIds.has(s.id));

function makeBundle(figures, series) {
  const brands = JSON.parse(readFileSync('tools/seed/brands.json', 'utf8'));
  const ips = JSON.parse(readFileSync('tools/seed/ips.json', 'utf8'));
  const catalogFigureIds = new Set(figures.map((f) => f.id));
  return {
    figures,
    series,
    brands,
    ips,
    metadata,
    catalogFigureIds,
    catalogToMetadata: buildCatalogToMetadataMap(metadata.figures, catalogFigureIds),
    seriesById: new Map(series.map((s) => [s.id, s])),
    brandById: new Map(brands.map((b) => [b.id, b])),
    ipById: new Map(ips.map((i) => [i.id, i])),
  };
}

const prodBundle = makeBundle(prodFigures, prodSeries);
const seedBundle = makeBundle(seedFigures, seedSeries);

function planStats(bundle, label) {
  const plans = buildFigureSearchPlans(bundle);
  const noTerms = plans.filter((p) => p.skipReason === SnapshotSkipReason.NO_SEARCH_TERMS);
  const disabled = plans.filter((p) => p.skipReason === SnapshotSkipReason.DISABLED);
  const active = plans.filter((p) => !p.skipReason);
  const nonBlind = plans.filter((p) => {
    const fig = bundle.figures.find((f) => f.id === p.catalogFigureId);
    const s = bundle.seriesById.get(fig?.seriesId);
    return s?.isBlindBox === false;
  });
  const mega = plans.filter((p) => /mega|400%|1000%/i.test(p.displayName + ' ' + p.catalogFigureId));
  return {
    label,
    figures: bundle.figures.length,
    series: bundle.series.length,
    plans: plans.length,
    active,
    disabled: disabled.length,
    noSearchTerms: noTerms.length,
    noSearchTermsExamples: noTerms.slice(0, 5).map((p) => p.catalogFigureId),
    nonBlindActive: nonBlind.filter((p) => !p.skipReason).length,
    nonBlindTotal: nonBlind.length,
    megaActive: mega.filter((p) => !p.skipReason).length,
    megaTotal: mega.length,
  };
}

console.log(
  JSON.stringify(
    {
      catalogDiff: {
        prodFigures: prodFigures.length,
        seedFigures: seedFigures.length,
        missingFromSeed: missingFromSeed.length,
        extraInSeed: extraInSeed.length,
        missingSeriesFromSeed: missingSeriesFromSeed.length,
        missingSeriesExamples: missingSeriesFromSeed.slice(0, 8).map((s) => ({
          id: s.id,
          isBlindBox: s.isBlindBox,
        })),
        missingFigureExamples: missingFromSeed.slice(0, 8).map((f) => f.id),
      },
      seedPlans: planStats(seedBundle, 'seed'),
      prodPlans: planStats(prodBundle, 'prod'),
    },
    null,
    2,
  ),
);

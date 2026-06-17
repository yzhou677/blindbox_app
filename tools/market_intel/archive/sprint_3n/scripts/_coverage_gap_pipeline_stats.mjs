#!/usr/bin/env node
/**
 * One-off stats for MARKET_COVERAGE_GAP_AUDIT — production catalog export.
 * Reads d:/blindbox-catalog/data/*.json (Firestore upload source).
 */
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import {
  buildFigureSearchPlan,
  buildFigureSearchPlans,
  SnapshotSkipReason,
} from './_snapshot_search.mjs';
import { buildCatalogToMetadataMap } from './_catalog_bundle.mjs';

const catalogRoot = process.env.CATALOG_DATA_DIR ?? 'd:/blindbox-catalog/data';
const figures = JSON.parse(readFileSync(join(catalogRoot, 'figures.json'), 'utf8'));
const series = JSON.parse(readFileSync(join(catalogRoot, 'series.json'), 'utf8'));
const brands = JSON.parse(readFileSync(join(catalogRoot, 'brands.json'), 'utf8'));
const ips = JSON.parse(readFileSync(join(catalogRoot, 'ips.json'), 'utf8'));
const metadata = JSON.parse(
  readFileSync(join(process.cwd(), 'tools/market_intel/market_metadata.json'), 'utf8'),
);

const catalogFigureIds = new Set(figures.map((f) => f.id));
const bundle = {
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

const plans = buildFigureSearchPlans(bundle);
const stats = {
  catalogFigures: figures.length,
  catalogSeries: series.length,
  metadataFigureEntries: Object.keys(metadata.figures ?? {}).length,
  plansTotal: plans.length,
  activePlans: plans.filter((p) => !p.skipReason).length,
  skippedDisabled: plans.filter((p) => p.skipReason === SnapshotSkipReason.DISABLED).length,
  skippedNoSearchTerms: plans.filter(
    (p) => p.skipReason === SnapshotSkipReason.NO_SEARCH_TERMS,
  ).length,
};

const traceIds = [
  'the_monsters_mini_zimomo_maia_mini_zimomo_maia',
  'mega_crybaby_400_crying_in_pink_figure',
];

/** @type {Record<string, object>} */
const traces = {};
for (const id of traceIds) {
  const figure = figures.find((f) => f.id === id);
  traces[id] = {
    figureFound: Boolean(figure),
    seriesIsBlindBox: bundle.seriesById.get(figure?.seriesId)?.isBlindBox,
    plan: buildFigureSearchPlan(figure, bundle),
  };
}

console.log(JSON.stringify({ stats, traces }, null, 2));

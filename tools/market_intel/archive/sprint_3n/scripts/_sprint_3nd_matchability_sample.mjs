#!/usr/bin/env node
/** Sprint 3N-D — production catalog matchability sample */
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { auditCatalogCoverage, CoverageClass } from './_catalog_coverage_audit.mjs';
import { buildFigureSearchPlan } from './_snapshot_search.mjs';
import { loadJsonFromRepo } from './_catalog_bundle.mjs';

const repoRoot = join(import.meta.dirname, '..', '..');
const prodRoot = join(repoRoot, '..', 'blindbox-catalog');

function loadProdBundle() {
  const figures = JSON.parse(readFileSync(join(prodRoot, 'data', 'figures.json'), 'utf8'));
  const series = JSON.parse(readFileSync(join(prodRoot, 'data', 'series.json'), 'utf8'));
  const brands = JSON.parse(readFileSync(join(prodRoot, 'data', 'brands.json'), 'utf8'));
  const ips = JSON.parse(readFileSync(join(prodRoot, 'data', 'ips.json'), 'utf8'));
  const metadata = loadJsonFromRepo(repoRoot, 'tools/market_intel/market_metadata.json');
  return {
    repoRoot,
    figures,
    series,
    brands,
    ips,
    metadata,
    catalogFigureIds: new Set(figures.map((f) => f.id)),
    catalogToMetadata: new Map(),
    seriesById: new Map(series.map((r) => [r.id, r])),
    brandById: new Map(brands.map((r) => [r.id, r])),
    ipById: new Map(ips.map((r) => [r.id, r])),
  };
}

const bundle = loadProdBundle();
const audit = auditCatalogCoverage(bundle);

const sampleSelectors = [
  { label: 'Labubu / THE MONSTERS', match: (f) => f.id.includes('the_monsters') || f.seriesId.includes('the_monsters') },
  { label: 'Skullpanda', match: (f) => f.id.includes('skullpanda') || f.seriesId.includes('skullpanda') },
  { label: 'Crybaby', match: (f) => f.id.includes('crybaby') || f.seriesId.includes('crybaby') },
  { label: 'Hirono', match: (f) => f.id.includes('hirono') || f.seriesId.includes('hirono') },
  { label: 'Mega / 400% / 1000%', match: (f) => /mega|400|1000|100_series/i.test(`${f.id} ${f.displayName}`) },
  { label: 'Non-blind-box', match: (f) => bundle.seriesById.get(f.seriesId)?.isBlindBox === false },
];

const samples = [];
for (const sel of sampleSelectors) {
  const candidates = bundle.figures.filter(sel.match);
  const picked = [];
  const seenSeries = new Set();
  for (const f of candidates) {
    if (picked.length >= 3) break;
    if (seenSeries.has(f.seriesId) && picked.length >= 1) continue;
    seenSeries.add(f.seriesId);
    const plan = buildFigureSearchPlan(f, bundle);
    const rec = audit.figures.find((x) => x.figureId === f.id);
    picked.push({
      figureId: f.id,
      displayName: f.displayName,
      seriesId: f.seriesId,
      seriesName: bundle.seriesById.get(f.seriesId)?.displayName,
      isBlindBox: bundle.seriesById.get(f.seriesId)?.isBlindBox,
      searchTerms: plan?.searchTerms ?? [],
      skipReason: plan?.skipReason,
      coverageClass: rec?.classification,
      primaryReason: rec?.primaryReason,
      matcherRisks: rec?.matcherRisks?.map((r) => r.code) ?? [],
      likelyLiveSuccess:
        rec?.classification === CoverageClass.MATCHABLE
          ? 'high'
          : rec?.classification === CoverageClass.MATCHER_RISK
            ? 'medium'
            : 'low',
    });
  }
  samples.push({
    category: sel.label,
    prodFigureCount: candidates.length,
    auditDistribution: {
      matchable: candidates.filter((f) =>
        audit.figures.find((x) => x.figureId === f.id)?.classification === CoverageClass.MATCHABLE,
      ).length,
      matcherRisk: candidates.filter((f) =>
        audit.figures.find((x) => x.figureId === f.id)?.classification === CoverageClass.MATCHER_RISK,
      ).length,
      noSearchTerms: candidates.filter((f) =>
        audit.figures.find((x) => x.figureId === f.id)?.classification === CoverageClass.NO_SEARCH_TERMS,
      ).length,
    },
    examples: picked,
  });
}

console.log(
  JSON.stringify(
    {
      prodCatalogAudit: {
        totalFigures: audit.totalFigures,
        distribution: audit.distribution,
        percentages: audit.percentages,
      },
      samples,
    },
    null,
    2,
  ),
);

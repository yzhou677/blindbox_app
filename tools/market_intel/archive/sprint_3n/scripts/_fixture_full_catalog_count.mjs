#!/usr/bin/env node
/** Count fixture pipeline writables for full seed catalog */
import { loadCatalogBundle, findFigureById } from './_catalog_bundle.mjs';
import { buildFigureSearchPlans } from './_snapshot_search.mjs';
import { fetchFigureCompletedSales } from './_snapshot_fetch.mjs';
import { buildFigureSnapshot } from './_snapshot_document.mjs';
import { buildFirestoreDocument } from './push_market_snapshots.mjs';

const bundle = loadCatalogBundle();
const plans = buildFigureSearchPlans(bundle);

let skippedPlan = 0;
let fetched = 0;
let medianNull = 0;
let writable = 0;
let highConf = 0;
let lowConf = 0;

for (const plan of plans) {
  if (plan.skipReason) {
    skippedPlan += 1;
    continue;
  }
  const fetchResult = await fetchFigureCompletedSales(plan, { fetchMode: 'fixture' });
  fetched += 1;
  const figure = findFigureById(bundle, plan.catalogFigureId);
  if (!figure) continue;
  const pipeline = buildFigureSnapshot(fetchResult.listings, figure, bundle, {
    dataSource: 'fixture',
  });
  if (pipeline.aggregation.medianPrice == null) {
    medianNull += 1;
    continue;
  }
  const doc = buildFirestoreDocument(pipeline.document);
  if (doc) {
    writable += 1;
    if (pipeline.document.confidence === 'high') highConf += 1;
    else lowConf += 1;
  }
}

console.log(
  JSON.stringify(
    {
      catalogFigures: bundle.figures.length,
      plans: plans.length,
      skippedPlan,
      fetched,
      medianNull,
      writable,
      writableHighConfidence: highConf,
      writableLowConfidence: lowConf,
      writablePct: ((writable / bundle.figures.length) * 100).toFixed(1),
    },
    null,
    2,
  ),
);

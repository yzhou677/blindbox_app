#!/usr/bin/env node
/**
 * Market Intelligence — snapshot computation orchestrator.
 *
 * Usage (from repo root):
 *   node tools/market_intel/compute_snapshots.mjs --fetch
 *   node tools/market_intel/compute_snapshots.mjs --fetch --figure sisi
 *   node tools/market_intel/compute_snapshots.mjs --fetch --limit 50
 *   node tools/market_intel/compute_snapshots.mjs --dry-run
 *   node tools/market_intel/compute_snapshots.mjs --fetch --push-firestore
 *   node tools/market_intel/compute_snapshots.mjs --fetch --push-firestore --dry-run
 *   node tools/market_intel/compute_snapshots.mjs --dry-run --catalog-source file
 *   CATALOG_STRICT=1 node tools/market_intel/compute_snapshots.mjs --dry-run --catalog-source file
 *   EBAY_FETCH_MODE=fixture node tools/market_intel/compute_snapshots.mjs --fetch --figure sisi --snapshot-debug
 *
 * Catalog source (default: firestore):
 *   --catalog-source firestore   read brands/ips/series/figures from Firestore
 *   --catalog-source file        read JSON via CATALOG_DATA_DIR or tools/seed fallback
 *
 * Set CATALOG_STRICT=1 to fail when file mode would fall back to tools/seed.
 */

import { ebayClientIdConfigured, readEbayConfig } from './_ebay_env.mjs';
import {
  findFigureById,
  isCatalogStrict,
  loadCatalogBundleForSource,
  resolveCatalogSource,
} from './_catalog_bundle.mjs';
import {
  SnapshotSkipReason,
  analyzeQueryDuplication,
  buildDryRunFetchSteps,
  buildFigureSearchPlans,
} from './_snapshot_search.mjs';
import {
  fetchFigureCompletedSales,
  formatFigureFetchDebug,
  summarizeFetchResults,
} from './_snapshot_fetch.mjs';
import {
  buildFigureSnapshot,
  formatSnapshotDebug,
} from './_snapshot_document.mjs';
import { pushSnapshotsToFirestore } from './push_market_snapshots.mjs';

/**
 * @typedef {Object} CliOptions
 * @property {'dry-run' | 'fetch'} mode
 * @property {number | null} limit
 * @property {string | null} seriesFilter
 * @property {string | null} figureFilter
 * @property {boolean} verbose
 * @property {boolean} snapshotDebug
 * @property {boolean} pushFirestore
 * @property {'firestore' | 'file'} catalogSource
 */

/**
 * @param {string[]} argv
 * @returns {CliOptions}
 */
function parseCliOptions(argv) {
  /** @type {CliOptions} */
  const options = {
    mode: 'fetch',
    limit: null,
    seriesFilter: null,
    figureFilter: null,
    verbose: false,
    snapshotDebug: false,
    pushFirestore: false,
    catalogSource: 'firestore',
  };

  for (let index = 2; index < argv.length; index += 1) {
    const arg = argv[index];

    if (arg === '--catalog-source') {
      const value = argv[index + 1]?.trim();
      if (value !== 'firestore' && value !== 'file') {
        console.error('Expected firestore or file after --catalog-source');
        process.exit(1);
      }
      options.catalogSource = value;
      index += 1;
      continue;
    }

    if (arg === '--dry-run') {
      options.mode = 'dry-run';
      continue;
    }

    if (arg === '--fetch') {
      options.mode = 'fetch';
      continue;
    }

    if (arg === '--verbose') {
      options.verbose = true;
      continue;
    }

    if (arg === '--snapshot-debug') {
      options.snapshotDebug = true;
      continue;
    }

    if (arg === '--push-firestore') {
      options.pushFirestore = true;
      continue;
    }

    if (arg === '--limit') {
      const value = Number(argv[index + 1]);
      if (!Number.isFinite(value) || value <= 0) {
        console.error('Expected a positive number after --limit');
        process.exit(1);
      }
      options.limit = Math.floor(value);
      index += 1;
      continue;
    }

    if (arg === '--series') {
      const value = argv[index + 1]?.trim();
      if (!value) {
        console.error('Expected a value after --series');
        process.exit(1);
      }
      options.seriesFilter = value;
      index += 1;
      continue;
    }

    if (arg === '--figure') {
      const value = argv[index + 1]?.trim();
      if (!value) {
        console.error('Expected a value after --figure');
        process.exit(1);
      }
      options.figureFilter = value;
      index += 1;
      continue;
    }

    console.error(`Unknown argument: ${arg}`);
    process.exit(1);
  }

  return options;
}

/**
 * @param {import('./_snapshot_search.mjs').FigureSearchPlan} plan
 */
function printFigureDryRun(plan) {
  console.log('==================================================');
  console.log('CATALOG FIGURE ID:');
  console.log(plan.catalogFigureId);
  console.log('');
  console.log('METADATA KEY:');
  console.log(plan.metadataKey ?? '(none)');
  console.log('');
  console.log('DISPLAY NAME:');
  console.log(plan.displayName);
  console.log('');
  console.log('SEARCH TERM SOURCE:');
  console.log(
    plan.usesSearchTermsOverride
      ? 'metadata.searchTerms override'
      : 'deriveSearchTerms(catalog + metadata)',
  );
  console.log('');
  console.log('DERIVED SEARCH TERMS:');

  if (plan.searchTerms.length === 0) {
    console.log('(none)');
  } else {
    plan.searchTerms.forEach((term, index) => {
      console.log(`${index + 1}. ${term}`);
    });
  }

  console.log('');
  console.log('SNAPSHOT FETCH PATH:');

  const steps = buildDryRunFetchSteps(plan);
  for (const step of steps) {
    if (step.step === 'skip') {
      console.log(`SKIP (${step.skipReason})`);
      continue;
    }

    console.log(
      `${step.queryIndex}. ${step.query}  →  [pending eBay completed sales fetch]`,
    );
  }

  console.log('==================================================');
}

/**
 * @param {import('./_snapshot_search.mjs').FigureSearchPlan[]} plans
 */
function printPlanSummary(plans) {
  const activePlans = plans.filter((plan) => !plan.skipReason);
  const skippedDisabled = plans.filter(
    (plan) => plan.skipReason === SnapshotSkipReason.DISABLED,
  ).length;
  const skippedNoTerms = plans.filter(
    (plan) => plan.skipReason === SnapshotSkipReason.NO_SEARCH_TERMS,
  ).length;
  const overrideCount = plans.filter(
    (plan) => plan.usesSearchTermsOverride,
  ).length;
  const duplication = analyzeQueryDuplication(plans);

  console.log('');
  console.log('PLAN SUMMARY');
  console.log('');
  console.log(`Figures planned: ${plans.length}`);
  console.log(`Figures with fetch queries: ${activePlans.length}`);
  console.log(`Disabled skips: ${skippedDisabled}`);
  console.log(`No search term skips: ${skippedNoTerms}`);
  console.log(`Metadata searchTerms overrides: ${overrideCount}`);
  console.log('');
  console.log('Term count distribution');
  console.log('');

  /** @type {Record<number, number>} */
  const distribution = {};
  for (const plan of plans) {
    const count = plan.searchTerms.length;
    distribution[count] = (distribution[count] ?? 0) + 1;
  }

  for (const count of Object.keys(distribution)
    .map(Number)
    .sort((left, right) => left - right)) {
    console.log(`${count} term${count === 1 ? '' : 's'}: ${distribution[count]}`);
  }

  console.log('');
  console.log('Query duplication (planned)');
  console.log('');
  console.log(`Total queries (before dedupe): ${duplication.totalQueries}`);
  console.log(`Unique queries: ${duplication.uniqueQueries}`);
  console.log(`Duplicate query strings: ${duplication.duplicateQueries.length}`);
}

/**
 * @param {import('./_snapshot_fetch.mjs').FigureCompletedSalesFetch[]} fetches
 * @param {number} runtimeMs
 */
function printFetchSummary(fetches, runtimeMs) {
  const stats = summarizeFetchResults(fetches);

  console.log('');
  console.log('FETCH SUMMARY');
  console.log('');
  console.log(`Runtime ms: ${runtimeMs}`);
  console.log(`Total queries: ${stats.totalQueries}`);
  console.log(`Successful queries: ${stats.successfulQueries}`);
  console.log(`Failed queries: ${stats.failedQueries}`);
  console.log(`Rate-limited queries: ${stats.rateLimitedQueries}`);
  console.log(`Total retries: ${stats.totalRetries}`);
  console.log(`Average listings returned (per successful query): ${stats.averageListingsReturned.toFixed(2)}`);
  console.log(`Duplicate listings across queries (within figures): ${stats.duplicateListingsAcrossQueries}`);
}

async function main() {
  const options = parseCliOptions(process.argv);
  const config = readEbayConfig();
  const catalogSource = resolveCatalogSource({
    catalogSource: options.catalogSource,
  });
  const bundle = await loadCatalogBundleForSource(undefined, {
    catalogSource,
    strict: isCatalogStrict(),
  });

  if (bundle.catalogSource === 'firestore') {
    console.error(`Catalog source: Firestore (${bundle.catalogDataDir})`);
  } else if (bundle.catalogSource === 'seed_fallback') {
    console.error(
      'WARNING: catalog loaded from tools/seed (dev fallback). ' +
        'Production runs should use --catalog-source firestore (default).',
    );
  } else {
    console.error(`Catalog source: ${bundle.catalogDataDir} (${bundle.catalogSource})`);
  }
  console.error(
    `Catalog figures: ${bundle.figures.length}, series: ${bundle.series.length}`,
  );
  console.error('');

  const plans = buildFigureSearchPlans(bundle, {
    figureFilter: options.figureFilter,
    seriesFilter: options.seriesFilter,
    limit: options.limit,
  });

  if (plans.length === 0) {
    console.error('No figures matched the requested filters.');
    process.exit(1);
  }

  if (options.mode === 'dry-run') {
    console.error(
      `compute_snapshots: dry-run for ${plans.length} figure(s); search terms derived at runtime`,
    );
    console.error('');

    for (const plan of plans) {
      printFigureDryRun(plan);
    }

    printPlanSummary(plans);
    return;
  }

  if (config.fetchMode === 'live' && !ebayClientIdConfigured()) {
    console.error(
      'EBAY_CLIENT_ID not configured. Set functions/.env.blindbox-collection or use EBAY_FETCH_MODE=fixture / --dry-run.',
    );
    process.exit(1);
  }

  console.error(
    `compute_snapshots: fetch mode (${config.fetchMode}) for ${plans.length} figure(s)`,
  );
  console.error('');

  const startedAt = Date.now();
  /** @type {import('./_snapshot_fetch.mjs').FigureCompletedSalesFetch[]} */
  const fetches = [];
  /** @type {import('./_snapshot_document.mjs').SnapshotDocument[]} */
  const snapshots = [];

  const dataSource = config.fetchMode === 'fixture' ? 'fixture' : 'live';

  for (const plan of plans) {
    const fetchResult = await fetchFigureCompletedSales(plan, {
      fetchMode: config.fetchMode,
    });
    fetches.push(fetchResult);

    if (options.snapshotDebug) {
      if (fetchResult.skipped) {
        console.log('FIGURE:');
        console.log(fetchResult.plan.catalogFigureId);
        console.log('');
        console.log(`SKIP (${fetchResult.skipReason})`);
        console.log('');
        continue;
      }

      const figure = findFigureById(bundle, plan.catalogFigureId);
      if (!figure) {
        console.error(`Figure not found in catalog: ${plan.catalogFigureId}`);
        process.exit(1);
      }

      const pipeline = buildFigureSnapshot(
        fetchResult.listings,
        figure,
        bundle,
        { dataSource },
      );

      console.log(
        formatSnapshotDebug(
          plan.catalogFigureId,
          fetchResult.listings.length,
          pipeline,
        ),
      );
      console.log('');
      continue;
    }

    if (!fetchResult.skipped) {
      const figure = findFigureById(bundle, plan.catalogFigureId);
      if (figure) {
        const pipeline = buildFigureSnapshot(
          fetchResult.listings,
          figure,
          bundle,
          { dataSource },
        );
        snapshots.push(pipeline.document);
      }
    }

    const showDetailed =
      options.verbose ||
      options.figureFilter != null ||
      plans.length === 1;

    if (showDetailed) {
      console.log(formatFigureFetchDebug(fetchResult));
    } else {
      console.log(
        `${fetchResult.plan.catalogFigureId}: ${fetchResult.skipped ? `SKIP (${fetchResult.skipReason})` : `${fetchResult.listings.length} unique listings from ${fetchResult.queryResults.length} queries`}`,
      );
    }
  }

  printPlanSummary(plans);
  if (!options.snapshotDebug) {
    printFetchSummary(fetches, Date.now() - startedAt);
  }

  if (options.pushFirestore) {
    if (snapshots.length === 0) {
      console.error('No snapshots to push (all figures skipped or no data).');
      process.exit(0);
    }

    console.error('');
    console.error(`Pushing ${snapshots.length} snapshot(s) to Firestore...`);

    const result = await pushSnapshotsToFirestore(snapshots, {
      dryRun: options.mode === 'dry-run',
    });

    if (result.failed > 0) {
      console.error(`${result.failed} batch write(s) failed.`);
      process.exit(1);
    }
  }
}

main();

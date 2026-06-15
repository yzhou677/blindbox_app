import assert from 'node:assert/strict';
import { describe, test } from 'node:test';

import {
  buildCatalogContextForFigure,
  findFigureById,
  loadCatalogBundle,
} from './_catalog_bundle.mjs';
import { deriveSearchTerms } from './_search_term_derivation.mjs';
import {
  SnapshotSkipReason,
  analyzeQueryDuplication,
  buildDryRunFetchSteps,
  buildFigureSearchPlanById,
} from './_snapshot_search.mjs';

const FIGURE_LUCK = 'the_monsters_big_into_energy_vinyl_plush_pendant_luck';
const FIGURE_SISI = 'the_monsters_have_a_seat_vinyl_plush_sisi';
const FIGURE_ID = 'the_monsters_big_into_energy_vinyl_plush_pendant_id';

describe('buildFigureSearchPlanById — integration', () => {
  const bundle = loadCatalogBundle();

  test('Luck uses metadata searchTerms override until migration', () => {
    const plan = buildFigureSearchPlanById(bundle, FIGURE_LUCK);

    assert.ok(plan);
    assert.equal(plan.metadataKey, 'lucky_big_into_energy_popmart');
    assert.equal(plan.usesSearchTermsOverride, true);
    assert.deepEqual(plan.searchTerms, [
      'POP MART Lucky Big Into Energy',
      'POPMART LUCKY BIG ENERGY',
    ]);
    assert.equal(plan.skipReason, null);
  });

  test('SISI derives two Tier 1 search terms with no metadata entry', () => {
    const plan = buildFigureSearchPlanById(bundle, FIGURE_SISI);

    assert.ok(plan);
    assert.equal(plan.metadataKey, null);
    assert.equal(plan.usesSearchTermsOverride, false);
    assert.deepEqual(plan.searchTerms, [
      'POP MART Labubu Have a Seat SISI',
      'POPMART Labubu Have a Seat SISI',
    ]);
    assert.equal(plan.skipReason, null);
  });

  test('Id secret derives Tier 1 plus secret helper', () => {
    const plan = buildFigureSearchPlanById(bundle, FIGURE_ID);

    assert.ok(plan);
    assert.deepEqual(plan.searchTerms, [
      'POP MART Labubu Big into Energy Id',
      'POPMART Labubu Big into Energy Id',
      'POP MART Labubu Big into Energy Id secret',
    ]);
    assert.equal(plan.skipReason, null);
  });

  test('deriveSearchTerms via catalog joins matches direct fixture call for SISI', () => {
    const figure = findFigureById(bundle, FIGURE_SISI);
    const catalogContext = buildCatalogContextForFigure(figure, bundle);
    const direct = deriveSearchTerms(figure, catalogContext, {});
    const plan = buildFigureSearchPlanById(bundle, FIGURE_SISI);

    assert.deepEqual(plan.searchTerms, direct);
  });
});

describe('buildDryRunFetchSteps', () => {
  const bundle = loadCatalogBundle();

  test('maps derived terms to fetch steps', () => {
    const plan = buildFigureSearchPlanById(bundle, FIGURE_SISI);
    const steps = buildDryRunFetchSteps(plan);

    assert.equal(steps.length, 2);
    assert.equal(steps[0].step, 'fetch_query');
    assert.match(steps[0].pipeline, /deriveSearchTerms/);
    assert.equal(steps[0].query, plan.searchTerms[0]);
  });

  test('records skip reason when search terms are empty', () => {
    const plan = buildFigureSearchPlanById(bundle, FIGURE_SISI);
    const disabledPlan = {
      ...plan,
      searchTerms: [],
      skipReason: SnapshotSkipReason.DISABLED,
    };

    assert.deepEqual(buildDryRunFetchSteps(disabledPlan), [
      {
        step: 'skip',
        catalogFigureId: FIGURE_SISI,
        skipReason: SnapshotSkipReason.DISABLED,
      },
    ]);
  });
});

describe('analyzeQueryDuplication', () => {
  test('detects duplicate query strings across figures', () => {
    const plans = [
      {
        catalogFigureId: 'a',
        skipReason: null,
        searchTerms: ['POP MART Labubu Series One Figure A'],
      },
      {
        catalogFigureId: 'b',
        skipReason: null,
        searchTerms: ['POP MART Labubu Series One Figure A'],
      },
    ];

    const analysis = analyzeQueryDuplication(plans);
    assert.equal(analysis.totalQueries, 2);
    assert.equal(analysis.uniqueQueries, 1);
    assert.equal(analysis.duplicateQueries.length, 1);
  });
});

import assert from 'node:assert/strict';
import { describe, test } from 'node:test';

import { findFigureById, loadCatalogBundle } from './_catalog_bundle.mjs';
import {
  BIG_INTO_ENERGY_SERIES_ID,
  CoverageClass,
  auditCatalogCoverage,
  auditFigureCoverage,
} from './_catalog_coverage_audit.mjs';

describe('auditFigureCoverage', () => {
  const bundle = loadCatalogBundle();

  test('classifies Big Into Energy Luck as MATCHABLE', () => {
    const figure = findFigureById(
      bundle,
      'the_monsters_big_into_energy_vinyl_plush_pendant_luck',
    );
    const record = auditFigureCoverage(figure, bundle);

    assert.equal(record.classification, CoverageClass.MATCHABLE);
    assert.ok(record.searchTerms.length > 0);
    assert.equal(record.matcherRisks.length, 0);
    assert.ok(record.matcherWarnings.length > 0);
  });

  test('classifies Have a Seat SISI as MATCHABLE after generalization', () => {
    const figure = findFigureById(
      bundle,
      'the_monsters_have_a_seat_vinyl_plush_sisi',
    );
    const record = auditFigureCoverage(figure, bundle);

    // "Have a Seat" distinctive is 11 chars (safe >= 8) — no structural blocker
    assert.equal(record.classification, CoverageClass.MATCHABLE);
    assert.equal(record.matcherRisks.length, 0);
    // SISI is 4 chars, single token, no market aliases → ambiguousFigureName warning
    assert.ok(
      record.matcherWarnings.some((w) => w.code === 'ambiguousFigureName'),
    );
  });
});

describe('auditCatalogCoverage', () => {
  test('covers full catalog with expected Big Into Energy matchable set', () => {
    const audit = auditCatalogCoverage();
    const bigIntoEnergy = audit.figures.filter(
      (record) => record.seriesId === BIG_INTO_ENERGY_SERIES_ID,
    );

    assert.equal(audit.totalFigures, 1144);
    assert.equal(bigIntoEnergy.length, 7);
    assert.equal(
      bigIntoEnergy.filter(
        (record) => record.classification === CoverageClass.MATCHABLE,
      ).length,
      7,
    );
  });
});

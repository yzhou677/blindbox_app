import assert from 'node:assert/strict';
import { describe, test } from 'node:test';

import {
  DEFAULT_VALIDATION_SAMPLE,
  ProductionReadiness,
  ValidationStatus,
  aggregateRejectReasons,
  buildSearchTermReview,
  classifyFigureValidationStatus,
  detectSearchTermIssues,
  formatValidationReportMarkdown,
  runSnapshotValidationAudit,
  serializeValidationAuditJson,
  validateFirestorePayload,
  validateSnapshotDocumentShape,
} from './_snapshot_validation_audit.mjs';
import { buildFirestoreDocument } from './push_market_snapshots.mjs';

describe('detectSearchTermIssues', () => {
  test('flags empty and duplicate queries', () => {
    const issues = detectSearchTermIssues([
      'POP MART Lucky Big Into Energy',
      '',
      'pop mart lucky big into energy',
    ]);

    assert.ok(issues.some((issue) => issue.code === 'empty_query'));
    assert.ok(issues.some((issue) => issue.code === 'duplicate_query'));
  });

  test('flags short queries as unexpected truncation', () => {
    const issues = detectSearchTermIssues(['POP']);
    assert.ok(issues.some((issue) => issue.code === 'unexpected_truncation'));
  });
});

describe('aggregateRejectReasons', () => {
  test('counts reject reasons and sorts by frequency', () => {
    const rows = aggregateRejectReasons([
      {
        listing: { itemId: '1', title: 'A', soldPriceUsd: 10, soldDate: null, listingUrl: null },
        reason: 'noMatch',
        rejectReason: 'productTypeReject',
      },
      {
        listing: { itemId: '2', title: 'B', soldPriceUsd: 10, soldDate: null, listingUrl: null },
        reason: 'noMatch',
        rejectReason: 'seriesMismatch',
      },
      {
        listing: { itemId: '3', title: 'C', soldPriceUsd: 10, soldDate: null, listingUrl: null },
        reason: 'noMatch',
        rejectReason: 'productTypeReject',
      },
      {
        listing: { itemId: '4', title: 'D', soldPriceUsd: 10, soldDate: null, listingUrl: null },
        reason: 'excluded',
      },
    ]);

    assert.deepEqual(rows, [
      { reason: 'productTypeReject', count: 2 },
      { reason: 'seriesMismatch', count: 1 },
      { reason: 'excluded', count: 1 },
    ]);
  });
});

describe('validateSnapshotDocumentShape', () => {
  test('detects missing required fields', () => {
    const result = validateSnapshotDocumentShape({
      figureId: 'fig',
      seriesId: '',
      snapshotAt: '2026-06-15T00:00:00.000Z',
      sampleSize: 1,
      averagePrice: 10,
      medianPrice: 10,
      minPrice: 10,
      maxPrice: 10,
      confidence: 'low',
      dataSource: 'fixture',
    });

    assert.equal(result.malformed, true);
    assert.ok(result.missingFields.includes('seriesId (empty)'));
  });
});

describe('validateFirestorePayload', () => {
  test('skips when median price is null', () => {
    const snapshot = {
      figureId: 'fig',
      seriesId: 'series',
      snapshotAt: '2026-06-15T00:00:00.000Z',
      sampleSize: 0,
      averagePrice: null,
      medianPrice: null,
      minPrice: null,
      maxPrice: null,
      confidence: 'low',
      dataSource: 'fixture',
    };

    const result = validateFirestorePayload(snapshot, buildFirestoreDocument(snapshot));
    assert.equal(result.skipped, true);
    assert.equal(result.skipReason, 'medianPrice null');
    assert.equal(result.malformed, false);
  });

  test('validates required Firestore fields when writable', () => {
    const snapshot = {
      figureId: 'the_monsters_big_into_energy_vinyl_plush_pendant_luck',
      seriesId: 'the_monsters_big_into_energy_vinyl_plush_pendant',
      snapshotAt: '2026-06-15T00:00:00.000Z',
      sampleSize: 2,
      averagePrice: 39.75,
      medianPrice: 39.75,
      minPrice: 39.5,
      maxPrice: 40,
      confidence: 'low',
      dataSource: 'fixture',
    };

    const mapped = buildFirestoreDocument(snapshot);
    const result = validateFirestorePayload(snapshot, mapped);

    assert.equal(result.skipped, false);
    assert.equal(result.malformed, false);
    assert.equal(result.docId, snapshot.figureId);
    assert.equal(result.fields?.estimatedValueUsd, 39.75);
    assert.equal(result.fields?.confidence, 'low');
    assert.equal(result.fields?.recentSalesCount, 2);
    assert.ok(result.fields?.computedAt);
  });
});

describe('runSnapshotValidationAudit', () => {
  test('handles empty sample', async () => {
    const audit = await runSnapshotValidationAudit({
      figureIds: [],
      generatedAt: '2026-06-15T00:00:00.000Z',
    });

    assert.equal(audit.sampleSize, 0);
    assert.equal(audit.status, ValidationStatus.PASS);
    assert.equal(
      audit.productionReadiness,
      ProductionReadiness.READY_FOR_LIVE_DATA_SOURCE,
    );
    assert.deepEqual(audit.counts, { PASS: 0, WARNING: 0, FAIL: 0 });
  });

  test('generates markdown and JSON report for fixture sample', async () => {
    const audit = await runSnapshotValidationAudit({
      figureIds: [
        'the_monsters_big_into_energy_vinyl_plush_pendant_luck',
        'the_monsters_have_a_seat_vinyl_plush_sisi',
      ],
      fetchMode: 'fixture',
      generatedAt: '2026-06-15T00:00:00.000Z',
    });

    assert.equal(audit.sampleSize, 2);
    assert.ok(audit.figures.length === 2);
    assert.ok(audit.matcherReview.length === 2);
    assert.ok(typeof audit.firestoreReview.writable === 'number');

    const markdown = formatValidationReportMarkdown(audit);
    assert.ok(markdown.includes('Section 1 — Summary'));
    assert.ok(markdown.includes('Section 6 — Production Readiness Recommendation'));

    const json = serializeValidationAuditJson(audit);
    assert.equal(json.sampleSize, 2);
    assert.ok(Array.isArray(json.figures));
    assert.ok(Array.isArray(json.warnings));
    assert.ok(Array.isArray(json.failures));
  });
});

describe('classifyFigureValidationStatus', () => {
  test('FAIL beats WARNING', () => {
    const status = classifyFigureValidationStatus({
      failures: ['broken'],
      warnings: ['warn'],
    });
    assert.equal(status, ValidationStatus.FAIL);
  });
});

describe('buildSearchTermReview', () => {
  test('aggregates issue counts across figures', () => {
    const review = buildSearchTermReview([
      {
        searchTerms: ['POP MART Lucky', 'pop mart lucky'],
        searchTermIssues: [{ code: 'duplicate_query', message: 'dup' }],
      },
      {
        searchTerms: ['POP MART'],
        searchTermIssues: [{ code: 'unexpected_truncation', message: 'short' }],
      },
    ]);

    assert.equal(review.searchTermIssueSummary.duplicate_query, 1);
    assert.equal(review.searchTermIssueSummary.unexpected_truncation, 1);
    assert.ok(review.duplicateQueries.length >= 0);
  });
});

describe('DEFAULT_VALIDATION_SAMPLE', () => {
  test('includes 15 figures across required categories', () => {
    assert.equal(DEFAULT_VALIDATION_SAMPLE.length, 15);
    assert.ok(
      DEFAULT_VALIDATION_SAMPLE.includes(
        'the_monsters_big_into_energy_vinyl_plush_pendant_luck',
      ),
    );
    assert.ok(
      DEFAULT_VALIDATION_SAMPLE.includes('the_monsters_have_a_seat_vinyl_plush_sisi'),
    );
    assert.ok(
      DEFAULT_VALIDATION_SAMPLE.includes('nanci_poetic_beauty_shy_lotus'),
    );
  });
});

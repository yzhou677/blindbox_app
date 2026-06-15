import assert from 'node:assert/strict';
import { describe, test } from 'node:test';

import { findFigureById, loadCatalogBundle } from './_catalog_bundle.mjs';
import {
  buildFigureSnapshot,
  buildSnapshotDocument,
} from './_snapshot_document.mjs';
import { aggregateSales } from './_sales_aggregator.mjs';

const FIGURE_LUCK = 'the_monsters_big_into_energy_vinyl_plush_pendant_luck';

const figureSisi = {
  id: 'the_monsters_have_a_seat_vinyl_plush_sisi',
  displayName: 'SISI',
};

describe('buildSnapshotDocument', () => {
  test('creates snapshot document from aggregation', () => {
    const aggregation = aggregateSales([
      {
        itemId: '1',
        title: 'POP MART Labubu Have a Seat SISI Vinyl Plush',
        soldPriceUsd: 38.5,
        soldDate: '2025-05-01T00:00:00.000Z',
        listingUrl: null,
      },
      {
        itemId: '2',
        title: 'POPMART Have a Seat SISI Vinyl Plush',
        soldPriceUsd: 41,
        soldDate: '2025-05-03T00:00:00.000Z',
        listingUrl: null,
      },
    ]);

    const document = buildSnapshotDocument(figureSisi, aggregation, {
      snapshotAt: '2026-06-15T00:00:00.000Z',
      dataSource: 'fixture',
    });

    assert.deepEqual(document, {
      figureId: figureSisi.id,
      snapshotAt: '2026-06-15T00:00:00.000Z',
      sampleSize: 2,
      averagePrice: 39.75,
      medianPrice: 39.75,
      minPrice: 38.5,
      maxPrice: 41,
      dataSource: 'fixture',
    });
  });

  test('uses defaults for empty aggregation', () => {
    const aggregation = aggregateSales([]);
    const document = buildSnapshotDocument(figureSisi, aggregation, {
      snapshotAt: '2026-06-15T00:00:00.000Z',
    });

    assert.equal(document.figureId, figureSisi.id);
    assert.equal(document.sampleSize, 0);
    assert.equal(document.averagePrice, null);
    assert.equal(document.medianPrice, null);
    assert.equal(document.dataSource, 'fixture');
  });
});

describe('buildFigureSnapshot — fixture pipeline', () => {
  const bundle = loadCatalogBundle();

  test('matches and aggregates Luck listings end-to-end', () => {
    const figure = findFigureById(bundle, FIGURE_LUCK);
    const pipeline = buildFigureSnapshot(
      [
        {
          itemId: 'luck-1',
          title: 'POP MART THE MONSTERS Luck Big Into Energy Vinyl Plush',
          soldPriceUsd: 30,
          soldDate: null,
          listingUrl: null,
        },
        {
          itemId: 'hope-1',
          title:
            'POP MART THE MONSTERS Big Into Energy Hope Vinyl Plush Figure',
          soldPriceUsd: 99,
          soldDate: null,
          listingUrl: null,
        },
      ],
      figure,
      bundle,
      {
        snapshotAt: '2026-06-15T00:00:00.000Z',
        dataSource: 'fixture',
      },
    );

    assert.equal(pipeline.matchResult.stats.matched, 1);
    assert.equal(pipeline.aggregation.sampleSize, 1);
    assert.equal(pipeline.aggregation.medianPrice, 30);
    assert.equal(pipeline.document.figureId, FIGURE_LUCK);
    assert.equal(pipeline.document.dataSource, 'fixture');
  });
});

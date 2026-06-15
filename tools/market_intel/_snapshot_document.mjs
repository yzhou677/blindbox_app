/**
 * Market Intelligence — snapshot document builder (in-memory only).
 */

import { aggregateSales } from './_sales_aggregator.mjs';
import { matchListingsToFigure } from './_snapshot_match.mjs';

/**
 * @typedef {import('./_sales_aggregator.mjs').SalesAggregation} SalesAggregation
 * @typedef {import('./_snapshot_fetch.mjs').CompletedSaleListing} CompletedSaleListing
 * @typedef {import('./_snapshot_match.mjs').ListingMatchResult} ListingMatchResult
 */

/**
 * @typedef {Object} SnapshotDocument
 * @property {string} figureId
 * @property {string} snapshotAt
 * @property {number} sampleSize
 * @property {number | null} averagePrice
 * @property {number | null} medianPrice
 * @property {number | null} minPrice
 * @property {number | null} maxPrice
 * @property {string} dataSource
 */

/**
 * @typedef {Object} SnapshotDocumentMetadata
 * @property {string} [snapshotAt]
 * @property {string} [dataSource]
 */

/**
 * @typedef {Object} FigureSnapshotPipelineResult
 * @property {ListingMatchResult} matchResult
 * @property {SalesAggregation} aggregation
 * @property {SnapshotDocument} document
 */

/**
 * @param {object} figure
 * @param {SalesAggregation} aggregation
 * @param {SnapshotDocumentMetadata} [metadata]
 * @returns {SnapshotDocument}
 */
export function buildSnapshotDocument(figure, aggregation, metadata = {}) {
  return {
    figureId: figure.id,
    snapshotAt: metadata.snapshotAt ?? new Date().toISOString(),
    sampleSize: aggregation.sampleSize,
    averagePrice: aggregation.averagePrice,
    medianPrice: aggregation.medianPrice,
    minPrice: aggregation.minPrice,
    maxPrice: aggregation.maxPrice,
    dataSource: metadata.dataSource ?? 'fixture',
  };
}

/**
 * @param {readonly CompletedSaleListing[]} listings
 * @param {object} figure
 * @param {import('./_catalog_bundle.mjs').ReturnType<typeof import('./_catalog_bundle.mjs').loadCatalogBundle>} catalogBundle
 * @param {SnapshotDocumentMetadata} [metadata]
 * @returns {FigureSnapshotPipelineResult}
 */
export function buildFigureSnapshot(
  listings,
  figure,
  catalogBundle,
  metadata = {},
) {
  const matchResult = matchListingsToFigure(listings, figure, catalogBundle);
  const aggregation = aggregateSales(matchResult.matchedListings);
  const document = buildSnapshotDocument(figure, aggregation, metadata);

  return {
    matchResult,
    aggregation,
    document,
  };
}

/**
 * @param {string} figureId
 * @param {number} fetchedCount
 * @param {FigureSnapshotPipelineResult} pipeline
 */
export function formatSnapshotDebug(figureId, fetchedCount, pipeline) {
  const lines = [];

  lines.push('FIGURE:');
  lines.push(figureId);
  lines.push('');
  lines.push('FETCHED:');
  lines.push(String(fetchedCount));
  lines.push('');
  lines.push('MATCHED:');
  lines.push(String(pipeline.matchResult.stats.matched));
  lines.push('');
  lines.push('MEDIAN:');
  lines.push(
    pipeline.aggregation.medianPrice == null
      ? '(none)'
      : String(pipeline.aggregation.medianPrice),
  );
  lines.push('');
  lines.push('AVERAGE:');
  lines.push(
    pipeline.aggregation.averagePrice == null
      ? '(none)'
      : String(pipeline.aggregation.averagePrice),
  );
  lines.push('');
  lines.push('SNAPSHOT:');
  lines.push(JSON.stringify(pipeline.document, null, 2));

  return lines.join('\n');
}

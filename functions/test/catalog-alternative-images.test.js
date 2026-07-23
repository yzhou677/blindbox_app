'use strict';

const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const { Timestamp } = require('@google-cloud/firestore');
const { IMAGE_EMBEDDING_CONFIG } = require('../lib/figureRecognition/imageEmbeddingConfig');
const { CatalogEmbeddingJob } = require('../lib/figureRecognition/catalogEmbeddingJob');
const {
  alternativeEmbeddingDocumentId,
  primaryEmbeddingDocumentId,
} = require('../lib/figureRecognition/catalogEmbeddingIds');
const { parseAlternativeImages } = require('../lib/figureRecognition/catalogAlternativeImages');
const { aggregateFigureCandidates } = require('../lib/figureRecognition/figureCandidateAggregation');
const { FigureRetrievalService } = require('../lib/figureRecognition/figureRetrievalService');
const { FirestoreFigureVectorSearch } = require('../lib/figureRecognition/figureVectorSearch');

const space = IMAGE_EMBEDDING_CONFIG.embeddingSpace;

const figure = (overrides = {}) => ({
  figureId: 'fig-1',
  seriesId: 'series-1',
  brandId: 'brand-1',
  ipId: 'ip-1',
  isSecret: false,
  imageKey: 'fig-1',
  alternativeImages: [],
  catalogModifiedAt: Timestamp.fromMillis(1000),
  ...overrides,
});

function compatible(data = {}) {
  return {
    hasNativeVector: true,
    vector: Array(1024).fill(0.1),
    data: {
      figureId: 'fig-1',
      seriesId: 'series-1',
      brandId: 'brand-1',
      ipId: 'ip-1',
      isSecret: false,
      imageObjectPath: 'fig-1.webp',
      contentHash: 'fcc6824d4f99b1b5b6011e00c9b3db91555e6d2d8aab66693bc3a324c437bc6c',
      embeddingSpace: space,
      embeddingModel: IMAGE_EMBEDDING_CONFIG.model,
      embeddingLocation: IMAGE_EMBEDDING_CONFIG.location,
      embeddingDimension: 1024,
      embeddingVersion: IMAGE_EMBEDDING_CONFIG.version,
      catalogModifiedAt: Timestamp.fromMillis(1000),
      ...data,
    },
  };
}

function harness({ figures = [figure()], existingById = {}, imageBytes = Buffer.from('same-image') } = {}) {
  const calls = { embeds: 0, writes: [], metadata: [], deletes: [], resolveKeys: [] };
  const source = {
    async get(id) { return figures.find((item) => item.figureId === id) ?? null; },
    async *pages() { yield figures; },
  };
  const images = {
    async resolve(imageKey) {
      calls.resolveKeys.push(imageKey);
      return { objectPath: `${imageKey}.webp`, bytes: imageBytes, mimeType: 'image/webp' };
    },
  };
  const store = {
    async get(documentId) { return existingById[documentId] ?? null; },
    async writeEmbedding(metadata, vector, isNew) { calls.writes.push({ metadata, vector, isNew }); },
    async updateMetadata(metadata) { calls.metadata.push(metadata); },
    async listDocumentIdsForFigure(figureId) {
      return Object.keys(existingById)
        .filter((id) => id === figureId || id.startsWith(`${figureId}__alt__`))
        .sort();
    },
    async deleteAlternativeDocument(documentId) { calls.deletes.push(documentId); },
  };
  const provider = {
    async embedStoredImage() {
      calls.embeds++;
      return { vector: Array(1024).fill(0.25) };
    },
  };
  const job = new CatalogEmbeddingJob(source, images, store, provider, () => {}, () => 0);
  return { job, calls, store };
}

const match = (overrides = {}) => ({
  figureId: 'figure-a',
  seriesId: 'series-1',
  brandId: 'brand-1',
  ipId: 'ip-1',
  isSecret: false,
  embeddingSpace: space,
  distance: 0.2,
  ...overrides,
});

describe('alternativeImages parsing', () => {
  it('defaults missing alternatives to an empty list', () => {
    assert.deepEqual(parseAlternativeImages(undefined), []);
    assert.deepEqual(parseAlternativeImages(null), []);
    assert.deepEqual(parseAlternativeImages('nope'), []);
  });

  it('keeps only non-empty deterministic imageKey/variant pairs', () => {
    assert.deepEqual(parseAlternativeImages([
      { imageKey: ' a ', variant: ' top_view ' },
      { imageKey: '', variant: 'side_view' },
      { imageKey: 'dup', variant: 'a' },
      { imageKey: 'dup', variant: 'b' },
      { imageKey: 'ok', variant: '' },
    ]), [
      { imageKey: 'a', variant: 'top_view' },
      { imageKey: 'dup', variant: 'a' },
    ]);
  });
});

describe('legacy embedding behavior', () => {
  it('produces exactly one primary embedding with the current primary document id', async () => {
    const { job, calls } = harness();
    const summary = await job.run({});
    assert.equal(summary.embedded, 1);
    assert.equal(calls.embeds, 1);
    assert.equal(calls.writes.length, 1);
    assert.equal(calls.writes[0].metadata.documentId, primaryEmbeddingDocumentId('fig-1'));
    assert.equal(calls.writes[0].metadata.imageRole, 'primary');
    assert.equal(calls.writes[0].metadata.variant, 'front');
    assert.equal(calls.writes[0].metadata.imageKey, 'fig-1');
  });

  it('does not trigger alternative embedding work for legacy figures', async () => {
    const { job, calls } = harness({ existingById: { 'fig-1': compatible() } });
    const summary = await job.run({});
    assert.equal(summary.skipped, 1);
    assert.equal(calls.embeds, 0);
    assert.deepEqual(calls.resolveKeys, ['fig-1']);
  });
});

describe('alternative embedding records', () => {
  it('creates one primary and one alternative with shared figureId', async () => {
    const { job, calls } = harness({
      figures: [figure({
        alternativeImages: [{ imageKey: 'fig-1_top_view', variant: 'top_view' }],
      })],
    });
    const summary = await job.run({});
    assert.equal(summary.embedded, 2);
    assert.equal(calls.embeds, 2);
    assert.deepEqual(calls.writes.map((row) => row.metadata.documentId).sort(), [
      'fig-1',
      alternativeEmbeddingDocumentId('fig-1', 'fig-1_top_view'),
    ].sort());
    const alt = calls.writes.find((row) => row.metadata.imageRole === 'alternative');
    assert.equal(alt.metadata.figureId, 'fig-1');
    assert.equal(alt.metadata.variant, 'top_view');
    assert.equal(alt.metadata.imageKey, 'fig-1_top_view');
  });

  it('creates one record per alternative without overwriting and stays idempotent', async () => {
    const fig = figure({
      alternativeImages: [
        { imageKey: 'fig-1_top_view', variant: 'top_view' },
        { imageKey: 'fig-1_side_view', variant: 'side_view' },
      ],
    });
    const first = harness({ figures: [fig] });
    assert.equal((await first.job.run({})).embedded, 3);
    assert.equal(first.calls.writes.length, 3);

    const existingById = Object.fromEntries(first.calls.writes.map((row) => [
      row.metadata.documentId,
      compatible({
        figureId: row.metadata.figureId,
        imageObjectPath: `${row.metadata.imageKey}.webp`,
        imageKey: row.metadata.imageKey,
        imageRole: row.metadata.imageRole,
        variant: row.metadata.variant,
        contentHash: require('node:crypto').createHash('sha256').update(Buffer.from('same-image')).digest('hex'),
      }),
    ]));
    const second = harness({ figures: [fig], existingById });
    const summary = await second.job.run({});
    assert.equal(summary.skipped, 3);
    assert.equal(second.calls.embeds, 0);
    assert.equal(second.calls.writes.length, 0);
  });
});

describe('stale alternative cleanup', () => {
  it('removes only the stale alternative and never the primary', async () => {
    const keepId = alternativeEmbeddingDocumentId('fig-1', 'fig-1_top_view');
    const staleId = alternativeEmbeddingDocumentId('fig-1', 'fig-1_old');
    const { job, calls } = harness({
      figures: [figure({
        alternativeImages: [{ imageKey: 'fig-1_top_view', variant: 'top_view' }],
      })],
      existingById: {
        'fig-1': compatible({ imageRole: 'primary', variant: 'front', imageKey: 'fig-1' }),
        [keepId]: compatible({
          imageObjectPath: 'fig-1_top_view.webp',
          imageRole: 'alternative',
          variant: 'top_view',
          imageKey: 'fig-1_top_view',
          contentHash: require('node:crypto').createHash('sha256').update(Buffer.from('same-image')).digest('hex'),
        }),
        [staleId]: compatible({
          imageObjectPath: 'fig-1_old.webp',
          imageRole: 'alternative',
          variant: 'old',
          imageKey: 'fig-1_old',
        }),
      },
    });
    const summary = await job.run({ pruneStaleAlternatives: true });
    assert.deepEqual(calls.deletes, [staleId]);
    assert.equal(summary.staleAlternativesDeleted, 1);
    assert.ok(!calls.deletes.includes('fig-1'));
  });

  it('dry-run reports stale alternatives without deleting', async () => {
    const staleId = alternativeEmbeddingDocumentId('fig-1', 'fig-1_old');
    const { job, calls } = harness({
      figures: [figure()],
      existingById: {
        'fig-1': compatible(),
        [staleId]: compatible({ imageRole: 'alternative', imageKey: 'fig-1_old' }),
      },
    });
    const summary = await job.run({ pruneStaleAlternatives: true, pruneDryRun: true });
    assert.deepEqual(calls.deletes, []);
    assert.equal(summary.staleAlternativesWouldDelete, 1);
  });
});

describe('figure candidate aggregation', () => {
  it('is an identity transform for primary-only legacy matches', () => {
    const imageMatches = [
      match({ figureId: 'z', distance: 0.4 }),
      match({ figureId: 'b', distance: 0.1 }),
      match({ figureId: 'a', distance: 0.1 }),
    ];
    const { candidates, stats } = aggregateFigureCandidates(imageMatches);
    assert.deepEqual(candidates.map(({ figureId, rank, distance }) => ({ figureId, rank, distance })), [
      { figureId: 'a', rank: 1, distance: 0.1 },
      { figureId: 'b', rank: 2, distance: 0.1 },
      { figureId: 'z', rank: 3, distance: 0.4 },
    ]);
    assert.deepEqual(Object.keys(candidates[0]).sort(), [
      'brandId', 'distance', 'embeddingSpace', 'figureId', 'ipId', 'isSecret', 'rank', 'seriesId',
    ].sort());
    assert.equal(stats.candidateImageCount, 3);
    assert.equal(stats.candidateFigureCount, 3);
    assert.equal(stats.alternativeMatchCount, 0);
  });

  it('lets an alternative win and deduplicates by figureId', () => {
    const { candidates, stats } = aggregateFigureCandidates([
      match({
        figureId: 'figure-a', distance: 0.39, imageRole: 'primary', variant: 'front', matchedImageKey: 'a',
      }),
      match({
        figureId: 'figure-b', distance: 0.33, imageRole: 'primary', variant: 'front', matchedImageKey: 'b',
      }),
      match({
        figureId: 'figure-a', distance: 0.07, imageRole: 'alternative', variant: 'top_view', matchedImageKey: 'a_top',
      }),
      match({
        figureId: 'figure-a', distance: 0.20, imageRole: 'alternative', variant: 'side_view', matchedImageKey: 'a_side',
      }),
    ]);
    // cosine distance: 0.07 ≈ similarity 0.93, 0.33 ≈ 0.67, 0.39 ≈ 0.61
    assert.equal(candidates[0].figureId, 'figure-a');
    assert.equal(candidates[0].distance, 0.07);
    assert.equal(candidates[0].imageRole, 'alternative');
    assert.equal(candidates[0].variant, 'top_view');
    assert.equal(candidates[0].matchedImageKey, 'a_top');
    assert.equal(candidates[1].figureId, 'figure-b');
    assert.equal(candidates.length, 2);
    assert.equal(stats.alternativeMatchCount, 2);
    assert.equal(stats.winningImageRole, 'alternative');
    assert.equal(stats.winningVariant, 'top_view');
  });

  it('keeps the primary result when alternatives do not help', () => {
    const { candidates } = aggregateFigureCandidates([
      match({ figureId: 'figure-b', distance: 0.10, imageRole: 'primary', variant: 'front' }),
      match({ figureId: 'figure-a', distance: 0.20, imageRole: 'primary', variant: 'front' }),
      match({ figureId: 'figure-a', distance: 0.25, imageRole: 'alternative', variant: 'top_view' }),
    ]);
    assert.deepEqual(candidates.map((row) => row.figureId), ['figure-b', 'figure-a']);
    assert.equal(candidates[0].imageRole, 'primary');
  });
});

describe('single-query recognition path', () => {
  it('embeds once, searches once, and matches legacy results with no alternatives', async () => {
    const vector = Array(1024).fill(0.25);
    let embedCalls = 0;
    let searchCalls = 0;
    const legacyRows = [
      {
        figureId: 'a', seriesId: 's', brandId: 'b', ipId: 'i', isSecret: false,
        embeddingSpace: space, _vectorDistance: 0.1,
      },
      {
        figureId: 'b', seriesId: 's', brandId: 'b', ipId: 'i', isSecret: false,
        embeddingSpace: space, _vectorDistance: 0.2,
      },
    ];
    const firestore = {
      collection(name) {
        assert.equal(name, 'catalogFigureEmbeddings');
        return {
          where(...args) {
            assert.deepEqual(args, ['embeddingSpace', '==', space]);
            return {
              findNearest(options) {
                searchCalls++;
                assert.equal(options.limit, 5);
                return {
                  async get() {
                    return { docs: legacyRows.map((data) => ({ data: () => data })) };
                  },
                };
              },
            };
          },
        };
      },
    };
    const service = new FigureRetrievalService(
      { async read() { throw new Error('unused'); } },
      { async embedStoredImage() { embedCalls++; return { vector }; } },
      new FirestoreFigureVectorSearch(firestore),
    );
    const before = await service.retrieveStoredImageWithDiagnostics(
      { bytes: Buffer.from('x'), mimeType: 'image/jpeg' },
      5,
    );
    const after = await service.retrieveStoredImageWithDiagnostics(
      { bytes: Buffer.from('x'), mimeType: 'image/jpeg' },
      5,
    );
    assert.equal(embedCalls, 2);
    assert.equal(searchCalls, 2);
    assert.equal(before.diagnostics.vectorSearchCalls, 1);
    assert.equal(before.diagnostics.userEmbeddingCalls, 1);
    assert.equal(before.diagnostics.alternativeMatchCount, 0);
    assert.deepEqual(
      before.candidates.map(({ figureId, rank, distance }) => ({ figureId, rank, distance })),
      after.candidates.map(({ figureId, rank, distance }) => ({ figureId, rank, distance })),
    );
    assert.deepEqual(Object.keys(before.candidates[0]).sort(), [
      'brandId', 'distance', 'embeddingSpace', 'figureId', 'ipId', 'isSecret', 'rank', 'seriesId',
    ].sort());
  });
});

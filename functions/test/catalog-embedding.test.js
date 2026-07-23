'use strict';

const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const { Timestamp, VectorValue } = require('@google-cloud/firestore');
const { IMAGE_EMBEDDING_CONFIG } = require('../lib/figureRecognition/imageEmbeddingConfig');
const { FirebaseCatalogImageResolver } = require('../lib/figureRecognition/catalogImageResolver');
const { FirestoreCatalogEmbeddingStore } = require('../lib/figureRecognition/catalogEmbeddingStore');
const { CatalogEmbeddingJob, withTransientRetries } = require('../lib/figureRecognition/catalogEmbeddingJob');
const { parseCatalogEmbeddingArgs, createStartupDiagnostic } = require('../lib/figureRecognition/catalogEmbeddingCli');

const figure = (overrides = {}) => ({
  figureId: 'fig-1', seriesId: 'series-1', brandId: 'brand-1', ipId: 'ip-1', isSecret: false,
  imageKey: 'fig-1', alternativeImages: [], catalogModifiedAt: Timestamp.fromMillis(1000), ...overrides,
});

function harness({ existing = null, figures = [figure()], image = Buffer.from('same-image'), embedError, existingById } = {}) {
  const calls = { embeds: 0, writes: [], metadata: [], logs: [], deletes: [], listed: [] };
  const source = {
    async get(id) { return figures.find((item) => item.figureId === id) ?? null; },
    async *pages() { yield figures; },
  };
  const images = { async resolve(imageKey) { return { objectPath: `${imageKey}.webp`, bytes: image, mimeType: 'image/webp' }; } };
  const store = {
    async get(documentId) {
      if (existingById && Object.prototype.hasOwnProperty.call(existingById, documentId)) {
        return existingById[documentId];
      }
      return existing;
    },
    async writeEmbedding(metadata, vector, isNew) { calls.writes.push({ metadata, vector, isNew }); },
    async updateMetadata(metadata) { calls.metadata.push(metadata); },
    async listDocumentIdsForFigure(figureId) {
      calls.listed.push(figureId);
      if (existingById) {
        return Object.keys(existingById).filter((id) => id === figureId || id.startsWith(`${figureId}__alt__`)).sort();
      }
      return existing ? [figureId] : [];
    },
    async deleteAlternativeDocument(documentId) { calls.deletes.push(documentId); },
  };
  const provider = { async embedStoredImage() { calls.embeds++; if (embedError) throw embedError; return { vector: Array(1024).fill(0.25) }; } };
  const job = new CatalogEmbeddingJob(source, images, store, provider, (entry) => calls.logs.push(entry), (() => { let n = 0; return () => n += 5; })());
  return { job, calls };
}

function compatible(data = {}, vector = Array(1024).fill(0.1)) {
  return { hasNativeVector: true, vector, data: {
    figureId: 'fig-1', seriesId: 'series-1', brandId: 'brand-1', ipId: 'ip-1', isSecret: false,
    imageObjectPath: 'fig-1.webp', contentHash: 'fcc6824d4f99b1b5b6011e00c9b3db91555e6d2d8aab66693bc3a324c437bc6c',
    embeddingSpace: IMAGE_EMBEDDING_CONFIG.embeddingSpace, embeddingModel: IMAGE_EMBEDDING_CONFIG.model,
    embeddingLocation: IMAGE_EMBEDDING_CONFIG.location, embeddingDimension: 1024,
    embeddingVersion: IMAGE_EMBEDDING_CONFIG.version, catalogModifiedAt: Timestamp.fromMillis(1000), ...data,
  } };
}

describe('CatalogEmbeddingJob', () => {
  it('treats no arguments as full-catalog mode and enumerates every available figure', async () => {
    const figures = [figure(), figure({ figureId: 'fig-2' }), figure({ figureId: 'fig-3' })];
    const { job, calls } = harness({ figures });
    const plan = await job.plan(parseCatalogEmbeddingArgs([]));
    assert.equal(plan.summary.totalFigures, 3);
    assert.equal(plan.summary.requiresEmbedding, 3);
    assert.equal(calls.embeds, 0);
    assert.equal(calls.writes.length, 0);
  });

  it('emits sanitized planning progress every 25 figures', async () => {
    const figures = Array.from({ length: 50 }, (_, index) => figure({
      figureId: `fig-${index + 1}`,
      imageKey: `fig-${index + 1}`,
    }));
    const { job, calls } = harness({ figures });
    const progress = [];
    await job.plan({}, 0.00012, (entry) => progress.push(entry));
    assert.deepEqual(progress.map((entry) => entry.processed), [25, 50]);
    assert.ok(progress.every((entry) => entry.total === undefined));
    assert.deepEqual(progress[1], {
      processed: 50,
      alreadyUpToDate: 0,
      metadataOnlyUpdates: 0,
      requiresEmbedding: 50,
      missingImages: 0,
      failed: 0,
      elapsedMs: progress[1].elapsedMs,
    });
    assert.equal(calls.embeds, 0);
    assert.equal(calls.writes.length, 0);
    assert.doesNotMatch(JSON.stringify(progress), /same-image|contentHash|vector|token|https?:/);
  });

  it('plans API calls and cost without embedding or Firestore writes', async () => {
    const { job, calls } = harness({ figures: [figure(), figure({ figureId: 'fig-2' })] });
    const plan = await job.plan({ limit: 2 }, 0.5);
    assert.deepEqual(plan.summary, {
      totalFigures: 2, alreadyUpToDate: 0, metadataOnlyUpdates: 0, requiresEmbedding: 2,
      missingImages: 0, estimatedEmbeddingApiCalls: 2, estimatedAiCostUsd: 1,
      missingImageCount: 0, missingImageFigureIds: [], plannedImageRecords: 2,
    });
    assert.equal(calls.embeds, 0);
    assert.equal(calls.writes.length, 0);
    assert.equal(calls.metadata.length, 0);
  });

  it('writes a new 1024-dimensional embedding with the SHA-256 content hash', async () => {
    const { job, calls } = harness();
    const summary = await job.run({ limit: 1 });
    assert.equal(summary.embedded, 1);
    assert.equal(calls.writes[0].vector.length, 1024);
    assert.equal(calls.writes[0].metadata.contentHash, 'fcc6824d4f99b1b5b6011e00c9b3db91555e6d2d8aab66693bc3a324c437bc6c');
  });

  it('skips an unchanged compatible document on rerun', async () => {
    const { job, calls } = harness({ existing: compatible() });
    const summary = await job.run({});
    assert.equal(summary.skipped, 1);
    assert.equal(calls.embeds, 0);
  });

  it('updates identity metadata without a paid embedding call', async () => {
    const { job, calls } = harness({ existing: compatible({ brandId: 'old-brand' }) });
    const summary = await job.run({});
    assert.equal(summary.metadataUpdated, 1);
    assert.equal(calls.embeds, 0);
  });

  it('regenerates changed, missing, malformed, wrong-dimensional, and non-finite vectors', async () => {
    const cases = [
      compatible({ contentHash: 'changed' }),
      { hasNativeVector: false, vector: null, data: compatible().data },
      { hasNativeVector: false, vector: Array(1024).fill(1), data: compatible().data },
      compatible({}, [1]),
      compatible({}, [...Array(1023).fill(1), NaN]),
    ];
    for (const existing of cases) {
      const { job, calls } = harness({ existing });
      assert.equal((await job.run({})).embedded, 1);
      assert.equal(calls.embeds, 1);
    }
  });

  it('regenerates when any explicit embedding configuration field changes', async () => {
    for (const change of [
      { embeddingModel: 'old' }, { embeddingLocation: 'old' }, { embeddingDimension: 512 },
      { embeddingVersion: 'old' }, { embeddingSpace: 'old' },
    ]) {
      const { job, calls } = harness({ existing: compatible(change) });
      assert.equal((await job.run({})).embedded, 1);
      assert.equal(calls.embeds, 1);
    }
  });

  it('force regenerates and a failed figure does not stop later figures', async () => {
    const forced = harness({ existing: compatible() });
    assert.equal((await forced.job.run({ force: true })).embedded, 1);
    const base = harness({ figures: [figure(), figure({ figureId: 'fig-2', imageKey: 'fig-2' })] });
    let count = 0;
    base.job.provider = { async embedStoredImage() { count++; if (count === 1) throw new Error('nope'); return { vector: Array(1024).fill(1) }; } };
    const summary = await base.job.run({});
    assert.equal(summary.failed, 1);
    assert.equal(summary.embedded, 1);
  });

  it('logs no image bytes or vector values', async () => {
    const { job, calls } = harness();
    await job.run({});
    const output = JSON.stringify(calls.logs);
    assert.doesNotMatch(output, /same-image|0\.25|base64|token=|https?:/);
  });

  it('respects limit and figure-id selection', async () => {
    const figures = [figure(), figure({ figureId: 'fig-2' }), figure({ figureId: 'fig-3' })];
    const limited = harness({ figures });
    assert.equal((await limited.job.run({ limit: 2 })).scanned, 2);
    const selected = harness({ figures });
    const summary = await selected.job.run({ figureId: 'fig-3' });
    assert.equal(summary.scanned, 1);
    assert.equal(selected.calls.writes[0].metadata.figureId, 'fig-3');
  });

  it('reports zero missing images in planning and execution summaries', async () => {
    const { job } = harness();
    const plan = await job.plan({});
    assert.equal(plan.summary.missingImages, 0);
    assert.equal(plan.summary.missingImageCount, 0);
    assert.deepEqual(plan.summary.missingImageFigureIds, []);
    const summary = await job.execute(plan);
    assert.equal(summary.missingImages, 0);
    assert.equal(summary.missingImageCount, 0);
    assert.deepEqual(summary.missingImageFigureIds, []);
  });

  it('reports two missing-image figure IDs in both summaries', async () => {
    const base = harness({ figures: [
      figure(),
      figure({ figureId: 'fig-2', imageKey: 'fig-2' }),
      figure({ figureId: 'fig-3', imageKey: 'fig-3' }),
    ] });
    base.job.images = { async resolve(imageKey) {
      if (imageKey === 'fig-1' || imageKey === 'fig-2') throw new Error('missing');
      return { objectPath: `${imageKey}.webp`, bytes: Buffer.from('same-image'), mimeType: 'image/webp' };
    } };
    const plan = await base.job.plan({});
    assert.equal(plan.summary.missingImages, 2);
    assert.equal(plan.summary.missingImageCount, 2);
    assert.deepEqual(plan.summary.missingImageFigureIds, ['fig-1', 'fig-2']);
    const summary = await base.job.execute(plan);
    assert.equal(summary.missingImages, 2);
    assert.equal(summary.missingImageCount, 2);
    assert.deepEqual(summary.missingImageFigureIds, ['fig-1', 'fig-2']);
  });

  it('bounds missing-image IDs at twenty and marks truncation', async () => {
    const figures = Array.from({ length: 25 }, (_, index) => figure({ figureId: `fig-${index + 1}`, imageKey: `fig-${index + 1}` }));
    const base = harness({ figures });
    base.job.images = { async resolve() { throw new Error('missing'); } };
    const plan = await base.job.plan({});
    assert.equal(plan.summary.missingImageCount, 25);
    assert.equal(plan.summary.missingImageFigureIds.length, 20);
    assert.equal(plan.summary.missingImageFigureIdsTruncated, true);
    const summary = await base.job.execute(plan);
    assert.equal(summary.missingImageCount, 25);
    assert.equal(summary.missingImageFigureIds.length, 20);
    assert.equal(summary.missingImageFigureIdsTruncated, true);
    assert.doesNotMatch(JSON.stringify(summary), /\.webp|https?:|contentHash|same-image/);
  });

  it('keeps limit and figure-id planning behavior distinct', async () => {
    const figures = [figure(), figure({ figureId: 'fig-2' }), figure({ figureId: 'fig-3' })];
    const limited = harness({ figures });
    assert.equal((await limited.job.plan(parseCatalogEmbeddingArgs(['--limit', '2']))).summary.totalFigures, 2);
    const selected = harness({ figures });
    const plan = await selected.job.plan(parseCatalogEmbeddingArgs(['--figure-id', 'fig-3']));
    assert.equal(plan.summary.totalFigures, 1);
    assert.equal(plan.items[0].figure.figureId, 'fig-3');
  });
});

describe('adapters and CLI', () => {
  it('resolves extensions in canonical order and downloads only the first match', async () => {
    const probed = []; const read = [];
    const resolver = new FirebaseCatalogImageResolver({ async read(path) { read.push(path); return { bytes: Buffer.from('x'), mimeType: 'image/png' }; } }, {
      file(path) { return { async exists() { probed.push(path); return [path.endsWith('.png')]; } }; },
    });
    const result = await resolver.resolve('a');
    assert.deepEqual(probed, ['catalog/figures/a.avif', 'catalog/figures/a.webp', 'catalog/figures/a.png']);
    assert.deepEqual(read, ['catalog/figures/a.png']);
    assert.equal(result.objectPath, 'catalog/figures/a.png');
  });

  it('reports a missing image without preventing the next figure from succeeding', async () => {
    const base = harness({ figures: [figure(), figure({ figureId: 'fig-2' })] });
    let resolutions = 0;
    base.job.images = { async resolve() { resolutions++; if (resolutions === 1) throw new Error('missing'); return { objectPath: 'fig-2.webp', bytes: Buffer.from('same-image'), mimeType: 'image/webp' }; } };
    const summary = await base.job.run({});
    assert.equal(summary.failed, 1);
    assert.equal(summary.embedded, 1);
    assert.equal(base.calls.writes.length, 1);
  });

  it('persists a native VectorValue, never a plain array', async () => {
    let written;
    const firestore = { collection() { return { doc() { return { async set(data) { written = data; } }; } }; } };
    const store = new FirestoreCatalogEmbeddingStore(firestore);
    await store.writeEmbedding({
      documentId: 'fig-1',
      figureId: 'fig-1',
      seriesId: 'series-1',
      brandId: 'brand-1',
      ipId: 'ip-1',
      isSecret: false,
      imageKey: 'fig-1',
      imageRole: 'primary',
      variant: 'front',
      catalogModifiedAt: Timestamp.fromMillis(1000),
      imageObjectPath: 'a.webp',
      contentHash: 'abc',
    }, [1, 2], true);
    assert.ok(written.embedding instanceof VectorValue);
    assert.deepEqual(written.embedding.toArray(), [1, 2]);
    assert.equal(written.imageRole, 'primary');
    assert.equal(written.variant, 'front');
    assert.equal(written.imageKey, 'fig-1');
  });

  it('parses limit, figure-id, force, and prune flags', () => {
    assert.deepEqual(parseCatalogEmbeddingArgs([]), {});
    assert.deepEqual(parseCatalogEmbeddingArgs(['--limit', '10', '--force']), { limit: 10, force: true });
    assert.deepEqual(parseCatalogEmbeddingArgs(['--figure-id', 'fig-1', '--force']), { figureId: 'fig-1', force: true });
    assert.deepEqual(
      parseCatalogEmbeddingArgs(['--prune-stale-alternatives', '--prune-dry-run']),
      { pruneStaleAlternatives: true, pruneDryRun: true },
    );
    assert.throws(() => parseCatalogEmbeddingArgs(['--limit', '10', '--figure-id', 'fig-1']));
    assert.throws(() => parseCatalogEmbeddingArgs(['--limit', '10', '--limit', '20']));
    assert.throws(() => parseCatalogEmbeddingArgs(['--concurrency', '2']));
    assert.throws(() => parseCatalogEmbeddingArgs(['--prune-dry-run']));
  });

  it('reports a sanitized startup exception with its failing component', () => {
    assert.deepEqual(createStartupDiagnostic(
      new TypeError('Failed at https://example.test/path with token=secret'),
      'argument-parser',
    ), {
      success: false,
      errorCode: 'catalog-embedding-startup-failed',
      exceptionClass: 'TypeError',
      component: 'argument-parser',
      reason: 'Failed at [redacted-url] with token [redacted]',
    });
  });

  it('retries transient failures at most three attempts', async () => {
    let attempts = 0;
    await assert.rejects(() => withTransientRetries(async () => { attempts++; throw { code: 'unavailable' }; }, async () => {}, () => 0));
    assert.equal(attempts, 3);
  });
});

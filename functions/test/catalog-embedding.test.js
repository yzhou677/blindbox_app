'use strict';

const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const { Timestamp, VectorValue } = require('@google-cloud/firestore');
const { IMAGE_EMBEDDING_CONFIG } = require('../lib/figureRecognition/imageEmbeddingConfig');
const { FirebaseCatalogImageResolver } = require('../lib/figureRecognition/catalogImageResolver');
const { FirestoreCatalogEmbeddingStore } = require('../lib/figureRecognition/catalogEmbeddingStore');
const { CatalogEmbeddingJob, withTransientRetries } = require('../lib/figureRecognition/catalogEmbeddingJob');
const { parseCatalogEmbeddingArgs } = require('../lib/figureRecognition/catalogEmbeddingCli');

const figure = (overrides = {}) => ({
  figureId: 'fig-1', seriesId: 'series-1', brandId: 'brand-1', ipId: 'ip-1', isSecret: false,
  imageKey: 'fig-1', catalogModifiedAt: Timestamp.fromMillis(1000), ...overrides,
});

function harness({ existing = null, figures = [figure()], image = Buffer.from('same-image'), embedError } = {}) {
  const calls = { embeds: 0, writes: [], metadata: [], logs: [] };
  const source = {
    async get(id) { return figures.find((item) => item.figureId === id) ?? null; },
    async *pages() { yield figures; },
  };
  const images = { async resolve(imageKey) { return { objectPath: `${imageKey}.webp`, bytes: image, mimeType: 'image/webp' }; } };
  const store = {
    async get() { return existing; },
    async writeEmbedding(metadata, vector, isNew) { calls.writes.push({ metadata, vector, isNew }); },
    async updateMetadata(metadata) { calls.metadata.push(metadata); },
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
  it('plans API calls and cost without embedding or Firestore writes', async () => {
    const { job, calls } = harness({ figures: [figure(), figure({ figureId: 'fig-2' })] });
    const plan = await job.plan({ limit: 2 }, 0.5);
    assert.deepEqual(plan.summary, {
      totalFigures: 2, alreadyUpToDate: 0, metadataOnlyUpdates: 0, requiresEmbedding: 2,
      missingImages: 0, estimatedEmbeddingApiCalls: 2, estimatedAiCostUsd: 1,
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
    await store.writeEmbedding({ ...figure(), imageObjectPath: 'a.webp', contentHash: 'abc' }, [1, 2], true);
    assert.ok(written.embedding instanceof VectorValue);
    assert.deepEqual(written.embedding.toArray(), [1, 2]);
  });

  it('parses only limit, figure-id, and force', () => {
    assert.deepEqual(parseCatalogEmbeddingArgs(['--limit', '10', '--figure-id', 'fig-1', '--force']), { limit: 10, figureId: 'fig-1', force: true });
    assert.throws(() => parseCatalogEmbeddingArgs(['--concurrency', '2']));
  });

  it('retries transient failures at most three attempts', async () => {
    let attempts = 0;
    await assert.rejects(() => withTransientRetries(async () => { attempts++; throw { code: 'unavailable' }; }, async () => {}, () => 0));
    assert.equal(attempts, 3);
  });
});

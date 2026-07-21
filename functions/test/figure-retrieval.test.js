'use strict';

const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const { IMAGE_EMBEDDING_CONFIG } = require('../lib/figureRecognition/imageEmbeddingConfig');
const { LocalImageReader, detectImageMimeType } = require('../lib/figureRecognition/localImageReader');
const { FigureRetrievalService, validateQueryVector } = require('../lib/figureRecognition/figureRetrievalService');
const { parseFigureRetrievalArgs, formatFigureRetrievalCandidate, formatPrimarySubjectResult } = require('../lib/figureRecognition/figureRetrievalCli');
const { FirestoreFigureVectorSearch, FigureVectorIndexUnavailableError } = require('../lib/figureRecognition/figureVectorSearch');

const vector = () => Array(1024).fill(0.25);
const candidate = (overrides = {}) => ({
  figureId: 'figure-1', seriesId: 'series-1', brandId: 'brand-1', ipId: 'ip-1',
  isSecret: false, embeddingSpace: IMAGE_EMBEDDING_CONFIG.embeddingSpace,
  _vectorDistance: 0.2, ...overrides,
});

function firestoreHarness(rows = [], queryError) {
  const calls = {};
  const firestore = {
    collection(name) {
      calls.collection = name;
      return {
        where(...args) {
          calls.where = args;
          return {
            findNearest(options) {
              calls.findNearest = options;
              return { async get() {
                if (queryError) throw queryError;
                return { docs: rows.map((data) => ({ data: () => data })) };
              } };
            },
            select(...fields) {
              calls.select = fields;
              return {
                findNearest(options) {
                  calls.findNearest = options;
                  return { async get() {
                    if (queryError) throw queryError;
                    return { docs: rows.map((data) => ({ data: () => data })) };
                  } };
                },
              };
            },
          };
        },
      };
    },
  };
  return { search: new FirestoreFigureVectorSearch(firestore), calls };
}

describe('LocalImageReader', () => {
  it('validates existence and regular files', async () => {
    const missing = new LocalImageReader({ async stat() { throw new Error('ENOENT'); }, async readFile() { throw new Error('unused'); } });
    await assert.rejects(() => missing.read('missing.png'), /does not exist/);
    const directory = new LocalImageReader({ async stat() { return { isFile: () => false }; }, async readFile() { throw new Error('unused'); } });
    await assert.rejects(() => directory.read('folder'), /regular file/);
  });

  it('detects MIME type from bytes rather than the filename', async () => {
    const png = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
    const reader = new LocalImageReader({ async stat() { return { isFile: () => true }; }, async readFile() { return png; } });
    assert.equal((await reader.read('not-an-image.txt')).mimeType, 'image/png');
    assert.throws(() => detectImageMimeType(Buffer.from('image bytes')));
  });
});

describe('Figure retrieval', () => {
  it('keeps the approved active embedding configuration', () => {
    assert.deepEqual({
      model: IMAGE_EMBEDDING_CONFIG.model, location: IMAGE_EMBEDDING_CONFIG.location,
      dimension: IMAGE_EMBEDDING_CONFIG.outputDimension, version: IMAGE_EMBEDDING_CONFIG.version,
      space: IMAGE_EMBEDDING_CONFIG.embeddingSpace,
    }, {
      model: 'gemini-embedding-2', location: 'us', dimension: 1024,
      version: 'image-v1', space: 'gemini-embedding-2_us_1024_image-v1',
    });
  });

  it('validates exactly 1024 finite query values', () => {
    assert.doesNotThrow(() => validateQueryVector(vector()));
    assert.throws(() => validateQueryVector([1]));
    assert.throws(() => validateQueryVector([...Array(1023).fill(1), NaN]));
  });

  it('filters the active space and performs bounded COSINE retrieval', async () => {
    const { search, calls } = firestoreHarness([candidate()]);
    await search.search(vector(), 5);
    assert.equal(calls.collection, 'catalogFigureEmbeddings');
    assert.deepEqual(calls.where, ['embeddingSpace', '==', IMAGE_EMBEDDING_CONFIG.embeddingSpace]);
    assert.deepEqual(calls.findNearest, {
      vectorField: 'embedding', queryVector: vector(), limit: 5,
      distanceMeasure: 'COSINE', distanceResultField: '_vectorDistance',
    });
    assert.equal(calls.select, undefined);
  });

  it('returns a valid candidate when Firestore supplies the synthetic distance field', async () => {
    const { search } = firestoreHarness([candidate({ ipId: 'ip-preserved', _vectorDistance: 0.125 })]);
    const results = await search.search(vector(), 5);
    assert.equal(results.length, 1);
    assert.equal(results[0].distance, 0.125);
    assert.equal(results[0].rank, 1);
    assert.equal(results[0].ipId, 'ip-preserved');
    assert.ok(formatFigureRetrievalCandidate(results[0]).includes('ipId: ip-preserved'));
  });

  it('sanitizes a missing synthetic distance by skipping the document', async () => {
    const row = candidate();
    delete row._vectorDistance;
    const { search } = firestoreHarness([row]);
    assert.deepEqual(await search.search(vector(), 5), []);
  });

  it('ranks nearest to farthest deterministically and returns only the approved contract', async () => {
    const { search } = firestoreHarness([
      candidate({ figureId: 'z', _vectorDistance: 0.4 }),
      candidate({ figureId: 'b', _vectorDistance: 0.1 }),
      candidate({ figureId: 'a', _vectorDistance: 0.1 }),
    ]);
    const results = await search.search(vector(), 5);
    assert.deepEqual(results.map(({ figureId, rank }) => ({ figureId, rank })), [
      { figureId: 'a', rank: 1 }, { figureId: 'b', rank: 2 }, { figureId: 'z', rank: 3 },
    ]);
    assert.deepEqual(Object.keys(results[0]).sort(), ['brandId', 'distance', 'embeddingSpace', 'figureId', 'ipId', 'isSecret', 'rank', 'seriesId'].sort());
    assert.doesNotMatch(JSON.stringify(results), /0\.25|embedding":|bytes|base64/);
  });

  it('handles empty results and skips malformed or wrong-space documents', async () => {
    assert.deepEqual(await firestoreHarness([]).search.search(vector(), 5), []);
    const { search } = firestoreHarness([
      candidate({ figureId: '' }), candidate({ embeddingSpace: 'old-space' }), candidate({ _vectorDistance: NaN }), candidate(),
    ]);
    assert.equal((await search.search(vector(), 5)).length, 1);
  });

  it('surfaces a missing or building vector index clearly', async () => {
    const { search } = firestoreHarness([], { code: 9 });
    await assert.rejects(() => search.search(vector(), 5), FigureVectorIndexUnavailableError);
  });

  it('rejects invalid input and Top-K before embedding', async () => {
    let embeddingCalls = 0;
    const service = new FigureRetrievalService(
      { async read() { throw new Error('unsupported'); } },
      { async embedStoredImage() { embeddingCalls++; return { vector: vector() }; } },
      { async search() { return []; } },
    );
    await assert.rejects(() => service.retrieve('bad.gif', 5), /unsupported/);
    await assert.rejects(() => service.retrieve('bad.gif', 21), /Top-K/);
    assert.equal(embeddingCalls, 0);
  });

  it('parses only a local file and a Top-K from 1 through 20', () => {
    assert.deepEqual(parseFigureRetrievalArgs(['--file', 'photo.jpg']), { file: 'photo.jpg', topK: 5, isolateSubject: false, previewDir: undefined, overwritePreview: false });
    assert.deepEqual(parseFigureRetrievalArgs(['--file', 'photo.jpg', '--top-k', '20']), { file: 'photo.jpg', topK: 20, isolateSubject: false, previewDir: undefined, overwritePreview: false });
    assert.deepEqual(parseFigureRetrievalArgs(['--file', 'photo.jpg', '--isolate-subject', '--preview-dir', 'previews', '--overwrite-preview']), { file: 'photo.jpg', topK: 5, isolateSubject: true, previewDir: 'previews', overwritePreview: true });
    assert.throws(() => parseFigureRetrievalArgs(['--file', 'photo.jpg', '--preview-dir', 'previews']));
    assert.throws(() => parseFigureRetrievalArgs(['--file', 'photo.jpg', '--top-k', '0']));
    assert.throws(() => parseFigureRetrievalArgs(['--storage-path', 'photo.jpg']));
  });

  it('prints full-precision crop, blur, and failed-check diagnostics', () => {
    const lines = formatPrimarySubjectResult({
      status: 'too_blurry', reason: 'crop_detail_below_threshold',
      candidates: [{ candidateNumber: 1, normalized: { ymin: 101, xmin: 202, ymax: 899, xmax: 798 }, pixels: { top: 40, left: 80, width: 260, height: 360 },
        centerScore: 0.91, sharpnessScore: 0.82, areaScore: 0.76, backgroundScore: 0.7, totalScore: 0.83, selected: true }],
      diagnostics: {
        locatorModel: 'configured-model', locatorPromptVersion: 'configured-prompt', elapsedMs: 7,
        sourceWidth: 640, sourceHeight: 480, cropWidth: 260, cropHeight: 360,
        subjectAreaRatio: 0.476123456789, blurMetric: 1.234567890123,
        blurThreshold: 1.5, blurAlgorithm: 'sharp.stats().sharpness', detailMetric: 0.75,
        detailThreshold: 1, detailAlgorithm: 'mean absolute grayscale gradient', combinedBlurPassed: false,
        failedBlurSignals: ['sharpness', 'gradient energy'], padding: 0.12, processingResolution: '260x360', failedChecks: ['blur'],
        refinement: { attempted: true, accepted: false, reason: 'area_reduction_too_small',
          coarseNormalizedBox: { ymin: 90, xmin: 190, ymax: 910, xmax: 810 }, refinedNormalizedBox: { ymin: 101, xmin: 202, ymax: 899, xmax: 798 },
          coarsePixelBox: { top: 35, left: 75, width: 270, height: 370 }, refinedPixelBox: { top: 40, left: 80, width: 260, height: 360 },
          coarseArea: 99900, refinedArea: 93600, areaReductionRatio: 0.06306306306306306, finalPadding: 0.06 },
      },
    }, { coarseOverlay: 'photo.coarse-subject-overlay.jpg', refinedOverlay: 'photo.refined-subject-overlay.jpg', coarseCrop: 'photo.coarse-subject-crop.jpg', crop: 'photo.subject-crop.jpg' });
    const output = lines.join('\n');
    assert.match(output, /Blur diagnostics\n\nsharpnessMetric:\n1\.234567890123/);
    assert.match(output, /sharpnessThreshold:\n1\.5\n\nsharpnessPassed:\nfalse/);
    assert.match(output, /sharpnessAlgorithm:\nsharp\.stats\(\)\.sharpness/);
    assert.match(output, /detailMetric:\n0\.75[\s\S]*detailThreshold:\n1[\s\S]*combinedDecision:\nfailed/);
    assert.match(output, /failedSignals:\n\n- sharpness\n- gradient energy/);
    assert.match(output, /Candidate scores[\s\S]*Candidate 1[\s\S]*centerScore:\n0\.91[\s\S]*totalScore:\n0\.83[\s\S]*selected:\ntrue/);
    assert.match(output, /Crop diagnostics[\s\S]*sourceWidth:\n640[\s\S]*normalizedBoundingBox:/);
    assert.match(output, /Quality Gate[\s\S]*status:\ntoo_blurry[\s\S]*failedChecks:\n\n- blur/);
    assert.match(output, /Refinement diagnostics[\s\S]*attempted:\ntrue[\s\S]*accepted:\nfalse/);
    assert.match(output, /reason:\narea_reduction_too_small[\s\S]*areaReductionRatio:\n0\.06306306306306306/);
    assert.doesNotMatch(output, /base64|image bytes|vector|credentials/i);
    assert.match(output, /Coarse overlay preview: photo\.coarse-subject-overlay\.jpg/);
    assert.match(output, /Refined overlay preview: photo\.refined-subject-overlay\.jpg/);
    assert.match(output, /Coarse crop preview: photo\.coarse-subject-crop\.jpg/);
    assert.match(output, /Crop preview: photo\.subject-crop\.jpg/);
  });
});

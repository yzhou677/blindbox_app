'use strict';

const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const sharp = require('sharp');
const { PRIMARY_SUBJECT_CONFIG } = require('../lib/figureRecognition/primarySubjectConfig');
const { GooglePrimarySubjectLocator, PRIMARY_SUBJECT_PROMPT } = require('../lib/figureRecognition/googlePrimarySubjectLocator');
const { validateLocatorResponse, InvalidLocatorOutputError } = require('../lib/figureRecognition/primarySubjectOutputValidator');
const { PrimarySubjectCropper } = require('../lib/figureRecognition/primarySubjectCropper');
const { PrimarySubjectIsolationService } = require('../lib/figureRecognition/primarySubjectIsolationService');
const { PrimarySubjectPreviewWriter } = require('../lib/figureRecognition/primarySubjectPreviewWriter');
const { PrimarySubjectRefinementService } = require('../lib/figureRecognition/primarySubjectRefinementService');
const { GooglePrimarySubjectRefiner, PRIMARY_SUBJECT_REFINEMENT_PROMPT } = require('../lib/figureRecognition/googlePrimarySubjectRefiner');
const { FigureRetrievalService } = require('../lib/figureRecognition/figureRetrievalService');

const single = (bbox = [100, 200, 900, 800]) => ({ candidates: [{ bbox }] });
const three = () => ({ candidates: [
  { bbox: [100, 30, 500, 300] },
  { bbox: [200, 350, 850, 650] },
  { bbox: [250, 720, 700, 970] },
] });

async function fixture(width = 640, height = 480, options = {}) {
  const channels = options.alpha ? 4 : 3;
  const data = Buffer.alloc(width * height * channels);
  for (let y = 0; y < height; y++) for (let x = 0; x < width; x++) {
    const offset = (y * width + x) * channels;
    const value = options.blur ? 128 : ((x * 17 + y * 31) % 256);
    data[offset] = value; data[offset + 1] = 255 - value; data[offset + 2] = (value * 3) % 256;
    if (channels === 4) data[offset + 3] = (x + y) % 256;
  }
  let pipeline = sharp(data, { raw: { width, height, channels } });
  if (options.orientation) pipeline = pipeline.jpeg().withMetadata({ orientation: options.orientation });
  else pipeline = options.alpha ? pipeline.png() : pipeline.jpeg({ quality: 95 });
  return { bytes: await pipeline.toBuffer(), mimeType: options.alpha ? 'image/png' : 'image/jpeg' };
}

async function smoothCollectibleFixture() {
  const svg = Buffer.from(`<svg width="640" height="480" xmlns="http://www.w3.org/2000/svg">
    <rect width="640" height="480" fill="#e7e0d8"/>
    <ellipse cx="320" cy="250" rx="155" ry="185" fill="#f3a9b8"/>
    <circle cx="270" cy="215" r="18" fill="#202020"/><circle cx="370" cy="215" r="18" fill="#202020"/>
    <path d="M270 315 Q320 350 370 315" fill="none" stroke="#202020" stroke-width="10"/>
  </svg>`);
  return { bytes: await sharp(svg).png().toBuffer(), mimeType: 'image/png' };
}

describe('Primary subject locator contract', () => {
  it('centralizes the approved stable Vertex configuration', () => {
    assert.deepEqual({ model: PRIMARY_SUBJECT_CONFIG.model, location: PRIMARY_SUBJECT_CONFIG.location, temperature: PRIMARY_SUBJECT_CONFIG.temperature, mediaResolution: PRIMARY_SUBJECT_CONFIG.mediaResolution, promptVersion: PRIMARY_SUBJECT_CONFIG.promptVersion },
      { model: 'gemini-3.5-flash', location: 'us', temperature: 0, mediaResolution: 'MEDIA_RESOLUTION_HIGH', promptVersion: 'primary-subject-v3' });
    assert.equal(Object.values(PRIMARY_SUBJECT_CONFIG.candidateScoreWeights).reduce((sum, weight) => sum + weight, 0), 1);
  });

  it('sends fixed semantic exclusions and strict structured generation settings', async () => {
    let request;
    const client = { models: { async generateContent(value) { request = value; return { text: JSON.stringify(single()) }; } } };
    const locator = new GooglePrimarySubjectLocator('project', PRIMARY_SUBJECT_CONFIG, client);
    assert.deepEqual(await locator.locate(await fixture()), single());
    assert.equal(request.model, 'gemini-3.5-flash');
    assert.equal(request.config.temperature, 0);
    assert.equal(request.config.mediaResolution, 'MEDIA_RESOLUTION_HIGH');
    assert.equal(request.config.responseMimeType, 'application/json');
    assert.equal(request.config.responseJsonSchema.properties.candidates.maxItems, 3);
    assert.deepEqual(request.config.responseJsonSchema.properties.candidates.items.required, ['bbox']);
    assert.equal('status' in request.config.responseJsonSchema.properties, false);
    assert.match(PRIMARY_SUBJECT_PROMPT, /reflections/);
    assert.match(PRIMARY_SUBJECT_PROMPT, /drinks/);
    assert.match(PRIMARY_SUBJECT_PROMPT, /packaging artwork/);
    assert.match(PRIMARY_SUBJECT_PROMPT, /printed/);
    assert.match(PRIMARY_SUBJECT_PROMPT, /beverage cans/);
    assert.match(PRIMARY_SUBJECT_PROMPT, /props/);
    assert.match(PRIMARY_SUBJECT_PROMPT, /display shelves/);
    assert.match(PRIMARY_SUBJECT_PROMPT, /plush toys in the background/);
    assert.match(PRIMARY_SUBJECT_PROMPT, /exactly one collectible/);
    assert.match(PRIMARY_SUBJECT_PROMPT, /Never merge nearby collectibles or unrelated objects/);
    assert.match(PRIMARY_SUBJECT_PROMPT, /Do not decide which candidate is primary/);
    assert.match(PRIMARY_SUBJECT_PROMPT, /hands, keyboards, and tables/);
    assert.match(PRIMARY_SUBJECT_PROMPT, /Do not identify, name, classify, or guess any Catalog entity/);
    assert.equal('apiKey' in request, false);
  });

  it('constructs the official client in Vertex AI ADC mode without an API key', () => {
    let options;
    new GooglePrimarySubjectLocator('project-id', PRIMARY_SUBJECT_CONFIG, undefined, (value) => {
      options = value; return { models: { async generateContent() { return { text: '{}' }; } } };
    });
    assert.deepEqual(options, { vertexai: true, project: 'project-id', location: 'us' });
    assert.equal('apiKey' in options, false);
  });

  it('retries only transient cloud failures with a bounded policy', async () => {
    let calls = 0; const delays = [];
    const client = { models: { async generateContent() { calls++; if (calls < 3) throw { code: 429 }; return { text: JSON.stringify(single()) }; } } };
    const locator = new GooglePrimarySubjectLocator('project', PRIMARY_SUBJECT_CONFIG, client, undefined, async (ms) => delays.push(ms));
    await locator.locate(await fixture());
    assert.deepEqual({ calls, delays }, { calls: 3, delays: [400, 800] });
    calls = 0;
    const invalid = new GooglePrimarySubjectLocator('project', PRIMARY_SUBJECT_CONFIG, { models: { async generateContent() { calls++; throw { code: 400 }; } } }, undefined, async () => {});
    await assert.rejects(() => invalid.locate({ bytes: Buffer.from('x'), mimeType: 'image/jpeg' }));
    assert.equal(calls, 1);
  });

  it('validates one, three, and zero candidate responses', () => {
    assert.equal(validateLocatorResponse(single()).candidates[0].box.xmin, 200);
    assert.equal(validateLocatorResponse(three()).candidates.length, 3);
    assert.deepEqual(validateLocatorResponse({ candidates: [] }).candidates, []);
    assert.equal(validateLocatorResponse(single([-0.5, 0, 1000.5, 1000])).candidates[0].box.ymin, 0);
  });

  it('fails closed for malformed JSON and independently malformed candidates', async () => {
    const malformed = new GooglePrimarySubjectLocator('project', PRIMARY_SUBJECT_CONFIG, { models: { async generateContent() { return { text: '{' }; } } });
    await assert.rejects(() => malformed.locate({ bytes: Buffer.from('x'), mimeType: 'image/jpeg' }), /malformed JSON/);
    for (const value of [
      single([100, 100, 100, 200]), single([NaN, 1, 2, 3]),
      { candidates: [{ bbox: [1, 2, 3] }] }, { candidates: [...three().candidates, { bbox: [1, 2, 3, 4] }] },
    ]) assert.throws(() => validateLocatorResponse(value), InvalidLocatorOutputError);
  });
});

describe('Primary subject crop and gate', () => {
  const config = { ...PRIMARY_SUBJECT_CONFIG, minCropWidth: 80, minCropHeight: 80, minSubjectAreaRatio: 0.01, minSharpness: 0.1 };
  const cropper = new PrimarySubjectCropper(config);

  it('applies padding, clamps edges, preserves portrait/landscape geometry, and rejects degenerate boxes', () => {
    assert.deepEqual(cropper.pixelBox({ ymin: 0, xmin: 0, ymax: 1000, xmax: 1000 }, 200, 100), { left: 0, top: 0, width: 200, height: 100 });
    const portrait = cropper.pixelBox({ ymin: 100, xmin: 400, ymax: 900, xmax: 600 }, 400, 800);
    assert.ok(portrait.height > portrait.width);
    assert.throws(() => cropper.pixelBox({ ymin: 1, xmin: 1, ymax: 1, xmax: 2 }, 100, 100));
  });

  it('auto-orients EXIF input and keeps alpha-capable crops valid', async () => {
    const oriented = await cropper.orient(await fixture(120, 240, { orientation: 6 }));
    assert.deepEqual([oriented.width, oriented.height], [240, 120]);
    const alpha = await cropper.orient(await fixture(200, 200, { alpha: true }));
    const crop = await cropper.crop(alpha, validateLocatorResponse(single()).candidates[0]);
    assert.equal(crop.image.mimeType, 'image/png');
    assert.equal((await sharp(crop.image.bytes).metadata()).hasAlpha, true);
  });

  it('classifies sharp, blurry, tiny, no-subject, and invalid results locally', async () => {
    const sharpImage = await fixture();
    const usable = await new PrimarySubjectIsolationService({ async locate() { return single(); } }, cropper, config).isolate(sharpImage);
    assert.equal(usable.status, 'usable');
    const blurryConfig = { ...config, minSharpness: 9999, minGradientEnergy: 9999 };
    assert.equal((await new PrimarySubjectIsolationService({ async locate() { return single(); } }, new PrimarySubjectCropper(blurryConfig), blurryConfig).isolate(sharpImage)).status, 'too_blurry');
    assert.equal((await new PrimarySubjectIsolationService({ async locate() { return single([490, 490, 510, 510]); } }, cropper, config).isolate(sharpImage)).status, 'subject_too_small');
    assert.equal((await new PrimarySubjectIsolationService({ async locate() { return { candidates: [] }; } }, cropper, config).isolate(sharpImage)).status, 'no_subject');
    assert.equal((await new PrimarySubjectIsolationService({ async locate() { return { bad: true }; } }, cropper, config).isolate(sharpImage)).reason, 'invalid_locator_output');
    const flatImage = await fixture(640, 480, { blur: true });
    assert.equal((await new PrimarySubjectIsolationService({ async locate() { return single(); } }, cropper, config).isolate(flatImage)).status, 'too_blurry');
  });

  it('allows a smooth but sharply bounded synthetic collectible through the composite gate', async () => {
    const result = await new PrimarySubjectIsolationService({ async locate() { return single([20, 100, 980, 900]); } }, cropper, config).isolate(await smoothCollectibleFixture());
    assert.equal(result.status, 'usable');
    assert.equal(result.diagnostics.combinedBlurPassed, true);
  });

  it('scores three collectible proposals locally and selects the centered candidate', async () => {
    const result = await new PrimarySubjectIsolationService({ async locate() { return three(); } }, cropper, config).isolate(await fixture());
    assert.equal(result.status, 'usable');
    assert.equal(result.candidates.length, 3);
    assert.equal(result.candidates.find((candidate) => candidate.selected).candidateNumber, 2);
    assert.ok(result.candidates[1].centerScore > result.candidates[0].centerScore);
    assert.ok(result.candidates.every((candidate) => Number.isFinite(candidate.totalScore)));
  });

  it('rejects blur only when both signals fail and preserves size/area precedence', async () => {
    const compositeConfig = { ...config, minSharpness: 1.5, minGradientEnergy: 1 };
    const run = async (sharpness, gradientEnergy, box = { left: 10, top: 10, width: 300, height: 300 }) => {
      const fakeCropper = {
        async orient() { return { bytes: Buffer.from('oriented'), width: 640, height: 480, hasAlpha: false }; },
        pixelBox() { return box; },
        async crop() { return { image: { bytes: Buffer.from('crop'), mimeType: 'image/jpeg' }, box, width: box.width, height: box.height, sharpness, gradientEnergy }; },
      };
      return new PrimarySubjectIsolationService({ async locate() { return single(); } }, fakeCropper, compositeConfig).isolate({ bytes: Buffer.from('source'), mimeType: 'image/jpeg' });
    };
    const sharpnessLow = await run(0.5, 4);
    assert.equal(sharpnessLow.status, 'usable');
    assert.deepEqual(sharpnessLow.diagnostics.failedBlurSignals, ['sharpness']);
    const gradientLow = await run(3, 0.2);
    assert.equal(gradientLow.status, 'usable');
    assert.deepEqual(gradientLow.diagnostics.failedBlurSignals, ['gradient energy']);
    const bothLow = await run(0.5, 0.2);
    assert.equal(bothLow.status, 'too_blurry');
    assert.deepEqual(bothLow.diagnostics.failedBlurSignals, ['sharpness', 'gradient energy']);
    const tooSmall = await run(0.5, 0.2, { left: 10, top: 10, width: 20, height: 20 });
    assert.equal(tooSmall.status, 'subject_too_small');
    assert.equal(tooSmall.reason, 'crop_dimensions_below_threshold');
  });
});

describe('Primary subject refinement', () => {
  const prepared = { bytes: Buffer.from('oriented'), width: 1000, height: 800, hasAlpha: false };
  const coarse = { image: { bytes: Buffer.from('coarse'), mimeType: 'image/jpeg' }, box: { left: 100, top: 50, width: 400, height: 300 }, width: 400, height: 300, sharpness: 3, gradientEnergy: 3 };
  const baseConfig = { ...PRIMARY_SUBJECT_CONFIG, minCropWidth: 20, minCropHeight: 20, minSubjectAreaRatio: 0.001, minSharpness: 1.5, minGradientEnergy: 1 };

  function refinementHarness(response, overrides = {}, cropMetrics = { sharpness: 3, gradientEnergy: 3 }) {
    let calls = 0;
    const cropper = {
      paddedPixelBox(box, ratio, sourceWidth, sourceHeight, containment) {
        const left = Math.max(containment.left, Math.floor(box.left - box.width * ratio));
        const top = Math.max(containment.top, Math.floor(box.top - box.height * ratio));
        const right = Math.min(containment.left + containment.width, Math.ceil(box.left + box.width * (1 + ratio)));
        const bottom = Math.min(containment.top + containment.height, Math.ceil(box.top + box.height * (1 + ratio)));
        return { left, top, width: right - left, height: bottom - top };
      },
      async cropPixelBox(image, box) { return { image: { bytes: Buffer.from(`final:${box.left}:${box.top}:${box.width}:${box.height}`), mimeType: 'image/jpeg' }, box, width: box.width, height: box.height, ...cropMetrics }; },
    };
    const refiner = { async refine() { calls++; if (response instanceof Error) throw response; return response; } };
    const service = new PrimarySubjectRefinementService(refiner, cropper, { ...baseConfig, ...overrides });
    return { service, cropper, calls: () => calls };
  }

  it('uses the coarse crop in one structured Vertex refinement request', async () => {
    let request; let options;
    const client = { models: { async generateContent(value) { request = value; return { text: JSON.stringify({ bbox: [100, 100, 900, 900] }) }; } } };
    const refiner = new GooglePrimarySubjectRefiner('project', PRIMARY_SUBJECT_CONFIG, client, (value) => { options = value; return client; });
    await refiner.refine(coarse.image);
    assert.equal(request.model, PRIMARY_SUBJECT_CONFIG.model);
    assert.equal(request.contents[0].parts[1].inlineData.data, coarse.image.bytes.toString('base64'));
    assert.deepEqual(request.config.responseJsonSchema.required, ['bbox']);
    assert.match(PRIMARY_SUBJECT_REFINEMENT_PROMPT, /same physical collectible/);
    assert.match(PRIMARY_SUBJECT_REFINEMENT_PROMPT, /Do not choose another figure/);
    assert.equal(options, undefined);
  });

  it('maps a valid tightened box back to original oriented-image coordinates and runs once', async () => {
    const harness = refinementHarness({ bbox: [100, 100, 900, 900] });
    const result = await harness.service.refine(prepared, coarse);
    assert.equal(harness.calls(), 1);
    assert.equal(result.diagnostics.accepted, true);
    assert.deepEqual(result.diagnostics.refinedPixelBox, { left: 140, top: 80, width: 320, height: 240 });
    assert.equal(result.diagnostics.areaReductionRatio, 0.36);
    assert.deepEqual(result.normalized, { ymin: 100, xmin: 140, ymax: 400, xmax: 460 });
  });

  it('accepts refinement reduction through 70% and rejects only values above it', async () => {
    const observed = await refinementHarness({ bbox: [200, 215, 803, 785] }).service.refine(prepared, coarse);
    assert.equal(observed.diagnostics.areaReductionRatio, 0.6561);
    assert.equal(observed.diagnostics.accepted, true);

    const boundary = await refinementHarness({ bbox: [200, 250, 800, 750] }).service.refine(prepared, coarse);
    assert.equal(boundary.diagnostics.areaReductionRatio, 0.7);
    assert.equal(boundary.diagnostics.accepted, true);

    const above = await refinementHarness({ bbox: [200, 262.5, 800, 737.5] }).service.refine(prepared, coarse);
    assert.ok(above.diagnostics.areaReductionRatio > 0.7);
    assert.equal(above.diagnostics.accepted, false);
    assert.equal(above.diagnostics.reason, 'area_reduction_too_large');
  });

  it('falls back for expanded, degenerate, too-small, and excessive reductions', async () => {
    const cases = [
      [{ bbox: [-5, -5, 1005, 1005] }, {}, 'refinement_failed'],
      [{ bbox: [500, 500, 500, 700] }, {}, 'refinement_failed'],
      [{ bbox: [10, 10, 990, 990] }, {}, 'area_reduction_too_small'],
      [{ bbox: [400, 400, 600, 600] }, {}, 'area_reduction_too_large'],
    ];
    for (const [response, overrides, reason] of cases) {
      const result = await refinementHarness(response, overrides).service.refine(prepared, coarse);
      assert.equal(result.diagnostics.accepted, false);
      assert.equal(result.diagnostics.reason, reason);
      assert.equal(result.crop.image.bytes.toString(), 'coarse');
    }
  });

  it('falls back when the refined crop fails size or composite quality', async () => {
    const size = await refinementHarness({ bbox: [100, 100, 900, 900] }, { minCropWidth: 500 }).service.refine(prepared, coarse);
    assert.equal(size.diagnostics.reason, 'refined_crop_too_small');
    const blur = await refinementHarness({ bbox: [100, 100, 900, 900] }, {}, { sharpness: 0.1, gradientEnergy: 0.1 }).service.refine(prepared, coarse);
    assert.equal(blur.diagnostics.reason, 'refined_crop_too_blurry');
  });

  it('falls back for malformed output and exhausted model failure', async () => {
    assert.equal((await refinementHarness({ prose: 'not allowed' }).service.refine(prepared, coarse)).diagnostics.reason, 'refinement_failed');
    const failed = refinementHarness(new Error('transient attempts exhausted'));
    const result = await failed.service.refine(prepared, coarse);
    assert.equal(failed.calls(), 1);
    assert.equal(result.diagnostics.reason, 'refinement_failed');
  });

  it('falls back after the refiner exhausts exactly three transient attempts', async () => {
    let calls = 0;
    const client = { models: { async generateContent() { calls++; throw { code: 429 }; } } };
    const adapter = new GooglePrimarySubjectRefiner('project', baseConfig, client, undefined, async () => {});
    const cropper = refinementHarness({ bbox: [100, 100, 900, 900] }).cropper;
    const service = new PrimarySubjectRefinementService(adapter, cropper, baseConfig);
    const result = await service.refine(prepared, coarse);
    assert.equal(calls, 3);
    assert.equal(result.diagnostics.reason, 'refinement_failed');
    assert.equal(result.crop.image.bytes.toString(), 'coarse');
  });

  it('passes accepted refinement, or coarse fallback, to embedding and never the full image', async () => {
    const source = await fixture();
    const config = { ...PRIMARY_SUBJECT_CONFIG, minCropWidth: 1, minCropHeight: 1, minSubjectAreaRatio: 0, minSharpness: 0, minGradientEnergy: 0 };
    const cropper = new PrimarySubjectCropper(config);
    const acceptedRefinement = new PrimarySubjectRefinementService({ async refine() { return { bbox: [100, 100, 900, 900] }; } }, cropper, config);
    const accepted = await new PrimarySubjectIsolationService({ async locate() { return single(); } }, cropper, config, acceptedRefinement).isolate(source);
    assert.equal(accepted.status, 'usable'); assert.equal(accepted.diagnostics.refinement.accepted, true);
    let embedded;
    const retrieval = new FigureRetrievalService({ async read() { throw new Error('unused'); } }, { async embedStoredImage(image) { embedded = image; return { vector: Array(1024).fill(1) }; } }, { async search() { return []; } });
    await retrieval.retrieveStoredImage(accepted.crop, 5);
    assert.equal(embedded.bytes.equals(accepted.crop.bytes), true);
    assert.equal(embedded.bytes.equals(accepted.previewCrops.coarse.bytes), false);
    assert.equal(embedded.bytes.equals(source.bytes), false);

    const rejectedRefinement = new PrimarySubjectRefinementService({ async refine() { return { invalid: true }; } }, cropper, config);
    const rejected = await new PrimarySubjectIsolationService({ async locate() { return single(); } }, cropper, config, rejectedRefinement).isolate(source);
    assert.equal(rejected.status, 'usable'); assert.equal(rejected.diagnostics.refinement.accepted, false);
    await retrieval.retrieveStoredImage(rejected.crop, 5);
    assert.equal(embedded.bytes.equals(rejected.previewCrops.coarse.bytes), true);
    assert.equal(embedded.bytes.equals(source.bytes), false);
  });
});

describe('Isolation integration and previews', () => {
  it('keeps the existing refined crop as embedding input when segmentation is not configured', async () => {
    const config = { ...PRIMARY_SUBJECT_CONFIG, minCropWidth: 1, minCropHeight: 1, minSubjectAreaRatio: 0, minSharpness: 0, minGradientEnergy: 0 };
    const result = await new PrimarySubjectIsolationService({ async locate() { return single(); } }, new PrimarySubjectCropper(config), config).isolate(await fixture());
    assert.equal(result.status, 'usable');
    assert.equal(result.embeddingInput.bytes.equals(result.previewCrops.final.bytes), true);
    assert.equal(result.crop.bytes.equals(result.embeddingInput.bytes), true);
    assert.deepEqual(result.diagnostics.segmentation, { elapsedMs: 0, method: 'none', reason: 'not_configured', status: 'unavailable', usedFallback: true, fallbackUsed: true, fallbackReason: 'not_configured' });
  });

  it('routes a generic segmenter result to embedding without exposing provider-specific types', async () => {
    const config = { ...PRIMARY_SUBJECT_CONFIG, minCropWidth: 1, minCropHeight: 1, minSubjectAreaRatio: 0, minSharpness: 0, minGradientEnergy: 0 };
    let input;
    const segmentedImage = { bytes: Buffer.from('segmented'), mimeType: 'image/png' };
    const preview = { mask: segmentedImage, overlay: segmentedImage, subject: segmentedImage };
    const segmenter = { async segment(value) { input = value; return { status: 'segmented', image: segmentedImage, preview, diagnostics: { elapsedMs: 12, method: 'fake' } }; } };
    const result = await new PrimarySubjectIsolationService({ async locate() { return single(); } }, new PrimarySubjectCropper(config), config, undefined, segmenter).isolate(await fixture());
    assert.equal(result.status, 'usable');
    assert.deepEqual(input.refinedBoundingBox, { left: 0, top: 0, width: result.diagnostics.cropWidth, height: result.diagnostics.cropHeight });
    assert.equal(result.embeddingInput, segmentedImage);
    assert.equal(result.previewCrops.segmentation, preview);
    assert.deepEqual(result.diagnostics.segmentation, { elapsedMs: 12, method: 'fake', status: 'segmented', usedFallback: false, fallbackUsed: false, fallbackReason: undefined });
  });

  it('falls back to the refined crop when a segmenter is unavailable or throws', async () => {
    const config = { ...PRIMARY_SUBJECT_CONFIG, minCropWidth: 1, minCropHeight: 1, minSubjectAreaRatio: 0, minSharpness: 0, minGradientEnergy: 0 };
    for (const segmenter of [
      { async segment() { return { status: 'unavailable', diagnostics: { elapsedMs: 3, method: 'fake', reason: 'unsupported' } }; } },
      { async segment() { throw new Error('provider detail'); } },
    ]) {
      const result = await new PrimarySubjectIsolationService({ async locate() { return single(); } }, new PrimarySubjectCropper(config), config, undefined, segmenter).isolate(await fixture());
      assert.equal(result.status, 'usable');
      assert.equal(result.embeddingInput.bytes.equals(result.previewCrops.final.bytes), true);
      assert.equal(result.diagnostics.segmentation.usedFallback, true);
    }
  });

  it('keeps future segmentation and embedding-input previews behind the preview writer boundary', async () => {
    const writes = new Map();
    const fakeFs = { async mkdir() {}, async writeFile(file, bytes) { writes.set(file, bytes); } };
    const config = { ...PRIMARY_SUBJECT_CONFIG, minCropWidth: 1, minCropHeight: 1, minSubjectAreaRatio: 0, minSharpness: 0, minGradientEnergy: 0 };
    const segmentedImage = { bytes: Buffer.from('segmented-image'), mimeType: 'image/png' };
    const segmenter = { async segment() { return { status: 'segmented', image: segmentedImage, preview: {
      mask: { bytes: Buffer.from('mask-preview'), mimeType: 'image/png' },
      overlay: { bytes: Buffer.from('overlay-preview'), mimeType: 'image/jpeg' },
      subject: { bytes: Buffer.from('subject-preview'), mimeType: 'image/png' },
    }, diagnostics: { elapsedMs: 1, method: 'fake' } }; } };
    const cropper = new PrimarySubjectCropper(config);
    const source = await fixture();
    const result = await new PrimarySubjectIsolationService({ async locate() { return single(); } }, cropper, config, undefined, segmenter).isolate(source);
    assert.equal(result.status, 'usable');
    const artifacts = await new PrimarySubjectPreviewWriter(cropper, fakeFs).write('preview', 'photo.jpg', source, result.candidates.map((candidate) => ({ box: candidate.normalized })), result, false);
    const value = (filename) => writes.get(`preview\\${filename}`) ?? writes.get(`preview/${filename}`);
    assert.equal(artifacts.segmentationMask, 'photo.segmentation-mask.png');
    assert.equal(artifacts.segmentedOverlay, 'photo.segmented-overlay.jpg');
    assert.equal(artifacts.segmentedSubject, 'photo.segmented-subject.png');
    assert.equal(artifacts.embeddingInput, 'photo.embedding-input.png');
    assert.equal(value(artifacts.segmentationMask).toString(), 'mask-preview');
    assert.equal(value(artifacts.segmentedOverlay).toString(), 'overlay-preview');
    assert.equal(value(artifacts.segmentedSubject).toString(), 'subject-preview');
    assert.equal(value(artifacts.embeddingInput).equals(result.embeddingInput.bytes), true);
    const diagnostics = value(artifacts.segmentationJson).toString();
    assert.match(diagnostics, /"outcome": "segmented"/);
    assert.doesNotMatch(diagnostics, /polygon|base64|image bytes|source path|credential|token/i);
  });

  it('passes usable crop rather than original bytes to the existing retrieval path', async () => {
    let embedded; let searches = 0;
    const service = new FigureRetrievalService({ async read() { throw new Error('unused'); } }, { async embedStoredImage(image) { embedded = image; return { vector: Array(1024).fill(1) }; } }, { async search() { searches++; return []; } });
    const crop = { bytes: Buffer.from('crop'), mimeType: 'image/jpeg' };
    await service.retrieveStoredImage(crop, 5);
    assert.equal(embedded, crop); assert.equal(searches, 1);
  });

  it('non-usable isolation performs zero embedding and vector queries', async () => {
    let embeds = 0; let searches = 0;
    const service = new FigureRetrievalService({ async read() { throw new Error('unused'); } }, { async embedStoredImage() { embeds++; return { vector: Array(1024).fill(1) }; } }, { async search() { searches++; return []; } });
    const config = { ...PRIMARY_SUBJECT_CONFIG, minCropWidth: 1, minCropHeight: 1, minSubjectAreaRatio: 0, minSharpness: 9999, minGradientEnergy: 9999 };
    const result = await new PrimarySubjectIsolationService({ async locate() { return single(); } }, new PrimarySubjectCropper(config), config).isolate(await fixture());
    if (result.status === 'usable') await service.retrieveStoredImage(result.crop, 5);
    assert.deepEqual({ embeds, searches }, { embeds: 0, searches: 0 });
  });

  it('writes bounded filename-only overlay/crops, creates directories, and protects overwrite', async () => {
    const writes = new Map(); let mkdirCalls = 0;
    const fakeFs = { async mkdir() { mkdirCalls++; }, async writeFile(file, bytes, options) { if (options.flag === 'wx' && writes.has(file)) { const error = new Error('exists'); error.code = 'EEXIST'; throw error; } writes.set(file, bytes); } };
    const config = { ...PRIMARY_SUBJECT_CONFIG, minCropWidth: 1, minCropHeight: 1, minSubjectAreaRatio: 0, minSharpness: 0 };
    const cropper = new PrimarySubjectCropper(config); const source = await fixture();
    const response = three();
    const result = await new PrimarySubjectIsolationService({ async locate() { return response; } }, cropper, config).isolate(source);
    const writer = new PrimarySubjectPreviewWriter(cropper, fakeFs);
    const previewCandidates = validateLocatorResponse(response).candidates;
    const artifacts = await writer.write('secret/full/path', 'shelf photo.jpg', source, previewCandidates, result, false);
    assert.equal(mkdirCalls, 1); assert.equal(artifacts.crop, 'shelf-photo.subject-crop.jpg'); assert.equal(writes.size, 6);
    assert.equal(artifacts.coarseOverlay, 'shelf-photo.coarse-subject-overlay.jpg');
    assert.equal(artifacts.refinedOverlay, 'shelf-photo.refined-subject-overlay.jpg');
    assert.equal(artifacts.coarseCrop, 'shelf-photo.coarse-subject-crop.jpg');
    assert.equal(artifacts.embeddingInput, 'shelf-photo.embedding-input.jpg');
    assert.equal(artifacts.segmentationJson, 'shelf-photo.segmentation.json');
    const embeddingPreview = writes.get([...writes.keys()].find((name) => name.endsWith('embedding-input.jpg')));
    assert.equal(embeddingPreview.equals(result.embeddingInput.bytes), true);
    const fallbackDiagnostics = writes.get([...writes.keys()].find((name) => name.endsWith('segmentation.json'))).toString();
    assert.match(fallbackDiagnostics, /"outcome": "refined_crop_fallback"/);
    const overlay = writes.get([...writes.keys()].find((name) => name.includes('overlay')));
    assert.deepEqual(await sharp(overlay).metadata().then(({ width, height }) => ({ width, height })), { width: 640, height: 480 });
    assert.ok([...writes.keys()].every((name) => !name.includes('source-image') && !name.includes('base64')));
    await assert.rejects(() => writer.write('secret/full/path', 'shelf photo.jpg', source, previewCandidates, result, false), /exists/);
    await assert.doesNotReject(() => writer.write('secret/full/path', 'shelf photo.jpg', source, previewCandidates, result, true));
  });

  it('writes the evaluated subject crop for a quality-gate rejection without changing its status', async () => {
    const writes = new Map();
    const fakeFs = { async mkdir() {}, async writeFile(file, bytes) { writes.set(file, bytes); } };
    const config = { ...PRIMARY_SUBJECT_CONFIG, minCropWidth: 1, minCropHeight: 1, minSubjectAreaRatio: 0, minSharpness: 9999, minGradientEnergy: 9999 };
    const cropper = new PrimarySubjectCropper(config);
    const source = await fixture();
    const response = single();
    const result = await new PrimarySubjectIsolationService({ async locate() { return response; } }, cropper, config).isolate(source);
    assert.equal(result.status, 'too_blurry');
    assert.deepEqual(result.diagnostics.failedChecks, ['blur']);
    const previewCandidates = result.candidates.map((candidate) => ({ box: candidate.normalized }));
    const artifacts = await new PrimarySubjectPreviewWriter(cropper, fakeFs).write('preview', 'photo.jpg', source, previewCandidates, result, false);
    assert.equal(artifacts.crop, 'photo.subject-crop.jpg');
    assert.ok(writes.has('preview\\photo.coarse-subject-overlay.jpg') || writes.has('preview/photo.coarse-subject-overlay.jpg'));
    assert.ok(writes.has('preview\\photo.refined-subject-overlay.jpg') || writes.has('preview/photo.refined-subject-overlay.jpg'));
    assert.ok(writes.has('preview\\photo.coarse-subject-crop.jpg') || writes.has('preview/photo.coarse-subject-crop.jpg'));
    assert.ok(writes.has('preview\\photo.subject-crop.jpg') || writes.has('preview/photo.subject-crop.jpg'));
  });

  it('writes distinct accepted coarse/refined overlays and exact coarse/final crop bytes', async () => {
    const writes = new Map();
    const fakeFs = { async mkdir() {}, async writeFile(file, bytes) { writes.set(file, bytes); } };
    const config = { ...PRIMARY_SUBJECT_CONFIG, minCropWidth: 1, minCropHeight: 1, minSubjectAreaRatio: 0, minSharpness: 0, minGradientEnergy: 0 };
    const cropper = new PrimarySubjectCropper(config); const source = await fixture();
    const refinement = new PrimarySubjectRefinementService({ async refine() { return { bbox: [100, 100, 900, 900] }; } }, cropper, config);
    const result = await new PrimarySubjectIsolationService({ async locate() { return single(); } }, cropper, config, refinement).isolate(source);
    assert.equal(result.status, 'usable');
    const candidates = result.candidates.map((candidate) => ({ box: candidate.normalized }));
    const artifacts = await new PrimarySubjectPreviewWriter(cropper, fakeFs).write('preview', 'photo.jpg', source, candidates, result, false);
    const value = (filename) => writes.get(`preview\\${filename}`) ?? writes.get(`preview/${filename}`);
    assert.equal(value(artifacts.coarseCrop).equals(result.previewCrops.coarse.bytes), true);
    assert.equal(value(artifacts.crop).equals(result.crop.bytes), true);
    assert.equal(value(artifacts.coarseOverlay).equals(value(artifacts.refinedOverlay)), false);
  });
});

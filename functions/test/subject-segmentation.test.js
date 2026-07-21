'use strict';

const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const sharp = require('sharp');
const { PRIMARY_SUBJECT_CONFIG } = require('../lib/figureRecognition/primarySubjectConfig');
const { GeminiSubjectSegmenter, PRIMARY_SUBJECT_SEGMENTATION_PROMPT } = require('../lib/figureRecognition/geminiSubjectSegmenter');
const { validatePolygon, rasterizeAndProcessPolygon, processBinaryMask, renderSegmentedSubject } = require('../lib/figureRecognition/subjectMaskProcessor');

const square = [[150, 150], [850, 150], [850, 850], [150, 850]];
const response = (polygons = [{ points: square }]) => JSON.stringify({ polygons });
const box = { left: 0, top: 0, width: 100, height: 100 };
const segmentationConfig = (overrides = {}) => ({ ...PRIMARY_SUBJECT_CONFIG.segmentation, ...overrides });

async function image(width = 100, height = 100) {
  const bytes = await sharp({ create: { width, height, channels: 3, background: { r: 160, g: 90, b: 120 } } }).png().toBuffer();
  return { bytes, mimeType: 'image/png' };
}

describe('GeminiSubjectSegmenter adapter', () => {
  it('uses Vertex ADC, centralized settings, strict JSON, and the fixed same-subject prompt', async () => {
    let options; let request;
    const client = { models: { async generateContent(value) { request = value; return { text: response() }; } } };
    const segmenter = new GeminiSubjectSegmenter('project', PRIMARY_SUBJECT_CONFIG, undefined, (value) => { options = value; return client; });
    const result = await segmenter.segment({ image: await image(), refinedBoundingBox: box });
    assert.equal(result.status, 'segmented');
    assert.deepEqual(options, { vertexai: true, project: 'project', location: 'us' });
    assert.equal(request.model, PRIMARY_SUBJECT_CONFIG.model);
    assert.equal(request.config.temperature, 0);
    assert.equal(request.config.mediaResolution, 'MEDIA_RESOLUTION_HIGH');
    assert.equal(request.config.responseMimeType, 'application/json');
    assert.equal(request.config.responseJsonSchema.additionalProperties, false);
    assert.equal(request.config.responseJsonSchema.properties.polygons.maxItems, 1);
    assert.match(PRIMARY_SUBJECT_SEGMENTATION_PROMPT, /same physical collectible/);
    for (const term of ['beverage cans', 'shelves', 'hands', 'reflections', 'background figures']) assert.match(PRIMARY_SUBJECT_SEGMENTATION_PROMPT, new RegExp(term));
    assert.match(PRIMARY_SUBJECT_SEGMENTATION_PROMPT, /Do not identify, name, classify, or describe/);
    assert.equal(result.diagnostics.promptVersion, 'primary-subject-segmentation-v1');
    assert.equal('apiKey' in options, false);
  });

  it('accepts one polygon and keeps model prose and private coordinates out of diagnostics', async () => {
    const client = { models: { async generateContent() { return { text: response() }; } } };
    const result = await new GeminiSubjectSegmenter('project', PRIMARY_SUBJECT_CONFIG, client).segment({ image: await image(), refinedBoundingBox: box });
    assert.equal(result.status, 'segmented');
    assert.equal(result.image.mimeType, 'image/png');
    assert.equal(result.mask.coordinateSpace, 'segmentation-input');
    const serialized = JSON.stringify(result.diagnostics);
    assert.doesNotMatch(serialized, /150,150|base64|reasoning/);
  });

  it('fails closed for empty, competing, malformed, unknown, and invalid responses without retrying', async () => {
    const cases = [
      JSON.stringify({ polygons: [] }),
      response([{ points: square }, { points: square }]),
      '{',
      JSON.stringify({ polygons: [{ points: square, label: 'prose' }] }),
      JSON.stringify({ polygons: [{ points: [[1, 2], [3, 4]] }] }),
    ];
    for (const text of cases) {
      let calls = 0;
      const client = { models: { async generateContent() { calls++; return { text }; } } };
      const result = await new GeminiSubjectSegmenter('project', PRIMARY_SUBJECT_CONFIG, client).segment({ image: await image(), refinedBoundingBox: box });
      assert.equal(result.status, 'unavailable'); assert.equal(calls, 1);
      assert.equal('text' in result.diagnostics, false);
    }
  });

  it('retries only transient transport failures at most three times', async () => {
    let calls = 0; const delays = [];
    const client = { models: { async generateContent() { calls++; if (calls < 3) throw { code: 429 }; return { text: response() }; } } };
    const result = await new GeminiSubjectSegmenter('project', PRIMARY_SUBJECT_CONFIG, client, undefined, async (ms) => delays.push(ms)).segment({ image: await image(), refinedBoundingBox: box });
    assert.equal(result.status, 'segmented'); assert.deepEqual({ calls, delays }, { calls: 3, delays: [400, 800] });
    calls = 0;
    const bad = new GeminiSubjectSegmenter('project', PRIMARY_SUBJECT_CONFIG, { models: { async generateContent() { calls++; throw { code: 400 }; } } });
    assert.equal((await bad.segment({ image: await image(), refinedBoundingBox: box })).status, 'unavailable'); assert.equal(calls, 1);
  });
});

describe('polygon validation and deterministic mask processing', () => {
  it('accepts a valid polygon, minimally clamps boundary overflow, and recomputes pixel bounds', () => {
    const points = validatePolygon([[-1, 100], [900, 100], [900, 900], [-1, 900]], segmentationConfig());
    assert.equal(points[0][0], 0);
    const result = rasterizeAndProcessPolygon(points, 100, 80, { left: 0, top: 0, width: 100, height: 80 }, segmentationConfig());
    assert.ok(result.tightBoundingBox.width > result.tightBoundingBox.height);
    assert.ok(result.mask.data.some((value) => value === 255));
  });

  it('rejects invalid point count, non-finite, overflow, zero-area, self-intersection, and excessive points', () => {
    const config = segmentationConfig({ maxPolygonPoints: 5 });
    for (const polygon of [
      [[1, 1], [2, 2]],
      [[1, 1], [2, 2], [NaN, 3]],
      [[-2, 1], [20, 20], [30, 10]],
      [[1, 1], [2, 2], [3, 3]],
      [[100, 100], [900, 900], [100, 900], [900, 100]],
      [[0, 0], [200, 0], [400, 0], [600, 100], [800, 200], [0, 500]],
    ]) assert.throws(() => validatePolygon(polygon, config));
  });

  it('rejects a distant corner, too-small foreground, and implausibly large foreground', () => {
    assert.throws(() => rasterizeAndProcessPolygon(validatePolygon([[0, 0], [250, 0], [250, 250], [0, 250]], segmentationConfig()), 100, 100, box, segmentationConfig()), /foreground_misses_anchor/);
    const tinyConfig = segmentationConfig({ minForegroundAreaRatio: 0.1 });
    assert.throws(() => rasterizeAndProcessPolygon(validatePolygon([[450, 450], [550, 450], [550, 550], [450, 550]], tinyConfig), 100, 100, box, tinyConfig), /foreground_too_small/);
    const largeConfig = segmentationConfig({ maxForegroundAreaRatio: 0.5 });
    assert.throws(() => rasterizeAndProcessPolygon(validatePolygon([[0, 0], [1000, 0], [1000, 1000], [0, 1000]], largeConfig), 100, 100, box, largeConfig), /foreground_too_large/);
  });

  it('retains the anchored component, removes distant noise, fills small holes, and preserves a large hole', () => {
    const width = 60; const height = 60; const mask = new Uint8Array(width * height);
    for (let y = 10; y < 50; y++) for (let x = 10; x < 50; x++) mask[y * width + x] = 255;
    mask[30 * width + 30] = 0;
    for (let y = 20; y < 28; y++) for (let x = 20; x < 28; x++) mask[y * width + x] = 0;
    mask[1] = 255;
    const result = processBinaryMask(mask, width, height, { left: 0, top: 0, width, height }, segmentationConfig({ maxHolePixels: 4, maxHoleAreaRatio: 1 }));
    assert.equal(result.connectedComponentCount, 2);
    assert.equal(result.mask.data[1], 0);
    assert.equal(result.mask.data[30 * width + 30], 255);
    assert.equal(result.mask.data[23 * width + 23], 0);
  });

  it('preserves thin attached features and applies padding without square forcing', () => {
    const polygon = [[300, 200], [450, 200], [480, 20], [510, 200], [700, 200], [700, 800], [300, 800]];
    const result = rasterizeAndProcessPolygon(validatePolygon(polygon, segmentationConfig()), 200, 100, { left: 0, top: 0, width: 200, height: 100 }, segmentationConfig());
    assert.ok(result.mask.data.some((value, index) => value && Math.floor(index / 200) < 10));
    assert.notEqual(result.tightBoundingBox.width, result.tightBoundingBox.height);
  });

  it('renders an undistorted transparent PNG whose alpha matches the final mask', async () => {
    const source = await image(100, 100);
    const processed = rasterizeAndProcessPolygon(validatePolygon(square, segmentationConfig()), 100, 100, box, segmentationConfig());
    const rendered = await renderSegmentedSubject(source, processed);
    const metadata = await sharp(rendered.image.bytes).metadata();
    assert.equal(rendered.image.mimeType, 'image/png'); assert.equal(metadata.hasAlpha, true);
    assert.deepEqual([metadata.width, metadata.height], [processed.tightBoundingBox.width, processed.tightBoundingBox.height]);
    const raw = await sharp(rendered.image.bytes).raw().toBuffer({ resolveWithObject: true });
    const alpha = (x, y) => raw.data[(y * raw.info.width + x) * raw.info.channels + 3];
    assert.equal(alpha(0, 0), 0);
    assert.equal(alpha(Math.floor(raw.info.width / 2), Math.floor(raw.info.height / 2)), 255);
    assert.equal(rendered.preview.mask.mimeType, 'image/png'); assert.equal(rendered.preview.overlay.mimeType, 'image/jpeg');
  });
});

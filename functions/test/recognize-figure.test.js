const assert = require('node:assert/strict');
const { describe, it } = require('node:test');
const sharp = require('sharp');
const { RecognizeFigureService } = require('../lib/figureRecognition/recognizeFigureService');
const { validateRecognizeFigureRequest } = require('../lib/figureRecognition/recognizeFigureRequestValidator');

const request = (dataBase64 = '') => ({ version: 1, image: { dataBase64, mimeType: 'image/png' }, selection: { left: .1, top: .2, width: .3, height: .4, coordinateSpace: 'normalized_oriented_image' } });

describe('recognizeFigureV1 orchestration', () => {
  it('validates original image plus normalized oriented-image selection', async () => {
    const bytes = await sharp({ create: { width: 20, height: 10, channels: 3, background: 'white' } }).png().toBuffer();
    const validated = await validateRecognizeFigureRequest(request(bytes.toString('base64')));
    assert.equal(validated.image.bytes.equals(bytes), true);
    assert.deepEqual(validated.request.selection, request().selection);
    await assert.rejects(() => validateRecognizeFigureRequest({ ...request(bytes.toString('base64')), selection: { ...request().selection, width: .95 } }), /invalid_selection/);
  });

  it('uses exact unpadded canonical crop, frozen quality result, retrieval and shadow decision', async () => {
    const calls = [];
    const cropImage = { bytes: Buffer.from('crop'), mimeType: 'image/jpeg' };
    const cropper = {
      orient: async (image) => (calls.push(['orient', image]), { width: 1000, height: 500 }),
      pixelBox: (box, width, height, padded) => (calls.push(['pixelBox', box, width, height, padded]), { left: 100, top: 100, width: 300, height: 200 }),
      cropPixelBox: async (_prepared, box) => (calls.push(['crop', box]), { image: cropImage }),
    };
    const blur = { evaluateImage: async (image) => (calls.push(['blur', image]), { quality: 'good', evaluatorVersion: 'blur-quality-v1' }) };
    const candidates = [{ figureId: 'f1', seriesId: 's1', brandId: 'b1', ipId: 'i1', rank: 1, distance: .2, isSecret: false, embeddingSpace: 'x' }];
    const retrieval = { retrieveStoredImage: async (image, topK) => (calls.push(['retrieve', image, topK]), candidates) };
    const resolver = { decide: (evidence) => (calls.push(['decide', evidence]), { outcome: 'needs_review', candidates, policyVersion: 'retrieval-policy-shadow-v1' }) };
    const hydrated = [{ rank: 1, figureId: 'f1', figureName: 'Figure', seriesId: 's1', seriesName: 'Series', ipId: 'i1', ipName: 'IP', imageKey: 'figure' }];
    const hydrator = { hydrate: async (input) => (calls.push(['hydrate', input]), hydrated) };
    const service = new RecognizeFigureService(cropper, blur, retrieval, resolver, hydrator);
    const response = await service.recognize(request(), { bytes: Buffer.from('original'), mimeType: 'image/png' });
    assert.equal(calls.find((call) => call[0] === 'pixelBox')[4], false);
    assert.equal(calls.find((call) => call[0] === 'blur')[1], cropImage);
    assert.equal(calls.find((call) => call[0] === 'retrieve')[1], cropImage);
    assert.deepEqual(response, { version: 1, status: 'candidates', subjectQuality: 'good', blurEvaluatorVersion: 'blur-quality-v1', policyVersion: 'retrieval-policy-shadow-v1', decision: 'needs_review', candidates: hydrated });
  });

  it('blocks too blurry, pauses borderline, and preserves no-match semantics', async () => {
    const baseCropper = { orient: async () => ({ width: 10, height: 10 }), pixelBox: () => ({ left: 0, top: 0, width: 10, height: 10 }), cropPixelBox: async () => ({ image: { bytes: Buffer.from('crop'), mimeType: 'image/jpeg' } }) };
    let retrievalCalls = 0;
    const retrieval = { retrieveStoredImage: async () => { retrievalCalls++; return []; } };
    const resolver = { decide: () => ({ outcome: 'no_confident_match', policyVersion: 'retrieval-policy-shadow-v1' }) };
    const hydrator = { hydrate: async () => { throw new Error('must not hydrate'); } };
    for (const quality of ['too_blurry', 'borderline']) {
      const service = new RecognizeFigureService(baseCropper, { evaluateImage: async () => ({ quality, evaluatorVersion: 'blur-quality-v1' }) }, retrieval, resolver, hydrator);
      assert.equal((await service.recognize(request(), { bytes: Buffer.from('original'), mimeType: 'image/png' })).status, quality);
    }
    assert.equal(retrievalCalls, 0);
    const service = new RecognizeFigureService(baseCropper, { evaluateImage: async () => ({ quality: 'borderline', evaluatorVersion: 'blur-quality-v1' }) }, retrieval, resolver, hydrator);
    assert.equal((await service.recognize({ ...request(), continueBorderline: true }, { bytes: Buffer.from('original'), mimeType: 'image/png' })).status, 'no_confident_match');
    assert.equal(retrievalCalls, 1);
  });
});

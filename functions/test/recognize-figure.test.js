const assert = require('node:assert/strict');
const { describe, it } = require('node:test');
const sharp = require('sharp');
const { RecognizeFigureService } = require('../lib/figureRecognition/recognizeFigureService');
const { validateRecognizeFigureRequest } = require('../lib/figureRecognition/recognizeFigureRequestValidator');

const request = (dataBase64 = '') => ({ version: 2, image: { dataBase64, mimeType: 'image/png', role: 'selected_subject_crop' } });
const unusedCropper = { orient: async () => { throw new Error('new contract must not orient'); }, pixelBox: () => { throw new Error('new contract must not map a box'); }, cropPixelBox: async () => { throw new Error('new contract must not crop'); } };
const mockRetrieval = (retrieve) => ({
  retrieveStoredImageWithDiagnostics: async (image, topK, onTiming, options) => {
    const candidates = await retrieve(image, topK, onTiming, options);
    return {
      candidates,
      diagnostics: {
        userEmbeddingMs: 0, vectorSearchMs: 0, aggregationMs: 0, totalMs: 0,
        candidateImageCount: candidates.length, candidateFigureCount: candidates.length,
        alternativeMatchCount: 0, vectorSearchCalls: 1, userEmbeddingCalls: 1,
      },
    };
  },
});

describe('recognizeFigureV1 orchestration', () => {
  it('validates a version 2 selected-subject crop and rejects a mislabeled image role', async () => {
    const bytes = await sharp({ create: { width: 20, height: 10, channels: 3, background: 'white' } }).png().toBuffer();
    const validated = await validateRecognizeFigureRequest(request(bytes.toString('base64')));
    assert.equal(validated.image.bytes.equals(bytes), true);
    assert.equal(validated.request.version, 2);
    await assert.rejects(() => validateRecognizeFigureRequest({ ...request(bytes.toString('base64')), image: { ...request().image, dataBase64: bytes.toString('base64'), role: 'original_image' } }), /invalid_request/);
  });

  it('preserves strict canonical base64 validation', async () => {
    const bytes = await sharp({ create: { width: 20, height: 10, channels: 3, background: 'white' } }).png().toBuffer();
    await validateRecognizeFigureRequest(request(bytes.toString('base64')));
    for (const malformed of ['/x==', '/w=', '/w===', '=w==', '/w==\n']) {
      await assert.rejects(
        () => validateRecognizeFigureRequest(request(malformed)),
        (error) => error?.name === 'RecognizeFigureRequestError',
      );
    }
  });

  it('keeps the version 1 original-image contract valid for rolling deploys', async () => {
    const bytes = await sharp({ create: { width: 20, height: 10, channels: 3, background: 'white' } }).png().toBuffer();
    const legacy = { version: 1, image: { dataBase64: bytes.toString('base64'), mimeType: 'image/png' }, selection: { left: .1, top: .2, width: .3, height: .4, coordinateSpace: 'normalized_oriented_image' } };
    assert.equal((await validateRecognizeFigureRequest(legacy)).request.version, 1);
  });

  it('uses the supplied crop directly for frozen quality, retrieval and candidate decision', async () => {
    const calls = [];
    const cropImage = { bytes: Buffer.from('crop'), mimeType: 'image/jpeg' };
    const blur = { evaluateImage: async (image) => (calls.push(['blur', image]), { quality: 'good', usable: true, evaluatorVersion: 'blur-quality-v1' }) };
    const candidates = [{ figureId: 'f1', seriesId: 's1', brandId: 'b1', ipId: 'i1', rank: 1, distance: .2, isSecret: false, embeddingSpace: 'x' }];
    const retrieval = mockRetrieval(async (image, topK) => (calls.push(['retrieve', image, topK]), candidates));
    const resolver = { decide: (evidence) => (calls.push(['decide', evidence]), { outcome: 'needs_review', candidates, policyVersion: 'retrieval-policy-candidate-v1' }) };
    const hydrated = [{ rank: 1, figureId: 'f1', figureName: 'Figure', seriesId: 's1', seriesName: 'Series', ipId: 'i1', ipName: 'IP', imageKey: 'figure' }];
    const hydrator = { hydrate: async (input) => (calls.push(['hydrate', input]), hydrated) };
    const service = new RecognizeFigureService(unusedCropper, blur, retrieval, resolver, hydrator);
    const response = await service.recognize(request(), cropImage);
    assert.equal(calls.find((call) => call[0] === 'blur')[1], cropImage);
    assert.equal(calls.find((call) => call[0] === 'retrieve')[1], cropImage);
    assert.equal(calls.find((call) => call[0] === 'decide')[1].calibrationProfile, 'figure-image-retrieval-v1');
    assert.deepEqual(response, { version: 1, status: 'candidates', subjectQuality: 'good', blurEvaluatorVersion: 'blur-quality-v1', policyVersion: 'retrieval-policy-candidate-v1', decision: 'needs_review', candidates: hydrated });
  });

  it('hydrates candidates for high_confidence without downgrading the decision', async () => {
    const calls = [];
    const cropImage = { bytes: Buffer.from('crop'), mimeType: 'image/jpeg' };
    const candidates = [
      { figureId: 'f1', seriesId: 's1', brandId: 'b1', ipId: 'i1', rank: 1, distance: .1, isSecret: false, embeddingSpace: 'x' },
      { figureId: 'f2', seriesId: 's2', brandId: 'b1', ipId: 'i1', rank: 2, distance: .2, isSecret: false, embeddingSpace: 'x' },
    ];
    const hydrated = [
      { rank: 1, figureId: 'f1', figureName: 'Figure', seriesId: 's1', seriesName: 'Series', ipId: 'i1', ipName: 'IP', imageKey: 'figure' },
      { rank: 2, figureId: 'f2', figureName: 'Figure 2', seriesId: 's2', seriesName: 'Series 2', ipId: 'i1', ipName: 'IP', imageKey: 'figure-2' },
    ];
    const service = new RecognizeFigureService(
      unusedCropper,
      { evaluateImage: async () => ({ quality: 'good', usable: true, evaluatorVersion: 'blur-quality-v1' }) },
      mockRetrieval(async () => candidates),
      { decide: () => ({ outcome: 'high_confidence', candidate: candidates[0], policyVersion: 'retrieval-policy-candidate-v1' }) },
      { hydrate: async (input) => (calls.push(['hydrate', input]), hydrated) },
    );
    const response = await service.recognize(request(), cropImage);
    assert.deepEqual(calls[0][1], candidates);
    assert.equal(response.status, 'candidates');
    assert.equal(response.decision, 'high_confidence');
    assert.deepEqual(response.candidates, hydrated);
  });

  it('does not hydrate when the decision is no_confident_match', async () => {
    let hydrateCalls = 0;
    const cropImage = { bytes: Buffer.from('crop'), mimeType: 'image/jpeg' };
    const service = new RecognizeFigureService(
      unusedCropper,
      { evaluateImage: async () => ({ quality: 'good', usable: true, evaluatorVersion: 'blur-quality-v1' }) },
      mockRetrieval(async () => [{ figureId: 'f1', seriesId: 's1', brandId: 'b1', ipId: 'i1', rank: 1, distance: .5, isSecret: false, embeddingSpace: 'x' }]),
      { decide: () => ({ outcome: 'no_confident_match', policyVersion: 'retrieval-policy-candidate-v1' }) },
      { hydrate: async () => { hydrateCalls++; throw new Error('must not hydrate'); } },
    );
    const response = await service.recognize(request(), cropImage);
    assert.equal(response.status, 'no_confident_match');
    assert.equal(hydrateCalls, 0);
    assert.equal('candidates' in response, false);
  });

  it('uses evaluator usability so good and borderline proceed while too blurry blocks', async () => {
    const cropImage = { bytes: Buffer.from('crop'), mimeType: 'image/jpeg' };
    let retrievalCalls = 0;
    const retrieval = mockRetrieval(async () => { retrievalCalls++; return []; });
    const resolver = { decide: () => ({ outcome: 'no_confident_match', policyVersion: 'retrieval-policy-candidate-v1' }) };
    const hydrator = { hydrate: async () => { throw new Error('must not hydrate'); } };
    for (const quality of ['good', 'borderline']) {
      const service = new RecognizeFigureService(unusedCropper, { evaluateImage: async () => ({ quality, usable: true, evaluatorVersion: 'blur-quality-v1' }) }, retrieval, resolver, hydrator);
      const result = await service.recognize(request(), cropImage);
      assert.equal(result.status, 'no_confident_match');
      assert.equal(result.subjectQuality, quality);
    }
    assert.equal(retrievalCalls, 2);
    const service = new RecognizeFigureService(unusedCropper, { evaluateImage: async () => ({ quality: 'too_blurry', usable: false, evaluatorVersion: 'blur-quality-v1' }) }, retrieval, resolver, hydrator);
    assert.equal((await service.recognize(request(), cropImage)).status, 'too_blurry');
    assert.equal(retrievalCalls, 2);
  });

  it('wires production to the candidate resolver, not the shadow resolver', async () => {
    const { createProductionRetrievalDecisionResolver } = require('../lib/recognizeFigureCallable');
    const { CandidateRetrievalDecisionResolver } = require('../lib/figureRecognition/retrievalCandidatePolicyResolver');
    const { ShadowRetrievalDecisionResolver } = require('../lib/figureRecognition/retrievalDecisionResolver');
    const { RETRIEVAL_CANDIDATE_POLICY_CONFIG } = require('../lib/figureRecognition/retrievalCandidatePolicyConfig');
    const resolver = createProductionRetrievalDecisionResolver();
    assert.equal(resolver instanceof CandidateRetrievalDecisionResolver, true);
    assert.equal(resolver instanceof ShadowRetrievalDecisionResolver, false);
    const braceletLike = [
      { figureId: 'figure-1', seriesId: 'series-a', ipId: 'ip-a', brandId: 'brand-a', isSecret: false, distance: 0.41, rank: 1, embeddingSpace: 'opaque-space' },
      { figureId: 'figure-2', seriesId: 'series-a', ipId: 'ip-a', brandId: 'brand-a', isSecret: false, distance: 0.44, rank: 2, embeddingSpace: 'opaque-space' },
      { figureId: 'figure-3', seriesId: 'series-b', ipId: 'ip-a', brandId: 'brand-a', isSecret: false, distance: 0.47, rank: 3, embeddingSpace: 'opaque-space' },
    ];
    const decision = resolver.decide({
      candidates: braceletLike,
      requestedTopK: 5,
      distanceSemantics: 'lower_is_better',
      calibrationProfile: RETRIEVAL_CANDIDATE_POLICY_CONFIG.calibrationProfile,
    });
    assert.equal(decision.outcome, 'no_confident_match');
    assert.equal(decision.policyVersion, 'retrieval-policy-candidate-v1');
  });

  it('accepts legacy continueBorderline without requiring or using it', async () => {
    const bytes = await sharp({ create: { width: 20, height: 10, channels: 3, background: 'white' } }).png().toBuffer();
    const legacy = { version: 1, image: { dataBase64: bytes.toString('base64'), mimeType: 'image/png' }, selection: { left: .1, top: .2, width: .3, height: .4, coordinateSpace: 'normalized_oriented_image' }, continueBorderline: false };
    assert.equal((await validateRecognizeFigureRequest(legacy)).request.continueBorderline, false);
  });

  it('accepts optional seriesId and trims it for Series Scan', async () => {
    const bytes = await sharp({ create: { width: 20, height: 10, channels: 3, background: 'white' } }).png().toBuffer();
    const validated = await validateRecognizeFigureRequest({
      ...request(bytes.toString('base64')),
      seriesId: '  series_a  ',
    });
    assert.equal(validated.request.seriesId, 'series_a');
  });

  it('rejects malformed seriesId without embedding or retrieval', async () => {
    const bytes = await sharp({ create: { width: 20, height: 10, channels: 3, background: 'white' } }).png().toBuffer();
    for (const seriesId of ['', '   ', 'bad id', 12, 'x'.repeat(129)]) {
      await assert.rejects(
        () => validateRecognizeFigureRequest({ ...request(bytes.toString('base64')), seriesId }),
        (error) => error?.name === 'RecognizeFigureRequestError' && error.reason === 'invalid_request',
      );
    }
  });

  it('uses series-scoped Top-K and filter when seriesId is present', async () => {
    const calls = [];
    const cropImage = { bytes: Buffer.from('crop'), mimeType: 'image/jpeg' };
    const candidates = [
      { figureId: 'fa', seriesId: 'series_a', brandId: 'b1', ipId: 'i1', rank: 1, distance: .2, isSecret: false, embeddingSpace: 'x' },
      { figureId: 'fb', seriesId: 'series_b', brandId: 'b1', ipId: 'i1', rank: 2, distance: .1, isSecret: false, embeddingSpace: 'x' },
    ];
    const retrieval = mockRetrieval(async (image, topK, _onTiming, options) => {
      calls.push(['retrieve', topK, options]);
      return candidates;
    });
    const hydrated = [{ rank: 1, figureId: 'fa', figureName: 'Figure', seriesId: 'series_a', seriesName: 'Series', ipId: 'i1', ipName: 'IP', imageKey: 'figure' }];
    const service = new RecognizeFigureService(
      unusedCropper,
      { evaluateImage: async () => ({ quality: 'good', usable: true, evaluatorVersion: 'blur-quality-v1' }) },
      retrieval,
      { decide: (evidence) => (calls.push(['decide', evidence.candidates.map((c) => c.figureId)]), { outcome: 'needs_review', candidates: evidence.candidates, policyVersion: 'retrieval-policy-candidate-v1' }) },
      { hydrate: async (input) => (calls.push(['hydrate', input.map((c) => c.seriesId)]), hydrated) },
    );
    const response = await service.recognize({ ...request(), seriesId: 'series_a' }, cropImage);
    assert.deepEqual(calls[0], ['retrieve', 15, { seriesId: 'series_a' }]);
    assert.deepEqual(calls[1][1], ['fa']);
    assert.deepEqual(calls[2][1], ['series_a']);
    assert.equal(response.status, 'candidates');
    assert.deepEqual(response.candidates.map((c) => c.seriesId), ['series_a']);
  });

  it('keeps legacy global Top-K when seriesId is absent', async () => {
    const calls = [];
    const cropImage = { bytes: Buffer.from('crop'), mimeType: 'image/jpeg' };
    const service = new RecognizeFigureService(
      unusedCropper,
      { evaluateImage: async () => ({ quality: 'good', usable: true, evaluatorVersion: 'blur-quality-v1' }) },
      mockRetrieval(async (_image, topK, _onTiming, options) => {
        calls.push([topK, options]);
        return [];
      }),
      { decide: () => ({ outcome: 'no_confident_match', policyVersion: 'retrieval-policy-candidate-v1' }) },
      { hydrate: async () => { throw new Error('must not hydrate'); } },
    );
    await service.recognize(request(), cropImage);
    assert.deepEqual(calls, [[5, undefined]]);
  });

  it('excludes cross-series hydrated records and returns no_confident_match when none remain', async () => {
    const cropImage = { bytes: Buffer.from('crop'), mimeType: 'image/jpeg' };
    const candidates = [
      { figureId: 'fa', seriesId: 'series_a', brandId: 'b1', ipId: 'i1', rank: 1, distance: .2, isSecret: false, embeddingSpace: 'x' },
    ];
    const service = new RecognizeFigureService(
      unusedCropper,
      { evaluateImage: async () => ({ quality: 'good', usable: true, evaluatorVersion: 'blur-quality-v1' }) },
      mockRetrieval(async () => candidates),
      { decide: () => ({ outcome: 'needs_review', candidates, policyVersion: 'retrieval-policy-candidate-v1' }) },
      { hydrate: async () => [{ rank: 1, figureId: 'fa', figureName: 'Figure', seriesId: 'series_b', seriesName: 'Other', ipId: 'i1', ipName: 'IP', imageKey: 'figure' }] },
    );
    const response = await service.recognize({ ...request(), seriesId: 'series_a' }, cropImage);
    assert.equal(response.status, 'no_confident_match');
  });

  it('treats a valid unknown series as empty retrieval without global fallback', async () => {
    const cropImage = { bytes: Buffer.from('crop'), mimeType: 'image/jpeg' };
    let optionsSeen;
    const service = new RecognizeFigureService(
      unusedCropper,
      { evaluateImage: async () => ({ quality: 'good', usable: true, evaluatorVersion: 'blur-quality-v1' }) },
      mockRetrieval(async (_image, _topK, _onTiming, options) => {
        optionsSeen = options;
        return [];
      }),
      { decide: () => ({ outcome: 'no_confident_match', policyVersion: 'retrieval-policy-candidate-v1' }) },
      { hydrate: async () => { throw new Error('must not hydrate'); } },
    );
    const response = await service.recognize({ ...request(), seriesId: 'unknown_series_id' }, cropImage);
    assert.deepEqual(optionsSeen, { seriesId: 'unknown_series_id' });
    assert.equal(response.status, 'no_confident_match');
  });
});

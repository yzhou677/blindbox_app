'use strict';

const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs/promises');
const os = require('node:os');
const path = require('node:path');
const { LocalImageReader } = require('../lib/figureRecognition/localImageReader');
const { FigureRetrievalEvaluationManifestLoader, validateManifest } = require('../lib/figureRecognition/figureRetrievalEvaluationManifest');
const { FigureRetrievalEvaluationRunner } = require('../lib/figureRecognition/figureRetrievalEvaluationRunner');
const { aggregateFigureRetrievalEvaluation, describeDistribution } = require('../lib/figureRecognition/figureRetrievalEvaluationMetrics');
const { FigureRetrievalEvaluationWriter, toCsv } = require('../lib/figureRecognition/figureRetrievalEvaluationWriter');
const { parseFigureRetrievalEvaluationArgs, formatEvaluationProgress, formatRetrievalDebug } = require('../lib/figureRecognition/figureRetrievalEvaluationCli');
const { filterEvaluationCases } = require('../lib/figureRecognition/figureRetrievalEvaluationCli');
const { FigureRetrievalEvaluationPreviewWriter } = require('../lib/figureRecognition/figureRetrievalEvaluationPreviewWriter');
const { ShadowRetrievalDecisionResolver } = require('../lib/figureRecognition/retrievalDecisionResolver');
const { RETRIEVAL_DECISION_CONFIG } = require('../lib/figureRecognition/retrievalDecisionConfig');
const { RETRIEVAL_CANDIDATE_POLICY_CONFIG } = require('../lib/figureRecognition/retrievalCandidatePolicyConfig');
const { CandidateRetrievalDecisionResolver } = require('../lib/figureRecognition/retrievalCandidatePolicyResolver');

const present = (overrides = {}) => ({ id: 'present-1', file: 'photo.jpg', expectedFigureId: 'expected', catalogPresence: 'present', ...overrides });
const absent = (overrides = {}) => ({ id: 'absent-1', file: 'unknown.jpg', catalogPresence: 'absent', ...overrides });
const presentPhoto = (overrides = {}) => ({ file: 'photo.jpg', expectedFigureId: 'expected', catalogPresence: 'present', ...overrides });
const absentPhoto = (overrides = {}) => ({ file: 'unknown.jpg', catalogPresence: 'absent', ...overrides });
const candidate = (rank, figureId, distance, seriesId = 'series-a') => ({ figureId, seriesId, brandId: 'brand-a', ipId: 'ip-a', isSecret: false, distance, rank, embeddingSpace: 'space' });
const decisionResolver = new ShadowRetrievalDecisionResolver(RETRIEVAL_DECISION_CONFIG);
const candidateDecisionResolver = new CandidateRetrievalDecisionResolver(RETRIEVAL_CANDIDATE_POLICY_CONFIG);
const png = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);

async function temporaryDirectory() { return fs.mkdtemp(path.join(os.tmpdir(), 'shelfy-eval-')); }

describe('evaluation manifest', () => {
  it('accepts strict present and absent photos with a required dataset', () => {
    const result = validateManifest({ version: 1, dataset: 'golden-v1', photos: [presentPhoto(), absentPhoto()] });
    assert.equal(result.dataset, 'golden-v1'); assert.equal(result.photos[0].expectedFigureId, 'expected'); assert.equal(result.photos[1].expectedFigureId, undefined);
  });

  it('resolves relative and absolute paths and preflights every image', async () => {
    const directory = await temporaryDirectory();
    try {
      const relative = path.join(directory, 'relative.png'); const absolute = path.join(directory, 'absolute.png');
      await fs.writeFile(relative, png); await fs.writeFile(absolute, png);
      const manifestPath = path.join(directory, 'manifest.json');
      await fs.writeFile(manifestPath, JSON.stringify({ version: 1, dataset: 'golden-v1', photos: [presentPhoto({ file: 'relative.png' }), absentPhoto({ file: absolute })] }));
      const loaded = await new FigureRetrievalEvaluationManifestLoader(new LocalImageReader()).load(manifestPath);
      assert.equal(loaded.dataset, 'golden-v1'); assert.deepEqual(loaded.photos.map((entry) => entry.filePath), [relative, absolute]);
      assert.deepEqual(loaded.photos.map((entry) => entry.id), ['photo-0001', 'photo-0002']);
      await fs.writeFile(manifestPath, JSON.stringify({ version: 1, dataset: 'golden-v1', photos: [presentPhoto({ file: 'relative.png' }), absentPhoto({ file: relative })] }));
      await assert.rejects(() => new FigureRetrievalEvaluationManifestLoader(new LocalImageReader()).load(manifestPath), /duplicate photo/i);
    } finally { await fs.rm(directory, { recursive: true, force: true }); }
  });

  it('rejects missing dataset, empty photos, duplicates, unsupported versions, and contradictory labels', () => {
    assert.throws(() => validateManifest({ version: 2, dataset: 'golden-v1', photos: [presentPhoto()] }));
    assert.throws(() => validateManifest({ version: 1, photos: [presentPhoto()] }), /dataset/);
    assert.throws(() => validateManifest({ version: 1, dataset: 'golden-v1', photos: [] }), /non-empty photos/);
    assert.throws(() => validateManifest({ version: 1, dataset: 'golden-v1', photos: [presentPhoto(), presentPhoto()] }), /duplicate photo/i);
    assert.throws(() => validateManifest({ version: 1, dataset: 'golden-v1', photos: [presentPhoto({ expectedFigureId: undefined })] }), /requires expectedFigureId/);
    assert.throws(() => validateManifest({ version: 1, dataset: 'golden-v1', photos: [absentPhoto({ expectedFigureId: 'not-allowed' })] }), /must omit/);
    assert.throws(() => validateManifest({ version: 1, dataset: 'golden-v1', photos: [absentPhoto({ catalogPresence: 'maybe' })] }), /invalid catalogPresence/);
  });

  it('rejects missing and unsupported files during preflight before pipeline calls', async () => {
    const directory = await temporaryDirectory();
    try {
      const manifestPath = path.join(directory, 'manifest.json');
      await fs.writeFile(manifestPath, JSON.stringify({ version: 1, dataset: 'golden-v1', photos: [presentPhoto({ file: 'missing.jpg' })] }));
      await assert.rejects(() => new FigureRetrievalEvaluationManifestLoader(new LocalImageReader()).load(manifestPath), /missing or unsupported/);
      await fs.writeFile(path.join(directory, 'bad.jpg'), Buffer.from('not-image'));
      await fs.writeFile(manifestPath, JSON.stringify({ version: 1, dataset: 'golden-v1', photos: [presentPhoto({ file: 'bad.jpg' })] }));
      await assert.rejects(() => new FigureRetrievalEvaluationManifestLoader(new LocalImageReader()).load(manifestPath), /missing or unsupported/);
    } finally { await fs.rm(directory, { recursive: true, force: true }); }
  });

  it('points a missing manifest to the example without creating files', async () => {
    const directory = await temporaryDirectory();
    try {
      const missing = path.join(directory, 'manifest.json');
      await assert.rejects(() => new FigureRetrievalEvaluationManifestLoader(new LocalImageReader()).load(missing), /No evaluation manifest found[\s\S]*tools\/figure-retrieval-evaluation-manifest\.example\.json/);
      await assert.rejects(() => fs.stat(missing), { code: 'ENOENT' });
    } finally { await fs.rm(directory, { recursive: true, force: true }); }
  });
});

function runnerHarness({ candidates = [], isolationStatus = 'usable', readError, isolationError, retrievalError, previewWriter } = {}) {
  let retrievalCalls = 0; let tick = 0; const retrievalTopKs = [];
  const images = { async read() { if (readError) throw readError; return { bytes: Buffer.from('local-image'), mimeType: 'image/jpeg' }; } };
  const isolation = { async isolate() {
    if (isolationError) throw isolationError;
    if (isolationStatus !== 'usable') return { status: isolationStatus, reason: 'crop_detail_below_threshold', candidates: [{ normalized: { ymin: .1, xmin: .2, ymax: .8, xmax: .9 }, pixels: { top: 10, left: 20, width: 70, height: 80 }, selected: true }], previewCrops: { coarse: { bytes: Buffer.from('coarse'), mimeType: 'image/png' }, final: { bytes: Buffer.from('rejected-crop'), mimeType: 'image/png' } }, diagnostics: { locatorModel: 'x', locatorPromptVersion: 'x', elapsedMs: 1, sourceWidth: 100, sourceHeight: 120, cropWidth: 70, cropHeight: 80, blurMetric: .1, blurThreshold: .25, detailMetric: .2, detailThreshold: .65, combinedBlurPassed: false, subjectAreaRatio: .4, failedChecks: ['blur'], refinement: { attempted: true, accepted: false, reason: 'quality' } } };
    return { status: 'usable', reason: 'single_intended_collectible', boundingBox: {}, candidates: [], previewCrops: { coarse: { bytes: Buffer.from('coarse'), mimeType: 'image/png' }, final: { bytes: Buffer.from('final-crop'), mimeType: 'image/png' }, embeddingInput: { bytes: Buffer.from('selected-crop'), mimeType: 'image/png' } }, embeddingInput: { bytes: Buffer.from('selected-crop'), mimeType: 'image/png' }, crop: {}, diagnostics: { locatorModel: 'x', locatorPromptVersion: 'x', elapsedMs: 1, refinement: { accepted: true }, segmentation: { status: 'segmented', usedFallback: false } } };
  } };
  const retrieval = { async retrieveStoredImage(_image, topK) { retrievalCalls++; retrievalTopKs.push(topK); if (retrievalError) throw retrievalError; return candidates.slice(0, topK); } };
  return { runner: new FigureRetrievalEvaluationRunner(images, isolation, retrieval, decisionResolver, () => (tick++ * 10), candidateDecisionResolver, previewWriter), retrievalCalls: () => retrievalCalls, retrievalTopKs: () => retrievalTopKs };
}
const resolved = (entry) => { const { file, ...rest } = entry; return { ...rest, expectedFigureId: rest.expectedFigureId ?? undefined, filePath: `hidden/${file}` }; };
const options = { topK: 5, continueOnError: true, calibrationProfile: RETRIEVAL_DECISION_CONFIG.currentCalibrationProfile };

describe('per-case evaluation runner', () => {
  it('records Rank 1, Rank 3, and expected-absent-from-Top-K correctness', async () => {
    const cases = [
      [present({ id: 'rank-1' }), [candidate(1, 'expected', 0.1), candidate(2, 'other', 0.2)]],
      [present({ id: 'rank-3' }), [candidate(1, 'a', 0.1), candidate(2, 'b', 0.2), candidate(3, 'expected', 0.3)]],
      [present({ id: 'missing' }), [candidate(1, 'a', 0.1)]],
    ];
    const results = [];
    for (const [entry, candidates] of cases) results.push((await runnerHarness({ candidates }).runner.run([resolved(entry)], options))[0]);
    assert.deepEqual(results.map(({ expectedRank, top1Correct, top3Correct, top5Correct, presentInTopK }) => ({ expectedRank, top1Correct, top3Correct, top5Correct, presentInTopK })), [
      { expectedRank: 1, top1Correct: true, top3Correct: true, top5Correct: true, presentInTopK: true },
      { expectedRank: 3, top1Correct: false, top3Correct: true, top5Correct: true, presentInTopK: true },
      { expectedRank: undefined, top1Correct: false, top3Correct: false, top5Correct: false, presentInTopK: false },
    ]);
  });

  it('records Catalog-absent evidence without correctness fields', async () => {
    const result = (await runnerHarness({ candidates: [candidate(1, 'returned', 0.2)] }).runner.run([resolved(absent())], options))[0];
    assert.equal(result.status, 'completed'); assert.equal(result.top1FigureId, 'returned'); assert.equal(result.top1Correct, undefined);
    assert.equal(result.decisionOutcome, 'needs_review'); assert.equal(result.returnedCandidates.length, 1);
  });

  it('records isolation rejection without retrieval and sanitizes provider/retrieval failures', async () => {
    const rejected = runnerHarness({ isolationStatus: 'too_blurry' });
    const rejectedResult = (await rejected.runner.run([resolved(present())], options))[0];
    assert.equal(rejectedResult.status, 'isolation_rejected'); assert.equal(rejected.retrievalCalls(), 0);
    for (const harness of [runnerHarness({ isolationError: new Error('secret path') }), runnerHarness({ retrievalError: new Error('credential token') })]) {
      const result = (await harness.runner.run([resolved(present())], options))[0];
      assert.equal(result.status, 'failed'); assert.match(result.errorCode, /_failed$/);
      assert.doesNotMatch(JSON.stringify(result), /secret path|credential token|hidden\//);
    }
  });

  it('copies shadow decision and evidence, preserves order, and writes progress incrementally', async () => {
    const entries = [resolved(present({ id: 'first' })), resolved(absent({ id: 'second' }))];
    const snapshots = [];
    const candidates = [candidate(1, 'expected', 0.1), candidate(2, 'other', 0.2)];
    const results = await runnerHarness({ candidates }).runner.run(entries, options, async (progress, current) => snapshots.push({ id: progress.result.id, count: current.length }));
    assert.deepEqual(results.map((result) => result.id), ['first', 'second']); assert.deepEqual(snapshots, [{ id: 'first', count: 1 }, { id: 'second', count: 2 }]);
    assert.equal(results[0].policyVersion, 'retrieval-policy-shadow-v1'); assert.equal(results[0].top1Top2Gap, 0.1);
    assert.equal(results[0].shadowDecisionOutcome, 'needs_review'); assert.equal(results[0].candidateDecisionOutcome, 'high_confidence');
    assert.deepEqual(results[0].candidateDecisionReasons, ['candidate_policy_match']); assert.equal(results[0].candidatePolicyVersion, 'retrieval-policy-candidate-v1');
  });

  it('does not write previews unless explicitly requested and writes before rejected retrieval is skipped', async () => {
    const calls=[];const previewWriter={async write(...args){calls.push(args);}};const harness=runnerHarness({isolationStatus:'too_blurry',previewWriter});
    await harness.runner.run([resolved(present())],options);assert.equal(calls.length,0);
    await harness.runner.run([resolved(present())],{...options,previewDir:'safe-previews'});assert.equal(calls.length,1);assert.equal(calls[0][1],'present-1');assert.equal(calls[0][3].status,'too_blurry');assert.equal(harness.retrievalCalls(),0);
  });

  it('exposes extra raw debug candidates without changing evaluated Top-K results', async()=>{const candidates=Array.from({length:10},(_,i)=>candidate(i+1,i===6?'expected':`other-${i+1}`,0.1+i/100));const debug=[];const harness=runnerHarness({candidates});const result=(await harness.runner.run([resolved(present({id:'photo-0009'}))],{...options,debugTopK:10,onDebugCandidates:(entry,raw)=>debug.push({entry,raw})}))[0];assert.deepEqual(harness.retrievalTopKs(),[10]);assert.equal(debug[0].raw.length,10);assert.equal(result.returnedCandidates.length,5);assert.equal(result.presentInTopK,false);});
});

describe('evaluation preview artifacts and filtering',()=>{
  it('creates safe per-case diagnostics and preserves rejected crop and exact embedding input artifacts',async()=>{const root=await temporaryDirectory();try{const delegate={async write(directory,stem,source,candidates,result){const artifacts={};if(result.status!=='no_subject'){await fs.writeFile(path.join(directory,`${stem}.subject-crop.png`),result.previewCrops.final.bytes);artifacts.crop=`${stem}.subject-crop.png`;}if(result.status==='usable'){await fs.writeFile(path.join(directory,`${stem}.embedding-input.png`),result.embeddingInput.bytes);artifacts.embeddingInput=`${stem}.embedding-input.png`;}return artifacts;}};const writer=new FigureRetrievalEvaluationPreviewWriter(delegate);
    const rejected=runnerHarness({isolationStatus:'too_blurry'});let captured;const capture={async write(_r,_id,_source,result){captured=result;}};await runnerHarness({isolationStatus:'too_blurry',previewWriter:capture}).runner.run([resolved(present({id:'photo-0007'}))],{...options,previewDir:root});await writer.write(root,'photo-0007',{bytes:Buffer.from('source'),mimeType:'image/jpeg'},captured,false);const rejectedJson=await fs.readFile(path.join(root,'photo-0007','photo-0007.diagnostics.json'),'utf8');assert.match(rejectedJson,/crop_detail_below_threshold/);assert.match(rejectedJson,/"failedQualityChecks": \[\s*"blur"/);assert.doesNotMatch(rejectedJson,/hidden\\|hidden\/|local source|bytes|base64|vector/i);assert.equal(await fs.readFile(path.join(root,'photo-0007','photo-0007.subject-crop.png'),'utf8'),'rejected-crop');
    let usable;await runnerHarness({previewWriter:{async write(_r,_id,_source,result){usable=result;}}}).runner.run([resolved(present({id:'photo-0008'}))],{...options,previewDir:root});await writer.write(root,'photo-0008',{bytes:Buffer.from('source'),mimeType:'image/jpeg'},usable,false);assert.equal(await fs.readFile(path.join(root,'photo-0008','photo-0008.embedding-input.png'),'utf8'),'selected-crop');await assert.rejects(()=>writer.write(root,'photo-0008',{bytes:Buffer.alloc(0),mimeType:'image/jpeg'},usable,false),/already exist/);
  }finally{await fs.rm(root,{recursive:true,force:true});}});
  it('filters before evaluation, rejects unknown IDs, and preserves manifest order',()=>{const cases=[{id:'photo-0001'},{id:'photo-0002'},{id:'photo-0003'}];assert.deepEqual(filterEvaluationCases(cases,['photo-0003','photo-0001']),{cases:[cases[0],cases[2]],skippedByFilterCount:1});assert.throws(()=>filterEvaluationCases(cases,['photo-9999']),/Unknown/);});
});

describe('aggregate metrics and output', () => {
  const results = [
    { id: 'p1', catalogPresence: 'present', expectedFigureId: 'a', status: 'completed', expectedRank: 1, top1Correct: true, top3Correct: true, top5Correct: true, presentInTopK: true, decisionOutcome: 'needs_review', segmentationOutcome: 'segmented', refinementAccepted: true, top1Distance: 0.1, top1Top2Gap: 0.05, relativeTop1Top2Gap: 0.5, distanceSpread: 0.4, elapsedMs: 10 },
    { id: 'p2', catalogPresence: 'present', expectedFigureId: 'b', status: 'completed', expectedRank: 3, top1Correct: false, top3Correct: true, top5Correct: true, presentInTopK: true, decisionOutcome: 'needs_review', segmentationOutcome: 'refined_crop_fallback', refinementAccepted: false, top1Distance: 0.3, top1Top2Gap: 0.1, relativeTop1Top2Gap: 1 / 3, distanceSpread: 0.6, elapsedMs: 20 },
    { id: 'a1', catalogPresence: 'absent', status: 'completed', decisionOutcome: 'no_confident_match', top1Distance: 0.8, elapsedMs: 30 },
    { id: 'reject', catalogPresence: 'present', expectedFigureId: 'c', status: 'isolation_rejected', elapsedMs: 40 },
    { id: 'fail', catalogPresence: 'present', expectedFigureId: 'd', status: 'failed', elapsedMs: 50 },
  ];

  it('computes separate denominators, accuracy, MRR, decisions, pipeline counts, and percentiles', () => {
    const metrics = aggregateFigureRetrievalEvaluation(results);
    assert.deepEqual({ top1: metrics.top1Accuracy, top3: metrics.top3Accuracy, top5: metrics.top5Accuracy, mrr: metrics.meanReciprocalRank, present: metrics.expectedPresentInTopKRate }, { top1: 0.5, top3: 1, top5: 1, mrr: 2 / 3, present: 1 });
    assert.deepEqual({ review: metrics.needsReviewCount, noMatch: metrics.noConfidentMatchCount, absentNoMatch: metrics.catalogAbsentNoConfidentMatchCount }, { review: 2, noMatch: 1, absentNoMatch: 1 });
    assert.deepEqual({ segmented: metrics.segmentedCount, fallback: metrics.segmentationFallbackCount, refinement: metrics.refinementAcceptedCount, rejected: metrics.isolationRejectedCount }, { segmented: 1, fallback: 1, refinement: 1, rejected: 1 });
    assert.equal(metrics.averageElapsedMs, 30); assert.equal(metrics.p50ElapsedMs, 30); assert.equal(metrics.p95ElapsedMs, 48);
    assert.equal(metrics.evidenceDistributions.catalogPresent.top1Distance.mean, 0.2); assert.equal(metrics.evidenceDistributions.catalogAbsent.top1Top2Gap.count, 0);
    assert.deepEqual(describeDistribution([]), { count: 0 });
  });

  it('writes valid JSON and escaped CSV without paths or sensitive payloads and enforces overwrite', async () => {
    const directory = await temporaryDirectory();
    try {
      const writer = new FigureRetrievalEvaluationWriter(); await writer.prepare(directory, false);
      const summary = { runnerVersion: 'v1', generatedAt: '2026-01-01T00:00:00.000Z', manifestVersion: 1, policyVersion: 'shadow', calibrationProfile: 'profile', topK: 5, ...aggregateFigureRetrievalEvaluation(results) };
      const safeResults = [{ ...results[0], id: 'quoted,id', decisionReasons: ['a', 'b'], returnedCandidates: [{ figureId: 'a', seriesId: 's', brandId: 'b', ipId: 'i', isSecret: false, distance: 0.1, rank: 1 }] }];
      await writer.write(directory, safeResults, summary);
      assert.equal(JSON.parse(await fs.readFile(path.join(directory, 'evaluation-results.json'), 'utf8'))[0].id, 'quoted,id');
      assert.match(await fs.readFile(path.join(directory, 'evaluation-results.csv'), 'utf8'), /"quoted,id"/);
      assert.equal(JSON.parse(await fs.readFile(path.join(directory, 'evaluation-summary.json'), 'utf8')).runnerVersion, 'v1');
      const combined = await fs.readFile(path.join(directory, 'evaluation-results.json'), 'utf8') + toCsv(safeResults);
      assert.doesNotMatch(combined, /[A-Z]:\\|\/Users\/|image bytes|mask bytes|polygon|credential|token|vector/i);
      await assert.rejects(() => writer.prepare(directory, false), /already exists/);
      await assert.doesNotReject(() => writer.prepare(directory, true));
    } finally { await fs.rm(directory, { recursive: true, force: true }); }
  });

  it('parses bounded CLI options and emits sanitized progress', () => {
    assert.deepEqual(parseFigureRetrievalEvaluationArgs(['--manifest', 'm.json', '--output-dir', 'out']), { manifest: 'm.json', outputDir: 'out', topK: 5, overwrite: false, continueOnError: true, previewDir: undefined, overwritePreview: false, caseIds: [], debugTopCandidates: false, debugTopK: 10 });
    assert.equal(parseFigureRetrievalEvaluationArgs(['--manifest', 'm', '--output-dir', 'o', '--top-k', '20', '--overwrite']).topK, 20);
    assert.throws(() => parseFigureRetrievalEvaluationArgs(['--manifest', 'm', '--output-dir', 'o', '--top-k', '21']));
    assert.deepEqual(parseFigureRetrievalEvaluationArgs(['--manifest','m','--output-dir','o','--preview-dir','p','--overwrite-preview','--case-id','photo-0007','--case-ids','photo-0008,photo-0009']).caseIds,['photo-0007','photo-0008','photo-0009']);
    assert.throws(()=>parseFigureRetrievalEvaluationArgs(['--manifest','m','--output-dir','o','--overwrite-preview']),/requires --preview-dir/);
    assert.equal(parseFigureRetrievalEvaluationArgs(['--manifest','m','--output-dir','o','--case-id','photo-0007','--debug-top-candidates']).debugTopK,10);
    assert.equal(parseFigureRetrievalEvaluationArgs(['--manifest','m','--output-dir','o','--case-ids','photo-0007,photo-0008','--debug-top-candidates','--debug-top-k','7']).debugTopK,7);
    assert.throws(()=>parseFigureRetrievalEvaluationArgs(['--manifest','m','--output-dir','o','--debug-top-candidates']),/requires --case/);
    assert.throws(()=>parseFigureRetrievalEvaluationArgs(['--manifest','m','--output-dir','o','--case-id','photo-0007','--debug-top-k','2']),/requires --debug-top-candidates/);
    const output = formatEvaluationProgress({ index: 1, total: 2, result: results[0] }).join('\n');
    assert.match(output, /\[1\/2\] p1/); assert.doesNotMatch(output, /path|bytes|vector|credential/i);
  });

  it('formats isolated raw candidate debug blocks with present and absent expected figures',()=>{const candidates=[candidate(1,'first',.1),candidate(2,'expected',.241832),candidate(3,'third',.3)];const presentOutput=formatRetrievalDebug('photo-0009','expected',candidates,2).join('\n');assert.match(presentOutput,/Retrieval Debug[\s\S]*Case: photo-0009[\s\S]*Top 2 Candidates/);assert.match(presentOutput,/1\.[\s\S]*figureId: first[\s\S]*seriesId: series-a[\s\S]*brandId: brand-a[\s\S]*ipId: ip-a[\s\S]*distance: 0\.1/);assert.match(presentOutput,/Correct Figure Rank:\n2[\s\S]*Correct Figure Distance:\n0\.241832/);assert.doesNotMatch(presentOutput,/embedding|vector/i);const missing=formatRetrievalDebug('photo-0010','missing',candidates,10).join('\n');assert.match(missing,/Correct Figure Rank:\nNot in retrieved candidates/);const multiple=[formatRetrievalDebug('photo-0009','expected',candidates,2),formatRetrievalDebug('photo-0010','missing',candidates,2)].flat().join('\n');assert.equal((multiple.match(/Retrieval Debug/g)||[]).length,2);});
});

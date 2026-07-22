/** Sequential developer-only labeled retrieval evaluation. Nothing is persisted remotely. */
import { Firestore } from '@google-cloud/firestore';
import cliModule from '../lib/figureRecognition/figureRetrievalEvaluationCli.js';
import manifestModule from '../lib/figureRecognition/figureRetrievalEvaluationManifest.js';
import runnerModule from '../lib/figureRecognition/figureRetrievalEvaluationRunner.js';
import metricsModule from '../lib/figureRecognition/figureRetrievalEvaluationMetrics.js';
import writerModule from '../lib/figureRecognition/figureRetrievalEvaluationWriter.js';
import decisionConfigModule from '../lib/figureRecognition/retrievalDecisionConfig.js';
import decisionModule from '../lib/figureRecognition/retrievalDecisionResolver.js';
import candidateConfigModule from '../lib/figureRecognition/retrievalCandidatePolicyConfig.js';
import candidateDecisionModule from '../lib/figureRecognition/retrievalCandidatePolicyResolver.js';
import readerModule from '../lib/figureRecognition/localImageReader.js';
import providerModule from '../lib/figureRecognition/imageEmbeddingProvider.js';
import clientModule from '../lib/figureRecognition/googleImageEmbeddingClient.js';
import embeddingConfigModule from '../lib/figureRecognition/imageEmbeddingConfig.js';
import retrievalModule from '../lib/figureRecognition/figureRetrievalService.js';
import searchModule from '../lib/figureRecognition/figureVectorSearch.js';
import subjectConfigModule from '../lib/figureRecognition/primarySubjectConfig.js';
import locatorModule from '../lib/figureRecognition/googlePrimarySubjectLocator.js';
import cropperModule from '../lib/figureRecognition/primarySubjectCropper.js';
import isolationModule from '../lib/figureRecognition/primarySubjectIsolationService.js';
import refinerModule from '../lib/figureRecognition/googlePrimarySubjectRefiner.js';
import refinementModule from '../lib/figureRecognition/primarySubjectRefinementService.js';
import segmenterModule from '../lib/figureRecognition/geminiSubjectSegmenter.js';
import previewModule from '../lib/figureRecognition/primarySubjectPreviewWriter.js';
import evaluationPreviewModule from '../lib/figureRecognition/figureRetrievalEvaluationPreviewWriter.js';

const { parseFigureRetrievalEvaluationArgs, filterEvaluationCases, formatEvaluationProgress, formatEvaluationSummary, formatRetrievalDebug } = cliModule;
const { FigureRetrievalEvaluationManifestLoader } = manifestModule;
const { FigureRetrievalEvaluationRunner } = runnerModule;
const { aggregateFigureRetrievalEvaluation } = metricsModule;
const { FigureRetrievalEvaluationWriter } = writerModule;
const { RETRIEVAL_DECISION_CONFIG } = decisionConfigModule;
const { ShadowRetrievalDecisionResolver } = decisionModule;
const { RETRIEVAL_CANDIDATE_POLICY_CONFIG } = candidateConfigModule;
const { CandidateRetrievalDecisionResolver } = candidateDecisionModule;
const { LocalImageReader } = readerModule;
const { ImageEmbeddingProvider } = providerModule;
const { GoogleImageEmbeddingClient } = clientModule;
const { IMAGE_EMBEDDING_CONFIG } = embeddingConfigModule;
const { FigureRetrievalService } = retrievalModule;
const { FirestoreFigureVectorSearch } = searchModule;
const { PRIMARY_SUBJECT_CONFIG } = subjectConfigModule;
const { GooglePrimarySubjectLocator } = locatorModule;
const { PrimarySubjectCropper } = cropperModule;
const { PrimarySubjectIsolationService } = isolationModule;
const { GooglePrimarySubjectRefiner } = refinerModule;
const { PrimarySubjectRefinementService } = refinementModule;
const { GeminiSubjectSegmenter } = segmenterModule;
const { PrimarySubjectPreviewWriter } = previewModule;
const { FigureRetrievalEvaluationPreviewWriter } = evaluationPreviewModule;

const RUNNER_VERSION = 'figure-retrieval-evaluation-v1';
let component = 'arguments';
try {
  const options = parseFigureRetrievalEvaluationArgs(process.argv.slice(2));
  const reader = new LocalImageReader();
  component = 'manifest';
  const manifest = await new FigureRetrievalEvaluationManifestLoader(reader).load(options.manifest);
  const selection = filterEvaluationCases(manifest.photos, options.caseIds);
  component = 'output';
  const writer = new FigureRetrievalEvaluationWriter();
  await writer.prepare(options.outputDir, options.overwrite);

  component = 'startup';
  const projectId = process.env.GOOGLE_CLOUD_PROJECT?.trim();
  if (!projectId) throw new Error('GOOGLE_CLOUD_PROJECT is required');
  const embedding = new ImageEmbeddingProvider(
    IMAGE_EMBEDDING_CONFIG,
    { async read() { throw new Error('Storage query images are not supported'); } },
    new GoogleImageEmbeddingClient(projectId, IMAGE_EMBEDDING_CONFIG),
    { log: (entry) => console.log(JSON.stringify(entry)) },
  );
  const retrieval = new FigureRetrievalService(reader, embedding, new FirestoreFigureVectorSearch(new Firestore({ projectId })));
  const cropper = new PrimarySubjectCropper(PRIMARY_SUBJECT_CONFIG);
  const refinement = new PrimarySubjectRefinementService(new GooglePrimarySubjectRefiner(projectId, PRIMARY_SUBJECT_CONFIG), cropper, PRIMARY_SUBJECT_CONFIG);
  const isolation = new PrimarySubjectIsolationService(
    new GooglePrimarySubjectLocator(projectId, PRIMARY_SUBJECT_CONFIG), cropper, PRIMARY_SUBJECT_CONFIG, refinement,
    new GeminiSubjectSegmenter(projectId, PRIMARY_SUBJECT_CONFIG),
  );
  const decisions = new ShadowRetrievalDecisionResolver(RETRIEVAL_DECISION_CONFIG);
  const candidateDecisions = new CandidateRetrievalDecisionResolver(RETRIEVAL_CANDIDATE_POLICY_CONFIG);
  const previewWriter = options.previewDir ? new FigureRetrievalEvaluationPreviewWriter(new PrimarySubjectPreviewWriter(cropper)) : undefined;
  const runner = new FigureRetrievalEvaluationRunner(reader, isolation, retrieval, decisions, Date.now, candidateDecisions, previewWriter);
  const summaryFor = (results) => ({
    runnerVersion: RUNNER_VERSION,
    generatedAt: new Date().toISOString(),
    manifestVersion: manifest.version,
    policyVersion: RETRIEVAL_DECISION_CONFIG.policyVersion,
    calibrationProfile: RETRIEVAL_DECISION_CONFIG.currentCalibrationProfile,
    topK: options.topK,
    skippedByFilterCount: selection.skippedByFilterCount,
    ...aggregateFigureRetrievalEvaluation(results),
  });
  component = 'evaluation';
  const results = await runner.run(selection.cases, {
    topK: options.topK,
    continueOnError: options.continueOnError,
    calibrationProfile: RETRIEVAL_DECISION_CONFIG.currentCalibrationProfile,
    previewDir: options.previewDir,
    overwritePreview: options.overwritePreview,
    debugTopK: options.debugTopCandidates ? options.debugTopK : undefined,
    onDebugCandidates: options.debugTopCandidates ? (entry, candidates) => {
      for (const line of formatRetrievalDebug(entry.id, entry.expectedFigureId, candidates, options.debugTopK)) console.log(line);
    } : undefined,
  }, async (progress, currentResults) => {
    for (const line of formatEvaluationProgress(progress)) console.log(line);
    await writer.write(options.outputDir, currentResults, summaryFor(currentResults));
  });
  const summary = summaryFor(results);
  await writer.write(options.outputDir, results, summary);
  for (const line of formatEvaluationSummary(summary)) console.log(line);
  console.log(JSON.stringify({ success: true, outputFiles: ['evaluation-results.json', 'evaluation-results.csv', 'evaluation-summary.json'], caseCount: results.length }));
} catch (error) {
  console.log(JSON.stringify({
    success: false,
    errorCode: 'figure-retrieval-evaluation-failed',
    component,
    reason: component === 'manifest' ? 'Manifest validation failed before evaluation'
      : component === 'output' ? 'Output validation failed before evaluation'
      : component === 'arguments' ? 'Invalid evaluation arguments'
      : component === 'startup' ? 'Evaluation startup failed'
      : 'Evaluation run failed',
  }));
  process.exitCode = 1;
}

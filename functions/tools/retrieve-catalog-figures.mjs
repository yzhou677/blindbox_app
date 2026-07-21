/** Local image -> embedding -> Firestore Top-K evaluation. Nothing is persisted. */
import { Firestore } from '@google-cloud/firestore';
import cliModule from '../lib/figureRecognition/figureRetrievalCli.js';
import serviceModule from '../lib/figureRecognition/figureRetrievalService.js';
import searchModule from '../lib/figureRecognition/figureVectorSearch.js';
import readerModule from '../lib/figureRecognition/localImageReader.js';
import providerModule from '../lib/figureRecognition/imageEmbeddingProvider.js';
import clientModule from '../lib/figureRecognition/googleImageEmbeddingClient.js';
import configModule from '../lib/figureRecognition/imageEmbeddingConfig.js';
import isolationConfigModule from '../lib/figureRecognition/primarySubjectConfig.js';
import locatorModule from '../lib/figureRecognition/googlePrimarySubjectLocator.js';
import cropperModule from '../lib/figureRecognition/primarySubjectCropper.js';
import isolationModule from '../lib/figureRecognition/primarySubjectIsolationService.js';
import previewModule from '../lib/figureRecognition/primarySubjectPreviewWriter.js';
import refinerModule from '../lib/figureRecognition/googlePrimarySubjectRefiner.js';
import refinementModule from '../lib/figureRecognition/primarySubjectRefinementService.js';
import segmenterModule from '../lib/figureRecognition/geminiSubjectSegmenter.js';
import path from 'node:path';

const { parseFigureRetrievalArgs, formatFigureRetrievalCandidate, formatPrimarySubjectResult } = cliModule;
const { FigureRetrievalService } = serviceModule;
const { FirestoreFigureVectorSearch, FigureVectorIndexUnavailableError } = searchModule;
const { LocalImageReader } = readerModule;
const { ImageEmbeddingProvider } = providerModule;
const { GoogleImageEmbeddingClient } = clientModule;
const { IMAGE_EMBEDDING_CONFIG } = configModule;
const { PRIMARY_SUBJECT_CONFIG } = isolationConfigModule;
const { GooglePrimarySubjectLocator } = locatorModule;
const { PrimarySubjectCropper } = cropperModule;
const { PrimarySubjectIsolationService } = isolationModule;
const { PrimarySubjectPreviewWriter } = previewModule;
const { GooglePrimarySubjectRefiner } = refinerModule;
const { PrimarySubjectRefinementService } = refinementModule;
const { GeminiSubjectSegmenter } = segmenterModule;

const startedAt = Date.now();
let component = 'arguments';
try {
  const options = parseFigureRetrievalArgs(process.argv.slice(2));
  component = 'startup';
  const projectId = process.env.GOOGLE_CLOUD_PROJECT?.trim();
  if (!projectId) throw new Error('GOOGLE_CLOUD_PROJECT is required');
  const provider = new ImageEmbeddingProvider(
    IMAGE_EMBEDDING_CONFIG,
    { async read() { throw new Error('Storage query images are not supported'); } },
    new GoogleImageEmbeddingClient(projectId, IMAGE_EMBEDDING_CONFIG),
    { log: (entry) => console.log(JSON.stringify(entry)) },
  );
  const reader = new LocalImageReader();
  const service = new FigureRetrievalService(
    reader,
    provider,
    new FirestoreFigureVectorSearch(new Firestore({ projectId })),
  );
  let candidates;
  if (!options.isolateSubject) {
    component = 'retrieval';
    candidates = await service.retrieve(options.file, options.topK);
  } else {
    component = 'local-image';
    const source = await reader.read(options.file);
    const cropper = new PrimarySubjectCropper(PRIMARY_SUBJECT_CONFIG);
    const locator = new GooglePrimarySubjectLocator(projectId, PRIMARY_SUBJECT_CONFIG);
    const refiner = new GooglePrimarySubjectRefiner(projectId, PRIMARY_SUBJECT_CONFIG);
    const refinement = new PrimarySubjectRefinementService(refiner, cropper, PRIMARY_SUBJECT_CONFIG);
    const segmenter = new GeminiSubjectSegmenter(projectId, PRIMARY_SUBJECT_CONFIG);
    const isolation = new PrimarySubjectIsolationService(locator, cropper, PRIMARY_SUBJECT_CONFIG, refinement, segmenter);
    component = 'primary-subject-locator';
    const result = await isolation.isolate(source);
    let previews = {};
    const previewGeometries = result.status === 'no_subject' ? [] : result.candidates;
    if (options.previewDir && previewGeometries.length > 0) {
      const previewCandidates = previewGeometries.map((candidate, index) => ({
        box: candidate.normalized,
      }));
      component = 'preview-writer';
      previews = await new PrimarySubjectPreviewWriter(cropper).write(
        options.previewDir,
        path.basename(options.file),
        source,
        previewCandidates,
        result,
        options.overwritePreview,
      );
    }
    for (const line of formatPrimarySubjectResult(result, previews)) console.log(line);
    if (result.status !== 'usable') {
      console.log('Retrieval skipped.');
      process.exit(0);
    }
    component = 'retrieval';
    candidates = await service.retrieveStoredImage(result.embeddingInput, options.topK);
  }
  console.log(JSON.stringify({
    success: true,
    model: IMAGE_EMBEDDING_CONFIG.model,
    location: IMAGE_EMBEDDING_CONFIG.location,
    embeddingSpace: IMAGE_EMBEDDING_CONFIG.embeddingSpace,
    topK: options.topK,
    resultCount: candidates.length,
    elapsedMs: Date.now() - startedAt,
  }));
  for (const candidate of candidates) {
    for (const line of formatFigureRetrievalCandidate(candidate)) console.log(line);
  }
} catch (error) {
  console.log(JSON.stringify({
    success: false,
    error: error instanceof FigureVectorIndexUnavailableError ? 'vector-index-unavailable' : 'retrieval-failed',
    component,
    reason: component === 'primary-subject-locator' ? 'Primary subject localization failed'
      : component === 'preview-writer' ? 'Preview generation failed'
      : component === 'local-image' ? 'Local image validation failed'
      : component === 'arguments' ? 'Invalid CLI arguments'
      : 'Catalog retrieval failed',
    model: IMAGE_EMBEDDING_CONFIG.model,
    location: IMAGE_EMBEDDING_CONFIG.location,
    embeddingSpace: IMAGE_EMBEDDING_CONFIG.embeddingSpace,
    elapsedMs: Date.now() - startedAt,
  }));
  process.exitCode = 1;
}

/** Local image -> embedding -> Firestore Top-K evaluation. Nothing is persisted. */
import { Firestore } from '@google-cloud/firestore';
import cliModule from '../lib/figureRecognition/figureRetrievalCli.js';
import serviceModule from '../lib/figureRecognition/figureRetrievalService.js';
import searchModule from '../lib/figureRecognition/figureVectorSearch.js';
import readerModule from '../lib/figureRecognition/localImageReader.js';
import providerModule from '../lib/figureRecognition/imageEmbeddingProvider.js';
import clientModule from '../lib/figureRecognition/googleImageEmbeddingClient.js';
import configModule from '../lib/figureRecognition/imageEmbeddingConfig.js';

const { parseFigureRetrievalArgs, formatFigureRetrievalCandidate } = cliModule;
const { FigureRetrievalService } = serviceModule;
const { FirestoreFigureVectorSearch, FigureVectorIndexUnavailableError } = searchModule;
const { LocalImageReader } = readerModule;
const { ImageEmbeddingProvider } = providerModule;
const { GoogleImageEmbeddingClient } = clientModule;
const { IMAGE_EMBEDDING_CONFIG } = configModule;

const startedAt = Date.now();
try {
  const options = parseFigureRetrievalArgs(process.argv.slice(2));
  const projectId = process.env.GOOGLE_CLOUD_PROJECT?.trim();
  if (!projectId) throw new Error('GOOGLE_CLOUD_PROJECT is required');
  const provider = new ImageEmbeddingProvider(
    IMAGE_EMBEDDING_CONFIG,
    { async read() { throw new Error('Storage query images are not supported'); } },
    new GoogleImageEmbeddingClient(projectId, IMAGE_EMBEDDING_CONFIG),
    { log: (entry) => console.log(JSON.stringify(entry)) },
  );
  const service = new FigureRetrievalService(
    new LocalImageReader(),
    provider,
    new FirestoreFigureVectorSearch(new Firestore({ projectId })),
  );
  const candidates = await service.retrieve(options.file, options.topK);
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
    model: IMAGE_EMBEDDING_CONFIG.model,
    location: IMAGE_EMBEDDING_CONFIG.location,
    embeddingSpace: IMAGE_EMBEDDING_CONFIG.embeddingSpace,
    elapsedMs: Date.now() - startedAt,
  }));
  process.exitCode = 1;
}

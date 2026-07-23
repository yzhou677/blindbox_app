import { IMAGE_EMBEDDING_CONFIG } from './imageEmbeddingConfig';
import type {
  FigureRetrievalCandidate,
  FigureVectorSearch,
  FigureVectorSearchFilter,
  QueryEmbeddingProvider,
  QueryImageReader,
} from './figureRetrievalTypes';
import type { StoredImage } from './imageEmbeddingTypes';

export const DEFAULT_TOP_K = 5;
export const MAX_TOP_K = 20;

export type FigureRetrievalTimingStage =
  | 'embedding_request'
  | 'vector_retrieval'
  | 'aggregation';

export type FigureRetrievalDiagnostics = {
  userEmbeddingMs: number;
  vectorSearchMs: number;
  aggregationMs: number;
  totalMs: number;
  candidateImageCount: number;
  candidateFigureCount: number;
  alternativeMatchCount: number;
  winningImageRole?: string;
  winningVariant?: string;
  vectorSearchCalls: number;
  userEmbeddingCalls: number;
};

export type FigureRetrievalOptions = FigureVectorSearchFilter;

export class FigureRetrievalService {
  constructor(
    private readonly images: QueryImageReader,
    private readonly embeddings: QueryEmbeddingProvider,
    private readonly search: FigureVectorSearch,
  ) {}

  async retrieve(filePath: string, topK: number): Promise<FigureRetrievalCandidate[]> {
    validateTopK(topK);
    const image = await this.images.read(filePath);
    return (await this.retrieveStoredImageWithDiagnostics(image, topK)).candidates;
  }

  async retrieveStoredImage(
    image: StoredImage,
    topK: number,
    onTiming?: (stage: FigureRetrievalTimingStage, elapsedMs: number) => void,
    options?: FigureRetrievalOptions,
  ): Promise<FigureRetrievalCandidate[]> {
    return (await this.retrieveStoredImageWithDiagnostics(image, topK, onTiming, options)).candidates;
  }

  async retrieveStoredImageWithDiagnostics(
    image: StoredImage,
    topK: number,
    onTiming?: (stage: FigureRetrievalTimingStage, elapsedMs: number) => void,
    options?: FigureRetrievalOptions,
  ): Promise<{ candidates: FigureRetrievalCandidate[]; diagnostics: FigureRetrievalDiagnostics }> {
    validateTopK(topK);
    const totalStartedAt = Date.now();
    const embeddingStartedAt = Date.now();
    const result = await this.embeddings.embedStoredImage(image);
    const userEmbeddingMs = Date.now() - embeddingStartedAt;
    onTiming?.('embedding_request', userEmbeddingMs);
    validateQueryVector(result.vector);

    const filter: FigureVectorSearchFilter | undefined = options?.seriesId
      ? { seriesId: options.seriesId }
      : undefined;

    const retrievalStartedAt = Date.now();
    let candidates: FigureRetrievalCandidate[];
    let aggregationMs = 0;
    let candidateImageCount = 0;
    let candidateFigureCount = 0;
    let alternativeMatchCount = 0;
    let winningImageRole: string | undefined;
    let winningVariant: string | undefined;

    if (this.search.searchWithStats) {
      const searchResult = await this.search.searchWithStats(result.vector, topK, filter);
      candidates = searchResult.candidates;
      aggregationMs = searchResult.stats.aggregationMs;
      candidateImageCount = searchResult.stats.candidateImageCount;
      candidateFigureCount = searchResult.stats.candidateFigureCount;
      alternativeMatchCount = searchResult.stats.alternativeMatchCount;
      winningImageRole = searchResult.stats.winningImageRole;
      winningVariant = searchResult.stats.winningVariant;
      onTiming?.('aggregation', aggregationMs);
    } else {
      candidates = await this.search.search(result.vector, topK, filter);
      candidateImageCount = candidates.length;
      candidateFigureCount = candidates.length;
    }
    const vectorSearchMs = Date.now() - retrievalStartedAt;
    onTiming?.('vector_retrieval', vectorSearchMs);

    return {
      candidates,
      diagnostics: {
        userEmbeddingMs,
        vectorSearchMs,
        aggregationMs,
        totalMs: Math.max(0, Date.now() - totalStartedAt),
        candidateImageCount,
        candidateFigureCount,
        alternativeMatchCount,
        winningImageRole,
        winningVariant,
        vectorSearchCalls: 1,
        userEmbeddingCalls: 1,
      },
    };
  }
}

export function validateTopK(value: number): void {
  if (!Number.isInteger(value) || value < 1 || value > MAX_TOP_K) {
    throw new Error(`Top-K must be an integer from 1 to ${MAX_TOP_K}`);
  }
}

export function validateQueryVector(vector: number[]): void {
  if (vector.length !== IMAGE_EMBEDDING_CONFIG.outputDimension) {
    throw new Error(`Query embedding must contain exactly ${IMAGE_EMBEDDING_CONFIG.outputDimension} values`);
  }
  if (!vector.every(Number.isFinite)) throw new Error('Query embedding contains a non-finite value');
}

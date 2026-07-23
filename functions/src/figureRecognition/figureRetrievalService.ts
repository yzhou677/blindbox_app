import { IMAGE_EMBEDDING_CONFIG } from './imageEmbeddingConfig';
import type { FigureRetrievalCandidate, FigureVectorSearch, QueryEmbeddingProvider, QueryImageReader } from './figureRetrievalTypes';
import type { StoredImage } from './imageEmbeddingTypes';

export const DEFAULT_TOP_K = 5;
export const MAX_TOP_K = 20;

export class FigureRetrievalService {
  constructor(
    private readonly images: QueryImageReader,
    private readonly embeddings: QueryEmbeddingProvider,
    private readonly search: FigureVectorSearch,
  ) {}

  async retrieve(filePath: string, topK: number): Promise<FigureRetrievalCandidate[]> {
    validateTopK(topK);
    const image = await this.images.read(filePath);
    return this.retrieveStoredImage(image, topK);
  }

  async retrieveStoredImage(
    image: StoredImage,
    topK: number,
    onTiming?: (stage: 'embedding_request' | 'vector_retrieval', elapsedMs: number) => void,
  ): Promise<FigureRetrievalCandidate[]> {
    validateTopK(topK);
    const embeddingStartedAt = Date.now();
    const result = await this.embeddings.embedStoredImage(image);
    onTiming?.('embedding_request', Date.now() - embeddingStartedAt);
    validateQueryVector(result.vector);
    const retrievalStartedAt = Date.now();
    const candidates = await this.search.search(result.vector, topK);
    onTiming?.('vector_retrieval', Date.now() - retrievalStartedAt);
    return candidates;
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

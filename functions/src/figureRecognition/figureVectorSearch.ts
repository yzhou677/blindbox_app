import { Firestore } from '@google-cloud/firestore';
import { IMAGE_EMBEDDING_CONFIG } from './imageEmbeddingConfig';
import type { FigureRetrievalCandidate, FigureVectorSearch } from './figureRetrievalTypes';

const DISTANCE_FIELD = '_vectorDistance';
type VectorSearchQuery = {
  findNearest(options: {
    vectorField: string;
    queryVector: number[];
    limit: number;
    distanceMeasure: 'COSINE';
    distanceResultField: string;
  }): { get(): Promise<{ docs: Array<{ data(): Record<string, unknown> }> }> };
};

export class FigureVectorIndexUnavailableError extends Error {
  constructor() {
    super('Firestore vector index is missing or not ready');
    this.name = 'FigureVectorIndexUnavailableError';
  }
}

export class FirestoreFigureVectorSearch implements FigureVectorSearch {
  constructor(private readonly firestore: Firestore) {}

  async search(queryVector: number[], topK: number): Promise<FigureRetrievalCandidate[]> {
    try {
      const filteredQuery = this.firestore
        .collection('catalogFigureEmbeddings')
        .where('embeddingSpace', '==', IMAGE_EMBEDDING_CONFIG.embeddingSpace) as unknown as VectorSearchQuery;
      // firebase-admin v10 contributes an older ambient Query type. The direct
      // Firestore v8 runtime used here provides findNearest on this Query.
      const snapshot = await filteredQuery
        .findNearest({
          vectorField: 'embedding',
          queryVector,
          limit: topK,
          distanceMeasure: 'COSINE',
          distanceResultField: DISTANCE_FIELD,
        })
        .get();
      return snapshot.docs
        .map((document) => parseCandidate(document.data()))
        .filter((candidate): candidate is Omit<FigureRetrievalCandidate, 'rank'> => candidate !== null)
        .sort((left, right) => left.distance - right.distance || left.figureId.localeCompare(right.figureId))
        .map((candidate, index) => ({ ...candidate, rank: index + 1 }));
    } catch (error) {
      if (isMissingIndexError(error)) throw new FigureVectorIndexUnavailableError();
      throw error;
    }
  }
}

function parseCandidate(data: Record<string, unknown>): Omit<FigureRetrievalCandidate, 'rank'> | null {
  const requiredStrings = ['figureId', 'seriesId', 'brandId', 'ipId', 'embeddingSpace'] as const;
  if (requiredStrings.some((field) => typeof data[field] !== 'string' || !(data[field] as string).trim())) return null;
  if (data.embeddingSpace !== IMAGE_EMBEDDING_CONFIG.embeddingSpace || typeof data.isSecret !== 'boolean') return null;
  const distance = data[DISTANCE_FIELD];
  if (typeof distance !== 'number' || !Number.isFinite(distance)) return null;
  return {
    figureId: data.figureId as string,
    seriesId: data.seriesId as string,
    brandId: data.brandId as string,
    ipId: data.ipId as string,
    isSecret: data.isSecret,
    distance,
    embeddingSpace: data.embeddingSpace,
  };
}

function isMissingIndexError(error: unknown): boolean {
  const value = error as { code?: unknown };
  return value?.code === 9 || String(value?.code ?? '').toLowerCase().replaceAll('_', '-') === 'failed-precondition';
}

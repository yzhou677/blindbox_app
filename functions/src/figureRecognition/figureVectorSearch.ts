import { Firestore } from '@google-cloud/firestore';
import { IMAGE_EMBEDDING_CONFIG } from './imageEmbeddingConfig';
import { aggregateFigureCandidates, type ImageLevelRetrievalMatch } from './figureCandidateAggregation';
import type { EmbeddingImageRole } from './catalogEmbeddingIds';
import type {
  FigureRetrievalCandidate,
  FigureVectorSearch,
  FigureVectorSearchFilter,
  FigureVectorSearchResult,
} from './figureRetrievalTypes';
import { measureScanStage, measureScanStageSync } from './scanTiming';

const DISTANCE_FIELD = '_vectorDistance';
type VectorSearchQuery = {
  where(field: string, op: '==', value: string): VectorSearchQuery;
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

  async search(
    queryVector: number[],
    topK: number,
    filter?: FigureVectorSearchFilter,
  ): Promise<FigureRetrievalCandidate[]> {
    return (await this.searchWithStats(queryVector, topK, filter)).candidates;
  }

  async searchWithStats(
    queryVector: number[],
    topK: number,
    filter?: FigureVectorSearchFilter,
  ): Promise<FigureVectorSearchResult> {
    try {
      const seriesId = filter?.seriesId?.trim() || undefined;
      const filteredQuery = measureScanStageSync('vector_query_preparation', () => {
        // firebase-admin v10 contributes an older ambient Query type. The direct
        // Firestore v8 runtime used here provides findNearest on this Query.
        let query = this.firestore
          .collection('catalogFigureEmbeddings')
          .where('embeddingSpace', '==', IMAGE_EMBEDDING_CONFIG.embeddingSpace) as unknown as VectorSearchQuery;
        if (seriesId) {
          query = query.where('seriesId', '==', seriesId);
        }
        return query;
      });
      const snapshot = await measureScanStage('firestore_vector_index_call', () => filteredQuery
        .findNearest({
          vectorField: 'embedding',
          queryVector,
          limit: topK,
          distanceMeasure: 'COSINE',
          distanceResultField: DISTANCE_FIELD,
        })
        .get());
      const parsed = measureScanStageSync('vector_result_parsing', () => snapshot.docs
        .map((document) => parseImageMatch(document.data(), seriesId))
        .filter((candidate): candidate is ImageLevelRetrievalMatch => candidate !== null));
      const aggregationStartedAt = Date.now();
      const aggregated = aggregateFigureCandidates(parsed);
      const aggregationMs = Math.max(0, Date.now() - aggregationStartedAt);
      return {
        candidates: aggregated.candidates,
        stats: {
          ...aggregated.stats,
          aggregationMs,
        },
      };
    } catch (error) {
      if (isMissingIndexError(error)) throw new FigureVectorIndexUnavailableError();
      throw error;
    }
  }
}

function parseImageMatch(
  data: Record<string, unknown>,
  expectedSeriesId?: string,
): ImageLevelRetrievalMatch | null {
  const requiredStrings = ['figureId', 'seriesId', 'brandId', 'ipId', 'embeddingSpace'] as const;
  if (requiredStrings.some((field) => typeof data[field] !== 'string' || !(data[field] as string).trim())) return null;
  if (data.embeddingSpace !== IMAGE_EMBEDDING_CONFIG.embeddingSpace || typeof data.isSecret !== 'boolean') return null;
  if (expectedSeriesId && data.seriesId !== expectedSeriesId) return null;
  const distance = data[DISTANCE_FIELD];
  if (typeof distance !== 'number' || !Number.isFinite(distance)) return null;

  const imageRole = parseImageRole(data.imageRole);
  const variant = typeof data.variant === 'string' && data.variant.trim()
    ? data.variant.trim()
    : imageRole === 'primary' ? 'front' : undefined;
  const matchedImageKey = typeof data.imageKey === 'string' && data.imageKey.trim()
    ? data.imageKey.trim()
    : undefined;

  const match: ImageLevelRetrievalMatch = {
    figureId: data.figureId as string,
    seriesId: data.seriesId as string,
    brandId: data.brandId as string,
    ipId: data.ipId as string,
    isSecret: data.isSecret,
    distance,
    embeddingSpace: data.embeddingSpace,
  };
  // Legacy primary docs omit imageRole — leave fields unset so aggregation remains
  // an identity transform on the public candidate key set when possible.
  if (typeof data.imageRole === 'string') {
    match.imageRole = imageRole;
    if (variant) match.variant = variant;
    if (matchedImageKey) match.matchedImageKey = matchedImageKey;
  }
  return match;
}

function parseImageRole(value: unknown): EmbeddingImageRole {
  return value === 'alternative' ? 'alternative' : 'primary';
}

function isMissingIndexError(error: unknown): boolean {
  const value = error as { code?: unknown };
  return value?.code === 9 || String(value?.code ?? '').toLowerCase().replaceAll('_', '-') === 'failed-precondition';
}

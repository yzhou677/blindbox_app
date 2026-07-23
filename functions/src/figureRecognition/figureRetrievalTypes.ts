import type { EmbeddingImageRole } from './catalogEmbeddingIds';
import type { StoredImage } from './imageEmbeddingTypes';

export type FigureRetrievalCandidate = {
  figureId: string;
  seriesId: string;
  brandId: string;
  ipId: string;
  isSecret: boolean;
  distance: number;
  rank: number;
  embeddingSpace: string;
  /** Winning image role after aggregation; omitted for legacy primary-only docs. */
  imageRole?: EmbeddingImageRole;
  /** Winning variant after aggregation. */
  variant?: string;
  /** Winning embedding imageKey after aggregation. */
  matchedImageKey?: string;
};

export interface QueryImageReader {
  read(filePath: string): Promise<StoredImage>;
}

export interface QueryEmbeddingProvider {
  embedStoredImage(image: StoredImage): Promise<{ vector: number[] }>;
}

export type FigureVectorSearchResult = {
  candidates: FigureRetrievalCandidate[];
  stats: {
    candidateImageCount: number;
    candidateFigureCount: number;
    alternativeMatchCount: number;
    aggregationMs: number;
    winningImageRole?: EmbeddingImageRole;
    winningVariant?: string;
  };
};

/** Optional database-level filters for vector nearest-neighbor search. */
export type FigureVectorSearchFilter = {
  /** When set, restrict to embeddings with this seriesId. */
  seriesId?: string;
};

export interface FigureVectorSearch {
  search(
    queryVector: number[],
    topK: number,
    filter?: FigureVectorSearchFilter,
  ): Promise<FigureRetrievalCandidate[]>;
  searchWithStats?(
    queryVector: number[],
    topK: number,
    filter?: FigureVectorSearchFilter,
  ): Promise<FigureVectorSearchResult>;
}

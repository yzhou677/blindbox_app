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
};

export interface QueryImageReader {
  read(filePath: string): Promise<StoredImage>;
}

export interface QueryEmbeddingProvider {
  embedStoredImage(image: StoredImage): Promise<{ vector: number[] }>;
}

export interface FigureVectorSearch {
  search(queryVector: number[], topK: number): Promise<FigureRetrievalCandidate[]>;
}

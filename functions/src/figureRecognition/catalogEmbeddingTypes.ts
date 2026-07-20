import type { Timestamp } from '@google-cloud/firestore';
import type { StoredImage } from './imageEmbeddingTypes';

export type CatalogFigure = {
  figureId: string;
  seriesId: string;
  brandId: string;
  ipId: string;
  isSecret: boolean;
  imageKey: string;
  catalogModifiedAt: Timestamp | null;
};

export type ResolvedCatalogImage = StoredImage & { objectPath: string };

export type ExistingCatalogEmbedding = {
  data: Record<string, unknown>;
  vector: number[] | null;
  hasNativeVector: boolean;
};

export type EmbeddingMetadata = Omit<CatalogFigure, 'imageKey'> & {
  imageObjectPath: string;
  contentHash: string;
};

export interface CatalogFigureSource {
  get(figureId: string): Promise<CatalogFigure | null>;
  pages(pageSize: number): AsyncIterable<CatalogFigure[]>;
}

export interface CatalogImageResolver {
  resolve(imageKey: string): Promise<ResolvedCatalogImage>;
}

export interface CatalogEmbeddingStore {
  get(figureId: string): Promise<ExistingCatalogEmbedding | null>;
  writeEmbedding(metadata: EmbeddingMetadata, vector: number[], isNew: boolean): Promise<void>;
  updateMetadata(metadata: EmbeddingMetadata): Promise<void>;
}

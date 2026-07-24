import type { Timestamp } from '@google-cloud/firestore';
import type { StoredImage } from './imageEmbeddingTypes';
import type { CatalogAlternativeImage } from './catalogAlternativeImages';
import type { EmbeddingImageRole } from './catalogEmbeddingIds';

export type { CatalogAlternativeImage } from './catalogAlternativeImages';
export type { EmbeddingImageRole } from './catalogEmbeddingIds';

export type CatalogFigure = {
  figureId: string;
  seriesId: string;
  brandId: string;
  ipId: string;
  isSecret: boolean;
  imageKey: string;
  /** Optional recognition-only supplemental images; empty when unset. */
  alternativeImages: CatalogAlternativeImage[];
  catalogModifiedAt: Timestamp | null;
};

export type ResolvedCatalogImage = StoredImage & { objectPath: string };

export type ExistingCatalogEmbedding = {
  data: Record<string, unknown>;
  vector: number[] | null;
  hasNativeVector: boolean;
};

export type EmbeddingMetadata = {
  documentId: string;
  figureId: string;
  seriesId: string;
  brandId: string;
  ipId: string;
  isSecret: boolean;
  imageKey: string;
  imageRole: EmbeddingImageRole;
  variant: string;
  imageObjectPath: string;
  contentHash: string;
  catalogModifiedAt: Timestamp | null;
};

export interface CatalogFigureSource {
  get(figureId: string): Promise<CatalogFigure | null>;
  pages(pageSize: number): AsyncIterable<CatalogFigure[]>;
}

export interface CatalogImageResolver {
  resolve(imageKey: string): Promise<ResolvedCatalogImage>;
}

export interface CatalogEmbeddingStore {
  get(documentId: string): Promise<ExistingCatalogEmbedding | null>;
  writeEmbedding(metadata: EmbeddingMetadata, vector: number[], isNew: boolean): Promise<void>;
  updateMetadata(metadata: EmbeddingMetadata): Promise<void>;
  /** Returns embedding document ids for a figure (primary + alternatives). */
  listDocumentIdsForFigure(figureId: string): Promise<string[]>;
  /** Deletes an alternative embedding doc only; refuses primary doc ids. */
  deleteAlternativeDocument(documentId: string): Promise<void>;
}

import { FieldValue, Firestore, Timestamp, VectorValue } from '@google-cloud/firestore';
import { IMAGE_EMBEDDING_CONFIG } from './imageEmbeddingConfig';
import type { CatalogEmbeddingStore, EmbeddingMetadata, ExistingCatalogEmbedding } from './catalogEmbeddingTypes';

export class FirestoreCatalogEmbeddingStore implements CatalogEmbeddingStore {
  constructor(private readonly firestore: Firestore) {}

  async get(figureId: string): Promise<ExistingCatalogEmbedding | null> {
    const snapshot = await this.firestore.collection('catalogFigureEmbeddings').doc(figureId).get();
    if (!snapshot.exists) return null;
    const data = snapshot.data() ?? {};
    const embedding = data.embedding;
    return {
      data,
      hasNativeVector: embedding instanceof VectorValue,
      vector: embedding instanceof VectorValue ? embedding.toArray() : null,
    };
  }

  async writeEmbedding(metadata: EmbeddingMetadata, vector: number[], isNew: boolean): Promise<void> {
    const timestamps = isNew
      ? { createdAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp() }
      : { updatedAt: FieldValue.serverTimestamp() };
    await this.ref(metadata.figureId).set({
      ...documentMetadata(metadata),
      embedding: nativeVector(vector),
      ...timestamps,
    }, { merge: true });
  }

  async updateMetadata(metadata: EmbeddingMetadata): Promise<void> {
    await this.ref(metadata.figureId).set({
      ...documentMetadata(metadata),
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });
  }

  private ref(figureId: string) {
    return this.firestore.collection('catalogFigureEmbeddings').doc(figureId);
  }
}

function nativeVector(values: number[]): VectorValue {
  // firebase-admin v10 contributes an older ambient FieldValue type; the direct
  // Firestore v8 runtime and its own declarations provide this native vector API.
  return (FieldValue as typeof FieldValue & { vector(input: number[]): VectorValue }).vector(values);
}

function documentMetadata(metadata: EmbeddingMetadata): Record<string, unknown> {
  return {
    figureId: metadata.figureId,
    seriesId: metadata.seriesId,
    brandId: metadata.brandId,
    ipId: metadata.ipId,
    isSecret: metadata.isSecret,
    imageObjectPath: metadata.imageObjectPath,
    contentHash: metadata.contentHash,
    embeddingSpace: IMAGE_EMBEDDING_CONFIG.embeddingSpace,
    embeddingModel: IMAGE_EMBEDDING_CONFIG.model,
    embeddingLocation: IMAGE_EMBEDDING_CONFIG.location,
    embeddingDimension: IMAGE_EMBEDDING_CONFIG.outputDimension,
    embeddingVersion: IMAGE_EMBEDDING_CONFIG.version,
    catalogModifiedAt: metadata.catalogModifiedAt instanceof Timestamp ? metadata.catalogModifiedAt : null,
  };
}

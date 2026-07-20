export const IMAGE_EMBEDDING_CONFIG = Object.freeze({
  model: 'gemini-embedding-2',
  location: 'us',
  outputDimension: 1024,
  version: 'image-v1',
  embeddingSpace: 'gemini-embedding-2_us_1024_image-v1',
  estimatedPricePerImageUsd: 0.00012,
});

export type ImageEmbeddingConfig = typeof IMAGE_EMBEDDING_CONFIG;

export const IMAGE_EMBEDDING_CONFIG = Object.freeze({
  model: 'gemini-embedding-2',
  location: 'us',
  outputDimension: 1024,
});

export type ImageEmbeddingConfig = typeof IMAGE_EMBEDDING_CONFIG;

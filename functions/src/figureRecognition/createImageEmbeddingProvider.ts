import { IMAGE_EMBEDDING_CONFIG } from './imageEmbeddingConfig';
import { ImageEmbeddingProvider } from './imageEmbeddingProvider';
import { FirebaseStorageImageReader } from './firebaseStorageImageReader';
import { GoogleImageEmbeddingClient } from './googleImageEmbeddingClient';
import type { ImageEmbeddingLogger } from './imageEmbeddingTypes';

export function createImageEmbeddingProvider(
  projectId: string,
  logger: ImageEmbeddingLogger,
): ImageEmbeddingProvider {
  return new ImageEmbeddingProvider(
    IMAGE_EMBEDDING_CONFIG,
    new FirebaseStorageImageReader(),
    new GoogleImageEmbeddingClient(projectId, IMAGE_EMBEDDING_CONFIG),
    logger,
  );
}

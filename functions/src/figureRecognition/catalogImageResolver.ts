import { getStorage } from 'firebase-admin/storage';
import type { CatalogImageResolver, ResolvedCatalogImage } from './catalogEmbeddingTypes';
import type { StorageImageReader } from './imageEmbeddingTypes';

type Bucket = { file(path: string): { exists(): Promise<[boolean]> } };
export const CATALOG_IMAGE_EXTENSIONS = ['.avif', '.webp', '.png', '.jpg', '.jpeg'] as const;

export class FirebaseCatalogImageResolver implements CatalogImageResolver {
  constructor(
    private readonly reader: StorageImageReader,
    private readonly bucket: Bucket = getStorage().bucket(),
  ) {}

  async resolve(imageKey: string): Promise<ResolvedCatalogImage> {
    for (const extension of CATALOG_IMAGE_EXTENSIONS) {
      const objectPath = `catalog/figures/${imageKey}${extension}`;
      const [exists] = await this.bucket.file(objectPath).exists();
      if (exists) return { ...(await this.reader.read(objectPath)), objectPath };
    }
    throw new Error(`No catalog image found for imageKey ${imageKey}`);
  }
}

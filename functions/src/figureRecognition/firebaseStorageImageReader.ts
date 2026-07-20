import { getStorage } from 'firebase-admin/storage';
import type { StorageImageReader, StoredImage } from './imageEmbeddingTypes';

type StorageFile = {
  download(): Promise<[Buffer, ...unknown[]]>;
  getMetadata(): Promise<[Record<string, unknown>, ...unknown[]]>;
};

type StorageBucket = {
  file(objectPath: string): StorageFile;
};

const SUPPORTED_IMAGE_MIME_TYPES = new Set([
  'image/avif',
  'image/bmp',
  'image/heic',
  'image/heif',
  'image/jpeg',
  'image/png',
  'image/webp',
]);

/** Reads images only from the Firebase app's configured default bucket. */
export class FirebaseStorageImageReader implements StorageImageReader {
  constructor(private readonly bucket: StorageBucket = getStorage().bucket()) {}

  async read(objectPath: string): Promise<StoredImage> {
    const validatedPath = validateStorageObjectPath(objectPath);
    const file = this.bucket.file(validatedPath);
    const [[metadata], [bytes]] = await Promise.all([
      file.getMetadata(),
      file.download(),
    ]);
    const mimeType = readMimeType(metadata);
    return { bytes, mimeType };
  }
}

export function validateStorageObjectPath(objectPath: string): string {
  const trimmed = objectPath.trim();
  if (!trimmed) throw new Error('Storage object path is required');
  if (trimmed !== objectPath) {
    throw new Error('Storage object path must not contain surrounding whitespace');
  }
  if (
    trimmed.startsWith('/') ||
    trimmed.includes('\\') ||
    trimmed.includes('://') ||
    trimmed.split('/').some((part) => part === '' || part === '.' || part === '..')
  ) {
    throw new Error('Expected a Firebase Storage object path, not a URL or bucket URI');
  }
  return trimmed;
}

function readMimeType(metadata: Record<string, unknown>): string {
  const raw = metadata.contentType;
  const mimeType = typeof raw === 'string' ? raw.trim().toLowerCase() : '';
  if (!SUPPORTED_IMAGE_MIME_TYPES.has(mimeType)) {
    throw new Error('Storage object is missing a supported image MIME type');
  }
  return mimeType;
}

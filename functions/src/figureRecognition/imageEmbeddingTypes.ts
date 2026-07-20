export type StoredImage = {
  bytes: Buffer;
  mimeType: string;
};

export interface StorageImageReader {
  read(objectPath: string): Promise<StoredImage>;
}

export interface ImageEmbeddingClient {
  embed(image: StoredImage): Promise<number[]>;
}

export type ImageEmbeddingLog = {
  success: boolean;
  model: string;
  location: string;
  dimension: number;
  elapsedMs: number;
};

export interface ImageEmbeddingLogger {
  log(entry: ImageEmbeddingLog): void;
}

export type ImageEmbeddingResult = {
  vector: number[];
  model: string;
  location: string;
  dimension: number;
  elapsedMs: number;
};

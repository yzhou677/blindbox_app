import type { ImageEmbeddingConfig } from './imageEmbeddingConfig';
import type {
  ImageEmbeddingClient,
  ImageEmbeddingLogger,
  ImageEmbeddingResult,
  StorageImageReader,
} from './imageEmbeddingTypes';

export class ImageEmbeddingProvider {
  constructor(
    private readonly config: ImageEmbeddingConfig,
    private readonly storage: StorageImageReader,
    private readonly client: ImageEmbeddingClient,
    private readonly logger: ImageEmbeddingLogger,
    private readonly now: () => number = Date.now,
  ) {}

  async embedStorageObject(objectPath: string): Promise<ImageEmbeddingResult> {
    const startedAt = this.now();
    try {
      const image = await this.storage.read(objectPath);
      const vector = await this.client.embed(image);
      validateVector(vector, this.config.outputDimension);
      const elapsedMs = Math.max(0, this.now() - startedAt);
      this.logger.log(this.logEntry(true, vector.length, elapsedMs));
      return {
        vector,
        model: this.config.model,
        location: this.config.location,
        dimension: vector.length,
        elapsedMs,
      };
    } catch (error) {
      const elapsedMs = Math.max(0, this.now() - startedAt);
      this.logger.log(
        this.logEntry(false, this.config.outputDimension, elapsedMs),
      );
      throw error;
    }
  }

  private logEntry(success: boolean, dimension: number, elapsedMs: number) {
    return {
      success,
      model: this.config.model,
      location: this.config.location,
      dimension,
      elapsedMs,
    };
  }
}

function validateVector(vector: number[], expectedDimension: number): void {
  if (vector.length !== expectedDimension) {
    throw new Error(
      `Embedding dimension mismatch: expected ${expectedDimension}, received ${vector.length}`,
    );
  }
  if (!vector.every((value) => Number.isFinite(value))) {
    throw new Error('Embedding contains a non-finite numeric value');
  }
}

import { GoogleGenAI } from '@google/genai';
import type { ImageEmbeddingConfig } from './imageEmbeddingConfig';
import type { ImageEmbeddingClient, StoredImage } from './imageEmbeddingTypes';
import { measureScanStage, measureScanStageSync } from './scanTiming';

type EmbedContentClient = {
  models: {
    embedContent(input: {
      model: string;
      contents: {
        parts: Array<{
          inlineData: { data: string; mimeType: string };
        }>;
      };
      config: { outputDimensionality: number };
    }): Promise<{ embeddings?: Array<{ values?: number[] }> }>;
  };
};

/** Google multimodal embedding adapter. Authentication is provided by ADC. */
export class GoogleImageEmbeddingClient implements ImageEmbeddingClient {
  private readonly client: EmbedContentClient;

  constructor(
    projectId: string,
    private readonly config: ImageEmbeddingConfig,
    client?: EmbedContentClient,
  ) {
    if (!projectId.trim()) throw new Error('Google Cloud project ID is required');
    this.client =
      client ??
      new GoogleGenAI({
        vertexai: true,
        project: projectId,
        location: config.location,
      });
  }

  async embed(image: StoredImage): Promise<number[]> {
    const request = measureScanStageSync('embedding_request_serialization', () => ({
      model: this.config.model,
      contents: {
        parts: [
          {
            inlineData: {
              data: image.bytes.toString('base64'),
              mimeType: image.mimeType,
            },
          },
        ],
      },
      config: { outputDimensionality: this.config.outputDimension },
    }));
    const response = await measureScanStage('embedding_api_wait', () => this.client.models.embedContent(request));
    const values = measureScanStageSync('embedding_response_parsing', () => response.embeddings?.[0]?.values);
    if (!values) throw new Error('Embedding response did not contain a vector');
    return values;
  }
}

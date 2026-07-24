import { GoogleGenAI } from '@google/genai';
import type { PrimarySubjectConfig } from './primarySubjectConfig';
import type { StoredImage } from './imageEmbeddingTypes';
import type { PrimarySubjectLocator } from './primarySubjectTypes';
import { measureScanStage, measureScanStageSync } from './scanTiming';

export const PRIMARY_SUBJECT_PROMPT = `Propose up to three physical collectible or designer-toy figure candidates visible in the image.
Each candidate bounding box must represent exactly one collectible. Never merge nearby collectibles or unrelated objects into one box. Do not decide which candidate is primary and do not rank candidates.
Ignore beverage cans, drinks, food containers, props, display shelves, furniture, plants, decorations, reflections, screens, posters, printed characters, packaging artwork, photographs of figures, plush toys in the background, and other surrounding objects.
Also ignore hands, keyboards, and tables. Each box must tightly enclose only its collectible; include an object only when physically attached to that collectible. Avoid large background regions. Return zero candidates when no physical collectible is visible.
Do not identify, name, classify, or guess any Catalog entity. Return only data matching the supplied schema and no analysis or prose.`;

export const PRIMARY_SUBJECT_RESPONSE_SCHEMA = {
  type: 'object', additionalProperties: false, required: ['candidates'],
  properties: {
    candidates: { type: 'array', minItems: 0, maxItems: 3, items: { type: 'object', additionalProperties: false, required: ['bbox'], properties: {
      bbox: { type: 'array', minItems: 4, maxItems: 4, items: { type: 'number' } },
    } } },
  },
} as const;

type GenerateClient = { models: { generateContent(request: Record<string, unknown>): Promise<{ text?: string }> } };
type ClientFactory = (options: { vertexai: true; project: string; location: string }) => GenerateClient;

/** Semantic localization only. Vertex mode obtains credentials exclusively from ADC. */
export class GooglePrimarySubjectLocator implements PrimarySubjectLocator {
  private readonly client: GenerateClient;
  constructor(
    projectId: string,
    private readonly config: PrimarySubjectConfig,
    client?: GenerateClient,
    clientFactory: ClientFactory = (options) => new GoogleGenAI(options) as unknown as GenerateClient,
    private readonly delay: (ms: number) => Promise<void> = (ms) => new Promise((resolve) => setTimeout(resolve, ms)),
  ) {
    if (!projectId.trim()) throw new Error('Google Cloud project ID is required');
    this.client = client ?? clientFactory({ vertexai: true, project: projectId, location: config.location });
  }
  async locate(image: StoredImage): Promise<unknown> {
    const request = measureScanStageSync('locator_request_serialization', () => ({
      model: this.config.model,
      contents: [{ role: 'user', parts: [{ text: PRIMARY_SUBJECT_PROMPT }, { inlineData: { data: image.bytes.toString('base64'), mimeType: image.mimeType } }] }],
      config: {
        temperature: this.config.temperature,
        mediaResolution: this.config.mediaResolution,
        responseMimeType: 'application/json',
        responseJsonSchema: PRIMARY_SUBJECT_RESPONSE_SCHEMA,
      },
    }));
    let response: { text?: string } | undefined;
    for (let attempt = 0; attempt < 3; attempt++) {
      try { response = await measureScanStage('locator_model_api_wait', () => this.client.models.generateContent(request), { attempt: attempt + 1 }); break; }
      catch (error) {
        if (!isTransientGoogleError(error) || attempt === 2) throw error;
        await this.delay(400 * 2 ** attempt);
      }
    }
    if (!response || typeof response.text !== 'string') throw new Error('Primary subject locator returned no structured response');
    try { return measureScanStageSync('locator_response_parsing', () => JSON.parse(response.text!)); } catch { throw new Error('Primary subject locator returned malformed JSON'); }
  }
}

function isTransientGoogleError(error: unknown): boolean {
  if (typeof error !== 'object' || error === null) return false;
  const value = error as { code?: unknown; status?: unknown; name?: unknown };
  const code = typeof value.code === 'number' ? value.code : typeof value.status === 'number' ? value.status : undefined;
  const label = String(value.code ?? value.status ?? value.name ?? '').toUpperCase();
  return code === 408 || code === 429 || (code !== undefined && code >= 500) || ['DEADLINE_EXCEEDED', 'RESOURCE_EXHAUSTED', 'ETIMEDOUT'].includes(label);
}

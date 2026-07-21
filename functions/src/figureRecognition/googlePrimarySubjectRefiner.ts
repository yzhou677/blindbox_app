import { GoogleGenAI } from '@google/genai';
import type { PrimarySubjectConfig } from './primarySubjectConfig';
import type { StoredImage } from './imageEmbeddingTypes';
import type { PrimarySubjectRefiner } from './primarySubjectTypes';

export const PRIMARY_SUBJECT_REFINEMENT_PROMPT = `Tightly locate the same physical collectible figure that is already the intended subject of this crop.
Return one bounding box around the collectible itself.
Include all physically attached identifying parts, including ears, hair, hats, horns, wings, tails, limbs, accessories, and bases.
Exclude unrelated nearby objects, background figures, beverage cans, shelves, hands, reflections, and empty background.
Do not identify or name the collectible. Do not choose another figure. Return only structured JSON.`;

export const PRIMARY_SUBJECT_REFINEMENT_SCHEMA = {
  type: 'object', additionalProperties: false, required: ['bbox'],
  properties: { bbox: { type: 'array', minItems: 4, maxItems: 4, items: { type: 'number' } } },
} as const;

type GenerateClient = { models: { generateContent(request: Record<string, unknown>): Promise<{ text?: string }> } };
type ClientFactory = (options: { vertexai: true; project: string; location: string }) => GenerateClient;

export class GooglePrimarySubjectRefiner implements PrimarySubjectRefiner {
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

  async refine(image: StoredImage): Promise<unknown> {
    const request = {
      model: this.config.model,
      contents: [{ role: 'user', parts: [{ text: PRIMARY_SUBJECT_REFINEMENT_PROMPT }, { inlineData: { data: image.bytes.toString('base64'), mimeType: image.mimeType } }] }],
      config: { temperature: this.config.temperature, mediaResolution: this.config.mediaResolution, responseMimeType: 'application/json', responseJsonSchema: PRIMARY_SUBJECT_REFINEMENT_SCHEMA },
    };
    let response: { text?: string } | undefined;
    for (let attempt = 0; attempt < 3; attempt++) {
      try { response = await this.client.models.generateContent(request); break; }
      catch (error) {
        if (!isTransient(error) || attempt === 2) throw error;
        await this.delay(400 * 2 ** attempt);
      }
    }
    if (!response || typeof response.text !== 'string') throw new Error('Primary subject refiner returned no structured response');
    try { return JSON.parse(response.text); } catch { throw new Error('Primary subject refiner returned malformed JSON'); }
  }
}

function isTransient(error: unknown): boolean {
  if (typeof error !== 'object' || error === null) return false;
  const value = error as { code?: unknown; status?: unknown; name?: unknown };
  const code = typeof value.code === 'number' ? value.code : typeof value.status === 'number' ? value.status : undefined;
  const label = String(value.code ?? value.status ?? value.name ?? '').toUpperCase();
  return code === 408 || code === 429 || (code !== undefined && code >= 500) || ['DEADLINE_EXCEEDED', 'RESOURCE_EXHAUSTED', 'ETIMEDOUT'].includes(label);
}

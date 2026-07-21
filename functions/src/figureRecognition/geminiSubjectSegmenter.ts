import { GoogleGenAI } from '@google/genai';
import sharp from 'sharp';
import type { PrimarySubjectConfig } from './primarySubjectConfig';
import { rasterizeAndProcessPolygon, renderSegmentedSubject, validatePolygon } from './subjectMaskProcessor';
import type { SubjectSegmentationDiagnostics, SubjectSegmentationInput, SubjectSegmentationResult, SubjectSegmenter } from './subjectSegmentationTypes';

export const PRIMARY_SUBJECT_SEGMENTATION_PROMPT = `Segment only the same physical collectible figure that is already the intended subject of this crop.
Return one polygon that follows the visible outer boundary of that collectible. Polygon points must be [x, y] normalized from 0 to 1000 relative to this crop.
Include all physically attached identifying parts, including ears, hair, hats, horns, wings, tails, limbs, clothing, attached flowers, accessories, and bases.
Exclude unrelated nearby objects, beverage cans, shelves, hands, reflections, background figures, decorations, props, packaging artwork, and empty background.
Do not identify, name, classify, or describe the collectible. Do not select a different figure.
Return only structured JSON matching the supplied schema with no reasoning or prose.`;

export const PRIMARY_SUBJECT_SEGMENTATION_SCHEMA = {
  type: 'object', additionalProperties: false, required: ['polygons'],
  properties: {
    polygons: {
      type: 'array', minItems: 0, maxItems: 1,
      items: {
        type: 'object', additionalProperties: false, required: ['points'],
        properties: {
          points: {
            type: 'array', minItems: 3,
            items: { type: 'array', minItems: 2, maxItems: 2, items: { type: 'number' } },
          },
        },
      },
    },
  },
} as const;

type GenerateClient = { models: { generateContent(request: Record<string, unknown>): Promise<{ text?: string }> } };
type ClientFactory = (options: { vertexai: true; project: string; location: string }) => GenerateClient;

/** Gemini-specific schema, transport and polygon semantics stop at this boundary. */
export class GeminiSubjectSegmenter implements SubjectSegmenter {
  private readonly client: GenerateClient;
  constructor(
    projectId: string,
    private readonly config: PrimarySubjectConfig,
    client?: GenerateClient,
    clientFactory: ClientFactory = (options) => new GoogleGenAI(options) as unknown as GenerateClient,
    private readonly delay: (ms: number) => Promise<void> = (ms) => new Promise((resolve) => setTimeout(resolve, ms)),
    private readonly now: () => number = Date.now,
  ) {
    if (!projectId.trim()) throw new Error('Google Cloud project ID is required');
    this.client = client ?? clientFactory({ vertexai: true, project: projectId, location: config.location });
  }

  async segment(input: SubjectSegmentationInput): Promise<SubjectSegmentationResult> {
    const startedAt = this.now();
    const base = (): SubjectSegmentationDiagnostics => ({
      method: 'gemini-polygon', modelVersion: this.config.model, promptVersion: this.config.segmentation.promptVersion, elapsedMs: this.now() - startedAt,
    });
    try {
      const metadata = await sharp(input.image.bytes).rotate().metadata();
      if (!metadata.width || !metadata.height) return unavailable(base(), 'invalid_image_dimensions');
      const dimensions = { sourceWidth: metadata.width, sourceHeight: metadata.height };
      const request = {
        model: this.config.model,
        contents: [{ role: 'user', parts: [{ text: PRIMARY_SUBJECT_SEGMENTATION_PROMPT }, { inlineData: { data: input.image.bytes.toString('base64'), mimeType: input.image.mimeType } }] }],
        config: {
          temperature: this.config.temperature,
          mediaResolution: this.config.mediaResolution,
          responseMimeType: 'application/json',
          responseJsonSchema: PRIMARY_SUBJECT_SEGMENTATION_SCHEMA,
        },
      };
      const response = await this.generate(request);
      if (!response || typeof response.text !== 'string') return unavailable({ ...base(), ...dimensions }, 'missing_structured_response');
      let parsed: unknown;
      try { parsed = JSON.parse(response.text); } catch { return unavailable({ ...base(), ...dimensions }, 'malformed_structured_response'); }
      let polygons: unknown[];
      try { polygons = extractPolygons(parsed); } catch (error) { return unavailable({ ...base(), ...dimensions }, safeReason(error, 'invalid_response_shape')); }
      if (polygons.length === 0) return unavailable({ ...base(), ...dimensions, sourcePolygonCount: 0 }, 'empty_polygon_response');
      if (polygons.length !== 1) return unavailable({ ...base(), ...dimensions, sourcePolygonCount: polygons.length }, 'multiple_polygons');
      let points;
      try { points = validatePolygon(polygons[0], this.config.segmentation); }
      catch (error) { return unavailable({ ...base(), ...dimensions, sourcePolygonCount: 1 }, safeReason(error, 'invalid_polygon')); }
      let processed;
      try { processed = rasterizeAndProcessPolygon(points, metadata.width, metadata.height, input.refinedBoundingBox, this.config.segmentation); }
      catch (error) { return unavailable({ ...base(), ...dimensions, sourcePolygonCount: 1, acceptedPolygonPointCount: points.length }, safeReason(error, 'unsafe_mask')); }
      const rendered = await renderSegmentedSubject(input.image, processed);
      const diagnostics: SubjectSegmentationDiagnostics = {
        ...base(), ...dimensions, sourcePolygonCount: 1, acceptedPolygonPointCount: processed.acceptedPolygonPointCount,
        rawForegroundAreaRatio: processed.rawForegroundAreaRatio, finalForegroundAreaRatio: processed.finalForegroundAreaRatio,
        foregroundAreaRatio: processed.finalForegroundAreaRatio, connectedComponentCount: processed.connectedComponentCount,
        tightBoundingBox: processed.tightBoundingBox,
      };
      return { status: 'segmented', image: rendered.image, mask: processed.mask, tightBoundingBox: processed.tightBoundingBox, preview: rendered.preview, diagnostics };
    } catch {
      return unavailable(base(), 'provider_failure');
    }
  }

  private async generate(request: Record<string, unknown>): Promise<{ text?: string }> {
    for (let attempt = 0; attempt < 3; attempt++) {
      try { return await this.client.models.generateContent(request); }
      catch (error) {
        if (!isTransient(error) || attempt === 2) throw error;
        await this.delay(400 * 2 ** attempt);
      }
    }
    throw new Error('unreachable');
  }
}

function extractPolygons(value: unknown): unknown[] {
  if (!isExactObject(value, ['polygons']) || !Array.isArray(value.polygons)) throw new Error('invalid_response_shape');
  return value.polygons.map((polygon) => {
    if (!isExactObject(polygon, ['points']) || !Array.isArray(polygon.points)) throw new Error('invalid_polygon_shape');
    return polygon.points;
  });
}

function isExactObject(value: unknown, keys: string[]): value is Record<string, unknown> {
  if (typeof value !== 'object' || value === null || Array.isArray(value)) return false;
  const actual = Object.keys(value).sort(); const expected = [...keys].sort();
  return actual.length === expected.length && actual.every((key, index) => key === expected[index]);
}

function unavailable(diagnostics: SubjectSegmentationDiagnostics, reason: string): SubjectSegmentationResult {
  return { status: 'unavailable', diagnostics: { ...diagnostics, reason } };
}

function safeReason(error: unknown, fallback: string): string {
  return error instanceof Error && /^[a-z_]+$/.test(error.message) ? error.message : fallback;
}

function isTransient(error: unknown): boolean {
  if (typeof error !== 'object' || error === null) return false;
  const value = error as { code?: unknown; status?: unknown; name?: unknown };
  const code = typeof value.code === 'number' ? value.code : typeof value.status === 'number' ? value.status : undefined;
  const label = String(value.code ?? value.status ?? value.name ?? '').toUpperCase();
  return code === 408 || code === 429 || (code !== undefined && code >= 500) || ['DEADLINE_EXCEEDED', 'RESOURCE_EXHAUSTED', 'ETIMEDOUT'].includes(label);
}

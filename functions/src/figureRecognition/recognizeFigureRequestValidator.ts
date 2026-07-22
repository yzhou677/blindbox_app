import sharp from 'sharp';
import type { StoredImage } from './imageEmbeddingTypes';
import { RECOGNIZE_FIGURE_ENDPOINT_CONFIG as config } from './recognizeFigureEndpointConfig';
import { RecognizeFigureRequestError, type RecognizeFigureRequestV1 } from './recognizeFigureEndpointTypes';

const requestIdPattern = /^[A-Za-z0-9._:-]{1,64}$/;
export async function validateRecognizeFigureRequest(value: unknown): Promise<{ request: RecognizeFigureRequestV1; image: StoredImage }> {
  if (!record(value) || unknown(value, ['version', 'image', 'selection', 'continueBorderline', 'requestId']) || value.version !== 1 || !record(value.image) || unknown(value.image, ['dataBase64', 'mimeType']) || !record(value.selection) || unknown(value.selection, ['left', 'top', 'width', 'height', 'coordinateSpace'])) throw new RecognizeFigureRequestError('invalid_request');
  if (value.requestId !== undefined && (typeof value.requestId !== 'string' || !requestIdPattern.test(value.requestId))) throw new RecognizeFigureRequestError('invalid_request');
  if (value.continueBorderline !== undefined && typeof value.continueBorderline !== 'boolean') throw new RecognizeFigureRequestError('invalid_request');
  const mimeType = value.image.mimeType;
  if (typeof mimeType !== 'string' || !(config.allowedMimeTypes as readonly string[]).includes(mimeType)) throw new RecognizeFigureRequestError('unsupported_mime_type');
  const encoded = value.image.dataBase64;
  if (typeof encoded !== 'string' || !encoded.length || encoded.length > Math.ceil(config.maxDecodedBytes / 3) * 4 || !/^[A-Za-z0-9+/]+={0,2}$/.test(encoded) || encoded.length % 4 !== 0) throw new RecognizeFigureRequestError(encoded?.length ? 'payload_too_large' : 'invalid_request');
  const bytes = Buffer.from(encoded, 'base64');
  if (!bytes.length || bytes.length > config.maxDecodedBytes || bytes.toString('base64') !== encoded) throw new RecognizeFigureRequestError(bytes.length > config.maxDecodedBytes ? 'payload_too_large' : 'invalid_request');
  let metadata: { width?: number; height?: number };
  try { metadata = await sharp(bytes).metadata(); } catch { throw new RecognizeFigureRequestError('invalid_image'); }
  const width = metadata.width ?? 0, height = metadata.height ?? 0;
  if (!width || !height) throw new RecognizeFigureRequestError('invalid_image');
  if (width > config.maxWidth || height > config.maxHeight || width * height > config.maxPixels) throw new RecognizeFigureRequestError('image_dimensions_unsupported');
  const selection = value.selection;
  const numbers = [selection.left, selection.top, selection.width, selection.height];
  if (selection.coordinateSpace !== 'normalized_oriented_image' || numbers.some((item) => typeof item !== 'number' || !Number.isFinite(item)) || selection.left < 0 || selection.top < 0 || selection.width <= 0 || selection.height <= 0 || selection.left + selection.width > 1 || selection.top + selection.height > 1) throw new RecognizeFigureRequestError('invalid_selection');
  return { request: value as RecognizeFigureRequestV1, image: { bytes, mimeType: mimeType as StoredImage['mimeType'] } };
}
function record(value: unknown): value is Record<string, any> { return typeof value === 'object' && value !== null && !Array.isArray(value); }
function unknown(value: Record<string, unknown>, keys: string[]): boolean { return Object.keys(value).some((key) => !keys.includes(key)); }

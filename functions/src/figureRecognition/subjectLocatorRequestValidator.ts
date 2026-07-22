import sharp from 'sharp';
import type { StoredImage } from './imageEmbeddingTypes';
import { SUBJECT_LOCATOR_ENDPOINT_CONFIG as config } from './subjectLocatorEndpointConfig';
import { SubjectLocatorRequestError, type SubjectLocatorRequestV1 } from './subjectLocatorEndpointTypes';

const requestIdPattern = /^[A-Za-z0-9._:-]{1,64}$/;

export async function validateSubjectLocatorRequest(value: unknown): Promise<{ request: SubjectLocatorRequestV1; image: StoredImage }> {
  if (!isRecord(value) || hasUnknownKeys(value, ['version', 'image', 'requestId']) || value.version !== 1 || !isRecord(value.image) || hasUnknownKeys(value.image, ['dataBase64', 'mimeType'])) {
    throw new SubjectLocatorRequestError('invalid_request');
  }
  if (value.requestId !== undefined && (typeof value.requestId !== 'string' || !requestIdPattern.test(value.requestId))) {
    throw new SubjectLocatorRequestError('invalid_request');
  }
  const mimeType = value.image.mimeType;
  if (typeof mimeType !== 'string' || !(config.allowedMimeTypes as readonly string[]).includes(mimeType)) {
    throw new SubjectLocatorRequestError('unsupported_mime_type');
  }
  const dataBase64 = value.image.dataBase64;
  if (typeof dataBase64 !== 'string' || dataBase64.length === 0) throw new SubjectLocatorRequestError('invalid_request');
  if (dataBase64.length > Math.ceil(config.maxDecodedBytes / 3) * 4) throw new SubjectLocatorRequestError('payload_too_large');
  if (!/^[A-Za-z0-9+/]+={0,2}$/.test(dataBase64) || dataBase64.length % 4 !== 0) throw new SubjectLocatorRequestError('invalid_request');
  const bytes = Buffer.from(dataBase64, 'base64');
  if (bytes.length === 0 || bytes.length > config.maxDecodedBytes || bytes.toString('base64') !== dataBase64) {
    throw new SubjectLocatorRequestError(bytes.length > config.maxDecodedBytes ? 'payload_too_large' : 'invalid_request');
  }
  let metadata: { width?: number; height?: number };
  try { metadata = await sharp(bytes).metadata(); }
  catch { throw new SubjectLocatorRequestError('invalid_image'); }
  const width = metadata.width ?? 0;
  const height = metadata.height ?? 0;
  if (width <= 0 || height <= 0) throw new SubjectLocatorRequestError('invalid_image');
  if (width > config.maxWidth || height > config.maxHeight || width * height > config.maxPixels) {
    throw new SubjectLocatorRequestError('image_dimensions_unsupported');
  }
  return { request: value as SubjectLocatorRequestV1, image: { bytes, mimeType: mimeType as StoredImage['mimeType'] } };
}

function isRecord(value: unknown): value is Record<string, unknown> { return typeof value === 'object' && value !== null && !Array.isArray(value); }
function hasUnknownKeys(value: Record<string, unknown>, allowed: string[]): boolean { return Object.keys(value).some((key) => !allowed.includes(key)); }

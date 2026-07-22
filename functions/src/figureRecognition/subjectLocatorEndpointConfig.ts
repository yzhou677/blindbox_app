export const SUBJECT_LOCATOR_ENDPOINT_CONFIG = Object.freeze({
  contractVersion: 1,
  functionName: 'subjectLocatorV1',
  region: process.env.FUNCTION_REGION ?? 'us-central1',
  allowedMimeTypes: Object.freeze(['image/jpeg', 'image/png', 'image/webp'] as const),
  maxDecodedBytes: 6 * 1024 * 1024,
  maxWidth: 12_000,
  maxHeight: 12_000,
  maxPixels: 50_000_000,
  locatorTimeoutMs: 40_000,
  functionTimeoutSeconds: 45,
  locatorVersion: 'primary-subject-v3',
  selectorVersion: 'primary-subject-selector-v1',
});

export type SubjectLocatorEndpointConfig = typeof SUBJECT_LOCATOR_ENDPOINT_CONFIG;

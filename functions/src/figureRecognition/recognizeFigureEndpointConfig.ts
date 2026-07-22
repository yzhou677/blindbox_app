export const RECOGNIZE_FIGURE_ENDPOINT_CONFIG = Object.freeze({
  region: 'us-central1',
  functionTimeoutSeconds: 120,
  maxDecodedBytes: 18 * 1024 * 1024,
  maxWidth: 12000,
  maxHeight: 12000,
  maxPixels: 50_000_000,
  allowedMimeTypes: Object.freeze(['image/jpeg', 'image/png', 'image/webp']),
  retrievalTopK: 5,
  presentationCandidateLimit: 3,
});


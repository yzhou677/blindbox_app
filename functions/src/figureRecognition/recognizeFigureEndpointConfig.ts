export const RECOGNIZE_FIGURE_ENDPOINT_CONFIG = Object.freeze({
  region: 'us-central1',
  functionTimeoutSeconds: 120,
  maxDecodedBytes: 18 * 1024 * 1024,
  maxWidth: 12000,
  maxHeight: 12000,
  maxPixels: 50_000_000,
  allowedMimeTypes: Object.freeze(['image/jpeg', 'image/png', 'image/webp']),
  /** Global (legacy) image-level Top-K for unscoped recognition. */
  retrievalTopK: 5,
  /**
   * Series-scoped image-level Top-K over-fetch. Series typically have ~12–18
   * figures; alternatives can duplicate figureIds in the image-level Top-K.
   * Over-fetch then aggregate by figureId, then apply presentationCandidateLimit.
   * Legacy global requests keep retrievalTopK unchanged.
   */
  seriesScopedRetrievalTopK: 15,
  presentationCandidateLimit: 3,
});


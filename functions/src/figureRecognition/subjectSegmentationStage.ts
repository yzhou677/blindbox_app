import type { StoredImage } from './imageEmbeddingTypes';
import type { PixelBoundingBox } from './primarySubjectTypes';
import type { SubjectSegmentationOutcome, SubjectSegmenter } from './subjectSegmentationTypes';

/**
 * Owns the segmentation/fallback decision so embedding and retrieval never need
 * to know which foreground-isolation implementation is configured.
 */
export class SubjectSegmentationStage {
  constructor(private readonly segmenter?: SubjectSegmenter) {}

  async process(fallbackImage: StoredImage, refinedBoundingBox: PixelBoundingBox): Promise<SubjectSegmentationOutcome> {
    if (!this.segmenter) {
      return {
        result: { status: 'unavailable', diagnostics: { elapsedMs: 0, method: 'none', reason: 'not_configured' } },
        embeddingInput: fallbackImage,
        usedFallback: true,
      };
    }
    let result;
    try {
      result = await this.segmenter.segment({ image: fallbackImage, refinedBoundingBox });
    } catch {
      return {
        result: { status: 'unavailable', diagnostics: { elapsedMs: 0, method: 'unknown', reason: 'segmenter_failed' } },
        embeddingInput: fallbackImage,
        usedFallback: true,
      };
    }
    if (result.status === 'segmented') {
      return { result, embeddingInput: result.image, preview: result.preview, usedFallback: false };
    }
    return { result, embeddingInput: fallbackImage, usedFallback: true };
  }
}

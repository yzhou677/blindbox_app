import type { StoredImage } from './imageEmbeddingTypes';
import type { PixelBoundingBox } from './primarySubjectTypes';

/** Pixel coordinates are relative to the accepted refined/coarse crop in image. */
export type SubjectSegmentationInput = {
  image: StoredImage;
  refinedBoundingBox: PixelBoundingBox;
};

export type SubjectMask = {
  width: number;
  height: number;
  format: 'binary' | 'alpha';
  data: Uint8Array;
  coordinateSpace: 'segmentation-input';
};

export type SubjectSegmentationPreview = {
  mask: StoredImage;
  overlay: StoredImage;
  subject: StoredImage;
};

export type SubjectSegmentationDiagnostics = {
  elapsedMs: number;
  method: string;
  reason?: string;
  modelVersion?: string;
  foregroundAreaRatio?: number;
  connectedComponentCount?: number;
  promptVersion?: string;
  sourcePolygonCount?: number;
  acceptedPolygonPointCount?: number;
  rawForegroundAreaRatio?: number;
  finalForegroundAreaRatio?: number;
  tightBoundingBox?: PixelBoundingBox;
  sourceWidth?: number;
  sourceHeight?: number;
};

export type SubjectSegmentationResult =
  | {
      status: 'segmented';
      image: StoredImage;
      mask?: SubjectMask;
      tightBoundingBox?: PixelBoundingBox;
      preview?: SubjectSegmentationPreview;
      diagnostics: SubjectSegmentationDiagnostics;
    }
  | {
      status: 'unavailable';
      diagnostics: SubjectSegmentationDiagnostics;
    };

export interface SubjectSegmenter {
  segment(input: SubjectSegmentationInput): Promise<SubjectSegmentationResult>;
}

export type SubjectSegmentationOutcome = {
  result: SubjectSegmentationResult;
  embeddingInput: StoredImage;
  preview?: SubjectSegmentationPreview;
  usedFallback: boolean;
};

import type { StoredImage } from './imageEmbeddingTypes';
import type { SubjectSegmentationPreview, SubjectSegmentationResult } from './subjectSegmentationTypes';

export type NormalizedBoundingBox = { ymin: number; xmin: number; ymax: number; xmax: number };
export type PixelBoundingBox = { top: number; left: number; width: number; height: number };
export type LocatorCandidate = {
  box: NormalizedBoundingBox;
};
export type LocatorResponse = {
  candidates: LocatorCandidate[];
};
export interface PrimarySubjectLocator { locate(image: StoredImage): Promise<unknown>; }
export interface PrimarySubjectRefiner { refine(image: StoredImage): Promise<unknown>; }

export type PrimarySubjectRefinementDiagnostics = {
  attempted: boolean;
  accepted: boolean;
  reason: string;
  coarseNormalizedBox?: NormalizedBoundingBox;
  refinedNormalizedBox?: NormalizedBoundingBox;
  coarsePixelBox?: PixelBoundingBox;
  refinedPixelBox?: PixelBoundingBox;
  coarseArea?: number;
  refinedArea?: number;
  areaReductionRatio?: number;
  finalPadding: number;
};

export type SubjectCandidateGeometry = { normalized: NormalizedBoundingBox; pixels: PixelBoundingBox };
export type PrimarySubjectCandidateScore = SubjectCandidateGeometry & {
  candidateNumber: number;
  centerScore: number;
  sharpnessScore: number;
  areaScore: number;
  backgroundScore: number;
  totalScore: number;
  selected: boolean;
};
export type PrimarySubjectDiagnostics = {
  locatorModel: string;
  locatorPromptVersion: string;
  elapsedMs: number;
  sourceWidth?: number;
  sourceHeight?: number;
  cropWidth?: number;
  cropHeight?: number;
  subjectAreaRatio?: number;
  blurMetric?: number;
  blurThreshold?: number;
  blurAlgorithm?: string;
  detailMetric?: number;
  detailThreshold?: number;
  detailAlgorithm?: string;
  combinedBlurPassed?: boolean;
  failedBlurSignals?: Array<'sharpness' | 'gradient energy'>;
  padding?: number;
  processingResolution?: string;
  failedChecks?: Array<'blur' | 'subject size' | 'subject area'>;
  refinement?: PrimarySubjectRefinementDiagnostics;
  segmentation?: SubjectSegmentationResult['diagnostics'] & { status: SubjectSegmentationResult['status']; usedFallback: boolean; fallbackUsed: boolean; fallbackReason?: string };
};
export type PrimarySubjectResult =
  | { status: 'usable'; reason: 'single_intended_collectible'; boundingBox: SubjectCandidateGeometry; candidates: PrimarySubjectCandidateScore[]; previewCrops: { coarse: StoredImage; final: StoredImage; segmentation?: SubjectSegmentationPreview; embeddingInput: StoredImage }; embeddingInput: StoredImage; crop: StoredImage; diagnostics: PrimarySubjectDiagnostics }
  | { status: 'no_subject'; reason: 'no_collectible_visible' | 'invalid_locator_output'; diagnostics: PrimarySubjectDiagnostics }
  | { status: 'too_blurry'; reason: 'crop_detail_below_threshold'; candidates: PrimarySubjectCandidateScore[]; previewCrops: { coarse: StoredImage; final: StoredImage }; diagnostics: PrimarySubjectDiagnostics }
  | { status: 'subject_too_small'; reason: 'crop_dimensions_below_threshold' | 'subject_area_below_threshold'; candidates: PrimarySubjectCandidateScore[]; previewCrops: { coarse: StoredImage; final: StoredImage }; diagnostics: PrimarySubjectDiagnostics };

export type PrimarySubjectPreviewArtifacts = { coarseOverlay?: string; refinedOverlay?: string; coarseCrop?: string; segmentationMask?: string; segmentedOverlay?: string; segmentedSubject?: string; segmentationJson?: string; embeddingInput?: string; crop?: string };

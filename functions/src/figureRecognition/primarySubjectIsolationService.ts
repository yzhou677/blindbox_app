import type { PrimarySubjectConfig } from './primarySubjectConfig';
import type { StoredImage } from './imageEmbeddingTypes';
import { PrimarySubjectCropper } from './primarySubjectCropper';
import { PrimarySubjectCandidateSelector } from './primarySubjectCandidateSelector';
import type { PrimarySubjectRefinementService } from './primarySubjectRefinementService';
import { InvalidLocatorOutputError, validateLocatorResponse } from './primarySubjectOutputValidator';
import type { PrimarySubjectLocator, PrimarySubjectResult } from './primarySubjectTypes';
import { SubjectSegmentationStage } from './subjectSegmentationStage';
import type { SubjectSegmenter } from './subjectSegmentationTypes';
import { PrimarySubjectBlurEvaluator, type BlurQualityResult } from './primarySubjectBlurEvaluator';

export class PrimarySubjectIsolationService {
  constructor(
    private readonly locator: PrimarySubjectLocator,
    private readonly cropper: PrimarySubjectCropper,
    private readonly config: PrimarySubjectConfig,
    private readonly refinement?: PrimarySubjectRefinementService,
    segmenter?: SubjectSegmenter,
    private readonly now: () => number = Date.now,
    private readonly selector: PrimarySubjectCandidateSelector = new PrimarySubjectCandidateSelector(cropper, config),
    blur?: PrimarySubjectBlurEvaluator,
  ) { this.segmentation = new SubjectSegmentationStage(segmenter); this.blur = blur ?? new PrimarySubjectBlurEvaluator(cropper); }

  private readonly segmentation: SubjectSegmentationStage;
  private readonly blur: PrimarySubjectBlurEvaluator;

  async isolate(image: StoredImage): Promise<PrimarySubjectResult> {
    const startedAt = this.now();
    let response;
    try { response = validateLocatorResponse(await this.locator.locate(image)); }
    catch (error) {
      if (error instanceof InvalidLocatorOutputError) return { status: 'no_subject', reason: 'invalid_locator_output', diagnostics: this.diagnostics(startedAt) };
      throw error;
    }
    if (response.candidates.length === 0) return { status: 'no_subject', reason: 'no_collectible_visible', diagnostics: this.diagnostics(startedAt) };

    const prepared = await this.cropper.orient(image);
    const selection = await this.selector.select(prepared, response.candidates);
    const primary = selection.selected.candidate;
    const coarseCrop = selection.selected.crop;
    let crop = coarseCrop;
    let boundingBox = selection.selected.score;
    let refinement = { attempted: false, accepted: false, reason: 'not_configured', finalPadding: this.config.finalRefinementPaddingRatio };
    let areaRatio = ((primary.box.xmax - primary.box.xmin) * (primary.box.ymax - primary.box.ymin)) / 1_000_000;
    if (this.refinement) {
      const refined = await this.refinement.refine(prepared, coarseCrop);
      crop = refined.crop;
      refinement = refined.diagnostics;
      if (refined.diagnostics.accepted) {
        boundingBox = { ...selection.selected.score, normalized: refined.normalized, pixels: refined.box };
        areaRatio = (refined.box.width * refined.box.height) / (prepared.width * prepared.height);
      }
    }
    const candidateScores = selection.candidates.map(({ score }) => score);
    const failedChecks: Array<'blur' | 'subject size' | 'subject area'> = [];
    const cropDimensionsFailed = crop.box.width < this.config.minCropWidth || crop.box.height < this.config.minCropHeight;
    const subjectAreaFailed = areaRatio < this.config.minSubjectAreaRatio;
    const blur = await this.blur.evaluateImage(crop.image);
    const blurFailed = !blur.usable;
    if (cropDimensionsFailed) failedChecks.push('subject size');
    if (subjectAreaFailed) failedChecks.push('subject area');
    if (blurFailed) failedChecks.push('blur');
    const diagnostics = { ...this.diagnostics(startedAt, prepared.width, prepared.height, crop.width, crop.height, areaRatio, blur, failedChecks), refinement };
    if (cropDimensionsFailed) {
      return { status: 'subject_too_small', reason: 'crop_dimensions_below_threshold', candidates: candidateScores, previewCrops: { coarse: coarseCrop.image, final: crop.image }, diagnostics };
    }
    if (subjectAreaFailed) {
      return { status: 'subject_too_small', reason: 'subject_area_below_threshold', candidates: candidateScores, previewCrops: { coarse: coarseCrop.image, final: crop.image }, diagnostics };
    }
    if (blurFailed) return { status: 'too_blurry', reason: 'crop_detail_below_threshold', candidates: candidateScores, previewCrops: { coarse: coarseCrop.image, final: crop.image }, diagnostics };
    const segmentationInputBox = { left: 0, top: 0, width: crop.width, height: crop.height };
    const segmented = await this.segmentation.process(crop.image, segmentationInputBox);
    const segmentationDiagnostics = {
      ...segmented.result.diagnostics,
      status: segmented.result.status,
      usedFallback: segmented.usedFallback,
      fallbackUsed: segmented.usedFallback,
      fallbackReason: segmented.usedFallback ? segmented.result.diagnostics.reason : undefined,
    };
    return {
      status: 'usable',
      reason: 'single_intended_collectible',
      boundingBox,
      candidates: candidateScores,
      previewCrops: { coarse: coarseCrop.image, final: crop.image, segmentation: segmented.preview, embeddingInput: segmented.embeddingInput },
      embeddingInput: segmented.embeddingInput,
      // Backward-compatible alias. New callers should use embeddingInput.
      crop: segmented.embeddingInput,
      diagnostics: { ...diagnostics, segmentation: segmentationDiagnostics },
    };
  }

  private diagnostics(startedAt: number, sourceWidth?: number, sourceHeight?: number, cropWidth?: number, cropHeight?: number, subjectAreaRatio?: number, blur?: BlurQualityResult, failedChecks?: Array<'blur' | 'subject size' | 'subject area'>) {
    return {
      locatorModel: this.config.model,
      locatorPromptVersion: this.config.promptVersion,
      elapsedMs: this.now() - startedAt,
      sourceWidth,
      sourceHeight,
      cropWidth,
      cropHeight,
      subjectAreaRatio,
      blurMetric: blur?.sharpStats,
      blurThreshold: blur?.sharpStatsThreshold,
      blurAlgorithm: blur?.sharpnessAlgorithm,
      detailMetric: blur?.laplacianVariance,
      detailThreshold: blur?.laplacianVarianceThreshold,
      detailAlgorithm: blur?.detailAlgorithm,
      combinedBlurPassed: blur?.usable,
      failedBlurSignals: blur?.failedSignals,
      blurQuality: blur,
      padding: blur === undefined ? undefined : this.config.paddingRatio,
      processingResolution: cropWidth === undefined || cropHeight === undefined ? undefined : `${cropWidth}x${cropHeight}`,
      failedChecks,
    };
  }
}

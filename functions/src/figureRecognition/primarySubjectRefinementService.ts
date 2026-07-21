import type { PrimarySubjectConfig } from './primarySubjectConfig';
import { PrimarySubjectCropper, type PreparedCrop, type PreparedImage } from './primarySubjectCropper';
import { validateRefinementResponse } from './primarySubjectOutputValidator';
import type { NormalizedBoundingBox, PixelBoundingBox, PrimarySubjectRefinementDiagnostics, PrimarySubjectRefiner } from './primarySubjectTypes';

export type PrimarySubjectRefinementResult = { crop: PreparedCrop; box: PixelBoundingBox; normalized: NormalizedBoundingBox; diagnostics: PrimarySubjectRefinementDiagnostics };

export class PrimarySubjectRefinementService {
  constructor(private readonly refiner: PrimarySubjectRefiner, private readonly cropper: PrimarySubjectCropper, private readonly config: PrimarySubjectConfig) {}

  async refine(prepared: PreparedImage, coarse: PreparedCrop): Promise<PrimarySubjectRefinementResult> {
    const coarseNormalized = toNormalized(coarse.box, prepared.width, prepared.height);
    const base = this.diagnostics(coarse.box, coarseNormalized);
    try {
      const response = validateRefinementResponse(await this.refiner.refine(coarse.image));
      const refinedBox = mapToSource(response.box, coarse.box);
      const coarseArea = area(coarse.box);
      const refinedArea = area(refinedBox);
      const reduction = 1 - refinedArea / coarseArea;
      const details = { ...base, refinedNormalizedBox: toNormalized(refinedBox, prepared.width, prepared.height), refinedPixelBox: refinedBox, refinedArea, areaReductionRatio: reduction };
      if (!contains(coarse.box, refinedBox) || refinedArea > coarseArea) return this.fallback(coarse, coarseNormalized, details, 'refined_box_outside_coarse');
      if (reduction < this.config.minRefinementAreaReductionRatio) return this.fallback(coarse, coarseNormalized, details, 'area_reduction_too_small');
      if (reduction > this.config.maxRefinementAreaReductionRatio) return this.fallback(coarse, coarseNormalized, details, 'area_reduction_too_large');
      const finalBox = this.cropper.paddedPixelBox(refinedBox, this.config.finalRefinementPaddingRatio, prepared.width, prepared.height, coarse.box);
      const finalCrop = await this.cropper.cropPixelBox(prepared, finalBox);
      const subjectAreaRatio = refinedArea / (prepared.width * prepared.height);
      if (finalBox.width < this.config.minCropWidth || finalBox.height < this.config.minCropHeight || subjectAreaRatio < this.config.minSubjectAreaRatio) {
        return this.fallback(coarse, coarseNormalized, details, 'refined_crop_too_small');
      }
      if (finalCrop.sharpness < this.config.minSharpness && finalCrop.gradientEnergy < this.config.minGradientEnergy) {
        return this.fallback(coarse, coarseNormalized, details, 'refined_crop_too_blurry');
      }
      return { crop: finalCrop, box: refinedBox, normalized: details.refinedNormalizedBox, diagnostics: { ...details, accepted: true, reason: 'accepted' } };
    } catch {
      return this.fallback(coarse, coarseNormalized, base, 'refinement_failed');
    }
  }

  private diagnostics(coarseBox: PixelBoundingBox, coarseNormalizedBox: NormalizedBoundingBox): PrimarySubjectRefinementDiagnostics {
    return { attempted: true, accepted: false, reason: 'not_evaluated', coarseNormalizedBox, coarsePixelBox: coarseBox, coarseArea: area(coarseBox), finalPadding: this.config.finalRefinementPaddingRatio };
  }

  private fallback(coarse: PreparedCrop, normalized: NormalizedBoundingBox, diagnostics: PrimarySubjectRefinementDiagnostics, reason: string): PrimarySubjectRefinementResult {
    return { crop: coarse, box: coarse.box, normalized, diagnostics: { ...diagnostics, accepted: false, reason } };
  }
}

function mapToSource(box: NormalizedBoundingBox, coarse: PixelBoundingBox): PixelBoundingBox {
  const left = coarse.left + Math.floor((box.xmin / 1000) * coarse.width);
  const top = coarse.top + Math.floor((box.ymin / 1000) * coarse.height);
  const right = coarse.left + Math.ceil((box.xmax / 1000) * coarse.width);
  const bottom = coarse.top + Math.ceil((box.ymax / 1000) * coarse.height);
  return { left, top, width: right - left, height: bottom - top };
}
function toNormalized(box: PixelBoundingBox, width: number, height: number): NormalizedBoundingBox {
  return { ymin: (box.top / height) * 1000, xmin: (box.left / width) * 1000, ymax: ((box.top + box.height) / height) * 1000, xmax: ((box.left + box.width) / width) * 1000 };
}
function area(box: PixelBoundingBox): number { return box.width * box.height; }
function contains(outer: PixelBoundingBox, inner: PixelBoundingBox): boolean {
  return inner.left >= outer.left && inner.top >= outer.top && inner.left + inner.width <= outer.left + outer.width && inner.top + inner.height <= outer.top + outer.height;
}

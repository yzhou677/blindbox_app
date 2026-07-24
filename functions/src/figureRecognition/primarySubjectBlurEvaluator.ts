import type { StoredImage } from './imageEmbeddingTypes';
import { PrimarySubjectCropper } from './primarySubjectCropper';
import { BLUR_QUALITY_CONFIG, type BlurQualityConfig } from './blurQualityConfig';
import { calculateLaplacianVarianceMetric } from './blurMetricCalculators';
import { measureScanStage, measureScanStageSync } from './scanTiming';
export type BlurQuality = 'good' | 'borderline' | 'too_blurry';
export type BlurQualityResult = { quality: BlurQuality; laplacianVariance: number; sharpStats: number; meanAbsoluteGradient: number; laplacianPassed: boolean; sharpStatsPassed: boolean; evaluatorVersion: string; usable: boolean; laplacianVarianceThreshold: number; sharpStatsThreshold: number; sharpnessMetric: number; detailMetric: number; sharpnessThreshold: number; detailThreshold: number; sharpnessAlgorithm: 'sharp.stats().sharpness'; detailAlgorithm: 'variance of laplacian'; sharpnessPassed: boolean; detailPassed: boolean; combinedBlurPassed: boolean; failedSignals: Array<'sharpness' | 'laplacian variance'> };
export class PrimarySubjectBlurEvaluator {
  constructor(private readonly cropper: PrimarySubjectCropper, private readonly config: BlurQualityConfig = BLUR_QUALITY_CONFIG) {}
  async evaluateImage(image: StoredImage): Promise<BlurQualityResult> {
    const prepared = await measureScanStage('blur_metric_preparation_orientation', () => this.cropper.orient(image));
    const crop = await measureScanStage('sharp_stats', () => this.cropper.cropPixelBox(prepared, { left: 0, top: 0, width: prepared.width, height: prepared.height }));
    const laplacianVariance = await calculateLaplacianVarianceMetric(image, this.config.maxAnalysisDimension);
    return measureScanStageSync('blur_classification', () => this.classify(laplacianVariance, crop.sharpness, crop.gradientEnergy));
  }

  classify(laplacianVariance: number, sharpStats: number, meanAbsoluteGradient = 0): BlurQualityResult {
    const laplacianPassed = laplacianVariance >= this.config.laplacianVarianceThreshold, sharpStatsPassed = sharpStats >= this.config.sharpStatsThreshold;
    const quality: BlurQuality = laplacianPassed && sharpStatsPassed ? 'good' : laplacianPassed || sharpStatsPassed ? 'borderline' : 'too_blurry'; const usable = quality !== 'too_blurry';
    const failedSignals: Array<'sharpness' | 'laplacian variance'> = []; if (!sharpStatsPassed) failedSignals.push('sharpness'); if (!laplacianPassed) failedSignals.push('laplacian variance');
    return { quality, laplacianVariance, sharpStats, meanAbsoluteGradient, laplacianPassed, sharpStatsPassed, evaluatorVersion: this.config.evaluatorVersion, usable, laplacianVarianceThreshold: this.config.laplacianVarianceThreshold, sharpStatsThreshold: this.config.sharpStatsThreshold, sharpnessMetric: sharpStats, detailMetric: laplacianVariance, sharpnessThreshold: this.config.sharpStatsThreshold, detailThreshold: this.config.laplacianVarianceThreshold, sharpnessAlgorithm: 'sharp.stats().sharpness', detailAlgorithm: 'variance of laplacian', sharpnessPassed: sharpStatsPassed, detailPassed: laplacianPassed, combinedBlurPassed: usable, failedSignals };
  }
}

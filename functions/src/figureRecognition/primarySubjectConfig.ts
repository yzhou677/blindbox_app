export type PrimarySubjectConfig = {
  model: string;
  location: string;
  temperature: number;
  mediaResolution: 'MEDIA_RESOLUTION_HIGH';
  promptVersion: string;
  paddingRatio: number;
  minCropWidth: number;
  minCropHeight: number;
  minSubjectAreaRatio: number;
  minSharpness: number;
  minGradientEnergy: number;
  maxProcessedDimension: number;
  candidateScoreWeights: {
    center: number;
    sharpness: number;
    area: number;
    background: number;
  };
  candidateAreaScoreSaturation: number;
  refinementPromptVersion: string;
  minRefinementAreaReductionRatio: number;
  maxRefinementAreaReductionRatio: number;
  finalRefinementPaddingRatio: number;
  segmentation: {
    promptVersion: string;
    maxPolygonPoints: number;
    normalizedBoundaryOverflow: number;
    minForegroundAreaRatio: number;
    maxForegroundAreaRatio: number;
    anchorInsetRatio: number;
    minAnchorOverlapRatio: number;
    minAttachedComponentAreaRatio: number;
    maxAttachedComponentDistance: number;
    maxHoleAreaRatio: number;
    maxHolePixels: number;
    closingRadius: number;
    safetyPaddingRatio: number;
  };
};

/** Evaluation defaults live here so model and technical gates can be replaced centrally. */
export const PRIMARY_SUBJECT_CONFIG: Readonly<PrimarySubjectConfig> = Object.freeze({
  model: 'gemini-3.5-flash',
  location: 'us',
  temperature: 0,
  mediaResolution: 'MEDIA_RESOLUTION_HIGH',
  promptVersion: 'primary-subject-v3',
  paddingRatio: 0.12,
  minCropWidth: 160,
  minCropHeight: 160,
  minSubjectAreaRatio: 0.02,
  minSharpness: 1.5,
  minGradientEnergy: 1,
  maxProcessedDimension: 4096,
  candidateScoreWeights: Object.freeze({ center: 0.4, sharpness: 0.25, area: 0.2, background: 0.15 }),
  candidateAreaScoreSaturation: 0.25,
  refinementPromptVersion: 'primary-subject-refinement-v1',
  minRefinementAreaReductionRatio: 0.05,
  maxRefinementAreaReductionRatio: 0.70,
  finalRefinementPaddingRatio: 0.06,
  segmentation: Object.freeze({
    promptVersion: 'primary-subject-segmentation-v1',
    maxPolygonPoints: 512,
    normalizedBoundaryOverflow: 1,
    minForegroundAreaRatio: 0.03,
    maxForegroundAreaRatio: 0.92,
    anchorInsetRatio: 0.3,
    minAnchorOverlapRatio: 0.01,
    minAttachedComponentAreaRatio: 0.0005,
    maxAttachedComponentDistance: 2,
    maxHoleAreaRatio: 0.001,
    maxHolePixels: 256,
    closingRadius: 1,
    safetyPaddingRatio: 0.04,
  }),
});

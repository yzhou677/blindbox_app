import type { BlurQualityResult } from './primarySubjectBlurEvaluator';
export type BlurValidationLabel = 'sharp' | 'blurry';
export type BlurValidationDatasetEntry = { file: string; filePath: string; expectedLabel: BlurValidationLabel };
export type BlurValidationResult = BlurQualityResult & { file: string; expectedLabel: BlurValidationLabel; actualOutcome: 'usable' | 'too_blurry'; isCorrect: boolean };
export type BlurValidationSummary = { totalImages: number; sharpImages: number; blurryImages: number; correct: number; incorrect: number; accuracy: number; sharpPassCount: number; sharpRejectCount: number; sharpPassRate: number; sharpFalseRejectRate: number; blurryRejectCount: number; blurryPassCount: number; blurryRejectRate: number; blurryFalseAcceptRate: number; falseRejects: BlurValidationResult[]; falseAccepts: BlurValidationResult[] };

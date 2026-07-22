import type { LocalImageReader } from './localImageReader';
import type { PrimarySubjectBlurEvaluator } from './primarySubjectBlurEvaluator';
import type { BlurValidationDatasetEntry, BlurValidationResult, BlurValidationSummary } from './figureBlurValidationTypes';

export class FigureBlurValidationRunner {
  constructor(
    private readonly images: Pick<LocalImageReader, 'read'>,
    private readonly blur: Pick<PrimarySubjectBlurEvaluator, 'evaluateImage'>,
  ) {}

  async run(entries: readonly BlurValidationDatasetEntry[]): Promise<{ results: BlurValidationResult[]; summary: BlurValidationSummary }> {
    const results: BlurValidationResult[] = [];
    for (const entry of entries) {
      let image;
      try { image = await this.images.read(entry.filePath); }
      catch { throw new Error(`Unreadable or unsupported image: ${entry.file}`); }
      const assessment = await this.blur.evaluateImage(image);
      const actualOutcome = (assessment.usable ?? assessment.combinedBlurPassed) ? 'usable' : 'too_blurry';
      const isCorrect = entry.expectedLabel === 'sharp' ? actualOutcome === 'usable' : actualOutcome === 'too_blurry';
      results.push({ file: entry.file, expectedLabel: entry.expectedLabel, actualOutcome, isCorrect, ...assessment });
    }
    return { results, summary: aggregateBlurValidation(results) };
  }
}

export function aggregateBlurValidation(results: readonly BlurValidationResult[]): BlurValidationSummary {
  const sharp = results.filter((result) => result.expectedLabel === 'sharp');
  const blurry = results.filter((result) => result.expectedLabel === 'blurry');
  const falseRejects = sharp.filter((result) => !result.isCorrect);
  const falseAccepts = blurry.filter((result) => !result.isCorrect);
  const correct = results.filter((result) => result.isCorrect).length;
  return {
    totalImages: results.length,
    sharpImages: sharp.length,
    blurryImages: blurry.length,
    correct,
    incorrect: results.length - correct,
    accuracy: ratio(correct, results.length),
    sharpPassCount: sharp.length - falseRejects.length,
    sharpRejectCount: falseRejects.length,
    sharpPassRate: ratio(sharp.length - falseRejects.length, sharp.length),
    sharpFalseRejectRate: ratio(falseRejects.length, sharp.length),
    blurryRejectCount: blurry.length - falseAccepts.length,
    blurryPassCount: falseAccepts.length,
    blurryRejectRate: ratio(blurry.length - falseAccepts.length, blurry.length),
    blurryFalseAcceptRate: ratio(falseAccepts.length, blurry.length),
    falseRejects,
    falseAccepts,
  };
}

function ratio(value: number, total: number): number { return total === 0 ? 0 : value / total; }

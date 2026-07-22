import { promises as fs } from 'node:fs';
import path from 'node:path';
import type { FigureRetrievalEvaluationCaseResult, FigureRetrievalEvaluationSummary } from './figureRetrievalEvaluationTypes';

const OUTPUT_FILES = ['evaluation-results.json', 'evaluation-results.csv', 'evaluation-summary.json'] as const;
type EvaluationFileSystem = Pick<typeof fs, 'mkdir' | 'stat' | 'writeFile'>;

export class FigureRetrievalEvaluationWriter {
  constructor(private readonly fileSystem: EvaluationFileSystem = fs) {}

  async prepare(outputDir: string, overwrite: boolean): Promise<void> {
    if (!outputDir.trim()) throw new Error('Output directory is required');
    await this.fileSystem.mkdir(outputDir, { recursive: true });
    if (!overwrite) for (const filename of OUTPUT_FILES) {
      try { await this.fileSystem.stat(path.join(outputDir, filename)); throw new Error('Evaluation output already exists; use --overwrite'); }
      catch (error) {
        if (error instanceof Error && error.message.includes('already exists')) throw error;
        if ((error as { code?: unknown })?.code !== 'ENOENT') throw error;
      }
    }
  }

  async write(outputDir: string, results: readonly FigureRetrievalEvaluationCaseResult[], summary: FigureRetrievalEvaluationSummary): Promise<void> {
    await Promise.all([
      this.fileSystem.writeFile(path.join(outputDir, OUTPUT_FILES[0]), `${JSON.stringify(results, null, 2)}\n`, 'utf8'),
      this.fileSystem.writeFile(path.join(outputDir, OUTPUT_FILES[1]), toCsv(results), 'utf8'),
      this.fileSystem.writeFile(path.join(outputDir, OUTPUT_FILES[2]), `${JSON.stringify(summary, null, 2)}\n`, 'utf8'),
    ]);
  }
}

export function toCsv(results: readonly FigureRetrievalEvaluationCaseResult[]): string {
  const fields: Array<keyof FigureRetrievalEvaluationCaseResult> = [
    'id', 'catalogPresence', 'expectedFigureId', 'expectedSeriesId', 'status', 'isolationStatus', 'refinementAccepted', 'segmentationOutcome',
    'expectedRank', 'top1Correct', 'top3Correct', 'top5Correct', 'presentInTopK', 'top1FigureId', 'top1SeriesId', 'top1Distance', 'top2Distance',
    'top1Top2Gap', 'relativeTop1Top2Gap', 'distanceSpread', 'topSeriesRatio', 'topIpRatio', 'topBrandRatio', 'sameSeriesLeadingAmbiguity',
    'decisionOutcome', 'decisionReasons', 'policyVersion', 'shadowDecisionOutcome', 'candidateDecisionOutcome', 'candidateDecisionReasons', 'candidatePolicyVersion', 'calibrationProfile', 'elapsedMs', 'errorCode', 'errorComponent', 'returnedCandidates',
  ];
  const lines = [fields.map(csv).join(',')];
  for (const result of results) lines.push(fields.map((field) => csv(flatten(result[field]))).join(','));
  return `${lines.join('\n')}\n`;
}

function flatten(value: unknown): string | number | boolean | undefined {
  if (Array.isArray(value)) return value.every((item) => typeof item === 'string') ? value.join('|') : JSON.stringify(value);
  return value as string | number | boolean | undefined;
}
function csv(value: unknown): string { const text = value === undefined || value === null ? '' : String(value); return /[",\r\n]/.test(text) ? `"${text.replaceAll('"', '""')}"` : text; }

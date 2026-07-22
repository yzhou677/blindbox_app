import { validateTopK } from './figureRetrievalService';
import type { EvaluationProgress } from './figureRetrievalEvaluationRunner';
import type { FigureRetrievalEvaluationMetrics } from './figureRetrievalEvaluationTypes';
import type { FigureRetrievalCandidate } from './figureRetrievalTypes';

export type FigureRetrievalEvaluationCliOptions = { manifest: string; outputDir: string; topK: number; overwrite: boolean; continueOnError: boolean; previewDir?: string; overwritePreview: boolean; caseIds: string[]; debugTopCandidates: boolean; debugTopK: number };

export function parseFigureRetrievalEvaluationArgs(args: string[]): FigureRetrievalEvaluationCliOptions {
  let manifest: string | undefined; let outputDir: string | undefined; let topK = 5; let overwrite = false; let continueOnError = true; let previewDir: string | undefined; let overwritePreview = false; const caseIds: string[] = []; let debugTopCandidates = false; let debugTopK = 10; let debugTopKProvided = false;
  for (let index = 0; index < args.length; index++) {
    const arg = args[index];
    if (arg === '--manifest') manifest = requiredValue(args[++index], '--manifest');
    else if (arg === '--output-dir') outputDir = requiredValue(args[++index], '--output-dir');
    else if (arg === '--top-k') { topK = Number(requiredValue(args[++index], '--top-k')); validateTopK(topK); }
    else if (arg === '--overwrite') overwrite = true;
    else if (arg === '--preview-dir') previewDir = requiredValue(args[++index], '--preview-dir');
    else if (arg === '--overwrite-preview') overwritePreview = true;
    else if (arg === '--case-id') caseIds.push(requiredValue(args[++index], '--case-id'));
    else if (arg === '--case-ids') caseIds.push(...requiredValue(args[++index], '--case-ids').split(',').map((value) => value.trim()).filter(Boolean));
    else if (arg === '--debug-top-candidates') debugTopCandidates = true;
    else if (arg === '--debug-top-k') { debugTopK = Number(requiredValue(args[++index], '--debug-top-k')); validateTopK(debugTopK); debugTopKProvided = true; }
    else if (arg === '--continue-on-error') continueOnError = true;
    else throw new Error(`Unknown option: ${arg}`);
  }
  if (!manifest) throw new Error('--manifest is required');
  if (!outputDir) throw new Error('--output-dir is required');
  if (overwritePreview && !previewDir) throw new Error('--overwrite-preview requires --preview-dir');
  const unique = new Set<string>();
  for (const id of caseIds) { if (!/^photo-[0-9]{4,}$/.test(id)) throw new Error(`Invalid case ID: ${id}`); if (unique.has(id)) throw new Error(`Duplicate case ID: ${id}`); unique.add(id); }
  if (debugTopCandidates && caseIds.length === 0) throw new Error('--debug-top-candidates requires --case-id or --case-ids');
  if (debugTopKProvided && !debugTopCandidates) throw new Error('--debug-top-k requires --debug-top-candidates');
  return { manifest, outputDir, topK, overwrite, continueOnError, previewDir, overwritePreview, caseIds, debugTopCandidates, debugTopK };
}

export function filterEvaluationCases<T extends { id: string }>(cases: readonly T[], requestedIds: readonly string[]): { cases: T[]; skippedByFilterCount: number } {
  if (requestedIds.length === 0) return { cases: [...cases], skippedByFilterCount: 0 };
  const available = new Set(cases.map((entry) => entry.id));
  for (const id of requestedIds) if (!available.has(id)) throw new Error(`Unknown evaluation case ID: ${id}`);
  const selected = new Set(requestedIds);
  return { cases: cases.filter((entry) => selected.has(entry.id)), skippedByFilterCount: cases.length - selected.size };
}

export function formatEvaluationProgress(progress: EvaluationProgress): string[] {
  const result = progress.result;
  const lines = [`[${progress.index}/${progress.total}] ${result.id}`, `status: ${result.status}`];
  if (result.catalogPresence === 'absent') lines.push('catalogPresence: absent');
  if (result.expectedRank !== undefined) lines.push(`expectedRank: ${result.expectedRank}`);
  if (result.top1Distance !== undefined) lines.push(`top1Distance: ${result.top1Distance}`);
  if (result.decisionOutcome) lines.push(`decision: ${result.decisionOutcome}`);
  if (result.errorCode) lines.push(`errorCode: ${result.errorCode}`);
  lines.push(`elapsedMs: ${result.elapsedMs}`, '');
  return lines;
}

export function formatRetrievalDebug(caseId: string, expectedFigureId: string | undefined, candidates: readonly FigureRetrievalCandidate[], topK: number): string[] {
  const shown = candidates.slice(0, topK);
  const lines = ['====================================================', 'Retrieval Debug', `Case: ${caseId}`, '', 'Expected Figure:', expectedFigureId ?? 'Catalog absent', '', `Top ${topK} Candidates`, ''];
  for (const candidate of shown) lines.push(`${candidate.rank}.`, `figureId: ${candidate.figureId}`, `seriesId: ${candidate.seriesId}`, `brandId: ${candidate.brandId}`, `ipId: ${candidate.ipId}`, `distance: ${candidate.distance}`, '');
  if (expectedFigureId) {
    const correct = candidates.find((candidate) => candidate.figureId === expectedFigureId);
    lines.push('Correct Figure Rank:', correct ? String(correct.rank) : 'Not in retrieved candidates');
    if (correct) lines.push('', 'Correct Figure Distance:', String(correct.distance));
  } else lines.push('Correct Figure Rank:', 'Not applicable (Catalog absent)');
  lines.push('', '====================================================');
  return lines;
}

export function formatEvaluationSummary(metrics: FigureRetrievalEvaluationMetrics): string[] {
  return ['Evaluation summary', JSON.stringify({
    totalCases: metrics.totalCases, completedCases: metrics.completedCases, isolationRejectedCases: metrics.isolationRejectedCases,
    failedCases: metrics.failedCases, top1Accuracy: metrics.top1Accuracy, top3Accuracy: metrics.top3Accuracy,
    top5Accuracy: metrics.top5Accuracy, meanReciprocalRank: metrics.meanReciprocalRank,
    needsReviewCount: metrics.needsReviewCount, noConfidentMatchCount: metrics.noConfidentMatchCount,
    skippedByFilterCount: 'skippedByFilterCount' in metrics ? metrics.skippedByFilterCount : undefined,
    averageElapsedMs: metrics.averageElapsedMs, p95ElapsedMs: metrics.p95ElapsedMs,
  })];
}

function requiredValue(value: string | undefined, option: string): string { if (!value || value.startsWith('--')) throw new Error(`${option} requires a value`); return value; }

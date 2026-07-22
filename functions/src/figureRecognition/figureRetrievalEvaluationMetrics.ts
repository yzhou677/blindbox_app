import type { DistributionSummary, EvidenceDistributionGroup, FigureRetrievalEvaluationCaseResult, FigureRetrievalEvaluationMetrics } from './figureRetrievalEvaluationTypes';

export function aggregateFigureRetrievalEvaluation(results: readonly FigureRetrievalEvaluationCaseResult[]): FigureRetrievalEvaluationMetrics {
  const completed = results.filter((result) => result.status === 'completed');
  const presentCompleted = completed.filter((result) => result.catalogPresence === 'present' && result.expectedFigureId);
  const absentCompleted = completed.filter((result) => result.catalogPresence === 'absent');
  const elapsed = results.map((result) => result.elapsedMs).filter(finite);
  return {
    totalCases: results.length,
    catalogPresentCases: results.filter((result) => result.catalogPresence === 'present').length,
    catalogAbsentCases: results.filter((result) => result.catalogPresence === 'absent').length,
    completedCases: completed.length,
    isolationRejectedCases: results.filter((result) => result.status === 'isolation_rejected').length,
    failedCases: results.filter((result) => result.status === 'failed').length,
    top1Accuracy: accuracy(presentCompleted, 'top1Correct'),
    top3Accuracy: accuracy(presentCompleted, 'top3Correct'),
    top5Accuracy: accuracy(presentCompleted, 'top5Correct'),
    meanReciprocalRank: presentCompleted.length ? presentCompleted.reduce((sum, result) => sum + (result.expectedRank ? 1 / result.expectedRank : 0), 0) / presentCompleted.length : undefined,
    expectedPresentInTopKRate: accuracy(presentCompleted, 'presentInTopK'),
    highConfidenceCount: countOutcome(completed, 'high_confidence'),
    needsReviewCount: countOutcome(completed, 'needs_review'),
    noConfidentMatchCount: countOutcome(completed, 'no_confident_match'),
    catalogAbsentNeedsReviewCount: countOutcome(absentCompleted, 'needs_review'),
    catalogAbsentNoConfidentMatchCount: countOutcome(absentCompleted, 'no_confident_match'),
    catalogAbsentHighConfidenceCount: countOutcome(absentCompleted, 'high_confidence'),
    segmentedCount: results.filter((result) => result.segmentationOutcome === 'segmented').length,
    segmentationFallbackCount: results.filter((result) => result.segmentationOutcome === 'refined_crop_fallback').length,
    refinementAcceptedCount: results.filter((result) => result.refinementAccepted === true).length,
    isolationRejectedCount: results.filter((result) => result.status === 'isolation_rejected').length,
    averageElapsedMs: elapsed.length ? elapsed.reduce((sum, value) => sum + value, 0) / elapsed.length : 0,
    p50ElapsedMs: percentile(elapsed, 0.5) ?? 0,
    p95ElapsedMs: percentile(elapsed, 0.95) ?? 0,
    evidenceDistributions: { catalogPresent: distributions(presentCompleted), catalogAbsent: distributions(absentCompleted) },
  };
}

export function describeDistribution(values: readonly number[]): DistributionSummary {
  const sorted = values.filter(finite).slice().sort((a, b) => a - b);
  if (!sorted.length) return { count: 0 };
  return {
    count: sorted.length, min: sorted[0], max: sorted[sorted.length - 1], mean: sorted.reduce((sum, value) => sum + value, 0) / sorted.length,
    median: percentile(sorted, 0.5), p10: percentile(sorted, 0.1), p25: percentile(sorted, 0.25),
    p75: percentile(sorted, 0.75), p90: percentile(sorted, 0.9), p95: percentile(sorted, 0.95),
  };
}

function distributions(results: readonly FigureRetrievalEvaluationCaseResult[]): EvidenceDistributionGroup {
  return {
    top1Distance: describeDistribution(values(results, 'top1Distance')),
    top1Top2Gap: describeDistribution(values(results, 'top1Top2Gap')),
    relativeTop1Top2Gap: describeDistribution(values(results, 'relativeTop1Top2Gap')),
    distanceSpread: describeDistribution(values(results, 'distanceSpread')),
  };
}

function percentile(values: readonly number[], quantile: number): number | undefined {
  if (!values.length) return undefined;
  const sorted = values.slice().sort((a, b) => a - b); const position = (sorted.length - 1) * quantile;
  const lower = Math.floor(position); const upper = Math.ceil(position);
  return lower === upper ? sorted[lower] : sorted[lower] + (sorted[upper] - sorted[lower]) * (position - lower);
}

function values(results: readonly FigureRetrievalEvaluationCaseResult[], field: 'top1Distance' | 'top1Top2Gap' | 'relativeTop1Top2Gap' | 'distanceSpread'): number[] { return results.map((result) => result[field]).filter(finite); }
function finite(value: unknown): value is number { return typeof value === 'number' && Number.isFinite(value); }
function accuracy(results: readonly FigureRetrievalEvaluationCaseResult[], field: 'top1Correct' | 'top3Correct' | 'top5Correct' | 'presentInTopK'): number | undefined { return results.length ? results.filter((result) => result[field] === true).length / results.length : undefined; }
function countOutcome(results: readonly FigureRetrievalEvaluationCaseResult[], outcome: string): number { return results.filter((result) => result.decisionOutcome === outcome).length; }

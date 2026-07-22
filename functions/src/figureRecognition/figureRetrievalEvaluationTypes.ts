import type { FigureRetrievalCandidate } from './figureRetrievalTypes';
import type { RetrievalDecisionOutcome, RetrievalDecisionReason } from './retrievalDecisionTypes';

export type CatalogPresence = 'present' | 'absent';
export type FigureRetrievalEvaluationManifestPhoto = { file: string; expectedFigureId?: string; catalogPresence: CatalogPresence; notes?: string };
export type ResolvedFigureRetrievalEvaluationCase = Omit<FigureRetrievalEvaluationManifestPhoto, 'file'> & { id: string; filePath: string };
export type FigureRetrievalEvaluationManifest = { version: 1; dataset: string; photos: FigureRetrievalEvaluationManifestPhoto[] };

export type SafeEvaluationCandidate = Pick<FigureRetrievalCandidate, 'figureId' | 'seriesId' | 'brandId' | 'ipId' | 'isSecret' | 'distance' | 'rank'>;

export type FigureRetrievalEvaluationCaseResult = {
  id: string;
  catalogPresence: CatalogPresence;
  expectedFigureId?: string;
  expectedSeriesId?: string;
  status: 'completed' | 'isolation_rejected' | 'failed';
  isolationStatus?: string;
  refinementAccepted?: boolean;
  segmentationOutcome?: string;
  expectedRank?: number;
  top1Correct?: boolean;
  top3Correct?: boolean;
  top5Correct?: boolean;
  presentInTopK?: boolean;
  top1FigureId?: string;
  top1SeriesId?: string;
  top1Distance?: number;
  top2Distance?: number;
  top1Top2Gap?: number;
  relativeTop1Top2Gap?: number;
  distanceSpread?: number;
  topSeriesRatio?: number;
  topIpRatio?: number;
  topBrandRatio?: number;
  sameSeriesLeadingAmbiguity?: boolean;
  returnedCandidates?: SafeEvaluationCandidate[];
  decisionOutcome?: RetrievalDecisionOutcome;
  decisionReasons?: RetrievalDecisionReason[];
  policyVersion?: string;
  shadowDecisionOutcome?: RetrievalDecisionOutcome;
  candidateDecisionOutcome?: RetrievalDecisionOutcome;
  candidateDecisionReasons?: RetrievalDecisionReason[];
  candidatePolicyVersion?: string;
  calibrationProfile?: string;
  elapsedMs: number;
  errorCode?: string;
  errorComponent?: string;
};

export type DistributionSummary = { count: number; min?: number; max?: number; mean?: number; median?: number; p10?: number; p25?: number; p75?: number; p90?: number; p95?: number };
export type EvidenceDistributionGroup = { top1Distance: DistributionSummary; top1Top2Gap: DistributionSummary; relativeTop1Top2Gap: DistributionSummary; distanceSpread: DistributionSummary };
export type FigureRetrievalEvaluationMetrics = {
  totalCases: number; catalogPresentCases: number; catalogAbsentCases: number; completedCases: number; isolationRejectedCases: number; failedCases: number;
  top1Accuracy?: number; top3Accuracy?: number; top5Accuracy?: number; meanReciprocalRank?: number; expectedPresentInTopKRate?: number;
  highConfidenceCount: number; needsReviewCount: number; noConfidentMatchCount: number;
  catalogAbsentNeedsReviewCount: number; catalogAbsentNoConfidentMatchCount: number; catalogAbsentHighConfidenceCount: number;
  segmentedCount: number; segmentationFallbackCount: number; refinementAcceptedCount: number; isolationRejectedCount: number;
  averageElapsedMs: number; p50ElapsedMs: number; p95ElapsedMs: number;
  evidenceDistributions: { catalogPresent: EvidenceDistributionGroup; catalogAbsent: EvidenceDistributionGroup };
};

export type FigureRetrievalEvaluationSummary = FigureRetrievalEvaluationMetrics & {
  runnerVersion: string; generatedAt: string; manifestVersion: number; policyVersion: string; calibrationProfile: string; topK: number; skippedByFilterCount?: number;
};

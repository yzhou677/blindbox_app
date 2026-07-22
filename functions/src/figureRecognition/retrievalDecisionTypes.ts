import type { FigureRetrievalCandidate } from './figureRetrievalTypes';

export type RetrievalEvidence = {
  candidates: readonly FigureRetrievalCandidate[];
  requestedTopK: number;
  distanceSemantics: 'lower_is_better';
  calibrationProfile: string;
};

export type RetrievalEvidenceSummary = {
  candidateCount: number;
  requestedTopK: number;
  returnedCandidateRatio: number;
  top1Distance?: number;
  top2Distance?: number;
  top1Top2Gap?: number;
  relativeTop1Top2Gap?: number;
  distanceSpread?: number;
  leadingTieCount: number;
  nearDuplicateDistanceCount: number;
  distinctFigureCount: number;
  distinctSeriesCount: number;
  distinctIpCount: number;
  distinctBrandCount: number;
  topSeriesCandidateCount: number;
  topIpCandidateCount: number;
  topBrandCandidateCount: number;
  topSeriesRatio: number;
  topIpRatio: number;
  topBrandRatio: number;
  top1SeriesCandidateCount: number;
  top1IpCandidateCount: number;
  top1BrandCandidateCount: number;
  sameSeriesLeadingAmbiguity: boolean;
};

export type RetrievalDecisionOutcome = 'high_confidence' | 'needs_review' | 'no_confident_match';

export type RetrievalDecisionReason =
  | 'no_candidates'
  | 'invalid_evidence'
  | 'uncalibrated_profile'
  | 'shadow_evaluation_only'
  | 'ambiguous_leading_candidates'
  | 'duplicate_leading_distances'
  | 'same_series_figure_ambiguity'
  | 'sparse_candidate_set'
  | 'strong_top1_distance_signal'
  | 'clear_top1_margin_signal'
  | 'weak_top1_distance_signal'
  | 'candidate_policy_match'
  | 'candidate_policy_not_met';

type DecisionBase = {
  reasons: RetrievalDecisionReason[];
  evidence: RetrievalEvidenceSummary;
  policyVersion: string;
  calibrationProfile: string;
};

export type RetrievalDecision =
  | (DecisionBase & { outcome: 'high_confidence'; candidate: FigureRetrievalCandidate })
  | (DecisionBase & { outcome: 'needs_review'; suggestedCandidate?: FigureRetrievalCandidate; candidates: readonly FigureRetrievalCandidate[] })
  | (DecisionBase & { outcome: 'no_confident_match' });

export interface RetrievalDecisionResolver {
  decide(evidence: RetrievalEvidence): RetrievalDecision;
}

export type RetrievalEvaluationRecord = {
  expectedFigureId: string;
  expectedRank?: number;
  top1Correct: boolean;
  presentInTopK: boolean;
  decisionOutcome: RetrievalDecisionOutcome;
  policyVersion: string;
  calibrationProfile: string;
};

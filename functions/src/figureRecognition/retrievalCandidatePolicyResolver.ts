import { emptyRetrievalEvidenceSummary, summarizeRetrievalEvidence } from './retrievalEvidenceSummarizer';
import type { RetrievalCandidatePolicyConfig } from './retrievalCandidatePolicyConfig';
import type { RetrievalDecision, RetrievalDecisionReason, RetrievalDecisionResolver, RetrievalEvidence } from './retrievalDecisionTypes';

/**
 * Production retrieval decision policy (calibration-derived thresholds).
 *
 * Absolute Top-1 distance is a hard gate: weak nearest neighbors must not become
 * presentable candidates. Margin separates high_confidence from needs_review.
 */
export class CandidateRetrievalDecisionResolver implements RetrievalDecisionResolver {
  constructor(private readonly config: RetrievalCandidatePolicyConfig) {}

  decide(evidence: RetrievalEvidence): RetrievalDecision {
    const base = {
      policyVersion: this.config.policyVersion,
      calibrationProfile:
        typeof evidence?.calibrationProfile === 'string' ? evidence.calibrationProfile : '',
    };
    if (Array.isArray(evidence?.candidates) && evidence.candidates.length === 0) {
      return {
        outcome: 'no_confident_match',
        reasons: ['no_candidates'],
        evidence: emptyRetrievalEvidenceSummary(evidence.requestedTopK),
        ...base,
      };
    }
    let summary;
    try {
      summary = summarizeRetrievalEvidence(evidence, this.config.numericSummarization);
    } catch {
      return {
        outcome: 'no_confident_match',
        reasons: ['invalid_evidence'],
        evidence: emptyRetrievalEvidenceSummary(evidence?.requestedTopK),
        ...base,
      };
    }
    if (evidence.calibrationProfile !== this.config.calibrationProfile) {
      return {
        outcome: 'no_confident_match',
        reasons: ['uncalibrated_profile'],
        evidence: summary,
        ...base,
      };
    }

    const tolerance = this.config.numericSummarization.exactDistanceTolerance;
    const top1 = summary.top1Distance;
    const gap = summary.top1Top2Gap;

    if (top1 === undefined || top1 > this.config.maximumTop1Distance + tolerance) {
      return {
        outcome: 'no_confident_match',
        reasons: ['weak_top1_distance_signal'],
        evidence: summary,
        ...base,
      };
    }

    // Absolute gate passed — margin decides review vs accept.
    if (gap === undefined) {
      return {
        outcome: 'no_confident_match',
        reasons: ['candidate_policy_not_met'],
        evidence: summary,
        ...base,
      };
    }

    if (gap + tolerance < this.config.minimumTop1Top2Gap) {
      const reasons: RetrievalDecisionReason[] = ['candidate_policy_not_met'];
      if (summary.leadingTieCount > 1) {
        reasons.push('ambiguous_leading_candidates', 'duplicate_leading_distances');
      }
      if (summary.sameSeriesLeadingAmbiguity) reasons.push('same_series_figure_ambiguity');
      return {
        outcome: 'needs_review',
        suggestedCandidate: evidence.candidates[0],
        candidates: evidence.candidates,
        reasons,
        evidence: summary,
        ...base,
      };
    }

    return {
      outcome: 'high_confidence',
      candidate: evidence.candidates[0],
      reasons: ['candidate_policy_match'],
      evidence: summary,
      ...base,
    };
  }
}

import { emptyRetrievalEvidenceSummary, summarizeRetrievalEvidence } from './retrievalEvidenceSummarizer';
import type { RetrievalCandidatePolicyConfig } from './retrievalCandidatePolicyConfig';
import type { RetrievalDecision, RetrievalDecisionResolver, RetrievalEvidence } from './retrievalDecisionTypes';

/** Evaluates the calibration-derived candidate policy without controlling product behavior. */
export class CandidateRetrievalDecisionResolver implements RetrievalDecisionResolver {
  constructor(private readonly config: RetrievalCandidatePolicyConfig) {}

  decide(evidence: RetrievalEvidence): RetrievalDecision {
    const base = { policyVersion: this.config.policyVersion, calibrationProfile: typeof evidence?.calibrationProfile === 'string' ? evidence.calibrationProfile : '' };
    if (Array.isArray(evidence?.candidates) && evidence.candidates.length === 0) {
      return { outcome: 'no_confident_match', reasons: ['no_candidates'], evidence: emptyRetrievalEvidenceSummary(evidence.requestedTopK), ...base };
    }
    let summary;
    try { summary = summarizeRetrievalEvidence(evidence, this.config.numericSummarization); }
    catch { return { outcome: 'no_confident_match', reasons: ['invalid_evidence'], evidence: emptyRetrievalEvidenceSummary(evidence?.requestedTopK), ...base }; }
    if (evidence.calibrationProfile !== this.config.calibrationProfile) {
      return { outcome: 'no_confident_match', reasons: ['uncalibrated_profile'], evidence: summary, ...base };
    }
    const tolerance = this.config.numericSummarization.exactDistanceTolerance;
    const matches = summary.top1Distance !== undefined && summary.top1Top2Gap !== undefined
      && summary.top1Distance <= this.config.maximumTop1Distance + tolerance
      && summary.top1Top2Gap + tolerance >= this.config.minimumTop1Top2Gap;
    if (matches) return { outcome: 'high_confidence', candidate: evidence.candidates[0], reasons: ['candidate_policy_match'], evidence: summary, ...base };
    return { outcome: 'needs_review', suggestedCandidate: evidence.candidates[0], candidates: evidence.candidates, reasons: ['candidate_policy_not_met'], evidence: summary, ...base };
  }
}

import type { RetrievalDecisionConfig } from './retrievalDecisionConfig';
import { emptyRetrievalEvidenceSummary, summarizeRetrievalEvidence } from './retrievalEvidenceSummarizer';
import type { RetrievalDecision, RetrievalDecisionReason, RetrievalDecisionResolver, RetrievalEvidence } from './retrievalDecisionTypes';

/** Conservative shadow policy: it deliberately cannot emit high_confidence. */
export class ShadowRetrievalDecisionResolver implements RetrievalDecisionResolver {
  constructor(private readonly config: RetrievalDecisionConfig) {}

  decide(evidence: RetrievalEvidence): RetrievalDecision {
    const base = { policyVersion: this.config.policyVersion, calibrationProfile: typeof evidence?.calibrationProfile === 'string' ? evidence.calibrationProfile : '' };
    if (Array.isArray(evidence?.candidates) && evidence.candidates.length === 0) {
      return { outcome: 'no_confident_match', reasons: ['no_candidates'], evidence: emptyRetrievalEvidenceSummary(evidence.requestedTopK), ...base };
    }
    let summary;
    try { summary = summarizeRetrievalEvidence(evidence, this.config.numericSummarization); }
    catch { return { outcome: 'no_confident_match', reasons: ['invalid_evidence'], evidence: emptyRetrievalEvidenceSummary(evidence?.requestedTopK), ...base }; }
    if (!this.config.supportedCalibrationProfiles.includes(evidence.calibrationProfile)) {
      return { outcome: 'no_confident_match', reasons: ['uncalibrated_profile'], evidence: summary, ...base };
    }
    const reasons: RetrievalDecisionReason[] = ['shadow_evaluation_only'];
    if (summary.leadingTieCount > 1) reasons.push('ambiguous_leading_candidates', 'duplicate_leading_distances');
    if (summary.sameSeriesLeadingAmbiguity) reasons.push('same_series_figure_ambiguity');
    if (summary.candidateCount < summary.requestedTopK) reasons.push('sparse_candidate_set');
    return { outcome: 'needs_review', suggestedCandidate: evidence.candidates[0], candidates: evidence.candidates, reasons, evidence: summary, ...base };
  }
}

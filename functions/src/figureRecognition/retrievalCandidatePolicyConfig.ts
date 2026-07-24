/** Calibration-derived production thresholds for recognizeFigureV1 decisions. */
export const RETRIEVAL_CANDIDATE_POLICY_CONFIG = Object.freeze({
  policyVersion: 'retrieval-policy-candidate-v1',
  calibrationProfile: 'figure-image-retrieval-v1',
  maximumTop1Distance: 0.240,
  minimumTop1Top2Gap: 0.025,
  numericSummarization: Object.freeze({
    exactDistanceTolerance: Number.EPSILON * 16,
    nearDuplicateDistanceTolerance: 1e-9,
  }),
});

export type RetrievalCandidatePolicyConfig = typeof RETRIEVAL_CANDIDATE_POLICY_CONFIG;

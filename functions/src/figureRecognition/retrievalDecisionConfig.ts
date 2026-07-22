export const RETRIEVAL_DECISION_CONFIG = Object.freeze({
  policyVersion: 'retrieval-policy-shadow-v1',
  currentCalibrationProfile: 'figure-image-retrieval-v1',
  supportedCalibrationProfiles: Object.freeze(['figure-image-retrieval-v1']),
  numericSummarization: Object.freeze({
    exactDistanceTolerance: Number.EPSILON * 16,
    nearDuplicateDistanceTolerance: 1e-9,
  }),
});

export type RetrievalDecisionConfig = typeof RETRIEVAL_DECISION_CONFIG;

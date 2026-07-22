export type CalibrationInputSample = {
  id: string;
  catalogPresence: 'present' | 'absent';
  expectedFigureId?: string;
  top1FigureId?: string;
  top1SeriesId?: string;
  top1IpId?: string;
  top1Correct?: boolean;
  expectedRank?: number;
  expectedSeriesId?: string;
  expectedIpId?: string;
  top1Distance: number;
  top2Distance?: number;
  top1Top2Gap?: number;
  relativeTop1Top2Gap?: number;
  distanceSpread?: number;
  policyVersion: string;
  calibrationProfile: string;
};

export type RetrievalQualityGroup = { id: string; cases: number; top1Accuracy: number; top3Accuracy: number; top5Accuracy: number; meanReciprocalRank: number; averageRank?: number };
export type RetrievalHardFailure = { caseId: string; expectedFigureId: string; expectedSeriesId: string; expectedIpId: string; retrievedTop1FigureId?: string; retrievedTop1SeriesId?: string; retrievedTop1IpId?: string; correctRank?: number; top1Distance: number };
export type RetrievalQualityReport = {
  overall: { catalogPresent: { cases: number; top1Accuracy: number; top3Accuracy: number; top5Accuracy: number; meanReciprocalRank: number; averageTop1Distance?: number; medianTop1Distance?: number }; catalogAbsent: { cases: number; falseTop1Rate: number; averageTop1Distance?: number } };
  accuracyByIp: RetrievalQualityGroup[];
  accuracyBySeries: RetrievalQualityGroup[];
  hardFailures: RetrievalHardFailure[];
  summary: { overallTop1: number; overallTop3: number; overallTop5: number; worstPerformingIp?: string; worstPerformingSeries?: string; hardFailures: number };
};

export type CalibrationPolicyShape = 'distance_and_relative_gap' | 'distance_and_absolute_gap' | 'distance_and_either_margin' | 'strong_distance_or_distance_with_relative_gap';
export type CalibrationThresholds = { maximumTop1Distance: number; minimumAbsoluteGap?: number; minimumRelativeGap?: number; strongDistance?: number; minimumDistanceSpread?: number };
export type CalibrationPolicyCandidate = { id: string; shape: CalibrationPolicyShape; thresholds: CalibrationThresholds; complexity: number };
export type CalibrationOutcome = 'high_confidence' | 'needs_review' | 'no_confident_match';

export type CalibrationConfusion = {
  presentCorrectTop1: Record<CalibrationOutcome, number>;
  presentIncorrectTop1: Record<CalibrationOutcome, number>;
  catalogAbsent: Record<CalibrationOutcome, number>;
};

export type CalibrationPolicyMetrics = {
  evaluatedCaseCount: number; highConfidenceCount: number; needsReviewCount: number; noConfidentMatchCount: number;
  highConfidencePrecision?: number; highConfidenceCoverage: number; falseAcceptCount: number; falseAcceptRate: number;
  catalogPresentHighConfidenceCount: number; catalogPresentCorrectHighConfidenceCount: number; catalogPresentIncorrectHighConfidenceCount: number;
  catalogAbsentHighConfidenceCount: number; catalogAbsentNeedsReviewCount: number; catalogAbsentNoConfidentMatchCount: number;
  catalogPresentNeedsReviewCount: number; catalogPresentNoConfidentMatchCount: number;
  correctTop1AutoAcceptedCount: number; correctTop1ReviewedCount: number; incorrectTop1ReviewedCount: number;
  confusion: CalibrationConfusion;
};

export type CalibrationPolicyResult = CalibrationPolicyCandidate & { metrics: CalibrationPolicyMetrics };
export type CalibrationCaseDiagnostics = { falseAcceptCaseIds: string[]; correctHighConfidenceCaseIds: string[]; reviewedIncorrectTop1CaseIds: string[]; catalogAbsentHighConfidenceCaseIds: string[] };
export type ShortlistedCalibrationPolicy = CalibrationPolicyResult & { diagnostics: CalibrationCaseDiagnostics };
export type CalibrationInputSummary = { totalRows: number; evaluatedRows: number; excludedRows: number; excludedFailed: number; excludedIsolationRejected: number; excludedIncompleteEvidence: number; catalogPresentRows: number; catalogAbsentRows: number; sourcePolicyVersion: string; sourceCalibrationProfile: string };

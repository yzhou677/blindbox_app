import type { CalibrationCaseDiagnostics, CalibrationInputSample, CalibrationOutcome, CalibrationPolicyCandidate, CalibrationPolicyMetrics, CalibrationPolicyResult } from './retrievalCalibrationTypes';
import { RETRIEVAL_CALIBRATION_CONFIG } from './retrievalCalibrationConfig';

const f = (n: number | undefined) => n === undefined ? 'none' : String(n);
export function generateCalibrationPolicies(): CalibrationPolicyCandidate[] {
  const g = RETRIEVAL_CALIBRATION_CONFIG.grid; const out: CalibrationPolicyCandidate[] = [];
  for (const maximumTop1Distance of g.maximumTop1Distance) for (const minimumDistanceSpread of g.minimumDistanceSpread) {
    for (const minimumRelativeGap of g.minimumRelativeGap) out.push(policy('distance_and_relative_gap', { maximumTop1Distance, minimumRelativeGap, minimumDistanceSpread }, 2));
    for (const minimumAbsoluteGap of g.minimumAbsoluteGap) out.push(policy('distance_and_absolute_gap', { maximumTop1Distance, minimumAbsoluteGap, minimumDistanceSpread }, 2));
    for (const minimumRelativeGap of g.minimumRelativeGap) for (const minimumAbsoluteGap of g.minimumAbsoluteGap) out.push(policy('distance_and_either_margin', { maximumTop1Distance, minimumRelativeGap, minimumAbsoluteGap, minimumDistanceSpread }, 3));
    for (const strongDistance of g.strongDistance) if (strongDistance <= maximumTop1Distance) for (const minimumRelativeGap of g.minimumRelativeGap) out.push(policy('strong_distance_or_distance_with_relative_gap', { maximumTop1Distance, strongDistance, minimumRelativeGap, minimumDistanceSpread }, 3));
  }
  return out;
}
function policy(shape: CalibrationPolicyCandidate['shape'], thresholds: CalibrationPolicyCandidate['thresholds'], complexity: number): CalibrationPolicyCandidate {
  return { id: `${shape}:d=${f(thresholds.maximumTop1Distance)}:a=${f(thresholds.minimumAbsoluteGap)}:r=${f(thresholds.minimumRelativeGap)}:s=${f(thresholds.strongDistance)}:spread=${f(thresholds.minimumDistanceSpread)}`, shape, thresholds, complexity };
}
export function decideCalibrationOutcome(sample: CalibrationInputSample, candidate: CalibrationPolicyCandidate): CalibrationOutcome {
  const t = candidate.thresholds; const spread = t.minimumDistanceSpread === undefined || (sample.distanceSpread !== undefined && sample.distanceSpread >= t.minimumDistanceSpread);
  const abs = t.minimumAbsoluteGap !== undefined && sample.top1Top2Gap !== undefined && sample.top1Top2Gap >= t.minimumAbsoluteGap;
  const rel = t.minimumRelativeGap !== undefined && sample.relativeTop1Top2Gap !== undefined && sample.relativeTop1Top2Gap >= t.minimumRelativeGap;
  let strong = false;
  if (spread) switch (candidate.shape) {
    case 'distance_and_relative_gap': strong = sample.top1Distance <= t.maximumTop1Distance && rel; break;
    case 'distance_and_absolute_gap': strong = sample.top1Distance <= t.maximumTop1Distance && abs; break;
    case 'distance_and_either_margin': strong = sample.top1Distance <= t.maximumTop1Distance && (abs || rel); break;
    case 'strong_distance_or_distance_with_relative_gap': strong = sample.top1Distance <= (t.strongDistance ?? -Infinity) || (sample.top1Distance <= t.maximumTop1Distance && rel); break;
  }
  return strong ? 'high_confidence' : sample.top1Distance > t.maximumTop1Distance ? 'no_confident_match' : 'needs_review';
}
const outcomes = (): Record<CalibrationOutcome, number> => ({ high_confidence: 0, needs_review: 0, no_confident_match: 0 });
export function evaluateCalibrationPolicy(samples: CalibrationInputSample[], candidate: CalibrationPolicyCandidate): CalibrationPolicyResult {
  const confusion = { presentCorrectTop1: outcomes(), presentIncorrectTop1: outcomes(), catalogAbsent: outcomes() };
  let high=0, review=0, no=0, falseAccept=0, presentHigh=0, correctHigh=0, incorrectHigh=0, absentHigh=0, absentReview=0, absentNo=0, presentReview=0, presentNo=0, correctReview=0, incorrectReview=0;
  for (const s of samples) { const o=decideCalibrationOutcome(s,candidate); o==='high_confidence'?high++:o==='needs_review'?review++:no++;
    if(s.catalogPresence==='absent'){confusion.catalogAbsent[o]++; if(o==='high_confidence'){absentHigh++;falseAccept++;} else if(o==='needs_review')absentReview++;else absentNo++;}
    else {const bucket=s.top1Correct?confusion.presentCorrectTop1:confusion.presentIncorrectTop1;bucket[o]++; if(o==='high_confidence'){presentHigh++;if(s.top1Correct)correctHigh++;else{incorrectHigh++;falseAccept++;}}else if(o==='needs_review'){presentReview++;if(s.top1Correct)correctReview++;else incorrectReview++;}else presentNo++;}
  }
  const n=samples.length; const metrics: CalibrationPolicyMetrics={evaluatedCaseCount:n,highConfidenceCount:high,needsReviewCount:review,noConfidentMatchCount:no,highConfidencePrecision:high?correctHigh/high:undefined,highConfidenceCoverage:n?high/n:0,falseAcceptCount:falseAccept,falseAcceptRate:n?falseAccept/n:0,catalogPresentHighConfidenceCount:presentHigh,catalogPresentCorrectHighConfidenceCount:correctHigh,catalogPresentIncorrectHighConfidenceCount:incorrectHigh,catalogAbsentHighConfidenceCount:absentHigh,catalogAbsentNeedsReviewCount:absentReview,catalogAbsentNoConfidentMatchCount:absentNo,catalogPresentNeedsReviewCount:presentReview,catalogPresentNoConfidentMatchCount:presentNo,correctTop1AutoAcceptedCount:correctHigh,correctTop1ReviewedCount:correctReview,incorrectTop1ReviewedCount:incorrectReview,confusion};
  return {...candidate,metrics};
}
export function calibrationDiagnostics(samples: CalibrationInputSample[], candidate: CalibrationPolicyCandidate): CalibrationCaseDiagnostics { const d={falseAcceptCaseIds:[],correctHighConfidenceCaseIds:[],reviewedIncorrectTop1CaseIds:[],catalogAbsentHighConfidenceCaseIds:[]} as CalibrationCaseDiagnostics; for(const s of samples){const o=decideCalibrationOutcome(s,candidate);if(o==='high_confidence'&&s.catalogPresence==='present'&&s.top1Correct)d.correctHighConfidenceCaseIds.push(s.id);if(o==='high_confidence'&&(s.catalogPresence==='absent'||!s.top1Correct))d.falseAcceptCaseIds.push(s.id);if(o==='high_confidence'&&s.catalogPresence==='absent')d.catalogAbsentHighConfidenceCaseIds.push(s.id);if(o==='needs_review'&&s.catalogPresence==='present'&&!s.top1Correct)d.reviewedIncorrectTop1CaseIds.push(s.id);}return d; }

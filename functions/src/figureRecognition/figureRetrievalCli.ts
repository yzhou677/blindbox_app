import { DEFAULT_TOP_K, validateTopK } from './figureRetrievalService';
import type { FigureRetrievalCandidate } from './figureRetrievalTypes';
import type { PrimarySubjectPreviewArtifacts, PrimarySubjectResult } from './primarySubjectTypes';
import type { RetrievalDecision, RetrievalEvaluationRecord, RetrievalEvidenceSummary } from './retrievalDecisionTypes';

export type FigureRetrievalCliOptions = { file: string; topK: number; isolateSubject: boolean; previewDir?: string; overwritePreview: boolean; evaluationLabel?: string };

export function parseFigureRetrievalArgs(args: string[]): FigureRetrievalCliOptions {
  let file: string | undefined;
  let topK = DEFAULT_TOP_K;
  let isolateSubject = false;
  let previewDir: string | undefined;
  let overwritePreview = false;
  let evaluationLabel: string | undefined;
  for (let index = 0; index < args.length; index++) {
    const arg = args[index];
    if (arg === '--file') {
      const value = args[++index];
      if (!value || value.startsWith('--')) throw new Error('--file requires a local image path');
      file = value;
    } else if (arg === '--top-k') {
      const value = args[++index];
      topK = Number(value);
      validateTopK(topK);
    } else if (arg === '--isolate-subject') {
      isolateSubject = true;
    } else if (arg === '--preview-dir') {
      const value = args[++index];
      if (!value || value.startsWith('--')) throw new Error('--preview-dir requires a directory path');
      previewDir = value;
    } else if (arg === '--overwrite-preview') {
      overwritePreview = true;
    } else if (arg === '--evaluation-label') {
      const value = args[++index];
      if (!value || value.startsWith('--')) throw new Error('--evaluation-label requires an expected figure ID');
      evaluationLabel = value.trim();
    } else throw new Error(`Unknown option: ${arg}`);
  }
  if (!file) throw new Error('--file is required');
  if (previewDir && !isolateSubject) throw new Error('--preview-dir requires --isolate-subject');
  if (overwritePreview && !previewDir) throw new Error('--overwrite-preview requires --preview-dir');
  return { file, topK, isolateSubject, previewDir, overwritePreview, evaluationLabel };
}

export function formatPrimarySubjectResult(result: PrimarySubjectResult, previews: PrimarySubjectPreviewArtifacts = {}): string[] {
  const lines = [`Isolation status: ${result.status}`, `Reason: ${result.reason}`, `Locator model: ${result.diagnostics.locatorModel}`];
  const selected = result.status === 'usable' ? result.boundingBox
    : result.status === 'too_blurry' || result.status === 'subject_too_small' ? result.candidates.find((candidate) => candidate.selected) : undefined;
  if (result.status !== 'no_subject') {
    lines.push('', 'Candidate scores');
    for (const candidate of result.candidates) {
      lines.push('', `Candidate ${candidate.candidateNumber}`, '', 'centerScore:', String(candidate.centerScore),
        '', 'sharpnessScore:', String(candidate.sharpnessScore), '', 'areaScore:', String(candidate.areaScore),
        '', 'backgroundScore:', String(candidate.backgroundScore), '', 'totalScore:', String(candidate.totalScore),
        '', 'selected:', String(candidate.selected));
    }
  }
  if (selected && result.diagnostics.blurMetric !== undefined) {
    lines.push('', 'Blur diagnostics', '', 'sharpnessMetric:', String(result.diagnostics.blurMetric), '', 'sharpnessThreshold:', String(result.diagnostics.blurThreshold),
      '', 'sharpnessPassed:', String(result.diagnostics.blurMetric >= (result.diagnostics.blurThreshold ?? Number.POSITIVE_INFINITY)),
      '', 'sharpnessAlgorithm:', String(result.diagnostics.blurAlgorithm), '', 'detailMetric:', String(result.diagnostics.detailMetric),
      '', 'detailThreshold:', String(result.diagnostics.detailThreshold),
      '', 'detailPassed:', String((result.diagnostics.detailMetric ?? Number.NEGATIVE_INFINITY) >= (result.diagnostics.detailThreshold ?? Number.POSITIVE_INFINITY)),
      '', 'detailAlgorithm:', String(result.diagnostics.detailAlgorithm), '', 'combinedDecision:', result.diagnostics.combinedBlurPassed ? 'passed' : 'failed',
      '', 'failedSignals:', '', ...(result.diagnostics.failedBlurSignals ?? []).map((signal) => `- ${signal}`),
      '', 'cropWidth:', String(result.diagnostics.cropWidth),
      '', 'cropHeight:', String(result.diagnostics.cropHeight), '', 'subjectAreaRatio:', String(result.diagnostics.subjectAreaRatio),
      '', 'padding:', String(result.diagnostics.padding), '', 'processingResolution:', String(result.diagnostics.processingResolution),
      '', 'Crop diagnostics', '', 'sourceWidth:', String(result.diagnostics.sourceWidth), '', 'sourceHeight:', String(result.diagnostics.sourceHeight),
      '', 'cropWidth:', String(result.diagnostics.cropWidth), '', 'cropHeight:', String(result.diagnostics.cropHeight),
      '', 'normalizedBoundingBox:', JSON.stringify(selected.normalized), '', 'pixelBoundingBox:', JSON.stringify(selected.pixels));
  }
  if (result.status === 'too_blurry' || result.status === 'subject_too_small') {
    lines.push('', 'Quality Gate', '', 'status:', result.status, '', 'reason:', result.reason, '', 'failedChecks:', '');
    for (const check of result.diagnostics.failedChecks ?? []) lines.push(`- ${check}`);
  }
  if (result.diagnostics.refinement) {
    const refinement = result.diagnostics.refinement;
    lines.push('', 'Refinement diagnostics', '', 'attempted:', String(refinement.attempted), '', 'accepted:', String(refinement.accepted),
      '', 'reason:', refinement.reason, '', 'coarseNormalizedBox:', JSON.stringify(refinement.coarseNormalizedBox),
      '', 'refinedNormalizedBox:', JSON.stringify(refinement.refinedNormalizedBox), '', 'coarsePixelBox:', JSON.stringify(refinement.coarsePixelBox),
      '', 'refinedPixelBox:', JSON.stringify(refinement.refinedPixelBox), '', 'coarseArea:', String(refinement.coarseArea),
      '', 'refinedArea:', String(refinement.refinedArea), '', 'areaReductionRatio:', String(refinement.areaReductionRatio),
      '', 'finalPadding:', String(refinement.finalPadding));
  }
  if (previews.coarseOverlay) lines.push(`Coarse overlay preview: ${previews.coarseOverlay}`);
  if (previews.refinedOverlay) lines.push(`Refined overlay preview: ${previews.refinedOverlay}`);
  if (previews.coarseCrop) lines.push(`Coarse crop preview: ${previews.coarseCrop}`);
  if (result.status === 'usable' && result.diagnostics.segmentation) {
    const segmentation = result.diagnostics.segmentation;
    lines.push(`Segmentation outcome: ${segmentation.status === 'segmented' ? 'segmented' : 'refined_crop_fallback'}`);
    if (segmentation.modelVersion) lines.push(`Segmentation model: ${segmentation.modelVersion}`);
    if (segmentation.promptVersion) lines.push(`Segmentation prompt version: ${segmentation.promptVersion}`);
    if (segmentation.finalForegroundAreaRatio !== undefined) lines.push(`Foreground area ratio: ${segmentation.finalForegroundAreaRatio}`);
    if (segmentation.connectedComponentCount !== undefined) lines.push(`Connected components: ${segmentation.connectedComponentCount}`);
    if (segmentation.tightBoundingBox) lines.push(`Tight bounding box: ${JSON.stringify(segmentation.tightBoundingBox)}`);
    if (segmentation.usedFallback && segmentation.reason) lines.push(`Segmentation fallback reason: ${segmentation.reason}`);
  }
  if (previews.segmentationMask) lines.push(`Mask preview: ${previews.segmentationMask}`);
  if (previews.segmentedOverlay) lines.push(`Segmented overlay: ${previews.segmentedOverlay}`);
  if (previews.segmentedSubject) lines.push(`Segmented subject: ${previews.segmentedSubject}`);
  if (previews.embeddingInput) lines.push(`Final embedding input: ${previews.embeddingInput}`);
  if (previews.segmentationJson) lines.push(`Segmentation diagnostics: ${previews.segmentationJson}`);
  if (previews.crop) lines.push(`Crop preview: ${previews.crop}`);
  return lines;
}

export function formatFigureRetrievalCandidate(candidate: FigureRetrievalCandidate): string[] {
  return [
    `Rank ${candidate.rank}`,
    `figureId: ${candidate.figureId}`,
    `seriesId: ${candidate.seriesId}`,
    `brandId: ${candidate.brandId}`,
    `ipId: ${candidate.ipId}`,
    `isSecret: ${candidate.isSecret}`,
    `distance: ${candidate.distance}`,
  ];
}

export function formatRetrievalDecision(decision: RetrievalDecision, heading = 'Retrieval decision'): string[] {
  const lines = [
    '', heading, '', 'Outcome:', decision.outcome,
    '', 'Policy version:', decision.policyVersion,
    '', 'Calibration profile:', decision.calibrationProfile,
    '', 'Reasons:', ...decision.reasons.map((reason) => `- ${reason}`),
    '', 'Evidence',
  ];
  for (const [label, value] of evidenceEntries(decision.evidence)) lines.push('', `${label}:`, String(value));
  return lines;
}

export function buildRetrievalEvaluationRecord(expectedFigureId: string, candidates: readonly FigureRetrievalCandidate[], decision: RetrievalDecision): RetrievalEvaluationRecord {
  const expectedRank = candidates.find((candidate) => candidate.figureId === expectedFigureId)?.rank;
  return {
    expectedFigureId,
    expectedRank,
    top1Correct: candidates[0]?.figureId === expectedFigureId,
    presentInTopK: expectedRank !== undefined,
    decisionOutcome: decision.outcome,
    policyVersion: decision.policyVersion,
    calibrationProfile: decision.calibrationProfile,
  };
}

export function formatRetrievalEvaluationRecord(record: RetrievalEvaluationRecord): string[] {
  return ['', 'Evaluation record', '', 'expectedFigureId:', record.expectedFigureId, '', 'expectedRank:', String(record.expectedRank),
    '', 'top1Correct:', String(record.top1Correct), '', 'presentInTopK:', String(record.presentInTopK),
    '', 'decisionOutcome:', record.decisionOutcome, '', 'policyVersion:', record.policyVersion,
    '', 'calibrationProfile:', record.calibrationProfile];
}

function evidenceEntries(summary: RetrievalEvidenceSummary): Array<[string, number | boolean | undefined]> {
  return [
    ['candidateCount', summary.candidateCount], ['requestedTopK', summary.requestedTopK], ['returnedCandidateRatio', summary.returnedCandidateRatio],
    ['top1Distance', summary.top1Distance], ['top2Distance', summary.top2Distance], ['top1Top2Gap', summary.top1Top2Gap],
    ['relativeTop1Top2Gap', summary.relativeTop1Top2Gap], ['distanceSpread', summary.distanceSpread],
    ['leadingTieCount', summary.leadingTieCount], ['nearDuplicateDistanceCount', summary.nearDuplicateDistanceCount],
    ['distinctFigureCount', summary.distinctFigureCount], ['distinctSeriesCount', summary.distinctSeriesCount],
    ['distinctIpCount', summary.distinctIpCount], ['distinctBrandCount', summary.distinctBrandCount],
    ['topSeriesCandidateCount', summary.topSeriesCandidateCount], ['topIpCandidateCount', summary.topIpCandidateCount],
    ['topBrandCandidateCount', summary.topBrandCandidateCount], ['topSeriesRatio', summary.topSeriesRatio],
    ['topIpRatio', summary.topIpRatio], ['topBrandRatio', summary.topBrandRatio],
    ['top1SeriesCandidateCount', summary.top1SeriesCandidateCount], ['top1IpCandidateCount', summary.top1IpCandidateCount],
    ['top1BrandCandidateCount', summary.top1BrandCandidateCount], ['sameSeriesLeadingAmbiguity', summary.sameSeriesLeadingAmbiguity],
  ];
}

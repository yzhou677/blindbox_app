import type { FigureRetrievalCandidate } from './figureRetrievalTypes';
import type { RetrievalEvidence, RetrievalEvidenceSummary } from './retrievalDecisionTypes';

export type RetrievalNumericSummarizationConfig = {
  exactDistanceTolerance: number;
  nearDuplicateDistanceTolerance: number;
};

export class InvalidRetrievalEvidenceError extends Error {
  constructor() { super('Retrieval evidence is invalid'); this.name = 'InvalidRetrievalEvidenceError'; }
}

/** Pure numerical/taxonomy derivation. Contains no recognition policy. */
export function summarizeRetrievalEvidence(evidence: RetrievalEvidence, config: RetrievalNumericSummarizationConfig): RetrievalEvidenceSummary {
  validateEvidence(evidence, config);
  const candidates = evidence.candidates;
  const first = candidates[0]; const second = candidates[1]; const last = candidates[candidates.length - 1];
  const gap = first && second ? second.distance - first.distance : undefined;
  const exactTolerance = config.exactDistanceTolerance;
  let leadingTieCount = 0;
  if (first) for (const candidate of candidates) {
    if (Math.abs(candidate.distance - first.distance) <= exactTolerance) leadingTieCount++;
    else break;
  }
  let nearDuplicateDistanceCount = 0;
  for (let index = 1; index < candidates.length; index++) {
    if (Math.abs(candidates[index].distance - candidates[index - 1].distance) <= config.nearDuplicateDistanceTolerance) nearDuplicateDistanceCount++;
  }
  const series = taxonomySummary(candidates, 'seriesId');
  const ips = taxonomySummary(candidates, 'ipId');
  const brands = taxonomySummary(candidates, 'brandId');
  const candidateCount = candidates.length;
  return {
    candidateCount,
    requestedTopK: evidence.requestedTopK,
    returnedCandidateRatio: candidateCount / evidence.requestedTopK,
    top1Distance: first?.distance,
    top2Distance: second?.distance,
    top1Top2Gap: gap,
    // Zero is a valid distance, but cannot be a safe relative-gap denominator.
    relativeTop1Top2Gap: gap === undefined || first.distance === 0 ? undefined : gap / first.distance,
    distanceSpread: first && last ? last.distance - first.distance : undefined,
    leadingTieCount,
    nearDuplicateDistanceCount,
    distinctFigureCount: distinctStrings(candidates.map((candidate) => candidate.figureId)),
    distinctSeriesCount: series.distinct,
    distinctIpCount: ips.distinct,
    distinctBrandCount: brands.distinct,
    topSeriesCandidateCount: series.topCount,
    topIpCandidateCount: ips.topCount,
    topBrandCandidateCount: brands.topCount,
    topSeriesRatio: ratio(series.topCount, candidateCount),
    topIpRatio: ratio(ips.topCount, candidateCount),
    topBrandRatio: ratio(brands.topCount, candidateCount),
    top1SeriesCandidateCount: countMatching(candidates, first?.seriesId, 'seriesId'),
    top1IpCandidateCount: countMatching(candidates, first?.ipId, 'ipId'),
    top1BrandCandidateCount: countMatching(candidates, first?.brandId, 'brandId'),
    sameSeriesLeadingAmbiguity: Boolean(first && second && validString(first.seriesId) && first.seriesId === second.seriesId && first.figureId !== second.figureId),
  };
}

export function emptyRetrievalEvidenceSummary(requestedTopK: number): RetrievalEvidenceSummary {
  return {
    candidateCount: 0, requestedTopK: Number.isInteger(requestedTopK) && requestedTopK > 0 ? requestedTopK : 0, returnedCandidateRatio: 0,
    leadingTieCount: 0, nearDuplicateDistanceCount: 0, distinctFigureCount: 0, distinctSeriesCount: 0, distinctIpCount: 0,
    distinctBrandCount: 0, topSeriesCandidateCount: 0, topIpCandidateCount: 0, topBrandCandidateCount: 0,
    topSeriesRatio: 0, topIpRatio: 0, topBrandRatio: 0, top1SeriesCandidateCount: 0, top1IpCandidateCount: 0,
    top1BrandCandidateCount: 0, sameSeriesLeadingAmbiguity: false,
  };
}

function validateEvidence(evidence: RetrievalEvidence, config: RetrievalNumericSummarizationConfig): void {
  if (!evidence || !Array.isArray(evidence.candidates) || !Number.isInteger(evidence.requestedTopK) || evidence.requestedTopK < 1 || evidence.distanceSemantics !== 'lower_is_better') throw new InvalidRetrievalEvidenceError();
  if (![config.exactDistanceTolerance, config.nearDuplicateDistanceTolerance].every((value) => Number.isFinite(value) && value >= 0)) throw new InvalidRetrievalEvidenceError();
  let previous = Number.NEGATIVE_INFINITY;
  for (let index = 0; index < evidence.candidates.length; index++) {
    const candidate = evidence.candidates[index];
    if (!candidate || !validString(candidate.figureId) || typeof candidate.distance !== 'number' || !Number.isFinite(candidate.distance) || candidate.rank !== index + 1 || candidate.distance < previous) throw new InvalidRetrievalEvidenceError();
    previous = candidate.distance;
  }
}

function taxonomySummary(candidates: readonly FigureRetrievalCandidate[], field: 'seriesId' | 'ipId' | 'brandId'): { distinct: number; topCount: number } {
  const counts = new Map<string, number>();
  for (const candidate of candidates) if (validString(candidate[field])) counts.set(candidate[field], (counts.get(candidate[field]) ?? 0) + 1);
  return { distinct: counts.size, topCount: Math.max(0, ...counts.values()) };
}

function distinctStrings(values: unknown[]): number { return new Set(values.filter(validString)).size; }
function validString(value: unknown): value is string { return typeof value === 'string' && Boolean(value.trim()); }
function ratio(value: number, total: number): number { return total === 0 ? 0 : value / total; }
function countMatching(candidates: readonly FigureRetrievalCandidate[], value: unknown, field: 'seriesId' | 'ipId' | 'brandId'): number {
  return validString(value) ? candidates.filter((candidate) => candidate[field] === value).length : 0;
}

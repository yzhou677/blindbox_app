'use strict';

const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const { RETRIEVAL_DECISION_CONFIG } = require('../lib/figureRecognition/retrievalDecisionConfig');
const { summarizeRetrievalEvidence } = require('../lib/figureRecognition/retrievalEvidenceSummarizer');
const { ShadowRetrievalDecisionResolver } = require('../lib/figureRecognition/retrievalDecisionResolver');
const { RETRIEVAL_CANDIDATE_POLICY_CONFIG } = require('../lib/figureRecognition/retrievalCandidatePolicyConfig');
const { CandidateRetrievalDecisionResolver } = require('../lib/figureRecognition/retrievalCandidatePolicyResolver');
const { formatFigureRetrievalCandidate, formatRetrievalDecision, buildRetrievalEvaluationRecord, formatRetrievalEvaluationRecord } = require('../lib/figureRecognition/figureRetrievalCli');

const candidate = (rank, distance, overrides = {}) => ({
  figureId: `figure-${rank}`, seriesId: rank < 3 ? 'series-a' : `series-${rank}`,
  ipId: rank < 4 ? 'ip-a' : `ip-${rank}`, brandId: 'brand-a', isSecret: false,
  distance, rank, embeddingSpace: 'opaque-space', ...overrides,
});
const input = (candidates, overrides = {}) => ({ candidates, requestedTopK: 5, distanceSemantics: 'lower_is_better', calibrationProfile: RETRIEVAL_DECISION_CONFIG.currentCalibrationProfile, ...overrides });
const summarize = (candidates, overrides) => summarizeRetrievalEvidence(input(candidates, overrides), RETRIEVAL_DECISION_CONFIG.numericSummarization);
const resolver = new ShadowRetrievalDecisionResolver(RETRIEVAL_DECISION_CONFIG);
const candidateResolver = new CandidateRetrievalDecisionResolver(RETRIEVAL_CANDIDATE_POLICY_CONFIG);

describe('RetrievalEvidenceSummarizer', () => {
  it('returns a valid deterministic empty summary', () => {
    const first = summarize([]); const second = summarize([]);
    assert.deepEqual(first, second);
    assert.deepEqual({ count: first.candidateCount, ratio: first.returnedCandidateRatio, ties: first.leadingTieCount }, { count: 0, ratio: 0, ties: 0 });
    assert.equal(first.top1Distance, undefined);
  });

  it('summarizes one candidate without inventing a relative gap', () => {
    const summary = summarize([candidate(1, 0.2)]);
    assert.equal(summary.candidateCount, 1); assert.equal(summary.returnedCandidateRatio, 0.2);
    assert.equal(summary.top1Distance, 0.2); assert.equal(summary.top2Distance, undefined);
    assert.equal(summary.relativeTop1Top2Gap, undefined); assert.equal(summary.leadingTieCount, 1);
  });

  it('derives gaps, spread, taxonomy concentration, and leading Series ambiguity from ordered Top-5', () => {
    const candidates = [candidate(1, 0.1), candidate(2, 0.14), candidate(3, 0.2), candidate(4, 0.3), candidate(5, 0.5)];
    const before = JSON.stringify(candidates); const summary = summarize(candidates);
    assert.equal(summary.top1Top2Gap, 0.04000000000000001);
    assert.equal(summary.relativeTop1Top2Gap, 0.4000000000000001);
    assert.equal(summary.distanceSpread, 0.4);
    assert.deepEqual({ figures: summary.distinctFigureCount, series: summary.distinctSeriesCount, ips: summary.distinctIpCount, brands: summary.distinctBrandCount }, { figures: 5, series: 4, ips: 3, brands: 1 });
    assert.deepEqual({ topSeries: summary.topSeriesCandidateCount, top1Series: summary.top1SeriesCandidateCount, topIp: summary.topIpCandidateCount, topBrand: summary.topBrandCandidateCount }, { topSeries: 2, top1Series: 2, topIp: 3, topBrand: 5 });
    assert.equal(summary.topSeriesRatio, 0.4); assert.equal(summary.topIpRatio, 0.6); assert.equal(summary.topBrandRatio, 1);
    assert.equal(summary.sameSeriesLeadingAmbiguity, true); assert.equal(JSON.stringify(candidates), before);
  });

  it('handles zero distance, exact ties, and near-duplicate distances safely', () => {
    const summary = summarize([candidate(1, 0), candidate(2, 0), candidate(3, 0.0000000005), candidate(4, 0.2)]);
    assert.equal(summary.top1Top2Gap, 0); assert.equal(summary.relativeTop1Top2Gap, undefined);
    assert.equal(summary.leadingTieCount, 2); assert.equal(summary.nearDuplicateDistanceCount, 2);
  });

  it('ignores missing taxonomy fields without crashing or changing ordering', () => {
    const candidates = [candidate(1, 0.1, { seriesId: undefined, ipId: undefined }), candidate(2, 0.2, { brandId: undefined })];
    const summary = summarize(candidates);
    assert.deepEqual({ series: summary.distinctSeriesCount, ips: summary.distinctIpCount, brands: summary.distinctBrandCount }, { series: 1, ips: 1, brands: 1 });
    assert.equal(summary.top1SeriesCandidateCount, 0); assert.deepEqual(candidates.map((value) => value.rank), [1, 2]);
  });
});

describe('ShadowRetrievalDecisionResolver', () => {
  it('returns no confident match for empty candidates', () => {
    const decision = resolver.decide(input([]));
    assert.equal(decision.outcome, 'no_confident_match'); assert.deepEqual(decision.reasons, ['no_candidates']);
  });

  it('fails safely for non-finite, contradictory, and unsupported evidence', () => {
    for (const candidates of [[candidate(1, NaN)], [candidate(2, 0.1)], [candidate(1, 0.2), candidate(2, 0.1)]]) {
      const decision = resolver.decide(input(candidates));
      assert.equal(decision.outcome, 'no_confident_match'); assert.deepEqual(decision.reasons, ['invalid_evidence']);
    }
    const unknown = resolver.decide(input([candidate(1, 0.1)], { calibrationProfile: 'unknown-profile' }));
    assert.equal(unknown.outcome, 'no_confident_match'); assert.deepEqual(unknown.reasons, ['uncalibrated_profile']);
  });

  it('keeps valid shadow evidence in review and never emits high confidence', () => {
    const candidates = [candidate(1, 0.1), candidate(2, 0.1), candidate(3, 0.3)];
    const decision = resolver.decide(input(candidates));
    assert.equal(decision.outcome, 'needs_review'); assert.equal(decision.suggestedCandidate, candidates[0]); assert.equal(decision.candidates, candidates);
    assert.deepEqual(decision.reasons, ['shadow_evaluation_only', 'ambiguous_leading_candidates', 'duplicate_leading_distances', 'same_series_figure_ambiguity', 'sparse_candidate_set']);
    assert.equal(decision.policyVersion, 'retrieval-policy-shadow-v1'); assert.equal(decision.calibrationProfile, 'figure-image-retrieval-v1');
    assert.equal('probability' in decision, false); assert.equal('confidencePercentage' in decision, false);
  });
});

describe('CandidateRetrievalDecisionResolver', () => {
  it('centralizes the production candidate policy thresholds', () => {
    assert.deepEqual({ version: RETRIEVAL_CANDIDATE_POLICY_CONFIG.policyVersion, profile: RETRIEVAL_CANDIDATE_POLICY_CONFIG.calibrationProfile, distance: RETRIEVAL_CANDIDATE_POLICY_CONFIG.maximumTop1Distance, gap: RETRIEVAL_CANDIDATE_POLICY_CONFIG.minimumTop1Top2Gap }, { version: 'retrieval-policy-candidate-v1', profile: 'figure-image-retrieval-v1', distance: 0.240, gap: 0.025 });
  });
  it('accepts exact inclusive Top-1 distance 0.240 as high confidence when gap holds', () => {
    const decision = candidateResolver.decide(input([candidate(1, 0.240), candidate(2, 0.265)]));
    assert.equal(decision.outcome, 'high_confidence'); assert.deepEqual(decision.reasons, ['candidate_policy_match']); assert.equal(decision.candidate.rank, 1);
  });
  it('returns no_confident_match when Top-1 absolute distance exceeds 0.240', () => {
    for (const candidates of [[candidate(1, 0.2400001), candidate(2, 0.3)], [candidate(1, 0.241), candidate(2, 0.5)]]) {
      const decision = candidateResolver.decide(input(candidates));
      assert.equal(decision.outcome, 'no_confident_match');
      assert.deepEqual(decision.reasons, ['weak_top1_distance_signal']);
    }
  });
  it('presents candidates for a true-match distance formerly blocked between 0.225 and 0.240', () => {
    const decision = candidateResolver.decide(input([candidate(1, 0.232), candidate(2, 0.27)]));
    assert.equal(decision.outcome, 'high_confidence');
    assert.deepEqual(decision.reasons, ['candidate_policy_match']);
    assert.equal(decision.candidate.figureId, 'figure-1');
    assert.deepEqual(decision.candidate, candidate(1, 0.232));
  });
  it('returns needs_review when Top-1 passes the absolute gate but margin is below minimum', () => {
    const decision = candidateResolver.decide(input([
      candidate(1, 0.1, { seriesId: 'series-a' }),
      candidate(2, 0.124, { seriesId: 'series-b' }),
    ]));
    assert.equal(decision.outcome, 'needs_review');
    assert.deepEqual(decision.reasons, ['candidate_policy_not_met']);
    assert.equal(decision.candidates.length, 2);
    assert.deepEqual(decision.candidates.map((c) => c.rank), [1, 2]);
  });
  it('rejects bracelet-like weak Top-K as no_confident_match (not presentable)', () => {
    const braceletLike = [candidate(1, 0.41), candidate(2, 0.44), candidate(3, 0.47)];
    const decision = candidateResolver.decide(input(braceletLike));
    assert.equal(decision.outcome, 'no_confident_match');
    assert.deepEqual(decision.reasons, ['weak_top1_distance_signal']);
  });
  it('returns no_confident_match when Top-1 passes but Top-2 gap evidence is missing', () => {
    const decision = candidateResolver.decide(input([candidate(1, 0.1)]));
    assert.equal(decision.outcome, 'no_confident_match');
    assert.deepEqual(decision.reasons, ['candidate_policy_not_met']);
  });
  it('retains fail-closed empty, invalid, and unsupported-profile behavior', () => {
    assert.equal(candidateResolver.decide(input([])).outcome, 'no_confident_match');
    assert.deepEqual(candidateResolver.decide(input([])).reasons, ['no_candidates']);
    assert.equal(candidateResolver.decide(input([candidate(1, NaN)])).outcome, 'no_confident_match');
    assert.deepEqual(candidateResolver.decide(input([candidate(1, NaN)])).reasons, ['invalid_evidence']);
    assert.equal(candidateResolver.decide(input([candidate(1, 0.1), candidate(2, 0.2)], { calibrationProfile: 'other' })).outcome, 'no_confident_match');
    assert.deepEqual(candidateResolver.decide(input([candidate(1, 0.1), candidate(2, 0.2)], { calibrationProfile: 'other' })).reasons, ['uncalibrated_profile']);
  });
  it('does not mutate candidates or affect the current shadow resolver', () => {
    const candidates=[candidate(1,0.1),candidate(2,0.2)];const before=JSON.stringify(candidates);assert.equal(candidateResolver.decide(input(candidates)).outcome,'high_confidence');assert.equal(resolver.decide(input(candidates)).outcome,'needs_review');assert.equal(JSON.stringify(candidates),before);
  });
});

describe('Retrieval decision CLI formatting', () => {
  it('appends sanitized decision evidence without changing existing candidate formatting', () => {
    const candidates = [candidate(1, 0.123456789), candidate(2, 0.2)];
    assert.deepEqual(formatFigureRetrievalCandidate(candidates[0]), ['Rank 1', 'figureId: figure-1', 'seriesId: series-a', 'brandId: brand-a', 'ipId: ip-a', 'isSecret: false', 'distance: 0.123456789']);
    const output = formatRetrievalDecision(resolver.decide(input(candidates))).join('\n');
    assert.match(output, /Retrieval decision[\s\S]*Outcome:\nneeds_review/);
    assert.match(output, /Policy version:\nretrieval-policy-shadow-v1/);
    assert.match(output, /top1Distance:\n0\.123456789/);
    assert.doesNotMatch(output, /vector|image bytes|base64|credential|gemini|firestore/i);
  });

  it('formats empty retrieval and an optional in-memory evaluation record safely', () => {
    const empty = resolver.decide(input([]));
    assert.match(formatRetrievalDecision(empty).join('\n'), /no_confident_match[\s\S]*no_candidates/);
    const candidates = [candidate(1, 0.1), candidate(2, 0.2)];
    const decision = resolver.decide(input(candidates));
    const record = buildRetrievalEvaluationRecord('figure-2', candidates, decision);
    assert.deepEqual({ rank: record.expectedRank, top1: record.top1Correct, present: record.presentInTopK }, { rank: 2, top1: false, present: true });
    const output = formatRetrievalEvaluationRecord(record).join('\n');
    assert.match(output, /expectedFigureId:\nfigure-2/); assert.doesNotMatch(output, /path|bytes|vector|base64/i);
  });
});

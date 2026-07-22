import type { StoredImage } from './imageEmbeddingTypes';
import type { FigureRetrievalCandidate } from './figureRetrievalTypes';
import type { PrimarySubjectResult } from './primarySubjectTypes';
import type { RetrievalDecisionResolver } from './retrievalDecisionTypes';
import type { FigureRetrievalEvaluationCaseResult, ResolvedFigureRetrievalEvaluationCase, SafeEvaluationCandidate } from './figureRetrievalEvaluationTypes';

type EvaluationImageReader = { read(filePath: string): Promise<StoredImage> };
type EvaluationIsolation = { isolate(image: StoredImage): Promise<PrimarySubjectResult> };
type EvaluationRetrieval = { retrieveStoredImage(image: StoredImage, topK: number): Promise<FigureRetrievalCandidate[]> };
type EvaluationPreviewWriter = { write(root: string, caseId: string, source: StoredImage, result: PrimarySubjectResult, overwrite: boolean): Promise<unknown> };

export type FigureRetrievalEvaluationRunOptions = { topK: number; continueOnError: boolean; calibrationProfile: string; previewDir?: string; overwritePreview?: boolean; debugTopK?: number; onDebugCandidates?: (entry: ResolvedFigureRetrievalEvaluationCase, candidates: readonly FigureRetrievalCandidate[]) => void };
export type EvaluationProgress = { index: number; total: number; result: FigureRetrievalEvaluationCaseResult };

export class FigureRetrievalEvaluationRunner {
  constructor(
    private readonly images: EvaluationImageReader,
    private readonly isolation: EvaluationIsolation,
    private readonly retrieval: EvaluationRetrieval,
    private readonly decisions: RetrievalDecisionResolver,
    private readonly now: () => number = Date.now,
    private readonly candidateDecisions?: RetrievalDecisionResolver,
    private readonly previewWriter?: EvaluationPreviewWriter,
  ) {}

  async run(cases: readonly ResolvedFigureRetrievalEvaluationCase[], options: FigureRetrievalEvaluationRunOptions, onProgress?: (progress: EvaluationProgress, results: readonly FigureRetrievalEvaluationCaseResult[]) => Promise<void> | void): Promise<FigureRetrievalEvaluationCaseResult[]> {
    const results: FigureRetrievalEvaluationCaseResult[] = [];
    for (let index = 0; index < cases.length; index++) {
      const result = await this.evaluate(cases[index], options);
      results.push(result);
      await onProgress?.({ index: index + 1, total: cases.length, result }, results);
      if (result.status === 'failed' && !options.continueOnError) break;
    }
    return results;
  }

  private async evaluate(entry: ResolvedFigureRetrievalEvaluationCase, options: FigureRetrievalEvaluationRunOptions): Promise<FigureRetrievalEvaluationCaseResult> {
    const startedAt = this.now(); let component = 'local_image';
    const base = () => ({ id: entry.id, catalogPresence: entry.catalogPresence, expectedFigureId: entry.expectedFigureId, elapsedMs: Math.max(0, this.now() - startedAt) });
    try {
      const source = await this.images.read(entry.filePath);
      component = 'isolation';
      const isolated = await this.isolation.isolate(source);
      const pipeline = isolationFields(isolated);
      if (options.previewDir) {
        if (!this.previewWriter) throw new Error('Evaluation preview writer is not configured');
        component = 'preview';
        await this.previewWriter.write(options.previewDir, entry.id, source, isolated, options.overwritePreview ?? false);
      }
      if (isolated.status !== 'usable') return { ...base(), ...pipeline, status: 'isolation_rejected' };
      component = 'retrieval';
      const retrievedCandidates = await this.retrieval.retrieveStoredImage(isolated.embeddingInput, options.debugTopK ?? options.topK);
      options.onDebugCandidates?.(entry, retrievedCandidates);
      const candidates = options.debugTopK === undefined ? retrievedCandidates : retrievedCandidates.slice(0, options.topK);
      component = 'decision';
      const decision = this.decisions.decide({ candidates, requestedTopK: options.topK, distanceSemantics: 'lower_is_better', calibrationProfile: options.calibrationProfile });
      const candidateDecision = this.candidateDecisions?.decide({ candidates, requestedTopK: options.topK, distanceSemantics: 'lower_is_better', calibrationProfile: options.calibrationProfile });
      const expectedRank = entry.catalogPresence === 'present' ? candidates.find((candidate) => candidate.figureId === entry.expectedFigureId)?.rank : undefined;
      const correctness = entry.catalogPresence === 'present' ? {
        expectedRank, top1Correct: expectedRank === 1, top3Correct: expectedRank !== undefined && expectedRank <= 3,
        top5Correct: expectedRank !== undefined && expectedRank <= 5, presentInTopK: expectedRank !== undefined,
      } : {};
      return {
        ...base(), ...pipeline, ...correctness, status: 'completed',
        top1FigureId: candidates[0]?.figureId, top1SeriesId: candidates[0]?.seriesId,
        top1Distance: decision.evidence.top1Distance, top2Distance: decision.evidence.top2Distance,
        top1Top2Gap: decision.evidence.top1Top2Gap, relativeTop1Top2Gap: decision.evidence.relativeTop1Top2Gap,
        distanceSpread: decision.evidence.distanceSpread, topSeriesRatio: decision.evidence.topSeriesRatio,
        topIpRatio: decision.evidence.topIpRatio, topBrandRatio: decision.evidence.topBrandRatio,
        sameSeriesLeadingAmbiguity: decision.evidence.sameSeriesLeadingAmbiguity,
        returnedCandidates: candidates.map(safeCandidate), decisionOutcome: decision.outcome, decisionReasons: decision.reasons,
        policyVersion: decision.policyVersion, calibrationProfile: decision.calibrationProfile,
        shadowDecisionOutcome: decision.outcome,
        candidateDecisionOutcome: candidateDecision?.outcome,
        candidateDecisionReasons: candidateDecision?.reasons,
        candidatePolicyVersion: candidateDecision?.policyVersion,
      };
    } catch {
      return { ...base(), status: 'failed', errorCode: `${component}_failed`, errorComponent: component };
    }
  }
}

function isolationFields(result: PrimarySubjectResult): Pick<FigureRetrievalEvaluationCaseResult, 'isolationStatus' | 'refinementAccepted' | 'segmentationOutcome'> {
  return {
    isolationStatus: result.status,
    refinementAccepted: result.diagnostics.refinement?.accepted,
    segmentationOutcome: result.status === 'usable' && result.diagnostics.segmentation
      ? result.diagnostics.segmentation.status === 'segmented' ? 'segmented' : 'refined_crop_fallback'
      : undefined,
  };
}

function safeCandidate(candidate: FigureRetrievalCandidate): SafeEvaluationCandidate {
  return { figureId: candidate.figureId, seriesId: candidate.seriesId, brandId: candidate.brandId, ipId: candidate.ipId, isSecret: candidate.isSecret, distance: candidate.distance, rank: candidate.rank };
}

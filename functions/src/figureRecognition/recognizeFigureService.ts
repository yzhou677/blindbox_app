import type { StoredImage } from './imageEmbeddingTypes';
import { logger } from 'firebase-functions';
import { measureScanStage } from './scanTiming';
import type { PrimarySubjectBlurEvaluator } from './primarySubjectBlurEvaluator';
import type { PrimarySubjectCropper } from './primarySubjectCropper';
import type { FigureRetrievalService } from './figureRetrievalService';
import type { RetrievalDecisionResolver } from './retrievalDecisionTypes';
import { RECOGNIZE_FIGURE_ENDPOINT_CONFIG as config } from './recognizeFigureEndpointConfig';
import type { RecognitionCandidateHydrator } from './recognitionCandidateHydrator';
import {
  RecognitionQualityUnavailableError,
  type RecognitionCandidateV1,
  type RecognizeFigureRequest,
  type RecognizeFigureResponseV1,
} from './recognizeFigureEndpointTypes';
import { RETRIEVAL_CANDIDATE_POLICY_CONFIG } from './retrievalCandidatePolicyConfig';
import type { FigureRetrievalCandidate } from './figureRetrievalTypes';

export class RecognizeFigureService {
  constructor(
    private readonly cropper: PrimarySubjectCropper,
    private readonly blur: PrimarySubjectBlurEvaluator,
    private readonly retrieval: FigureRetrievalService,
    private readonly resolver: RetrievalDecisionResolver,
    private readonly hydrator: RecognitionCandidateHydrator,
  ) {}

  async recognize(request: RecognizeFigureRequest, inputImage: StoredImage): Promise<RecognizeFigureResponseV1> {
    const correlationId = request.requestId ?? 'recognition-unavailable';
    const requestedSeriesId = request.seriesId;
    const seriesScoped = Boolean(requestedSeriesId);
    const imageLevelTopK = seriesScoped ? config.seriesScopedRetrievalTopK : config.retrievalTopK;
    const totalStartedAt = Date.now();
    let selectedSubjectCrop = inputImage;
    if (request.version === 1) {
      const prepared = await measureScanStage('legacy_orientation_normalization', () => this.cropper.orient(inputImage));
      const s = request.selection;
      const normalized = { xmin: s.left * 1000, ymin: s.top * 1000, xmax: (s.left + s.width) * 1000, ymax: (s.top + s.height) * 1000 };
      const box = this.cropper.pixelBox(normalized, prepared.width, prepared.height, false);
      selectedSubjectCrop = (await measureScanStage('legacy_selected_subject_crop', () => this.cropper.cropPixelBox(prepared, box))).image;
    }
    let quality;
    const qualityStartedAt = Date.now();
    try { quality = await this.blur.evaluateImage(selectedSubjectCrop); } catch { throw new RecognitionQualityUnavailableError(); }
    this.timing(correlationId, 'selected_subject_blur_evaluation', qualityStartedAt);
    if (!quality.usable) {
      this.timing(correlationId, 'total_service', totalStartedAt);
      return { version: 1, status: 'too_blurry', blurEvaluatorVersion: quality.evaluatorVersion };
    }
    const retrieval = await this.retrieval.retrieveStoredImageWithDiagnostics(
      selectedSubjectCrop,
      imageLevelTopK,
      (stage, elapsedMs) => logger.debug('Figure scan timing', { component: 'backend_recognition', correlationId, stage, elapsedMs }),
      requestedSeriesId ? { seriesId: requestedSeriesId } : undefined,
    );
    const candidates = filterCandidatesToSeries(retrieval.candidates, requestedSeriesId, correlationId);
    logger.debug('Figure recognition retrieval diagnostics', {
      component: 'backend_recognition',
      correlationId,
      requestedSeriesId: requestedSeriesId ?? null,
      seriesScoped,
      imageLevelTopK,
      userEmbeddingMs: retrieval.diagnostics.userEmbeddingMs,
      vectorSearchMs: retrieval.diagnostics.vectorSearchMs,
      aggregationMs: retrieval.diagnostics.aggregationMs,
      totalMs: retrieval.diagnostics.totalMs,
      candidateImageCount: retrieval.diagnostics.candidateImageCount,
      candidateFigureCount: candidates.length,
      alternativeMatchCount: retrieval.diagnostics.alternativeMatchCount,
      winningImageRole: retrieval.diagnostics.winningImageRole,
      winningVariant: retrieval.diagnostics.winningVariant,
      vectorSearchCalls: retrieval.diagnostics.vectorSearchCalls,
      userEmbeddingCalls: retrieval.diagnostics.userEmbeddingCalls,
    });
    const decisionStartedAt = Date.now();
    const decision = this.resolver.decide({
      candidates,
      // Keep policy evidence keyed to the returned figure-candidate budget, not
      // the series over-fetch image-level K, so legacy thresholds stay stable.
      requestedTopK: config.retrievalTopK,
      distanceSemantics: 'lower_is_better',
      calibrationProfile: RETRIEVAL_CANDIDATE_POLICY_CONFIG.calibrationProfile,
    });
    this.timing(correlationId, 'decision_policy', decisionStartedAt);
    const subjectQuality = quality.quality === 'borderline' ? 'borderline' as const : 'good' as const;
    const base = { version: 1 as const, subjectQuality, blurEvaluatorVersion: quality.evaluatorVersion, policyVersion: decision.policyVersion };

    if (decision.outcome === 'no_confident_match') {
      this.logReturnedCount(correlationId, requestedSeriesId, seriesScoped, imageLevelTopK, retrieval, candidates, 0);
      this.timing(correlationId, 'total_service', totalStartedAt);
      return { ...base, status: 'no_confident_match' };
    }

    const presentable =
      decision.outcome === 'needs_review'
        ? decision.candidates
        : candidates;
    if (!presentable.length) {
      this.logReturnedCount(correlationId, requestedSeriesId, seriesScoped, imageLevelTopK, retrieval, candidates, 0);
      this.timing(correlationId, 'total_service', totalStartedAt);
      return { ...base, status: 'no_confident_match' };
    }

    const visible = presentable.slice(0, config.presentationCandidateLimit);
    const hydratedRaw = await measureScanStage('candidate_hydration', () => this.hydrator.hydrate(visible));
    const hydrated = filterHydratedToSeries(hydratedRaw, requestedSeriesId, correlationId);
    if (!hydrated.length) {
      this.logReturnedCount(correlationId, requestedSeriesId, seriesScoped, imageLevelTopK, retrieval, candidates, 0);
      this.timing(correlationId, 'total_service', totalStartedAt);
      return { ...base, status: 'no_confident_match' };
    }

    const serializationStartedAt = Date.now();
    const response: RecognizeFigureResponseV1 = {
      ...base,
      status: 'candidates',
      decision: decision.outcome,
      candidates: hydrated,
    };
    this.logReturnedCount(
      correlationId,
      requestedSeriesId,
      seriesScoped,
      imageLevelTopK,
      retrieval,
      candidates,
      hydrated.length,
    );
    this.timing(correlationId, 'response_serialization', serializationStartedAt);
    this.timing(correlationId, 'total_service', totalStartedAt);
    return response;
  }

  private logReturnedCount(
    correlationId: string,
    requestedSeriesId: string | undefined,
    seriesScoped: boolean,
    imageLevelTopK: number,
    retrieval: { diagnostics: { vectorSearchMs: number; candidateImageCount: number; alternativeMatchCount: number } },
    candidates: FigureRetrievalCandidate[],
    returnedFigureCount: number,
  ): void {
    logger.debug('Figure recognition result diagnostics', {
      component: 'backend_recognition',
      correlationId,
      requestedSeriesId: requestedSeriesId ?? null,
      seriesScoped,
      vectorSearchMs: retrieval.diagnostics.vectorSearchMs,
      candidateImageCount: retrieval.diagnostics.candidateImageCount,
      candidateFigureCount: candidates.length,
      returnedFigureCount,
      imageLevelTopK,
      alternativeMatchCount: retrieval.diagnostics.alternativeMatchCount,
    });
  }

  private timing(correlationId: string, stage: string, startedAt: number): void {
    logger.debug('Figure scan timing', { component: 'backend_recognition', correlationId, stage, elapsedMs: Date.now() - startedAt });
  }
}

function filterCandidatesToSeries(
  candidates: FigureRetrievalCandidate[],
  seriesId: string | undefined,
  correlationId: string,
): FigureRetrievalCandidate[] {
  if (!seriesId) return candidates;
  const kept: FigureRetrievalCandidate[] = [];
  for (const candidate of candidates) {
    if (candidate.seriesId === seriesId) {
      kept.push(candidate);
      continue;
    }
    logger.warn('Figure recognition series invariant violation', {
      component: 'backend_recognition',
      correlationId,
      requestedSeriesId: seriesId,
      figureId: candidate.figureId,
      candidateSeriesId: candidate.seriesId,
      stage: 'retrieval_candidates',
    });
  }
  return kept.map((candidate, index) => ({ ...candidate, rank: index + 1 }));
}

function filterHydratedToSeries(
  candidates: RecognitionCandidateV1[],
  seriesId: string | undefined,
  correlationId: string,
): RecognitionCandidateV1[] {
  if (!seriesId) return candidates;
  const kept: RecognitionCandidateV1[] = [];
  for (const candidate of candidates) {
    if (candidate.seriesId === seriesId) {
      kept.push(candidate);
      continue;
    }
    logger.warn('Figure recognition series invariant violation', {
      component: 'backend_recognition',
      correlationId,
      requestedSeriesId: seriesId,
      figureId: candidate.figureId,
      candidateSeriesId: candidate.seriesId,
      stage: 'hydration',
    });
  }
  return kept.map((candidate, index) => ({ ...candidate, rank: index + 1 }));
}

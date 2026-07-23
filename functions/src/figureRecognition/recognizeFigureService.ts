import type { StoredImage } from './imageEmbeddingTypes';
import { logger } from 'firebase-functions';
import { measureScanStage } from './scanTiming';
import type { PrimarySubjectBlurEvaluator } from './primarySubjectBlurEvaluator';
import type { PrimarySubjectCropper } from './primarySubjectCropper';
import type { FigureRetrievalService } from './figureRetrievalService';
import type { RetrievalDecisionResolver } from './retrievalDecisionTypes';
import { RECOGNIZE_FIGURE_ENDPOINT_CONFIG as config } from './recognizeFigureEndpointConfig';
import type { RecognitionCandidateHydrator } from './recognitionCandidateHydrator';
import { RecognitionQualityUnavailableError, type RecognizeFigureRequest, type RecognizeFigureResponseV1 } from './recognizeFigureEndpointTypes';
import { RETRIEVAL_DECISION_CONFIG } from './retrievalDecisionConfig';

export class RecognizeFigureService {
  constructor(private readonly cropper: PrimarySubjectCropper, private readonly blur: PrimarySubjectBlurEvaluator, private readonly retrieval: FigureRetrievalService, private readonly resolver: RetrievalDecisionResolver, private readonly hydrator: RecognitionCandidateHydrator) {}
  async recognize(request: RecognizeFigureRequest, inputImage: StoredImage): Promise<RecognizeFigureResponseV1> {
    const correlationId = request.requestId ?? 'recognition-unavailable';
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
    const candidates = await this.retrieval.retrieveStoredImage(
      selectedSubjectCrop,
      config.retrievalTopK,
      (stage, elapsedMs) => logger.debug('Figure scan timing', { component: 'backend_recognition', correlationId, stage, elapsedMs }),
    );
    const decisionStartedAt = Date.now();
    const decision = this.resolver.decide({ candidates, requestedTopK: config.retrievalTopK, distanceSemantics: 'lower_is_better', calibrationProfile: RETRIEVAL_DECISION_CONFIG.currentCalibrationProfile });
    this.timing(correlationId, 'decision_policy', decisionStartedAt);
    const subjectQuality = quality.quality === 'borderline' ? 'borderline' as const : 'good' as const;
    const base = { version: 1 as const, subjectQuality, blurEvaluatorVersion: quality.evaluatorVersion, policyVersion: decision.policyVersion };
    if (decision.outcome !== 'needs_review' || !decision.candidates.length) {
      this.timing(correlationId, 'total_service', totalStartedAt);
      return { ...base, status: 'no_confident_match' };
    }
    const visible = decision.candidates.slice(0, config.presentationCandidateLimit);
    const hydrated = await measureScanStage('candidate_hydration', () => this.hydrator.hydrate(visible));
    const serializationStartedAt = Date.now();
    const response: RecognizeFigureResponseV1 = { ...base, status: 'candidates', decision: 'needs_review', candidates: hydrated };
    this.timing(correlationId, 'response_serialization', serializationStartedAt);
    this.timing(correlationId, 'total_service', totalStartedAt);
    return response;
  }

  private timing(correlationId: string, stage: string, startedAt: number): void {
    logger.debug('Figure scan timing', { component: 'backend_recognition', correlationId, stage, elapsedMs: Date.now() - startedAt });
  }
}

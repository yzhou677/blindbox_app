import type { StoredImage } from './imageEmbeddingTypes';
import type { PrimarySubjectBlurEvaluator } from './primarySubjectBlurEvaluator';
import type { PrimarySubjectCropper } from './primarySubjectCropper';
import type { FigureRetrievalService } from './figureRetrievalService';
import type { RetrievalDecisionResolver } from './retrievalDecisionTypes';
import { RECOGNIZE_FIGURE_ENDPOINT_CONFIG as config } from './recognizeFigureEndpointConfig';
import type { RecognitionCandidateHydrator } from './recognitionCandidateHydrator';
import { RecognitionQualityUnavailableError, type RecognizeFigureRequestV1, type RecognizeFigureResponseV1 } from './recognizeFigureEndpointTypes';
import { RETRIEVAL_DECISION_CONFIG } from './retrievalDecisionConfig';

export class RecognizeFigureService {
  constructor(private readonly cropper: PrimarySubjectCropper, private readonly blur: PrimarySubjectBlurEvaluator, private readonly retrieval: FigureRetrievalService, private readonly resolver: RetrievalDecisionResolver, private readonly hydrator: RecognitionCandidateHydrator) {}
  async recognize(request: RecognizeFigureRequestV1, original: StoredImage): Promise<RecognizeFigureResponseV1> {
    const prepared = await this.cropper.orient(original);
    const s = request.selection;
    const normalized = { xmin: s.left * 1000, ymin: s.top * 1000, xmax: (s.left + s.width) * 1000, ymax: (s.top + s.height) * 1000 };
    const box = this.cropper.pixelBox(normalized, prepared.width, prepared.height, false);
    const crop = await this.cropper.cropPixelBox(prepared, box);
    let quality;
    try { quality = await this.blur.evaluateImage(crop.image); } catch { throw new RecognitionQualityUnavailableError(); }
    if (quality.quality === 'too_blurry') return { version: 1, status: 'too_blurry', blurEvaluatorVersion: quality.evaluatorVersion };
    if (quality.quality === 'borderline' && request.continueBorderline !== true) return { version: 1, status: 'borderline', subjectQuality: 'borderline', blurEvaluatorVersion: quality.evaluatorVersion };
    const candidates = await this.retrieval.retrieveStoredImage(crop.image, config.retrievalTopK);
    const decision = this.resolver.decide({ candidates, requestedTopK: config.retrievalTopK, distanceSemantics: 'lower_is_better', calibrationProfile: RETRIEVAL_DECISION_CONFIG.currentCalibrationProfile });
    const base = { version: 1 as const, subjectQuality: quality.quality, blurEvaluatorVersion: quality.evaluatorVersion, policyVersion: decision.policyVersion };
    if (decision.outcome !== 'needs_review' || !decision.candidates.length) return { ...base, status: 'no_confident_match' };
    const visible = decision.candidates.slice(0, config.presentationCandidateLimit);
    return { ...base, status: 'candidates', decision: 'needs_review', candidates: await this.hydrator.hydrate(visible) };
  }
}

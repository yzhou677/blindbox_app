import type { StoredImage } from './imageEmbeddingTypes';
import { logger } from 'firebase-functions';
import { measureScanStage, measureScanStageSync } from './scanTiming';
import { PrimarySubjectCandidateSelector } from './primarySubjectCandidateSelector';
import { PrimarySubjectCropper } from './primarySubjectCropper';
import { InvalidLocatorOutputError, validateLocatorResponse } from './primarySubjectOutputValidator';
import type { PrimarySubjectLocator } from './primarySubjectTypes';
import { SUBJECT_LOCATOR_ENDPOINT_CONFIG as endpointConfig } from './subjectLocatorEndpointConfig';
import { SubjectLocatorTimeoutError, type SubjectLocatorResponseV1 } from './subjectLocatorEndpointTypes';

export class PrimarySubjectSuggestionService {
  constructor(
    private readonly locator: PrimarySubjectLocator,
    private readonly cropper: PrimarySubjectCropper,
    private readonly selector: PrimarySubjectCandidateSelector,
    private readonly timeoutMs = endpointConfig.locatorTimeoutMs,
  ) {}

  async suggest(original: StoredImage, correlationId = 'locator-unavailable'): Promise<SubjectLocatorResponseV1> {
    const totalStartedAt = Date.now();
    const preprocessingStartedAt = Date.now();
    const prepared = await measureScanStage('orientation_normalization', () => this.cropper.orient(original));
    logger.debug('Figure scan timing', { component: 'backend_locator', correlationId, stage: 'locator_preprocessing', elapsedMs: Date.now() - preprocessingStartedAt });
    const oriented: StoredImage = { bytes: prepared.bytes, mimeType: original.mimeType };
    let response;
    try {
      const inferenceStartedAt = Date.now();
      response = validateLocatorResponse(await withTimeout(this.locator.locate(oriented), this.timeoutMs));
      logger.debug('Figure scan timing', { component: 'backend_locator', correlationId, stage: 'locator_inference', elapsedMs: Date.now() - inferenceStartedAt });
    } catch (error) {
      if (error instanceof InvalidLocatorOutputError) return this.noSuggestion(prepared.width, prepared.height);
      throw error;
    }
    if (response.candidates.length === 0) {
      logger.debug('Figure scan timing', { component: 'backend_locator', correlationId, stage: 'total_service', elapsedMs: Date.now() - totalStartedAt });
      return this.noSuggestion(prepared.width, prepared.height);
    }
    let selected;
    const postprocessingStartedAt = Date.now();
    try { selected = (await measureScanStage('locator_candidate_scoring', () => this.selector.select(prepared, response.candidates))).selected.candidate.box; }
    catch { return this.noSuggestion(prepared.width, prepared.height); }
    const [left, top, right, bottom] = measureScanStageSync('bounding_box_normalization', () => [
      clamp01(selected.xmin / 1000),
      clamp01(selected.ymin / 1000),
      clamp01(selected.xmax / 1000),
      clamp01(selected.ymax / 1000),
    ]);
    if (![left, top, right, bottom].every(Number.isFinite) || right <= left || bottom <= top) return this.noSuggestion(prepared.width, prepared.height);
    const result: SubjectLocatorResponseV1 = {
      ...this.base(prepared.width, prepared.height), status: 'suggestion',
      rect: { left, top, width: right - left, height: bottom - top },
      coordinateSpace: 'normalized_oriented_image',
    };
    logger.debug('Figure scan timing', { component: 'backend_locator', correlationId, stage: 'postprocessing', elapsedMs: Date.now() - postprocessingStartedAt });
    logger.debug('Figure scan timing', { component: 'backend_locator', correlationId, stage: 'total_service', elapsedMs: Date.now() - totalStartedAt });
    return result;
  }

  private base(orientedWidth: number, orientedHeight: number) {
    return { version: 1 as const, orientedWidth, orientedHeight, locatorVersion: endpointConfig.locatorVersion, selectorVersion: endpointConfig.selectorVersion };
  }
  private noSuggestion(width: number, height: number): SubjectLocatorResponseV1 { return { ...this.base(width, height), status: 'no_suggestion' }; }
}

function clamp01(value: number): number { return Math.max(0, Math.min(1, value)); }
function withTimeout<T>(promise: Promise<T>, timeoutMs: number): Promise<T> {
  return new Promise<T>((resolve, reject) => {
    const timer = setTimeout(() => reject(new SubjectLocatorTimeoutError()), timeoutMs);
    promise.then((value) => { clearTimeout(timer); resolve(value); }, (error) => { clearTimeout(timer); reject(error); });
  });
}

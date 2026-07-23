import { logger } from 'firebase-functions';
import { HttpsError, type CallableRequest } from 'firebase-functions/v2/https';
import { GooglePrimarySubjectLocator } from './figureRecognition/googlePrimarySubjectLocator';
import { PrimarySubjectCandidateSelector } from './figureRecognition/primarySubjectCandidateSelector';
import { PRIMARY_SUBJECT_CONFIG } from './figureRecognition/primarySubjectConfig';
import { PrimarySubjectCropper } from './figureRecognition/primarySubjectCropper';
import { PrimarySubjectSuggestionService } from './figureRecognition/primarySubjectSuggestionService';
import { SubjectLocatorRequestError, SubjectLocatorTimeoutError, type SubjectLocatorResponseV1 } from './figureRecognition/subjectLocatorEndpointTypes';
import { validateSubjectLocatorRequest } from './figureRecognition/subjectLocatorRequestValidator';
import { measureScanStage, withScanTimingContext } from './figureRecognition/scanTiming';

export type SubjectLocatorSuggestionHandler = (data: unknown) => Promise<SubjectLocatorResponseV1>;

export function createSubjectLocatorSuggestionHandler(service: PrimarySubjectSuggestionService): SubjectLocatorSuggestionHandler {
  return async (data) => {
    const startedAt = Date.now();
    let correlationId = safeCorrelationId(data, 'locator-unavailable');
    return withScanTimingContext({ component: 'backend_locator', correlationId }, async () => { try {
      const verificationStartedAt = Date.now();
      const { request, image } = await measureScanStage('request_validation_total', () => validateSubjectLocatorRequest(data));
      correlationId = request.requestId ?? correlationId;
      logger.debug('Figure scan timing', { component: 'backend_locator', correlationId, stage: 'request_verification_and_image_decode', elapsedMs: Date.now() - verificationStartedAt });
      const result = await service.suggest(image, correlationId);
      logger.info('Subject locator request completed', { success: true, correlationId, status: result.status, elapsedMs: Date.now() - startedAt });
      return result;
    } catch (error) {
      logger.warn('Subject locator request failed', { success: false, correlationId, reason: safeReason(error), elapsedMs: Date.now() - startedAt });
      if (error instanceof SubjectLocatorRequestError) {
        const code = error.reason === 'payload_too_large' ? 'resource-exhausted' : 'invalid-argument';
        throw new HttpsError(code, 'Subject locator request was rejected', { reason: error.reason });
      }
      if (error instanceof SubjectLocatorTimeoutError) throw new HttpsError('deadline-exceeded', 'Subject locator timed out', { reason: 'locator_timeout' });
      throw new HttpsError('unavailable', 'Subject locator is unavailable', { reason: 'locator_unavailable' });
    } });
  };
}

function safeCorrelationId(data: unknown, fallback: string): string {
  if (typeof data !== 'object' || data === null) return fallback;
  const value = (data as { requestId?: unknown }).requestId;
  return typeof value === 'string' && /^[A-Za-z0-9._:-]{1,64}$/.test(value) ? value : fallback;
}

export function createProductionSubjectLocatorHandler(): (request: CallableRequest<unknown>) => Promise<SubjectLocatorResponseV1> {
  let handler: SubjectLocatorSuggestionHandler | undefined;
  return (request) => {
    if (!handler) {
      const initializationStartedAt = process.hrtime.bigint();
      const projectId = process.env.GCLOUD_PROJECT ?? process.env.GOOGLE_CLOUD_PROJECT ?? '';
      const cropper = new PrimarySubjectCropper(PRIMARY_SUBJECT_CONFIG);
      const locator = new GooglePrimarySubjectLocator(projectId, PRIMARY_SUBJECT_CONFIG);
      const selector = new PrimarySubjectCandidateSelector(cropper, PRIMARY_SUBJECT_CONFIG);
      handler = createSubjectLocatorSuggestionHandler(new PrimarySubjectSuggestionService(locator, cropper, selector));
      logger.debug('Figure scan service initialized', { component: 'backend_locator', initializationMs: Number(process.hrtime.bigint() - initializationStartedAt) / 1_000_000 });
    } else {
      logger.debug('Figure scan service reused', { component: 'backend_locator' });
    }
    return handler(request.data);
  };
}

function safeReason(error: unknown): string {
  if (error instanceof SubjectLocatorRequestError || error instanceof SubjectLocatorTimeoutError) return error.message;
  return 'locator_unavailable';
}

import { logger } from 'firebase-functions';
import { HttpsError, type CallableRequest } from 'firebase-functions/v2/https';
import { GooglePrimarySubjectLocator } from './figureRecognition/googlePrimarySubjectLocator';
import { PrimarySubjectCandidateSelector } from './figureRecognition/primarySubjectCandidateSelector';
import { PRIMARY_SUBJECT_CONFIG } from './figureRecognition/primarySubjectConfig';
import { PrimarySubjectCropper } from './figureRecognition/primarySubjectCropper';
import { PrimarySubjectSuggestionService } from './figureRecognition/primarySubjectSuggestionService';
import { SubjectLocatorRequestError, SubjectLocatorTimeoutError, type SubjectLocatorResponseV1 } from './figureRecognition/subjectLocatorEndpointTypes';
import { validateSubjectLocatorRequest } from './figureRecognition/subjectLocatorRequestValidator';

export type SubjectLocatorSuggestionHandler = (data: unknown) => Promise<SubjectLocatorResponseV1>;

export function createSubjectLocatorSuggestionHandler(service: PrimarySubjectSuggestionService): SubjectLocatorSuggestionHandler {
  return async (data) => {
    const startedAt = Date.now();
    try {
      const { image } = await validateSubjectLocatorRequest(data);
      const result = await service.suggest(image);
      logger.info('Subject locator request completed', { success: true, status: result.status, elapsedMs: Date.now() - startedAt });
      return result;
    } catch (error) {
      logger.warn('Subject locator request failed', { success: false, reason: safeReason(error), elapsedMs: Date.now() - startedAt });
      if (error instanceof SubjectLocatorRequestError) {
        const code = error.reason === 'payload_too_large' ? 'resource-exhausted' : 'invalid-argument';
        throw new HttpsError(code, 'Subject locator request was rejected', { reason: error.reason });
      }
      if (error instanceof SubjectLocatorTimeoutError) throw new HttpsError('deadline-exceeded', 'Subject locator timed out', { reason: 'locator_timeout' });
      throw new HttpsError('unavailable', 'Subject locator is unavailable', { reason: 'locator_unavailable' });
    }
  };
}

export function createProductionSubjectLocatorHandler(): (request: CallableRequest<unknown>) => Promise<SubjectLocatorResponseV1> {
  let handler: SubjectLocatorSuggestionHandler | undefined;
  return (request) => {
    if (!handler) {
      const projectId = process.env.GCLOUD_PROJECT ?? process.env.GOOGLE_CLOUD_PROJECT ?? '';
      const cropper = new PrimarySubjectCropper(PRIMARY_SUBJECT_CONFIG);
      const locator = new GooglePrimarySubjectLocator(projectId, PRIMARY_SUBJECT_CONFIG);
      const selector = new PrimarySubjectCandidateSelector(cropper, PRIMARY_SUBJECT_CONFIG);
      handler = createSubjectLocatorSuggestionHandler(new PrimarySubjectSuggestionService(locator, cropper, selector));
    }
    return handler(request.data);
  };
}

function safeReason(error: unknown): string {
  if (error instanceof SubjectLocatorRequestError || error instanceof SubjectLocatorTimeoutError) return error.message;
  return 'locator_unavailable';
}

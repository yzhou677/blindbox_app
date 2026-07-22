import { Firestore } from '@google-cloud/firestore';
import { logger } from 'firebase-functions';
import { HttpsError, type CallableRequest } from 'firebase-functions/v2/https';
import { BLUR_QUALITY_CONFIG } from './figureRecognition/blurQualityConfig';
import { IMAGE_EMBEDDING_CONFIG } from './figureRecognition/imageEmbeddingConfig';
import { ImageEmbeddingProvider } from './figureRecognition/imageEmbeddingProvider';
import { GoogleImageEmbeddingClient } from './figureRecognition/googleImageEmbeddingClient';
import { PrimarySubjectBlurEvaluator } from './figureRecognition/primarySubjectBlurEvaluator';
import { PRIMARY_SUBJECT_CONFIG } from './figureRecognition/primarySubjectConfig';
import { PrimarySubjectCropper } from './figureRecognition/primarySubjectCropper';
import { FigureRetrievalService } from './figureRecognition/figureRetrievalService';
import { FirestoreFigureVectorSearch } from './figureRecognition/figureVectorSearch';
import { FirestoreRecognitionCandidateHydrator } from './figureRecognition/recognitionCandidateHydrator';
import { RecognitionHydrationError, RecognitionQualityUnavailableError, RecognizeFigureRequestError, type RecognizeFigureResponseV1 } from './figureRecognition/recognizeFigureEndpointTypes';
import { validateRecognizeFigureRequest } from './figureRecognition/recognizeFigureRequestValidator';
import { RecognizeFigureService } from './figureRecognition/recognizeFigureService';
import { RETRIEVAL_DECISION_CONFIG } from './figureRecognition/retrievalDecisionConfig';
import { ShadowRetrievalDecisionResolver } from './figureRecognition/retrievalDecisionResolver';

export type RecognizeFigureHandler = (data: unknown) => Promise<RecognizeFigureResponseV1>;

export function createRecognizeFigureHandler(service: RecognizeFigureService): RecognizeFigureHandler {
  return async (data) => {
    const startedAt = Date.now();
    try {
      const { request, image } = await validateRecognizeFigureRequest(data);
      const response = await service.recognize(request, image);
      logger.info('Figure recognition request completed', { success: true, status: response.status, elapsedMs: Date.now() - startedAt });
      return response;
    } catch (error) {
      const reason = safeReason(error);
      logger.warn('Figure recognition request failed', { success: false, reason, elapsedMs: Date.now() - startedAt });
      if (error instanceof RecognizeFigureRequestError) throw new HttpsError(error.reason === 'payload_too_large' ? 'resource-exhausted' : 'invalid-argument', 'Figure recognition request was rejected', { reason });
      if (error instanceof RecognitionQualityUnavailableError) throw new HttpsError('unavailable', 'Photo quality could not be checked', { reason: 'quality_unavailable' });
      if (error instanceof RecognitionHydrationError) throw new HttpsError('unavailable', 'Figure recognition is unavailable', { reason: 'candidate_hydration_failed' });
      throw new HttpsError('unavailable', 'Figure recognition is unavailable', { reason: 'recognition_unavailable' });
    }
  };
}

export function createProductionRecognizeFigureHandler(): (request: CallableRequest<unknown>) => Promise<RecognizeFigureResponseV1> {
  let handler: RecognizeFigureHandler | undefined;
  return (request) => {
    if (!handler) {
      const projectId = process.env.GCLOUD_PROJECT ?? process.env.GOOGLE_CLOUD_PROJECT ?? '';
      if (!projectId) throw new HttpsError('failed-precondition', 'Figure recognition is not configured', { reason: 'recognition_unavailable' });
      const firestore = new Firestore({ projectId });
      const cropper = new PrimarySubjectCropper(PRIMARY_SUBJECT_CONFIG);
      const embeddings = new ImageEmbeddingProvider(
        IMAGE_EMBEDDING_CONFIG,
        { read: async () => { throw new Error('Storage reads are not supported by recognizeFigureV1'); } },
        new GoogleImageEmbeddingClient(projectId, IMAGE_EMBEDDING_CONFIG),
        { log: (entry) => logger.info('Recognition embedding completed', entry) },
      );
      const retrieval = new FigureRetrievalService({ read: async () => { throw new Error('File reads are not supported by recognizeFigureV1'); } }, embeddings, new FirestoreFigureVectorSearch(firestore));
      const service = new RecognizeFigureService(cropper, new PrimarySubjectBlurEvaluator(cropper, BLUR_QUALITY_CONFIG), retrieval, new ShadowRetrievalDecisionResolver(RETRIEVAL_DECISION_CONFIG), new FirestoreRecognitionCandidateHydrator(firestore));
      handler = createRecognizeFigureHandler(service);
    }
    return handler(request.data);
  };
}

function safeReason(error: unknown): string {
  if (error instanceof RecognizeFigureRequestError) return error.reason;
  if (error instanceof RecognitionQualityUnavailableError || error instanceof RecognitionHydrationError) return error.message;
  return 'recognition_unavailable';
}

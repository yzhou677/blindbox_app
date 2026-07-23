/**
 * Thin Cloud Functions entry — bounded-context isolation for cold starts.
 *
 * Design choice (single Firebase codebase, multiple lazy entry graphs):
 * - One `firebase.json` codebase (`market`) and one `package.json` `main`.
 * - Each exported function dynamically imports only its own context on first use.
 * - Recognition does not load Market, Recommendations, or Subject Locator.
 *
 * Multi-codebase splits remain possible later; this keeps deploy ergonomics.
 */
import { initializeApp } from 'firebase-admin/app';
import { onCall, onRequest, type CallableRequest } from 'firebase-functions/v2/https';
import { RECOGNIZE_FIGURE_ENDPOINT_CONFIG } from './figureRecognition/recognizeFigureEndpointConfig';
import { SUBJECT_LOCATOR_ENDPOINT_CONFIG } from './figureRecognition/subjectLocatorEndpointConfig';
import { lazySingleton } from './shared/lazySingleton';

initializeApp();

const getRecognizeFigureHandler = lazySingleton(async () => {
  const { createProductionRecognizeFigureHandler } = await import(
    './recognizeFigureCallable'
  );
  return createProductionRecognizeFigureHandler();
});

const getSubjectLocatorHandler = lazySingleton(async () => {
  const { createProductionSubjectLocatorHandler } = await import(
    './subjectLocatorCallable'
  );
  return createProductionSubjectLocatorHandler();
});

const getMarketBrowse = lazySingleton(() => import('./marketBrowseRouter'));
const getMarketItem = lazySingleton(() => import('./marketItemRouter'));
const getRecommendations = lazySingleton(() => import('./recommendationsRouter'));

export const subjectLocatorV1 = onCall(
  {
    region: SUBJECT_LOCATOR_ENDPOINT_CONFIG.region,
    timeoutSeconds: SUBJECT_LOCATOR_ENDPOINT_CONFIG.functionTimeoutSeconds,
    memory: '1GiB',
    concurrency: 1,
    maxInstances: 10,
    enforceAppCheck: true,
  },
  async (request: CallableRequest<unknown>) => {
    const handler = await getSubjectLocatorHandler();
    return handler(request);
  },
);

export const recognizeFigureV1 = onCall(
  {
    region: RECOGNIZE_FIGURE_ENDPOINT_CONFIG.region,
    timeoutSeconds: RECOGNIZE_FIGURE_ENDPOINT_CONFIG.functionTimeoutSeconds,
    memory: '2GiB',
    concurrency: 1,
    maxInstances: 10,
    enforceAppCheck: true,
  },
  async (request: CallableRequest<unknown>) => {
    const handler = await getRecognizeFigureHandler();
    return handler(request);
  },
);

/**
 * Thin market provider gateway.
 *
 * Routes:
 *   GET /v1/browse?limit=&cursor=&q=
 *   GET /v1/item?itemId=
 *
 * Deploy URL (example):
 *   https://<region>-<project>.cloudfunctions.net/market/v1/browse
 *
 * Flutter `MARKET_GATEWAY_BASE_URL` should be the function root (…/market).
 */
export const market = onRequest(
  {
    cors: true,
    region: process.env.FUNCTION_REGION ?? 'us-central1',
    timeoutSeconds: 30,
    memory: '256MiB',
    maxInstances: 10,
  },
  async (req, res) => {
    if (req.method === 'OPTIONS') {
      res.status(204).send('');
      return;
    }

    const path = normalizePath(req.path);
    if (path === '/v1/browse') {
      const { handleMarketBrowseRequest } = await getMarketBrowse();
      await handleMarketBrowseRequest(req, res);
      return;
    }
    if (path === '/v1/item') {
      const { handleMarketItemRequest } = await getMarketItem();
      await handleMarketItemRequest(req, res);
      return;
    }

    res.status(404).json({
      error: 'not_found',
      message: 'Supported: GET /v1/browse, GET /v1/item',
    });
  },
);

/**
 * Anonymous recommendation profile + for-you gateway.
 *
 * Routes:
 *   POST /v1/profile
 *   GET  /v1/for-you?installId=
 */
export const recommendations = onRequest(
  {
    cors: true,
    region: process.env.FUNCTION_REGION ?? 'us-central1',
    timeoutSeconds: 30,
    memory: '256MiB',
    maxInstances: 10,
  },
  async (req, res) => {
    if (req.method === 'OPTIONS') {
      res.status(204).send('');
      return;
    }

    const path = normalizePath(req.path);
    if (path === '/v1/profile') {
      const { handleRecommendationProfileRequest } = await getRecommendations();
      await handleRecommendationProfileRequest(req, res);
      return;
    }
    if (path === '/v1/for-you') {
      const { handleRecommendationForYouRequest } = await getRecommendations();
      await handleRecommendationForYouRequest(req, res);
      return;
    }

    res.status(404).json({
      error: 'not_found',
      message: 'Supported: POST /v1/profile, GET /v1/for-you',
    });
  },
);

function normalizePath(path: string | undefined): string {
  const trimmed = (path ?? '/').trim();
  if (!trimmed || trimmed === '/') return '/';
  const noTrailing = trimmed.replace(/\/+$/, '');
  return noTrailing.startsWith('/') ? noTrailing : `/${noTrailing}`;
}

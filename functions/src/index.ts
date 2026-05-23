import { initializeApp } from 'firebase-admin/app';
import { onRequest } from 'firebase-functions/v2/https';
import { handleMarketBrowseRequest } from './marketBrowseRouter';

initializeApp();

/**
 * Thin market provider gateway.
 *
 * Routes:
 *   GET /v1/browse?limit=&cursor=&q=
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
      await handleMarketBrowseRequest(req, res);
      return;
    }

    res.status(404).json({
      error: 'not_found',
      message: 'Supported: GET /v1/browse',
    });
  },
);

function normalizePath(path: string | undefined): string {
  const trimmed = (path ?? '/').trim();
  if (!trimmed || trimmed === '/') return '/';
  const noTrailing = trimmed.replace(/\/+$/, '');
  return noTrailing.startsWith('/') ? noTrailing : `/${noTrailing}`;
}

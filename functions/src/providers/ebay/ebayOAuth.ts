import { readCache, writeCache } from '../../shared/cache/memoryCache';
import { fetchJson, HttpError } from '../../shared/http/fetchJson';

const TOKEN_CACHE_KEY = 'ebay:oauth:access_token';
const DEFAULT_SCOPE = 'https://api.ebay.com/oauth/api_scope';

export type EbayApiEnv = 'sandbox' | 'production';

export function resolveEbayApiEnv(): EbayApiEnv {
  const raw = (process.env.EBAY_ENV ?? 'sandbox').trim().toLowerCase();
  return raw === 'production' ? 'production' : 'sandbox';
}

export function resolveEbayApiBase(): string {
  return resolveEbayApiEnv() === 'production'
    ? 'https://api.ebay.com'
    : 'https://api.sandbox.ebay.com';
}

export function ebayCredentialsConfigured(): boolean {
  return Boolean(
    process.env.EBAY_CLIENT_ID?.trim() && process.env.EBAY_CLIENT_SECRET?.trim(),
  );
}

/** Client-credentials OAuth — cached until shortly before expiry. */
export async function getEbayAccessToken(): Promise<string> {
  const cached = readCache<string>(TOKEN_CACHE_KEY);
  if (cached) return cached;

  const clientId = process.env.EBAY_CLIENT_ID?.trim();
  const clientSecret = process.env.EBAY_CLIENT_SECRET?.trim();
  if (!clientId || !clientSecret) {
    throw new HttpError('eBay credentials not configured', 503);
  }

  const credentials = Buffer.from(`${clientId}:${clientSecret}`, 'utf8').toString(
    'base64',
  );
  const body = new URLSearchParams({
    grant_type: 'client_credentials',
    scope: process.env.EBAY_OAUTH_SCOPE?.trim() || DEFAULT_SCOPE,
  });

  const payload = (await fetchJson(`${resolveEbayApiBase()}/identity/v1/oauth2/token`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
      Authorization: `Basic ${credentials}`,
    },
    body: body.toString(),
    timeoutMs: 12_000,
  })) as {
    access_token?: string;
    expires_in?: number;
    token_type?: string;
  };

  const token = payload.access_token?.trim();
  if (!token) {
    throw new HttpError('eBay OAuth response missing access_token', 502);
  }

  const expiresIn = payload.expires_in ?? 7200;
  const ttlMs = Math.max(60_000, (expiresIn - 120) * 1000);
  writeCache(TOKEN_CACHE_KEY, token, ttlMs);
  return token;
}

export function clearEbayTokenCache(): void {
  writeCache(TOKEN_CACHE_KEY, '', 0);
}

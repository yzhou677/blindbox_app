import type { Request, Response } from 'express';
import { readCache, writeCache } from '../../shared/cache/memoryCache';
import { fetchJson, HttpError } from '../../shared/http/fetchJson';
import { withRetries } from '../../shared/http/retry';
import {
  buildBrowseMeta,
  gatewayDebugLog,
} from '../gateway/gatewayDiagnostics';
import type { GatewayItemDetailDto, ProviderRawItem } from '../gateway/gatewayTypes';
import { parseEbayLegacyItemId } from '../gateway/normalizeBrowseItems';
import { normalizeItemDetail } from '../gateway/normalizeItemDetail';
import { ebayCredentialsConfigured, getEbayAccessToken, resolveEbayApiBase } from './ebayOAuth';

const CACHE_TTL_MS = 120_000;

type EbayMode = 'fixture' | 'live';

function resolveMode(): EbayMode {
  const raw = (process.env.MARKET_GATEWAY_MODE ?? 'fixture').trim().toLowerCase();
  if (raw !== 'live') return 'fixture';
  return ebayCredentialsConfigured() ? 'live' : 'fixture';
}

/** Public item detail handler for eBay provider (`GET /v1/item`). */
export async function handleEbayItemRequest(
  req: Request,
  res: Response,
): Promise<void> {
  if (req.method !== 'GET') {
    res.status(405).json({ error: 'method_not_allowed' });
    return;
  }

  const itemId = String(req.query.itemId ?? '').trim();
  if (!itemId) {
    res.status(400).json({
      error: 'bad_request',
      message: 'Query param itemId is required',
    });
    return;
  }

  try {
    const cacheKey = `ebay:item:${itemId}`;
    const cached = readCache<GatewayItemDetailDto>(cacheKey);
    if (cached) {
      res.status(200).json({ item: cached, meta: buildItemMeta(resolveMode()) });
      return;
    }

    const item = await fetchEbayItemDetail(itemId);
    if (!item) {
      res.status(404).json({
        error: 'not_found',
        message: 'Item detail unavailable',
      });
      return;
    }

    writeCache(cacheKey, item, CACHE_TTL_MS);
    res.status(200).json({ item, meta: buildItemMeta(resolveMode()) });
  } catch (e) {
    const status = e instanceof HttpError ? (e.statusCode ?? 502) : 502;
    const message = e instanceof Error ? e.message : 'Item detail failed';
    gatewayDebugLog('ebay_item_handler_error', { itemId, message });
    res.status(status).json({
      error: 'gateway_unavailable',
      message,
      meta: buildItemMeta(resolveMode(), message),
    });
  }
}

async function fetchEbayItemDetail(itemId: string): Promise<GatewayItemDetailDto | null> {
  const mode = resolveMode();
  if (mode === 'fixture') {
    return null;
  }

  try {
    const raw = await withRetries(() => fetchEbayItemRaw(itemId));
    return normalizeItemDetail(raw);
  } catch (e) {
    const legacyId = parseEbayLegacyItemId(itemId);
    if (!legacyId || legacyId === itemId) throw e;
    gatewayDebugLog('ebay_item_retry_legacy', { itemId, legacyId });
    const raw = await withRetries(() => fetchEbayItemByLegacyId(legacyId));
    return normalizeItemDetail(raw);
  }
}

async function fetchEbayItemRaw(itemId: string): Promise<ProviderRawItem> {
  return fetchEbayItemFromPath(itemId);
}

async function fetchEbayItemByLegacyId(legacyItemId: string): Promise<ProviderRawItem> {
  const token = await getEbayAccessToken();
  const marketplace =
    process.env.EBAY_MARKETPLACE_ID?.trim() || 'EBAY_US';
  const params = new URLSearchParams({
    legacy_item_id: legacyItemId,
    fieldgroups: 'PRODUCT,ADDITIONAL_SELLER_DETAILS',
  });

  return (await fetchJson(
    `${resolveEbayApiBase()}/buy/browse/v1/item/get_item_by_legacy_id?${params.toString()}`,
    {
      headers: {
        Authorization: `Bearer ${token}`,
        'X-EBAY-C-MARKETPLACE-ID': marketplace,
        Accept: 'application/json',
      },
      timeoutMs: 12_000,
    },
  )) as ProviderRawItem;
}

async function fetchEbayItemFromPath(itemId: string): Promise<ProviderRawItem> {
  const token = await getEbayAccessToken();
  const marketplace =
    process.env.EBAY_MARKETPLACE_ID?.trim() || 'EBAY_US';
  const encoded = encodeURIComponent(itemId);
  // Valid fieldgroups: COMPACT (alone), PRODUCT, ADDITIONAL_SELLER_DETAILS, CHARITY_DETAILS.
  // SHIPPING is not valid and causes HTTP 400 from eBay Browse API.
  const params = new URLSearchParams({
    fieldgroups: 'PRODUCT,ADDITIONAL_SELLER_DETAILS',
  });

  return (await fetchJson(
    `${resolveEbayApiBase()}/buy/browse/v1/item/${encoded}?${params.toString()}`,
    {
      headers: {
        Authorization: `Bearer ${token}`,
        'X-EBAY-C-MARKETPLACE-ID': marketplace,
        Accept: 'application/json',
      },
      timeoutMs: 12_000,
    },
  )) as ProviderRawItem;
}

function buildItemMeta(mode: EbayMode, message?: string) {
  return buildBrowseMeta(
    { provider: 'ebay', mode, query: '', limit: 1 },
    message ? { message, acquisitionStrategy: 'ebay-item' } : { acquisitionStrategy: 'ebay-item' },
  );
}

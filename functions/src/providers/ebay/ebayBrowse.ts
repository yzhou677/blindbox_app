import type { Request, Response } from 'express';
import { readCache, writeCache } from '../../shared/cache/memoryCache';
import { fetchJson, HttpError } from '../../shared/http/fetchJson';
import { withRetries } from '../../shared/http/retry';
import {
  buildBrowseMeta,
  classifyUpstreamError,
  emptyDiagnostics,
  gatewayDebugLog,
  shouldUseFixtureFallback,
} from '../gateway/gatewayDiagnostics';
import { normalizeBrowseItems } from '../gateway/normalizeBrowseItems';
import {
  decodeCursor,
  encodeCursor,
  parseBrowseQuery,
} from '../gateway/parseBrowseQuery';
import type {
  BrowseDiagnostics,
  BrowseQuery,
  BrowseResponseDto,
  ProviderRawItem,
} from '../gateway/gatewayTypes';
import { ebayCredentialsConfigured, getEbayAccessToken, resolveEbayApiBase } from './ebayOAuth';
import { ebayFixtureItems } from './ebayFixture';
const CACHE_TTL_MS = 90_000;

type EbayMode = 'fixture' | 'live';

function resolveMode(): EbayMode {
  const raw = (process.env.MARKET_GATEWAY_MODE ?? 'fixture').trim().toLowerCase();
  if (raw !== 'live') return 'fixture';
  return ebayCredentialsConfigured() ? 'live' : 'fixture';
}

/** Public browse handler for eBay provider (`GET /v1/browse`). */
export async function handleEbayBrowseRequest(
  req: Request,
  res: Response,
): Promise<void> {
  if (req.method !== 'GET') {
    res.status(405).json({ error: 'method_not_allowed' });
    return;
  }

  try {
    const query = parseBrowseQuery(req);
    const cacheKey = `ebay:browse:${query.q}:${query.limit}:${query.cursor ?? ''}`;
    const cached = readCache<BrowseResponseDto>(cacheKey);
    if (cached) {
      res.status(200).json(cached);
      return;
    }

    const payload = await browseEbay(query);
    writeCache(cacheKey, payload, CACHE_TTL_MS);
    res.status(200).json(payload);
  } catch (e) {
    const status = e instanceof HttpError ? (e.statusCode ?? 502) : 502;
    const diagnostics: BrowseDiagnostics = {
      ...classifyUpstreamError(e),
      parseFailed: true,
      message: e instanceof Error ? e.message : 'Browse failed',
    };
    gatewayDebugLog('ebay_browse_handler_error', diagnostics);
    res.status(status).json({
      error: 'gateway_unavailable',
      message: diagnostics.message,
      items: [],
      hasMore: false,
      meta: buildBrowseMeta(
        { provider: 'ebay', mode: resolveMode(), query: '', limit: 0 },
        diagnostics,
      ),
    });
  }
}

export async function browseEbay(query: BrowseQuery): Promise<BrowseResponseDto> {
  const mode = resolveMode();
  if (mode === 'fixture') {
    return fixtureBrowse(query);
  }
  return liveBrowse(query);
}

async function liveBrowse(query: BrowseQuery): Promise<BrowseResponseDto> {
  const decoded = decodeCursor(query.cursor);
  const q = query.q || decoded.q;
  const limit = query.limit;
  const offset = query.cursor ? decoded.offset : 0;

  const diagnostics: BrowseDiagnostics = {
    ...emptyDiagnostics(),
    acquisitionStrategy: 'ebay-browse',
  };
  let rawItems: ProviderRawItem[] = [];
  let fetchFailed = false;

  try {
    rawItems = await withRetries(() =>
      fetchEbaySearchPage({ query: q, limit, offset }),
    );
  } catch (e) {
    fetchFailed = true;
    Object.assign(diagnostics, classifyUpstreamError(e));
    diagnostics.message =
      e instanceof Error ? e.message : 'eBay upstream unavailable';
    gatewayDebugLog('ebay_live_fetch_failed', { query: q, ...diagnostics });
  }

  if (!fetchFailed && rawItems.length === 0) {
    diagnostics.parseEmpty = true;
    diagnostics.message = 'eBay returned no listing rows';
  }

  diagnostics.rawRowCount = rawItems.length;
  let normalized = normalizeBrowseItems(rawItems);
  diagnostics.normalizedCount = normalized.items.length;
  const rowsDropped =
    normalized.stats.malformedDropped + normalized.stats.duplicateDropped;
  if (rowsDropped > 0) diagnostics.rowsDropped = rowsDropped;

  if (
    shouldUseFixtureFallback({
      fetchFailed,
      rawRowCount: rawItems.length,
      normalizedCount: normalized.items.length,
    })
  ) {
    diagnostics.usedFixtureFallback = true;
    return buildFixtureFallbackResponse({
      q,
      limit,
      offset,
      diagnostics,
    });
  }

  let hasMore = rawItems.length >= limit;
  let nextCursor = hasMore
    ? encodeCursor({ q, limit, offset: offset + limit })
    : undefined;

  if (hasMore && normalized.items.length === 0) {
    diagnostics.paginationInconsistent = true;
    hasMore = false;
    nextCursor = undefined;
  }

  gatewayDebugLog('ebay_live_success', {
    query: q,
    rawRowCount: rawItems.length,
    normalizedCount: normalized.items.length,
  });

  return {
    items: normalized.items,
    nextCursor,
    hasMore,
    meta: buildBrowseMeta(
      { provider: 'ebay', mode: 'live', query: q, limit },
      diagnostics,
    ),
  };
}

function fixtureBrowse(query: BrowseQuery): BrowseResponseDto {
  const decoded = decodeCursor(query.cursor);
  const q = query.q || decoded.q;
  const limit = query.limit;
  const offset = query.cursor ? decoded.offset : 0;
  const all = ebayFixtureItems(q);
  const slice = all.slice(offset, offset + limit);
  const hasMore = offset + limit < all.length;
  const normalized = normalizeBrowseItems(slice);

  return {
    items: normalized.items,
    nextCursor: hasMore
      ? encodeCursor({ q, limit, offset: offset + limit })
      : undefined,
    hasMore,
    meta: buildBrowseMeta(
      { provider: 'ebay', mode: 'fixture', query: q, limit },
      { acquisitionStrategy: 'fixture' },
    ),
  };
}

function buildFixtureFallbackResponse(input: {
  q: string;
  limit: number;
  offset: number;
  diagnostics: BrowseDiagnostics;
}): BrowseResponseDto {
  const { q, limit, offset, diagnostics } = input;
  const all = ebayFixtureItems(q);
  const slice = all.slice(offset, offset + limit);
  const hasMore = offset + limit < all.length;
  const normalized = normalizeBrowseItems(slice);
  diagnostics.normalizedCount = normalized.items.length;
  gatewayDebugLog('ebay_fixture_fallback', { query: q, diagnostics });

  return {
    items: normalized.items,
    nextCursor: hasMore
      ? encodeCursor({ q, limit, offset: offset + limit })
      : undefined,
    hasMore,
    meta: buildBrowseMeta(
      { provider: 'ebay', mode: 'live', query: q, limit },
      diagnostics,
    ),
  };
}

async function fetchEbaySearchPage(input: {
  query: string;
  limit: number;
  offset: number;
}): Promise<ProviderRawItem[]> {
  const token = await getEbayAccessToken();
  const params = new URLSearchParams({
    q: input.query,
    limit: String(input.limit),
    offset: String(input.offset),
  });
  const marketplace =
    process.env.EBAY_MARKETPLACE_ID?.trim() || 'EBAY_US';

  const payload = (await fetchJson(
    `${resolveEbayApiBase()}/buy/browse/v1/item_summary/search?${params.toString()}`,
    {
      headers: {
        Authorization: `Bearer ${token}`,
        'X-EBAY-C-MARKETPLACE-ID': marketplace,
        Accept: 'application/json',
      },
      timeoutMs: 12_000,
    },
  )) as { itemSummaries?: ProviderRawItem[] };

  const rows = payload.itemSummaries;
  return Array.isArray(rows) ? rows : [];
}

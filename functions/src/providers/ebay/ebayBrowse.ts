import type { Request, Response } from 'express';
import { readCache, writeCache } from '../../shared/cache/memoryCache';
import { fetchJson, HttpError } from '../../shared/http/fetchJson';
import { withRetries } from '../../shared/http/retry';
import {
  buildBrowseMeta,
  classifyUpstreamError,
  emptyDiagnostics,
  gatewayDebugLog,
} from '../gateway/gatewayDiagnostics';
import { normalizeBrowseItems } from '../gateway/normalizeBrowseItems';
import {
  composeTier2AspectFilter,
  composeTier2KeywordQ,
  mergeRawItemsById,
  shouldRunTier2Supplement,
  tier2CategoryIds,
} from '../gateway/composeBrowseTier2';
import { filterRawItemsByTaxonomy } from '../gateway/titleTaxonomyFilter';
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
    const cacheKey = `ebay:browse:${query.signature}:${query.limit}:${query.cursor ?? ''}`;
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
  let upstreamTotal = 0;
  let fetchFailed = false;

  try {
    let page = await withRetries(() =>
      fetchEbaySearchPage({
        query: q,
        limit,
        offset,
        categoryIds: query.categoryIds,
        aspectFilter: query.aspectFilter,
      }),
    );
    rawItems = page.items;
    upstreamTotal = page.total;

    if (
      rawItems.length === 0 &&
      query.franchiseAspectFilter &&
      query.franchiseAspectFilter !== query.aspectFilter
    ) {
      page = await withRetries(() =>
        fetchEbaySearchPage({
          query: q,
          limit,
          offset,
          categoryIds: query.categoryIds,
          aspectFilter: query.franchiseAspectFilter,
        }),
      );
      rawItems = page.items;
      upstreamTotal = page.total;
      diagnostics.acquisitionStrategy = 'ebay-browse-franchise-aspect';
    }

    if (shouldRunTier2Supplement(query, rawItems.length)) {
      const tier2Aspect = composeTier2AspectFilter(query);
      const tier2Q = composeTier2KeywordQ(query);
      if (tier2Aspect || tier2Q.trim()) {
        const tier2Page = await withRetries(() =>
          fetchEbaySearchPage({
            query: tier2Q,
            limit,
            offset,
            categoryIds: tier2CategoryIds(query),
            aspectFilter: tier2Aspect,
          }),
        );
        if (tier2Page.items.length > 0) {
          rawItems = mergeRawItemsById(rawItems, tier2Page.items);
          upstreamTotal = Math.max(upstreamTotal, rawItems.length);
          diagnostics.acquisitionStrategy = 'ebay-browse-tier2-keyword';
        }
      }
    }
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

  const beforeTitleFilter = rawItems.length;
  rawItems = filterRawItemsByTaxonomy(rawItems, {
    brandId: query.brandId,
    ipId: query.ipId,
  });
  const titleFilteredCount = beforeTitleFilter - rawItems.length;
  if (titleFilteredCount > 0) {
    diagnostics.rowsDropped = (diagnostics.rowsDropped ?? 0) + titleFilteredCount;
  }

  diagnostics.rawRowCount = rawItems.length;
  let normalized = normalizeBrowseItems(rawItems);
  diagnostics.normalizedCount = normalized.items.length;
  const rowsDropped =
    normalized.stats.malformedDropped + normalized.stats.duplicateDropped;
  if (rowsDropped > 0) diagnostics.rowsDropped = rowsDropped;

  let hasMore =
    upstreamTotal > 0
      ? offset + rawItems.length < upstreamTotal
      : rawItems.length >= limit;
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
  return emptyBrowseResponse({
    q,
    limit: query.limit,
    message: 'Gateway fixture mode disabled — configure live eBay credentials',
    acquisitionStrategy: 'fixture-disabled',
  });
}

function emptyBrowseResponse(input: {
  q: string;
  limit: number;
  message?: string;
  acquisitionStrategy?: string;
}): BrowseResponseDto {
  return {
    items: [],
    hasMore: false,
    meta: buildBrowseMeta(
      { provider: 'ebay', mode: 'fixture', query: input.q, limit: input.limit },
      {
        acquisitionStrategy: input.acquisitionStrategy ?? 'empty',
        parseEmpty: true,
        message: input.message,
      },
    ),
  };
}

async function fetchEbaySearchPage(input: {
  query: string;
  limit: number;
  offset: number;
  categoryIds?: string;
  aspectFilter?: string;
}): Promise<{ items: ProviderRawItem[]; total: number; offset: number }> {
  const token = await getEbayAccessToken();
  const params = new URLSearchParams({
    limit: String(input.limit),
    offset: String(input.offset),
  });
  const q = input.query.trim();
  if (q) params.set('q', q);
  const categoryIds = input.categoryIds?.trim();
  if (categoryIds) params.set('category_ids', categoryIds);
  const aspectFilter = input.aspectFilter?.trim();
  if (aspectFilter) params.set('aspect_filter', aspectFilter);
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
  )) as {
    itemSummaries?: ProviderRawItem[];
    total?: number;
    offset?: number;
  };

  const rows = payload.itemSummaries;
  const items = Array.isArray(rows) ? rows : [];
  const total =
    typeof payload.total === 'number' && Number.isFinite(payload.total)
      ? payload.total
      : items.length;
  const responseOffset =
    typeof payload.offset === 'number' && Number.isFinite(payload.offset)
      ? payload.offset
      : input.offset;
  return { items, total, offset: responseOffset };
}

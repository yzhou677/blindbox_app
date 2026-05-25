import type { Request, Response } from 'express';
import { readCache, writeCache } from '../../shared/cache/memoryCache';
import { HttpError } from '../../shared/http/fetchJson';
import { withRetries } from '../../shared/http/retry';
import { createMercariRuntime } from './runtime/createMercariRuntime';
import { normalizeBrowseItems } from './mercariNormalize';
import {
  buildBrowseMeta,
  classifyUpstreamError,
  emptyDiagnostics,
  gatewayDebugLog,
  shouldUseFixtureFallback,
} from './mercariDiagnostics';
import type {
  BrowseDiagnostics,
  BrowseQuery,
  BrowseResponseDto,
  MercariRawItem,
} from './mercariTypes';
import {
  decodeCursor,
  encodeCursor,
  parseBrowseQuery,
} from '../gateway/parseBrowseQuery';

const CACHE_TTL_MS = 90_000;

type MercariMode = 'fixture' | 'live';

function resolveMode(): MercariMode {
  const raw = (process.env.MERCARI_GATEWAY_MODE ?? 'fixture').trim().toLowerCase();
  return raw === 'live' ? 'live' : 'fixture';
}

/** Public browse handler for `GET /v1/browse`. */
export async function handleMercariBrowseRequest(
  req: Request,
  res: Response,
): Promise<void> {
  if (req.method !== 'GET') {
    res.status(405).json({ error: 'method_not_allowed' });
    return;
  }

  try {
    const query = parseBrowseQuery(req);
    const cacheKey = `browse:${query.signature}:${query.limit}:${query.cursor ?? ''}`;
    const cached = readCache<BrowseResponseDto>(cacheKey);
    if (cached) {
      res.status(200).json(cached);
      return;
    }

    const payload = await browseMercari(query);
    writeCache(cacheKey, payload, CACHE_TTL_MS);
    res.status(200).json(payload);
  } catch (e) {
    const status = e instanceof HttpError ? (e.statusCode ?? 502) : 502;
    const diagnostics: BrowseDiagnostics = {
      ...classifyUpstreamError(e),
      parseFailed: true,
      message: e instanceof Error ? e.message : 'Browse failed',
    };
    gatewayDebugLog('browse_handler_error', diagnostics);
    res.status(status).json({
      error: 'gateway_unavailable',
      message: diagnostics.message,
      items: [],
      hasMore: false,
      meta: buildBrowseMeta(
        { provider: 'mercari', mode: resolveMode(), query: '', limit: 0 },
        diagnostics,
      ),
    });
  }
}

export async function browseMercari(query: BrowseQuery): Promise<BrowseResponseDto> {
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

  const runtime = createMercariRuntime();
  const diagnostics: BrowseDiagnostics = {
    ...emptyDiagnostics(),
    acquisitionStrategy: runtime.strategyId,
  };
  let rawItems: MercariRawItem[] = [];
  let fetchFailed = false;

  try {
    rawItems = await withRetries(() =>
      runtime.fetchSearchPage({ query: q, limit, offset }),
    );
  } catch (e) {
    fetchFailed = true;
    Object.assign(diagnostics, classifyUpstreamError(e));
    diagnostics.message =
      e instanceof Error ? e.message : 'Upstream unavailable';
    gatewayDebugLog('live_fetch_failed', {
      query: q,
      ...diagnostics,
    });
  }

  if (!fetchFailed && rawItems.length === 0) {
    diagnostics.parseEmpty = true;
    diagnostics.message = 'Upstream returned no listing rows';
  }

  diagnostics.rawRowCount = rawItems.length;
  let normalized = normalizeBrowseItems(rawItems);
  diagnostics.normalizedCount = normalized.items.length;
  const rowsDropped =
    normalized.stats.malformedDropped + normalized.stats.duplicateDropped;
  if (rowsDropped > 0) diagnostics.rowsDropped = rowsDropped;

  if (shouldUseFixtureFallback({
    fetchFailed,
    rawRowCount: rawItems.length,
    normalizedCount: normalized.items.length,
  })) {
    diagnostics.usedFixtureFallback = true;
    const all = fixtureItems(q);
    const slice = all.slice(offset, offset + limit);
    normalized = normalizeBrowseItems(slice);
    diagnostics.normalizedCount = normalized.items.length;
    gatewayDebugLog('live_fixture_fallback', { query: q, diagnostics });
    return buildLiveFixtureFallbackResponse({
      q,
      limit,
      offset,
      all,
      items: normalized.items,
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

  gatewayDebugLog('live_success', {
    query: q,
    rawRowCount: rawItems.length,
    normalizedCount: normalized.items.length,
  });

  return {
    items: normalized.items,
    nextCursor,
    hasMore,
    meta: buildBrowseMeta(
      { provider: 'mercari', mode: 'live', query: q, limit },
      diagnostics,
    ),
  };
}

function buildLiveFixtureFallbackResponse(input: {
  q: string;
  limit: number;
  offset: number;
  all: MercariRawItem[];
  items: ReturnType<typeof normalizeBrowseItems>['items'];
  diagnostics: BrowseDiagnostics;
}): BrowseResponseDto {
  const { q, limit, offset, all, items, diagnostics } = input;
  const hasMore = offset + limit < all.length;
  return {
    items,
    nextCursor: hasMore
      ? encodeCursor({ q, limit, offset: offset + limit })
      : undefined,
    hasMore,
    meta: buildBrowseMeta(
      { provider: 'mercari', mode: 'live', query: q, limit },
      diagnostics,
    ),
  };
}

function fixtureBrowse(query: BrowseQuery): BrowseResponseDto {
  const decoded = decodeCursor(query.cursor);
  const q = query.q || decoded.q;
  const limit = query.limit;
  const offset = query.cursor ? decoded.offset : 0;
  const all = fixtureItems(q);
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
      { provider: 'mercari', mode: 'fixture', query: q, limit },
      { acquisitionStrategy: 'fixture' },
    ),
  };
}

function fixtureItems(query: string): MercariRawItem[] {
  const seed = query.toLowerCase();
  return [
    {
      id: 'm90000000001',
      title: `${seed} — cozy vinyl figure`,
      price: { value: '24.00', currency: 'USD' },
      image: {
        imageUrl:
          'https://u-web-mercari-static.com/assets/common/images/logo.svg',
      },
      listingUrl: 'https://www.mercari.com/us/item/m90000000001/',
    },
    {
      id: 'm90000000002',
      title: `${seed} — sealed blind box`,
      price: { value: '38.50', currency: 'USD' },
      image: {
        imageUrl:
          'https://u-web-mercari-static.com/assets/common/images/logo.svg',
      },
      listingUrl: 'https://www.mercari.com/us/item/m90000000002/',
    },
    {
      id: 'm90000000003',
      title: `${seed} — chase variant listing`,
      price: { value: '52.00', currency: 'USD' },
      image: {
        imageUrl:
          'https://u-web-mercari-static.com/assets/common/images/logo.svg',
      },
      listingUrl: 'https://www.mercari.com/us/item/m90000000003/',
    },
    {
      id: 'm90000000004',
      title: `${seed} — display set bundle`,
      price: { value: '71.00', currency: 'USD' },
      image: {
        imageUrl:
          'https://u-web-mercari-static.com/assets/common/images/logo.svg',
      },
      listingUrl: 'https://www.mercari.com/us/item/m90000000004/',
    },
  ];
}

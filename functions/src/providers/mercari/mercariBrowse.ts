import type { Request, Response } from 'express';
import { readCache, writeCache } from '../../shared/cache/memoryCache';
import { fetchJson, HttpError } from '../../shared/http/fetchJson';
import { withRetries } from '../../shared/http/retry';
import { extractMercariItems } from './mercariParser';
import { normalizeBrowseItems } from './mercariNormalize';
import {
  buildBrowseMeta,
  classifyUpstreamError,
  emptyDiagnostics,
  gatewayDebugLog,
  shouldUseFixtureFallback,
} from './mercariDiagnostics';
import type {
  BrowseCursorPayload,
  BrowseDiagnostics,
  BrowseQuery,
  BrowseResponseDto,
  MercariRawItem,
} from './mercariTypes';

const DEFAULT_QUERY = 'pop mart blind box';
const DEFAULT_LIMIT = 24;
const MAX_LIMIT = 48;
const CACHE_TTL_MS = 90_000;
const SEARCH_APQ_HASH =
  '5b7b667eaf8a796406058428fa5df18e7cecd5229702ee0753a091d980884d38';

type MercariMode = 'fixture' | 'live';

function resolveMode(): MercariMode {
  const raw = (process.env.MERCARI_GATEWAY_MODE ?? 'fixture').trim().toLowerCase();
  return raw === 'live' ? 'live' : 'fixture';
}

function resolveDefaultQuery(): string {
  const q = process.env.MERCARI_DEFAULT_QUERY?.trim();
  return q && q.length > 0 ? q : DEFAULT_QUERY;
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
    const cacheKey = `browse:${query.q}:${query.limit}:${query.cursor ?? ''}`;
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
        { mode: resolveMode(), query: '', limit: 0 },
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

function parseBrowseQuery(req: Request): BrowseQuery {
  const limitRaw = parseInt(String(req.query.limit ?? DEFAULT_LIMIT), 10);
  const limit = clamp(
    Number.isFinite(limitRaw) ? limitRaw : DEFAULT_LIMIT,
    1,
    MAX_LIMIT,
  );
  const qRaw = String(req.query.q ?? req.query.query ?? '').trim();
  const q = qRaw.length > 0 ? qRaw : resolveDefaultQuery();
  const cursorRaw = String(req.query.cursor ?? '').trim();
  return { limit, q, cursor: cursorRaw || undefined };
}

function parseCursor(raw: string): BrowseCursorPayload | undefined {
  const trimmed = raw.trim();
  if (!trimmed) return undefined;
  try {
    const json = Buffer.from(trimmed, 'base64url').toString('utf8');
    const parsed = JSON.parse(json) as BrowseCursorPayload;
    if (
      typeof parsed.q === 'string' &&
      typeof parsed.limit === 'number' &&
      typeof parsed.offset === 'number'
    ) {
      return parsed;
    }
  } catch {
    return undefined;
  }
  return undefined;
}

function encodeCursor(payload: BrowseCursorPayload): string {
  return Buffer.from(JSON.stringify(payload), 'utf8').toString('base64url');
}

function decodeCursor(token: string | undefined): BrowseCursorPayload {
  if (!token) {
    return { q: resolveDefaultQuery(), limit: DEFAULT_LIMIT, offset: 0 };
  }
  return parseCursor(token) ?? { q: resolveDefaultQuery(), limit: DEFAULT_LIMIT, offset: 0 };
}

async function liveBrowse(query: BrowseQuery): Promise<BrowseResponseDto> {
  const decoded = decodeCursor(query.cursor);
  const q = query.q || decoded.q;
  const limit = query.limit;
  const offset = query.cursor ? decoded.offset : 0;

  const diagnostics: BrowseDiagnostics = emptyDiagnostics();
  let rawItems: MercariRawItem[] = [];
  let fetchFailed = false;

  try {
    rawItems = await withRetries(() => fetchMercariSearchPage(q, limit, offset));
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
    meta: buildBrowseMeta({ mode: 'live', query: q, limit }, diagnostics),
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
    meta: buildBrowseMeta({ mode: 'live', query: q, limit }, diagnostics),
  };
}

async function fetchMercariSearchPage(
  query: string,
  limit: number,
  offset: number,
): Promise<MercariRawItem[]> {
  const variables = {
    criteria: query,
    offset,
    limit,
    sortBy: 2,
    itemStatuses: [1, 2],
    sellerIds: [],
    facetTypes: [],
    facetValues: [],
    priceMin: 0,
    priceMax: 0,
    conditionIds: [],
    shippingPayerIds: [],
    shippingMethodIds: [],
    countrySources: ['US'],
  };

  const params = new URLSearchParams({
    operationName: 'searchFacetQuery',
    variables: JSON.stringify(variables),
    extensions: JSON.stringify({
      persistedQuery: { version: 1, sha256Hash: SEARCH_APQ_HASH },
    }),
  });

  const url = `https://www.mercari.com/v1/api?${params.toString()}`;
  const headers = buildMercariHeaders();
  const payload = await fetchJson(url, { headers, timeoutMs: 12_000 });
  return extractMercariItems(payload);
}

function buildMercariHeaders(): Record<string, string> {
  const base: Record<string, string> = {
    accept: 'application/json',
    'accept-language': 'en-US,en;q=0.9',
    'user-agent':
      process.env.MERCARI_USER_AGENT?.trim() ||
      'Mozilla/5.0 (compatible; BlindboxGateway/1.0)',
    'x-apollo-operation-name': 'searchFacetQuery',
  };

  const extraJson = process.env.MERCARI_EXTRA_HEADERS_JSON?.trim();
  if (!extraJson) return base;

  try {
    const extra = JSON.parse(extraJson) as Record<string, string>;
    return { ...base, ...extra };
  } catch {
    return base;
  }
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
    meta: buildBrowseMeta({ mode: 'fixture', query: q, limit }, emptyDiagnostics()),
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

function clamp(value: number, min: number, max: number): number {
  return Math.min(max, Math.max(min, value));
}

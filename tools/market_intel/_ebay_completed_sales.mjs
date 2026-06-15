/**
 * Market Intelligence — eBay completed sales fetch (Finding API).
 *
 * Uses findCompletedItems for sold listing retrieval.
 * Pure response parsing is testable without network.
 */

import {
  ebayClientIdConfigured,
  readEbayConfig,
  resolveFindingApiBase,
} from './_ebay_env.mjs';

const DEFAULT_PAGE_SIZE = 50;
const DEFAULT_MAX_RETRIES = 3;
const DEFAULT_RETRY_BASE_MS = 500;
const DEFAULT_INTER_QUERY_DELAY_MS = 300;

const RETRYABLE_STATUS = new Set([429, 500, 502, 503, 504]);

/** @type {typeof fetch | null} */
let fetchImpl = typeof fetch === 'function' ? fetch : null;

/**
 * @param {typeof fetch} impl
 */
export function setFetchImplementation(impl) {
  fetchImpl = impl;
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

/**
 * @param {unknown} value
 * @returns {string | undefined}
 */
function firstValue(value) {
  if (Array.isArray(value)) {
    return value[0];
  }

  if (value == null) {
    return undefined;
  }

  return String(value);
}

/**
 * @param {unknown} priceNode
 * @returns {number | null}
 */
export function parseSoldPriceUsd(priceNode) {
  if (priceNode == null) {
    return null;
  }

  const node = Array.isArray(priceNode) ? priceNode[0] : priceNode;
  if (node == null) {
    return null;
  }

  if (typeof node === 'number') {
    return Number.isFinite(node) ? node : null;
  }

  if (typeof node === 'string') {
    const parsed = Number.parseFloat(node);
    return Number.isFinite(parsed) ? parsed : null;
  }

  if (typeof node === 'object') {
    const raw =
      node.__value__ ??
      node.value ??
      node['@__value__'] ??
      node['__value__'];
    const parsed = Number.parseFloat(String(raw ?? ''));
    return Number.isFinite(parsed) ? parsed : null;
  }

  return null;
}

/**
 * @param {unknown} payload
 * @returns {import('./_snapshot_fetch.mjs').CompletedSaleListing[]}
 */
export function parseFindCompletedItemsResponse(payload) {
  const response = payload?.findCompletedItemsResponse?.[0] ?? payload?.findCompletedItemsResponse;
  const searchResult = response?.searchResult?.[0] ?? response?.searchResult;
  const rawItems = searchResult?.item ?? [];

  const items = Array.isArray(rawItems) ? rawItems : rawItems ? [rawItems] : [];

  return items
    .map((item) => {
      const sellingStatus = item?.sellingStatus?.[0] ?? item?.sellingStatus;
      const listingInfo = item?.listingInfo?.[0] ?? item?.listingInfo;

      return {
        itemId: firstValue(item?.itemId) ?? '',
        title: firstValue(item?.title) ?? '',
        soldPriceUsd: parseSoldPriceUsd(sellingStatus?.currentPrice),
        soldDate: firstValue(listingInfo?.endTime) ?? null,
        listingUrl: firstValue(item?.viewItemURL) ?? null,
      };
    })
    .filter((item) => item.itemId && item.title);
}

/**
 * @param {unknown} payload
 * @returns {number | null}
 */
export function parseFindCompletedItemsTotal(payload) {
  const response = payload?.findCompletedItemsResponse?.[0] ?? payload?.findCompletedItemsResponse;
  const pagination = response?.paginationOutput?.[0] ?? response?.paginationOutput;
  const totalEntries = firstValue(pagination?.totalEntries);
  if (!totalEntries) {
    return null;
  }

  const parsed = Number.parseInt(totalEntries, 10);
  return Number.isFinite(parsed) ? parsed : null;
}

/**
 * @param {string} query
 * @param {{
 *   pageSize?: number,
 *   pageNumber?: number,
 *   globalId?: string,
 * }} [options]
 * @returns {URLSearchParams}
 */
export function buildFindCompletedItemsParams(query, options = {}) {
  const params = new URLSearchParams({
    'OPERATION-NAME': 'findCompletedItems',
    'SERVICE-VERSION': '1.13.0',
    'RESPONSE-DATA-FORMAT': 'JSON',
    'REST-PAYLOAD': '',
    keywords: query,
    'paginationInput.entriesPerPage': String(options.pageSize ?? DEFAULT_PAGE_SIZE),
    'paginationInput.pageNumber': String(options.pageNumber ?? 1),
    'itemFilter(0).name': 'SoldItemsOnly',
    'itemFilter(0).value': 'true',
    'GLOBAL-ID': options.globalId ?? 'EBAY-US',
  });

  return params;
}

/**
 * @param {string} query
 * @returns {import('./_snapshot_fetch.mjs').CompletedSaleListing[]}
 */
export function buildFixtureCompletedSales(query) {
  const normalized = query.toLowerCase();

  if (normalized.includes('sisi')) {
    return [
      {
        itemId: 'fixture-sisi-1',
        title: 'POP MART Labubu Have a Seat SISI Vinyl Plush',
        soldPriceUsd: 38.5,
        soldDate: '2025-05-01T18:22:00.000Z',
        listingUrl: 'https://www.ebay.com/itm/fixture-sisi-1',
      },
      {
        itemId: 'fixture-sisi-2',
        title: 'POPMART Have a Seat SISI Plush Keychain',
        soldPriceUsd: 41,
        soldDate: '2025-05-03T11:05:00.000Z',
        listingUrl: 'https://www.ebay.com/itm/fixture-sisi-2',
      },
    ];
  }

  if (normalized.includes(' id ') || normalized.endsWith(' id') || normalized.includes(' id secret')) {
    return [
      {
        itemId: 'fixture-id-1',
        title: 'POP MART Labubu Big Into Energy Id Secret Chase',
        soldPriceUsd: 95,
        soldDate: '2025-04-28T09:15:00.000Z',
        listingUrl: 'https://www.ebay.com/itm/fixture-id-1',
      },
    ];
  }

  const isBigIntoEnergyLuckQuery =
    normalized.includes('big into energy') ||
    normalized.includes('lucky big into energy') ||
    normalized.includes('lucky big energy');

  if (
    isBigIntoEnergyLuckQuery &&
    (normalized.includes('lucky') || /\bluck\b/.test(normalized))
  ) {
    return [
      {
        itemId: 'fixture-luck-1',
        title: 'POP MART THE MONSTERS Luck Big Into Energy Vinyl Plush',
        soldPriceUsd: 40,
        soldDate: '2025-05-02T10:00:00.000Z',
        listingUrl: 'https://www.ebay.com/itm/fixture-luck-1',
      },
      {
        itemId: 'fixture-luck-2',
        title: 'POPMART THE MONSTERS Big Into Energy Luck Vinyl Plush Figure',
        soldPriceUsd: 39.5,
        soldDate: '2025-05-04T14:30:00.000Z',
        listingUrl: 'https://www.ebay.com/itm/fixture-luck-2',
      },
    ];
  }

  return [
    {
      itemId: 'fixture-generic-1',
      title: `${query} - sold listing sample A`,
      soldPriceUsd: 42,
      soldDate: '2025-05-10T12:00:00.000Z',
      listingUrl: 'https://www.ebay.com/itm/fixture-generic-1',
    },
    {
      itemId: 'fixture-generic-2',
      title: `${query} - sold listing sample B`,
      soldPriceUsd: 39.99,
      soldDate: '2025-05-08T08:30:00.000Z',
      listingUrl: 'https://www.ebay.com/itm/fixture-generic-2',
    },
  ];
}

/**
 * @param {string} query
 * @param {{
 *   pageSize?: number,
 *   pageNumber?: number,
 *   maxRetries?: number,
 *   retryBaseMs?: number,
 *   fetchMode?: 'live' | 'fixture',
 *   clientId?: string,
 * }} [options]
 * @returns {Promise<import('./_snapshot_fetch.mjs').CompletedSalesQueryResult>}
 */
export async function fetchCompletedSalesForQuery(query, options = {}) {
  const startedAt = Date.now();
  const config = readEbayConfig();
  const fetchMode = options.fetchMode ?? config.fetchMode;
  const pageSize = options.pageSize ?? DEFAULT_PAGE_SIZE;
  const pageNumber = options.pageNumber ?? 1;
  const maxRetries = options.maxRetries ?? DEFAULT_MAX_RETRIES;
  const retryBaseMs = options.retryBaseMs ?? DEFAULT_RETRY_BASE_MS;
  const clientId = options.clientId ?? config.clientId;

  if (fetchMode === 'fixture') {
    const listings = buildFixtureCompletedSales(query);
    return {
      query,
      ok: true,
      listings,
      total: listings.length,
      error: null,
      retries: 0,
      rateLimited: false,
      durationMs: Date.now() - startedAt,
      source: 'fixture',
    };
  }

  if (!clientId || !ebayClientIdConfigured()) {
    return {
      query,
      ok: false,
      listings: [],
      total: 0,
      error: 'EBAY_CLIENT_ID not configured',
      retries: 0,
      rateLimited: false,
      durationMs: Date.now() - startedAt,
      source: 'finding_api',
    };
  }

  if (!fetchImpl) {
    return {
      query,
      ok: false,
      listings: [],
      total: 0,
      error: 'fetch implementation unavailable',
      retries: 0,
      rateLimited: false,
      durationMs: Date.now() - startedAt,
      source: 'finding_api',
    };
  }

  const params = buildFindCompletedItemsParams(query, { pageSize, pageNumber });
  params.set('SECURITY-APPNAME', clientId);

  const url = `${resolveFindingApiBase()}?${params.toString()}`;

  let retries = 0;
  let rateLimited = false;

  for (let attempt = 0; attempt <= maxRetries; attempt += 1) {
    try {
      const response = await fetchImpl(url, {
        method: 'GET',
        headers: {
          Accept: 'application/json',
        },
      });

      const contentType = response.headers.get('content-type') ?? '';
      const bodyText = await response.text();
      /** @type {unknown} */
      let payload;

      try {
        payload = JSON.parse(bodyText);
      } catch {
        const snippet = bodyText.trim().slice(0, 120).replace(/\s+/g, ' ');
        const parseError = `Non-JSON response (HTTP ${response.status}, ${contentType || 'unknown content-type'}): ${snippet}`;

        if (RETRYABLE_STATUS.has(response.status) && attempt < maxRetries) {
          retries += 1;
          if (response.status === 429) {
            rateLimited = true;
          }
          await sleep(retryBaseMs * 2 ** attempt);
          continue;
        }

        return {
          query,
          ok: false,
          listings: [],
          total: 0,
          error: parseError,
          retries,
          rateLimited: response.status === 429 || rateLimited,
          durationMs: Date.now() - startedAt,
          source: 'finding_api',
        };
      }

      if (response.ok) {
        const ack = firstValue(payload?.findCompletedItemsResponse?.[0]?.ack) ??
          payload?.findCompletedItemsResponse?.ack;

        if (ack && ack !== 'Success' && ack !== 'Warning') {
          const errorMessage =
            firstValue(payload?.findCompletedItemsResponse?.[0]?.errorMessage?.[0]?.error?.[0]?.message) ??
            `Finding API ack=${ack}`;

          return {
            query,
            ok: false,
            listings: [],
            total: 0,
            error: errorMessage,
            retries,
            rateLimited,
            durationMs: Date.now() - startedAt,
            source: 'finding_api',
          };
        }

        const listings = parseFindCompletedItemsResponse(payload);
        return {
          query,
          ok: true,
          listings,
          total: parseFindCompletedItemsTotal(payload) ?? listings.length,
          error: null,
          retries,
          rateLimited,
          durationMs: Date.now() - startedAt,
          source: 'finding_api',
        };
      }

      if (response.status === 429) {
        rateLimited = true;
      }

      if (RETRYABLE_STATUS.has(response.status) && attempt < maxRetries) {
        retries += 1;
        await sleep(retryBaseMs * 2 ** attempt);
        continue;
      }

      const apiMessage =
        payload?.errorMessage?.[0]?.error?.[0]?.message ??
        payload?.errors?.[0]?.message ??
        `HTTP ${response.status}`;

      return {
        query,
        ok: false,
        listings: [],
        total: 0,
        error: String(apiMessage),
        retries,
        rateLimited,
        durationMs: Date.now() - startedAt,
        source: 'finding_api',
      };
    } catch (error) {
      if (attempt < maxRetries) {
        retries += 1;
        await sleep(retryBaseMs * 2 ** attempt);
        continue;
      }

      return {
        query,
        ok: false,
        listings: [],
        total: 0,
        error: error instanceof Error ? error.message : String(error),
        retries,
        rateLimited,
        durationMs: Date.now() - startedAt,
        source: 'finding_api',
      };
    }
  }

  return {
    query,
    ok: false,
    listings: [],
    total: 0,
    error: 'exhausted retries',
    retries,
    rateLimited,
    durationMs: Date.now() - startedAt,
    source: 'finding_api',
  };
}

export const EBAY_FETCH_DEFAULTS = Object.freeze({
  pageSize: DEFAULT_PAGE_SIZE,
  maxRetries: DEFAULT_MAX_RETRIES,
  retryBaseMs: DEFAULT_RETRY_BASE_MS,
  interQueryDelayMs: DEFAULT_INTER_QUERY_DELAY_MS,
});

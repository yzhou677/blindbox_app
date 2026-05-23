import { fetchJson } from '../../../shared/http/fetchJson';
import { extractMercariItems } from '../mercariParser';
import type { MercariRawItem } from '../mercariTypes';
import type {
  MercariProviderRuntime,
  MercariSearchPageRequest,
} from './mercariProviderRuntime';

const SEARCH_APQ_HASH =
  '5b7b667eaf8a796406058428fa5df18e7cecd5229702ee0753a091d980884d38';

/**
 * HTTP + Mercari US search APQ acquisition.
 *
 * Treat as one strategy — not the permanent architecture. Session headers via
 * `MERCARI_EXTRA_HEADERS_JSON` are a bridge until browser-runtime acquisition exists.
 */
export class FetchMercariRuntime implements MercariProviderRuntime {
  readonly strategyId = 'fetch' as const;

  async fetchSearchPage(request: MercariSearchPageRequest): Promise<MercariRawItem[]> {
    const { query, limit, offset } = request;
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
    const payload = await fetchJson(url, {
      headers: buildMercariHeaders(),
      timeoutMs: 12_000,
    });
    return extractMercariItems(payload);
  }
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

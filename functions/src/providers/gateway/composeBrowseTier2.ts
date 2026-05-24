/**
 * Tier 2 — when strict aspect rows are sparse, supplement with Brand aspect
 * locked + IP keywords in `q` (no Character aspect).
 */

import {
  ANY_BRAND,
  ANY_IP,
  composeBrowseUpstreamQ,
  ipKeywordTerm,
} from './composeBrowseQuery';
import {
  composeBrowseBrandOnlyAspectPlan,
  resolveBrowseCategoryId,
} from './composeBrowseAspectFilter';
import type { BrowseQuery, ProviderRawItem } from './gatewayTypes';

export const TIER2_MIN_RAW_ROWS = 6;

export function shouldRunTier2Supplement(query: BrowseQuery, rawCount: number): boolean {
  if (rawCount >= TIER2_MIN_RAW_ROWS) return false;
  if (!query.aspectFilter?.trim()) return false;
  const brandId = (query.brandId ?? ANY_BRAND).trim();
  const ipId = (query.ipId ?? ANY_IP).trim();
  return (
    (brandId.length > 0 && brandId !== ANY_BRAND) ||
    (ipId.length > 0 && ipId !== ANY_IP)
  );
}

export function composeTier2KeywordQ(query: BrowseQuery): string {
  const terms: string[] = [];
  const ipId = (query.ipId ?? ANY_IP).trim();
  if (ipId && ipId !== ANY_IP) {
    const ipTerm = ipKeywordTerm(ipId);
    if (ipTerm) terms.push(ipTerm);
  }
  const search = (query.searchText ?? '').trim();
  if (search) terms.push(search);
  if (terms.length > 0) return terms.join(' ');

  return composeBrowseUpstreamQ({
    brandId: query.brandId,
    ipId: query.ipId,
    searchText: query.searchText,
  });
}

export function composeTier2AspectFilter(query: BrowseQuery): string | undefined {
  const brandId = (query.brandId ?? ANY_BRAND).trim();
  if (!brandId || brandId === ANY_BRAND) return undefined;
  const ipId = (query.ipId ?? ANY_IP).trim();
  return composeBrowseBrandOnlyAspectPlan(
    brandId,
    ipId !== ANY_IP ? ipId : undefined,
  )?.aspectFilter;
}

export function mergeRawItemsById(
  primary: ProviderRawItem[],
  supplemental: ProviderRawItem[],
): ProviderRawItem[] {
  const out: ProviderRawItem[] = [...primary];
  const seen = new Set(primary.map(readItemId).filter(Boolean));
  for (const row of supplemental) {
    const id = readItemId(row);
    if (id && seen.has(id)) continue;
    if (id) seen.add(id);
    out.push(row);
  }
  return out;
}

function readItemId(raw: ProviderRawItem): string {
  const id = raw.itemId ?? raw.id ?? raw.productId;
  return typeof id === 'string' ? id.trim() : '';
}

export function tier2CategoryIds(query: BrowseQuery): string {
  return query.categoryIds?.trim() || resolveBrowseCategoryId();
}

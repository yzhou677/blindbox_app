/**
 * Tier 2 — when verified Character aspect rows are sparse, retry q-only
 * (no aspect_filter) with full brand + IP keywords.
 */

import { ANY_BRAND, ANY_IP, composeBrowseUpstreamQ } from './composeBrowseQuery';
import { resolveBrowseCategoryId } from './composeBrowseAspectFilter';
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
  return composeBrowseUpstreamQ({
    brandId: query.brandId,
    ipId: query.ipId,
    searchText: query.searchText,
  });
}

/** Tier 2 is q-only — Brand aspect_filter is deprecated. */
export function composeTier2AspectFilter(_query: BrowseQuery): string | undefined {
  return undefined;
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

export function tier2CategoryIds(_query: BrowseQuery): string {
  return resolveBrowseCategoryId();
}

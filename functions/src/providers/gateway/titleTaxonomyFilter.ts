/**
 * Tier 3 — drop browse rows whose titles contradict selected brand/IP facets.
 * Mirrors Flutter [TitleTaxonomyResolver] substring rules (gateway-only).
 */

import {
  ANY_BRAND,
  ANY_IP,
  MARKET_TAXONOMY_BRANDS,
  MARKET_TAXONOMY_IPS,
} from './composeBrowseQuery';
import { brandTitleMatchTokens } from './ebayBrandAspect';
import type { ProviderRawItem } from './gatewayTypes';

export function filterRawItemsByTaxonomy(
  rows: ProviderRawItem[],
  input: { brandId?: string; ipId?: string },
): ProviderRawItem[] {
  const brandId = (input.brandId ?? ANY_BRAND).trim();
  const ipId = (input.ipId ?? ANY_IP).trim();
  const hasBrand = brandId.length > 0 && brandId !== ANY_BRAND;
  const hasIp = ipId.length > 0 && ipId !== ANY_IP;
  if (!hasBrand && !hasIp) return rows;

  return rows.filter((row) => {
    const title = readTitle(row);
    if (!title) return false;
    return listingTitleMatchesTaxonomy(title, { brandId, ipId });
  });
}

export function listingTitleMatchesTaxonomy(
  rawTitle: string,
  input: { brandId?: string; ipId?: string },
): boolean {
  const brandId = (input.brandId ?? ANY_BRAND).trim();
  const ipId = (input.ipId ?? ANY_IP).trim();
  const hasBrand = brandId.length > 0 && brandId !== ANY_BRAND;
  const hasIp = ipId.length > 0 && ipId !== ANY_IP;
  const norm = normalizeTitle(rawTitle);
  if (!norm) return false;

  if (hasIp && !titleContainsIp(norm, ipId)) return false;
  if (hasBrand && !titleContainsBrand(norm, brandId)) {
    // Sellers often omit studio brand in title when IP is obvious (e.g. Baby Three).
    return hasIp && titleContainsIp(norm, ipId);
  }
  return true;
}

function titleContainsBrand(normTitle: string, brandId: string): boolean {
  const tokens = brandTitleMatchTokens(brandId);
  const brand = MARKET_TAXONOMY_BRANDS.find((b) => b.id === brandId);
  for (const extra of brand?.titleMatchAliases ?? []) {
    tokens.push(normalizeTitle(extra));
  }
  return tokens.some((token) => token.length > 0 && normTitle.includes(token));
}

function titleContainsIp(normTitle: string, ipId: string): boolean {
  const ip = MARKET_TAXONOMY_IPS.find((row) => row.id === ipId);
  if (!ip) return false;
  const tokens: string[] = [];
  for (const alias of ip.aliases) {
    const token = normalizeTitle(alias);
    if (token.length > 0) tokens.push(token);
  }
  const display = normalizeTitle(ip.displayName);
  if (display.length > 0) tokens.push(display);
  for (const extra of ip.titleMatchAliases ?? []) {
    const token = normalizeTitle(extra);
    if (token.length > 0) tokens.push(token);
  }
  return tokens.some((token) => normTitle.includes(token));
}

function normalizeTitle(raw: string): string {
  return raw.trim().toUpperCase().replace(/\s+/g, ' ');
}

function readTitle(raw: ProviderRawItem): string {
  const title = raw.title ?? raw.name;
  return typeof title === 'string' ? title.trim() : '';
}

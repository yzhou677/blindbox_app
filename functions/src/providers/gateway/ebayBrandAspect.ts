/**
 * Maps in-app brand/IP facets to eBay Browse Brand aspect values.
 */

import {
  ANY_IP,
  MARKET_HIDDEN_BROWSE_BRAND_IDS,
  MARKET_TAXONOMY_BRANDS,
  MARKET_TAXONOMY_IPS,
  type TaxonomyBrand,
} from './composeBrowseQuery';

/** All visible in-app brands → unique eBay Brand aspect values (OR discover feed). */
export function resolveCuratedEbayBrandAspectValues(): string[] {
  const out = new Set<string>();
  for (const brand of MARKET_TAXONOMY_BRANDS) {
    if (MARKET_HIDDEN_BROWSE_BRAND_IDS.has(brand.id)) continue;
    for (const value of resolveEbayBrandAspectValues(brand.id, ANY_IP)) {
      out.add(value);
    }
  }
  return [...out];
}

/** Resolves eBay `Brand:{…}` aspect values for a brand/IP facet pair. */
export function resolveEbayBrandAspectValues(
  brandId: string,
  ipId?: string,
): string[] {
  const trimmedIp = (ipId ?? ANY_IP).trim();
  if (trimmedIp && trimmedIp !== ANY_IP) {
    const ip = MARKET_TAXONOMY_IPS.find((row) => row.id === trimmedIp);
    if (ip?.ebayAspectBrand) return [ip.ebayAspectBrand];
  }

  const brand = MARKET_TAXONOMY_BRANDS.find((b) => b.id === brandId);
  if (!brand) return [];

  if (brand.ebayAspectBrands?.length) return [...brand.ebayAspectBrands];
  if (brand.ebayAspectBrand) return [brand.ebayAspectBrand];
  return [brand.displayName];
}

export function ipUsesCharacterAspect(ipId: string): boolean {
  const ip = MARKET_TAXONOMY_IPS.find((row) => row.id === ipId);
  if (!ip) return false;
  return !ip.ebayAspectBrand;
}

/** Title-match tokens for a studio brand (includes child eBay brand lines). */
export function brandTitleMatchTokens(brandId: string): string[] {
  const brand = MARKET_TAXONOMY_BRANDS.find((b) => b.id === brandId);
  if (!brand) return [];
  const out = new Set<string>();
  for (const token of collectBrandTitleTokens(brand)) {
    out.add(token);
  }
  for (const ip of MARKET_TAXONOMY_IPS) {
    if (ip.brandId !== brandId) continue;
    if (ip.ebayAspectBrand) {
      out.add(normalizeToken(ip.ebayAspectBrand));
    }
    out.add(normalizeToken(ip.displayName));
    for (const alias of ip.aliases) {
      out.add(normalizeToken(alias));
    }
  }
  out.delete('');
  return [...out];
}

function collectBrandTitleTokens(brand: TaxonomyBrand): string[] {
  const out = new Set<string>();
  out.add(normalizeToken(brand.displayName));
  if (brand.ebayAspectBrand) out.add(normalizeToken(brand.ebayAspectBrand));
  for (const value of brand.ebayAspectBrands ?? []) {
    out.add(normalizeToken(value));
  }
  for (const alias of brand.aliases ?? []) {
    out.add(normalizeToken(alias));
  }
  out.delete('');
  return [...out];
}

function normalizeToken(raw: string): string {
  return raw.trim().toUpperCase().replace(/\s+/g, ' ');
}

/**
 * Brand/IP title tokens and legacy aspect helpers.
 * Live retrieval uses `q` + verified Character facet — not Brand aspect_filter.
 */

import {
  MARKET_TAXONOMY_BRANDS,
  MARKET_TAXONOMY_IPS,
  type TaxonomyBrand,
} from './composeBrowseQuery';

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
  if (brand.ebayBrandQuery) out.add(normalizeToken(brand.ebayBrandQuery));
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

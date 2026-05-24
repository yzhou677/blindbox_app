/**
 * eBay Browse aspect filters for brand/IP facets.
 *
 * Uses structured item specifics (Brand, Character, Franchise) instead of
 * stuffing brand/IP into the keyword `q` parameter.
 */

import {
  ANY_BRAND,
  ANY_IP,
  MARKET_TAXONOMY_IPS,
  type TaxonomyIp,
} from './composeBrowseQuery';
import {
  ipUsesCharacterAspect,
  resolveCuratedEbayBrandAspectValues,
  resolveEbayBrandAspectValues,
} from './ebayBrandAspect';

export type BrowseAspectPlan = {
  active: boolean;
  categoryIds: string;
  aspectFilter?: string;
  /** Character aspect OR-list (for diagnostics). */
  ipCharacterValues?: string[];
  /** Franchise aspect OR-list (fallback when Character misses). */
  ipFranchiseValues?: string[];
};

const DEFAULT_CATEGORY_ID = '19007'; // Collectibles > Designer & Urban Vinyl (US)

export function resolveBrowseCategoryId(): string {
  const raw =
    process.env.EBAY_BROWSE_CATEGORY_ID?.trim() ||
    process.env.EBAY_BROWSE_CATEGORY_IDS?.trim();
  if (raw) return raw.split(',')[0]?.trim() || DEFAULT_CATEGORY_ID;
  return DEFAULT_CATEGORY_ID;
}

export function composeBrowseAspectPlan(input: {
  brandId?: string;
  ipId?: string;
}): BrowseAspectPlan {
  const brandId = (input.brandId ?? ANY_BRAND).trim();
  const ipId = (input.ipId ?? ANY_IP).trim();
  const hasBrand = brandId.length > 0 && brandId !== ANY_BRAND;
  const hasIp = ipId.length > 0 && ipId !== ANY_IP;

  const categoryIds = resolveBrowseCategoryId();

  if (!hasBrand && !hasIp) {
    const brandValues = resolveCuratedEbayBrandAspectValues();
    if (brandValues.length === 0) {
      return { active: false, categoryIds };
    }
    return {
      active: true,
      categoryIds,
      aspectFilter: `categoryId:${categoryIds},Brand:${formatAspectOrValues(brandValues)}`,
    };
  }
  const parts: string[] = [`categoryId:${categoryIds}`];

  if (hasBrand) {
    const brandValues = resolveEbayBrandAspectValues(brandId, ipId);
    if (brandValues.length > 0) {
      parts.push(`Brand:${formatAspectOrValues(brandValues)}`);
    }
  }

  const ipCharacterValues =
    hasIp && ipUsesCharacterAspect(ipId) ? ebayIpCharacterValues(ipId) : [];
  const ipFranchiseValues = hasIp ? ebayIpFranchiseValues(ipId) : [];

  if (ipCharacterValues.length > 0) {
    parts.push(`Character:${formatAspectOrValues(ipCharacterValues)}`);
  }

  return {
    active: true,
    categoryIds,
    aspectFilter: parts.join(','),
    ipCharacterValues,
    ipFranchiseValues,
  };
}

/** Franchise-only aspect filter — used when Character aspect returns no rows. */
export function composeBrowseFranchiseAspectPlan(input: {
  brandId?: string;
  ipId?: string;
}): BrowseAspectPlan | null {
  const brandId = (input.brandId ?? ANY_BRAND).trim();
  const ipId = (input.ipId ?? ANY_IP).trim();
  const franchiseValues = ebayIpFranchiseValues(ipId);
  if (!franchiseValues.length) return null;

  const categoryIds = resolveBrowseCategoryId();
  const parts: string[] = [`categoryId:${categoryIds}`];

  const hasBrand = brandId.length > 0 && brandId !== ANY_BRAND;
  if (hasBrand) {
    const brandValues = resolveEbayBrandAspectValues(brandId, ipId);
    if (brandValues.length > 0) {
      parts.push(`Brand:${formatAspectOrValues(brandValues)}`);
    }
  }

  parts.push(`Franchise:${formatAspectOrValues(franchiseValues)}`);

  return {
    active: true,
    categoryIds,
    aspectFilter: parts.join(','),
    ipFranchiseValues: franchiseValues,
  };
}

/** Brand-only aspect filter (Tier 2 keyword path). */
export function composeBrowseBrandOnlyAspectPlan(
  brandId: string,
  ipId?: string,
): BrowseAspectPlan | null {
  const brandValues = resolveEbayBrandAspectValues(brandId, ipId);
  if (brandValues.length === 0) return null;
  const categoryIds = resolveBrowseCategoryId();
  return {
    active: true,
    categoryIds,
    aspectFilter: `categoryId:${categoryIds},Brand:${formatAspectOrValues(brandValues)}`,
  };
}

function ebayIpCharacterValues(ipId: string): string[] {
  const ip = MARKET_TAXONOMY_IPS.find((row) => row.id === ipId);
  if (!ip) return [];
  return collectIpAspectTokens(ip, { includeFranchiseLine: true });
}

function ebayIpFranchiseValues(ipId: string): string[] {
  const ip = MARKET_TAXONOMY_IPS.find((row) => row.id === ipId);
  if (!ip) return [];
  const franchiseLine = franchiseLineForIp(ip);
  if (!franchiseLine) return [];
  return [franchiseLine];
}

function collectIpAspectTokens(
  ip: TaxonomyIp,
  input: { includeFranchiseLine: boolean },
): string[] {
  const out = new Set<string>();
  for (const token of ip.aliases) {
    if (token.trim()) out.add(token.trim());
  }
  if (input.includeFranchiseLine) {
    const franchise = franchiseLineForIp(ip);
    if (franchise) out.add(franchise);
  }
  const primary = primaryIpAlias(ip);
  if (primary) out.add(primary);
  return [...out];
}

/** Line-level IP name when distinct from the primary figure alias (e.g. THE MONSTERS vs LABUBU). */
function franchiseLineForIp(ip: TaxonomyIp): string | undefined {
  const display = ip.displayName.trim();
  const primary = primaryIpAlias(ip);
  if (!display || !primary) return undefined;
  if (display.toUpperCase() === primary.toUpperCase()) return undefined;
  return display;
}

function primaryIpAlias(ip: TaxonomyIp): string {
  for (const alias of ip.aliases) {
    if (alias.toUpperCase() !== ip.displayName.toUpperCase()) return alias;
  }
  return ip.displayName;
}

function formatAspectOrValues(values: string[]): string {
  const unique = [...new Set(values.map((v) => v.trim()).filter(Boolean))];
  return `{${unique.map(escapeAspectValue).join('|')}}`;
}

function escapeAspectValue(value: string): string {
  return value.replace(/\|/g, '\\|');
}

export function shouldUseAspectFacets(input: {
  brandId?: string;
  ipId?: string;
  qOverride?: string;
}): boolean {
  if (input.qOverride?.trim()) return false;
  const brandId = (input.brandId ?? ANY_BRAND).trim();
  const ipId = (input.ipId ?? ANY_IP).trim();
  const hasBrand = brandId.length > 0 && brandId !== ANY_BRAND;
  const hasIp = ipId.length > 0 && ipId !== ANY_IP;
  if (!hasBrand && !hasIp) return true;
  return hasBrand || hasIp;
}

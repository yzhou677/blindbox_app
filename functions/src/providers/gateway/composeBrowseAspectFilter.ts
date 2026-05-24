/**
 * eBay Browse aspect filters — precision refinement only.
 *
 * Live API calibration: Brand aspect is unreliable; Character facet is
 * verified-only per taxonomy row. Primary retrieval lives in `q` + category.
 */

import {
  ANY_IP,
  CANONICAL_EBAY_BROWSE_CATEGORY_ID,
  isDiscoverBrowse,
  normalizeBrowseFacetIds,
  resolveVerifiedCharacterAspectValue,
} from './composeBrowseQuery';

export type BrowseAspectPlan = {
  active: boolean;
  categoryIds: string;
  aspectFilter?: string;
  /** Verified Character value (diagnostics). */
  ipCharacterValues?: string[];
};

export function resolveBrowseCategoryId(): string {
  const raw =
    process.env.EBAY_BROWSE_CATEGORY_ID?.trim() ||
    process.env.EBAY_BROWSE_CATEGORY_IDS?.trim();
  if (raw) return raw.split(',')[0]?.trim() || CANONICAL_EBAY_BROWSE_CATEGORY_ID;
  return CANONICAL_EBAY_BROWSE_CATEGORY_ID;
}

export function composeBrowseAspectPlan(input: {
  brandId?: string;
  ipId?: string;
}): BrowseAspectPlan {
  const { brandId, ipId } = normalizeBrowseFacetIds(input);
  const categoryIds = resolveBrowseCategoryId();

  if (isDiscoverBrowse(brandId, ipId)) {
    return { active: false, categoryIds };
  }

  const characterValue =
    ipId !== ANY_IP ? resolveVerifiedCharacterAspectValue(ipId) : undefined;

  if (!characterValue) {
    return { active: false, categoryIds };
  }

  return {
    active: true,
    categoryIds,
    aspectFilter: `categoryId:${categoryIds},Character:{${escapeAspectValue(characterValue)}}`,
    ipCharacterValues: [characterValue],
  };
}

/** @deprecated Franchise facet — ineffective for designer toys; no longer used. */
export function composeBrowseFranchiseAspectPlan(_input: {
  brandId?: string;
  ipId?: string;
}): BrowseAspectPlan | null {
  return null;
}

/** @deprecated Brand aspect — live API shows no meaningful narrowing. */
export function composeBrowseBrandOnlyAspectPlan(
  _brandId: string,
  _ipId?: string,
): BrowseAspectPlan | null {
  return null;
}

function escapeAspectValue(value: string): string {
  return value.replace(/\|/g, '\\|');
}

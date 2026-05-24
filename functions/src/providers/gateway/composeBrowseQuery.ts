/** Curated brand/IP search terms — mirrors Flutter taxonomy registries. */

/** Live-calibrated eBay browse category for designer blind box collectibles. */
export const CANONICAL_EBAY_BROWSE_CATEGORY_ID = '261068';

export type TaxonomyBrand = {
  id: string;
  displayName: string;
  aliases?: string[];
  /** Primary `q` contribution for this brand (live API — Brand aspect is unreliable). */
  ebayBrandQuery?: string;
  /** When IP is Any, override discover fallback (e.g. Dreams Inc → sonny angel blind box). */
  ebayPreferredQueryAnyIp?: string;
  /** Extra normalized title tokens beyond displayName/aliases. */
  titleMatchAliases?: string[];
  /** Alternate q strings validated by audit (first match wins in tooling only). */
  ebayQueryAliases?: string[];
  /** Observed seller naming notes from marketplace audit. */
  observedSellerNaming?: string[];
  titleNoiseRisk?: 'low' | 'medium' | 'high';
  /** @deprecated Brand aspect_filter — retained for title tokens only. */
  ebayAspectBrand?: string;
  /** @deprecated Brand aspect OR — retained for title tokens only. */
  ebayAspectBrands?: string[];
};

export type TaxonomyIp = {
  id: string;
  displayName: string;
  brandId: string;
  aliases: string[];
  ebayCategoryId?: string;
  /** Exact eBay Character facet value — only when [aspectVerified]. */
  ebayCharacterValue?: string;
  /** When true, Character aspect_filter is applied (verified via live refinements). */
  aspectVerified?: boolean;
  /** Overrides default IP keyword in `q` when observed seller naming differs. */
  ebayPreferredQuery?: string;
  /** Extra normalized title-match tokens (spacing/alternate spellings). */
  titleMatchAliases?: string[];
  /** Observed high-frequency seller title tokens (calibration notes). */
  observedSellerNaming?: string[];
  /** q-only | q_and_verified_character | discover | preferred_q */
  retrievalMode?: string;
  /** low | medium | high — accessory/custom collision risk in browse sample */
  titleNoiseRisk?: 'low' | 'medium' | 'high';
  /** Studio line label for title matching (Sonny Angel, Smiski) — not used for aspect_filter. */
  ebayAspectBrand?: string;
};

export const MARKET_TAXONOMY_BRANDS: TaxonomyBrand[] = [
  {
    id: 'pop_mart',
    displayName: 'POP MART',
    aliases: ['POPMART'],
    ebayBrandQuery: 'pop mart',
  },
  {
    id: 'dreams_inc',
    displayName: 'Dreams Inc.',
    aliases: ['DREAMS INC', 'DREAMS'],
    ebayAspectBrands: ['Sonny Angel', 'Smiski'],
    ebayPreferredQueryAnyIp: 'sonny angel blind box',
    observedSellerNaming: ['Sonny Angel', 'Smiski'],
    titleNoiseRisk: 'low',
  },
  {
    id: 'rolife',
    displayName: 'Rolife',
    aliases: ['ROLIFE'],
    ebayBrandQuery: 'rolife',
  },
  {
    id: 'finding_unicorn',
    displayName: 'Finding Unicorn',
    aliases: ['FINDING UNICORN'],
    ebayBrandQuery: 'finding unicorn',
  },
  {
    id: 'tntspace',
    displayName: 'TNT SPACE',
    aliases: ['TNTSPACE'],
    ebayBrandQuery: 'tnt space',
    titleMatchAliases: ['TNTSPACE'],
  },
  {
    id: 'toptoy',
    displayName: 'TOPTOY',
    aliases: ['TOP TOY'],
    ebayBrandQuery: 'toptoy',
    titleMatchAliases: ['TOP TOY'],
  },
  {
    id: 'dpl',
    displayName: 'DPL',
    aliases: ['DPL', 'CUREPLANETA'],
    ebayBrandQuery: 'cureplaneta',
    ebayAspectBrand: 'Cureplaneta',
  },
];

export const MARKET_TAXONOMY_IPS: TaxonomyIp[] = [
  {
    id: 'the_monsters',
    displayName: 'THE MONSTERS',
    brandId: 'pop_mart',
    aliases: ['LABUBU', 'THE MONSTERS'],
    ebayCategoryId: CANONICAL_EBAY_BROWSE_CATEGORY_ID,
    ebayCharacterValue: 'Labubu',
    aspectVerified: true,
  },
  {
    id: 'hirono',
    displayName: 'Hirono',
    brandId: 'pop_mart',
    aliases: ['HIRONO'],
    ebayCategoryId: CANONICAL_EBAY_BROWSE_CATEGORY_ID,
    ebayCharacterValue: 'Hirono',
    aspectVerified: true,
  },
  {
    id: 'skullpanda',
    displayName: 'Skullpanda',
    brandId: 'pop_mart',
    aliases: ['SKULLPANDA'],
    ebayCategoryId: CANONICAL_EBAY_BROWSE_CATEGORY_ID,
    ebayCharacterValue: 'Skullpanda',
    aspectVerified: true,
  },
  {
    id: 'crybaby',
    displayName: 'Crybaby',
    brandId: 'pop_mart',
    aliases: ['CRYBABY'],
    ebayCategoryId: CANONICAL_EBAY_BROWSE_CATEGORY_ID,
    ebayCharacterValue: 'Crybaby',
    aspectVerified: true,
    ebayPreferredQuery: 'Crybaby',
    titleMatchAliases: ['CRY BABY'],
    observedSellerNaming: ['POP MART', 'Crybaby', 'x Crybaby'],
    retrievalMode: 'q_and_verified_character',
    titleNoiseRisk: 'medium',
  },
  {
    id: 'dimoo',
    displayName: 'Dimoo',
    brandId: 'pop_mart',
    aliases: ['DIMOO'],
    ebayCategoryId: CANONICAL_EBAY_BROWSE_CATEGORY_ID,
    aspectVerified: false,
  },
  {
    id: 'molly',
    displayName: 'Molly',
    brandId: 'pop_mart',
    aliases: ['MOLLY'],
    ebayCategoryId: CANONICAL_EBAY_BROWSE_CATEGORY_ID,
    ebayCharacterValue: 'Molly',
    aspectVerified: true,
  },
  {
    id: 'peach_riot',
    displayName: 'Peach Riot',
    brandId: 'pop_mart',
    aliases: ['PEACH RIOT'],
    ebayCategoryId: CANONICAL_EBAY_BROWSE_CATEGORY_ID,
    aspectVerified: false,
  },
  {
    id: 'nyota',
    displayName: 'Nyota',
    brandId: 'pop_mart',
    aliases: ['NYOTA'],
    ebayCategoryId: CANONICAL_EBAY_BROWSE_CATEGORY_ID,
    aspectVerified: false,
  },
  {
    id: 'pucky',
    displayName: 'Pucky',
    brandId: 'pop_mart',
    aliases: ['PUCKY'],
    ebayCategoryId: CANONICAL_EBAY_BROWSE_CATEGORY_ID,
    ebayCharacterValue: 'Pucky',
    aspectVerified: true,
    ebayPreferredQuery: 'Pucky',
    observedSellerNaming: ['POP MART', 'Pucky'],
    retrievalMode: 'q_and_verified_character',
    titleNoiseRisk: 'medium',
  },
  {
    id: 'hacipupu',
    displayName: 'Hacipupu',
    brandId: 'pop_mart',
    aliases: ['HACIPUPU'],
    ebayCategoryId: CANONICAL_EBAY_BROWSE_CATEGORY_ID,
    aspectVerified: false,
  },
  {
    id: 'sweet_bean',
    displayName: 'Sweet Bean',
    brandId: 'pop_mart',
    aliases: ['SWEET BEAN'],
    ebayCategoryId: CANONICAL_EBAY_BROWSE_CATEGORY_ID,
    aspectVerified: false,
  },
  {
    id: 'azura',
    displayName: 'Azura',
    brandId: 'pop_mart',
    aliases: ['AZURA'],
    ebayCategoryId: CANONICAL_EBAY_BROWSE_CATEGORY_ID,
    aspectVerified: false,
  },
  {
    id: 'duckoo',
    displayName: 'Duckoo',
    brandId: 'pop_mart',
    aliases: ['DUCKOO'],
    ebayCategoryId: CANONICAL_EBAY_BROWSE_CATEGORY_ID,
    aspectVerified: false,
  },
  {
    id: 'zsiga',
    displayName: 'Zsiga',
    brandId: 'pop_mart',
    aliases: ['ZSIGA'],
    ebayCategoryId: CANONICAL_EBAY_BROWSE_CATEGORY_ID,
    aspectVerified: false,
  },
  {
    id: 'sonny_angel',
    displayName: 'Sonny Angel',
    brandId: 'dreams_inc',
    aliases: ['SONNY ANGEL', 'SONNYANGEL'],
    ebayAspectBrand: 'Sonny Angel',
    ebayCategoryId: CANONICAL_EBAY_BROWSE_CATEGORY_ID,
    aspectVerified: false,
  },
  {
    id: 'smiski',
    displayName: 'Smiski',
    brandId: 'dreams_inc',
    aliases: ['SMISKI'],
    ebayAspectBrand: 'Smiski',
    ebayCategoryId: CANONICAL_EBAY_BROWSE_CATEGORY_ID,
    aspectVerified: false,
  },
  {
    id: 'nanci',
    displayName: 'Nanci',
    brandId: 'rolife',
    aliases: ['NANCI'],
    ebayCategoryId: CANONICAL_EBAY_BROWSE_CATEGORY_ID,
    aspectVerified: false,
  },
  {
    id: 'zzoton',
    displayName: 'Zzoton',
    brandId: 'finding_unicorn',
    aliases: ['ZZOTON'],
    ebayCategoryId: CANONICAL_EBAY_BROWSE_CATEGORY_ID,
    aspectVerified: false,
  },
  {
    id: 'farmer_bob',
    displayName: 'Farmer Bob',
    brandId: 'finding_unicorn',
    aliases: ['FARMER BOB'],
    ebayCategoryId: CANONICAL_EBAY_BROWSE_CATEGORY_ID,
    aspectVerified: false,
  },
  {
    id: 'rico',
    displayName: 'Rico',
    brandId: 'finding_unicorn',
    aliases: ['RICO'],
    ebayCategoryId: CANONICAL_EBAY_BROWSE_CATEGORY_ID,
    aspectVerified: false,
  },
  {
    id: 'molinta',
    displayName: 'Molinta',
    brandId: 'finding_unicorn',
    aliases: ['MOLINTA'],
    ebayCategoryId: CANONICAL_EBAY_BROWSE_CATEGORY_ID,
    aspectVerified: false,
  },
  {
    id: 'shinwoo',
    displayName: 'Shinwoo',
    brandId: 'finding_unicorn',
    aliases: ['SHINWOO'],
    ebayCategoryId: CANONICAL_EBAY_BROWSE_CATEGORY_ID,
    aspectVerified: false,
  },
  {
    id: 'rayan',
    displayName: 'Rayan',
    brandId: 'tntspace',
    aliases: ['RAYAN'],
    ebayCategoryId: CANONICAL_EBAY_BROWSE_CATEGORY_ID,
    aspectVerified: false,
  },
  {
    id: 'dora',
    displayName: 'Dora',
    brandId: 'tntspace',
    aliases: ['DORA'],
    ebayCategoryId: CANONICAL_EBAY_BROWSE_CATEGORY_ID,
    aspectVerified: false,
    ebayPreferredQuery: 'Dora',
    titleMatchAliases: ['TNTSPACE DORA', 'TNT SPACE DORA'],
    observedSellerNaming: ['TNT SPACE', 'TNTSPACE', 'Dora', 'DORA'],
    retrievalMode: 'q_only',
  },
  {
    id: 'zoraa',
    displayName: 'Zoraa',
    brandId: 'tntspace',
    aliases: ['ZORAA'],
    ebayCategoryId: CANONICAL_EBAY_BROWSE_CATEGORY_ID,
    aspectVerified: false,
  },
  {
    id: 'anmoo',
    displayName: 'Anmoo',
    brandId: 'tntspace',
    aliases: ['ANMOO'],
    ebayCategoryId: CANONICAL_EBAY_BROWSE_CATEGORY_ID,
    aspectVerified: false,
  },
  {
    id: 'liila',
    displayName: 'Liila',
    brandId: 'tntspace',
    aliases: ['LIILA', 'LIITA'],
    ebayCategoryId: CANONICAL_EBAY_BROWSE_CATEGORY_ID,
    aspectVerified: false,
    ebayPreferredQuery: 'Liita',
    titleMatchAliases: ['LIILA', 'LIITA'],
    observedSellerNaming: ['Liita', 'Liila', 'TNT SPACE', 'TNTSPACE'],
    retrievalMode: 'q_only',
    titleNoiseRisk: 'high',
  },
  {
    id: 'nommi',
    displayName: 'Nommi',
    brandId: 'toptoy',
    aliases: ['NOMMI'],
    ebayCategoryId: CANONICAL_EBAY_BROWSE_CATEGORY_ID,
    aspectVerified: false,
    ebayPreferredQuery: 'Nommi',
  },
  {
    id: 'maymei',
    displayName: 'Maymei',
    brandId: 'toptoy',
    aliases: ['MAYMEI'],
    ebayCategoryId: CANONICAL_EBAY_BROWSE_CATEGORY_ID,
    aspectVerified: false,
    ebayPreferredQuery: 'Maymei',
    titleMatchAliases: ['MAY MEI', 'TOPTOY'],
    observedSellerNaming: ['Maymei', 'TOPTOY', 'TopToy', 'Top Toy'],
    retrievalMode: 'q_only',
  },
  {
    id: 'baby_three',
    displayName: 'Baby Three',
    brandId: 'dpl',
    aliases: ['BABY THREE', 'BABYTHREE'],
    ebayCategoryId: CANONICAL_EBAY_BROWSE_CATEGORY_ID,
    aspectVerified: false,
  },
];

export const ANY_BRAND = 'any_brand';
export const ANY_IP = 'any_ip';

/** Brands hidden from filter chips — excluded from Any-brand OR discover feed. */
export const MARKET_HIDDEN_BROWSE_BRAND_IDS = new Set(['finding_unicorn']);

/** Neutral Any-brand browse keywords — category 261068, no Brand aspect OR. */
export const DISCOVER_BROWSE_Q =
  process.env.EBAY_DISCOVER_QUERY?.trim() || 'blind box vinyl figure';

export function normalizeBrowseFacetIds(input: {
  brandId?: string;
  ipId?: string;
}): { brandId: string; ipId: string } {
  const brandId = (input.brandId ?? '').trim() || ANY_BRAND;
  const ipId = (input.ipId ?? '').trim() || ANY_IP;
  return { brandId, ipId };
}

export function isDiscoverBrowse(brandId: string, ipId: string): boolean {
  return brandId === ANY_BRAND && ipId === ANY_IP;
}

export function findTaxonomyIp(ipId: string): TaxonomyIp | undefined {
  return MARKET_TAXONOMY_IPS.find((row) => row.id === ipId);
}

export function ipHasVerifiedCharacterAspect(ipId: string): boolean {
  const ip = findTaxonomyIp(ipId);
  return Boolean(ip?.aspectVerified && ip.ebayCharacterValue?.trim());
}

export function resolveVerifiedCharacterAspectValue(
  ipId: string,
): string | undefined {
  const ip = findTaxonomyIp(ipId);
  if (!ip?.aspectVerified) return undefined;
  const value = ip.ebayCharacterValue?.trim();
  return value || undefined;
}

function primaryIpAlias(ip: TaxonomyIp): string {
  for (const alias of ip.aliases) {
    if (alias.toUpperCase() !== ip.displayName.toUpperCase()) return alias;
  }
  return ip.displayName;
}

function brandSearchTerm(brandId: string): string | undefined {
  const brand = MARKET_TAXONOMY_BRANDS.find((b) => b.id === brandId);
  if (!brand) return undefined;
  const q = brand.ebayBrandQuery?.trim();
  return q || undefined;
}

function ipSearchTerm(ipId: string): string | undefined {
  const ip = findTaxonomyIp(ipId);
  return ip ? primaryIpAlias(ip) : undefined;
}

/** Exported for Tier 2 keyword supplement — prefers spaced aliases for eBay `q`. */
export function ipKeywordTerm(ipId: string): string | undefined {
  const ip = findTaxonomyIp(ipId);
  if (!ip) return undefined;
  const candidates = [...ip.aliases, ip.displayName].map((v) => v.trim()).filter(Boolean);
  const spaced = candidates.filter((value) => value.includes(' '));
  if (spaced.length > 0) {
    return spaced.sort((a, b) => b.length - a.length)[0];
  }
  return ipSearchTerm(ipId);
}

const COLLECTIBLE_SEARCH_CONTEXT_PHRASES = [
  'blind box',
  'blind-box',
  'mystery box',
  'vinyl figure',
  'designer toy',
  'art toy',
  'sealed blind',
  'pop mart',
  'popmart',
];

let cachedTaxonomyNativeSearchPhrases: string[] | undefined;

function normalizeSearchText(raw: string): string {
  return raw.trim().toLowerCase().replace(/\s+/g, ' ');
}

function collectTaxonomyNativeSearchPhrases(): string[] {
  if (cachedTaxonomyNativeSearchPhrases) return cachedTaxonomyNativeSearchPhrases;

  const raw: string[] = [];
  const push = (value: string | undefined) => {
    const norm = normalizeSearchText(value ?? '');
    if (norm.length > 0) raw.push(norm);
  };

  for (const brand of MARKET_TAXONOMY_BRANDS) {
    push(brand.displayName);
    for (const alias of brand.aliases ?? []) push(alias);
    push(brand.ebayBrandQuery);
    push(brand.ebayPreferredQueryAnyIp);
    for (const alias of brand.titleMatchAliases ?? []) push(alias);
    for (const aspect of brand.ebayAspectBrands ?? []) push(aspect);
  }

  for (const ip of MARKET_TAXONOMY_IPS) {
    push(ip.displayName);
    for (const alias of ip.aliases ?? []) push(alias);
    push(ip.ebayCharacterValue);
    push(ip.ebayPreferredQuery);
    push(ip.ebayAspectBrand);
    for (const alias of ip.titleMatchAliases ?? []) push(alias);
  }

  cachedTaxonomyNativeSearchPhrases = [...new Set(raw)].sort(
    (a, b) => b.length - a.length,
  );
  return cachedTaxonomyNativeSearchPhrases;
}

function escapeRegExp(value: string): string {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function searchContainsPhrase(norm: string, phrase: string): boolean {
  if (phrase.includes(' ')) return norm.includes(phrase);
  if (norm === phrase) return true;
  return new RegExp(`\\b${escapeRegExp(phrase)}\\b`, 'i').test(norm);
}

export function searchContainsCollectibleContext(search: string): boolean {
  const norm = normalizeSearchText(search);
  if (!norm) return false;
  if (norm === normalizeSearchText(DISCOVER_BROWSE_Q)) return true;
  return COLLECTIBLE_SEARCH_CONTEXT_PHRASES.some((phrase) =>
    searchContainsPhrase(norm, phrase),
  );
}

export function isCollectibleNativeSearch(search: string): boolean {
  const norm = normalizeSearchText(search);
  if (!norm) return false;
  return collectTaxonomyNativeSearchPhrases().some((phrase) =>
    searchContainsPhrase(norm, phrase),
  );
}

/** Whether discover browse should prepend [DISCOVER_BROWSE_Q] to user search. */
export function shouldAnchorDiscoverSearch(
  search: string,
  brandId: string,
  ipId: string,
): boolean {
  const trimmed = search.trim();
  if (!trimmed) return false;
  if (!isDiscoverBrowse(brandId, ipId)) return false;
  if (isCollectibleNativeSearch(trimmed)) return false;
  if (searchContainsCollectibleContext(trimmed)) return false;
  return true;
}

export function resolveSearchTextForBrowse(input: {
  searchText: string;
  brandId?: string;
  ipId?: string;
}): string {
  const trimmed = input.searchText.trim();
  if (!trimmed) return trimmed;

  const { brandId, ipId } = normalizeBrowseFacetIds(input);
  if (shouldAnchorDiscoverSearch(trimmed, brandId, ipId)) {
    return `${DISCOVER_BROWSE_Q} ${trimmed}`;
  }
  return trimmed;
}

/** @internal test helper */
export function resetSearchAnchorCacheForTests(): void {
  cachedTaxonomyNativeSearchPhrases = undefined;
}

/**
 * Builds upstream `q` — primary retrieval intent.
 * Verified Character IPs omit IP keywords (aspect refinement handles precision).
 */
export function composeBrowseUpstreamQ(input: {
  brandId?: string;
  ipId?: string;
  searchText?: string;
  qOverride?: string;
}): string {
  const override = input.qOverride?.trim();
  if (override) return override;

  const search = (input.searchText ?? '').trim();
  const { brandId, ipId } = normalizeBrowseFacetIds(input);

  const terms: string[] = [];

  if (brandId !== ANY_BRAND && ipId === ANY_IP) {
    const brand = MARKET_TAXONOMY_BRANDS.find((b) => b.id === brandId);
    const anyIpQ = brand?.ebayPreferredQueryAnyIp?.trim();
    if (anyIpQ) terms.push(anyIpQ);
    else {
      const brandTerm = brandSearchTerm(brandId);
      if (brandTerm) terms.push(brandTerm);
    }
  } else if (brandId !== ANY_BRAND) {
    const brandTerm = brandSearchTerm(brandId);
    if (brandTerm) terms.push(brandTerm);
  }

  if (ipId !== ANY_IP && !ipHasVerifiedCharacterAspect(ipId)) {
    const ip = findTaxonomyIp(ipId);
    const ipTerm =
      ip?.ebayPreferredQuery?.trim() || ipKeywordTerm(ipId) || ipSearchTerm(ipId);
    if (ipTerm) terms.push(ipTerm);
  } else if (ipId !== ANY_IP && ipHasVerifiedCharacterAspect(ipId)) {
    // Verified Character facet — optional q supplement when audit shows sparse samples.
    const supplement = findTaxonomyIp(ipId)?.ebayPreferredQuery?.trim();
    if (supplement) terms.push(supplement);
  }

  if (search) {
    terms.push(
      resolveSearchTextForBrowse({ searchText: search, brandId, ipId }),
    );
  }

  if (terms.length === 0) {
    if (isDiscoverBrowse(brandId, ipId)) return DISCOVER_BROWSE_Q;
    return (
      process.env.EBAY_DEFAULT_QUERY?.trim() ||
      DISCOVER_BROWSE_Q
    );
  }
  return terms.join(' ');
}

export function browseQuerySignature(input: {
  brandId?: string;
  ipId?: string;
  searchText?: string;
  sort?: string;
}): string {
  const brandId = (input.brandId ?? ANY_BRAND).trim();
  const ipId = (input.ipId ?? ANY_IP).trim();
  const search = (input.searchText ?? '').trim().toLowerCase();
  const sort = (input.sort ?? 'relevance').trim();
  return `${brandId}|${ipId}|${search}|${sort}`;
}

/** Curated brand/IP search terms — mirrors Flutter taxonomy registries. */

export type TaxonomyBrand = {
  id: string;
  displayName: string;
  aliases?: string[];
  /** Single eBay item-aspect Brand value (e.g. DPL → Cureplaneta). */
  ebayAspectBrand?: string;
  /** OR-list of eBay Brand aspects for studio labels (e.g. Dreams Inc. → Sonny Angel | Smiski). */
  ebayAspectBrands?: string[];
};

export type TaxonomyIp = {
  id: string;
  displayName: string;
  brandId: string;
  aliases: string[];
  /** When the IP line is the eBay Brand aspect (Sonny Angel, Smiski), not Character. */
  ebayAspectBrand?: string;
};

export const MARKET_TAXONOMY_BRANDS: TaxonomyBrand[] = [
  { id: 'pop_mart', displayName: 'POP MART', aliases: ['POPMART'] },
  { id: 'dreams_inc', displayName: 'Dreams Inc.', aliases: ['DREAMS INC', 'DREAMS'], ebayAspectBrands: ['Sonny Angel', 'Smiski'] },
  { id: 'rolife', displayName: 'Rolife', aliases: ['ROLIFE'] },
  { id: 'finding_unicorn', displayName: 'Finding Unicorn', aliases: ['FINDING UNICORN'] },
  { id: 'tntspace', displayName: 'TNT SPACE', aliases: ['TNTSPACE'] },
  { id: 'toptoy', displayName: 'TOPTOY', aliases: ['TOP TOY'] },
  {
    id: 'dpl',
    displayName: 'DPL',
    aliases: ['DPL', 'CUREPLANETA'],
    ebayAspectBrand: 'Cureplaneta',
  },
];

export const MARKET_TAXONOMY_IPS: TaxonomyIp[] = [
  {
    id: 'the_monsters',
    displayName: 'THE MONSTERS',
    brandId: 'pop_mart',
    aliases: ['LABUBU', 'THE MONSTERS'],
  },
  { id: 'hirono', displayName: 'Hirono', brandId: 'pop_mart', aliases: ['HIRONO'] },
  {
    id: 'skullpanda',
    displayName: 'Skullpanda',
    brandId: 'pop_mart',
    aliases: ['SKULLPANDA'],
  },
  { id: 'crybaby', displayName: 'Crybaby', brandId: 'pop_mart', aliases: ['CRYBABY'] },
  { id: 'dimoo', displayName: 'Dimoo', brandId: 'pop_mart', aliases: ['DIMOO'] },
  { id: 'molly', displayName: 'Molly', brandId: 'pop_mart', aliases: ['MOLLY'] },
  {
    id: 'peach_riot',
    displayName: 'Peach Riot',
    brandId: 'pop_mart',
    aliases: ['PEACH RIOT'],
  },
  { id: 'nyota', displayName: 'Nyota', brandId: 'pop_mart', aliases: ['NYOTA'] },
  { id: 'pucky', displayName: 'Pucky', brandId: 'pop_mart', aliases: ['PUCKY'] },
  {
    id: 'hacipupu',
    displayName: 'Hacipupu',
    brandId: 'pop_mart',
    aliases: ['HACIPUPU'],
  },
  {
    id: 'sweet_bean',
    displayName: 'Sweet Bean',
    brandId: 'pop_mart',
    aliases: ['SWEET BEAN'],
  },
  { id: 'azura', displayName: 'Azura', brandId: 'pop_mart', aliases: ['AZURA'] },
  { id: 'duckoo', displayName: 'Duckoo', brandId: 'pop_mart', aliases: ['DUCKOO'] },
  { id: 'zsiga', displayName: 'Zsiga', brandId: 'pop_mart', aliases: ['ZSIGA'] },
  {
    id: 'sonny_angel',
    displayName: 'Sonny Angel',
    brandId: 'dreams_inc',
    aliases: ['SONNY ANGEL', 'SONNYANGEL'],
    ebayAspectBrand: 'Sonny Angel',
  },
  {
    id: 'smiski',
    displayName: 'Smiski',
    brandId: 'dreams_inc',
    aliases: ['SMISKI'],
    ebayAspectBrand: 'Smiski',
  },
  { id: 'nanci', displayName: 'Nanci', brandId: 'rolife', aliases: ['NANCI'] },
  {
    id: 'zzoton',
    displayName: 'Zzoton',
    brandId: 'finding_unicorn',
    aliases: ['ZZOTON'],
  },
  {
    id: 'farmer_bob',
    displayName: 'Farmer Bob',
    brandId: 'finding_unicorn',
    aliases: ['FARMER BOB'],
  },
  { id: 'rayan', displayName: 'Rayan', brandId: 'tntspace', aliases: ['RAYAN'] },
  { id: 'nommi', displayName: 'Nommi', brandId: 'toptoy', aliases: ['NOMMI'] },
  {
    id: 'baby_three',
    displayName: 'Baby Three',
    brandId: 'dpl',
    aliases: ['BABY THREE', 'BABYTHREE'],
  },
];

export const ANY_BRAND = 'any_brand';
export const ANY_IP = 'any_ip';

/** Brands hidden from filter chips — excluded from Any-brand OR discover feed. */
export const MARKET_HIDDEN_BROWSE_BRAND_IDS = new Set(['finding_unicorn']);

function primaryIpAlias(ip: TaxonomyIp): string {
  for (const alias of ip.aliases) {
    if (alias.toUpperCase() !== ip.displayName.toUpperCase()) return alias;
  }
  return ip.displayName;
}

function brandSearchTerm(brandId: string): string | undefined {
  return MARKET_TAXONOMY_BRANDS.find((b) => b.id === brandId)?.displayName;
}

function ipSearchTerm(ipId: string): string | undefined {
  const ip = MARKET_TAXONOMY_IPS.find((row) => row.id === ipId);
  return ip ? primaryIpAlias(ip) : undefined;
}

/** Exported for Tier 2 keyword supplement — prefers spaced aliases for eBay `q`. */
export function ipKeywordTerm(ipId: string): string | undefined {
  const ip = MARKET_TAXONOMY_IPS.find((row) => row.id === ipId);
  if (!ip) return undefined;
  const candidates = [...ip.aliases, ip.displayName].map((v) => v.trim()).filter(Boolean);
  const spaced = candidates.filter((value) => value.includes(' '));
  if (spaced.length > 0) {
    return spaced.sort((a, b) => b.length - a.length)[0];
  }
  return ipSearchTerm(ipId);
}

function shouldUseAspectFacets(input: {
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

export function composeBrowseUpstreamQ(input: {
  brandId?: string;
  ipId?: string;
  searchText?: string;
  qOverride?: string;
}): string {
  const override = input.qOverride?.trim();
  if (override) return override;

  const search = (input.searchText ?? '').trim();
  if (shouldUseAspectFacets(input)) {
    return search;
  }

  const terms: string[] = [];
  const brandId = (input.brandId ?? ANY_BRAND).trim();
  const ipId = (input.ipId ?? ANY_IP).trim();

  if (brandId && brandId !== ANY_BRAND) {
    const brandTerm = brandSearchTerm(brandId);
    if (brandTerm) terms.push(brandTerm);
  }
  if (ipId && ipId !== ANY_IP) {
    const ipTerm = ipSearchTerm(ipId);
    if (ipTerm) terms.push(ipTerm);
  }
  if (search) terms.push(search);

  if (terms.length === 0) {
    return (
      process.env.EBAY_DEFAULT_QUERY?.trim() ||
      process.env.MERCARI_DEFAULT_QUERY?.trim() ||
      'designer vinyl blind box figure'
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

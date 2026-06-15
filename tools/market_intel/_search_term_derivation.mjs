/**
 * Market Intelligence — search term derivation.
 *
 * Implements SEARCH_TERM_DERIVATION_DESIGN.md (Sprint 2 Step 3B).
 * Pure functions only — no I/O, network, or side effects.
 */

export const AUTO_MAX_TERMS = 4;
export const OVERRIDE_MAX_TERMS = 6;
export const MAX_ALIAS_TERMS = 2;

const TRAILING_BOILERPLATE_PATTERN =
  /\s*(?:Series(?:\s*[-–])?.*|Blind Box.*|Vinyl Plush.*|Pendant.*|Figures.*|Doll.*|Plush.*)$/i;

const LEADING_IP_PREFIX_PATTERNS = [
  /^THE MONSTERS\s*[-–]?\s*/i,
  /^SKULLPANDA\s*[-–]?\s*/i,
  /^PUCKY\s*[-–]?\s*/i,
  /^DIMOO\s*[-–]?\s*/i,
  /^CRYBABY\s*[-–]?\s*/i,
  /^TWINKLE TWINKLE\s*[-–]?\s*/i,
  /^MOLLY\s*[-–]?\s*/i,
  /^HIRONO\s*[-–]?\s*/i,
  /^ZSIGA\s*[-–]?\s*/i,
];

function escapeRegExp(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function normalizeTerm(term) {
  return String(term ?? '')
    .trim()
    .replace(/\s+/g, ' ');
}

function dedupePreserveOrder(terms) {
  const seen = new Set();
  const result = [];

  for (const term of terms) {
    const cleaned = normalizeTerm(term);
    if (!cleaned) {
      continue;
    }

    const key = cleaned.toLowerCase();
    if (seen.has(key)) {
      continue;
    }

    seen.add(key);
    result.push(cleaned);
  }

  return result;
}

function buildBrandTokens(brand) {
  if (!brand?.displayName) {
    return [];
  }

  const tokens = [brand.displayName];
  for (const alias of brand.aliases ?? []) {
    tokens.push(alias);
  }

  return dedupePreserveOrder(tokens);
}

export function resolveIpToken(ip) {
  if (!ip) {
    return '';
  }

  const firstAlias = ip.aliases?.[0];
  if (firstAlias) {
    return normalizeTerm(firstAlias);
  }

  return normalizeTerm(ip.displayName);
}

function stripSeriesBoilerplate(text) {
  let result = normalizeTerm(text);
  result = result.replace(TRAILING_BOILERPLATE_PATTERN, '');
  result = result.replace(/[-–]\s*$/, '').trim();
  return result;
}

function stripLeadingIpPrefix(text, ip) {
  let result = normalizeTerm(text);

  if (ip?.displayName) {
    const ipPattern = new RegExp(
      `^\\s*${escapeRegExp(ip.displayName)}\\s*[-–]?\\s*`,
      'i',
    );
    result = result.replace(ipPattern, '');
  }

  for (const pattern of LEADING_IP_PREFIX_PATTERNS) {
    result = result.replace(pattern, '');
  }

  return result.trim();
}

/**
 * @param {{ displayName?: string, aliases?: string[] }} series
 * @param {{ displayName?: string, aliases?: string[] } | null | undefined} ip
 */
export function extractSeriesDistinctive(series, ip) {
  if (!series?.displayName) {
    return '';
  }

  let distinctive = stripSeriesBoilerplate(
    stripLeadingIpPrefix(series.displayName, ip),
  );

  if (distinctive.length >= 3) {
    return distinctive;
  }

  const aliasCandidates = [...(series.aliases ?? [])]
    .map((alias) => stripSeriesBoilerplate(stripLeadingIpPrefix(alias, ip)))
    .filter((alias) => alias.length >= 3)
    .sort((left, right) => right.length - left.length);

  return aliasCandidates[0] ?? distinctive;
}

function assembleTerm(parts) {
  return normalizeTerm(parts.filter(Boolean).join(' '));
}

function collectAliasFigureNames(figure, metadata) {
  const primary = normalizeTerm(figure?.displayName);
  const aliases = [];

  for (const alias of figure?.aliases ?? []) {
    aliases.push(alias);
  }

  for (const alias of metadata?.marketAliases ?? []) {
    aliases.push(alias);
  }

  return dedupePreserveOrder(aliases).filter(
    (alias) => alias.toLowerCase() !== primary.toLowerCase(),
  );
}

/**
 * @param {{
 *   displayName?: string,
 *   isSecret?: boolean,
 *   aliases?: string[],
 * }} figure
 * @param {{
 *   brand?: { displayName?: string, aliases?: string[] },
 *   ip?: { displayName?: string, aliases?: string[] },
 *   series?: { displayName?: string, aliases?: string[] },
 * }} catalogContext
 * @param {{
 *   disabled?: boolean,
 *   searchTerms?: string[],
 *   marketAliases?: string[],
 * } | null | undefined} metadata
 * @returns {string[]}
 */
export function deriveSearchTerms(figure, catalogContext, metadata = {}) {
  const resolvedMetadata = metadata ?? {};

  if (resolvedMetadata.disabled === true) {
    return [];
  }

  const overrideTerms = resolvedMetadata.searchTerms ?? [];
  if (overrideTerms.length > 0) {
    return dedupePreserveOrder(overrideTerms).slice(0, OVERRIDE_MAX_TERMS);
  }

  const brand = catalogContext?.brand;
  const ip = catalogContext?.ip;
  const series = catalogContext?.series;
  const primaryFigureName = normalizeTerm(figure?.displayName);

  if (!primaryFigureName || !brand?.displayName || !series?.displayName) {
    return [];
  }

  const brandTokens = buildBrandTokens(brand);
  const ipToken = resolveIpToken(ip);
  const seriesDistinctive = extractSeriesDistinctive(series, ip);

  if (!ipToken || !seriesDistinctive) {
    return [];
  }

  const primaryBrandToken = brandTokens[0];
  const aliasFigureNames = collectAliasFigureNames(
    figure,
    resolvedMetadata,
  ).slice(0, MAX_ALIAS_TERMS);

  const terms = [];

  for (const brandToken of brandTokens) {
    terms.push(
      assembleTerm([
        brandToken,
        ipToken,
        seriesDistinctive,
        primaryFigureName,
      ]),
    );
  }

  for (const aliasFigureName of aliasFigureNames) {
    terms.push(
      assembleTerm([
        primaryBrandToken,
        ipToken,
        seriesDistinctive,
        aliasFigureName,
      ]),
    );
  }

  if (figure?.isSecret === true && primaryFigureName.length <= 4) {
    terms.push(
      assembleTerm([
        primaryBrandToken,
        ipToken,
        seriesDistinctive,
        primaryFigureName,
        'secret',
      ]),
    );
  }

  return dedupePreserveOrder(terms).slice(0, AUTO_MAX_TERMS);
}

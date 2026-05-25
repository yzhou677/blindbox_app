/**
 * Validates curated official-feed seed JSON before Firestore push.
 * Phase 1: POP MART US only — no scraping, quality gates at push time.
 */

const POPMART_PLACEHOLDER_IMAGES = [
  /\/images\/192\.png/i,
  /favicon\.ico/i,
  /\/images\/logo/i,
];

const HOMEPAGE_PATHS = new Set(['/us', '']);

/**
 * @param {string} raw
 * @returns {URL|null}
 */
export function parseHttpsUrl(raw) {
  if (typeof raw !== 'string' || !raw.trim()) return null;
  try {
    const url = new URL(raw.trim());
    if (url.protocol !== 'https:') return null;
    return url;
  } catch {
    return null;
  }
}

/**
 * @param {string} imageUrl
 */
export function isPlaceholderImageUrl(imageUrl) {
  return POPMART_PLACEHOLDER_IMAGES.some((re) => re.test(imageUrl));
}

/**
 * POP MART US item link must be deeper than the storefront home.
 * @param {URL} url
 */
export function isPopMartUsItemUrl(url) {
  if (!url.hostname.endsWith('popmart.com')) return false;
  const path = url.pathname.replace(/\/+$/, '') || '/';
  if (HOMEPAGE_PATHS.has(path) || path === '/us') return false;
  if (!path.startsWith('/us/')) return false;

  if (path.startsWith('/us/products/')) {
    const rest = path.slice('/us/products/'.length);
    return rest.length > 0 && rest !== '/';
  }
  if (path.startsWith('/us/pop-now/')) {
    const rest = path.slice('/us/pop-now/'.length);
    return rest.length > 0;
  }
  if (path.startsWith('/us/collection/')) {
    return /^\/us\/collection\/\d+/.test(path);
  }
  return false;
}

/**
 * @param {unknown} seed
 * @returns {{ ok: boolean, errors: string[], warnings: string[] }}
 */
export function validateOfficialFeedSeed(seed) {
  const errors = [];
  const warnings = [];

  const sourceId = seed?.sourceId?.trim();
  if (!sourceId) errors.push('Missing sourceId.');
  if (sourceId && sourceId !== 'popmart_us') {
    warnings.push(`Unexpected sourceId "${sourceId}" (Phase 1 expects popmart_us).`);
  }

  const items = seed?.items;
  if (!Array.isArray(items) || items.length === 0) {
    errors.push('items must be a non-empty array.');
    return { ok: false, errors, warnings };
  }

  const seenIds = new Set();
  const seenOfficial = new Set();
  const seenImages = new Set();

  for (let i = 0; i < items.length; i++) {
    const item = items[i];
    const label = `items[${i}]`;

    const id = item?.id?.trim();
    const title = item?.title?.trim();
    const imageUrl = item?.imageUrl?.trim();
    const officialUrl = item?.officialUrl?.trim();
    const publishedAt = item?.publishedAt?.trim();
    const status = item?.status?.trim() ?? 'active';

    if (!id) errors.push(`${label}: missing id.`);
    else if (seenIds.has(id)) errors.push(`${label}: duplicate id "${id}".`);
    else seenIds.add(id);

    if (!title) errors.push(`${label}: missing title.`);

    const imageParsed = parseHttpsUrl(imageUrl);
    if (!imageParsed) errors.push(`${label}: imageUrl must be a valid https URL.`);
    else {
      if (isPlaceholderImageUrl(imageUrl)) {
        errors.push(`${label}: imageUrl is a brand placeholder (${imageUrl}).`);
      }
      if (seenImages.has(imageUrl)) {
        errors.push(`${label}: duplicate imageUrl across items.`);
      } else seenImages.add(imageUrl);
      if (!imageParsed.hostname.includes('popmart.com')) {
        warnings.push(
          `${label}: imageUrl is not on popmart CDN — prefer product art from popmart.com DevTools when possible.`,
        );
      }
    }

    const officialParsed = parseHttpsUrl(officialUrl);
    if (!officialParsed) {
      errors.push(`${label}: officialUrl must be a valid https URL.`);
    } else {
      if (!isPopMartUsItemUrl(officialParsed)) {
        errors.push(
          `${label}: officialUrl must be a POP MART US product, POP NOW set, or collection page — not the homepage (${officialUrl}).`,
        );
      }
      if (seenOfficial.has(officialUrl)) {
        errors.push(`${label}: duplicate officialUrl across items.`);
      } else seenOfficial.add(officialUrl);
    }

    if (!publishedAt || Number.isNaN(Date.parse(publishedAt))) {
      errors.push(`${label}: publishedAt must be ISO-8601 UTC.`);
    }

    if (status !== 'active') {
      warnings.push(`${label}: status is "${status}" (push still writes it; app hides non-active).`);
    }
  }

  return { ok: errors.length === 0, errors, warnings };
}

/**
 * Validates curated official-feed seed JSON before Firestore push.
 * Phase 1: POP MART US only — no scraping, quality gates at push time.
 */

const POPMART_PLACEHOLDER_IMAGES = [
  /\/images\/192\.png/i,
  /favicon\.ico/i,
  /\/images\/logo/i,
];

/** Seed-only override; never written to Firestore. */
export const CURATION_OVERRIDE_RESELLER = 'reseller_image_ok';

/** Seed-only flag: curator verified numeric productId in a hydrated browser session. */
export const PRODUCT_ID_CONFIRMED_FIELD = 'productIdConfirmed';

const HOMEPAGE_PATHS = new Set(['/us', '']);

/** Instagram/carousel batch slide filenames (A_, B_, C_, …). */
const BATCH_CAROUSEL_IMAGE_PATH = /\/files\/[A-Z]_/i;

const SUSPICIOUS_PROMO_FILENAME = /(?:banner|promo|collage|lineup|whole-set|instagram|reel|launch-post)/i;

/** Third-party retailer CDN hosts — ERROR unless curationOverride is set. */
const RESELLER_IMAGE_HOSTS = new Set([
  'whoopea.com',
  'www.whoopea.com',
  'toysez.com',
  'www.toysez.com',
  'myfunboxs.com',
  'www.myfunboxs.com',
  'cooldragonhobby.ca',
  'www.cooldragonhobby.ca',
  'mynekoshop.com',
  'www.mynekoshop.com',
  'littlemysteries.store',
  'www.littlemysteries.store',
  'hobbiesville.com',
  'www.hobbiesville.com',
  'ttmartglobal.com',
  'www.ttmartglobal.com',
  'labubushopuk.com',
  'www.labubushopuk.com',
  'shumistore.com',
  'www.shumistore.com',
]);

/** POP MART US Shopify store paths (ambiguous — warn, not error). */
const SHOPIFY_OFFICIAL_STORE_PATHS = [
  '/s/files/1/0737/5506/6686/',
  '/s/files/1/0709/9449/3615/',
];

const MONTH_NAME_TO_INDEX = {
  jan: 0,
  january: 0,
  feb: 1,
  february: 1,
  mar: 2,
  march: 2,
  apr: 3,
  april: 3,
  may: 4,
  jun: 5,
  june: 5,
  jul: 6,
  july: 6,
  aug: 7,
  august: 7,
  sep: 8,
  sept: 8,
  september: 8,
  oct: 9,
  october: 9,
  nov: 10,
  november: 10,
  dec: 11,
  december: 11,
};

/** US online drops at 7 PM PT often land on the next UTC calendar day. */
export const SUMMARY_PUBLISHED_AT_MAX_DAY_DRIFT = 1;

const SUMMARY_RELEASE_DATE_RE =
  /\b(january|jan|february|feb|march|mar|april|apr|may|june|jun|july|jul|august|aug|september|sept|sep|october|oct|november|nov|december|dec)\s+(\d{1,2})\b/i;

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
 * @param {unknown} item
 */
export function hasResellerImageOverride(item) {
  return item?.curationOverride?.trim() === CURATION_OVERRIDE_RESELLER;
}

/**
 * @param {unknown} item
 */
export function hasProductIdConfirmed(item) {
  return item?.[PRODUCT_ID_CONFIRMED_FIELD] === true;
}

/**
 * @param {string} officialUrl
 * @returns {string|null}
 */
export function productIdFromOfficialUrl(officialUrl) {
  const parsed = parseHttpsUrl(officialUrl);
  if (!parsed?.pathname.startsWith('/us/products/')) return null;
  return parsed.pathname.match(/^\/us\/products\/(\d+)/)?.[1] ?? null;
}

/**
 * Seed item ids should end with `_{productId}` so wrong ids are obvious in review.
 * @param {string} id
 * @param {string} productId
 */
export function itemIdEndsWithProductId(id, productId) {
  if (!id?.trim() || !productId?.trim()) return false;
  return id.trim().endsWith(`_${productId.trim()}`);
}

/**
 * @param {string} summary
 * @param {number} [year]
 * @returns {{ month: number, day: number }|null}
 */
export function parseSummaryReleaseDate(summary, year = new Date().getUTCFullYear()) {
  if (!summary?.trim()) return null;
  const match = summary.trim().match(SUMMARY_RELEASE_DATE_RE);
  if (!match) return null;
  const month = MONTH_NAME_TO_INDEX[match[1].toLowerCase()];
  const day = Number.parseInt(match[2], 10);
  if (month == null || !Number.isFinite(day) || day < 1 || day > 31) return null;
  return { month, day, year };
}

/**
 * Soft consistency only — cannot prove the official US release date.
 * @param {string} summary
 * @param {string} publishedAt
 */
export function summaryPublishedAtDateDriftDays(summary, publishedAt) {
  const parsed = parseSummaryReleaseDate(
    summary,
    new Date(publishedAt).getUTCFullYear(),
  );
  if (!parsed) return null;
  const pub = new Date(publishedAt);
  const summaryUtc = Date.UTC(parsed.year, parsed.month, parsed.day);
  const publishedUtc = Date.UTC(
    pub.getUTCFullYear(),
    pub.getUTCMonth(),
    pub.getUTCDate(),
  );
  return Math.round(Math.abs(summaryUtc - publishedUtc) / 86_400_000);
}

/**
 * @param {string} imageUrl
 */
export function isBatchCarouselImageUrl(imageUrl) {
  try {
    return BATCH_CAROUSEL_IMAGE_PATH.test(new URL(imageUrl).pathname);
  } catch {
    return BATCH_CAROUSEL_IMAGE_PATH.test(imageUrl);
  }
}

/**
 * @param {string} imageUrl
 */
export function isSuspiciousPromoFilename(imageUrl) {
  try {
    return SUSPICIOUS_PROMO_FILENAME.test(new URL(imageUrl).pathname);
  } catch {
    return SUSPICIOUS_PROMO_FILENAME.test(imageUrl);
  }
}

/**
 * @param {string} hostname
 */
export function isResellerImageHost(hostname) {
  return RESELLER_IMAGE_HOSTS.has(hostname.toLowerCase());
}

/**
 * @param {string} hostname
 */
export function isOfficialPopMartImageHost(hostname) {
  const h = hostname.toLowerCase();
  return h.endsWith('popmart.com');
}

/**
 * @param {string} imageUrl
 * @returns {'official'|'shopify_official'|'reseller'|'other'}
 */
export function imageHostTier(imageUrl) {
  const parsed = parseHttpsUrl(imageUrl);
  if (!parsed) return 'other';
  const host = parsed.hostname.toLowerCase();
  if (isOfficialPopMartImageHost(host)) return 'official';
  if (isResellerImageHost(host)) return 'reseller';
  if (
    host === 'cdn.shopify.com' &&
    SHOPIFY_OFFICIAL_STORE_PATHS.some((p) => parsed.pathname.includes(p))
  ) {
    return 'shopify_official';
  }
  return 'other';
}

/** First segment after `/us/products/` must be numeric spuId (not a title slug). */
export function isPopMartUsNumericProductUrl(url) {
  if (!url.hostname.endsWith('popmart.com')) return false;
  const match = url.pathname.match(/^\/us\/products\/([^/]+)/);
  if (!match) return false;
  return /^\d+$/.test(match[1]);
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
    return isPopMartUsNumericProductUrl(url);
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

    const overrideRaw = item?.curationOverride?.trim();
    if (overrideRaw && overrideRaw !== CURATION_OVERRIDE_RESELLER) {
      errors.push(
        `${label}: unknown curationOverride "${overrideRaw}" (allowed: "${CURATION_OVERRIDE_RESELLER}").`,
      );
    }

    const summary = item?.summary?.trim();
    if (summary && summary.length > 80) {
      warnings.push(`${label}: summary exceeds ~80 chars (${summary.length}).`);
    }

    const imageParsed = parseHttpsUrl(imageUrl);
    if (!imageParsed) errors.push(`${label}: imageUrl must be a valid https URL.`);
    else {
      if (isPlaceholderImageUrl(imageUrl)) {
        errors.push(`${label}: imageUrl is a brand placeholder (${imageUrl}).`);
      }
      if (seenImages.has(imageUrl)) {
        errors.push(`${label}: duplicate imageUrl across items.`);
      } else seenImages.add(imageUrl);

      if (isBatchCarouselImageUrl(imageUrl)) {
        errors.push(
          `${label}: imageUrl looks like a batch/carousel slide (A_/B_/C_ filename) — use single-product art.`,
        );
      }

      if (isSuspiciousPromoFilename(imageUrl)) {
        warnings.push(
          `${label}: imageUrl filename suggests promo/collage art — verify single-product image.`,
        );
      }

      const tier = imageHostTier(imageUrl);
      if (tier === 'reseller' && !hasResellerImageOverride(item)) {
        errors.push(
          `${label}: imageUrl on reseller host (${imageParsed.hostname}) — use official art or set curationOverride "${CURATION_OVERRIDE_RESELLER}".`,
        );
      } else if (tier === 'other' && !imageParsed.hostname.includes('popmart.com')) {
        warnings.push(
          `${label}: imageUrl host "${imageParsed.hostname}" is not a known official CDN.`,
        );
      }

      if (hasResellerImageOverride(item)) {
        warnings.push(
          `${label}: curationOverride "${CURATION_OVERRIDE_RESELLER}" — reseller image explicitly allowed (auditable).`,
        );
      }
    }

    const officialParsed = parseHttpsUrl(officialUrl);
    if (!officialParsed) {
      errors.push(`${label}: officialUrl must be a valid https URL.`);
    } else {
      if (!isPopMartUsItemUrl(officialParsed)) {
        const slugOnly =
          officialParsed.pathname.startsWith('/us/products/') &&
          !isPopMartUsNumericProductUrl(officialParsed);
        errors.push(
          slugOnly
            ? `${label}: officialUrl must use a numeric POP MART product id (/us/products/{id}/slug) — do not invent slug-only paths (${officialUrl}).`
            : `${label}: officialUrl must be a POP MART US product, POP NOW set, or collection page — not the homepage (${officialUrl}).`,
        );
      }
      const releaseType = item?.releaseType?.trim();
      const productId = item?.productId?.trim();
      const urlProductId = productIdFromOfficialUrl(officialUrl);

      if (officialParsed?.pathname.startsWith('/us/products/')) {
        if (releaseType === 'product' && !productId) {
          errors.push(
            `${label}: releaseType "product" requires productId (copy numeric id from browser after page loads — HTTP 200 alone is not proof).`,
          );
        }
        if (productId && urlProductId && productId !== urlProductId) {
          errors.push(
            `${label}: productId "${productId}" does not match officialUrl id "${urlProductId}".`,
          );
        }
        if (productId && id && !itemIdEndsWithProductId(id, productId)) {
          errors.push(
            `${label}: id must end with "_${productId}" (e.g. popmart_us_*_${productId}) — keeps productId auditable in review.`,
          );
        }
      }
      if (seenOfficial.has(officialUrl)) {
        errors.push(`${label}: duplicate officialUrl across items.`);
      } else seenOfficial.add(officialUrl);
    }

    if (!publishedAt || Number.isNaN(Date.parse(publishedAt))) {
      errors.push(`${label}: publishedAt must be ISO-8601 UTC.`);
    } else if (summary) {
      const drift = summaryPublishedAtDateDriftDays(summary, publishedAt);
      if (
        drift != null &&
        drift > SUMMARY_PUBLISHED_AT_MAX_DAY_DRIFT
      ) {
        warnings.push(
          `${label}: summary date and publishedAt calendar day differ by ${drift} day(s) — align after checking the official US announcement (scripts cannot verify release date).`,
        );
      }
    }

    if (status !== 'active') {
      warnings.push(`${label}: status is "${status}" (push still writes it; app hides non-active).`);
    }
  }

  return { ok: errors.length === 0, errors, warnings };
}

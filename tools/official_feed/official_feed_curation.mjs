/**
 * Async curation validation for official feed seed (network probes).
 * Complements sync rules in seed_validation.mjs.
 */

import {
  hasProductIdConfirmed,
  hasResellerImageOverride,
  imageHostTier,
  isOfficialInstagramPostUrl,
  isPopMartUsItemUrl,
  isValidOfficialFeedDestinationUrl,
  parseHttpsUrl,
  productIdFromOfficialUrl,
} from './seed_validation.mjs';

export const REQUEST_TIMEOUT_MS = 15_000;
export const USER_AGENT = 'Mozilla/5.0 (compatible; ShelfyOfficialFeedCuration/1.0)';

/** POP MART US product pages are client-rendered shells (~20 KB) with empty pageProps. */
export const SPA_SHELL_MAX_BYTES = 28_000;

/** Phantom ids that must not resolve to real products if the server validated ids. */
export const PHANTOM_PRODUCT_IDS = ['1', '99999999'];

/** Case-insensitive unavailable copy (substring match on HTML body). */
export const UNAVAILABLE_COPY = [
  'not available',
  'the product you are looking for is not available',
  'not available in your region',
  'back to homepage',
  'strconv.parseuint',
  'product not found',
];

/**
 * @param {string} body
 */
export function bodyHasUnavailableCopy(body) {
  const lower = body.toLowerCase();
  return UNAVAILABLE_COPY.some((phrase) => lower.includes(phrase));
}

/**
 * @param {string} url
 */
export function normalizeImageUrlForCompare(url) {
  try {
    const u = new URL(url.trim());
    u.hash = '';
    u.search = '';
    return u.href;
  } catch {
    return url.trim();
  }
}

/**
 * @param {string} url
 */
export function imageBasename(url) {
  try {
    const path = new URL(url).pathname;
    return path.split('/').pop() ?? '';
  } catch {
    return '';
  }
}

/**
 * @param {string} imageUrl
 * @param {string[]} candidates
 */
export function imageMatchesCandidates(imageUrl, candidates) {
  if (!imageUrl || candidates.length === 0) return false;
  const norm = normalizeImageUrlForCompare(imageUrl);
  const base = imageBasename(imageUrl).toLowerCase();
  for (const c of candidates) {
    if (normalizeImageUrlForCompare(c) === norm) return true;
    const cBase = imageBasename(c).toLowerCase();
    if (base && cBase && base === cBase) return true;
    if (base.length > 8 && c.includes(base)) return true;
  }
  return false;
}

/**
 * @param {string} html
 * @param {string} pageUrl
 */
export function extractCandidateImagesFromHtml(html, pageUrl) {
  const found = new Set();

  const og =
    html.match(/property="og:image"\s+content="([^"]+)"/i)?.[1] ??
    html.match(/content="([^"]+)"\s+property="og:image"/i)?.[1];
  if (og?.startsWith('http')) found.add(og);

  for (const m of html.matchAll(
    /https:\/\/cdn-global[^"'\\s>]+\.(?:png|jpg|jpeg|webp)(?:\?[^"'\\s>]*)?/gi,
  )) {
    const u = m[0];
    if (!u.includes('192.png') && !u.includes('_next/')) found.add(u);
  }

  for (const m of html.matchAll(
    /https:\/\/cdn\.shopify\.com\/[^"'\\s>]+\.(?:png|jpg|jpeg|webp)(?:\?[^"'\\s>]*)?/gi,
  )) {
    const u = m[0];
    if (!u.toLowerCase().includes('logo')) found.add(u);
  }

  const nextMatch = html.match(/<script id="__NEXT_DATA__"[^>]*>([\s\S]*?)<\/script>/i);
  if (nextMatch) {
    try {
      const str = nextMatch[1];
      for (const m of str.matchAll(
        /https?:\\\/\\\/cdn-global[^"\\]+?\.(?:png|jpg|jpeg|webp)/gi,
      )) {
        const u = m[0].replace(/\\\//g, '/');
        if (!u.includes('192.png')) found.add(u);
      }
      for (const m of str.matchAll(
        /https?:\\\/\\\/cdn\.shopify\.com[^"\\]+?\.(?:png|jpg|jpeg|webp)/gi,
      )) {
        found.add(m[0].replace(/\\\//g, '/'));
      }
    } catch {
      // ignore parse errors
    }
  }

  return [...found];
}

/**
 * @param {string} title
 * @param {string} body
 */
/**
 * POP MART US `/us/products/{id}/{slug}` returns the same SPA shell for arbitrary ids.
 * @param {string} body
 */
export function isPopMartUsProductSpaShell(body) {
  if (!body || body.length === 0 || body.length > SPA_SHELL_MAX_BYTES) return false;
  if (!body.includes('__NEXT_DATA__')) return false;
  if (!body.includes('"/products/[...queryParams]"')) return false;
  const next = body.match(/<script id="__NEXT_DATA__"[^>]*>([\s\S]*?)<\/script>/i);
  if (!next) return false;
  try {
    const data = JSON.parse(next[1]);
    const pageProps = data?.props?.pageProps;
    return (
      pageProps != null &&
      typeof pageProps === 'object' &&
      Object.keys(pageProps).length === 0
    );
  } catch {
    return false;
  }
}

/**
 * @param {string} slug
 */
export function phantomProductProbeUrl(slug, phantomId = PHANTOM_PRODUCT_IDS[0]) {
  return `https://www.popmart.com/us/products/${phantomId}/${slug}`;
}

/**
 * True when POP MART US accepts clearly invalid numeric ids for the same slug.
 * @param {string} slug
 */
export async function popMartUsAcceptsPhantomProductId(slug) {
  if (!slug?.trim()) return false;
  const probes = await Promise.all(
    PHANTOM_PRODUCT_IDS.map(async (phantomId) => {
      const url = phantomProductProbeUrl(slug, phantomId);
      const res = await fetch(url, {
        method: 'GET',
        redirect: 'manual',
        headers: { 'User-Agent': USER_AGENT },
        signal: AbortSignal.timeout(REQUEST_TIMEOUT_MS),
      });
      const body = res.status === 200 || res.status === 304 ? await res.text() : '';
      return {
        phantomId,
        ok: (res.status === 200 || res.status === 304) && isPopMartUsProductSpaShell(body),
      };
    }),
  );
  return probes.every((p) => p.ok);
}

/**
 * @param {string} officialUrl
 */
export function productSlugFromOfficialUrl(officialUrl) {
  const parsed = parseHttpsUrl(officialUrl);
  if (!parsed?.pathname.startsWith('/us/products/')) return null;
  const rest = parsed.pathname.slice('/us/products/'.length);
  const slash = rest.indexOf('/');
  if (slash < 0) return null;
  return rest.slice(slash + 1) || null;
}

export function titleAppearsInBody(title, body) {
  const tokens = title
    .toLowerCase()
    .replace(/[—–]/g, ' ')
    .replace(/[^a-z0-9]+/g, ' ')
    .split(/\s+/)
    .filter((t) => t.length > 3);
  if (tokens.length === 0) return false;
  const lowerBody = body.toLowerCase();
  const hits = tokens.filter((t) => lowerBody.includes(t));
  return hits.length >= Math.min(2, tokens.length);
}

/**
 * @param {string} url
 * @returns {Promise<{
 *   ok: boolean,
 *   finalUrl: string,
 *   status?: number,
 *   redirectChain: string[],
 *   body: string,
 *   candidates: string[],
 *   spaShell: boolean,
 *   unavailableCopy: boolean,
 *   finalParsed: URL|null,
 *   error?: string,
 * }>}
 */
export async function probeOfficialPage(url) {
  let current = url;
  const redirectChain = [];

  try {
    for (let hop = 0; hop < 10; hop++) {
      const res = await fetch(current, {
        method: 'GET',
        redirect: 'manual',
        headers: { 'User-Agent': USER_AGENT },
        signal: AbortSignal.timeout(REQUEST_TIMEOUT_MS),
      });

      if (res.status >= 300 && res.status < 400) {
        const loc = res.headers.get('location');
        if (!loc) {
          return {
            ok: false,
            finalUrl: current,
            status: res.status,
            redirectChain,
            body: '',
            candidates: [],
            spaShell: true,
            unavailableCopy: false,
            finalParsed: parseHttpsUrl(current),
            error: `redirect ${res.status} without location`,
          };
        }
        const next = new URL(loc, current).href;
        redirectChain.push(next);
        current = next;
        continue;
      }

      const body = await res.text();
      const finalParsed = parseHttpsUrl(current);
      const candidates = extractCandidateImagesFromHtml(body, current);
      const unavailableCopy = bodyHasUnavailableCopy(body);
      const spaShell = isPopMartUsProductSpaShell(body);

      return {
        ok: (res.status === 200 || res.status === 304) && !unavailableCopy,
        finalUrl: current,
        status: res.status,
        redirectChain,
        body,
        candidates,
        spaShell,
        unavailableCopy,
        finalParsed,
      };
    }

    return {
      ok: false,
      finalUrl: current,
      redirectChain,
      body: '',
      candidates: [],
      spaShell: true,
      unavailableCopy: false,
      finalParsed: parseHttpsUrl(current),
      error: 'too many redirects',
    };
  } catch (e) {
    return {
      ok: false,
      finalUrl: current,
      redirectChain,
      body: '',
      candidates: [],
      spaShell: true,
      unavailableCopy: false,
      finalParsed: parseHttpsUrl(current),
      error: e instanceof Error ? e.message : String(e),
    };
  }
}

/**
 * @param {string} url
 */
export async function probeImageReachability(url) {
  try {
    const res = await fetch(url, {
      method: 'HEAD',
      redirect: 'follow',
      headers: { 'User-Agent': USER_AGENT },
      signal: AbortSignal.timeout(REQUEST_TIMEOUT_MS),
    });
    const type = res.headers.get('content-type') ?? '';
    const imageLike = type.startsWith('image/') || type === '';
    return {
      ok: res.status >= 200 && res.status < 400 && imageLike,
      status: res.status,
      contentType: type,
    };
  } catch (e) {
    return { ok: false, error: e instanceof Error ? e.message : String(e) };
  }
}

/**
 * @typedef {{ level: 'error'|'warning'|'info', message: string, itemId?: string }} CurationIssue
 */

/**
 * @param {object} item
 * @param {number} index
 * @param {Awaited<ReturnType<typeof probeOfficialPage>>} pageProbe
 * @param {{ ok: boolean, status?: number, error?: string }} imageProbe
 * @param {{ acceptsPhantomProductId?: boolean }} [options]
 * @returns {CurationIssue[]}
 */
export function collectAsyncCurationIssues(item, index, pageProbe, imageProbe, options = {}) {
  const issues = [];
  const label = item.id?.trim() ?? `items[${index}]`;
  const itemId = item.id?.trim();
  const officialUrl = item.officialUrl?.trim() ?? '';
  const imageUrl = item.imageUrl?.trim() ?? '';
  const productId = item.productId?.trim();
  const title = item.title?.trim() ?? '';
  const override = hasResellerImageOverride(item);
  const tier = imageHostTier(imageUrl);

  if (pageProbe.error) {
    issues.push({
      level: 'error',
      message: `${label}: officialUrl fetch failed — ${pageProbe.error}`,
      itemId,
    });
    return issues;
  }

  if (pageProbe.status != null && pageProbe.status !== 200 && pageProbe.status !== 304) {
    issues.push({
      level: 'error',
      message: `${label}: officialUrl HTTP ${pageProbe.status} (${officialUrl})`,
      itemId,
    });
  }

  if (pageProbe.unavailableCopy) {
    issues.push({
      level: 'error',
      message: `${label}: officialUrl page contains unavailable/error copy`,
      itemId,
    });
  }

  const finalParsed = pageProbe.finalParsed;
  const isInstagramPost =
    finalParsed != null && isOfficialInstagramPostUrl(finalParsed);
  if (!finalParsed || !isValidOfficialFeedDestinationUrl(finalParsed)) {
    issues.push({
      level: 'error',
      message: `${label}: final URL is not a POP MART US item page or official Instagram post (${pageProbe.finalUrl})`,
      itemId,
    });
  } else if (
    finalParsed.pathname.startsWith('/us/products/') &&
    productId
  ) {
    const finalId = finalParsed.pathname.match(/^\/us\/products\/(\d+)/)?.[1];
    if (finalId && finalId !== productId) {
      issues.push({
        level: 'error',
        message: `${label}: productId "${productId}" does not match final URL id "${finalId}"`,
        itemId,
      });
    }
  }

  if (pageProbe.redirectChain.length > 0) {
    issues.push({
      level: 'info',
      message: `${label}: officialUrl redirected ${pageProbe.redirectChain.length} hop(s) → ${pageProbe.finalUrl}`,
      itemId,
    });
  }

  const isProductPage = finalParsed?.pathname.startsWith('/us/products/');
  const slug = isProductPage ? productSlugFromOfficialUrl(officialUrl) : null;
  const urlProductId = isProductPage ? productIdFromOfficialUrl(officialUrl) : null;

  if (isProductPage && pageProbe.spaShell) {
    if (options.acceptsPhantomProductId && productId) {
      if (!hasProductIdConfirmed(item)) {
        issues.push({
          level: 'error',
          message: `${label}: POP MART US SPA accepts phantom product ids for slug "${slug}" — HTTP 200 does not prove productId "${urlProductId ?? productId}" is correct. Open the live product page in a browser, copy the numeric id from the address bar after hydration, and set productIdConfirmed: true.`,
          itemId,
        });
      }
    }
  } else if (
    pageProbe.candidates.length === 0 &&
    !pageProbe.spaShell &&
    !isInstagramPost
  ) {
    issues.push({
      level: 'warning',
      message: `${label}: no product images extracted from officialUrl HTML`,
      itemId,
    });
  }

  if (
    finalParsed?.pathname.startsWith('/us/pop-now/') &&
    title &&
    pageProbe.body &&
    !titleAppearsInBody(title, pageProbe.body)
  ) {
    issues.push({
      level: 'warning',
      message: `${label}: POP NOW page body does not mention title tokens — verify set id`,
      itemId,
    });
  }

  if (!imageProbe.ok) {
    issues.push({
      level: 'error',
      message: `${label}: imageUrl not reachable (${imageUrl})${imageProbe.status != null ? ` HTTP ${imageProbe.status}` : ''}${imageProbe.error ? ` — ${imageProbe.error}` : ''}`,
      itemId,
    });
  }

  // Reseller / Shopify tier errors and override notices are enforced in seed_validation.mjs (sync).

  if (pageProbe.candidates.length > 0 && !isInstagramPost) {
    if (imageMatchesCandidates(imageUrl, pageProbe.candidates)) {
      issues.push({
        level: 'info',
        message: `${label}: imageUrl matches candidate from officialUrl page`,
        itemId,
      });
    } else if (!override && tier !== 'official') {
      issues.push({
        level: 'error',
        message: `${label}: imageUrl does not match any image extracted from officialUrl`,
        itemId,
      });
    }
  } else if (isInstagramPost && tier === 'other') {
    issues.push({
      level: 'info',
      message: `${label}: Instagram post uses hosted mirror image (not IG CDN art)`,
      itemId,
    });
  }

  return issues;
}

/**
 * @param {CurationIssue[]} issues
 */
export function partitionCurationIssues(issues) {
  return {
    errors: issues.filter((i) => i.level === 'error'),
    warnings: issues.filter((i) => i.level === 'warning'),
    infos: issues.filter((i) => i.level === 'info'),
  };
}

/**
 * @param {{ errors: CurationIssue[], warnings: CurationIssue[], infos: CurationIssue[] }} parts
 */
export function printCurationReport(parts) {
  console.log('\n========== CURATION REPORT ==========\n');

  console.log(`ERRORS (${parts.errors.length})`);
  if (parts.errors.length === 0) {
    console.log('  (none)');
  } else {
    for (const e of parts.errors) console.log(`  • ${e.message}`);
  }

  console.log(`\nWARNINGS (${parts.warnings.length})`);
  if (parts.warnings.length === 0) {
    console.log('  (none)');
  } else {
    for (const w of parts.warnings) console.log(`  • ${w.message}`);
  }

  console.log(`\nINFO (${parts.infos.length})`);
  if (parts.infos.length === 0) {
    console.log('  (none)');
  } else {
    for (const i of parts.infos) console.log(`  • ${i.message}`);
  }

  console.log('\n=====================================\n');
}

/**
 * @param {unknown} seed
 * @param {{ strict?: boolean }} [options]
 */
export async function validateOfficialFeedCuration(seed, options = {}) {
  const { strict = false } = options;
  const allIssues = [];
  const items = seed?.items ?? [];

  for (let i = 0; i < items.length; i++) {
    const item = items[i];
    const status = item?.status?.trim() ?? 'active';
    if (status !== 'active') continue;

    const officialUrl = item?.officialUrl?.trim();
    const imageUrl = item?.imageUrl?.trim();
    if (!officialUrl || !imageUrl) continue;

    const parsed = parseHttpsUrl(officialUrl);
    const slug = productSlugFromOfficialUrl(officialUrl);
    const isProduct = parsed?.pathname.startsWith('/us/products/') ?? false;
    const isInstagram = parsed != null && isOfficialInstagramPostUrl(parsed);

    const [pageProbe, imageProbe, acceptsPhantomProductId] = await Promise.all([
      probeOfficialPage(officialUrl),
      probeImageReachability(imageUrl),
      isProduct && slug && !isInstagram
        ? popMartUsAcceptsPhantomProductId(slug)
        : Promise.resolve(false),
    ]);

    allIssues.push(
      ...collectAsyncCurationIssues(item, i, pageProbe, imageProbe, {
        acceptsPhantomProductId,
      }),
    );
  }

  const parts = partitionCurationIssues(allIssues);
  const ok = parts.errors.length === 0 && (!strict || parts.warnings.length === 0);

  return { ok, ...parts, issues: allIssues };
}

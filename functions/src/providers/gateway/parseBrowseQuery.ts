import type { Request } from 'express';
import type { BrowseCursorPayload, BrowseQuery } from './gatewayTypes';
import {
  browseQuerySignature,
  composeBrowseUpstreamQ,
  normalizeBrowseFacetIds,
} from './composeBrowseQuery';
import {
  composeBrowseAspectPlan,
  resolveBrowseCategoryId,
} from './composeBrowseAspectFilter';

const DEFAULT_LIMIT = 12;
const MAX_LIMIT = 48;

export function resolveDefaultBrowseQuery(): string {
  return composeBrowseUpstreamQ({});
}

export function parseBrowseQuery(req: Request): BrowseQuery {
  const limitRaw = parseInt(String(req.query.limit ?? DEFAULT_LIMIT), 10);
  const limit = clamp(
    Number.isFinite(limitRaw) ? limitRaw : DEFAULT_LIMIT,
    1,
    MAX_LIMIT,
  );

  const brandIdRaw = String(req.query.brandId ?? req.query.brand_id ?? '').trim();
  const ipIdRaw = String(req.query.ipId ?? req.query.ip_id ?? '').trim();
  const { brandId, ipId } = normalizeBrowseFacetIds({
    brandId: brandIdRaw,
    ipId: ipIdRaw,
  });
  const searchText = String(
    req.query.searchText ?? req.query.search ?? '',
  ).trim();
  const sort = String(req.query.sort ?? 'relevance').trim();

  const qRaw = String(req.query.q ?? req.query.query ?? '').trim();
  const hasQOverride = qRaw.length > 0;
  const q = hasQOverride
    ? qRaw
    : composeBrowseUpstreamQ({
        brandId,
        ipId,
        searchText: searchText || undefined,
      });

  const aspectPlan = hasQOverride
    ? undefined
    : composeBrowseAspectPlan({ brandId, ipId });

  const signature = browseQuerySignature({
    brandId,
    ipId,
    searchText: searchText || undefined,
    sort: sort || undefined,
  });

  const cursorRaw = String(req.query.cursor ?? '').trim();
  return {
    limit,
    q,
    brandId: brandId !== 'any_brand' ? brandId : undefined,
    ipId: ipId !== 'any_ip' ? ipId : undefined,
    searchText: searchText || undefined,
    sort: sort || undefined,
    signature,
    cursor: cursorRaw || undefined,
    categoryIds: aspectPlan?.categoryIds ?? resolveBrowseCategoryId(),
    aspectFilter: aspectPlan?.active ? aspectPlan.aspectFilter : undefined,
  };
}

export function parseCursor(raw: string): BrowseCursorPayload | undefined {
  const trimmed = raw.trim();
  if (!trimmed) return undefined;
  try {
    const json = Buffer.from(trimmed, 'base64url').toString('utf8');
    const parsed = JSON.parse(json) as BrowseCursorPayload;
    if (
      typeof parsed.q === 'string' &&
      typeof parsed.limit === 'number' &&
      typeof parsed.offset === 'number'
    ) {
      return parsed;
    }
  } catch {
    return undefined;
  }
  return undefined;
}

export function encodeCursor(payload: BrowseCursorPayload): string {
  return Buffer.from(JSON.stringify(payload), 'utf8').toString('base64url');
}

export function decodeCursor(token: string | undefined): BrowseCursorPayload {
  if (!token) {
    return { q: resolveDefaultBrowseQuery(), limit: DEFAULT_LIMIT, offset: 0 };
  }
  return (
    parseCursor(token) ?? {
      q: resolveDefaultBrowseQuery(),
      limit: DEFAULT_LIMIT,
      offset: 0,
    }
  );
}

function clamp(value: number, min: number, max: number): number {
  return Math.min(max, Math.max(min, value));
}

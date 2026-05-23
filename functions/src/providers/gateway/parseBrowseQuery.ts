import type { Request } from 'express';
import type { BrowseCursorPayload, BrowseQuery } from './gatewayTypes';

const DEFAULT_QUERY = 'pop mart blind box';
const DEFAULT_LIMIT = 24;
const MAX_LIMIT = 48;

export function resolveDefaultBrowseQuery(): string {
  const q =
    process.env.EBAY_DEFAULT_QUERY?.trim() ||
    process.env.MERCARI_DEFAULT_QUERY?.trim();
  return q && q.length > 0 ? q : DEFAULT_QUERY;
}

export function parseBrowseQuery(req: Request): BrowseQuery {
  const limitRaw = parseInt(String(req.query.limit ?? DEFAULT_LIMIT), 10);
  const limit = clamp(
    Number.isFinite(limitRaw) ? limitRaw : DEFAULT_LIMIT,
    1,
    MAX_LIMIT,
  );
  const qRaw = String(req.query.q ?? req.query.query ?? '').trim();
  const q = qRaw.length > 0 ? qRaw : resolveDefaultBrowseQuery();
  const cursorRaw = String(req.query.cursor ?? '').trim();
  return { limit, q, cursor: cursorRaw || undefined };
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

import { HttpError } from '../../shared/http/fetchJson';
import type { BrowseDiagnostics, BrowseResponseMeta } from './mercariTypes';

/** Internal-only meta for operators; Flutter ignores unknown fields. */
export function emptyDiagnostics(): BrowseDiagnostics {
  return {};
}

export function classifyUpstreamError(error: unknown): BrowseDiagnostics {
  if (error instanceof HttpError) {
    const code = error.statusCode;
    if (code === 403) return { upstreamBlocked: true };
    if (code === 429) return { rateLimited: true };
    if (code === 408) return { timedOut: true };
    if (code != null && code >= 500) return { upstreamBlocked: true };
  }
  if (error instanceof Error && error.name === 'AbortError') {
    return { timedOut: true };
  }
  return {};
}

export function shouldUseFixtureFallback(input: {
  fetchFailed: boolean;
  rawRowCount: number;
  normalizedCount: number;
}): boolean {
  if (input.fetchFailed) return true;
  if (input.rawRowCount === 0) return true;
  return input.normalizedCount === 0;
}

export function buildBrowseMeta(
  base: Pick<BrowseResponseMeta, 'mode' | 'query' | 'limit'>,
  diagnostics: BrowseDiagnostics,
): BrowseResponseMeta {
  const upstreamDegraded =
    base.mode === 'live' &&
    (diagnostics.usedFixtureFallback === true ||
      diagnostics.upstreamBlocked === true ||
      diagnostics.parseEmpty === true ||
      diagnostics.parseFailed === true);

  const message = diagnostics.message;
  return {
    ...base,
    upstreamDegraded: upstreamDegraded || undefined,
    message,
    diagnostics: pruneDiagnostics(diagnostics),
  };
}

function pruneDiagnostics(diag: BrowseDiagnostics): BrowseDiagnostics | undefined {
  const out: BrowseDiagnostics = {};
  if (diag.acquisitionStrategy) out.acquisitionStrategy = diag.acquisitionStrategy;
  if (diag.upstreamBlocked) out.upstreamBlocked = true;
  if (diag.rateLimited) out.rateLimited = true;
  if (diag.timedOut) out.timedOut = true;
  if (diag.parseEmpty) out.parseEmpty = true;
  if (diag.parseFailed) out.parseFailed = true;
  if (diag.usedFixtureFallback) out.usedFixtureFallback = true;
  if (diag.paginationInconsistent) out.paginationInconsistent = true;
  if (diag.rawRowCount != null) out.rawRowCount = diag.rawRowCount;
  if (diag.normalizedCount != null) out.normalizedCount = diag.normalizedCount;
  if (diag.rowsDropped != null && diag.rowsDropped > 0) out.rowsDropped = diag.rowsDropped;
  return Object.keys(out).length > 0 ? out : undefined;
}

/** Opt-in: set MERCARI_GATEWAY_DEBUG=1 for Cloud Logs during internal live tests. */
export function gatewayDebugLog(event: string, payload?: Record<string, unknown>): void {
  if (process.env.MERCARI_GATEWAY_DEBUG?.trim() !== '1') return;
  console.warn('[mercari-gateway]', event, payload ?? {});
}

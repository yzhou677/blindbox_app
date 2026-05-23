import { HttpError } from '../../shared/http/fetchJson';
import type { BrowseDiagnostics, BrowseResponseMeta } from './gatewayTypes';

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
  base: Pick<BrowseResponseMeta, 'provider' | 'mode' | 'query' | 'limit'>,
  diagnostics: BrowseDiagnostics,
): BrowseResponseMeta {
  const upstreamDegraded =
    base.mode === 'live' &&
    (diagnostics.usedFixtureFallback === true ||
      diagnostics.upstreamBlocked === true ||
      diagnostics.parseEmpty === true ||
      diagnostics.parseFailed === true);

  return {
    ...base,
    upstreamDegraded: upstreamDegraded || undefined,
    message: diagnostics.message,
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

export function gatewayDebugLog(event: string, payload?: Record<string, unknown>): void {
  const debug =
    process.env.MARKET_GATEWAY_DEBUG?.trim() === '1' ||
    process.env.MERCARI_GATEWAY_DEBUG?.trim() === '1';
  if (!debug) return;
  console.warn('[market-gateway]', event, payload ?? {});
}

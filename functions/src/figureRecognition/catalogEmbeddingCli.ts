import type { CatalogEmbeddingJobOptions } from './catalogEmbeddingJob';

export type CatalogEmbeddingStartupDiagnostic = {
  success: false;
  errorCode: 'catalog-embedding-startup-failed';
  exceptionClass: string;
  component: string;
  reason: string;
};

export function parseCatalogEmbeddingArgs(args: string[]): CatalogEmbeddingJobOptions {
  const options: CatalogEmbeddingJobOptions = {};
  const seen = new Set<string>();
  for (let index = 0; index < args.length; index++) {
    const arg = args[index];
    if (seen.has(arg)) throw new Error(`Duplicate option: ${arg}`);
    seen.add(arg);
    if (arg === '--force') options.force = true;
    else if (arg === '--limit') options.limit = positiveInteger(args[++index], '--limit');
    else if (arg === '--figure-id') {
      const value = args[++index];
      if (!value || value.startsWith('--')) throw new Error('--figure-id requires a value');
      options.figureId = value;
    } else throw new Error(`Unknown option: ${arg}`);
  }
  if (options.limit !== undefined && options.figureId !== undefined) {
    throw new Error('--limit and --figure-id cannot be used together');
  }
  return options;
}

export function createStartupDiagnostic(error: unknown, component: string): CatalogEmbeddingStartupDiagnostic {
  const value = error as { name?: unknown; message?: unknown; constructor?: { name?: unknown } };
  const exceptionClass = safeLabel(value?.name ?? value?.constructor?.name, 'Error');
  const reason = sanitizeReason(typeof value?.message === 'string' ? value.message : 'Unknown startup failure');
  return {
    success: false,
    errorCode: 'catalog-embedding-startup-failed',
    exceptionClass,
    component: safeLabel(component, 'startup'),
    reason,
  };
}

function safeLabel(value: unknown, fallback: string): string {
  const label = typeof value === 'string' ? value : '';
  return /^[A-Za-z0-9._-]{1,80}$/.test(label) ? label : fallback;
}

function sanitizeReason(message: string): string {
  const sanitized = message
    .replace(/https?:\/\/\S+/gi, '[redacted-url]')
    .replace(/[A-Za-z]:\\[^\s]+/g, '[redacted-path]')
    .replace(/\b(token|credential|authorization|bearer)\b\s*[:=]?\s*\S+/gi, '$1 [redacted]')
    .replace(/[\r\n]+/g, ' ')
    .trim();
  return (sanitized || 'Unknown startup failure').slice(0, 240);
}

function positiveInteger(value: string | undefined, name: string): number {
  const parsed = Number(value);
  if (!Number.isInteger(parsed) || parsed <= 0) throw new Error(`${name} must be a positive integer`);
  return parsed;
}

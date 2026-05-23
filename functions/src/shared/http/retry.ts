import { HttpError } from './fetchJson';

export async function withRetries<T>(
  action: () => Promise<T>,
  options: { maxAttempts?: number; baseDelayMs?: number } = {},
): Promise<T> {
  const maxAttempts = options.maxAttempts ?? 3;
  const baseDelayMs = options.baseDelayMs ?? 400;
  let lastError: unknown;

  for (let attempt = 0; attempt < maxAttempts; attempt++) {
    try {
      return await action();
    } catch (e) {
      lastError = e;
      if (!isRetriable(e) || attempt >= maxAttempts - 1) break;
      const delay = baseDelayMs * 2 ** attempt;
      await sleep(delay);
    }
  }

  throw lastError;
}

function isRetriable(error: unknown): boolean {
  if (error instanceof HttpError) {
    const code = error.statusCode;
    if (code == null) return true;
    return code === 408 || code === 429 || code >= 500;
  }
  return true;
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

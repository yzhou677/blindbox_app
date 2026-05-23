export class HttpError extends Error {
  constructor(
    message: string,
    readonly statusCode?: number,
    readonly body?: string,
  ) {
    super(message);
    this.name = 'HttpError';
  }
}

export type FetchJsonOptions = {
  method?: 'GET' | 'POST';
  headers?: Record<string, string>;
  body?: string;
  timeoutMs?: number;
};

export async function fetchJson(
  url: string,
  options: FetchJsonOptions = {},
): Promise<unknown> {
  const timeoutMs = options.timeoutMs ?? 10_000;
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);

  try {
    const response = await fetch(url, {
      method: options.method ?? 'GET',
      headers: options.headers,
      body: options.body,
      signal: controller.signal,
    });

    const text = await response.text();
    if (!response.ok) {
      throw new HttpError(
        `HTTP ${response.status}`,
        response.status,
        text.slice(0, 500),
      );
    }

    if (!text.trim()) return {};
    try {
      return JSON.parse(text) as unknown;
    } catch {
      throw new HttpError('Response is not valid JSON', response.status, text.slice(0, 200));
    }
  } catch (e) {
    if (e instanceof HttpError) throw e;
    if (e instanceof Error && e.name === 'AbortError') {
      throw new HttpError('Request timed out', 408);
    }
    throw new HttpError(e instanceof Error ? e.message : 'Network error');
  } finally {
    clearTimeout(timer);
  }
}

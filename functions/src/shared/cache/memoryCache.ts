type CacheEntry<T> = {
  value: T;
  expiresAt: number;
};

const store = new Map<string, CacheEntry<unknown>>();

export function readCache<T>(key: string): T | undefined {
  const hit = store.get(key);
  if (!hit) return undefined;
  if (Date.now() > hit.expiresAt) {
    store.delete(key);
    return undefined;
  }
  return hit.value as T;
}

export function writeCache<T>(key: string, value: T, ttlMs: number): void {
  if (ttlMs <= 0) return;
  store.set(key, { value, expiresAt: Date.now() + ttlMs });
}

export function clearCache(): void {
  store.clear();
}

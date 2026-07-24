export type CatalogAlternativeImage = {
  imageKey: string;
  variant: string;
};

/**
 * Parse optional `alternativeImages` from a catalog figure document.
 * Missing / null / non-array → []. Invalid entries are skipped.
 * `imageKey` and `variant` must be non-empty trimmed strings.
 */
export function parseAlternativeImages(raw: unknown): CatalogAlternativeImage[] {
  if (raw == null) return [];
  if (!Array.isArray(raw)) return [];
  /** @type {CatalogAlternativeImage[]} */
  const out: CatalogAlternativeImage[] = [];
  const seenKeys = new Set<string>();
  for (const entry of raw) {
    if (entry === null || typeof entry !== 'object' || Array.isArray(entry)) continue;
    const row = entry as Record<string, unknown>;
    const imageKey = typeof row.imageKey === 'string' ? row.imageKey.trim() : '';
    const variant = typeof row.variant === 'string' ? row.variant.trim() : '';
    if (!imageKey || !variant) continue;
    if (seenKeys.has(imageKey)) continue;
    seenKeys.add(imageKey);
    out.push({ imageKey, variant });
  }
  return out;
}

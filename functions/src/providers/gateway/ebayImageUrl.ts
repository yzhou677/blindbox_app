import type { ProviderRawItem } from './gatewayTypes';

export type EbayImageSize = 'browse' | 'detail';

const SIZE_TOKEN: Record<EbayImageSize, string> = {
  browse: 's-l500',
  detail: 's-l1600',
};

/** Upgrade eBay CDN thumb tokens (e.g. s-l225 → s-l500 for cards). */
export function upgradeEbayImageUrl(
  url: string,
  size: EbayImageSize = 'browse',
): string {
  const trimmed = url.trim();
  if (!trimmed) return trimmed;
  const target = SIZE_TOKEN[size];
  if (/\/s-l\d+\./i.test(trimmed)) {
    return trimmed.replace(/\/s-l\d+\./i, `/${target}.`);
  }
  return trimmed;
}

/** Prefer the largest `s-lNNN` candidate from Browse / getItem image fields. */
export function pickBestEbayImageUrl(raw: ProviderRawItem): string {
  const candidates: string[] = [];
  const push = (url: string | undefined) => {
    const t = url?.trim();
    if (!t) return;
    if (t.startsWith('http://') || t.startsWith('https://')) {
      candidates.push(t);
    }
  };

  const imageRecord = readRecord(raw.image);
  push(readString(raw, ['imageUrl', 'url', 'thumbnail']));
  if (imageRecord) {
    push(readString(imageRecord, ['imageUrl', 'url']));
  }
  pushImagesFromArray(raw.thumbnailImages, push);
  pushImagesFromArray(raw.additionalImages, push);

  if (candidates.length === 0) return '';

  let best = candidates[0];
  let bestPx = ebayThumbPixels(best);
  for (const url of candidates.slice(1)) {
    const px = ebayThumbPixels(url);
    if (px > bestPx) {
      bestPx = px;
      best = url;
    }
  }
  return best;
}

function ebayThumbPixels(url: string): number {
  const match = url.match(/\/s-l(\d+)\./i);
  return match ? Number.parseInt(match[1], 10) : 0;
}

function pushImagesFromArray(
  value: unknown,
  push: (url: string | undefined) => void,
): void {
  if (!Array.isArray(value)) return;
  for (const entry of value) {
    if (typeof entry === 'string') {
      push(entry);
      continue;
    }
    if (entry && typeof entry === 'object') {
      push(readString(entry as ProviderRawItem, ['imageUrl', 'url']));
    }
  }
}

function readRecord(value: unknown): ProviderRawItem | undefined {
  if (typeof value === 'object' && value !== null && !Array.isArray(value)) {
    return value as ProviderRawItem;
  }
  return undefined;
}

function readString(obj: ProviderRawItem, keys: string[]): string | undefined {
  for (const key of keys) {
    const v = obj[key];
    if (typeof v === 'string' && v.trim().length > 0) return v.trim();
  }
  return undefined;
}

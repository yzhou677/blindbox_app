import { pickBestEbayImageUrl, upgradeEbayImageUrl } from './ebayImageUrl';
import type { GatewayListingDto, ProviderRawItem } from './gatewayTypes';

export type NormalizeStats = {
  malformedDropped: number;
  duplicateDropped: number;
};

export type NormalizeBrowseResult = {
  items: GatewayListingDto[];
  stats: NormalizeStats;
};

export function normalizeBrowseItems(rows: ProviderRawItem[]): NormalizeBrowseResult {
  const out: GatewayListingDto[] = [];
  const seen = new Set<string>();
  let malformedDropped = 0;
  let duplicateDropped = 0;

  for (const row of rows) {
    const dto = normalizeListing(row);
    if (!dto) {
      malformedDropped++;
      continue;
    }
    if (seen.has(dto.id)) {
      duplicateDropped++;
      continue;
    }
    seen.add(dto.id);
    out.push(dto);
  }

  return {
    items: out,
    stats: { malformedDropped, duplicateDropped },
  };
}

export function normalizeListing(raw: ProviderRawItem): GatewayListingDto | null {
  const id = readString(raw, ['id', 'itemId', 'productId']);
  const titleRaw = readString(raw, ['title', 'name', 'productName']);
  if (!id || !titleRaw) return null;

  const title = normalizeTitle(titleRaw);
  if (!title) return null;

  const legacyItemId = readString(raw, ['legacyItemId']);

  const priceBlock = readRecord(raw.price) ?? raw;
  const value =
    readPriceValue(priceBlock) ?? '0';
  const currency =
    readString(priceBlock, ['currency', 'currencyCode']) ?? 'USD';

  const imageUrl = upgradeEbayImageUrl(pickBestEbayImageUrl(raw), 'browse');

  const listingUrl = resolveListingUrl(
    readString(raw, ['itemWebUrl', 'itemAffiliateWebUrl', 'listingUrl', 'url']),
    id,
    legacyItemId,
  );

  return {
    id,
    title,
    price: { value, currency },
    image: { imageUrl },
    listingUrl,
  };
}

function normalizeTitle(raw: string): string {
  const trimmed = raw.trim();
  if (!trimmed) return '';
  try {
    return trimmed.normalize('NFC');
  } catch {
    return trimmed;
  }
}

export function resolveListingUrl(
  raw: string | undefined,
  itemId: string,
  legacyItemId?: string,
): string {
  const trimmed = raw?.trim() ?? '';
  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
    return trimmed;
  }
  const legacy = legacyItemId?.trim();
  if (legacy && /^\d+$/.test(legacy)) {
    return `https://www.ebay.com/itm/${legacy}`;
  }
  const fromItemId = parseEbayLegacyItemId(itemId);
  if (fromItemId) return `https://www.ebay.com/itm/${fromItemId}`;
  return '';
}

/** eBay Browse `itemId` is often `v1|{legacyItemId}|0`. */
export function parseEbayLegacyItemId(itemId: string): string | undefined {
  const parts = itemId.split('|');
  if (parts.length >= 2 && parts[0] === 'v1') {
    const legacy = parts[1]?.trim();
    if (legacy && /^\d+$/.test(legacy)) return legacy;
  }
  return undefined;
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

function readPriceValue(obj: ProviderRawItem): string | undefined {
  const v = obj.value ?? obj.amount ?? obj.price;
  if (typeof v === 'string' && v.trim()) return v.trim();
  if (typeof v === 'number' && Number.isFinite(v)) return String(v);
  return undefined;
}

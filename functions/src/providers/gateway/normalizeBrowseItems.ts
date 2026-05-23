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

  const title = titleRaw.trim();
  if (!title) return null;

  const priceBlock = readRecord(raw.price) ?? raw;
  const value =
    readString(priceBlock, ['value', 'amount', 'price']) ??
    readNumberAsString(priceBlock, ['price', 'amount']) ??
    '0';
  const currency =
    readString(priceBlock, ['currency', 'currencyCode']) ?? 'USD';

  const imageBlock = readRecord(raw.image) ?? readRecord(raw.thumbnailImages) ?? raw;
  const imageUrl =
    sanitizeImageUrl(
      readString(imageBlock, ['imageUrl', 'url', 'thumbnail']) ??
        readFirstImageUrl(raw) ??
        '',
    ) ?? '';

  const listingUrl = resolveListingUrl(
    readString(raw, ['listingUrl', 'itemWebUrl', 'url', 'productUrl']),
    id,
  );

  return {
    id,
    title,
    price: { value, currency },
    image: { imageUrl },
    listingUrl,
  };
}

function resolveListingUrl(raw: string | undefined, id: string): string {
  const trimmed = raw?.trim() ?? '';
  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
    return trimmed;
  }
  if (id.startsWith('v1|')) {
    return `https://www.ebay.com/itm/${encodeURIComponent(id)}`;
  }
  return trimmed;
}

function sanitizeImageUrl(raw: string): string | undefined {
  const t = raw.trim();
  if (!t.startsWith('http://') && !t.startsWith('https://')) return undefined;
  return t;
}

function readFirstImageUrl(raw: ProviderRawItem): string | undefined {
  const thumbs = raw.thumbnailImages;
  if (!Array.isArray(thumbs) || thumbs.length === 0) return undefined;
  const first = thumbs[0];
  if (typeof first === 'object' && first !== null) {
    return readString(first as ProviderRawItem, ['imageUrl', 'url']);
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

function readNumberAsString(obj: ProviderRawItem, keys: string[]): string | undefined {
  for (const key of keys) {
    const v = obj[key];
    if (typeof v === 'number' && Number.isFinite(v)) return String(v);
  }
  return undefined;
}

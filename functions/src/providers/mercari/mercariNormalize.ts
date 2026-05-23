import type { GatewayListingDto, MercariRawItem } from './mercariTypes';

export type NormalizeStats = {
  malformedDropped: number;
  duplicateDropped: number;
};

export type NormalizeBrowseResult = {
  items: GatewayListingDto[];
  stats: NormalizeStats;
};

/** Maps provider rows to stable gateway DTOs — skips malformed and duplicate ids. */
export function normalizeBrowseItems(rows: MercariRawItem[]): NormalizeBrowseResult {
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

/** Maps one provider row to stable gateway DTO — skips malformed rows. */
export function normalizeListing(raw: MercariRawItem): GatewayListingDto | null {
  const id = readString(raw, ['id', 'itemId', 'productId']);
  const titleRaw = readString(raw, ['title', 'name', 'productName']);
  if (!id || !titleRaw) return null;

  const title = normalizeTitle(titleRaw);
  if (!title) return null;

  const priceBlock = readRecord(raw.price) ?? raw;
  const value =
    readString(priceBlock, ['value', 'amount', 'price']) ??
    readNumberAsString(priceBlock, ['price', 'amount']) ??
    '0';
  const currency =
    readString(priceBlock, ['currency', 'currencyCode']) ?? 'USD';

  const imageBlock = readRecord(raw.image) ?? readRecord(raw.photos) ?? raw;
  const imageUrl =
    sanitizeImageUrl(
      readString(imageBlock, ['imageUrl', 'url', 'thumbnail']) ??
        readFirstPhotoUrl(raw) ??
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

function normalizeTitle(raw: string): string {
  const trimmed = raw.trim();
  if (!trimmed) return '';
  try {
    return trimmed.normalize('NFC');
  } catch {
    return trimmed;
  }
}

function sanitizeImageUrl(raw: string): string | undefined {
  const trimmed = raw.trim();
  if (!trimmed) return undefined;
  if (/^https?:\/\//i.test(trimmed)) return trimmed;
  return undefined;
}

function resolveListingUrl(raw: string | undefined, id: string): string {
  const trimmed = raw?.trim() ?? '';
  if (trimmed && /^https?:\/\//i.test(trimmed)) return trimmed;
  if (/^m\d+$/i.test(id)) return `https://www.mercari.com/us/item/${id}/`;
  return '';
}

function readFirstPhotoUrl(raw: MercariRawItem): string | undefined {
  const photos = raw.photos;
  if (!Array.isArray(photos) || photos.length === 0) return undefined;
  const first = photos[0];
  if (typeof first === 'string' && first.trim()) return first.trim();
  if (first && typeof first === 'object') {
    return readString(first as MercariRawItem, ['imageUrl', 'url', 'thumbnail']);
  }
  return undefined;
}

function readString(
  obj: MercariRawItem | undefined,
  keys: string[],
): string | undefined {
  if (!obj) return undefined;
  for (const key of keys) {
    const v = obj[key];
    if (typeof v === 'string' && v.trim()) return v.trim();
    if (typeof v === 'number' && Number.isFinite(v)) return String(v);
  }
  return undefined;
}

function readNumberAsString(
  obj: MercariRawItem,
  keys: string[],
): string | undefined {
  for (const key of keys) {
    const v = obj[key];
    if (typeof v === 'number' && Number.isFinite(v)) return v.toFixed(2);
  }
  return undefined;
}

function readRecord(value: unknown): MercariRawItem | undefined {
  if (value && typeof value === 'object' && !Array.isArray(value)) {
    return value as MercariRawItem;
  }
  return undefined;
}

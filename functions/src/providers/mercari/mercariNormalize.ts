import type { GatewayListingDto, MercariRawItem } from './mercariTypes';

/** Maps one provider row to stable gateway DTO — skips malformed rows. */
export function normalizeListing(raw: MercariRawItem): GatewayListingDto | null {
  const id = readString(raw, ['id', 'itemId', 'productId']);
  const title = readString(raw, ['title', 'name', 'productName']);
  if (!id || !title) return null;

  const priceBlock = readRecord(raw.price) ?? raw;
  const value =
    readString(priceBlock, ['value', 'amount', 'price']) ??
    readNumberAsString(priceBlock, ['price', 'amount']) ??
    '0';
  const currency =
    readString(priceBlock, ['currency', 'currencyCode']) ?? 'USD';

  const imageBlock = readRecord(raw.image) ?? readRecord(raw.photos) ?? raw;
  const imageUrl =
    readString(imageBlock, ['imageUrl', 'url', 'thumbnail']) ??
    readFirstPhotoUrl(raw) ??
    '';

  const listingUrl =
    readString(raw, ['listingUrl', 'itemWebUrl', 'url', 'productUrl']) ??
    (id.startsWith('m') ? `https://www.mercari.com/us/item/${id}/` : '');

  return {
    id,
    title,
    price: { value, currency },
    image: { imageUrl },
    listingUrl,
  };
}

export function normalizeBrowseItems(rows: MercariRawItem[]): GatewayListingDto[] {
  const out: GatewayListingDto[] = [];
  for (const row of rows) {
    const dto = normalizeListing(row);
    if (dto) out.push(dto);
  }
  return out;
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

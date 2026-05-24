import { pickBestEbayImageUrl, upgradeEbayImageUrl } from './ebayImageUrl';
import type { GatewayItemDetailDto, ProviderRawItem } from './gatewayTypes';
import { resolveListingUrl } from './normalizeBrowseItems';

export function normalizeItemDetail(raw: ProviderRawItem): GatewayItemDetailDto | null {
  const itemId = readString(raw, ['itemId', 'id']);
  const title = normalizeTitle(readString(raw, ['title', 'name']) ?? '');
  if (!itemId || !title) return null;

  const legacyItemId = readString(raw, ['legacyItemId']);
  const priceBlock = readRecord(raw.price) ?? raw;
  const value = readPriceValue(priceBlock) ?? '0';
  const currency = readString(priceBlock, ['currency', 'currencyCode']) ?? 'USD';

  const imageUrl = upgradeEbayImageUrl(pickBestEbayImageUrl(raw), 'detail');
  const listingUrl = resolveListingUrl(
    readString(raw, ['itemWebUrl', 'itemAffiliateWebUrl', 'listingUrl']),
    itemId,
    legacyItemId,
  );

  const condition = readConditionLabel(raw);
  const availability = readEstimatedAvailability(raw);
  const shortDescription = trimDescription(
    readString(raw, ['shortDescription', 'description']),
  );

  const sellerBlock = readRecord(raw.seller);
  const sellerUsername = sellerBlock
    ? readString(sellerBlock, ['username'])
    : undefined;
  const sellerFeedback = sellerBlock
    ? readString(sellerBlock, ['feedbackPercentage'])
    : undefined;

  const shippingSummary = buildShippingSummary(raw);

  return {
    itemId,
    title,
    price: { value, currency },
    imageUrl,
    listingUrl,
    condition: condition || undefined,
    quantity: availability.quantity,
    availabilityStatus: availability.status,
    shortDescription: shortDescription || undefined,
    seller:
      sellerUsername || sellerFeedback
        ? {
            username: sellerUsername,
            feedbackPercentage: sellerFeedback,
          }
        : undefined,
    shipping: shippingSummary ? { summary: shippingSummary } : undefined,
  };
}

function readConditionLabel(raw: ProviderRawItem): string | undefined {
  const display = readString(raw, [
    'conditionDisplayName',
    'conditionDescription',
  ]);
  if (display) return display;

  const nested = readRecord(raw.condition);
  if (nested) {
    const nestedLabel = readString(nested, [
      'conditionDisplayName',
      'conditionDescription',
      'condition',
    ]);
    if (nestedLabel) return formatConditionToken(nestedLabel);
  }

  const token = readString(raw, ['condition']);
  if (token) return formatConditionToken(token);
  return undefined;
}

function formatConditionToken(raw: string): string {
  const trimmed = raw.trim();
  if (!trimmed) return '';
  const key = trimmed.toUpperCase().replace(/[\s-]+/g, '_');
  const labels: Record<string, string> = {
    NEW: 'New',
    NEW_WITH_DEFECTS: 'New with defects',
    NEW_OTHER: 'New (other)',
    MANUFACTURER_REFURBISHED: 'Manufacturer refurbished',
    CERTIFIED_REFURBISHED: 'Certified refurbished',
    EXCELLENT_REFURBISHED: 'Excellent refurbished',
    VERY_GOOD_REFURBISHED: 'Very good refurbished',
    GOOD_REFURBISHED: 'Good refurbished',
    SELLER_REFURBISHED: 'Seller refurbished',
    LIKE_NEW: 'Like new',
    USED: 'Used',
    VERY_GOOD: 'Very good',
    GOOD: 'Good',
    ACCEPTABLE: 'Acceptable',
    FOR_PARTS_OR_NOT_WORKING: 'For parts or not working',
  };
  return labels[key] ?? toTitleWords(trimmed.replace(/_/g, ' '));
}

function toTitleWords(raw: string): string {
  return raw
    .split(/\s+/)
    .filter(Boolean)
    .map((word) => word.charAt(0).toUpperCase() + word.slice(1).toLowerCase())
    .join(' ');
}

function readEstimatedAvailability(raw: ProviderRawItem): {
  quantity?: number;
  status?: string;
} {
  const rows = raw.estimatedAvailabilities;
  if (!Array.isArray(rows) || rows.length === 0) {
    const direct = readQuantityValue(raw.estimatedAvailableQuantity);
    return direct != null ? { quantity: direct } : {};
  }

  let quantity: number | undefined;
  let status: string | undefined;
  for (const row of rows) {
    if (!row || typeof row !== 'object') continue;
    const entry = row as ProviderRawItem;
    const rowQty = readQuantityValue(entry.estimatedAvailableQuantity);
    if (rowQty != null) {
      quantity = quantity == null ? rowQty : quantity + rowQty;
    }
    const rowStatus = readString(entry, ['estimatedAvailabilityStatus']);
    if (rowStatus) {
      status = mergeAvailabilityStatus(status, rowStatus);
    }
  }

  return {
    quantity,
    status,
  };
}

function mergeAvailabilityStatus(
  current: string | undefined,
  next: string,
): string {
  const normalized = next.trim().toUpperCase();
  if (!current) return normalized;
  const rank = (value: string) => {
    if (value === 'OUT_OF_STOCK') return 0;
    if (value === 'LIMITED_STOCK') return 1;
    return 2;
  };
  return rank(normalized) < rank(current) ? normalized : current;
}

function readQuantityValue(value: unknown): number | undefined {
  if (typeof value === 'number' && Number.isFinite(value) && value >= 0) {
    return Math.floor(value);
  }
  if (typeof value === 'string' && value.trim()) {
    const parsed = Number.parseInt(value.trim(), 10);
    if (Number.isFinite(parsed) && parsed >= 0) return parsed;
  }
  return undefined;
}

function buildShippingSummary(raw: ProviderRawItem): string | undefined {
  const options = raw.shippingOptions;
  if (!Array.isArray(options) || options.length === 0) return undefined;

  const first = options[0];
  if (!first || typeof first !== 'object') return undefined;
  const option = first as ProviderRawItem;

  const costBlock = readRecord(option.shippingCost);
  const rawValue = costBlock ? readPriceValue(costBlock) : undefined;
  const parsed = rawValue ? Number.parseFloat(rawValue) : Number.NaN;
  const currency = costBlock
    ? (readString(costBlock, ['currency', 'currencyCode']) ?? 'USD')
    : 'USD';
  const service = readString(option, ['type', 'shippingServiceCode']);

  if (Number.isFinite(parsed) && parsed === 0) {
    return service ? `Free shipping · ${service}` : 'Free shipping';
  }
  if (Number.isFinite(parsed) && parsed > 0) {
    const amount = formatMoney(parsed, currency);
    return service ? `${amount} shipping · ${service}` : `${amount} shipping`;
  }
  return service ?? undefined;
}

function formatMoney(value: number, currency: string): string {
  if (currency.toUpperCase() === 'USD') {
    return `$${value.toFixed(2)}`;
  }
  return `${value.toFixed(2)} ${currency}`;
}

function trimDescription(raw: string | undefined): string | undefined {
  const text = raw?.trim() ?? '';
  if (!text) return undefined;
  const plain = text.replace(/<[^>]+>/g, ' ').replace(/\s+/g, ' ').trim();
  if (!plain) return undefined;
  return plain.length > 480 ? `${plain.slice(0, 477)}…` : plain;
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

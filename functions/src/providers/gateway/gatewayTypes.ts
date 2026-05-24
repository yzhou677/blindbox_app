/** Stable market gateway wire — provider-neutral listing JSON. */

export type GatewayListingDto = {
  id: string;
  title: string;
  price: { value: string; currency: string };
  image: { imageUrl: string };
  listingUrl: string;
  /** Minimal seller identity for heat/seller-diversity derivations. */
  seller?: { username?: string };
  /** ISO-8601 listing creation timestamp when upstream provides it. */
  itemCreationDate?: string;
};

export type GatewayItemDetailDto = {
  itemId: string;
  title: string;
  price: { value: string; currency: string };
  imageUrl: string;
  listingUrl: string;
  condition?: string;
  /** Estimated units available for purchase (eBay estimatedAvailableQuantity). */
  quantity?: number;
  /** IN_STOCK, LIMITED_STOCK, OUT_OF_STOCK when provided by upstream. */
  availabilityStatus?: string;
  shortDescription?: string;
  seller?: {
    username?: string;
    feedbackPercentage?: string;
  };
  shipping?: {
    summary: string;
  };
};

export type BrowseResponseDto = {
  items: GatewayListingDto[];
  nextCursor?: string;
  hasMore: boolean;
  meta?: BrowseResponseMeta;
};

export type BrowseDiagnostics = {
  acquisitionStrategy?: string;
  upstreamBlocked?: boolean;
  rateLimited?: boolean;
  timedOut?: boolean;
  parseEmpty?: boolean;
  parseFailed?: boolean;
  usedFixtureFallback?: boolean;
  paginationInconsistent?: boolean;
  rawRowCount?: number;
  normalizedCount?: number;
  rowsDropped?: number;
  message?: string;
};

export type BrowseResponseMeta = {
  provider: 'ebay' | 'mercari';
  mode: 'fixture' | 'live';
  query: string;
  limit: number;
  upstreamDegraded?: boolean;
  message?: string;
  diagnostics?: BrowseDiagnostics;
};

export type BrowseQuery = {
  limit: number;
  cursor?: string;
  q: string;
  brandId?: string;
  ipId?: string;
  searchText?: string;
  sort?: string;
  signature: string;
  categoryIds?: string;
  aspectFilter?: string;
};

export type BrowseCursorPayload = {
  q: string;
  limit: number;
  offset: number;
};

export type ProviderRawItem = Record<string, unknown>;

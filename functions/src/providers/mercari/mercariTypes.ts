/** Stable gateway wire — matches Flutter [MercariBrowseResponseDto] / [MercariListingDto]. */

export type GatewayListingDto = {
  id: string;
  title: string;
  price: { value: string; currency: string };
  image: { imageUrl: string };
  listingUrl: string;
};

export type BrowseResponseDto = {
  items: GatewayListingDto[];
  nextCursor?: string;
  hasMore: boolean;
  meta?: BrowseResponseMeta;
};

export type BrowseResponseMeta = {
  mode: 'fixture' | 'live';
  query: string;
  limit: number;
  upstreamDegraded?: boolean;
  message?: string;
};

export type BrowseQuery = {
  limit: number;
  cursor?: string;
  q: string;
};

/** Opaque cursor payload (gateway-owned, not Mercari-native). */
export type BrowseCursorPayload = {
  q: string;
  limit: number;
  offset: number;
};

/** Loose upstream row before normalization. */
export type MercariRawItem = Record<string, unknown>;

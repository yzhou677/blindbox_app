export type RecommendationReasonType =
  | 'owned_ip'
  | 'wishlist_ip'
  | 'recent_release'
  | 'new_in_catalog';

export interface RecommendationProfile {
  installId: string;
  ownedCatalogSeriesIds: string[];
  wishlistCatalogSeriesIds: string[];
  ownedIpIds: string[];
  wishlistIpIds: string[];
  profileHash: string;
  updatedAt?: unknown;
}

export interface RecommendationItemWire {
  seriesId: string;
  reasonType: RecommendationReasonType;
  reasonMeta?: string;
}

export interface CatalogSeriesDoc {
  id: string;
  ipId: string;
  displayName: string;
  releaseDate?: string | null;
}

export interface CatalogIpDoc {
  id: string;
  displayName: string;
}

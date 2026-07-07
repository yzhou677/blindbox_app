export type RecommendationReasonType =
  | 'tracked_ip'
  | 'wishlist_ip'
  | 'recent_release'
  | 'new_in_catalog';

export interface RecommendationProfile {
  installId: string;
  trackedCatalogSeriesIds: string[];
  ownedCatalogSeriesIds?: string[];
  wishlistCatalogSeriesIds?: string[];
  trackedIpIds: string[];
  ownedIpIds?: string[];
  wishlistIpIds?: string[];
  profileHash: string;
  updatedAt?: unknown;
}

export interface RecommendationItemWire {
  seriesId: string;
  primaryReasonType: RecommendationReasonType;
  primaryReasonMeta?: string;
  secondaryReasonType?: RecommendationReasonType;
  secondaryReasonMeta?: string;
  /** @deprecated Legacy mirror of primary — emitted for older clients. */
  reasonType?: RecommendationReasonType;
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

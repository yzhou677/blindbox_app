import type { MercariRawItem } from '../mercariTypes';

/** Opaque gateway pagination slice passed into acquisition (not Mercari-native). */
export type MercariSearchPageRequest = {
  query: string;
  limit: number;
  offset: number;
};

/**
 * Replaceable upstream acquisition boundary.
 *
 * Implementations return provider-shaped raw rows only. Normalization and
 * stable gateway DTOs happen outside this layer.
 */
export interface MercariProviderRuntime {
  readonly strategyId: MercariAcquisitionStrategyId;

  /** Search/browse page acquisition (primary live path today). */
  fetchSearchPage(request: MercariSearchPageRequest): Promise<MercariRawItem[]>;
}

export type MercariAcquisitionStrategyId = 'fetch' | 'playwright' | 'fixture';

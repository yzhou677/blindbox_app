import { FetchMercariRuntime } from './fetchMercariRuntime';
import { PlaywrightMercariRuntime } from './playwrightMercariRuntime';
import type {
  MercariAcquisitionStrategyId,
  MercariProviderRuntime,
} from './mercariProviderRuntime';

export function resolveAcquisitionStrategyId(): MercariAcquisitionStrategyId {
  const raw = (process.env.MERCARI_ACQUISITION_RUNTIME ?? 'fetch')
    .trim()
    .toLowerCase();
  if (raw === 'playwright') return 'playwright';
  return 'fetch';
}

/** Factory for the active Mercari acquisition implementation. */
export function createMercariRuntime(): MercariProviderRuntime {
  const strategy = resolveAcquisitionStrategyId();
  switch (strategy) {
    case 'playwright':
      return new PlaywrightMercariRuntime();
    case 'fetch':
    default:
      return new FetchMercariRuntime();
  }
}

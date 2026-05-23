import { HttpError } from '../../../shared/http/fetchJson';
import type { MercariRawItem } from '../mercariTypes';
import type {
  MercariProviderRuntime,
  MercariSearchPageRequest,
} from './mercariProviderRuntime';

/**
 * Future browser-backed acquisition (Playwright / headless).
 *
 * Not implemented — reserved so gateway orchestration stays stable when
 * browser runtime ships. Do not wire scraping orchestration here.
 */
export class PlaywrightMercariRuntime implements MercariProviderRuntime {
  readonly strategyId = 'playwright' as const;

  async fetchSearchPage(_request: MercariSearchPageRequest): Promise<MercariRawItem[]> {
    throw new HttpError(
      'PlaywrightMercariRuntime is not implemented; use MERCARI_ACQUISITION_RUNTIME=fetch or fixture mode',
      501,
    );
  }
}

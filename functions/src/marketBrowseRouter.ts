import type { Request, Response } from 'express';
import { handleEbayBrowseRequest } from './providers/ebay/ebayBrowse';
import { handleMercariBrowseRequest } from './providers/mercari/mercariBrowse';

export type MarketGatewayProvider = 'ebay' | 'mercari';

export function resolveMarketGatewayProvider(): MarketGatewayProvider {
  const raw = (process.env.MARKET_GATEWAY_PROVIDER ?? 'ebay')
    .trim()
    .toLowerCase();
  return raw === 'mercari' ? 'mercari' : 'ebay';
}

/** Routes `GET /v1/browse` to the configured marketplace provider. */
export async function handleMarketBrowseRequest(
  req: Request,
  res: Response,
): Promise<void> {
  const provider = resolveMarketGatewayProvider();
  if (provider === 'mercari') {
    await handleMercariBrowseRequest(req, res);
    return;
  }
  await handleEbayBrowseRequest(req, res);
}

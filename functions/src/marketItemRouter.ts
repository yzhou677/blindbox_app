import type { Request, Response } from 'express';
import { handleEbayItemRequest } from './providers/ebay/ebayItemDetail';
import { resolveMarketGatewayProvider } from './marketBrowseRouter';

/** Routes `GET /v1/item` to the configured marketplace provider. */
export async function handleMarketItemRequest(
  req: Request,
  res: Response,
): Promise<void> {
  const provider = resolveMarketGatewayProvider();
  if (provider !== 'ebay') {
    res.status(501).json({
      error: 'not_implemented',
      message: 'Item detail is only supported for the eBay provider',
    });
    return;
  }
  await handleEbayItemRequest(req, res);
}

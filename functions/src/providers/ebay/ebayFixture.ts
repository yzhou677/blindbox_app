import type { ProviderRawItem } from '../gateway/gatewayTypes';

const FIXTURE_ROWS: ProviderRawItem[] = [
  {
    itemId: 'v1|900000000001|0',
    legacyItemId: '900000000001',
    title: 'POP MART sealed blind box (fixture)',
    price: { value: '32.00', currency: 'USD' },
    condition: 'New',
    shortDescription: 'Sealed POP MART blind box from fixture data.',
    seller: { username: 'fixture_seller', feedbackPercentage: '99.1' },
    shippingOptions: [
      {
        type: 'Standard Shipping',
        shippingCost: { value: '0.0', currency: 'USD' },
      },
    ],
    image: {
      imageUrl:
        'https://ir.ebaystatic.com/pictures/aw/pics/logos/ebay-logo-200x200.png',
    },
    itemWebUrl: 'https://www.ebay.com/itm/900000000001',
  },
  {
    itemId: 'v1|900000000002|0',
    legacyItemId: '900000000002',
    title: 'Labubu vinyl figure (fixture)',
    price: { value: '58.00', currency: 'USD' },
    condition: 'Used',
    shortDescription: 'Labubu vinyl figure listing from fixture data.',
    seller: { username: 'fixture_seller', feedbackPercentage: '98.4' },
    shippingOptions: [
      {
        type: 'Economy Shipping',
        shippingCost: { value: '6.99', currency: 'USD' },
      },
    ],
    image: {
      imageUrl:
        'https://ir.ebaystatic.com/pictures/aw/pics/logos/ebay-logo-200x200.png',
    },
    itemWebUrl: 'https://www.ebay.com/itm/900000000002',
  },
  {
    itemId: 'v1|900000000003|0',
    legacyItemId: '900000000003',
    title: 'Hirono chase listing (fixture)',
    price: { value: '89.00', currency: 'USD' },
    condition: 'New',
    shortDescription: 'Hirono chase variant from fixture data.',
    seller: { username: 'fixture_seller', feedbackPercentage: '100.0' },
    shippingOptions: [
      {
        type: 'Standard Shipping',
        shippingCost: { value: '0.0', currency: 'USD' },
      },
    ],
    image: {
      imageUrl:
        'https://ir.ebaystatic.com/pictures/aw/pics/logos/ebay-logo-200x200.png',
    },
    itemWebUrl: 'https://www.ebay.com/itm/900000000003',
  },
  {
    itemId: 'v1|900000000004|0',
    legacyItemId: '900000000004',
    title: 'Skullpanda display set (fixture)',
    price: { value: '74.00', currency: 'USD' },
    condition: 'New',
    shortDescription: 'Skullpanda display set from fixture data.',
    seller: { username: 'fixture_seller', feedbackPercentage: '97.8' },
    shippingOptions: [
      {
        type: 'Standard Shipping',
        shippingCost: { value: '4.50', currency: 'USD' },
      },
    ],
    image: {
      imageUrl:
        'https://ir.ebaystatic.com/pictures/aw/pics/logos/ebay-logo-200x200.png',
    },
    itemWebUrl: 'https://www.ebay.com/itm/900000000004',
  },
];

export function ebayFixtureItems(query: string): ProviderRawItem[] {
  const seed = query.toLowerCase();
  return FIXTURE_ROWS.map((row) => ({
    ...row,
    title: `${seed} — ${String(row.title ?? 'fixture listing')}`,
  }));
}

export function ebayFixtureItemDetail(itemId: string): ProviderRawItem | null {
  const trimmed = itemId.trim();
  if (!trimmed) return null;

  for (const row of FIXTURE_ROWS) {
    const id = String(row.itemId ?? '');
    const legacy = String(row.legacyItemId ?? '');
    if (trimmed === id || trimmed === legacy) {
      return row;
    }
  }

  const legacyFromId = trimmed.split('|')[1]?.trim();
  if (legacyFromId) {
    for (const row of FIXTURE_ROWS) {
      if (String(row.legacyItemId ?? '') === legacyFromId) return row;
    }
  }

  return null;
}

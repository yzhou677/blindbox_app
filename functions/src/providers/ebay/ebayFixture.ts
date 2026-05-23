import type { ProviderRawItem } from '../gateway/gatewayTypes';

export function ebayFixtureItems(query: string): ProviderRawItem[] {
  const seed = query.toLowerCase();
  return [
    {
      itemId: 'v1|900000000001|0',
      title: `${seed} — POP MART sealed blind box (fixture)`,
      price: { value: '32.00', currency: 'USD' },
      image: {
        imageUrl:
          'https://ir.ebaystatic.com/pictures/aw/pics/logos/ebay-logo-200x200.png',
      },
      itemWebUrl: 'https://www.ebay.com/itm/900000000001',
    },
    {
      itemId: 'v1|900000000002|0',
      title: `${seed} — Labubu vinyl figure (fixture)`,
      price: { value: '58.00', currency: 'USD' },
      image: {
        imageUrl:
          'https://ir.ebaystatic.com/pictures/aw/pics/logos/ebay-logo-200x200.png',
      },
      itemWebUrl: 'https://www.ebay.com/itm/900000000002',
    },
    {
      itemId: 'v1|900000000003|0',
      title: `${seed} — Hirono chase listing (fixture)`,
      price: { value: '89.00', currency: 'USD' },
      image: {
        imageUrl:
          'https://ir.ebaystatic.com/pictures/aw/pics/logos/ebay-logo-200x200.png',
      },
      itemWebUrl: 'https://www.ebay.com/itm/900000000003',
    },
    {
      itemId: 'v1|900000000004|0',
      title: `${seed} — Skullpanda display set (fixture)`,
      price: { value: '74.00', currency: 'USD' },
      image: {
        imageUrl:
          'https://ir.ebaystatic.com/pictures/aw/pics/logos/ebay-logo-200x200.png',
      },
      itemWebUrl: 'https://www.ebay.com/itm/900000000004',
    },
  ];
}

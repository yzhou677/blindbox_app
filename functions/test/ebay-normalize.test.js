'use strict';

const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const { normalizeListing } = require('../lib/providers/gateway/normalizeBrowseItems');

describe('normalizeListing eBay Browse shape', () => {
  it('maps item_summary fields and stable listing URL', () => {
    const dto = normalizeListing({
      itemId: 'v1|110589358256|0',
      legacyItemId: '110589358256',
      title: 'POP MART Labubu',
      price: { value: '24.50', currency: 'USD' },
      itemWebUrl:
        'https://www.ebay.com/itm/POP-MART-Labubu/110589358256',
      thumbnailImages: [{ imageUrl: 'https://i.ebayimg.com/sample.jpg' }],
    });
    assert.ok(dto);
    assert.equal(dto.id, 'v1|110589358256|0');
    assert.equal(dto.title, 'POP MART Labubu');
    assert.equal(dto.price.value, '24.50');
    assert.equal(dto.image.imageUrl, 'https://i.ebayimg.com/sample.jpg');
    assert.ok(dto.listingUrl.includes('110589358256'));
  });

  it('maps seller username and itemCreationDate when present', () => {
    const dto = normalizeListing({
      itemId: 'v1|110589358256|0',
      legacyItemId: '110589358256',
      title: 'POP MART Labubu',
      price: { value: '24.50', currency: 'USD' },
      itemWebUrl:
        'https://www.ebay.com/itm/POP-MART-Labubu/110589358256',
      seller: { username: 'collectible_hub' },
      itemCreationDate: '2026-03-01T12:00:00.000Z',
    });
    assert.ok(dto);
    assert.equal(dto.seller?.username, 'collectible_hub');
    assert.equal(dto.itemCreationDate, '2026-03-01T12:00:00.000Z');
  });

  it('ignores itemHref API URLs when itemWebUrl missing', () => {
    const dto = normalizeListing({
      itemId: 'v1|999|0',
      legacyItemId: '999',
      title: 'Test',
      price: { value: 1, currency: 'USD' },
      itemHref: 'https://api.ebay.com/buy/browse/v1/item/v1%7C999%7C0',
    });
    assert.ok(dto);
    assert.equal(dto.listingUrl, 'https://www.ebay.com/itm/999');
    assert.equal(dto.price.value, '1');
  });
});

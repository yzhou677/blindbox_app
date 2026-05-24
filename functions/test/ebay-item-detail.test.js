'use strict';

const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const { normalizeItemDetail } = require('../lib/providers/gateway/normalizeItemDetail');

describe('normalizeItemDetail', () => {
  it('maps condition, seller, shipping, and description', () => {
    const dto = normalizeItemDetail({
      itemId: 'v1|110589358256|0',
      legacyItemId: '110589358256',
      title: 'POP MART Labubu',
      price: { value: '24.50', currency: 'USD' },
      condition: 'New',
      shortDescription: 'Sealed blind box.',
      seller: { username: 'seller_one', feedbackPercentage: '99.2' },
      shippingOptions: [
        {
          type: 'Standard Shipping',
          shippingCost: { value: '0.0', currency: 'USD' },
        },
      ],
      image: {
        imageUrl: 'https://i.ebayimg.com/images/g/abc/s-l225.jpg',
      },
      itemWebUrl:
        'https://www.ebay.com/itm/POP-MART-Labubu/110589358256',
    });

    assert.ok(dto);
    assert.equal(dto.itemId, 'v1|110589358256|0');
    assert.equal(dto.condition, 'New');
    assert.equal(dto.shortDescription, 'Sealed blind box.');
    assert.equal(dto.seller?.username, 'seller_one');
    assert.equal(dto.seller?.feedbackPercentage, '99.2');
    assert.equal(dto.shipping?.summary, 'Free shipping · Standard Shipping');
    assert.equal(
      dto.imageUrl,
      'https://i.ebayimg.com/images/g/abc/s-l1600.jpg',
    );
    assert.ok(dto.listingUrl.includes('110589358256'));
  });
});

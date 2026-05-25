'use strict';

const { describe, it } = require('node:test');
const assert = require('node:assert/strict');
const {
  pickBestEbayImageUrl,
  upgradeEbayImageUrl,
} = require('../lib/providers/gateway/ebayImageUrl');

describe('upgradeEbayImageUrl', () => {
  it('upgrades browse thumbs to s-l500', () => {
    const url =
      'https://i.ebayimg.com/images/g/abc/s-l225.jpg';
    assert.equal(
      upgradeEbayImageUrl(url, 'browse'),
      'https://i.ebayimg.com/images/g/abc/s-l500.jpg',
    );
  });

  it('upgrades detail thumbs to s-l1600', () => {
    const url =
      'https://i.ebayimg.com/images/g/abc/s-l500.jpg';
    assert.equal(
      upgradeEbayImageUrl(url, 'detail'),
      'https://i.ebayimg.com/images/g/abc/s-l1600.jpg',
    );
  });
});

describe('pickBestEbayImageUrl', () => {
  it('prefers the largest s-l token', () => {
    const raw = {
      thumbnailImages: [
        { imageUrl: 'https://i.ebayimg.com/a/s-l225.jpg' },
        { imageUrl: 'https://i.ebayimg.com/b/s-l500.jpg' },
      ],
    };
    assert.equal(
      pickBestEbayImageUrl(raw),
      'https://i.ebayimg.com/b/s-l500.jpg',
    );
  });
});

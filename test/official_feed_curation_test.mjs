import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import {
  bodyHasUnavailableCopy,
  collectAsyncCurationIssues,
  extractCandidateImagesFromHtml,
  imageMatchesCandidates,
  isPopMartUsProductSpaShell,
  titleAppearsInBody,
} from '../tools/official_feed/official_feed_curation.mjs';
import {
  CURATION_OVERRIDE_RESELLER,
  hasResellerImageOverride,
  imageHostTier,
  isBatchCarouselImageUrl,
  isOfficialInstagramPostUrl,
  isResellerImageHost,
  itemIdEndsWithProductId,
  parseSummaryReleaseDate,
  productIdFromOfficialUrl,
  summaryPublishedAtDateDriftDays,
  validateOfficialFeedSeed,
  validateOfficialFeedSeedsNoDuplicateIds,
  isValidOfficialFeedDestinationUrl,
} from '../tools/official_feed/seed_validation.mjs';

describe('seed_validation curation sync rules', () => {
  const baseItem = {
    id: 'popmart_us_test_product_1234',
    title: 'Test Product',
    imageUrl: 'https://cdn-global.popmart.com/nas/images/content/example/product.png',
    officialUrl: 'https://www.popmart.com/us/products/1234/test-product',
    publishedAt: '2026-06-01T12:00:00Z',
    status: 'active',
    releaseType: 'product',
    productId: '1234',
    productIdConfirmed: true,
  };

  it('rejects reseller image without curationOverride', () => {
    const seed = {
      sourceId: 'popmart_us',
      items: [
        {
          ...baseItem,
          imageUrl: 'https://whoopea.com/cdn/shop/files/product.jpg',
        },
      ],
    };
    const result = validateOfficialFeedSeed(seed);
    assert.equal(result.ok, false);
    assert.ok(result.errors.some((e) => e.includes('reseller host')));
  });

  it('allows reseller image with curationOverride', () => {
    const seed = {
      sourceId: 'popmart_us',
      items: [
        {
          ...baseItem,
          imageUrl: 'https://whoopea.com/cdn/shop/files/product.jpg',
          curationOverride: CURATION_OVERRIDE_RESELLER,
        },
      ],
    };
    const result = validateOfficialFeedSeed(seed);
    assert.equal(result.ok, true);
    assert.ok(result.warnings.some((w) => w.includes('curationOverride')));
  });

  it('rejects batch carousel A_/B_/C_ filenames', () => {
    assert.equal(
      isBatchCarouselImageUrl(
        'https://cdn.shopify.com/s/files/1/0737/5506/6686/files/B_abc.webp',
      ),
      true,
    );
    const seed = {
      sourceId: 'popmart_us',
      items: [
        {
          ...baseItem,
          imageUrl:
            'https://cdn.shopify.com/s/files/1/0737/5506/6686/files/B_abc.webp',
        },
      ],
    };
    const result = validateOfficialFeedSeed(seed);
    assert.equal(result.ok, false);
    assert.ok(result.errors.some((e) => e.includes('batch/carousel')));
  });

  it('classifies image host tiers', () => {
    assert.equal(
      imageHostTier('https://cdn-global.popmart.com/nas/foo.png'),
      'official',
    );
    assert.equal(
      imageHostTier(
        'https://cdn.shopify.com/s/files/1/0737/5506/6686/files/x.webp',
      ),
      'shopify_official',
    );
    assert.equal(imageHostTier('https://toysez.com/cdn/shop/files/x.jpg'), 'reseller');
    assert.ok(isResellerImageHost('toysez.com'));
  });

  it('requires productId and matching id suffix when productId is set', () => {
    const seed = {
      sourceId: 'popmart_us',
      items: [
        {
          ...baseItem,
          id: 'popmart_us_wrong_suffix_9999',
          productId: '1234',
        },
      ],
    };
    const result = validateOfficialFeedSeed(seed);
    assert.equal(result.ok, false);
    assert.ok(result.errors.some((e) => e.includes('must end with "_1234"')));
  });

  it('does not warn when summary release date differs from announcement publishedAt', () => {
    const seed = {
      sourceId: 'popmart_us',
      items: [
        {
          ...baseItem,
          summary: 'Blind box figures — online June 5, 7:00 PM PT',
          publishedAt: '2026-05-29T00:00:00Z',
        },
      ],
    };
    const result = validateOfficialFeedSeed(seed);
    assert.ok(
      !result.warnings.some((w) => w.includes('summary date and publishedAt')),
    );
  });

  it('parses summary release dates for curator helpers', () => {
    assert.equal(
      summaryPublishedAtDateDriftDays(
        'Blind box figures — online June 4, 7:00 PM PT',
        '2026-06-05T11:00:00Z',
      ),
      1,
    );
    assert.equal(parseSummaryReleaseDate('online June 5, 7:00 PM PT')?.day, 5);
  });

  it('extracts productId from officialUrl', () => {
    assert.equal(
      productIdFromOfficialUrl(
        'https://www.popmart.com/us/products/6267/hirono-behind-time-figure',
      ),
      '6267',
    );
    assert.equal(itemIdEndsWithProductId('popmart_us_hirono_behind_time_6267', '6267'), true);
  });

  it('allows official Instagram post as officialUrl without productId', () => {
    assert.equal(
      isOfficialInstagramPostUrl(new URL('https://www.instagram.com/p/DZhdyd6m984/')),
      true,
    );
    const seed = {
      sourceId: 'popmart_us',
      items: [
        {
          id: 'popmart_us_monsters_fifa_world_cup_2026',
          title: 'THE MONSTERS × FIFA World Cup 2026',
          summary: 'Official FIFA World Cup collaboration announcement.',
          imageUrl:
            'https://scontent.cdninstagram.com/v/t51.82787-15/example_n.jpg',
          officialUrl: 'https://www.instagram.com/p/DZhdyd6m984/',
          publishedAt: '2026-05-29T00:00:00Z',
          status: 'active',
        },
      ],
    };
    const result = validateOfficialFeedSeed(seed);
    assert.equal(result.ok, true);
  });

  it('hasResellerImageOverride only accepts reseller_image_ok', () => {
    assert.equal(hasResellerImageOverride({ curationOverride: 'reseller_image_ok' }), true);
    assert.equal(hasResellerImageOverride({ curationOverride: 'other' }), false);
    const seed = {
      sourceId: 'popmart_us',
      items: [{ ...baseItem, curationOverride: 'bogus' }],
    };
    const result = validateOfficialFeedSeed(seed);
    assert.ok(result.errors.some((e) => e.includes('unknown curationOverride')));
  });
});

describe('official_feed_curation helpers', () => {
  it('detects unavailable copy case-insensitively', () => {
    assert.equal(
      bodyHasUnavailableCopy('The product you are looking for is not available'),
      true,
    );
    assert.equal(bodyHasUnavailableCopy('Welcome to POP MART'), false);
    // Live upcoming PDPs still embed i18n catalogs — must not false-positive.
    assert.equal(
      bodyHasUnavailableCopy(
        '{"product_empty_text":"The product you are looking for is not available","product_not_found":"Product Not Found","back_to_homepage":"BACK TO HOMEPAGE"}',
      ),
      false,
    );
  });

  it('extracts og:image and cdn-global from HTML', () => {
    const html = `
      <meta property="og:image" content="https://cdn-global.popmart.com/nas/a.png" />
      <img src="https://cdn-global.popmart.com/nas/b.jpg" />
    `;
    const candidates = extractCandidateImagesFromHtml(html, 'https://www.popmart.com/us/products/1/x');
    assert.ok(candidates.some((c) => c.includes('a.png')));
  });

  it('imageMatchesCandidates compares basename and normalized URL', () => {
    const candidates = ['https://cdn-global.popmart.com/nas/foo.png?v=1'];
    assert.equal(
      imageMatchesCandidates('https://cdn-global.popmart.com/nas/foo.png', candidates),
      true,
    );
  });

  it('detects POP MART US product SPA shell', () => {
    const shell = `<!DOCTYPE html><html><head></head><body>
      <script id="__NEXT_DATA__" type="application/json">{"props":{"pageProps":{}},"page":"/products/[...queryParams]","query":{}}</script>
    </body></html>`;
    assert.equal(isPopMartUsProductSpaShell(shell), true);
    assert.equal(isPopMartUsProductSpaShell('<html>real product page</html>'), false);
  });

  it('errors on phantom product id acceptance without productIdConfirmed', () => {
    const item = {
      id: 'popmart_us_hirono_behind_time_6440',
      title: 'Hirono Behind Time Figure',
      productId: '6440',
      officialUrl: 'https://www.popmart.com/us/products/6440/hirono-behind-time-figure',
      imageUrl: 'https://cdn-global.popmart.com/nas/foo.png',
    };
    const pageProbe = {
      ok: true,
      status: 200,
      redirectChain: [],
      body: '{"props":{"pageProps":{}}}',
      candidates: [],
      spaShell: true,
      unavailableCopy: false,
      finalUrl: item.officialUrl,
      finalParsed: new URL(item.officialUrl),
    };
    const issues = collectAsyncCurationIssues(item, 0, pageProbe, { ok: true }, {
      acceptsPhantomProductId: true,
    });
    assert.ok(
      issues.some(
        (i) => i.level === 'error' && i.message.includes('phantom product ids'),
      ),
    );
  });

  it('titleAppearsInBody matches POP NOW set pages', () => {
    const body = 'Twinkle Twinkle Create Your Taste Series Figures - A $13.99';
    assert.equal(
      titleAppearsInBody('Twinkle Twinkle Create Your Taste Series Figures — A', body),
      true,
    );
  });
});

describe('multi-brand seed destination gates', () => {
  it('rejects unknown sourceId as an error', () => {
    const result = validateOfficialFeedSeed({
      sourceId: 'unknown_brand',
      items: [
        {
          id: 'x_1',
          title: 'X',
          imageUrl: 'https://cdn.example.com/a.png',
          officialUrl: 'https://www.instagram.com/p/Abc123def/',
          publishedAt: '2026-07-01T00:00:00Z',
          status: 'active',
        },
      ],
    });
    assert.equal(result.ok, false);
    assert.ok(result.errors.some((e) => e.includes('Unknown sourceId')));
  });

  it('rejects unknown brand destinations and unsupported IG paths', () => {
    assert.equal(
      isValidOfficialFeedDestinationUrl(
        new URL('https://www.instagram.com/p/Abc123def/'),
        'unknown_brand',
      ),
      false,
    );
    assert.equal(
      isValidOfficialFeedDestinationUrl(
        new URL('https://www.instagram.com/stories/user/1'),
        'tntspace_us',
      ),
      false,
    );
    assert.equal(
      isValidOfficialFeedDestinationUrl(
        new URL('https://gotoptoy.com/us'),
        'toptoy_us',
      ),
      false,
    );
    assert.equal(
      isValidOfficialFeedDestinationUrl(
        new URL('https://www.tntspace.com/us/products/a'),
        'tntspace_us',
      ),
      true,
    );
  });

  it('rejects duplicate ids across curated brand seeds', () => {
    const result = validateOfficialFeedSeedsNoDuplicateIds([
      {
        path: 'tntspace_us.seed.json',
        seed: {
          sourceId: 'tntspace_us',
          items: [{ id: 'shared_id', title: 'A' }],
        },
      },
      {
        path: 'toptoy_us.seed.json',
        seed: {
          sourceId: 'toptoy_us',
          items: [{ id: 'shared_id', title: 'B' }],
        },
      },
    ]);
    assert.equal(result.ok, false);
    assert.ok(result.errors.some((e) => e.includes('shared_id')));
  });

  it('accepts current curated seeds without cross-seed id collisions', async () => {
    const { readFileSync } = await import('node:fs');
    const { dirname, join } = await import('node:path');
    const { fileURLToPath } = await import('node:url');
    const root = join(dirname(fileURLToPath(import.meta.url)), '..');
    const seeds = ['popmart_us', 'tntspace_us', 'toptoy_us'].map((id) => {
      const path = join(root, 'tools/official_feed', `${id}.seed.json`);
      return { path, seed: JSON.parse(readFileSync(path, 'utf8')) };
    });
    for (const entry of seeds) {
      const one = validateOfficialFeedSeed(entry.seed);
      assert.equal(one.ok, true, `${entry.path}: ${one.errors.join('; ')}`);
    }
    const cross = validateOfficialFeedSeedsNoDuplicateIds(seeds);
    assert.equal(cross.ok, true, cross.errors.join('; '));
  });

  it('rejects blank ids, invalid dates, duplicate images and destinations', () => {
    const base = {
      id: 'popmart_us_ok_1',
      title: 'Ok',
      imageUrl: 'https://cdn-global.popmart.com/nas/images/content/a.png',
      officialUrl: 'https://www.popmart.com/us/products/1/a',
      publishedAt: '2026-07-01T00:00:00Z',
      status: 'active',
      productId: '1',
      productIdConfirmed: true,
    };

    let result = validateOfficialFeedSeed({
      sourceId: 'popmart_us',
      items: [{ ...base, id: '   ' }],
    });
    assert.equal(result.ok, false);
    assert.ok(result.errors.some((e) => e.includes('missing id')));

    result = validateOfficialFeedSeed({
      sourceId: 'popmart_us',
      items: [{ ...base, publishedAt: 'not-a-date' }],
    });
    assert.equal(result.ok, false);
    assert.ok(result.errors.some((e) => e.includes('publishedAt')));

    result = validateOfficialFeedSeed({
      sourceId: 'popmart_us',
      items: [
        base,
        {
          ...base,
          id: 'popmart_us_item_2',
          productId: '2',
          officialUrl: 'https://www.popmart.com/us/products/2/b',
          imageUrl: base.imageUrl,
        },
      ],
    });
    assert.equal(result.ok, false);
    assert.ok(result.errors.some((e) => e.includes('duplicate imageUrl')));

    result = validateOfficialFeedSeed({
      sourceId: 'toptoy_us',
      items: [
        {
          id: 'tt_a',
          title: 'A',
          imageUrl: 'https://cdn.example.com/a.png',
          officialUrl: 'https://gotoptoy.com/products/a',
          publishedAt: '2026-07-01T00:00:00Z',
          status: 'active',
        },
        {
          id: 'tt_b',
          title: 'B',
          imageUrl: 'https://cdn.example.com/b.png',
          officialUrl: 'https://gotoptoy.com/products/a',
          publishedAt: '2026-07-02T00:00:00Z',
          status: 'active',
        },
      ],
    });
    assert.equal(result.ok, false);
    assert.ok(result.errors.some((e) => e.includes('duplicate officialUrl')));
  });
});

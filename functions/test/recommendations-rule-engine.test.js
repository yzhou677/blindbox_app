import { test } from 'node:test';
import assert from 'node:assert/strict';
import { computeRecommendations } from '../lib/recommendations/ruleEngine.js';

test('computeRecommendations ranks owned IP matches and excludes owned series', () => {
  const items = computeRecommendations({
    profile: {
      installId: 'install-1',
      ownedCatalogSeriesIds: ['dimoo_owned'],
      wishlistCatalogSeriesIds: [],
      ownedIpIds: ['dimoo'],
      wishlistIpIds: [],
      profileHash: 'hash',
    },
    series: [
      {
        id: 'dimoo_owned',
        ipId: 'dimoo',
        displayName: 'Dimoo Owned',
        releaseDate: '2026-01-01',
      },
      {
        id: 'dimoo_new',
        ipId: 'dimoo',
        displayName: 'Dimoo New',
        releaseDate: '2026-05-01',
      },
      {
        id: 'labubu_gap',
        ipId: 'labubu',
        displayName: 'Labubu Gap',
        releaseDate: '2026-04-01',
      },
    ],
    ips: [
      { id: 'dimoo', displayName: 'DIMOO' },
      { id: 'labubu', displayName: 'LABUBU' },
    ],
    now: new Date('2026-05-21T00:00:00.000Z'),
  });

  assert.ok(items.some((item) => item.seriesId === 'dimoo_new'));
  assert.equal(
    items.find((item) => item.seriesId === 'dimoo_new')?.reasonType,
    'recent_release',
  );
  assert.equal(
    items.some((item) => item.seriesId === 'dimoo_owned'),
    false,
  );
});

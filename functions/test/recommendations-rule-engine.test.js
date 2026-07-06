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

test('computeRecommendations caps at 10 curated picks', () => {
  const series = Array.from({ length: 30 }, (_, i) => ({
    id: `series_${i}`,
    ipId: 'dimoo',
    displayName: `Series ${i}`,
    releaseDate: `2026-05-${String((i % 28) + 1).padStart(2, '0')}`,
  }));

  const items = computeRecommendations({
    profile: {
      installId: 'install-1',
      ownedCatalogSeriesIds: [],
      wishlistCatalogSeriesIds: [],
      ownedIpIds: [],
      wishlistIpIds: [],
      profileHash: 'hash',
    },
    series,
    ips: [{ id: 'dimoo', displayName: 'DIMOO' }],
    now: new Date('2026-05-21T00:00:00.000Z'),
  });

  assert.equal(items.length, 10);
});

test('computeRecommendations keeps stable top picks and rotates exploration', () => {
  const series = Array.from({ length: 15 }, (_, i) => ({
    id: `labubu_${i}`,
    ipId: 'labubu',
    displayName: `Labubu ${i}`,
    releaseDate: `2026-05-${String(15 - i).padStart(2, '0')}`,
  }));

  const profile = {
    installId: 'install-1',
    ownedCatalogSeriesIds: ['labubu_0'],
    wishlistCatalogSeriesIds: [],
    ownedIpIds: ['labubu'],
    wishlistIpIds: [],
    profileHash: 'profile-hash',
  };

  const run = (now) =>
    computeRecommendations({
      profile,
      series,
      ips: [{ id: 'labubu', displayName: 'LABUBU' }],
      now,
    });

  const weekA = run(new Date('2026-05-21T00:00:00.000Z'));
  const weekB = run(new Date('2026-05-28T00:00:00.000Z'));
  const stableA = weekA.slice(0, 8).map((item) => item.seriesId);
  const stableB = weekB.slice(0, 8).map((item) => item.seriesId);

  assert.deepEqual(stableA, stableB);
  assert.deepEqual(
    stableA,
    Array.from({ length: 8 }, (_, i) => `labubu_${i + 1}`),
  );
  assert.notDeepEqual(
    weekA.slice(8).map((item) => item.seriesId),
    weekB.slice(8).map((item) => item.seriesId),
  );
});

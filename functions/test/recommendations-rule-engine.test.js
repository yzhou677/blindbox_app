import { test } from 'node:test';
import assert from 'node:assert/strict';
import { computeRecommendations } from '../lib/recommendations/ruleEngine.js';

test('computeRecommendations ranks tracked IP matches and excludes tracked series', () => {
  const items = computeRecommendations({
    profile: {
      installId: 'install-1',
      trackedCatalogSeriesIds: ['dimoo_owned'],
      ownedCatalogSeriesIds: ['dimoo_owned'],
      wishlistCatalogSeriesIds: [],
      trackedIpIds: ['dimoo'],
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

test('computeRecommendations limits scored picks to two per IP', () => {
  const series = [
    ...Array.from({ length: 6 }, (_, i) => ({
      id: `labubu_${i + 1}`,
      ipId: 'labubu',
      displayName: `Labubu ${i + 1}`,
      releaseDate: `2026-05-${String(i + 1).padStart(2, '0')}`,
    })),
    { id: 'dimoo_1', ipId: 'dimoo', displayName: 'Dimoo 1', releaseDate: '2026-04-01' },
    { id: 'crybaby_1', ipId: 'crybaby', displayName: 'Crybaby 1', releaseDate: '2026-04-02' },
    { id: 'nommi_1', ipId: 'nommi', displayName: 'Nommi 1', releaseDate: '2026-04-03' },
    { id: 'molly_1', ipId: 'molly', displayName: 'Molly 1', releaseDate: '2026-04-04' },
  ];

  const items = computeRecommendations({
    profile: {
      installId: 'install-1',
      trackedCatalogSeriesIds: [],
      ownedCatalogSeriesIds: [],
      wishlistCatalogSeriesIds: [],
      trackedIpIds: ['labubu'],
      wishlistIpIds: [],
      profileHash: 'hash',
    },
    series,
    ips: [
      { id: 'labubu', displayName: 'LABUBU' },
      { id: 'dimoo', displayName: 'DIMOO' },
      { id: 'crybaby', displayName: 'CRYBABY' },
      { id: 'nommi', displayName: 'NOMMI' },
      { id: 'molly', displayName: 'MOLLY' },
    ],
    now: new Date('2026-05-21T00:00:00.000Z'),
  });

  const ipCounts = new Map();
  for (const item of items) {
    const ipId = item.seriesId.startsWith('labubu_')
      ? 'labubu'
      : item.seriesId.split('_')[0];
    ipCounts.set(ipId, (ipCounts.get(ipId) ?? 0) + 1);
  }
  for (const count of ipCounts.values()) {
    assert.ok(count <= 2);
  }
  assert.equal(ipCounts.get('labubu'), 2);
  assert.ok(items.some((item) => item.seriesId === 'labubu_6'));
  assert.ok(items.some((item) => item.seriesId === 'labubu_5'));
  assert.equal(items.some((item) => item.seriesId === 'labubu_4'), false);
});

test('computeRecommendations caps scored picks at 10 without gap fill', () => {
  const series = Array.from({ length: 10 }, (__, ip) =>
    Array.from({ length: 3 }, (_, i) => ({
      id: `series_${ip}_${i}`,
      ipId: `ip_${ip}`,
      displayName: `Series ${ip}-${i}`,
      releaseDate: `2026-05-${String(ip * 3 + i + 1).padStart(2, '0')}`,
    })),
  ).flat();

  const items = computeRecommendations({
    profile: {
      installId: 'install-1',
      trackedCatalogSeriesIds: [],
      ownedCatalogSeriesIds: [],
      wishlistCatalogSeriesIds: [],
      trackedIpIds: Array.from({ length: 10 }, (_, i) => `ip_${i}`),
      wishlistIpIds: [],
      profileHash: 'hash',
    },
    series,
    ips: Array.from({ length: 10 }, (_, i) => ({
      id: `ip_${i}`,
      displayName: `IP ${i}`,
    })),
    now: new Date('2026-05-21T00:00:00.000Z'),
  });

  assert.equal(items.length, 10);
  assert.equal(
    items.some((item) => item.reasonType === 'new_in_catalog'),
    false,
  );
});

test('computeRecommendations gap fills only to minimum without scored picks', () => {
  const series = Array.from({ length: 5 }, (_, i) => ({
    id: `series_${i}`,
    ipId: `ip_${i}`,
    displayName: `Series ${i}`,
    releaseDate: `2026-05-${String(5 - i).padStart(2, '0')}`,
  }));

  const items = computeRecommendations({
    profile: {
      installId: 'install-1',
      trackedCatalogSeriesIds: [],
      ownedCatalogSeriesIds: [],
      wishlistCatalogSeriesIds: [],
      trackedIpIds: [],
      wishlistIpIds: [],
      profileHash: 'hash',
    },
    series,
    ips: Array.from({ length: 5 }, (_, i) => ({
      id: `ip_${i}`,
      displayName: `IP ${i}`,
    })),
    now: new Date('2026-05-21T00:00:00.000Z'),
  });

  assert.equal(items.length, 5);
  assert.equal(
    items.every((item) => item.reasonType === 'new_in_catalog'),
    true,
  );
});

test('computeRecommendations keeps stable top picks; exploration follows profile and catalog', () => {
  const series = Array.from({ length: 10 }, (__, ip) =>
    Array.from({ length: 2 }, (_, i) => ({
      id: `ip${ip}_${i}`,
      ipId: `ip_${ip}`,
      displayName: `IP ${ip} series ${i}`,
      releaseDate: `2026-05-${String(20 - ip * 2 - i).padStart(2, '0')}`,
    })),
  ).flat();

  const profileFor = (profileHash) => ({
    installId: 'install-1',
    trackedCatalogSeriesIds: [],
    ownedCatalogSeriesIds: [],
    wishlistCatalogSeriesIds: [],
    trackedIpIds: Array.from({ length: 10 }, (_, i) => `ip_${i}`),
    wishlistIpIds: [],
    profileHash,
  });

  const run = ({ profile, seriesList, now = new Date('2026-05-21T00:00:00.000Z') }) =>
    computeRecommendations({
      profile,
      series: seriesList,
      ips: Array.from({ length: 10 }, (_, i) => ({
        id: `ip_${i}`,
        displayName: `IP ${i}`,
      })),
      now,
    });

  const baseline = run({ profile: profileFor('profile-hash'), seriesList: series });
  const stable = baseline.slice(0, 8).map((item) => item.seriesId);
  const explore = baseline.slice(8).map((item) => item.seriesId);

  assert.equal(baseline.length, 10);
  assert.equal(stable.length, 8);
  assert.equal(explore.length, 2);

  assert.deepEqual(
    run({
      profile: profileFor('profile-hash'),
      seriesList: series,
      now: new Date('2026-06-02T00:00:00.000Z'),
    })
      .slice(8)
      .map((item) => item.seriesId),
    explore,
  );

  assert.notDeepEqual(
    run({ profile: profileFor('profile-hash-v2'), seriesList: series })
      .slice(8)
      .map((item) => item.seriesId),
    explore,
  );

  assert.notDeepEqual(
    run({
      profile: profileFor('profile-hash'),
      seriesList: [
        ...series,
        {
          id: 'ip_new_drop',
          ipId: 'ip_9',
          displayName: 'IP 9 new',
          releaseDate: '2026-06-01',
        },
      ],
    })
      .slice(8)
      .map((item) => item.seriesId),
    explore,
  );
});

test('computeRecommendations breaks score ties by newest release date', () => {
  const items = computeRecommendations({
    profile: {
      installId: 'install-1',
      trackedCatalogSeriesIds: ['dimoo_owned'],
      ownedCatalogSeriesIds: ['dimoo_owned'],
      wishlistCatalogSeriesIds: [],
      trackedIpIds: ['dimoo'],
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
        id: 'dimoo_older',
        ipId: 'dimoo',
        displayName: 'Dimoo Older',
        releaseDate: '2026-03-01',
      },
      {
        id: 'dimoo_newer',
        ipId: 'dimoo',
        displayName: 'Dimoo Newer',
        releaseDate: '2026-05-01',
      },
    ],
    ips: [{ id: 'dimoo', displayName: 'DIMOO' }],
    now: new Date('2026-05-21T00:00:00.000Z'),
  });

  assert.deepEqual(
    items.map((item) => item.seriesId),
    ['dimoo_newer', 'dimoo_older'],
  );
});

test('computeRecommendations excludes shelf-tracked series without owned figures', () => {
  const items = computeRecommendations({
    profile: {
      installId: 'install-1',
      trackedCatalogSeriesIds: ['dimoo_owned'],
      ownedCatalogSeriesIds: [],
      wishlistCatalogSeriesIds: [],
      trackedIpIds: [],
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
    ],
    ips: [{ id: 'dimoo', displayName: 'DIMOO' }],
    now: new Date('2026-05-21T00:00:00.000Z'),
  });

  assert.equal(items.some((item) => item.seriesId === 'dimoo_owned'), false);
  assert.ok(items.some((item) => item.seriesId === 'dimoo_new'));
});

test('computeRecommendations gap fill randomizes within recent pool', () => {
  const series = Array.from({ length: 25 }, (_, i) => ({
    id: `series_${i}`,
    ipId: `ip_${i}`,
    displayName: `Series ${i}`,
    releaseDate: `2026-05-${String(25 - i).padStart(2, '0')}`,
  }));

  const profileFor = (profileHash) => ({
    installId: 'install-1',
    trackedCatalogSeriesIds: [],
    ownedCatalogSeriesIds: [],
    wishlistCatalogSeriesIds: [],
    trackedIpIds: [],
    wishlistIpIds: [],
    profileHash,
  });

  const run = (profileHash) =>
    computeRecommendations({
      profile: profileFor(profileHash),
      series,
      ips: Array.from({ length: 25 }, (_, i) => ({
        id: `ip_${i}`,
        displayName: `IP ${i}`,
      })),
      now: new Date('2026-05-21T00:00:00.000Z'),
    });

  const stable = run('profile-gap-fill');
  const repeat = run('profile-gap-fill');
  const alternate = run('profile-gap-fill-v2');

  assert.deepEqual(
    stable.map((item) => item.seriesId),
    repeat.map((item) => item.seriesId),
  );
  assert.equal(stable.length, 5);
  for (const item of stable) {
    const index = Number(item.seriesId.split('_')[1]);
    assert.ok(index < 20);
  }
  assert.notDeepEqual(
    alternate.map((item) => item.seriesId),
    stable.map((item) => item.seriesId),
  );
});

test('computeRecommendations skips gap fill when diversified scored picks reach minimum', () => {
  const series = ['labubu', 'dimoo', 'crybaby'].flatMap((ip) =>
    Array.from({ length: 3 }, (_, i) => ({
      id: `${ip}_${i}`,
      ipId: ip,
      displayName: `${ip} ${i}`,
      releaseDate: `2026-05-${String(9 - i).padStart(2, '0')}`,
    })),
  );

  const items = computeRecommendations({
    profile: {
      installId: 'install-1',
      trackedCatalogSeriesIds: ['labubu_0', 'dimoo_0', 'crybaby_0'],
      ownedCatalogSeriesIds: ['labubu_0', 'dimoo_0', 'crybaby_0'],
      wishlistCatalogSeriesIds: [],
      trackedIpIds: ['labubu', 'dimoo', 'crybaby'],
      wishlistIpIds: [],
      profileHash: 'hash',
    },
    series,
    ips: [
      { id: 'labubu', displayName: 'LABUBU' },
      { id: 'dimoo', displayName: 'DIMOO' },
      { id: 'crybaby', displayName: 'CRYBABY' },
    ],
    now: new Date('2026-05-21T00:00:00.000Z'),
  });

  assert.equal(items.length, 6);
  assert.equal(
    items.some((item) => item.reasonType === 'new_in_catalog'),
    false,
  );
});

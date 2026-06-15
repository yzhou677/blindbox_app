import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { describe, test } from 'node:test';
import { fileURLToPath } from 'node:url';

import {
  DEFAULT_MATCH_THRESHOLD,
  buildMatcherContext,
  matchCatalogFigure,
} from './_catalog_matcher.mjs';
import { normalizeMarketTitle } from './_title_normalizer.mjs';

const __dirname = dirname(fileURLToPath(import.meta.url));
const repoRoot = join(__dirname, '..', '..');

const brandPopMart = {
  id: 'pop_mart',
  displayName: 'POP MART',
  aliases: ['POPMART'],
};

const ipTheMonsters = {
  id: 'the_monsters',
  displayName: 'The Monsters',
  aliases: ['Labubu', 'Monsters'],
};

const seriesBigIntoEnergy = {
  id: 'the_monsters_big_into_energy_vinyl_plush_pendant',
  displayName:
    'THE MONSTERS Big into Energy Series-Vinyl Plush Pendant Blind Box',
  aliases: [
    'THE MONSTERS Big into Energy Series-',
    'the monsters big into energy vinyl plush pendant',
  ],
};

const figureLuck = {
  id: 'the_monsters_big_into_energy_vinyl_plush_pendant_luck',
  displayName: 'Luck',
  seriesId: seriesBigIntoEnergy.id,
  brandId: brandPopMart.id,
  isSecret: false,
};

const figureHope = {
  id: 'the_monsters_big_into_energy_vinyl_plush_pendant_hope',
  displayName: 'Hope',
  seriesId: seriesBigIntoEnergy.id,
  brandId: brandPopMart.id,
  isSecret: false,
};

const figureIdSecret = {
  id: 'the_monsters_big_into_energy_vinyl_plush_pendant_id',
  displayName: 'Id',
  seriesId: seriesBigIntoEnergy.id,
  brandId: brandPopMart.id,
  isSecret: true,
};

const siblingFigures = [
  figureHope,
  {
    id: 'the_monsters_big_into_energy_vinyl_plush_pendant_serenity',
    displayName: 'Serenity',
  },
  {
    id: 'the_monsters_big_into_energy_vinyl_plush_pendant_loyalty',
    displayName: 'Loyalty',
  },
  {
    id: 'the_monsters_big_into_energy_vinyl_plush_pendant_happiness',
    displayName: 'Happiness',
  },
  {
    id: 'the_monsters_big_into_energy_vinyl_plush_pendant_love',
    displayName: 'Love',
  },
  figureIdSecret,
];

const conflictingSeriesFixtures = [
  {
    id: 'the_monsters_have_a_seat_vinyl_plush',
    displayName: 'THE MONSTERS - Have a Seat Vinyl Plush Blind Box',
    aliases: ['the monsters have a seat vinyl plush'],
  },
  {
    id: 'the_monsters_exciting_macaron_vinyl_face',
    displayName: 'THE MONSTERS Exciting Macaron Vinyl Face Blind Box',
    aliases: ['the monsters exciting macaron vinyl face'],
  },
  {
    id: 'pop_mart_x_sweet_bean_i_want_a_hug_series',
    displayName: 'POP MART x Sweet Bean I Want a Hug Series',
    aliases: ['sweet bean'],
  },
  {
    id: 'charlotte_series',
    displayName: 'Charlotte Series',
    aliases: ['charlotte series'],
  },
  seriesBigIntoEnergy,
];

const luckyMetadata = {
  marketAliases: ['lucky', 'ラッキー', '幸运'],
  matchThreshold: null,
};

function buildLuckContext() {
  return buildMatcherContext({
    targetFigure: figureLuck,
    series: seriesBigIntoEnergy,
    brand: brandPopMart,
    ip: ipTheMonsters,
    siblingFigures,
    allSeries: conflictingSeriesFixtures,
  });
}

function buildIdSecretContext() {
  return buildMatcherContext({
    targetFigure: figureIdSecret,
    series: seriesBigIntoEnergy,
    brand: brandPopMart,
    ip: ipTheMonsters,
    siblingFigures: siblingFigures.filter(
      (figure) => figure.id !== figureIdSecret.id,
    ),
    allSeries: conflictingSeriesFixtures,
  });
}

function matchRaw(rawTitle, context = buildLuckContext(), metadata = luckyMetadata) {
  return matchCatalogFigure(normalizeMarketTitle(rawTitle), context, metadata);
}

describe('buildMatcherContext', () => {
  test('derives sibling and conflicting series phrases from catalog records', () => {
    const context = buildLuckContext();
    assert.equal(context.figureId, figureLuck.id);
    assert.ok(context.siblingFigureTokens.includes('hope'));
    assert.ok(
      context.conflictingSeries.some((entry) =>
        entry.phrases.some((phrase) => phrase.includes('have a seat')),
      ),
    );
  });

  test('seriesDistinctivePhrase is catalog-derived for Big Into Energy', () => {
    const context = buildLuckContext();
    assert.equal(context.seriesDistinctivePhrase, 'big into energy');
  });

  test('ipAnchorTokens are catalog-derived (no hardcoded SERIES_IP_ANCHORS)', () => {
    const context = buildLuckContext();
    // The Monsters IP: displayName "The Monsters", aliases ["Labubu", "Monsters"]
    assert.ok(context.ipAnchorTokens.includes('the monsters'));
    assert.ok(context.ipAnchorTokens.includes('labubu'));
    assert.ok(context.ipAnchorTokens.includes('monsters'));
    // Must NOT contain tokens from other IPs
    assert.ok(!context.ipAnchorTokens.includes('skullpanda'));
  });
});

describe('matchCatalogFigure — Lucky positive matches', () => {
  test('accepts canonical marketplace Lucky title', () => {
    const result = matchRaw(
      'POP MART THE MONSTERS Big Into Energy Lucky Vinyl Plush Figure',
    );
    assert.equal(result.matched, true);
    assert.equal(result.figureId, figureLuck.id);
    assert.equal(result.rejectReason, null);
    assert.ok(result.score >= 0.75);
    assert.ok(result.reasons.includes('brandMatch'));
    assert.ok(result.reasons.includes('seriesMatch:full'));
    assert.ok(result.reasons.some((r) => r.startsWith('marketAliasMatch:')));
    assert.ok(result.reasons.includes('accepted'));
  });

  test('accepts catalog displayName token luck', () => {
    const result = matchRaw(
      'POP MART THE MONSTERS Luck Big Into Energy Vinyl Plush',
    );
    assert.equal(result.matched, true);
    assert.ok(result.reasons.includes('figureNameMatch'));
    assert.equal(result.score, 0.9);
  });

  test('accepts POPMART spelling and labubu market alias bonus', () => {
    const result = matchRaw(
      'POPMART Labubu Big Into Energy Lucky Confirmed Figure',
    );
    assert.equal(result.matched, true);
    assert.equal(result.score, 1);
    assert.ok(result.signals.marketAliasMatch);
  });
});

describe('matchCatalogFigure — hard rejects', () => {
  test('crossFigureContamination rejects lucky + hope', () => {
    const result = matchRaw(
      'POP MART Big Into Energy Lucky Hope Bundle 2 Figures',
    );
    assert.equal(result.matched, false);
    assert.equal(result.score, 0);
    assert.equal(result.rejectReason, 'crossFigureContamination');
    assert.ok(result.reasons.includes('hardReject:crossFigureContamination'));
    assert.equal(result.figureId, null);
  });

  test('wrongFigureName rejects Hope-only title for Luck target', () => {
    const result = matchRaw('POP MART Big Into Energy Hope Figure');
    assert.equal(result.rejectReason, 'wrongFigureName');
    assert.equal(result.score, 0);
  });

  test('secretMismatch rejects secret language on common Luck', () => {
    const result = matchRaw(
      'POP MART THE MONSTERS Lucky Secret Chase 隐藏 Big Into Energy',
    );
    assert.equal(result.rejectReason, 'secretMismatch');
    assert.equal(result.score, 0);
  });

  test('secretMismatch rejects Id secret target without secret indicators', () => {
    const result = matchCatalogFigure(
      'pop mart the monsters id big into energy vinyl plush',
      buildIdSecretContext(),
      { marketAliases: ['id'], matchThreshold: null },
    );
    assert.equal(result.rejectReason, 'secretMismatch');
  });

  test('seriesMismatch rejects Have a Seat series title', () => {
    const result = matchRaw(
      'POP MART Labubu Have a Seat Lucky Secret Figure',
    );
    assert.equal(result.rejectReason, 'seriesMismatch');
  });

  test('seriesMismatch rejects macaron series title', () => {
    const result = matchRaw('POP MART Macaron Series Labubu Figure');
    assert.equal(result.rejectReason, 'seriesMismatch');
  });

  test('productTypeReject rejects storage bag listing', () => {
    const result = matchRaw(
      'POP MART Authentic Twinkle Twinkle Wonderful Journey Storage Bag',
    );
    assert.equal(result.rejectReason, 'productTypeReject');
  });

  test('productTypeReject rejects storage bag even with Lucky name', () => {
    const result = matchRaw(
      'POP MART THE MONSTERS Lucky Big Into Energy Storage Bag',
    );
    assert.equal(result.rejectReason, 'productTypeReject');
  });

  test('productTypeReject rejects charm accessory listing', () => {
    const result = matchRaw(
      'POP MART THE MONSTERS Lucky Charm Strap Accessory',
    );
    assert.equal(result.rejectReason, 'productTypeReject');
  });
});

describe('matchCatalogFigure — threshold and gates', () => {
  test('rejects series-only title below threshold', () => {
    const result = matchRaw('POP MART Big Into Energy Figure');
    assert.equal(result.matched, false);
    assert.equal(result.rejectReason, 'gate:fullSeriesRequired');
    assert.ok(result.score < DEFAULT_MATCH_THRESHOLD);
    assert.ok(result.reasons.includes('gate:figureIdentityRequired'));
  });

  test('rejects missing brand even when figure and series match', () => {
    const result = matchCatalogFigure(
      'the monsters labubu lucky big into energy figure',
      buildLuckContext(),
      luckyMetadata,
    );
    assert.equal(result.matched, false);
    assert.equal(result.rejectReason, 'gate:brandRequired');
    assert.equal(result.score, 0.85);
  });

  test('rejects brand + figure without full series anchor', () => {
    const result = matchRaw('POP MART Lucky Figure');
    assert.equal(result.matched, false);
    assert.ok(result.reasons.includes('gate:fullSeriesRequired'));
  });

  test('respects per-figure matchThreshold override', () => {
    const title = normalizeMarketTitle(
      'POP MART THE MONSTERS Luck Big Into Energy Vinyl Plush',
    );
    const context = buildLuckContext();
    const permissive = matchCatalogFigure(title, context, {
      marketAliases: ['lucky'],
      matchThreshold: 0.85,
    });
    const strict = matchCatalogFigure(title, context, {
      marketAliases: ['lucky'],
      matchThreshold: 0.95,
    });
    assert.equal(permissive.matched, true);
    assert.equal(permissive.score, 0.9);
    assert.equal(strict.matched, false);
    assert.equal(strict.rejectReason, 'belowThreshold');
  });
});

describe('matchCatalogFigure — explainability', () => {
  test('surfaces signal breakdown and score on acceptance', () => {
    const result = matchRaw('POP MART Lucky Big Into Energy Figure');
    assert.ok(Array.isArray(result.reasons));
    assert.ok(result.reasons.length >= 5);
    assert.match(result.reasons.join(' '), /score=/);
    assert.match(result.reasons.join(' '), /threshold=/);
    assert.equal(typeof result.signals.brandMatch, 'boolean');
    assert.equal(typeof result.effectiveThreshold, 'number');
  });

  test('hard reject reasons remain inspectable with zero score', () => {
    const result = matchRaw(
      'POP MART Big Into Energy Lucky Hope Serenity Bundle',
    );
    assert.deepEqual(result.signals, {
      brandMatch: false,
      seriesMatchFull: false,
      seriesMatchPartial: false,
      seriesMatchScore: 0,
      figureNameMatch: false,
      marketAliasMatch: false,
      figureIdentityMatch: false,
      secretSignalConsistent: false,
      matchedMarketAliasTokens: [],
      matchedCatalogFigureTokens: [],
      matchedSiblingTokens: [],
    });
    assert.ok(result.reasons.some((r) => r.includes('hope')));
  });
});

describe('matchCatalogFigure — design matrix spot checks', () => {
  const matrix = [
    {
      title: 'POP MART THE MONSTERS Lucky Big Into Energy Figure',
      matched: true,
    },
    {
      title: 'POP MART Big Into Energy Figure',
      matched: false,
    },
    {
      title: 'POP MART Big Into Energy Lucky Hope',
      rejectReason: 'crossFigureContamination',
    },
    {
      title: 'POP MART Big Into Energy Hope Figure',
      rejectReason: 'wrongFigureName',
    },
    {
      title: 'POP MART Lucky Big Into Energy Poster Art Print',
      rejectReason: 'productTypeReject',
    },
    {
      title: 'POP MART THE MONSTERS Id Secret Big Into Energy 1/72',
      rejectReason: 'wrongFigureName',
    },
  ];

  for (const entry of matrix) {
    test(entry.title.slice(0, 64), () => {
      const result = matchRaw(entry.title);
      if (entry.rejectReason) {
        assert.equal(result.rejectReason, entry.rejectReason);
        assert.equal(result.matched, false);
        return;
      }
      assert.equal(result.matched, entry.matched);
    });
  }
});

describe('matchCatalogFigure — seed catalog integration', () => {
  test('builds context from tools/seed JSON slice', () => {
    const figures = JSON.parse(
      readFileSync(join(repoRoot, 'tools/seed/figures.json'), 'utf8'),
    );
    const series = JSON.parse(
      readFileSync(join(repoRoot, 'tools/seed/series.json'), 'utf8'),
    );
    const brands = JSON.parse(
      readFileSync(join(repoRoot, 'tools/seed/brands.json'), 'utf8'),
    );
    const ips = JSON.parse(
      readFileSync(join(repoRoot, 'tools/seed/ips.json'), 'utf8'),
    );

    const targetFigure = figures.find(
      (figure) => figure.id === figureLuck.id,
    );
    const targetSeries = series.find((row) => row.id === seriesBigIntoEnergy.id);
    const brand = brands.find((row) => row.id === 'pop_mart');
    const ip = ips.find((row) => row.id === 'the_monsters');
    const siblings = figures.filter(
      (figure) =>
        figure.seriesId === targetSeries.id && figure.id !== targetFigure.id,
    );

    const context = buildMatcherContext({
      targetFigure,
      series: targetSeries,
      brand,
      ip,
      siblingFigures: siblings,
      allSeries: series.filter((row) => row.brandId === 'pop_mart').slice(0, 40),
    });

    const result = matchCatalogFigure(
      normalizeMarketTitle(
        'POP MART THE MONSTERS Big Into Energy Lucky Vinyl Plush Sealed',
      ),
      context,
      luckyMetadata,
    );

    assert.equal(result.matched, true);
    assert.equal(result.figureId, figureLuck.id);
  });
});

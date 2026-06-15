import assert from 'node:assert/strict';
import { describe, test } from 'node:test';

import {
  AUTO_MAX_TERMS,
  OVERRIDE_MAX_TERMS,
  deriveSearchTerms,
  extractSeriesDistinctive,
} from './_search_term_derivation.mjs';

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

const ipNoAlias = {
  id: 'pucky',
  displayName: 'Pucky',
  aliases: [],
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

const seriesHaveASeat = {
  id: 'the_monsters_have_a_seat_vinyl_plush',
  displayName: 'THE MONSTERS - Have a Seat Vinyl Plush Blind Box',
  aliases: [
    'THE MONSTERS - Have a Seat Vinyl Plush',
    'the monsters have a seat vinyl plush',
  ],
};

const seriesPetalsInFourActs = {
  id: 'skullpanda_petals_in_four_acts',
  displayName: 'SKULLPANDA Petals in Four Acts Series Figures',
  aliases: ['SKULLPANDA Petals in Four Acts'],
};

const ipSkullpanda = {
  id: 'skullpanda',
  displayName: 'Skullpanda',
  aliases: ['Skull Panda'],
};

const figureLuck = {
  id: 'the_monsters_big_into_energy_vinyl_plush_pendant_luck',
  displayName: 'Luck',
  seriesId: seriesBigIntoEnergy.id,
  brandId: brandPopMart.id,
  isSecret: false,
};

const figureSisi = {
  id: 'the_monsters_have_a_seat_vinyl_plush_sisi',
  displayName: 'SISI',
  seriesId: seriesHaveASeat.id,
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

const figureFairysTrick = {
  id: 'skullpanda_petals_in_four_acts_the_fairys_trick',
  displayName: "The Fairy's Trick",
  seriesId: seriesPetalsInFourActs.id,
  brandId: brandPopMart.id,
  isSecret: false,
};

function monstersCatalog(series) {
  return {
    brand: brandPopMart,
    ip: ipTheMonsters,
    series,
  };
}

describe('extractSeriesDistinctive', () => {
  test('strips Monsters boilerplate from Big Into Energy', () => {
    assert.equal(
      extractSeriesDistinctive(seriesBigIntoEnergy, ipTheMonsters),
      'Big into Energy',
    );
  });

  test('strips Monsters boilerplate from Have a Seat', () => {
    assert.equal(
      extractSeriesDistinctive(seriesHaveASeat, ipTheMonsters),
      'Have a Seat',
    );
  });

  test('strips Skullpanda boilerplate from Petals in Four Acts', () => {
    assert.equal(
      extractSeriesDistinctive(seriesPetalsInFourActs, ipSkullpanda),
      'Petals in Four Acts',
    );
  });
});

describe('deriveSearchTerms — Luck', () => {
  test('generates Tier 1 and alias terms without brandless variant', () => {
    const terms = deriveSearchTerms(
      figureLuck,
      monstersCatalog(seriesBigIntoEnergy),
      { marketAliases: ['Lucky'] },
    );

    assert.deepEqual(terms, [
      'POP MART Labubu Big into Energy Luck',
      'POPMART Labubu Big into Energy Luck',
      'POP MART Labubu Big into Energy Lucky',
    ]);
    assert.equal(terms.length, 3);
    assert.ok(
      !terms.some((term) => term.startsWith('Labubu ')),
      'expected no brandless Tier 2 term',
    );
  });
});

describe('deriveSearchTerms — SISI', () => {
  test('generates two Tier 1 terms only', () => {
    const terms = deriveSearchTerms(
      figureSisi,
      monstersCatalog(seriesHaveASeat),
      {},
    );

    assert.deepEqual(terms, [
      'POP MART Labubu Have a Seat SISI',
      'POPMART Labubu Have a Seat SISI',
    ]);
    assert.equal(terms.length, 2);
  });
});

describe('deriveSearchTerms — secret Id', () => {
  test('includes secret helper term', () => {
    const terms = deriveSearchTerms(
      figureIdSecret,
      monstersCatalog(seriesBigIntoEnergy),
      {},
    );

    assert.deepEqual(terms, [
      'POP MART Labubu Big into Energy Id',
      'POPMART Labubu Big into Energy Id',
      'POP MART Labubu Big into Energy Id secret',
    ]);
    assert.ok(terms.some((term) => /\bsecret$/i.test(term)));
  });
});

describe('deriveSearchTerms — disabled', () => {
  test('returns empty array immediately', () => {
    assert.deepEqual(
      deriveSearchTerms(
        figureLuck,
        monstersCatalog(seriesBigIntoEnergy),
        {
          disabled: true,
          searchTerms: ['POP MART override should not win'],
          marketAliases: ['lucky'],
        },
      ),
      [],
    );
  });
});

describe('deriveSearchTerms — override path', () => {
  test('returns override terms with dedupe and cap', () => {
    const terms = deriveSearchTerms(
      figureLuck,
      monstersCatalog(seriesBigIntoEnergy),
      {
        searchTerms: [
          '  POP MART Lucky Big Into Energy  ',
          'POP MART Lucky Big Into Energy',
          'POPMART LUCKY BIG ENERGY',
          'term 4',
          'term 5',
          'term 6',
          'term 7',
        ],
      },
    );

    assert.deepEqual(terms, [
      'POP MART Lucky Big Into Energy',
      'POPMART LUCKY BIG ENERGY',
      'term 4',
      'term 5',
      'term 6',
      'term 7',
    ]);
    assert.equal(terms.length, OVERRIDE_MAX_TERMS);
  });
});

describe('deriveSearchTerms — missing IP alias', () => {
  test('falls back to ip.displayName', () => {
    const terms = deriveSearchTerms(
      figureLuck,
      {
        brand: brandPopMart,
        ip: ipNoAlias,
        series: seriesBigIntoEnergy,
      },
      {},
    );

    assert.deepEqual(terms, [
      'POP MART Pucky Big into Energy Luck',
      'POPMART Pucky Big into Energy Luck',
    ]);
  });
});

describe('deriveSearchTerms — no brandless terms', () => {
  test('never generates Tier 2 brandless terms for Luck', () => {
    const terms = deriveSearchTerms(
      figureLuck,
      monstersCatalog(seriesBigIntoEnergy),
      { marketAliases: ['Lucky'] },
    );

    assert.ok(
      terms.every(
        (term) => term.startsWith('POP MART') || term.startsWith('POPMART'),
      ),
    );
  });

  test('never generates Tier 2 brandless terms for SISI', () => {
    const terms = deriveSearchTerms(
      figureSisi,
      monstersCatalog(seriesHaveASeat),
      {},
    );

    assert.ok(
      terms.every(
        (term) => term.startsWith('POP MART') || term.startsWith('POPMART'),
      ),
    );
  });

  test('never generates Tier 2 brandless terms for Id', () => {
    const terms = deriveSearchTerms(
      figureIdSecret,
      monstersCatalog(seriesBigIntoEnergy),
      {},
    );

    assert.ok(
      terms.every(
        (term) => term.startsWith('POP MART') || term.startsWith('POPMART'),
      ),
    );
  });

  test('never generates Tier 2 brandless terms for multi-word figures', () => {
    const terms = deriveSearchTerms(
      figureFairysTrick,
      {
        brand: brandPopMart,
        ip: ipSkullpanda,
        series: seriesPetalsInFourActs,
      },
      {},
    );

    assert.deepEqual(terms, [
      'POP MART Skull Panda Petals in Four Acts The Fairy\'s Trick',
      'POPMART Skull Panda Petals in Four Acts The Fairy\'s Trick',
    ]);
    assert.ok(
      terms.every(
        (term) => term.startsWith('POP MART') || term.startsWith('POPMART'),
      ),
    );
  });
});

describe('deriveSearchTerms — alias limits and cleanup', () => {
  test('limits alias terms to two and uses primary brand only', () => {
    const terms = deriveSearchTerms(
      figureLuck,
      monstersCatalog(seriesBigIntoEnergy),
      {
        marketAliases: ['Lucky', 'Lucky BIE', 'Luckster'],
      },
    );

    assert.deepEqual(terms, [
      'POP MART Labubu Big into Energy Luck',
      'POPMART Labubu Big into Energy Luck',
      'POP MART Labubu Big into Energy Lucky',
      'POP MART Labubu Big into Energy Lucky BIE',
    ]);
    assert.equal(terms.length, AUTO_MAX_TERMS);
    assert.ok(!terms.some((term) => term.includes('Luckster')));
    assert.ok(!terms.some((term) => term.startsWith('POPMART Labubu Big into Energy Lucky')));
  });

  test('includes catalog figure aliases in alias expansion', () => {
    const terms = deriveSearchTerms(
      {
        ...figureLuck,
        aliases: ['Fortune'],
      },
      monstersCatalog(seriesBigIntoEnergy),
      { marketAliases: ['Lucky'] },
    );

    assert.deepEqual(terms, [
      'POP MART Labubu Big into Energy Luck',
      'POPMART Labubu Big into Energy Luck',
      'POP MART Labubu Big into Energy Fortune',
      'POP MART Labubu Big into Energy Lucky',
    ]);
  });

  test('empty searchTerms override falls back to auto generation', () => {
    const terms = deriveSearchTerms(
      figureSisi,
      monstersCatalog(seriesHaveASeat),
      { searchTerms: [] },
    );

    assert.equal(terms.length, 2);
  });
});

import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { describe, test } from 'node:test';
import { fileURLToPath } from 'node:url';

import {
  evaluateEdgeCaseEntry,
  loadEdgeCaseCorpus,
  summarizeCorpusCoverage,
} from './_edge_case_loader.mjs';
import {
  findExcludeTerm,
  isExcludedTitle,
  normalizeMarketTitle,
  stripNoiseTokens,
  structurallyNormalizeTitle,
} from './_title_normalizer.mjs';

const __dirname = dirname(fileURLToPath(import.meta.url));
const corpusEntries = loadEdgeCaseCorpus();
const corpusFns = { normalizeMarketTitle, findExcludeTerm };

describe('edge_case_titles.txt corpus', () => {
  test('loads 100–150 realistic marketplace titles', () => {
    assert.ok(
      corpusEntries.length >= 100 && corpusEntries.length <= 150,
      `expected 100–150 titles, got ${corpusEntries.length}`,
    );
  });

  test('includes titles sourced from project eBay audit data', () => {
    const auditTitles = corpusEntries.filter((entry) => entry.source === 'audit');
    assert.ok(
      auditTitles.length >= 40,
      `expected substantial audit-derived coverage, got ${auditTitles.length}`,
    );
  });

  for (const entry of corpusEntries) {
    test(`[${entry.category}] ${entry.raw.slice(0, 72)}`, () => {
      const result = evaluateEdgeCaseEntry(entry, corpusFns);
      assert.equal(
        result.ok,
        true,
        result.errors.join('; '),
      );
    });
  }

  test('coverage summary by category', () => {
    const summary = summarizeCorpusCoverage(corpusEntries, corpusFns);
    const lines = ['', 'Edge-case corpus coverage summary', ''];

    for (const [category, stats] of summary.entries()) {
      lines.push(
        `${category}: titles=${stats.total} pass=${stats.pass} fail=${stats.fail} excluded=${stats.excluded} normalized=${stats.normalized}`,
      );
      assert.equal(stats.fail, 0, `category ${category} has failures`);
      assert.equal(stats.pass, stats.total);
    }

    console.log(lines.join('\n'));
  });
});

describe('edge_case_titles.txt distribution targets', () => {
  test('approximates 40/30/20/10 primary mix', () => {
    const primary = {
      valid_sale: corpusEntries.filter((e) => e.category === 'valid_sale').length,
      excluded_sale: corpusEntries.filter((e) => e.category === 'excluded_sale')
        .length,
      normalization_stress: corpusEntries.filter(
        (e) => e.category === 'normalization_stress',
      ).length,
      multilingual: corpusEntries.filter((e) => e.category === 'multilingual')
        .length,
    };
    const total = corpusEntries.length;

    assert.ok(primary.valid_sale / total >= 0.34);
    assert.ok(primary.excluded_sale / total >= 0.24);
    assert.ok(primary.normalization_stress / total >= 0.14);
    assert.ok(primary.multilingual / total >= 0.06);
  });
});

describe('edge_case_titles.txt failure-mode tags', () => {
  test('false-positive guard titles stay clean', () => {
    const guards = corpusEntries.filter(
      (entry) => entry.category === 'false_positive_guard',
    );
    assert.ok(guards.length >= 6);
    for (const entry of guards) {
      const result = evaluateEdgeCaseEntry(entry, corpusFns);
      assert.equal(result.ok, true, entry.raw);
      assert.equal(result.excluded, false, entry.raw);
    }
  });

  test('pendant override allows pendant-series titles', () => {
    const allowed = corpusEntries.find(
      (entry) =>
        entry.category === 'pendant_override' &&
        entry.overrides.includes('pendant'),
    );
    assert.ok(allowed);
    const result = evaluateEdgeCaseEntry(allowed, corpusFns);
    assert.equal(result.ok, true);
    assert.equal(result.excluded, false);
  });

  test('secret and size tagged entries preserve identity tokens', () => {
    const secretEntries = corpusEntries.filter(
      (entry) => entry.subcategory === 'secret_preservation',
    );
    const sizeEntries = corpusEntries.filter(
      (entry) => entry.subcategory === 'size_preservation',
    );

    assert.ok(secretEntries.length >= 4);
    assert.ok(sizeEntries.length >= 4);

    for (const entry of [...secretEntries, ...sizeEntries]) {
      const result = evaluateEdgeCaseEntry(entry, corpusFns);
      assert.equal(result.ok, true, `${entry.raw}: ${result.errors.join('; ')}`);
    }
  });
});

describe('edge_case_titles.txt stays in sync with debug utility input', () => {
  test('contains one title per non-metadata line', () => {
    const raw = readFileSync(join(__dirname, 'edge_case_titles.txt'), 'utf8');
    const titleLines = raw
      .split(/\r?\n/)
      .map((line) => line.trim())
      .filter(
        (line) =>
          line.length > 0 && !line.startsWith('#') && !line.startsWith('@'),
      );
    assert.equal(titleLines.length, corpusEntries.length);
  });
});

describe('structurallyNormalizeTitle', () => {
  test('lowercases ASCII letters', () => {
    assert.equal(
      structurallyNormalizeTitle('POP MART Lucky'),
      'pop mart lucky',
    );
  });

  test('replaces separators with spaces', () => {
    assert.equal(
      structurallyNormalizeTitle('POP_MART/Lucky|Big·Energy•Chase'),
      'pop mart lucky big energy chase',
    );
    assert.equal(
      structurallyNormalizeTitle('POP MART Lucky, US Seller; NIB'),
      'pop mart lucky us seller nib',
    );
  });

  test('collapses and trims whitespace', () => {
    assert.equal(
      structurallyNormalizeTitle('  POP   MART\tLucky\n  '),
      'pop mart lucky',
    );
  });

  test('preserves rarity ratio slashes such as 1/144', () => {
    assert.equal(
      structurallyNormalizeTitle('POP MART Secret 1/144 Chase'),
      'pop mart secret 1/144 chase',
    );
  });

  test('preserves CJK characters', () => {
    assert.equal(
      structurallyNormalizeTitle('POP MART 隐藏 SECRET'),
      'pop mart 隐藏 secret',
    );
  });
});

describe('stripNoiseTokens', () => {
  test('removes single-word condition and version noise tokens', () => {
    const normalized = stripNoiseTokens(
      'pop mart lucky big into energy bnib sealed v2 new mint',
    );
    assert.equal(normalized, 'pop mart lucky big into energy');
  });

  test('removes multi-word shipping and marketing phrases', () => {
    const normalized = stripNoiseTokens(
      'pop mart lucky free shipping us seller hard to find rare htf limited exclusive fast ship',
    );
    assert.equal(normalized, 'pop mart lucky');
  });
});

describe('normalizeMarketTitle', () => {
  test('produces stable output for equivalent marketplace titles', () => {
    const a = normalizeMarketTitle(
      'POP MART Lucky Big Into Energy - BNIB | Free Shipping | AUTHENTIC',
    );
    const b = normalizeMarketTitle(
      'pop mart lucky big into energy sealed official genuine',
    );
    assert.equal(a, 'pop mart lucky big into energy');
    assert.equal(b, 'pop mart lucky big into energy');
  });

  test('preserves secret and chase identity tokens', () => {
    const normalized = normalizeMarketTitle(
      'POP MART Lucky SECRET Chase 隐藏 1/144 BNIB NEW',
    );
    assert.match(normalized, /\bsecret\b/);
    assert.match(normalized, /\bchase\b/);
    assert.match(normalized, /隐藏/);
    assert.match(normalized, /1\/144/);
    assert.doesNotMatch(normalized, /\bbnib\b/);
    assert.doesNotMatch(normalized, /\bnew\b/);
  });

  test('preserves size designators', () => {
    const normalized = normalizeMarketTitle('LABUBU 1000% 400% MEGA');
    assert.match(normalized, /1000%/);
    assert.match(normalized, /400%/);
  });
});

describe('Sprint 2 Step 1 regression — normalizer quality', () => {
  test('does not leave shipping -> ping fragments from partial phrase removal', () => {
    const normalized = normalizeMarketTitle(
      'POP MART aespa Fluffy Club Series Vinyl Plush Doll - US FAST SHIPPING',
    );
    assert.equal(
      normalized,
      'pop mart aespa fluffy club series vinyl plush doll',
    );
    assert.doesNotMatch(normalized, /\bping\b/);
    assert.doesNotMatch(normalized, /\bshipping\b/);
  });

  test('does not modify spaceship or shippington whole tokens', () => {
    assert.equal(
      normalizeMarketTitle('POP MART Spaceship Series Figure'),
      'pop mart spaceship series figure',
    );
    assert.equal(
      normalizeMarketTitle('POP MART Shippington Vinyl Plush'),
      'pop mart shippington vinyl plush',
    );
  });

  test('removes symbol-wrapped AUTHENTIC noise like plain AUTHENTIC', () => {
    const expected = 'pop mart lucky';
    for (const wrapped of [
      '***AUTHENTIC***',
      '~~AUTHENTIC~~',
      '(AUTHENTIC)',
      '[AUTHENTIC]',
      '【AUTHENTIC】',
    ]) {
      assert.equal(
        normalizeMarketTitle(`${wrapped} POP MART Lucky`),
        expected,
        wrapped,
      );
    }
  });

  test('removes free gift with purchase phrase', () => {
    assert.equal(
      normalizeMarketTitle(
        'Baby Three Explorer 1000% Limited Edition FREE GIFT WITH PURCHASE',
      ),
      'baby three explorer 1000% limited edition',
    );
  });

  test('cleans orphan punctuation and decorative wrappers after noise removal', () => {
    assert.equal(
      normalizeMarketTitle('(AUTHENTIC) POP MART Lucky'),
      'pop mart lucky',
    );
    assert.equal(
      normalizeMarketTitle(
        '***NEW*** POP-MART_Lucky|Big·Into·Energy|BNIB|FREE SHIPPING|AUTHENTIC***',
      ),
      'pop mart lucky big into energy',
    );
    assert.doesNotMatch(
      normalizeMarketTitle('~~ ~~ POP MART Lucky ~~ ~~'),
      /~|\(\)|\[\]/,
    );
  });
});

describe('Sprint 2 Step 1.1 regression — final normalizer cleanup', () => {
  test('removes ship fast and us seller shipping noise', () => {
    assert.equal(
      normalizeMarketTitle(
        'POP MART Twinkle Twinkle Crush On You Series Figure - US SELLER - SHIP FAST',
      ),
      'pop mart twinkle twinkle crush on you series figure',
    );
  });

  test('removes orphan us after shipping cleanup without touching embedded us', () => {
    assert.equal(
      normalizeMarketTitle(
        'POP MART Nyota Where Moments Meet Series Plush Doll - US SHIPPING',
      ),
      'pop mart nyota where moments meet series plush doll',
    );
    assert.equal(
      normalizeMarketTitle('POP MART Business As Usual Australia Series Figure'),
      'pop mart business as usual australia series figure',
    );
  });

  test('removes HTF in plain and wrapped forms', () => {
    const expected = 'pop mart lucky big into energy';
    assert.equal(
      normalizeMarketTitle(
        '【POP MART Lucky Big Into Energy】HTF RARE LIMITED EXCLUSIVE',
      ),
      expected,
    );
    for (const wrapped of ['HTF', '[HTF]', '【HTF】', '(HTF)']) {
      assert.equal(
        normalizeMarketTitle(`POP MART Lucky Big Into Energy ${wrapped}`),
        expected,
        wrapped,
      );
    }
  });

  test('removes Unicode wrapper characters from normalized output', () => {
    const normalized = normalizeMarketTitle(
      '「POP MART 100% Mega Space Molly Series 4 Blind Box Figure Toy Doll - BedTime Bear」',
    );
    assert.equal(
      normalized,
      'pop mart 100% mega space molly series 4 blind box figure toy doll bedtime bear',
    );
    assert.doesNotMatch(normalized, /[\u3010\u3011\u300c\u300d\u300e\u300f\u3008\u3009\u300a\u300b]/);
  });
});

describe('findExcludeTerm — lot detection', () => {
  test('detects lot with word boundaries', () => {
    assert.deepEqual(findExcludeTerm('POP MART Lucky lot of 3'), {
      term: 'lot',
      scope: 'global',
    });
  });

  test('does not false-positive on charlotte or ocelot', () => {
    assert.equal(findExcludeTerm('Charlotte Series Figure'), null);
    assert.equal(findExcludeTerm('Ocelot Vinyl Plush'), null);
  });

  test('detects multi-word lot signals', () => {
    assert.deepEqual(findExcludeTerm('POP MART Big Into Energy set of 12'), {
      term: 'set of',
      scope: 'global',
    });
    assert.deepEqual(findExcludeTerm('POP MART Big Into Energy full case'), {
      term: 'full case',
      scope: 'global',
    });
    assert.deepEqual(findExcludeTerm('POP MART Lucky wholesale bundle'), {
      term: 'bundle',
      scope: 'global',
    });
  });
});

describe('findExcludeTerm — accessory exclusion', () => {
  test('detects accessory terms case-insensitively on raw titles', () => {
    assert.deepEqual(findExcludeTerm('POP MART Lucky KEYCHAIN'), {
      term: 'keychain',
      scope: 'accessory',
    });
    assert.deepEqual(findExcludeTerm('POP MART Lucky Phone Strap'), {
      term: 'phone strap',
      scope: 'accessory',
    });
    assert.deepEqual(findExcludeTerm('POP MART Lucky Bag Charm'), {
      term: 'bag charm',
      scope: 'accessory',
    });
  });

  test('respects global exclude overrides for pendant series figures', () => {
    const title = 'POP MART Vinyl Plush Pendant Lucky';
    assert.deepEqual(findExcludeTerm(title), {
      term: 'pendant',
      scope: 'accessory',
    });
    assert.equal(
      findExcludeTerm(title, { globalExcludeOverrides: ['pendant'] }),
      null,
    );
  });
});

describe('findExcludeTerm — global structural excludes', () => {
  test('detects inauthentic and damaged listing language', () => {
    assert.deepEqual(findExcludeTerm('POP MART Lucky custom bootleg'), {
      term: 'custom',
      scope: 'global',
    });
    assert.deepEqual(findExcludeTerm('POP MART Lucky fake replica inspired'), {
      term: 'fake',
      scope: 'global',
    });
    assert.deepEqual(findExcludeTerm('POP MART Lucky 3d print'), {
      term: '3d print',
      scope: 'global',
    });
    assert.deepEqual(findExcludeTerm('POP MART Lucky digital file'), {
      term: 'digital file',
      scope: 'global',
    });
    assert.deepEqual(findExcludeTerm('POP MART Lucky for parts'), {
      term: 'for parts',
      scope: 'global',
    });
    assert.deepEqual(findExcludeTerm('POP MART Lucky not working broken'), {
      term: 'not working',
      scope: 'global',
    });
  });

  test('detects case-insensitively before normalization in caller', () => {
    assert.deepEqual(findExcludeTerm('Pop Mart Lucky FULL CASE'), {
      term: 'full case',
      scope: 'global',
    });
  });
});

describe('findExcludeTerm — per-figure excludes', () => {
  test('applies per-figure word-boundary excludes', () => {
    assert.deepEqual(
      findExcludeTerm('Angel Halloween POP MART', {
        perFigureExcludes: ['sanrio', 'lol'],
      }),
      null,
    );
    assert.deepEqual(
      findExcludeTerm('Sanrio Angel Figure POP MART', {
        perFigureExcludes: ['sanrio'],
      }),
      { term: 'sanrio', scope: 'perFigure' },
    );
  });

  test('applies per-figure multi-word excludes', () => {
    assert.deepEqual(
      findExcludeTerm('POP MART Lucky Star Wars mashup', {
        perFigureExcludes: ['star wars'],
      }),
      { term: 'star wars', scope: 'perFigure' },
    );
  });
});

describe('isExcludedTitle', () => {
  test('returns false for clean single-unit figure titles', () => {
    assert.equal(
      isExcludedTitle('POP MART Lucky Big Into Energy Secret Chase'),
      false,
    );
  });

  test('returns true when any exclude term matches', () => {
    assert.equal(isExcludedTitle('POP MART Lucky wholesale lot'), true);
  });
});

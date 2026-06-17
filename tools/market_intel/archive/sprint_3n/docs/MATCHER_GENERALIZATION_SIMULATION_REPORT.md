# Matcher Generalization Simulation Report

> Generated: 2026-06-15T03:21:03.439Z
> Sprint 2 Step 3E.1 — simulation only. No matcher code was changed.
> Simulates: `fullSeriesRequired` driven by `extractSeriesDistinctive(series, ip)` instead of hardcoded `"big into energy"` phrase.

## 1. Current Baseline

**Total catalog figures:** 1144

| Classification | Count | % |
|----------------|------:|--:|
| MATCHABLE | 7 | 0.6% |
| NO_SEARCH_TERMS | 7 | 0.6% |
| MATCHER_RISK | 1130 | 98.8% |
| DISABLED | 0 | 0% |
| UNKNOWN | 0 | 0% |

Root cause: `TARGET_SERIES_PHRASE = 'big into energy'` blocks `gate:fullSeriesRequired` for every non–Big Into Energy figure. Only 7 figures (0.6%) are currently matchable.

## 2. Simulated Coverage

_Simulation assumption: series gate requires `extractSeriesDistinctive(series, ip)` instead of the hardcoded phrase._

| Classification | Count | % |
|----------------|------:|--:|
| MATCHABLE | 1000 | 87.4% |
| MATCHABLE_BORDERLINE | 137 | 12% |
| NO_SEARCH_TERMS | 7 | 0.6% |

**MATCHABLE** (safe, phrase ≥ 8 chars): 1000 figures
**MATCHABLE_BORDERLINE** (phrase 4–7 chars, needs validation): 137 figures
**Combined simulated matchable:** 1137 / 1144 (99.4%)

## 3. Coverage Delta

| Metric | Before | After | Change |
|--------|-------:|------:|-------:|
| MATCHABLE (combined) | 7 (0.6%) | 1137 (99.4%) | **+1130 figures** |
| MATCHER_RISK | 1130 (98.8%) | 0 (0%) | -1130 |
| NO_SEARCH_TERMS | 7 (0.6%) | 7 (0.6%) | 0 |

**Absolute improvement:** +1130 matchable figures (+98.8 percentage points)
**Figures upgraded by generalization:** 1130

## 4. Top Remaining Risk Categories

Figures remaining in MATCHER_RISK or MATCHABLE_BORDERLINE after simulation, grouped by primary risk code:

| Risk Code | Description | Figures | Series |
|-----------|-------------|--------:|-------:|
| `shortSeriesDistinctive` | Series distinctive 4–7 chars — borderline false-positive risk | 137 | 13 |
| `siblingCollision` | Series has many short single-token sibling names | 55 | 6 |
| `ambiguousFigureName` | Single-token figure name ≤ 5 chars with no market aliases | 31 | 10 |
| `secretConsistency` | Secret figures require chase/secret indicator in listing titles | 8 | 8 |

## 5. Series Quality Analysis

Based on `extractSeriesDistinctive` output across all 109 series:

| Quality | Series count | Figures covered | Phrase length |
|---------|----------:|----------:|---------------|
| Safe (≥ 8 chars) | 95 | 1000 | ≥ 8 |
| Borderline (4–7 chars) | 13 | 137 | 4–7 |
| Too Short (< 4 chars) | 1 | 7 | < 4 |

### Safe Distinctive Series (phrase ≥ 8 chars)

These series would satisfy `gate:fullSeriesRequired` after generalization.

| Series | Distinctive Phrase | Length | Figures |
|--------|--------------------|-------:|--------:|
| MOLLY Scenery Along the Way 20th Anniversary Series | `Scenery Along the Way 20th Anniversary` | 38 | 11 |
| Forest Kingdom 5-Joint Articulated Plush Gift Series | `Forest Kingdom 5-Joint Articulated` | 34 | 7 |
| A Bite of Sweetheart Sweet Bites Series | `A Bite of Sweetheart Sweet Bites` | 32 | 7 |
| MEGA SPACE MOLLY 100% × emoji™ Series | `MEGA SPACE MOLLY 100% × emoji™` | 30 | 21 |
| THE MONSTERS - Exciting Macaron Vinyl Face Blind Box | `Exciting Macaron Vinyl Face` | 27 | 7 |
| Crying to the Moon Sitting Series | `Crying to the Moon Sitting` | 26 | 13 |
| THE MONSTERS × Hello Kitty and Friends Series-Vinyl Plush Pendant Blind Box | `× Hello Kitty and Friends` | 25 | 7 |
| Constellation Monogatari | `Constellation Monogatari` | 24 | 13 |
| DIMOO The Secret Theatre Club Series | `The Secret Theatre Club` | 23 | 7 |
| We are Twinkle Twinkle Series Plush Pendant | `We are Twinkle Twinkle` | 22 | 7 |
| We are Twinkle Twinkle Series Figures | `We are Twinkle Twinkle` | 22 | 10 |
| Baby Molly My Huggable Discovery Series | `My Huggable Discovery` | 21 | 13 |
| Twinkle Twinkle Sweet Dreams Forecast Series Plush Pendant | `Sweet Dreams Forecast` | 21 | 7 |
| MEGA SPACE MOLLY 100% Series 2-B | `MEGA SPACE MOLLY 100%` | 21 | 13 |
| MEGA SPACE MOLLY 100% Series 3 | `MEGA SPACE MOLLY 100%` | 21 | 12 |
| MEGA SPACE MOLLY 100% Series4 | `MEGA SPACE MOLLY 100%` | 21 | 15 |
| Magical Christmas Eve Series | `Magical Christmas Eve` | 21 | 7 |
| Baby Sweetheart Bunny Plush Keychain Blind Boxes | `Baby Sweetheart Bunny` | 21 | 10 |
| Twinkle Twinkle The Gifts From Stars Series Figures | `The Gifts From Stars` | 20 | 10 |
| SKULLPANDA The Ink Plum Blossom Series Figures | `The Ink Plum Blossom` | 20 | 13 |
| Nanci's Museum of Fantasy | `'s Museum of Fantasy` | 20 | 13 |
| SKULLPANDA Petals in Four Acts Series Figures | `Petals in Four Acts` | 19 | 13 |
| SKULLPANDA Everyday Wonderland Series | `Everyday Wonderland` | 19 | 13 |
| About The Childhood Series | `About The Childhood` | 19 | 7 |
| The Fairytale World Series Plush Blind Box | `The Fairytale World` | 19 | 10 |
| Polar In Monster Village Series | `In Monster Village` | 18 | 13 |
| DIMOO Stories in the Cup Series | `Stories in the Cup` | 18 | 13 |
| Zsiga Borderline Drifter Series | `Borderline Drifter` | 18 | 13 |
| Hirono Monsters' Carnival Series Figures | `Monsters' Carnival` | 18 | 7 |
| Crying to the Moon Series | `Crying to the Moon` | 18 | 13 |
| _…and 65 more safe series_ | | | |

### Borderline Distinctive Series (phrase 4–7 chars)

These series would be classified MATCHABLE_BORDERLINE — simulated matchable with a `shortSeriesDistinctive` warning.

| Series | Distinctive Phrase | Length | Figures |
|--------|--------------------|-------:|--------:|
| THE MONSTERS Classic Series-Sparkly Plush Pendant Blind Box | `Classic` | 7 | 7 |
| Hirono Shelter Series Figures | `Shelter` | 7 | 13 |
| HIRONO Reshape Series Figures | `Reshape` | 7 | 10 |
| Flower Series | `Flower` | 6 | 12 |
| Marine Series | `Marine` | 6 | 12 |
| Sweets Series | `Sweets` | 6 | 12 |
| Toilet Series | `Toilet` | 6 | 7 |
| Fruit Series | `Fruit` | 5 | 12 |
| Snack Series | `Snack` | 5 | 12 |
| Hirono Echo Series Figures | `Echo` | 4 | 13 |
| HIRONO Mime Series Figures | `Mime` | 4 | 13 |
| Bath Series | `Bath` | 4 | 7 |
| Yoga Series | `Yoga` | 4 | 7 |

### Too-Short Distinctive Series (phrase < 4 chars)

These series cannot satisfy the series gate even after generalization. They require catalog metadata enrichment (aliases) or a brand-level fallback design.

| Series | Distinctive Phrase | Length | Figures |
|--------|--------------------|-------:|--------:|
| SMISKI Series 2 | `(empty)` | 0 | 7 |

## 6. Recommendation

### HIGH VALUE

Generalization would upgrade 1130 figures and unlock 99.4% of the catalog. The improvement is substantial. Implement matcher generalization as the next sprint.

| Metric | Value |
|--------|------:|
| Baseline matchable | 0.6% |
| Simulated matchable (safe) | 87.4% |
| Simulated matchable (safe + borderline) | 99.4% |
| Figures upgraded | 1130 |
| Remaining MATCHER_RISK | 0 |

_Note: MATCHABLE_BORDERLINE figures are included in "simulated matchable" counts above. They require production validation before relying on match quality._

---

Re-run: `node tools/market_intel/matcher_generalization_simulation_audit.mjs`

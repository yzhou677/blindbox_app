# Ecosystem Marketplace Calibration Report

Generated: 2026-05-25T05:10:08.231Z
Category universe: 261068

## Summary

| Metric | Count |
|--------|------:|
| total | 44 |
| healthy | 43 |
| sparse | 1 |
| noisy | 0 |
| ambiguous | 0 |
| broken | 0 |
| uiVisible | 38 |

## Problem combinations

### POP MART + Molly (sparse)

- **Why:** Only 5/12 sample rows passed title filter (threshold 6)
- **Query:** `pop mart`
- **Aspect:** categoryId:261068,Character:{Molly}
- **Upstream / post-filter:** 6116 / 5
- **Title pass rate:** 42%
- **Top title tokens:** box, pop, mart, mega, space, molly, series, confirmed, figure, 100, doll, blind
- **Recommendations:**
  - Keep Character facet; supplement q with IP display name (precision-safe)
  - Ensure Tier 2 q-only path activates on sparse pages

## Observed seller naming (aggregate)

- series (314)
- box (246)
- figure (235)
- pop (225)
- mart (221)
- blind (171)
- confirmed (119)
- space (85)
- plush (84)
- finding (68)
- tnt (68)
- unicorn (66)
- pendant (49)
- baby (44)
- toy (39)
- the (37)
- open (32)
- sealed (32)
- doll (29)
- authentic (29)
- molly (28)
- new (27)
- twinkle (24)
- sonny (24)
- angel (24)
- rolife (22)
- vinyl (21)
- nanci (21)
- three (21)
- bob (20)

## Title clustering (aggregate)

- Combos with believable multi-listing clusters: 39/44
- believable: 39
- noisy: 3
- no_multi_listing_clusters: 2

## Sample clusters (first healthy IP-specific combo with clusters)

### POP MART + THE MONSTERS
- **Labubu** (8 listings, 5 sellers, quality: accessory)
  - Pop Mart Labubu The Monsters x Hello Kitty And Friends Sanrio Plush Pendant
  - POP MART Labubu The Monsters Pin For Love Series Mini Vinyl Plush Doll Pendant Q
  - Pop Mart The Monsters x Sanrio Labubu Kuromi Plush Doll Pendant New In Open Box
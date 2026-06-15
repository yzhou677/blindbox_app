# Catalog Coverage Report — Market Intelligence

> Generated: 2026-06-15T03:31:22.275Z
> Sprint 2 Step 3E.2 — generalized matcher (catalog-driven series gate).

## Executive Summary

- **Total catalog figures:** 1144
- **Matchable:** 1137 (99.4%)
- **Matcher risk:** 0 (0%)
- **No search terms:** 7 (0.6%)
- **Disabled:** 0 (0%)
- **Unknown:** 0 (0%)
- **Matchable figures with metadata warnings:** 409

**Production-ready estimate (matchable):** 99.4% of catalog can flow through the current matcher architecture today.

## Failure Distribution

| Classification | Count | % |
|----------------|------:|--:|
| MATCHABLE | 1137 | 99.4% |
| NO_SEARCH_TERMS | 7 | 0.6% |
| MATCHER_RISK | 0 | 0% |
| DISABLED | 0 | 0% |
| UNKNOWN | 0 | 0% |

## Matcher Assumption Audit

Current matcher assumptions (report-only):

### brandRequired

- **Description:** Acceptance gate requires brand token in listing title
- **Catalog-wide safe:** true
- **Big Into Energy-specific:** false
- **False-negative risk:** low

### fullSeriesRequired

- **Description:** Acceptance gate requires full series match; detectSeriesMatchFull uses context.seriesDistinctivePhrase (catalog-derived, from extractSeriesDistinctive)
- **Catalog-wide safe:** true
- **Big Into Energy-specific:** false
- **False-negative risk:** low
- **Note:** Series with distinctive < 4 chars fall back to IP anchor + figure identity (no phrase gate)

### figureIdentityRequired

- **Description:** Acceptance gate requires figure name or market alias token
- **Catalog-wide safe:** true
- **Big Into Energy-specific:** false
- **False-negative risk:** medium
- **Affected figures (audit heuristic):** 109

### secretConsistency

- **Description:** Secret figures reject listings without secret/chase indicators
- **Catalog-wide safe:** true
- **Big Into Energy-specific:** false
- **False-negative risk:** medium
- **Affected figures (audit heuristic):** 121

### seriesMismatchHardReject

- **Description:** Conflicting series phrases in title hard-reject (scoped to same IP in snapshot pipeline)
- **Catalog-wide safe:** partial
- **Big Into Energy-specific:** false
- **False-negative risk:** medium
- **Note:** Snapshot pipeline limits conflict series to IP universe (resolveMatcherConflictSeries)

### crossFigureContamination

- **Description:** Sibling figure tokens in title hard-reject
- **Catalog-wide safe:** true
- **Big Into Energy-specific:** false
- **False-negative risk:** medium

### productTypeTierRejects

- **Description:** Accessory/product-type phrases hard-reject (keychain, pin only, etc.)
- **Catalog-wide safe:** true
- **Big Into Energy-specific:** false
- **False-negative risk:** low

### Big Into Energy vs Rest of Catalog

- Big Into Energy: 7/7 matchable
- Non–Big Into Energy: 1130/1137 matchable
- Non–Big Into Energy short-distinctive warnings: 137

## Series Coverage (structural failures first)

### SMISKI Series 2

- **Series ID:** `smiski_series_2`
- **Figures:** 7
- **Matchable:** 0
- **Matcher risk:** 0
- **No search terms:** 7
- **Disabled:** 0
- **Reason:** series distinctive extraction collapses to "(empty)"

## Top Risk Lists

### Top 25 NO_SEARCH_TERMS

| figureId | displayName | series | reason |
|----------|-------------|--------|--------|
| `smiski_series_2_secret` | Secret | SMISKI Series 2 | series distinctive extraction collapses to "(empty)" |
| `smiski_series_2_climbing` | Smiski Climbing | SMISKI Series 2 | series distinctive extraction collapses to "(empty)" |
| `smiski_series_2_daydreaming` | Smiski Daydreaming | SMISKI Series 2 | series distinctive extraction collapses to "(empty)" |
| `smiski_series_2_kneeling` | Smiski Kneeling | SMISKI Series 2 | series distinctive extraction collapses to "(empty)" |
| `smiski_series_2_listening` | Smiski Listening | SMISKI Series 2 | series distinctive extraction collapses to "(empty)" |
| `smiski_series_2_peeking` | Smiski Peeking | SMISKI Series 2 | series distinctive extraction collapses to "(empty)" |
| `smiski_series_2_pushing` | Smiski Pushing | SMISKI Series 2 | series distinctive extraction collapses to "(empty)" |

### Top 25 MATCHER_RISK

| figureId | displayName | series | reason |
|----------|-------------|--------|--------|

## Answers

1. **How many figures are matchable?** 1137 (99.4%).
2. **Which series are blocked?** See structural series section — full-series phrase bias blocks most non–Big Into Energy IPs; numeric series distinctive blocks Smiski Series 2.
3. **Which matcher assumptions cause risk?** shortSeriesDistinctive (4–7 char phrase) series require production validation; tooShortSeriesDistinctive (< 4 chars) cannot use phrase gate.
4. **Production-ready percentage?** 99.4% matchable under generalized matcher architecture.

---

Re-run: `node tools/market_intel/catalog_coverage_audit.mjs`

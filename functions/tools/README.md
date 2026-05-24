# eBay Browse aspect calibration

Live ontology observation for Market gateway taxonomy — **do not hand-guess** aspect values.

## Quick start

From `functions/` (requires `.env.blindbox-collection` with eBay production credentials):

```bash
node tools/fetch-ebay-aspect-refinements.mjs
```

Outputs:

- `tools/ebay-aspect-refinements-261068.json` — merged Character / Brand / Franchise refinements for category **261068** (canonical blind box universe)
- Console audit: taxonomy brand/IP rows vs live facet values

## Canonical browse universe

| Parameter | Value |
|-----------|--------|
| `category_ids` | **261068** |
| Any-brand `q` | `blind box vinyl figure` |
| Brand retrieval | `q` keywords (not Brand aspect_filter) |
| IP refinement | `Character:{…}` **only when `aspectVerified`** |

## Workflow for new IPs

1. Run calibration script with a probe query for the new IP.
2. Check whether **Character** (or another facet) appears in refinements with meaningful `matchCount`.
3. Test `aspect_filter` narrowing via live API (total must drop vs baseline).
4. If verified → add `ebayCharacterValue`, `aspectVerified: true`, `ebayCategoryId: '261068'` to `composeBrowseQuery.ts`.
5. If not verified → use `q` + title taxonomy only; set `aspectVerified: false`.
6. Re-run gateway tests: `npm test`.

## Retrieval philosophy

```
category_ids  → universe scope (261068)
q             → primary retrieval intent
aspect_filter → precision refinement (verified Character only)
title filter  → final collectible verification
```

## Coverage audit (Brand × IP matrix)

```bash
npm run audit:coverage          # UI-visible matrix (fast)
npm run audit:coverage:probe    # + alternate q probes for failures
npm run audit:ecosystem         # full ecosystem + listing quality report
```

Outputs:
- `tools/browse-coverage-audit.json` — counts per combination
- `tools/ecosystem-calibration-audit.json` — titles, noise, recommendations
- `tools/ecosystem-calibration-report.md` — human-readable summary

When adding Flutter IPs, **sync** `MARKET_TAXONOMY_IPS` in `composeBrowseQuery.ts`.


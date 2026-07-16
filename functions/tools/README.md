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
- `tools/ecosystem-calibration-report.md` — human-readable summary generated
  when the audit runs. A historical snapshot is archived at
  `../../docs/archive/2026-05/ecosystem-calibration-report.md`.

When adding Flutter IPs, **sync** `MARKET_TAXONOMY_IPS` in `composeBrowseQuery.ts`.

## Title clustering inspection

The ecosystem audit now reports per-combo:
- `titleClustering.sellerDiversity` — unique sellers, top-seller share
- `titleClustering.topClusters` — identity-level title clusters (min 2 listings)
- `titleClustering.clusterQuality` — `believable` | `mixed` | `noisy` | `no_multi_listing_clusters`

Shared algorithm: `tools/lib/market-title-cluster.mjs` (gateway audit) and `lib/features/market/domain/market_title_clusterer.dart` (app spike).

## Phase 1 Chasers (app)

Enable on live eBay with:

```bash
flutter run --dart-define=MARKET_CHASERS_SCORING=true ...
```

Probes up to 8 UI-visible IP-specific browse queries, clusters titles, ranks identity-level chasers. Rail appears when entries exist.


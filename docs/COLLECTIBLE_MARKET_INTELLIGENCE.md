# Collectible market intelligence (Phase 3B)

Market browse is shifting from flat listing rows to **collectible-centered surfaces** — quiet aggregation over enriched `MarketListing` data.

## Boundaries

| Layer | Role |
|-------|------|
| `MarketListing` | Transient provider observation (unchanged) |
| `CollectibleMarketSnapshot` | Derived, lightweight rollup — **not** canonical collectible identity |
| Catalog / shelf | Canonical identity and ownership |

Snapshots interpret market activity; they do not become catalog or collection truth.

## Aggregation tiers

1. **Figure** — `catalogMatch.matchedFigureId` with `MarketMatchConfidence` ≥ medium
2. **Series** — `matchedSeriesId` only (no figure), confidence ≥ medium
3. **Listing fallback** — one listing → one snapshot when confidence is weak

Deduping uses `marketListingDedupeKey` (`providerId:providerListingId`).

Wrong grouping is avoided by not merging below the medium confidence threshold.

## Fields

- `listingCount` / `listingIds` — density without copying listings into the domain model
- `observedPriceRange` — min/max USD across sightings
- `marketMood` — editorial tone (`calm`, `active`, `scarce`, `mixed`)
- `rarityPresence` — `none`, `hinted`, `observed`
- `aggregationConfidence` — how trustworthy the grouping is

## Pipeline

After `enrichBrowseListingsIdentity`:

```
installMarketBrowseIntelligence(listings)
  → MarketBrowseListingsSession
  → buildCollectibleMarketSnapshots
  → CollectibleMarketSession
  → CollectibleMarketSnapshotCache (memory + SharedPreferences)
```

## UI

- Browse feed: [`CollectibleMarketCard`](../lib/features/market/widgets/collectible_market_card.dart)
- Tap → sheet with underlying [`MarketListingCard`](../lib/features/market/widgets/market_listing_card.dart) rows
- No provider badges, trading charts, or investment copy

## Non-goals

Realtime feeds, predictive pricing, recommendations, `imageKey` on market cards, collection changes.

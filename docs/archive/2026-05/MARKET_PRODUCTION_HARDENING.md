# Market production hardening (Phase 8)

Stability and provider maturity for long-term real-world use — without changing product philosophy.

## Provider maturity (Mercari sandbox)

| Concern | Implementation |
|---------|----------------|
| Retry / backoff | [`mercari_gateway_policy.dart`](../lib/features/market/data/datasource/mercari/mercari_gateway_policy.dart) — 3 attempts, exponential delay |
| Pagination | `cursor` + `limit` query params; [`MercariSandboxMarketSource.fetchNextPage`](../lib/features/market/data/source/mercari_sandbox_market_source.dart) |
| Total cap | `maxMercariTotalRows` (72) — calm browsing, not infinite feed |
| Cache | [`MarketProviderBrowseCache`](../lib/features/market/data/cache/market_provider_browse_cache.dart) — append, `nextCursor`, disk TTL 7d |
| Schema drift | [`MercariListingDto.tryParse`](../lib/features/market/data/datasource/mercari/mercari_listing_dto.dart) skips bad rows |
| Failover | Stale memory/disk cache on gateway errors |

## UX

- **Pull to refresh** — resets Mercari pages, re-merges with asset feed
- **Load more sightings** — manual button only (no auto infinite scroll)
- Startup unchanged — asset-only until sandbox flags set

## Config ([`MarketSandboxConfig`](../lib/features/market/data/sandbox/market_sandbox_config.dart))

- `MARKET_SANDBOX_MERCARI`, `MERCARI_GATEWAY_BASE_URL`
- `pageSize` (24), `maxMercariTotalRows` (72)
- `gatewayMaxAttempts`, `requestTimeout`, `cacheTtl`, `diskStaleTtl`

## Non-goals

Social feeds, engagement loops, trading analytics, recommendation ML, push campaigns.

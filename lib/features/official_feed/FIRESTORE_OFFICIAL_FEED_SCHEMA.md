# Firestore official feed schema

Editorial external drops/news — **not** catalog, market, or shelf.

## Collection

`official_feed_items/{itemId}`

## Document fields

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `id` | string | yes | Same as document id |
| `sourceId` | string | yes | Stable source key, e.g. `popmart_us` |
| `sourceLabel` | string | yes | UI label, e.g. `POP MART` |
| `title` | string | yes | Headline |
| `imageUrl` | string | yes | HTTPS image URL (official CDN or hosted mirror) |
| `officialUrl` | string | yes | HTTPS link opened in system browser |
| `publishedAt` | Timestamp | yes | Display sort key |
| `ingestedAt` | Timestamp | yes | Set on write (ingestion / push script) |
| `status` | string | yes | `active` \| `archived` |
| `contentHash` | string | yes | Dedup key (`sourceId` + `officialUrl` recommended) |
| `locale` | string | no | e.g. `us` |

## Query (app)

```text
official_feed_items
  .where('sourceId', ==, 'popmart_us')
  .where('status', ==, 'active')
  .orderBy('publishedAt', descending: true)
  .limit(12)
```

**Composite index:** `sourceId` ASC, `status` ASC, `publishedAt` DESC.

## Security

- Client: read-only
- Writes: Admin SDK only (`tools/official_feed/push_official_feed.mjs` or future Functions job)

## Do not

- Store catalog `imageKey` or shelf fields here
- Merge into `brands` / `ips` / `series` / `figures`

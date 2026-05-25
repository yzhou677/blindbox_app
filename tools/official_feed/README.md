# Official feed — curated ingestion (Phase 1)

Manual POP MART US drops for the Home **Official drops** rail.

## Seed file

- `popmart_us.seed.json` — edit titles, URLs, and `publishedAt` (ISO-8601 UTC)

## Push to Firestore

From repo root:

```bash
cd functions
npm install
cd ..
```

Authenticate (pick one):

```bash
# Google account with access to blindbox-collection
gcloud auth application-default login

# or Firebase CLI (also sets ADC for many tools)
firebase login
```

Project id is read from `.firebaserc` (`blindbox-collection`). Override if needed:

```powershell
$env:FIREBASE_PROJECT_ID = "blindbox-collection"
```

Then push:

```bash
node tools/official_feed/push_official_feed.mjs
```

Optional custom seed path:

```bash
node tools/official_feed/push_official_feed.mjs tools/official_feed/popmart_us.seed.json
```

## Firestore index

Create composite index on `official_feed_items`:

- `sourceId` Ascending
- `status` Ascending
- `publishedAt` Descending

The app query is documented in `lib/features/official_feed/FIRESTORE_OFFICIAL_FEED_SCHEMA.md`.

## Notes

- Phase 1 does **not** scrape popmart.com — update the seed by hand or via a future Functions job after API spike.
- Replace placeholder `imageUrl` values with real product art URLs when curating.

// DEV ONLY — remove with dev validation flow.

/// Launch dev screen: `--dart-define=MARKET_SNAPSHOT_DEV=true`
const kMarketSnapshotDevValidation =
    bool.fromEnvironment('MARKET_SNAPSHOT_DEV', defaultValue: false);

/// Live Firestore reads (default). Set `--dart-define=MARKET_SNAPSHOT_DEV_LIVE=false` for mock.
const kMarketSnapshotDevLive =
    bool.fromEnvironment('MARKET_SNAPSHOT_DEV_LIVE', defaultValue: true);

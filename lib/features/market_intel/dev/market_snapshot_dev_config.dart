// DEV ONLY — remove with dev validation flow.

import 'package:flutter/foundation.dart';

/// Launch dev screen: `--dart-define=MARKET_SNAPSHOT_DEV=true`
const kMarketSnapshotDevValidation =
    bool.fromEnvironment('MARKET_SNAPSHOT_DEV', defaultValue: false);

/// Live Firestore reads (default). Set `--dart-define=MARKET_SNAPSHOT_DEV_LIVE=false` for mock.
const kMarketSnapshotDevLive =
    bool.fromEnvironment('MARKET_SNAPSHOT_DEV_LIVE', defaultValue: true);

/// Use in-memory mock snapshots in the full app (Collection Value UI, Discover gallery, etc.).
///
/// Also enabled automatically in debug builds unless
/// `--dart-define=MARKET_SNAPSHOT_LIVE=true`.
///
/// Force mock explicitly: `--dart-define=MARKET_SNAPSHOT_MOCK=true`
const kMarketSnapshotUseMock =
    bool.fromEnvironment('MARKET_SNAPSHOT_MOCK', defaultValue: false);

/// Opt into live Firestore reads while running a debug build.
const kMarketSnapshotForceLive =
    bool.fromEnvironment('MARKET_SNAPSHOT_LIVE', defaultValue: false);

/// True when [marketSnapshotRepositoryProvider] should use [DevMockMarketSnapshotRepository].
bool get kMarketSnapshotRepositoryUsesMock {
  if (kMarketSnapshotForceLive) return false;
  if (kMarketSnapshotUseMock) return true;
  if (kMarketSnapshotDevValidation && !kMarketSnapshotDevLive) return true;
  return kDebugMode;
}

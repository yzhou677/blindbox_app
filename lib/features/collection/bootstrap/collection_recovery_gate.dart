import 'package:flutter/foundation.dart';

/// Cold-start recovery decision gate.
///
/// While [isPending], background maintenance must not run:
/// recovery pack writes, vault GC, or collection snapshot persists from the
/// notifier. Otherwise a seed/empty shelf could overwrite the restored pack
/// before the collector chooses Import / Start fresh.
abstract final class CollectionRecoveryGate {
  CollectionRecoveryGate._();

  static bool _pending = false;

  static bool get isPending => _pending;

  /// True when pack writes / GC / notifier snapshot persist must no-op.
  static bool get blocksBackgroundWrites => _pending;

  static void enterPending() {
    _pending = true;
  }

  static void clearPending() {
    _pending = false;
  }

  /// Prefs empty + valid pack → offer dialog A before the main shell.
  static bool shouldOfferRecovery({
    required bool hasSnapshotPrefs,
    required bool hasValidPack,
  }) {
    return !hasSnapshotPrefs && hasValidPack;
  }

  @visibleForTesting
  static void resetForTest() {
    _pending = false;
  }
}

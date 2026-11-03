import 'package:blindbox_app/features/collection/application/collection_shelf_ui_prefs_provider.dart';
import 'package:blindbox_app/features/collection/bootstrap/collection_recovery_gate.dart';
import 'package:blindbox_app/features/collection/data/collection_memory_store.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/persistence/collection_snapshot_storage.dart';
import 'package:flutter/foundation.dart';

/// Shared replace-commit order for recovery packs and shelf export archives.
///
/// Order: install media → memory → UI prefs → **snapshot last** (commit marker).
abstract final class ShelfBackupCommit {
  ShelfBackupCommit._();

  /// Throws before memory replace (media may already be installed).
  @visibleForTesting
  static Future<void> Function()? testBeforeMemoryHook;

  /// Throws immediately before the snapshot prefs write (the commit marker).
  @visibleForTesting
  static Future<void> Function()? testBeforeSnapshotSaveHook;

  /// Applies a full replace of shelf state.
  ///
  /// When [manageGate] is true, enters [CollectionRecoveryGate] for the
  /// duration of this call (export import). Recovery cold-start already holds
  /// the gate and should pass `manageGate: false` so a failed import keeps
  /// the gate pending.
  static Future<CollectionSnapshot> apply({
    required CollectionSnapshot snapshot,
    required String memoryJson,
    required String uiPrefsJson,
    required Future<void> Function() installMedia,
    CollectionSnapshot Function(CollectionSnapshot)? transformSnapshot,
    bool manageGate = false,
  }) async {
    if (manageGate) {
      CollectionRecoveryGate.enterPending();
    }
    try {
      await installMedia();

      final beforeMemory = testBeforeMemoryHook;
      if (beforeMemory != null) {
        await beforeMemory();
      }
      await CollectionMemoryStore.instance.replaceFromRecoveryJson(memoryJson);

      final uiPrefs = CollectionShelfUiPrefsCodec.decode(uiPrefsJson);
      await CollectionShelfUiPrefsStorage.save(uiPrefs);

      final toSave = transformSnapshot == null
          ? snapshot
          : transformSnapshot(snapshot);

      final beforeSnapshot = testBeforeSnapshotSaveHook;
      if (beforeSnapshot != null) {
        await beforeSnapshot();
      }
      await CollectionSnapshotStorage.save(toSave);
      return toSave;
    } finally {
      if (manageGate) {
        CollectionRecoveryGate.clearPending();
      }
    }
  }
}

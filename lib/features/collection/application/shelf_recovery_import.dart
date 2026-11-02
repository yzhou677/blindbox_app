import 'dart:io';

import 'package:blindbox_app/features/collection/application/collection_shelf_ui_prefs_provider.dart';
import 'package:blindbox_app/features/collection/data/collection_memory_store.dart';
import 'package:blindbox_app/features/collection/data/shelf_media_vault.dart';
import 'package:blindbox_app/features/collection/data/shelf_recovery_pack.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/persistence/collection_snapshot_storage.dart';
import 'package:flutter/foundation.dart';

/// Applies a [ShelfRecoveryPackContents] into local prefs + vault.
abstract final class ShelfRecoveryImport {
  ShelfRecoveryImport._();

  /// Optional hook to force import failures in tests (pack remains on disk).
  @visibleForTesting
  static Future<void> Function()? testBeforeCommitHook;

  static Future<CollectionSnapshot> apply(ShelfRecoveryPackContents pack) async {
    final hook = testBeforeCommitHook;
    if (hook != null) {
      await hook();
    }

    await ShelfMediaVault.ensureReady();
    for (final id in pack.mediaIds) {
      final file = File(ShelfRecoveryPack.mediaFilePath(pack.packPath, id));
      if (!await file.exists()) continue;
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) continue;
      await ShelfMediaVault.installRecoveredThumb(id: id, thumbBytes: bytes);
    }

    await CollectionSnapshotStorage.save(pack.snapshot);
    await CollectionMemoryStore.instance.replaceFromRecoveryJson(pack.memoryJson);
    final uiPrefs = CollectionShelfUiPrefsCodec.decode(pack.uiPrefsJson);
    await CollectionShelfUiPrefsStorage.save(uiPrefs);

    return pack.snapshot;
  }
}

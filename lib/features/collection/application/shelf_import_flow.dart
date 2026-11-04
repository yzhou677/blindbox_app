import 'dart:async';

import 'package:blindbox_app/features/collection/data/shelf_export_archive.dart';
import 'package:blindbox_app/features/collection/data/shelf_media_vault.dart';
import 'package:blindbox_app/features/collection/data/shelf_recovery_pack.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

/// Counts + created date shown on the Replace confirm dialog.
@immutable
class ShelfImportBackupSummary {
  const ShelfImportBackupSummary({
    required this.seriesCount,
    required this.figureCount,
    required this.wishlistCount,
    required this.createdAt,
  });

  /// Prefer snapshot tallies over manifest counts when they disagree.
  factory ShelfImportBackupSummary.fromStaging(ShelfExportStaging staging) {
    return ShelfImportBackupSummary(
      seriesCount: staging.snapshot.shelfSeries.length,
      figureCount: staging.snapshot.totalShelfFigures,
      wishlistCount: staging.snapshot.totalWishlistItems,
      createdAt: staging.manifest.createdAt,
    );
  }

  final int seriesCount;
  final int figureCount;
  final int wishlistCount;

  /// Manifest `createdAt` (UTC). Display via [ShelfImportCopy.formatCreatedDate].
  final DateTime createdAt;
}

/// User-visible English copy for Collection → Shelf backup sheet / import.
abstract final class ShelfImportCopy {
  ShelfImportCopy._();

  static const importTitle = 'Import shelf';
  static const importSubtitle = 'Replace your shelf with a backup file';

  static const confirmTitle = 'Replace your shelf?';
  static const confirmBody =
      'Your current shelf, including your wishlist, will be replaced.';
  static const confirmSafetyNote =
      'A safety copy is saved on this device for 7 days.';
  static const confirmCancel = 'Cancel';
  static const confirmReplace = 'Replace shelf';

  static const checking = 'Checking backup…';
  static const importing = 'Importing backup…';
  static const successSnack = 'Shelf imported';
  static const failedSnack =
      'Couldn\'t import this backup. Your current shelf wasn\'t changed.';
  static const tooLargeSnack =
      'This backup is too large to import (over 2 GB).';
  static const safetyFailedSnack =
      'Couldn\'t save a safety copy. Import canceled.';
  static const chooseZipSnack =
      'Choose a Shelfy backup (.zip) file.';

  /// English summary line. Omits wishlist when [wishlistCount] is 0.
  ///
  /// Plural rules: series stays "series"; figure(s); wishlist item(s).
  static String confirmSummary({
    required int seriesCount,
    required int figureCount,
    required String createdDate,
    int wishlistCount = 0,
  }) {
    final seriesLabel =
        seriesCount == 1 ? '1 series' : '$seriesCount series';
    final figureLabel =
        figureCount == 1 ? '1 figure' : '$figureCount figures';
    if (wishlistCount <= 0) {
      return 'This backup has $seriesLabel and $figureLabel, created $createdDate.';
    }
    final wishlistLabel = wishlistCount == 1
        ? '1 wishlist item'
        : '$wishlistCount wishlist items';
    return 'This backup has $seriesLabel, $figureLabel and $wishlistLabel, '
        'created $createdDate.';
  }

  /// Local-time `MMM d, yyyy` (e.g. `Jan 1, 2026`).
  static String formatCreatedDate(DateTime createdAt) {
    final local = createdAt.toLocal();
    const months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[local.month - 1]} ${local.day}, ${local.year}';
  }
}

enum ShelfImportFlowStatus {
  success,
  cancelled,
  rejectedTooLarge,
  safetyCopyFailed,

  /// Picked file is not a `.zip` by name (before unpack / Checking).
  rejectedNotZip,
  failed,
}

/// Result of the system file picker for Import shelf.
@immutable
class ShelfImportPickedFile {
  const ShelfImportPickedFile({
    required this.path,
    this.name = '',
  });

  /// Test helper: [name] defaults to [path] so extension checks use the path.
  factory ShelfImportPickedFile.pathOnly(String path) =>
      ShelfImportPickedFile(path: path, name: path);

  /// Filesystem path (may lack an extension after Android content-URI copy).
  final String path;

  /// Original display name from the picker ([PlatformFile.name]).
  final String name;
}

@immutable
class ShelfImportFlowResult {
  const ShelfImportFlowResult({
    required this.status,
    this.importedSnapshot,
  });

  final ShelfImportFlowStatus status;
  final CollectionSnapshot? importedSnapshot;
}

/// Injectable hooks for Settings import (tests override these).
@immutable
class ShelfImportFlowDeps {
  const ShelfImportFlowDeps({
    this.pickZipPath,
    this.pickBackupFile,
    this.onChecking,
    this.confirmReplace,
    this.unpack,
    this.writeSafetyZip,
    this.commitStaging,
    this.clearPickerTemp,
    this.collectGarbage,
    this.scheduleRecoveryPack,
  });

  /// Returns a filesystem path, or null if the user cancelled.
  ///
  /// Prefer [pickBackupFile] when the original display name is needed
  /// (Android content URIs often drop the `.zip` suffix on [path]).
  final Future<String?> Function()? pickZipPath;

  /// Richer picker result (path + original name). Takes precedence over
  /// [pickZipPath] when both are set.
  final Future<ShelfImportPickedFile?> Function()? pickBackupFile;

  /// Called after the picked file passes the `.zip` name check, before unpack.
  final void Function()? onChecking;

  /// Shown after a successful unpack. Return false to cancel (staging deleted).
  final Future<bool> Function(ShelfImportBackupSummary summary)? confirmReplace;

  final Future<ShelfExportStaging> Function(String zipPath)? unpack;

  /// Writes `export_backups/pre_import_*.zip` for a non-empty current shelf.
  final Future<void> Function({
    required CollectionSnapshot snapshot,
    required String memoryJson,
    required String uiPrefsJson,
  })?
  writeSafetyZip;

  final Future<CollectionSnapshot> Function(ShelfExportStaging staging)?
  commitStaging;

  final Future<void> Function()? clearPickerTemp;

  final Future<void> Function(CollectionSnapshot snapshot)? collectGarbage;

  /// Refresh Auto Backup recovery pack after a successful Replace import.
  final void Function(CollectionSnapshot snapshot)? scheduleRecoveryPack;
}

/// Manual Import shelf (Replace only):
/// pick → unpack/validate → confirm (summary) → safety → commit.
/// Does not change recovery-gate *policy*.
abstract final class ShelfImportFlow {
  ShelfImportFlow._();

  static Future<ShelfImportFlowResult> run({
    required CollectionSnapshot currentSnapshot,
    required String currentMemoryJson,
    required String currentUiPrefsJson,
    required void Function() suspendPersistence,
    required void Function(CollectionSnapshot snapshot) replaceNotifierState,
    required void Function() resumePersistence,
    required Future<void> Function() reloadUiPrefs,
    ShelfImportFlowDeps deps = const ShelfImportFlowDeps(),
  }) async {
    final confirm = deps.confirmReplace;
    final unpackFn = deps.unpack ?? ShelfExportArchive.unpackToStaging;
    final safetyFn = deps.writeSafetyZip ?? _defaultSafetyZip;
    final commitFn = deps.commitStaging ?? ShelfExportArchive.commitStaging;
    final clearTemp = deps.clearPickerTemp ?? _defaultClearTemp;
    final gcFn = deps.collectGarbage ?? _defaultGc;
    final schedulePack = deps.scheduleRecoveryPack ??
        ((CollectionSnapshot s) {
          ShelfRecoveryPack.scheduleWrite(snapshot: s);
        });

    try {
      final picked = await _resolvePickedFile(deps);
      if (picked == null || picked.path.isEmpty) {
        return const ShelfImportFlowResult(
          status: ShelfImportFlowStatus.cancelled,
        );
      }

      if (!isZipBackupFilename(path: picked.path, name: picked.name)) {
        return const ShelfImportFlowResult(
          status: ShelfImportFlowStatus.rejectedNotZip,
        );
      }

      deps.onChecking?.call();
      suspendPersistence();

      ShelfExportStaging? staging;
      try {
        try {
          staging = await unpackFn(picked.path);
        } on ShelfExportException catch (e) {
          return ShelfImportFlowResult(
            status: _isTooLargeMessage(e.message)
                ? ShelfImportFlowStatus.rejectedTooLarge
                : ShelfImportFlowStatus.failed,
          );
        } on Object {
          return const ShelfImportFlowResult(
            status: ShelfImportFlowStatus.failed,
          );
        }

        if (confirm != null) {
          final summary = ShelfImportBackupSummary.fromStaging(staging);
          final ok = await confirm(summary);
          if (!ok) {
            return const ShelfImportFlowResult(
              status: ShelfImportFlowStatus.cancelled,
            );
          }
        }

        if (!currentSnapshot.isEmptyShelf) {
          try {
            await safetyFn(
              snapshot: currentSnapshot,
              memoryJson: currentMemoryJson,
              uiPrefsJson: currentUiPrefsJson,
            );
          } on Object {
            return const ShelfImportFlowResult(
              status: ShelfImportFlowStatus.safetyCopyFailed,
            );
          }
        }

        late final CollectionSnapshot saved;
        try {
          saved = await commitFn(staging);
        } on Object {
          return const ShelfImportFlowResult(
            status: ShelfImportFlowStatus.failed,
          );
        }

        replaceNotifierState(saved);
        try {
          await reloadUiPrefs();
        } on Object {
          // snapshot already committed; prefs UI may lag until next launch
        }

        // Import bypasses notifier persist — refresh recovery pack explicitly.
        try {
          schedulePack(saved);
        } on Object {
          // best-effort; prefs snapshot is already the commit marker
        }

        unawaited(() async {
          try {
            await gcFn(saved);
          } on Object {
            // best-effort
          }
        }());

        return ShelfImportFlowResult(
          status: ShelfImportFlowStatus.success,
          importedSnapshot: saved,
        );
      } finally {
        try {
          await staging?.delete();
        } on Object {
          // best-effort
        }
        resumePersistence();
      }
    } finally {
      try {
        await clearTemp();
      } on Object {
        // ignore picker temp cleanup failures
      }
    }
  }

  /// Shared picker used by the Shelf backup sheet and default deps.
  static Future<String?> pickZipPath() async {
    final picked = await pickBackupFile();
    return picked?.path;
  }

  /// Path + original name; uses [FileType.any] (no Android MIME filter).
  static Future<ShelfImportPickedFile?> pickBackupFile() => _defaultPickBackup();

  /// True when [path] or [name] ends with `.zip` (case-insensitive).
  ///
  /// Either side is enough: Android content-URI copies often keep the original
  /// name while the cached [path] has no / a non-zip suffix.
  static bool isZipBackupFilename({
    required String path,
    String name = '',
  }) {
    return _endsWithZip(_basename(path)) || _endsWithZip(name.trim());
  }

  static bool _endsWithZip(String value) =>
      value.toLowerCase().endsWith('.zip');

  static String _basename(String path) {
    final normalized = path.replaceAll('\\', '/');
    final slash = normalized.lastIndexOf('/');
    return slash < 0 ? normalized : normalized.substring(slash + 1);
  }

  static Future<ShelfImportPickedFile?> _resolvePickedFile(
    ShelfImportFlowDeps deps,
  ) async {
    if (deps.pickBackupFile != null) {
      return deps.pickBackupFile!();
    }
    if (deps.pickZipPath != null) {
      final path = await deps.pickZipPath!();
      if (path == null || path.isEmpty) return null;
      return ShelfImportPickedFile.pathOnly(path);
    }
    return _defaultPickBackup();
  }

  static Future<ShelfImportPickedFile?> _defaultPickBackup() async {
    // FileType.any: Android MIME filters drop Drive/Gmail zips that are not
    // application/zip. Keep path-based pick (no withData) to avoid RAM load.
    final file = await FilePicker.pickFile(type: FileType.any);
    final path = file?.path;
    if (file == null || path == null || path.isEmpty) return null;
    return ShelfImportPickedFile(path: path, name: file.name);
  }

  static Future<void> _defaultSafetyZip({
    required CollectionSnapshot snapshot,
    required String memoryJson,
    required String uiPrefsJson,
  }) async {
    final outPath = await ShelfExportBackupStore.nextBackupPath();
    final written = await ShelfExportArchive.exportToZip(
      snapshot: snapshot,
      memoryJson: memoryJson,
      uiPrefsJson: uiPrefsJson,
      outputPath: outPath,
    );
    if (!written.wrote) {
      throw StateError('safety zip rejected');
    }
    await ShelfExportBackupStore.prune();
  }

  static Future<void> _defaultClearTemp() async {
    await FilePicker.clearTemporaryFiles();
  }

  static Future<void> _defaultGc(CollectionSnapshot snapshot) {
    return ShelfMediaVault.collectGarbage(snapshot);
  }

  static bool _isTooLargeMessage(String message) {
    final m = message.toLowerCase();
    return m.contains('too large') ||
        m.contains('exceeds limit') ||
        m.contains('extracted size');
  }
}

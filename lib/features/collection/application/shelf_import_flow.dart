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
    required this.createdAt,
  });

  /// Prefer snapshot tallies over manifest counts when they disagree.
  factory ShelfImportBackupSummary.fromStaging(ShelfExportStaging staging) {
    return ShelfImportBackupSummary(
      seriesCount: staging.snapshot.shelfSeries.length,
      figureCount: staging.snapshot.totalShelfFigures,
      createdAt: staging.manifest.createdAt,
    );
  }

  final int seriesCount;
  final int figureCount;

  /// Manifest `createdAt` (UTC). Display via [ShelfImportCopy.formatCreatedDate].
  final DateTime createdAt;
}

/// User-visible English copy for Settings → Import shelf.
abstract final class ShelfImportCopy {
  ShelfImportCopy._();

  static const importTitle = 'Import shelf';
  static const importSubtitle = 'Replace your shelf with a backup file';

  static const confirmTitle = 'Replace your shelf?';
  static const confirmBody =
      'This replaces your current collection with the backup. '
      'Your current shelf can\'t be restored after this.';
  static const confirmSafetyNote =
      'A safety copy is kept on this device for 7 days.';
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

  /// English summary line. [series] stays "series"; [figure]/[figures] pluralize.
  static String confirmSummary({
    required int seriesCount,
    required int figureCount,
    required String createdDate,
  }) {
    final seriesLabel =
        seriesCount == 1 ? '1 series' : '$seriesCount series';
    final figureLabel =
        figureCount == 1 ? '1 figure' : '$figureCount figures';
    return 'This backup has $seriesLabel and $figureLabel, created $createdDate.';
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
  failed,
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
    this.confirmReplace,
    this.unpack,
    this.writeSafetyZip,
    this.commitStaging,
    this.clearPickerTemp,
    this.collectGarbage,
    this.scheduleRecoveryPack,
  });

  /// Returns a filesystem path to a `.zip`, or null if the user cancelled.
  final Future<String?> Function()? pickZipPath;

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
    final pick = deps.pickZipPath ?? _defaultPickZip;
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

    String? pickedPath;
    try {
      pickedPath = await pick();
      if (pickedPath == null || pickedPath.isEmpty) {
        return const ShelfImportFlowResult(
          status: ShelfImportFlowStatus.cancelled,
        );
      }

      suspendPersistence();

      ShelfExportStaging? staging;
      try {
        try {
          staging = await unpackFn(pickedPath);
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

        final shelfEmpty = currentSnapshot.shelfSeries.isEmpty;
        if (!shelfEmpty) {
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

  /// Shared picker used by Settings and the default [ShelfImportFlowDeps].
  static Future<String?> pickZipPath() => _defaultPickZip();

  static Future<String?> _defaultPickZip() async {
    // file_picker 13+: path-based pick (no withData) — avoids loading zip RAM.
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['zip'],
    );
    return file?.path;
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

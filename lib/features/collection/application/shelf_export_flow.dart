import 'dart:io';

import 'package:blindbox_app/features/collection/data/shelf_export_archive.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/presentation/shelf_export_format.dart';
import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';

/// Injectable hooks for Settings export (tests override these).
@immutable
class ShelfExportFlowDeps {
  const ShelfExportFlowDeps({
    this.estimate,
    this.export,
    this.shareZip,
    this.deleteFile,
    this.cleanupStale,
    this.loadMemoryJson,
    this.loadUiPrefsJson,
  });

  final Future<ShelfExportSizeEstimate> Function({
    required CollectionSnapshot snapshot,
    required String memoryJson,
    required String uiPrefsJson,
  })?
  estimate;

  final Future<ShelfExportWriteResult> Function({
    required CollectionSnapshot snapshot,
    required String memoryJson,
    required String uiPrefsJson,
    void Function(int completed, int total)? onProgress,
  })?
  export;

  /// Shares [zipPath]; return value is ignored except for completion.
  final Future<Object?> Function(String zipPath)? shareZip;

  /// Used only when share throws (receiver never got the file).
  final Future<void> Function(String path)? deleteFile;

  /// Best-effort purge of zip/staging older than one day (before export).
  final Future<void> Function()? cleanupStale;

  /// Optional loaders for widget tests (avoid SharedPreferences channel waits).
  final Future<String> Function()? loadMemoryJson;
  final Future<String> Function()? loadUiPrefsJson;
}

/// Outcome of a Settings export attempt (read-only — never touches gate/prefs).
enum ShelfExportFlowStatus {
  success,
  cancelled,
  rejectedTooLarge,
  failed,
}

@immutable
class ShelfExportFlowResult {
  const ShelfExportFlowResult({
    required this.status,
    this.mediaIncomplete = false,
    this.estimatedBytes = 0,
  });

  final ShelfExportFlowStatus status;
  final bool mediaIncomplete;
  final int estimatedBytes;
}

/// Runs estimate → optional large confirm → zip → share.
///
/// Keeps the zip after share success/cancel so Android receivers can finish
/// reading it. Deletes immediately only when share throws. Stale cache files
/// are purged before export and on app startup.
abstract final class ShelfExportFlow {
  ShelfExportFlow._();

  static Future<ShelfExportFlowResult> run({
    required CollectionSnapshot snapshot,
    required String memoryJson,
    required String uiPrefsJson,
    required Future<bool> Function(String humanSize) confirmLargeBackup,
    required void Function(int completed, int total) onProgress,
    ShelfExportFlowDeps deps = const ShelfExportFlowDeps(),
  }) async {
    final cleanupFn = deps.cleanupStale ?? ShelfExportArchive.cleanupStaleExports;
    final estimateFn = deps.estimate ?? ShelfExportArchive.estimateSize;
    final exportFn = deps.export ?? _defaultExport;
    final shareFn = deps.shareZip ?? _defaultShare;
    final deleteFn = deps.deleteFile ?? _defaultDelete;

    try {
      await cleanupFn();
    } on Object {
      // best-effort; export may still succeed
    }

    late final ShelfExportSizeEstimate estimate;
    try {
      estimate = await estimateFn(
        snapshot: snapshot,
        memoryJson: memoryJson,
        uiPrefsJson: uiPrefsJson,
      );
    } on Object {
      return ShelfExportFlowResult(
        status: ShelfExportFlowStatus.failed,
        estimatedBytes: 0,
      );
    }

    if (estimate.exceedsRejectThreshold) {
      return ShelfExportFlowResult(
        status: ShelfExportFlowStatus.rejectedTooLarge,
        mediaIncomplete: estimate.mediaIncomplete,
        estimatedBytes: estimate.uncompressedBytes,
      );
    }

    if (estimate.exceedsWarnThreshold) {
      final ok = await confirmLargeBackup(
        ShelfExportFormat.formatBytes(estimate.uncompressedBytes),
      );
      if (!ok) {
        return ShelfExportFlowResult(
          status: ShelfExportFlowStatus.cancelled,
          mediaIncomplete: estimate.mediaIncomplete,
          estimatedBytes: estimate.uncompressedBytes,
        );
      }
    }

    late final ShelfExportWriteResult write;
    try {
      write = await exportFn(
        snapshot: snapshot,
        memoryJson: memoryJson,
        uiPrefsJson: uiPrefsJson,
        onProgress: onProgress,
      );
    } on Object {
      return ShelfExportFlowResult(
        status: ShelfExportFlowStatus.failed,
        mediaIncomplete: estimate.mediaIncomplete,
        estimatedBytes: estimate.uncompressedBytes,
      );
    }

    if (!write.wrote) {
      if (write.rejectReason == ShelfExportRejectReason.tooLarge) {
        return ShelfExportFlowResult(
          status: ShelfExportFlowStatus.rejectedTooLarge,
          mediaIncomplete: write.mediaIncomplete,
          estimatedBytes: write.uncompressedBytes,
        );
      }
      return ShelfExportFlowResult(
        status: ShelfExportFlowStatus.failed,
        mediaIncomplete: write.mediaIncomplete,
        estimatedBytes: write.uncompressedBytes,
      );
    }

    final zipPath = write.zipPath!;
    try {
      await shareFn(zipPath);
    } on Object {
      // Share never handed off — safe to delete immediately.
      await _safeDelete(deleteFn, zipPath);
      return ShelfExportFlowResult(
        status: ShelfExportFlowStatus.failed,
        mediaIncomplete: write.mediaIncomplete,
        estimatedBytes: write.uncompressedBytes,
      );
    }

    // Keep zip after share success/cancel; stale cleanup removes it later.
    return ShelfExportFlowResult(
      status: ShelfExportFlowStatus.success,
      mediaIncomplete: write.mediaIncomplete,
      estimatedBytes: write.uncompressedBytes,
    );
  }

  static Future<ShelfExportWriteResult> _defaultExport({
    required CollectionSnapshot snapshot,
    required String memoryJson,
    required String uiPrefsJson,
    void Function(int completed, int total)? onProgress,
  }) {
    return ShelfExportArchive.exportToZip(
      snapshot: snapshot,
      memoryJson: memoryJson,
      uiPrefsJson: uiPrefsJson,
      onProgress: onProgress,
    );
  }

  static Future<Object?> _defaultShare(String zipPath) {
    final name = zipPath.replaceAll('\\', '/').split('/').last;
    // PR4b contract: share_plus Share.shareXFiles for the zip handoff.
    // ignore: deprecated_member_use
    return Share.shareXFiles(
      [XFile(zipPath, mimeType: 'application/zip', name: name)],
      text: 'Shelfy shelf backup',
    );
  }

  static Future<void> _defaultDelete(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  static Future<void> _safeDelete(
    Future<void> Function(String path) deleteFn,
    String path,
  ) async {
    try {
      await deleteFn(path);
    } on Object {
      // best-effort cleanup
    }
  }
}

import 'dart:io';

import 'package:blindbox_app/features/collection/application/shelf_export_flow.dart';
import 'package:blindbox_app/features/collection/bootstrap/collection_recovery_gate.dart';
import 'package:blindbox_app/features/collection/data/shelf_export_archive.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    CollectionRecoveryGate.resetForTest();
    ShelfExportArchive.resetForTest();
  });

  test('rejects over hard limit without sharing', () async {
    var shareCalls = 0;
    var exportCalls = 0;
    final result = await ShelfExportFlow.run(
      snapshot: CollectionSnapshot.emptyTest(),
      memoryJson: '{}',
      uiPrefsJson: '{}',
      confirmLargeBackup: (_) async => true,
      onProgress: (_, _) {},
      deps: ShelfExportFlowDeps(
        estimate: ({
          required snapshot,
          required memoryJson,
          required uiPrefsJson,
        }) async {
          ShelfExportArchive.testRejectBytesOverride = 100;
          return const ShelfExportSizeEstimate(
            uncompressedBytes: 200,
            mediaIncomplete: false,
          );
        },
        export: ({
          required snapshot,
          required memoryJson,
          required uiPrefsJson,
          onProgress,
        }) async {
          exportCalls++;
          return ShelfExportWriteResult.rejected(
            uncompressedBytes: 200,
            mediaIncomplete: false,
            reason: ShelfExportRejectReason.tooLarge,
          );
        },
        shareZip: (_) async {
          shareCalls++;
          return null;
        },
      ),
    );
    expect(result.status, ShelfExportFlowStatus.rejectedTooLarge);
    expect(exportCalls, 0);
    expect(shareCalls, 0);
  });

  test('large warn Cancel skips export and share', () async {
    var exportCalls = 0;
    ShelfExportArchive.testWarnBytesOverride = 50;
    final result = await ShelfExportFlow.run(
      snapshot: CollectionSnapshot.emptyTest(),
      memoryJson: '{}',
      uiPrefsJson: '{}',
      confirmLargeBackup: (_) async => false,
      onProgress: (_, _) {},
      deps: ShelfExportFlowDeps(
        estimate: ({
          required snapshot,
          required memoryJson,
          required uiPrefsJson,
        }) async =>
            const ShelfExportSizeEstimate(
              uncompressedBytes: 80,
              mediaIncomplete: false,
            ),
        export: ({
          required snapshot,
          required memoryJson,
          required uiPrefsJson,
          onProgress,
        }) async {
          exportCalls++;
          return ShelfExportWriteResult.written(
            zipPath: 'x.zip',
            uncompressedBytes: 80,
            zipBytes: 10,
            mediaIncomplete: false,
            exceedsWarnThreshold: true,
            originalCount: 0,
            thumbCount: 0,
          );
        },
      ),
    );
    expect(result.status, ShelfExportFlowStatus.cancelled);
    expect(exportCalls, 0);
  });

  test('large warn Continue exports, shares, then deletes zip', () async {
    final temp = await Directory.systemTemp.createTemp('shelf_export_flow_');
    final zip = File('${temp.path}${Platform.pathSeparator}out.zip');
    await zip.writeAsBytes([1, 2, 3], flush: true);
    var shareCalls = 0;
    var deleted = false;

    ShelfExportArchive.testWarnBytesOverride = 50;
    final result = await ShelfExportFlow.run(
      snapshot: CollectionSnapshot.emptyTest(),
      memoryJson: '{}',
      uiPrefsJson: '{}',
      confirmLargeBackup: (_) async => true,
      onProgress: (_, _) {},
      deps: ShelfExportFlowDeps(
        estimate: ({
          required snapshot,
          required memoryJson,
          required uiPrefsJson,
        }) async =>
            const ShelfExportSizeEstimate(
              uncompressedBytes: 80,
              mediaIncomplete: true,
            ),
        export: ({
          required snapshot,
          required memoryJson,
          required uiPrefsJson,
          onProgress,
        }) async {
          onProgress?.call(1, 2);
          onProgress?.call(2, 2);
          return ShelfExportWriteResult.written(
            zipPath: zip.path,
            uncompressedBytes: 80,
            zipBytes: 3,
            mediaIncomplete: true,
            exceedsWarnThreshold: true,
            originalCount: 0,
            thumbCount: 0,
          );
        },
        shareZip: (path) async {
          shareCalls++;
          expect(path, zip.path);
          expect(File(path).existsSync(), isTrue);
          return null;
        },
        deleteFile: (path) async {
          deleted = true;
          await File(path).delete();
        },
      ),
    );

    expect(result.status, ShelfExportFlowStatus.success);
    expect(result.mediaIncomplete, isTrue);
    expect(shareCalls, 1);
    expect(deleted, isTrue);
    expect(zip.existsSync(), isFalse);
    expect(CollectionRecoveryGate.isPending, isFalse);
    await temp.delete(recursive: true);
  });

  test('share cancel path still deletes zip', () async {
    final temp = await Directory.systemTemp.createTemp('shelf_export_flow2_');
    final zip = File('${temp.path}${Platform.pathSeparator}out.zip');
    await zip.writeAsBytes([9], flush: true);

    final result = await ShelfExportFlow.run(
      snapshot: CollectionSnapshot.emptyTest(),
      memoryJson: '{}',
      uiPrefsJson: '{}',
      confirmLargeBackup: (_) async => true,
      onProgress: (_, _) {},
      deps: ShelfExportFlowDeps(
        estimate: ({
          required snapshot,
          required memoryJson,
          required uiPrefsJson,
        }) async =>
            const ShelfExportSizeEstimate(
              uncompressedBytes: 10,
              mediaIncomplete: false,
            ),
        export: ({
          required snapshot,
          required memoryJson,
          required uiPrefsJson,
          onProgress,
        }) async {
          return ShelfExportWriteResult.written(
            zipPath: zip.path,
            uncompressedBytes: 10,
            zipBytes: 1,
            mediaIncomplete: false,
            exceedsWarnThreshold: false,
            originalCount: 0,
            thumbCount: 0,
          );
        },
        shareZip: (_) async {
          // User dismissed the sheet — still completes.
          return null;
        },
        deleteFile: (path) async {
          await File(path).delete();
        },
      ),
    );

    expect(result.status, ShelfExportFlowStatus.success);
    expect(zip.existsSync(), isFalse);
    await temp.delete(recursive: true);
  });

  test('export failure does not share and leaves gate untouched', () async {
    CollectionRecoveryGate.enterPending();
    var shareCalls = 0;
    final result = await ShelfExportFlow.run(
      snapshot: CollectionSnapshot.emptyTest(),
      memoryJson: '{}',
      uiPrefsJson: '{}',
      confirmLargeBackup: (_) async => true,
      onProgress: (_, _) {},
      deps: ShelfExportFlowDeps(
        estimate: ({
          required snapshot,
          required memoryJson,
          required uiPrefsJson,
        }) async =>
            const ShelfExportSizeEstimate(
              uncompressedBytes: 10,
              mediaIncomplete: false,
            ),
        export: ({
          required snapshot,
          required memoryJson,
          required uiPrefsJson,
          onProgress,
        }) async {
          throw StateError('boom');
        },
        shareZip: (_) async {
          shareCalls++;
          return null;
        },
      ),
    );
    expect(result.status, ShelfExportFlowStatus.failed);
    expect(shareCalls, 0);
    expect(CollectionRecoveryGate.isPending, isTrue);
    CollectionRecoveryGate.clearPending();
  });
}

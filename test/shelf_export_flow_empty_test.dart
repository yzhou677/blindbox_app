import 'dart:io';

import 'package:blindbox_app/features/collection/application/shelf_export_flow.dart';
import 'package:blindbox_app/features/collection/bootstrap/collection_recovery_gate.dart';
import 'package:blindbox_app/features/collection/data/shelf_export_archive.dart';
import 'package:blindbox_app/features/collection/data/shelf_media_vault.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory support;
  late Directory cache;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    support = await Directory.systemTemp.createTemp('export_empty_sup_');
    cache = await Directory.systemTemp.createTemp('export_empty_cache_');
    CollectionRecoveryGate.resetForTest();
    ShelfMediaVault.resetForTest();
    ShelfExportArchive.resetForTest();
    ShelfExportBackupStore.resetForTest();
    ShelfMediaVault.testSupportOverride = support;
    ShelfExportBackupStore.testSupportOverride = support;
    ShelfExportArchive.testCacheOverride = cache;
    await ShelfMediaVault.ensureReady();
  });

  tearDown(() async {
    CollectionRecoveryGate.resetForTest();
    ShelfMediaVault.resetForTest();
    ShelfExportArchive.resetForTest();
    ShelfExportBackupStore.resetForTest();
    try {
      await support.delete(recursive: true);
    } on Object {
      // ignore
    }
    try {
      await cache.delete(recursive: true);
    } on Object {
      // ignore
    }
  });

  test('ShelfExportFlow empty shelf returns cancelled without zip', () async {
    var exportCalls = 0;
    var shareCalls = 0;
    final result = await ShelfExportFlow.run(
      snapshot: CollectionSnapshot.emptyTest(),
      memoryJson: '{}',
      uiPrefsJson: '{}',
      confirmLargeBackup: (_) async => true,
      onProgress: (completed, total) {},
      deps: ShelfExportFlowDeps(
        cleanupStale: () async {},
        export: ({
          required snapshot,
          required memoryJson,
          required uiPrefsJson,
          onProgress,
        }) async {
          exportCalls++;
          fail('should not export empty shelf');
        },
        shareZip: (_) async {
          shareCalls++;
          return null;
        },
      ),
    );
    expect(result.status, ShelfExportFlowStatus.cancelled);
    expect(exportCalls, 0);
    expect(shareCalls, 0);
  });

  test('wishlist-only shelf exports zip containing seriesWishlist', () async {
    final wishlistOnly = CollectionSnapshot(
      shelfSeries: const [],
      figureStates: const {},
      seriesWishlist: [
        WishlistedCatalogSeries(
          catalogSeriesId: 'wish-1',
          name: 'Wish',
          brand: 'B',
          ipName: 'I',
          imageKey: 'k',
          addedAtMicros: 1,
        ),
      ],
    );
    expect(wishlistOnly.isEmptyShelf, isFalse);

    CollectionSnapshot? exportedSnap;
    final result = await ShelfExportFlow.run(
      snapshot: wishlistOnly,
      memoryJson: '{}',
      uiPrefsJson: '{}',
      confirmLargeBackup: (_) async => true,
      onProgress: (completed, total) {},
      deps: ShelfExportFlowDeps(
        cleanupStale: () async {},
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
          exportedSnap = snapshot;
          final written = await ShelfExportArchive.exportToZip(
            snapshot: snapshot,
            memoryJson: memoryJson,
            uiPrefsJson: uiPrefsJson,
          );
          expect(written.wrote, isTrue);
          return written;
        },
        shareZip: (_) async => null,
      ),
    );

    expect(result.status, ShelfExportFlowStatus.success);
    expect(exportedSnap!.seriesWishlist.single.catalogSeriesId, 'wish-1');
  });
}

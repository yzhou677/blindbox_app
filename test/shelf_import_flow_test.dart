import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/collection/application/collection_shelf_ui_prefs_provider.dart';
import 'package:blindbox_app/features/collection/application/shelf_backup_commit.dart';
import 'package:blindbox_app/features/collection/application/shelf_import_flow.dart';
import 'package:blindbox_app/features/collection/bootstrap/collection_app_bootstrap.dart';
import 'package:blindbox_app/features/collection/bootstrap/collection_recovery_gate.dart';
import 'package:blindbox_app/features/collection/data/collection_memory_store.dart';
import 'package:blindbox_app/features/collection/data/shelf_export_archive.dart';
import 'package:blindbox_app/features/collection/data/shelf_media_vault.dart';
import 'package:blindbox_app/features/collection/data/shelf_recovery_pack.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/persistence/collection_snapshot_codec.dart';
import 'package:blindbox_app/features/collection/persistence/collection_snapshot_storage.dart';
import 'package:blindbox_app/features/collection/presentation/collection_shelf_browse.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';

Uint8List _jpegBytes({int r = 90}) {
  final image = img.Image(width: 32, height: 32);
  img.fill(image, color: img.ColorRgb8(r, 40, 160));
  return Uint8List.fromList(img.encodeJpg(image, quality: 85));
}

Uint8List _pngBytes() {
  final image = img.Image(width: 40, height: 40);
  img.fill(image, color: img.ColorRgb8(20, 180, 90));
  return Uint8List.fromList(img.encodePng(image));
}

Future<void> _writeCraftedZip(String zipPath, Map<String, List<int>> entries) async {
  final archive = Archive();
  for (final e in entries.entries) {
    archive.addFile(ArchiveFile(e.key, e.value.length, e.value));
  }
  final bytes = ZipEncoder().encodeBytes(archive);
  await File(zipPath).writeAsBytes(bytes, flush: true);
}

Future<void> _reset(Directory support, Directory cache) async {
  SharedPreferences.setMockInitialValues({});
  CollectionMemoryStore.instance.resetForTest();
  CollectionRecoveryGate.resetForTest();
  ShelfBackupCommit.testBeforeMemoryHook = null;
  ShelfBackupCommit.testBeforeSnapshotSaveHook = null;
  ShelfMediaVault.resetForTest();
  ShelfRecoveryPack.resetForTest();
  ShelfExportArchive.resetForTest();
  ShelfExportBackupStore.resetForTest();
  ShelfMediaVault.testSupportOverride = support;
  ShelfRecoveryPack.testSupportOverride = support;
  ShelfExportBackupStore.testSupportOverride = support;
  ShelfExportArchive.testCacheOverride = cache;
  await ShelfMediaVault.ensureReady();
}

CollectionSnapshot _snap({
  required String seriesId,
  required String name,
  String? mediaRef,
}) {
  return CollectionSnapshot(
    shelfSeries: [
      ShelfSeries(
        id: seriesId,
        name: name,
        brand: 'Brand',
        ipName: 'IP',
        figures: [
          ShelfFigure(
            id: '${seriesId}_f1',
            seriesId: seriesId,
            name: 'Fig',
            localImageUri: mediaRef,
            rarity: 'Regular',
            isSecret: false,
          ),
        ],
        shelfAccent: const Color(0xFFE8F5E9),
      ),
    ],
    figureStates: const {},
  );
}

void main() {
  late Directory tempSupport;
  late Directory tempCache;

  setUp(() async {
    tempSupport = await Directory.systemTemp.createTemp('shelf_import_sup_');
    tempCache = await Directory.systemTemp.createTemp('shelf_import_cache_');
    await _reset(tempSupport, tempCache);
  });

  tearDown(() async {
    ShelfBackupCommit.testBeforeMemoryHook = null;
    ShelfBackupCommit.testBeforeSnapshotSaveHook = null;
    CollectionRecoveryGate.resetForTest();
    ShelfMediaVault.resetForTest();
    ShelfRecoveryPack.resetForTest();
    ShelfExportArchive.resetForTest();
    ShelfExportBackupStore.resetForTest();
    CollectionMemoryStore.instance.resetForTest();
    try {
      await tempSupport.delete(recursive: true);
    } on Object {
      // ignore
    }
    try {
      await tempCache.delete(recursive: true);
    } on Object {
      // ignore
    }
  });

  test('pick cancel leaves shelf unchanged', () async {
    final current = _snap(seriesId: 'old', name: 'Old');
    await CollectionSnapshotStorage.save(current);
    await CollectionMemoryStore.instance.replaceFromRecoveryJson(
      '{"firstSeriesAddedAtMs":1}',
    );

    var suspended = false;
    final result = await ShelfImportFlow.run(
      currentSnapshot: current,
      currentMemoryJson: '{"firstSeriesAddedAtMs":1}',
      currentUiPrefsJson: '{}',
      suspendPersistence: () => suspended = true,
      replaceNotifierState: (_) {},
      resumePersistence: () {},
      reloadUiPrefs: () async {},
      deps: ShelfImportFlowDeps(
        pickZipPath: () async => null,
        confirmReplace: (_) async => true,
        clearPickerTemp: () async {},
      ),
    );

    expect(result.status, ShelfImportFlowStatus.cancelled);
    expect(suspended, isFalse);
    final after = await CollectionSnapshotStorage.load();
    expect(after!.shelfSeries.single.name, 'Old');
  });

  test('confirm Cancel deletes staging and leaves shelf unchanged', () async {
    final current = _snap(seriesId: 'old', name: 'Old');
    await CollectionSnapshotStorage.save(current);

    CollectionAppBootstrap.prime(current);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(collectionNotifierProvider.notifier);

    var stagingDeleted = false;
    var resumeCalls = 0;
    var packCalls = 0;
    ShelfImportBackupSummary? seenSummary;
    final staging = _CancelStaging(
      onDelete: () => stagingDeleted = true,
      snapshot: _snap(seriesId: 'new', name: 'Would Import'),
      createdAt: DateTime.utc(2026, 3, 15),
    );

    final result = await ShelfImportFlow.run(
      currentSnapshot: current,
      currentMemoryJson: '{}',
      currentUiPrefsJson: '{}',
      suspendPersistence: notifier.suspendPersistenceForImport,
      replaceNotifierState: (_) => fail('should not replace'),
      resumePersistence: () {
        resumeCalls++;
        notifier.resumePersistence();
      },
      reloadUiPrefs: () async {},
      deps: ShelfImportFlowDeps(
        pickZipPath: () async => 'fake.zip',
        unpack: (_) async => staging,
        confirmReplace: (summary) async {
          seenSummary = summary;
          expect(notifier.persistenceSuspendedForTest, isTrue);
          return false;
        },
        commitStaging: (_) async => fail('should not commit'),
        clearPickerTemp: () async {},
        scheduleRecoveryPack: (_) => packCalls++,
      ),
    );

    expect(result.status, ShelfImportFlowStatus.cancelled);
    expect(stagingDeleted, isTrue);
    expect(resumeCalls, 1);
    expect(packCalls, 0);
    expect(notifier.persistenceSuspendedForTest, isFalse);
    expect(seenSummary!.seriesCount, 1);
    expect(seenSummary!.figureCount, 1);
    final after = await CollectionSnapshotStorage.load();
    expect(after!.shelfSeries.single.name, 'Old');
    expect(
      container.read(collectionNotifierProvider).shelfSeries.single.name,
      'Old',
    );
  });

  test('confirm summary uses snapshot counts over tampered manifest', () async {
    final snap = CollectionSnapshot(
      shelfSeries: [
        ShelfSeries(
          id: 's1',
          name: 'A',
          brand: 'B',
          ipName: 'I',
          figures: [
            ShelfFigure(
              id: 'f1',
              seriesId: 's1',
              name: 'One',
              rarity: 'Regular',
              isSecret: false,
            ),
            ShelfFigure(
              id: 'f2',
              seriesId: 's1',
              name: 'Two',
              rarity: 'Regular',
              isSecret: false,
            ),
          ],
          shelfAccent: const Color(0xFFE8F5E9),
        ),
      ],
      figureStates: const {},
    );
    final staging = ShelfExportStaging(
      stagingDir: Directory.systemTemp,
      manifest: ShelfExportManifest(
        kind: ShelfExportArchive.kind,
        schemaVersion: 1,
        createdAt: DateTime.utc(2026, 1, 1),
        appVersion: '1',
        seriesCount: 99,
        figureCount: 99,
        originalCount: 0,
        thumbCount: 0,
        mediaIncomplete: false,
      ),
      snapshot: snap,
      memoryJson: '{}',
      uiPrefsJson: '{}',
      originalFiles: const {},
      thumbFiles: const {},
      extractedBytes: 0,
    );

    ShelfImportBackupSummary? seen;
    final result = await ShelfImportFlow.run(
      currentSnapshot: CollectionSnapshot.emptyTest(),
      currentMemoryJson: '{}',
      currentUiPrefsJson: '{}',
      suspendPersistence: () {},
      replaceNotifierState: (_) {},
      resumePersistence: () {},
      reloadUiPrefs: () async {},
      deps: ShelfImportFlowDeps(
        pickZipPath: () async => 'x.zip',
        unpack: (_) async => staging,
        confirmReplace: (summary) async {
          seen = summary;
          return false;
        },
        clearPickerTemp: () async {},
        scheduleRecoveryPack: (_) {},
      ),
    );

    expect(result.status, ShelfImportFlowStatus.cancelled);
    expect(seen!.seriesCount, 1);
    expect(seen!.figureCount, 2);
  });

  test('bad zip fails before confirm dialog', () async {
    final old = _snap(seriesId: 'old', name: 'Keep');
    await CollectionSnapshotStorage.save(old);
    var confirmCalls = 0;
    final corrupt = File('${tempCache.path}${Platform.pathSeparator}bad.zip');
    await corrupt.writeAsBytes([1, 2, 3], flush: true);

    final result = await ShelfImportFlow.run(
      currentSnapshot: old,
      currentMemoryJson: '{}',
      currentUiPrefsJson: '{}',
      suspendPersistence: () {},
      replaceNotifierState: (_) => fail('no'),
      resumePersistence: () {},
      reloadUiPrefs: () async {},
      deps: ShelfImportFlowDeps(
        pickZipPath: () async => corrupt.path,
        confirmReplace: (_) async {
          confirmCalls++;
          return true;
        },
        clearPickerTemp: () async {},
        scheduleRecoveryPack: (_) {},
      ),
    );

    expect(result.status, ShelfImportFlowStatus.failed);
    expect(confirmCalls, 0);
    final after = await CollectionSnapshotStorage.load();
    expect(after!.shelfSeries.single.name, 'Keep');
  });

  test('happy path import replaces prefs memory media and notifier', () async {
    final png = _pngBytes();
    final thumb = _jpegBytes(r: 11);
    final ref = await ShelfMediaVault.installExportedOriginal(
      id: 'img1',
      originalBytes: png,
      ext: '.png',
      thumbBytes: thumb,
    );
    final backupSnap = _snap(seriesId: 'new', name: 'Imported', mediaRef: ref);
    final memoryJson = '{"firstSeriesAddedAtMs":42}';
    final uiPrefsJson = jsonEncode({
      'sort': CollectionShelfSort.alphabetical.name,
    });
    final exported = await ShelfExportArchive.exportToZip(
      snapshot: backupSnap,
      memoryJson: memoryJson,
      uiPrefsJson: uiPrefsJson,
    );
    expect(exported.wrote, isTrue);

    final old = _snap(seriesId: 'old', name: 'Old Shelf');
    await CollectionSnapshotStorage.save(old);
    await CollectionMemoryStore.instance.replaceFromRecoveryJson(
      '{"firstSeriesAddedAtMs":1}',
    );
    await CollectionShelfUiPrefsStorage.save(const CollectionShelfUiPrefs());

    CollectionAppBootstrap.prime(old);
    late CollectionSnapshot notifierState;
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(collectionNotifierProvider.notifier);
    expect(container.read(collectionNotifierProvider).shelfSeries.single.name, 'Old Shelf');

    var clearedTemp = false;
    CollectionSnapshot? scheduledPackSnap;
    final result = await ShelfImportFlow.run(
      currentSnapshot: old,
      currentMemoryJson: '{"firstSeriesAddedAtMs":1}',
      currentUiPrefsJson: '{}',
      suspendPersistence: notifier.suspendPersistenceForImport,
      replaceNotifierState: (snap) {
        notifier.replaceStateFromImport(snap);
        notifierState = snap;
      },
      resumePersistence: notifier.resumePersistence,
      reloadUiPrefs: () async {
        await container
            .read(collectionShelfUiPrefsProvider.notifier)
            .reloadFromStorage();
      },
      deps: ShelfImportFlowDeps(
        pickZipPath: () async => exported.zipPath,
        confirmReplace: (_) async => true,
        clearPickerTemp: () async {
          clearedTemp = true;
        },
        collectGarbage: (_) async {},
        scheduleRecoveryPack: (snap) {
          scheduledPackSnap = snap;
        },
      ),
    );

    expect(result.status, ShelfImportFlowStatus.success);
    expect(clearedTemp, isTrue);
    expect(scheduledPackSnap!.shelfSeries.single.name, 'Imported');
    expect(notifier.persistenceSuspendedForTest, isFalse);

    final prefsSnap = await CollectionSnapshotStorage.load();
    expect(prefsSnap!.shelfSeries.single.name, 'Imported');
    expect(notifierState.shelfSeries.single.name, 'Imported');
    expect(
      container.read(collectionNotifierProvider).shelfSeries.single.name,
      'Imported',
    );

    await CollectionMemoryStore.instance.ensureLoaded();
    expect(CollectionMemoryStore.instance.cached.firstSeriesAddedAtMs, 42);

    final loadedPrefs = await CollectionShelfUiPrefsStorage.load();
    expect(loadedPrefs.sort, CollectionShelfSort.alphabetical);

    final paths = await ShelfMediaVault.pathsForId('img1');
    expect(File(paths.originalPath!).readAsBytesSync(), png);
    expect(File(paths.thumbPath!).readAsBytesSync(), thumb);

    final backups = await ShelfExportBackupStore.directory();
    final safety = backups
        .listSync()
        .whereType<File>()
        .where((f) => f.path.contains('pre_import_'))
        .toList();
    expect(safety, isNotEmpty);
  });

  test('empty current shelf skips safety zip', () async {
    final empty = CollectionSnapshot.emptyTest();
    await CollectionSnapshotStorage.save(empty);
    final backup = await ShelfExportArchive.exportToZip(
      snapshot: _snap(seriesId: 'n', name: 'N'),
      memoryJson: '{}',
      uiPrefsJson: '{}',
    );

    var safetyCalls = 0;
    final result = await ShelfImportFlow.run(
      currentSnapshot: empty,
      currentMemoryJson: '{}',
      currentUiPrefsJson: '{}',
      suspendPersistence: () {},
      replaceNotifierState: (_) {},
      resumePersistence: () {},
      reloadUiPrefs: () async {},
      deps: ShelfImportFlowDeps(
        pickZipPath: () async => backup.zipPath,
        confirmReplace: (_) async => true,
        writeSafetyZip: ({
          required snapshot,
          required memoryJson,
          required uiPrefsJson,
        }) async {
          safetyCalls++;
        },
        clearPickerTemp: () async {},
        collectGarbage: (_) async {},
      ),
    );
    expect(result.status, ShelfImportFlowStatus.success);
    expect(safetyCalls, 0);
    final dir = await ShelfExportBackupStore.directory();
    final safetyFiles = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.uri.pathSegments.last.startsWith('pre_import_'));
    expect(safetyFiles, isEmpty);
  });

  test('safety zip failure cancels import and keeps old shelf', () async {
    final old = _snap(seriesId: 'old', name: 'Keep');
    await CollectionSnapshotStorage.save(old);
    final backup = await ShelfExportArchive.exportToZip(
      snapshot: _snap(seriesId: 'n', name: 'New'),
      memoryJson: '{}',
      uiPrefsJson: '{}',
    );

    var packCalls = 0;
    final result = await ShelfImportFlow.run(
      currentSnapshot: old,
      currentMemoryJson: '{}',
      currentUiPrefsJson: '{}',
      suspendPersistence: () {},
      replaceNotifierState: (_) => fail('should not replace'),
      resumePersistence: () {},
      reloadUiPrefs: () async {},
      deps: ShelfImportFlowDeps(
        pickZipPath: () async => backup.zipPath,
        confirmReplace: (_) async => true,
        writeSafetyZip: ({
          required snapshot,
          required memoryJson,
          required uiPrefsJson,
        }) async {
          throw StateError('disk full');
        },
        clearPickerTemp: () async {},
        scheduleRecoveryPack: (_) => packCalls++,
      ),
    );
    expect(result.status, ShelfImportFlowStatus.safetyCopyFailed);
    expect(packCalls, 0);
    final after = await CollectionSnapshotStorage.load();
    expect(after!.shelfSeries.single.name, 'Keep');
  });

  test('bad zip / kind / schema / traversal fail without changing shelf',
      () async {
    final old = _snap(seriesId: 'old', name: 'Keep');
    await CollectionSnapshotStorage.save(old);
    await CollectionMemoryStore.instance.replaceFromRecoveryJson(
      '{"firstSeriesAddedAtMs":9}',
    );

    Future<void> expectFail(String zipPath) async {
      final cacheBefore = Directory(
        '${tempCache.path}${Platform.pathSeparator}shelf_export',
      );
      var packCalls = 0;
      final result = await ShelfImportFlow.run(
        currentSnapshot: old,
        currentMemoryJson: '{"firstSeriesAddedAtMs":9}',
        currentUiPrefsJson: '{}',
        suspendPersistence: () {},
        replaceNotifierState: (_) => fail('no replace'),
        resumePersistence: () {},
        reloadUiPrefs: () async {},
        deps: ShelfImportFlowDeps(
          pickZipPath: () async => zipPath,
          confirmReplace: (_) async => true,
          clearPickerTemp: () async {},
          scheduleRecoveryPack: (_) => packCalls++,
        ),
      );
      expect(result.status, ShelfImportFlowStatus.failed);
      expect(packCalls, 0);
      final after = await CollectionSnapshotStorage.load();
      expect(after!.shelfSeries.single.name, 'Keep');
      await CollectionMemoryStore.instance.ensureLoaded();
      expect(CollectionMemoryStore.instance.cached.firstSeriesAddedAtMs, 9);
      if (await cacheBefore.exists()) {
        for (final e in cacheBefore.listSync()) {
          if (e is Directory &&
              e.path.contains(ShelfExportArchive.unpackStagingPrefix)) {
            fail('staging leftover: ${e.path}');
          }
        }
      }
    }

    final corrupt = File('${tempCache.path}${Platform.pathSeparator}c.zip');
    await corrupt.writeAsBytes([1, 2, 3], flush: true);
    await expectFail(corrupt.path);

    final badKind = File('${tempCache.path}${Platform.pathSeparator}k.zip');
    await _writeCraftedZip(badKind.path, {
      'shelfy_shelf_export/manifest.json': utf8.encode(
        jsonEncode({
          'kind': 'not_export',
          'schemaVersion': 1,
          'createdAt': '2026-01-01T00:00:00.000Z',
          'appVersion': '1',
        }),
      ),
      'shelfy_shelf_export/collection_snapshot_v1.json': utf8.encode(
        CollectionSnapshotCodec.encode(CollectionSnapshot.emptyTest()),
      ),
    });
    await expectFail(badKind.path);

    final badSchema = File('${tempCache.path}${Platform.pathSeparator}s.zip');
    await _writeCraftedZip(badSchema.path, {
      'shelfy_shelf_export/manifest.json': utf8.encode(
        jsonEncode({
          'kind': 'shelf_export',
          'schemaVersion': 99,
          'createdAt': '2026-01-01T00:00:00.000Z',
          'appVersion': '1',
        }),
      ),
      'shelfy_shelf_export/collection_snapshot_v1.json': utf8.encode(
        CollectionSnapshotCodec.encode(CollectionSnapshot.emptyTest()),
      ),
    });
    await expectFail(badSchema.path);

    final trav = File('${tempCache.path}${Platform.pathSeparator}t.zip');
    await _writeCraftedZip(trav.path, {
      'shelfy_shelf_export/../evil.txt': utf8.encode('x'),
      'shelfy_shelf_export/manifest.json': utf8.encode(
        jsonEncode({
          'kind': 'shelf_export',
          'schemaVersion': 1,
          'createdAt': '2026-01-01T00:00:00.000Z',
          'appVersion': '1',
        }),
      ),
      'shelfy_shelf_export/collection_snapshot_v1.json': utf8.encode(
        CollectionSnapshotCodec.encode(CollectionSnapshot.emptyTest()),
      ),
    });
    await expectFail(trav.path);
  });

  test('over size limit rejects with tooLarge status', () async {
    ShelfExportArchive.testRejectBytesOverride = 50;
    final old = _snap(seriesId: 'old', name: 'Keep');
    await CollectionSnapshotStorage.save(old);

    final big = List<int>.filled(200, 7);
    await ShelfMediaVault.installExportedOriginal(
      id: 'huge',
      originalBytes: big,
      ext: '.bin',
      thumbBytes: _jpegBytes(),
    );
    // Build zip with small reject disabled for export, then import with limit.
    ShelfExportArchive.testRejectBytesOverride = null;
    final exported = await ShelfExportArchive.exportToZip(
      snapshot: _snap(
        seriesId: 'n',
        name: 'Huge',
        mediaRef: 'shelf_media/originals/huge.bin',
      ),
      memoryJson: '{}',
      uiPrefsJson: '{}',
    );
    expect(exported.wrote, isTrue);

    ShelfExportArchive.testRejectBytesOverride = 50;
    var packCalls = 0;
    final result = await ShelfImportFlow.run(
      currentSnapshot: old,
      currentMemoryJson: '{}',
      currentUiPrefsJson: '{}',
      suspendPersistence: () {},
      replaceNotifierState: (_) => fail('no'),
      resumePersistence: () {},
      reloadUiPrefs: () async {},
      deps: ShelfImportFlowDeps(
        pickZipPath: () async => exported.zipPath,
        confirmReplace: (_) async => true,
        clearPickerTemp: () async {},
        scheduleRecoveryPack: (_) => packCalls++,
      ),
    );
    expect(result.status, ShelfImportFlowStatus.rejectedTooLarge);
    expect(packCalls, 0);
    final after = await CollectionSnapshotStorage.load();
    expect(after!.shelfSeries.single.name, 'Keep');
  });

  test('successful import refreshes real recovery pack', () async {
    // Suite keeps debounceEnabledForTest=false so scheduleWrite no-ops.
    // Inject real ShelfRecoveryPack.write (immediate, no debounce timer).
    final old = _snap(seriesId: 'old', name: 'Old Pack');
    await CollectionSnapshotStorage.save(old);
    await CollectionMemoryStore.instance.replaceFromRecoveryJson('{}');
    await ShelfRecoveryPack.write(
      snapshot: old,
      memoryJson: '{}',
      uiPrefsJson: '{}',
    );
    final before = await ShelfRecoveryPack.tryLoad();
    expect(before!.snapshot.shelfSeries.single.name, 'Old Pack');

    final backup = await ShelfExportArchive.exportToZip(
      snapshot: _snap(seriesId: 'new', name: 'Imported Pack'),
      memoryJson: '{}',
      uiPrefsJson: '{}',
    );

    final packWrites = <Future<void>>[];
    final result = await ShelfImportFlow.run(
      currentSnapshot: old,
      currentMemoryJson: '{}',
      currentUiPrefsJson: '{}',
      suspendPersistence: () {},
      replaceNotifierState: (_) {},
      resumePersistence: () {},
      reloadUiPrefs: () async {},
      deps: ShelfImportFlowDeps(
        pickZipPath: () async => backup.zipPath,
        confirmReplace: (_) async => true,
        writeSafetyZip: ({
          required snapshot,
          required memoryJson,
          required uiPrefsJson,
        }) async {},
        clearPickerTemp: () async {},
        collectGarbage: (_) async {},
        scheduleRecoveryPack: (snap) {
          packWrites.add(
            ShelfRecoveryPack.write(snapshot: snap).then((_) {}),
          );
        },
      ),
    );

    expect(result.status, ShelfImportFlowStatus.success);
    expect(packWrites, isNotEmpty);
    await Future.wait(packWrites);
    final after = await ShelfRecoveryPack.tryLoad();
    expect(after!.snapshot.shelfSeries.single.name, 'Imported Pack');
  });

  test('thumb-only Replace import overwrites existing original bytes', () async {
    final oldOriginal = _pngBytes();
    final backupThumb = _jpegBytes(r: 200);
    await ShelfMediaVault.installExportedOriginal(
      id: 'A',
      originalBytes: oldOriginal,
      ext: '.png',
      thumbBytes: _jpegBytes(r: 1),
    );
    final beforePaths = await ShelfMediaVault.pathsForId('A');
    final oldPngPath = beforePaths.originalPath!;
    expect(oldPngPath.endsWith('.png'), isTrue);
    expect(File(oldPngPath).existsSync(), isTrue);

    final backupSnap = _snap(
      seriesId: 'imported',
      name: 'ThumbOnly',
      mediaRef: 'shelf_media/originals/A.png',
    );
    final zipPath =
        '${tempCache.path}${Platform.pathSeparator}thumb_only_import.zip';
    await _writeCraftedZip(zipPath, {
      'shelfy_shelf_export/manifest.json': utf8.encode(
        jsonEncode({
          'kind': 'shelf_export',
          'schemaVersion': 1,
          'createdAt': '2026-01-01T00:00:00.000Z',
          'appVersion': '1',
          'seriesCount': 1,
          'figureCount': 1,
          'originalCount': 0,
          'thumbCount': 1,
          'mediaIncomplete': true,
        }),
      ),
      'shelfy_shelf_export/collection_snapshot_v1.json': utf8.encode(
        CollectionSnapshotCodec.encode(backupSnap),
      ),
      'shelfy_shelf_export/collection_memory.json': utf8.encode('{}'),
      'shelfy_shelf_export/collection_shelf_ui_prefs.json': utf8.encode('{}'),
      'shelfy_shelf_export/thumbs/A.jpg': backupThumb,
    });

    final old = _snap(
      seriesId: 'old',
      name: 'Old With Png',
      mediaRef: 'shelf_media/originals/A.png',
    );
    await CollectionSnapshotStorage.save(old);

    final result = await ShelfImportFlow.run(
      currentSnapshot: old,
      currentMemoryJson: '{}',
      currentUiPrefsJson: '{}',
      suspendPersistence: () {},
      replaceNotifierState: (_) {},
      resumePersistence: () {},
      reloadUiPrefs: () async {},
      deps: ShelfImportFlowDeps(
        pickZipPath: () async => zipPath,
        confirmReplace: (_) async => true,
        writeSafetyZip: ({
          required snapshot,
          required memoryJson,
          required uiPrefsJson,
        }) async {},
        clearPickerTemp: () async {},
        collectGarbage: (_) async {},
        scheduleRecoveryPack: (_) {},
      ),
    );

    expect(result.status, ShelfImportFlowStatus.success);
    expect(File(oldPngPath).existsSync(), isFalse);
    final afterPaths = await ShelfMediaVault.pathsForId('A');
    expect(afterPaths.originalPath!.endsWith('.jpg'), isTrue);
    expect(File(afterPaths.originalPath!).readAsBytesSync(), backupThumb);
    expect(
      await ShelfMediaVault.recoveredFromThumbForTest('shelf_media/originals/A.jpg'),
      isTrue,
    );
  });

  test('commit mid-failure keeps old snapshot and resumes persist', () async {
    final old = _snap(seriesId: 'old', name: 'Keep');
    await CollectionSnapshotStorage.save(old);
    final backup = await ShelfExportArchive.exportToZip(
      snapshot: _snap(seriesId: 'n', name: 'New'),
      memoryJson: '{}',
      uiPrefsJson: '{}',
    );

    CollectionAppBootstrap.prime(old);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(collectionNotifierProvider.notifier);

    ShelfBackupCommit.testBeforeSnapshotSaveHook = () async {
      throw StateError('boom');
    };

    var packCalls = 0;
    final result = await ShelfImportFlow.run(
      currentSnapshot: old,
      currentMemoryJson: '{}',
      currentUiPrefsJson: '{}',
      suspendPersistence: notifier.suspendPersistenceForImport,
      replaceNotifierState: notifier.replaceStateFromImport,
      resumePersistence: notifier.resumePersistence,
      reloadUiPrefs: () async {},
      deps: ShelfImportFlowDeps(
        pickZipPath: () async => backup.zipPath,
        confirmReplace: (_) async => true,
        writeSafetyZip: ({
          required snapshot,
          required memoryJson,
          required uiPrefsJson,
        }) async {},
        clearPickerTemp: () async {},
        scheduleRecoveryPack: (_) => packCalls++,
      ),
    );

    expect(result.status, ShelfImportFlowStatus.failed);
    expect(packCalls, 0);
    expect(notifier.persistenceSuspendedForTest, isFalse);
    expect(
      container.read(collectionNotifierProvider).shelfSeries.single.name,
      'Keep',
    );
    final after = await CollectionSnapshotStorage.load();
    expect(after!.shelfSeries.single.name, 'Keep');
  });

  test('stale debounce persist cannot overwrite imported shelf', () async {
    final old = _snap(seriesId: 'old', name: 'Old');
    final neu = _snap(seriesId: 'new', name: 'New');
    await CollectionSnapshotStorage.save(old);
    final backup = await ShelfExportArchive.exportToZip(
      snapshot: neu,
      memoryJson: '{"firstSeriesAddedAtMs":99}',
      uiPrefsJson: '{}',
    );

    CollectionAppBootstrap.prime(old);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(collectionNotifierProvider.notifier);

    // Schedule a debounce persist of "Old" mutations.
    notifier.cycleFigure('old_f1');
    expect(notifier.persistenceSuspendedForTest, isFalse);

    final result = await ShelfImportFlow.run(
      currentSnapshot: container.read(collectionNotifierProvider),
      currentMemoryJson: '{}',
      currentUiPrefsJson: '{}',
      suspendPersistence: notifier.suspendPersistenceForImport,
      replaceNotifierState: notifier.replaceStateFromImport,
      resumePersistence: notifier.resumePersistence,
      reloadUiPrefs: () async {},
      deps: ShelfImportFlowDeps(
        pickZipPath: () async => backup.zipPath,
        confirmReplace: (_) async => true,
        writeSafetyZip: ({
          required snapshot,
          required memoryJson,
          required uiPrefsJson,
        }) async {},
        clearPickerTemp: () async {},
        collectGarbage: (_) async {},
      ),
    );
    expect(result.status, ShelfImportFlowStatus.success);

    // Allow any lingering timers (should be no-ops while/after import).
    await Future<void>.delayed(const Duration(milliseconds: 500));

    final prefs = await CollectionSnapshotStorage.load();
    expect(prefs!.shelfSeries.single.name, 'New');
    expect(
      container.read(collectionNotifierProvider).shelfSeries.single.name,
      'New',
    );
  });

  test('installMedia File.copy preserves original and thumb bytes', () async {
    final png = _pngBytes();
    final thumb = _jpegBytes(r: 55);
    final ref = await ShelfMediaVault.installExportedOriginal(
      id: 'copyme',
      originalBytes: png,
      ext: '.png',
      thumbBytes: thumb,
    );
    // Wipe vault files then reinstall via FromFiles to mimic commitStaging.
    final paths = await ShelfMediaVault.pathsForId('copyme');
    final srcOriginal = File('${tempCache.path}${Platform.pathSeparator}o.png');
    final srcThumb = File('${tempCache.path}${Platform.pathSeparator}t.jpg');
    await srcOriginal.writeAsBytes(png, flush: true);
    await srcThumb.writeAsBytes(thumb, flush: true);
    await File(paths.originalPath!).delete();
    await File(paths.thumbPath!).delete();

    await ShelfMediaVault.installExportedOriginalFromFiles(
      id: 'copyme2',
      originalFile: srcOriginal,
      ext: '.png',
      thumbFile: srcThumb,
    );
    final installed = await ShelfMediaVault.pathsForId('copyme2');
    expect(File(installed.originalPath!).readAsBytesSync(), png);
    expect(File(installed.thumbPath!).readAsBytesSync(), thumb);
    expect(ref, isNotEmpty);
  });

  test('import copy constants are English', () {
    expect(ShelfImportCopy.importTitle, 'Import shelf');
    expect(ShelfImportCopy.confirmTitle, 'Replace your shelf?');
    expect(ShelfImportCopy.confirmReplace, 'Replace shelf');
    expect(ShelfImportCopy.checking, 'Checking backup…');
    expect(ShelfImportCopy.successSnack, 'Shelf imported');
    expect(ShelfImportCopy.failedSnack, contains('Couldn\'t import'));
    expect(ShelfImportCopy.tooLargeSnack, contains('2 GB'));
    expect(ShelfImportCopy.safetyFailedSnack, contains('safety copy'));

    expect(
      ShelfImportCopy.confirmSummary(
        seriesCount: 1,
        figureCount: 1,
        createdDate: 'Jan 1, 2026',
      ),
      'This backup has 1 series and 1 figure, created Jan 1, 2026.',
    );
    expect(
      ShelfImportCopy.confirmSummary(
        seriesCount: 2,
        figureCount: 2,
        createdDate: 'Mar 15, 2026',
      ),
      'This backup has 2 series and 2 figures, created Mar 15, 2026.',
    );
    expect(
      ShelfImportCopy.formatCreatedDate(DateTime.utc(2026, 1, 1)),
      ShelfImportCopy.formatCreatedDate(DateTime.utc(2026, 1, 1).toLocal()),
    );
    // Local MMM d, yyyy shape.
    expect(
      RegExp(r'^[A-Z][a-z]{2} \d{1,2}, \d{4}$')
          .hasMatch(ShelfImportCopy.formatCreatedDate(DateTime.utc(2026, 3, 15))),
      isTrue,
    );

    // No CJK characters in user-facing strings.
    final all = [
      ShelfImportCopy.importTitle,
      ShelfImportCopy.importSubtitle,
      ShelfImportCopy.confirmTitle,
      ShelfImportCopy.confirmBody,
      ShelfImportCopy.confirmSafetyNote,
      ShelfImportCopy.confirmCancel,
      ShelfImportCopy.confirmReplace,
      ShelfImportCopy.checking,
      ShelfImportCopy.importing,
      ShelfImportCopy.successSnack,
      ShelfImportCopy.failedSnack,
      ShelfImportCopy.tooLargeSnack,
      ShelfImportCopy.safetyFailedSnack,
      ShelfImportCopy.confirmSummary(
        seriesCount: 1,
        figureCount: 1,
        createdDate: 'Jan 1, 2026',
      ),
      ShelfImportCopy.confirmSummary(
        seriesCount: 2,
        figureCount: 3,
        createdDate: 'Mar 15, 2026',
      ),
    ].join();
    expect(RegExp(r'[\u4e00-\u9fff]').hasMatch(all), isFalse);
  });
}

class _CancelStaging extends ShelfExportStaging {
  _CancelStaging({
    required this.onDelete,
    required super.snapshot,
    required DateTime createdAt,
  }) : super(
          stagingDir: Directory.systemTemp,
          manifest: ShelfExportManifest(
            kind: ShelfExportArchive.kind,
            schemaVersion: 1,
            createdAt: createdAt,
            appVersion: '1',
            seriesCount: 0,
            figureCount: 0,
            originalCount: 0,
            thumbCount: 0,
            mediaIncomplete: false,
          ),
          memoryJson: '{}',
          uiPrefsJson: '{}',
          originalFiles: const {},
          thumbFiles: const {},
          extractedBytes: 0,
        );

  final void Function() onDelete;

  @override
  Future<void> delete() async => onDelete();
}

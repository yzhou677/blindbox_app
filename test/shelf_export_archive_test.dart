import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:blindbox_app/features/collection/application/collection_shelf_ui_prefs_provider.dart';
import 'package:blindbox_app/features/collection/application/shelf_backup_commit.dart';
import 'package:blindbox_app/features/collection/application/shelf_recovery_import.dart';
import 'package:blindbox_app/features/collection/bootstrap/collection_recovery_gate.dart';
import 'package:blindbox_app/features/collection/data/collection_memory_store.dart';
import 'package:blindbox_app/features/collection/data/shelf_export_archive.dart';
import 'package:blindbox_app/features/collection/data/shelf_media_vault.dart';
import 'package:blindbox_app/features/collection/data/shelf_recovery_pack.dart';
import 'package:blindbox_app/features/collection/data/shelf_vault_refs.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/persistence/collection_snapshot_codec.dart';
import 'package:blindbox_app/features/collection/persistence/collection_snapshot_storage.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';

Uint8List _jpegBytes({int width = 48, int height = 48, int r = 90}) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(r, 40, 160));
  return Uint8List.fromList(img.encodeJpg(image, quality: 85));
}

Uint8List _pngBytes({int width = 64, int height = 64, int g = 180}) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(20, g, 90));
  return Uint8List.fromList(img.encodePng(image));
}

Future<void> _resetAll(Directory support, Directory cache) async {
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

CollectionSnapshot _fullFieldSnapshot({
  required String figureRef,
  required String coverRef,
}) {
  return CollectionSnapshot(
    shelfSeries: [
      ShelfSeries(
        id: 'series-full',
        name: 'Full Series',
        brand: 'BrandX',
        ipName: 'IP Line',
        figures: [
          ShelfFigure(
            id: 'fig-full',
            seriesId: 'series-full',
            name: 'Full Figure',
            imageUrl: 'https://example.test/cache.png',
            localImageUri: figureRef,
            rarity: 'Secret',
            isSecret: true,
            rarityLabel: '1:72',
            imageKey: 'fig_key_1',
            taxonomyBrandId: 'tb1',
            taxonomyIpId: 'ti1',
            catalogFigureTemplateId: 'cft1',
          ),
        ],
        shelfAccent: const Color(0xFFABCDEF),
        notes: 'collector notes',
        catalogTemplateId: 'tmpl-1',
        taxonomyBrandId: 'stb1',
        taxonomyIpId: 'sti1',
        imageKey: 'series_key_1',
        customCoverImageUri: coverRef,
        releaseDate: '2024-05-01',
      ),
    ],
    figureStates: {
      'fig-full': const TrackedFigure(
        figureId: 'fig-full',
        state: FigureCollectionState.owned,
        updatedAtMicros: 123456,
        ownedQuantity: 3,
      ),
    },
    seriesWishlist: const [
      WishlistedCatalogSeries(
        catalogSeriesId: 'wish-1',
        name: 'Wish Series',
        brand: 'WishBrand',
        ipName: 'WishIP',
        imageKey: 'wish_key',
        addedAtMicros: 999,
        taxonomyBrandId: 'wtb',
        taxonomyIpId: 'wti',
      ),
    ],
  );
}

void _expectSeriesEqual(ShelfSeries a, ShelfSeries b) {
  expect(a.id, b.id);
  expect(a.name, b.name);
  expect(a.brand, b.brand);
  expect(a.ipName, b.ipName);
  expect(a.shelfAccent, b.shelfAccent);
  expect(a.notes, b.notes);
  expect(a.catalogTemplateId, b.catalogTemplateId);
  expect(a.taxonomyBrandId, b.taxonomyBrandId);
  expect(a.taxonomyIpId, b.taxonomyIpId);
  expect(a.imageKey, b.imageKey);
  expect(a.customCoverImageUri, b.customCoverImageUri);
  expect(a.releaseDate, b.releaseDate);
  expect(a.figures.length, b.figures.length);
}

void _expectFigureEqual(ShelfFigure a, ShelfFigure b) {
  expect(a.id, b.id);
  expect(a.seriesId, b.seriesId);
  expect(a.name, b.name);
  expect(a.imageUrl, b.imageUrl);
  expect(a.localImageUri, b.localImageUri);
  expect(a.rarity, b.rarity);
  expect(a.isSecret, b.isSecret);
  expect(a.rarityLabel, b.rarityLabel);
  expect(a.imageKey, b.imageKey);
  expect(a.taxonomyBrandId, b.taxonomyBrandId);
  expect(a.taxonomyIpId, b.taxonomyIpId);
  expect(a.catalogFigureTemplateId, b.catalogFigureTemplateId);
}

Future<List<String>> _zipEntryNames(String zipPath) async {
  final bytes = await File(zipPath).readAsBytes();
  final archive = ZipDecoder().decodeBytes(bytes, verify: true);
  return [
    for (final f in archive.files)
      if (f.isFile) f.name.replaceAll('\\', '/'),
  ];
}

Future<void> _writeCraftedZip(
  String path,
  Map<String, List<int>> entries,
) async {
  final archive = Archive();
  for (final e in entries.entries) {
    archive.addFile(ArchiveFile.bytes(e.key, e.value));
  }
  final encoded = ZipEncoder().encode(archive);
  await File(path).writeAsBytes(encoded, flush: true);
}

Future<void> _deleteQuietly(Directory dir) async {
  if (!await dir.exists()) return;
  try {
    await dir.delete(recursive: true);
  } on PathAccessException {
    // Windows may briefly lock zip handles after Isolate / archive decode.
  } on FileSystemException {
    // best-effort temp cleanup
  }
}

void main() {
  late Directory tempSupport;
  late Directory tempCache;

  setUp(() async {
    tempSupport = await Directory.systemTemp.createTemp('shelf_export_sup_');
    tempCache = await Directory.systemTemp.createTemp('shelf_export_cache_');
    await _resetAll(tempSupport, tempCache);
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
    await _deleteQuietly(tempSupport);
    await _deleteQuietly(tempCache);
  });

  test('delete refuses the system temp directory itself', () async {
    final marker = File(
      '${Directory.systemTemp.path}${Platform.pathSeparator}'
      'shelfy_system_temp_guard_${DateTime.now().microsecondsSinceEpoch}',
    );
    await marker.writeAsString('keep', flush: true);
    try {
      final root = _guardStaging(Directory(Directory.systemTemp.absolute.path));
      final trailing = _guardStaging(
        Directory('${Directory.systemTemp.path}${Platform.pathSeparator}'),
      );

      await expectLater(root.delete(), throwsA(_refusesSystemTemp));
      await expectLater(trailing.delete(), throwsA(_refusesSystemTemp));

      expect(marker.existsSync(), isTrue);
      expect(Directory.systemTemp.existsSync(), isTrue);

      final child = Directory.systemTemp.createTempSync('shelfy_staging_');
      final childFile = File('${child.path}${Platform.pathSeparator}keep.txt');
      await childFile.writeAsString('child', flush: true);
      await _guardStaging(child).delete();
      expect(child.existsSync(), isFalse);
    } finally {
      if (marker.existsSync()) {
        marker.deleteSync();
      }
    }
  });

  test('empty shelf exports a valid zip', () async {
    final result = await ShelfExportArchive.exportToZip(
      snapshot: CollectionSnapshot.emptyTest(),
      memoryJson: '{}',
      uiPrefsJson: '{}',
    );
    expect(result.wrote, isTrue);
    expect(result.mediaIncomplete, isFalse);
    expect(result.originalCount, 0);
    expect(result.thumbCount, 0);
    final names = await _zipEntryNames(result.zipPath!);
    expect(names, contains('shelfy_shelf_export/manifest.json'));
    expect(names, contains('shelfy_shelf_export/collection_snapshot_v1.json'));
    final staging = await ShelfExportArchive.unpackToStaging(result.zipPath!);
    expect(staging.snapshot.shelfSeries, isEmpty);
    await staging.delete();
  });

  test('png / jpg / heic originals keep real extensions in zip', () async {
    final png = _pngBytes();
    final jpg = _jpegBytes(r: 10);
    final heic = Uint8List.fromList([0, 0, 0, 0, ...utf8.encode('heic')]);
    final pngRef = await ShelfMediaVault.installExportedOriginal(
      id: 'idpng',
      originalBytes: png,
      ext: '.png',
      thumbBytes: _jpegBytes(r: 1),
    );
    final jpgRef = await ShelfMediaVault.installExportedOriginal(
      id: 'idjpg',
      originalBytes: jpg,
      ext: '.jpg',
      thumbBytes: _jpegBytes(r: 2),
    );
    final heicRef = await ShelfMediaVault.installExportedOriginal(
      id: 'idheic',
      originalBytes: heic,
      ext: '.heic',
      thumbBytes: _jpegBytes(r: 3),
    );

    final snap = CollectionSnapshot(
      shelfSeries: [
        ShelfSeries(
          id: 's1',
          name: 'S',
          brand: 'B',
          ipName: 'I',
          customCoverImageUri: heicRef,
          figures: [
            ShelfFigure(
              id: 'f1',
              seriesId: 's1',
              name: 'Png',
              localImageUri: pngRef,
              rarity: 'Regular',
              isSecret: false,
            ),
            ShelfFigure(
              id: 'f2',
              seriesId: 's1',
              name: 'Jpg',
              localImageUri: jpgRef,
              rarity: 'Regular',
              isSecret: false,
            ),
          ],
          shelfAccent: const Color(0xFFE8F5E9),
        ),
      ],
      figureStates: const {},
    );

    final result = await ShelfExportArchive.exportToZip(
      snapshot: snap,
      memoryJson: '{}',
      uiPrefsJson: '{}',
    );
    expect(result.wrote, isTrue);
    final names = await _zipEntryNames(result.zipPath!);
    expect(names, contains('shelfy_shelf_export/originals/idpng.png'));
    expect(names, contains('shelfy_shelf_export/originals/idjpg.jpg'));
    expect(names, contains('shelfy_shelf_export/originals/idheic.heic'));
    expect(names, contains('shelfy_shelf_export/thumbs/idpng.jpg'));
    expect(names, contains('shelfy_shelf_export/thumbs/idjpg.jpg'));
    expect(names, contains('shelfy_shelf_export/thumbs/idheic.jpg'));
  });

  test('missing original sets mediaIncomplete and still exports', () async {
    final ref = await ShelfMediaVault.installExportedOriginal(
      id: 'gone',
      originalBytes: _jpegBytes(),
      ext: '.jpg',
      thumbBytes: _jpegBytes(r: 5),
    );
    final abs = ShelfMediaVault.resolveToFilePathSync(ref)!;
    await File(abs).delete();

    final snap = CollectionSnapshot(
      shelfSeries: [
        ShelfSeries(
          id: 's1',
          name: 'S',
          brand: 'B',
          ipName: 'I',
          figures: [
            ShelfFigure(
              id: 'f1',
              seriesId: 's1',
              name: 'F',
              localImageUri: ref,
              rarity: 'Regular',
              isSecret: false,
            ),
          ],
          shelfAccent: const Color(0xFFE8F5E9),
        ),
      ],
      figureStates: const {},
    );

    final result = await ShelfExportArchive.exportToZip(
      snapshot: snap,
      memoryJson: '{}',
      uiPrefsJson: '{}',
    );
    expect(result.wrote, isTrue);
    expect(result.mediaIncomplete, isTrue);
    final names = await _zipEntryNames(result.zipPath!);
    expect(names.any((n) => n.contains('/originals/gone')), isFalse);
    expect(names, contains('shelfy_shelf_export/thumbs/gone.jpg'));
  });

  test('round-trip preserves snapshot, memory, prefs, hashes, thumbs', () async {
    final pngBytes = _pngBytes(g: 200);
    final coverBytes = _jpegBytes(r: 200);
    final figureRef = await ShelfMediaVault.installExportedOriginal(
      id: 'figmedia',
      originalBytes: pngBytes,
      ext: '.png',
      thumbBytes: _jpegBytes(r: 11),
    );
    final coverRef = await ShelfMediaVault.installExportedOriginal(
      id: 'covermedia',
      originalBytes: coverBytes,
      ext: '.jpg',
      thumbBytes: _jpegBytes(r: 12),
    );
    final snap = _fullFieldSnapshot(figureRef: figureRef, coverRef: coverRef);
    final memoryJson = jsonEncode({
      'firstSeriesAddedAtMs': 42,
      'ipSeriesDepth': {'ip.a': 2},
      'lastCompletedSeriesId': 'series-full',
    });
    final uiPrefsJson = CollectionShelfUiPrefsCodec.encode(
      const CollectionShelfUiPrefs(
        completedSectionExpanded: true,
        inProgressSectionExpanded: false,
      ),
    );

    final progress = <(int, int)>[];
    final exported = await ShelfExportArchive.exportToZip(
      snapshot: snap,
      memoryJson: memoryJson,
      uiPrefsJson: uiPrefsJson,
      onProgress: (done, total) => progress.add((done, total)),
    );
    expect(exported.wrote, isTrue);
    expect(progress, isNotEmpty);
    expect(progress.last.$1, progress.last.$2);

    // Wipe local shelf state, then import.
    SharedPreferences.setMockInitialValues({});
    CollectionMemoryStore.instance.resetForTest();
    ShelfMediaVault.resetForTest(clearSupportOverride: false);
    ShelfMediaVault.testSupportOverride = tempSupport;
    final vaultRoot = Directory(
      '${tempSupport.path}${Platform.pathSeparator}shelf_media',
    );
    if (await vaultRoot.exists()) {
      await vaultRoot.delete(recursive: true);
    }
    await ShelfMediaVault.ensureReady();

    final staging = await ShelfExportArchive.unpackToStaging(exported.zipPath!);
    final imported = await ShelfExportArchive.commitStaging(staging);

    _expectSeriesEqual(imported.shelfSeries.single, snap.shelfSeries.single);
    _expectFigureEqual(
      imported.shelfSeries.single.figures.single,
      snap.shelfSeries.single.figures.single,
    );
    expect(imported.figureStates['fig-full']?.ownedQuantity, 3);
    expect(imported.figureStates['fig-full']?.updatedAtMicros, 123456);
    expect(imported.seriesWishlist.single.catalogSeriesId, 'wish-1');
    expect(imported.seriesWishlist.single.taxonomyIpId, 'wti');

    await CollectionMemoryStore.instance.ensureLoaded();
    expect(CollectionMemoryStore.instance.cached.firstSeriesAddedAtMs, 42);
    expect(
      CollectionMemoryStore.instance.cached.lastCompletedSeriesId,
      'series-full',
    );
    final prefs = await CollectionShelfUiPrefsStorage.load();
    expect(prefs.completedSectionExpanded, isTrue);
    expect(prefs.inProgressSectionExpanded, isFalse);

    final figAbs = ShelfMediaVault.resolveToFilePathSync(figureRef)!;
    final coverAbs = ShelfMediaVault.resolveToFilePathSync(coverRef)!;
    expect(sha256.convert(await File(figAbs).readAsBytes()), sha256.convert(pngBytes));
    expect(
      sha256.convert(await File(coverAbs).readAsBytes()),
      sha256.convert(coverBytes),
    );
    expect(figureRef.endsWith('.png'), isTrue);
    expect(coverRef.endsWith('.jpg'), isTrue);

    final figThumb = (await ShelfMediaVault.pathsForId('figmedia')).thumbPath;
    expect(figThumb, isNotNull);
    expect(File(figThumb!).existsSync(), isTrue);
  });

  test('rewriteVaultRefsToRecoveredJpg preserves all ShelfSeries/Figure fields',
      () {
    const pngRef = 'shelf_media/originals/abc123.png';
    const coverRef = 'shelf_media/originals/cover99.png';
    final snap = _fullFieldSnapshot(figureRef: pngRef, coverRef: coverRef);
    final rewritten = ShelfRecoveryImport.rewriteVaultRefsToRecoveredJpg(snap);

    final before = snap.shelfSeries.single;
    final after = rewritten.shelfSeries.single;
    expect(after.id, before.id);
    expect(after.name, before.name);
    expect(after.brand, before.brand);
    expect(after.ipName, before.ipName);
    expect(after.shelfAccent, before.shelfAccent);
    expect(after.notes, before.notes);
    expect(after.catalogTemplateId, before.catalogTemplateId);
    expect(after.taxonomyBrandId, before.taxonomyBrandId);
    expect(after.taxonomyIpId, before.taxonomyIpId);
    expect(after.imageKey, before.imageKey);
    expect(after.releaseDate, before.releaseDate);
    expect(after.customCoverImageUri, 'shelf_media/originals/cover99.jpg');

    final bf = before.figures.single;
    final af = after.figures.single;
    expect(af.id, bf.id);
    expect(af.seriesId, bf.seriesId);
    expect(af.name, bf.name);
    expect(af.imageUrl, bf.imageUrl);
    expect(af.rarity, bf.rarity);
    expect(af.isSecret, bf.isSecret);
    expect(af.rarityLabel, bf.rarityLabel);
    expect(af.imageKey, bf.imageKey);
    expect(af.taxonomyBrandId, bf.taxonomyBrandId);
    expect(af.taxonomyIpId, bf.taxonomyIpId);
    expect(af.catalogFigureTemplateId, bf.catalogFigureTemplateId);
    expect(af.localImageUri, 'shelf_media/originals/abc123.jpg');

    expect(rewritten.figureStates, snap.figureStates);
    expect(rewritten.seriesWishlist, snap.seriesWishlist);
  });

  test('corrupt zip / bad kind / schema / traversal / limits reject safely',
      () async {
    await CollectionSnapshotStorage.save(
      CollectionSnapshot(
        shelfSeries: [
          ShelfSeries(
            id: 'keep',
            name: 'Keep Me',
            brand: 'B',
            ipName: 'I',
            figures: const [],
            shelfAccent: const Color(0xFFE8F5E9),
          ),
        ],
        figureStates: const {},
      ),
    );
    await CollectionMemoryStore.instance.replaceFromRecoveryJson(
      '{"firstSeriesAddedAtMs":7}',
    );
    final beforeSnap = await CollectionSnapshotStorage.load();
    expect(beforeSnap!.shelfSeries.single.name, 'Keep Me');

    Future<void> expectReject(String zipPath) async {
      await expectLater(
        ShelfExportArchive.unpackToStaging(zipPath),
        throwsA(isA<ShelfExportException>()),
      );
      final after = await CollectionSnapshotStorage.load();
      expect(after!.shelfSeries.single.name, 'Keep Me');
      await CollectionMemoryStore.instance.ensureLoaded();
      expect(CollectionMemoryStore.instance.cached.firstSeriesAddedAtMs, 7);
    }

    final corrupt = File('${tempCache.path}${Platform.pathSeparator}bad.zip');
    await corrupt.writeAsBytes([1, 2, 3, 4, 5], flush: true);
    await expectReject(corrupt.path);

    final badKind = File('${tempCache.path}${Platform.pathSeparator}kind.zip');
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
    await expectReject(badKind.path);

    final badSchema = File(
      '${tempCache.path}${Platform.pathSeparator}schema.zip',
    );
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
    await expectReject(badSchema.path);

    final traversal = File(
      '${tempCache.path}${Platform.pathSeparator}trav.zip',
    );
    await _writeCraftedZip(traversal.path, {
      'shelfy_shelf_export/../evil.txt': utf8.encode('nope'),
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
    await expectReject(traversal.path);

    final slash = File('${tempCache.path}${Platform.pathSeparator}slash.zip');
    await _writeCraftedZip(slash.path, {
      r'shelfy_shelf_export\manifest.json': utf8.encode('{}'),
    });
    await expectReject(slash.path);

    ShelfExportArchive.testMaxEntriesOverride = 1;
    final tooMany = File(
      '${tempCache.path}${Platform.pathSeparator}many.zip',
    );
    await _writeCraftedZip(tooMany.path, {
      'shelfy_shelf_export/manifest.json': utf8.encode('{}'),
      'shelfy_shelf_export/collection_snapshot_v1.json': utf8.encode('{}'),
    });
    await expectReject(tooMany.path);
    ShelfExportArchive.testMaxEntriesOverride = null;

    ShelfExportArchive.testRejectBytesOverride = 10;
    final bomb = File('${tempCache.path}${Platform.pathSeparator}bomb.zip');
    await _writeCraftedZip(bomb.path, {
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
      'shelfy_shelf_export/originals/big.jpg': List<int>.filled(64, 7),
    });
    await expectReject(bomb.path);
    ShelfExportArchive.testRejectBytesOverride = null;
  });

  test('commit mid-failure leaves old snapshot; gate blocks then clears',
      () async {
    final oldSnap = CollectionSnapshot(
      shelfSeries: [
        ShelfSeries(
          id: 'old',
          name: 'Old Shelf',
          brand: 'B',
          ipName: 'I',
          figures: const [],
          shelfAccent: const Color(0xFFE8F5E9),
        ),
      ],
      figureStates: const {},
    );
    await CollectionSnapshotStorage.save(oldSnap);

    final exported = await ShelfExportArchive.exportToZip(
      snapshot: CollectionSnapshot(
        shelfSeries: [
          ShelfSeries(
            id: 'new',
            name: 'New Shelf',
            brand: 'B',
            ipName: 'I',
            figures: const [],
            shelfAccent: const Color(0xFFE8F5E9),
          ),
        ],
        figureStates: const {},
      ),
      memoryJson: '{}',
      uiPrefsJson: '{}',
    );
    final staging = await ShelfExportArchive.unpackToStaging(exported.zipPath!);

    var sawGate = false;
    ShelfBackupCommit.testBeforeSnapshotSaveHook = () async {
      sawGate = CollectionRecoveryGate.blocksBackgroundWrites;
      throw StateError('boom');
    };

    await expectLater(
      ShelfExportArchive.commitStaging(staging),
      throwsA(isA<StateError>()),
    );
    expect(sawGate, isTrue);
    expect(CollectionRecoveryGate.blocksBackgroundWrites, isFalse);

    final kept = await CollectionSnapshotStorage.load();
    expect(kept!.shelfSeries.single.name, 'Old Shelf');
  });

  test('ShelfVaultRefs collects cover and figure ids', () {
    final snap = CollectionSnapshot(
      shelfSeries: [
        ShelfSeries(
          id: 's1',
          name: 'S',
          brand: 'B',
          ipName: 'I',
          customCoverImageUri: 'shelf_media/originals/cover1.jpg',
          figures: const [
            ShelfFigure(
              id: 'f1',
              seriesId: 's1',
              name: 'A',
              localImageUri: 'shelf_media/originals/fig1.png',
              rarity: 'Regular',
              isSecret: false,
            ),
            ShelfFigure(
              id: 'f2',
              seriesId: 's1',
              name: 'B',
              localImageUri: 'shelf_media/originals/cover1.jpg',
              rarity: 'Regular',
              isSecret: false,
            ),
          ],
          shelfAccent: const Color(0xFFE8F5E9),
        ),
      ],
      figureStates: const {},
    );
    expect(ShelfVaultRefs.referencedIds(snap), ['cover1', 'fig1']);
  });

  test('export_backups prune keeps one and deletes after 7 days', () async {
    final dir = await ShelfExportBackupStore.directory();
    final older = File(
      '${dir.path}${Platform.pathSeparator}pre_import_1.zip',
    );
    final newer = File(
      '${dir.path}${Platform.pathSeparator}pre_import_2.zip',
    );
    await older.writeAsBytes([1], flush: true);
    await newer.writeAsBytes([2], flush: true);
    await older.setLastModified(DateTime.now().toUtc().subtract(const Duration(days: 1)));
    await newer.setLastModified(DateTime.now().toUtc());

    await ShelfExportBackupStore.prune();
    expect(await older.exists(), isFalse);
    expect(await newer.exists(), isTrue);

    await newer.setLastModified(
      DateTime.now().toUtc().subtract(const Duration(days: 8)),
    );
    ShelfExportBackupStore.testNowUtc = DateTime.now().toUtc();
    await ShelfExportBackupStore.prune();
    expect(await newer.exists(), isFalse);
  });

  test('export rejects planned size over hard limit', () async {
    ShelfExportArchive.testRejectBytesOverride = 100;
    final big = List<int>.filled(200, 9);
    await ShelfMediaVault.installExportedOriginal(
      id: 'bigone',
      originalBytes: big,
      ext: '.bin',
      thumbBytes: _jpegBytes(),
    );
    final snap = CollectionSnapshot(
      shelfSeries: [
        ShelfSeries(
          id: 's1',
          name: 'S',
          brand: 'B',
          ipName: 'I',
          figures: const [
            ShelfFigure(
              id: 'f1',
              seriesId: 's1',
              name: 'F',
              localImageUri: 'shelf_media/originals/bigone.bin',
              rarity: 'Regular',
              isSecret: false,
            ),
          ],
          shelfAccent: const Color(0xFFE8F5E9),
        ),
      ],
      figureStates: const {},
    );
    final result = await ShelfExportArchive.exportToZip(
      snapshot: snap,
      memoryJson: '{}',
      uiPrefsJson: '{}',
    );
    expect(result.wrote, isFalse);
    expect(result.rejectReason, ShelfExportRejectReason.tooLarge);
  });

  test('defaultAppVersion matches pubspec.yaml version', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match = RegExp(r'^version:\s*(\S+)\s*$', multiLine: true)
        .firstMatch(pubspec);
    expect(match, isNotNull);
    expect(ShelfExportArchive.defaultAppVersion, match!.group(1));
  });

  test('lied header size still rejects on actual written bytes', () async {
    await CollectionSnapshotStorage.save(
      CollectionSnapshot(
        shelfSeries: [
          ShelfSeries(
            id: 'keep',
            name: 'Keep Me',
            brand: 'B',
            ipName: 'I',
            figures: const [],
            shelfAccent: const Color(0xFFE8F5E9),
          ),
        ],
        figureStates: const {},
      ),
    );
    final keepRef = await ShelfMediaVault.installExportedOriginal(
      id: 'keepmedia',
      originalBytes: _jpegBytes(r: 1),
      ext: '.jpg',
      thumbBytes: _jpegBytes(r: 2),
    );
    final keepAbs = ShelfMediaVault.resolveToFilePathSync(keepRef)!;
    expect(File(keepAbs).existsSync(), isTrue);

    ShelfExportArchive.testMaxSingleFileBytesOverride = 40;
    final payload = List<int>.filled(200, 9);
    final zipPath =
        '${tempCache.path}${Platform.pathSeparator}lied_size.zip';
    await _writeZipWithLiedUncompressedSize(
      zipPath: zipPath,
      entryName: 'shelfy_shelf_export/originals/bomb.jpg',
      payload: payload,
      liedUncompressedSize: 8,
    );

    final cacheRoot = Directory(
      '${tempCache.path}${Platform.pathSeparator}shelf_export',
    );
    final beforeDirs = cacheRoot.existsSync()
        ? cacheRoot
            .listSync()
            .whereType<Directory>()
            .map((d) => d.path)
            .toSet()
        : <String>{};

    await expectLater(
      ShelfExportArchive.unpackToStaging(zipPath),
      throwsA(isA<ShelfExportException>()),
    );

    final after = await CollectionSnapshotStorage.load();
    expect(after!.shelfSeries.single.name, 'Keep Me');
    expect(File(keepAbs).existsSync(), isTrue);

    if (cacheRoot.existsSync()) {
      for (final entity in cacheRoot.listSync()) {
        if (entity is Directory &&
            entity.path.contains('shelf_export_unpack_') &&
            !beforeDirs.contains(entity.path)) {
          fail('staging left behind: ${entity.path}');
        }
      }
    }
    ShelfExportArchive.testMaxSingleFileBytesOverride = null;
  });

  test('export leaves no staging dirs in cache', () async {
    final ref = await ShelfMediaVault.installExportedOriginal(
      id: 'nostage',
      originalBytes: _pngBytes(),
      ext: '.png',
      thumbBytes: _jpegBytes(r: 3),
    );
    final result = await ShelfExportArchive.exportToZip(
      snapshot: CollectionSnapshot(
        shelfSeries: [
          ShelfSeries(
            id: 's1',
            name: 'S',
            brand: 'B',
            ipName: 'I',
            figures: [
              ShelfFigure(
                id: 'f1',
                seriesId: 's1',
                name: 'F',
                localImageUri: ref,
                rarity: 'Regular',
                isSecret: false,
              ),
            ],
            shelfAccent: const Color(0xFFE8F5E9),
          ),
        ],
        figureStates: const {},
      ),
      memoryJson: '{}',
      uiPrefsJson: '{}',
    );
    expect(result.wrote, isTrue);

    final cacheRoot = Directory(
      '${tempCache.path}${Platform.pathSeparator}shelf_export',
    );
    expect(cacheRoot.existsSync(), isTrue);
    for (final entity in cacheRoot.listSync()) {
      if (entity is Directory) {
        fail('unexpected staging dir after export: ${entity.path}');
      }
    }
    expect(File(result.zipPath!).existsSync(), isTrue);
  });

  test('backup zip name uses local date and -2 for same-day collision', () {
    final day = DateTime(2026, 11, 2, 15, 30);
    expect(
      ShelfExportArchive.backupZipStem(day),
      'Shelfy-backup-2026-11-02',
    );
    expect(
      ShelfExportArchive.allocateBackupZipFileName(
        localDate: day,
        exists: (_) => false,
      ),
      'Shelfy-backup-2026-11-02.zip',
    );
    expect(
      ShelfExportArchive.allocateBackupZipFileName(
        localDate: day,
        exists: (name) => name == 'Shelfy-backup-2026-11-02.zip',
      ),
      'Shelfy-backup-2026-11-02-2.zip',
    );
    expect(
      ShelfExportArchive.allocateBackupZipFileName(
        localDate: day,
        exists: (name) =>
            name == 'Shelfy-backup-2026-11-02.zip' ||
            name == 'Shelfy-backup-2026-11-02-2.zip',
      ),
      'Shelfy-backup-2026-11-02-3.zip',
    );
  });

  test('exportToZip writes Shelfy-backup date name and bumps -2', () async {
    ShelfExportArchive.testNowOverride = DateTime(2026, 3, 15, 9, 0);
    final first = await ShelfExportArchive.exportToZip(
      snapshot: CollectionSnapshot.emptyTest(),
      memoryJson: '{}',
      uiPrefsJson: '{}',
    );
    expect(first.wrote, isTrue);
    expect(
      first.zipPath!.replaceAll('\\', '/').split('/').last,
      'Shelfy-backup-2026-03-15.zip',
    );

    final second = await ShelfExportArchive.exportToZip(
      snapshot: CollectionSnapshot.emptyTest(),
      memoryJson: '{}',
      uiPrefsJson: '{}',
    );
    expect(second.wrote, isTrue);
    expect(
      second.zipPath!.replaceAll('\\', '/').split('/').last,
      'Shelfy-backup-2026-03-15-2.zip',
    );
    expect(File(first.zipPath!).existsSync(), isTrue);
    expect(File(second.zipPath!).existsSync(), isTrue);
  });

  test('cleanupStaleExports removes old zip and staging; keeps fresh', () async {
    final cacheRoot = Directory(
      '${tempCache.path}${Platform.pathSeparator}shelf_export',
    );
    await cacheRoot.create(recursive: true);
    final now = DateTime(2026, 11, 3, 12);
    final oldZip = File(
      '${cacheRoot.path}${Platform.pathSeparator}Shelfy-backup-2020-01-01.zip',
    );
    await oldZip.writeAsBytes([1], flush: true);
    await oldZip.setLastModified(now.subtract(const Duration(days: 2)));
    final freshZip = File(
      '${cacheRoot.path}${Platform.pathSeparator}Shelfy-backup-2026-11-02.zip',
    );
    await freshZip.writeAsBytes([2], flush: true);
    await freshZip.setLastModified(now.subtract(const Duration(hours: 2)));

    final oldMs =
        now.subtract(const Duration(days: 2)).toUtc().millisecondsSinceEpoch;
    final freshMs =
        now.subtract(const Duration(hours: 2)).toUtc().millisecondsSinceEpoch;
    final oldStaging = Directory(
      '${cacheRoot.path}${Platform.pathSeparator}'
      '${ShelfExportArchive.unpackStagingPrefix}$oldMs',
    );
    await oldStaging.create(recursive: true);
    final freshStaging = Directory(
      '${cacheRoot.path}${Platform.pathSeparator}'
      '${ShelfExportArchive.unpackStagingPrefix}$freshMs',
    );
    await freshStaging.create(recursive: true);

    ShelfExportArchive.testNowOverride = now;
    await ShelfExportArchive.cleanupStaleExports();

    expect(oldZip.existsSync(), isFalse);
    expect(freshZip.existsSync(), isTrue);
    expect(oldStaging.existsSync(), isFalse);
    expect(freshStaging.existsSync(), isTrue);
  });

  test('cleanupStaleExports keeps entries within one day', () async {
    final cacheRoot = Directory(
      '${tempCache.path}${Platform.pathSeparator}shelf_export',
    );
    await cacheRoot.create(recursive: true);
    final now = DateTime(2026, 11, 3, 12);
    final zip = File(
      '${cacheRoot.path}${Platform.pathSeparator}Shelfy-backup-keep.zip',
    );
    await zip.writeAsBytes([1], flush: true);
    await zip.setLastModified(now.subtract(const Duration(hours: 12)));
    final freshMs =
        now.subtract(const Duration(hours: 12)).toUtc().millisecondsSinceEpoch;
    final staging = Directory(
      '${cacheRoot.path}${Platform.pathSeparator}'
      '${ShelfExportArchive.unpackStagingPrefix}$freshMs',
    );
    await staging.create(recursive: true);
    ShelfExportArchive.testNowOverride = now;
    await ShelfExportArchive.cleanupStaleExports();
    expect(zip.existsSync(), isTrue);
    expect(staging.existsSync(), isTrue);
  });

  test('exportToZip runs stale cleanup before writing', () async {
    final cacheRoot = Directory(
      '${tempCache.path}${Platform.pathSeparator}shelf_export',
    );
    await cacheRoot.create(recursive: true);
    final stale = File(
      '${cacheRoot.path}${Platform.pathSeparator}old_export.zip',
    );
    await stale.writeAsBytes([9], flush: true);
    final now = DateTime(2026, 11, 3);
    await stale.setLastModified(now.subtract(const Duration(days: 3)));
    ShelfExportArchive.testNowOverride = now;

    final result = await ShelfExportArchive.exportToZip(
      snapshot: CollectionSnapshot.emptyTest(),
      memoryJson: '{}',
      uiPrefsJson: '{}',
    );
    expect(result.wrote, isTrue);
    expect(stale.existsSync(), isFalse);
    expect(File(result.zipPath!).existsSync(), isTrue);
  });

  test('manageGate nested over existing pending keeps gate pending', () async {
    CollectionRecoveryGate.enterPending();
    expect(CollectionRecoveryGate.isPending, isTrue);

    final snap = CollectionSnapshot.emptyTest();
    await ShelfBackupCommit.apply(
      snapshot: snap,
      memoryJson: '{}',
      uiPrefsJson: '{}',
      manageGate: true,
      installMedia: () async {},
    );

    expect(CollectionRecoveryGate.isPending, isTrue);
    CollectionRecoveryGate.clearPending();
  });
}

/// Builds a stored zip entry then patches local+central uncompressed size
/// so header claims [liedUncompressedSize] while payload is larger.
Future<void> _writeZipWithLiedUncompressedSize({
  required String zipPath,
  required String entryName,
  required List<int> payload,
  required int liedUncompressedSize,
}) async {
  final archive = Archive();
  final file = ArchiveFile.bytes(entryName, payload);
  file.compression = CompressionType.none;
  archive.addFile(file);
  // Minimal companions so path whitelist still applies to the bomb entry.
  archive.addFile(
    ArchiveFile.string(
      'shelfy_shelf_export/manifest.json',
      jsonEncode({
        'kind': 'shelf_export',
        'schemaVersion': 1,
        'createdAt': '2026-01-01T00:00:00.000Z',
        'appVersion': '1',
      }),
    ),
  );
  archive.addFile(
    ArchiveFile.string(
      'shelfy_shelf_export/collection_snapshot_v1.json',
      CollectionSnapshotCodec.encode(CollectionSnapshot.emptyTest()),
    ),
  );
  final encoded = ZipEncoder().encodeBytes(archive);
  final patched = _patchUncompressedSizeFields(
    Uint8List.fromList(encoded),
    from: payload.length,
    to: liedUncompressedSize,
  );
  await File(zipPath).writeAsBytes(patched, flush: true);
}

Uint8List _patchUncompressedSizeFields(
  Uint8List zip, {
  required int from,
  required int to,
}) {
  final out = Uint8List.fromList(zip);
  var i = 0;
  while (i + 4 <= out.length) {
    final sig = _u32le(out, i);
    if (sig == 0x04034b50) {
      // Local file header: uncompressed size at +22
      if (i + 26 <= out.length && _u32le(out, i + 22) == from) {
        _setU32le(out, i + 22, to);
      }
      final nameLen = _u16le(out, i + 26);
      final extraLen = _u16le(out, i + 28);
      final compSize = _u32le(out, i + 18);
      i += 30 + nameLen + extraLen + compSize;
      continue;
    }
    if (sig == 0x02014b50) {
      // Central directory: uncompressed size at +24
      if (i + 28 <= out.length && _u32le(out, i + 24) == from) {
        _setU32le(out, i + 24, to);
      }
      final nameLen = _u16le(out, i + 28);
      final extraLen = _u16le(out, i + 30);
      final commentLen = _u16le(out, i + 32);
      i += 46 + nameLen + extraLen + commentLen;
      continue;
    }
    if (sig == 0x06054b50) break;
    i += 1;
  }
  return out;
}

int _u16le(Uint8List b, int i) => b[i] | (b[i + 1] << 8);

int _u32le(Uint8List b, int i) =>
    b[i] | (b[i + 1] << 8) | (b[i + 2] << 16) | (b[i + 3] << 24);

final _refusesSystemTemp = isA<StateError>().having(
  (StateError e) => e.message,
  'message',
  'Refusing to delete the system temporary directory.',
);

ShelfExportStaging _guardStaging(Directory dir) {
  return ShelfExportStaging(
    stagingDir: dir,
    manifest: ShelfExportManifest(
      kind: ShelfExportArchive.kind,
      schemaVersion: 1,
      createdAt: DateTime.utc(2026, 1, 1),
      appVersion: '1',
      seriesCount: 0,
      figureCount: 0,
      originalCount: 0,
      thumbCount: 0,
      mediaIncomplete: false,
    ),
    snapshot: CollectionSnapshot.emptyTest(),
    memoryJson: '{}',
    uiPrefsJson: '{}',
    originalFiles: const {},
    thumbFiles: const {},
    extractedBytes: 0,
  );
}

void _setU32le(Uint8List b, int i, int v) {
  b[i] = v & 0xff;
  b[i + 1] = (v >> 8) & 0xff;
  b[i + 2] = (v >> 16) & 0xff;
  b[i + 3] = (v >> 24) & 0xff;
}

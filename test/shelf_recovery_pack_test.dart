import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:blindbox_app/features/collection/application/collection_shelf_ui_prefs_provider.dart';
import 'package:blindbox_app/features/collection/data/shelf_media_vault.dart';
import 'package:blindbox_app/features/collection/data/shelf_recovery_pack.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/persistence/collection_snapshot_codec.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';

Uint8List _jpegBytes({int width = 200, int height = 200}) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(20, 140, 90));
  return Uint8List.fromList(img.encodeJpg(image, quality: 90));
}

CollectionSnapshot _snapshotWithLocal(String? localRef) {
  return CollectionSnapshot(
    shelfSeries: [
      ShelfSeries(
        id: 's1',
        name: 'Series',
        brand: 'Brand',
        ipName: 'IP',
        figures: [
          ShelfFigure(
            id: 'f1',
            seriesId: 's1',
            name: 'Figure',
            localImageUri: localRef,
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

Future<String> _importJpeg(Directory support, String name) async {
  final source = File('${support.path}${Platform.pathSeparator}$name');
  await source.writeAsBytes(_jpegBytes());
  final ref = await ShelfMediaVault.importFromPath(source.path);
  expect(ref, isNotNull);
  return ref!;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempSupport;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempSupport = await Directory.systemTemp.createTemp('shelf_recovery_');
    ShelfMediaVault.resetForTest();
    ShelfRecoveryPack.resetForTest();
    ShelfMediaVault.testSupportOverride = tempSupport;
    ShelfRecoveryPack.testSupportOverride = tempSupport;
    await ShelfMediaVault.ensureReady();
  });

  tearDown(() async {
    ShelfMediaVault.resetForTest();
    ShelfRecoveryPack.resetForTest();
    if (await tempSupport.exists()) {
      await tempSupport.delete(recursive: true);
    }
  });

  test('write/read round-trip keeps snapshot, memory, prefs, relative refs', () async {
    final ref = await _importJpeg(tempSupport, 'a.jpg');
    final snapshot = _snapshotWithLocal(ref);
    final memoryJson = jsonEncode({
      'firstSeriesAddedAtMs': 1000,
      'ipSeriesDepth': {'ip.x': 1},
    });
    final uiPrefs = const CollectionShelfUiPrefs(
      inProgressSectionExpanded: false,
      completedSectionExpanded: true,
    );
    final uiPrefsJson = CollectionShelfUiPrefsCodec.encode(uiPrefs);

    final write = await ShelfRecoveryPack.write(
      snapshot: snapshot,
      memoryJson: memoryJson,
      uiPrefsJson: uiPrefsJson,
      appVersion: 'test-1',
    );
    expect(write.wrote, isTrue);
    expect(write.mediaTruncated, isFalse);

    final loaded = await ShelfRecoveryPack.tryLoad();
    expect(loaded, isNotNull);
    expect(loaded!.manifest.appVersion, 'test-1');
    expect(loaded.manifest.seriesCount, 1);
    expect(loaded.manifest.figureCount, 1);
    expect(loaded.manifest.mediaCount, 1);
    expect(loaded.manifest.mediaTruncated, isFalse);
    expect(loaded.snapshot.shelfSeries.single.figures.single.localImageUri, ref);
    expect(ShelfMediaVault.isVaultRef(ref), isTrue);
    expect(loaded.memoryJson, memoryJson);
    expect(loaded.uiPrefsJson, uiPrefsJson);
    expect(loaded.mediaIds, [ShelfMediaVault.idFromRef(ref)]);

    final roundTrip = CollectionSnapshotCodec.tryDecode(loaded.snapshotJson);
    expect(roundTrip, isNotNull);
    expect(
      roundTrip!.shelfSeries.single.figures.single.localImageUri,
      ref,
    );
  });

  test('media truncation keeps newest lastAccessedAt first and sets flag', () async {
    final older = await _importJpeg(tempSupport, 'old.jpg');
    final newer = await _importJpeg(tempSupport, 'new.jpg');
    final olderId = ShelfMediaVault.idFromRef(older)!;
    final newerId = ShelfMediaVault.idFromRef(newer)!;

    await ShelfMediaVault.setLastAccessedAtForTest(
      older,
      DateTime.utc(2020, 1, 1),
    );
    await ShelfMediaVault.setLastAccessedAtForTest(
      newer,
      DateTime.utc(2024, 6, 1),
    );

    // Oversized thumbs so only one fits after JSON budget.
    final entries = await ShelfMediaVault.entriesByRecentAccess();
    for (final e in entries) {
      final thumb = File(e.thumbPath!);
      await thumb.writeAsBytes(List<int>.filled(8 * 1024, 7));
    }

    ShelfRecoveryPack.testMaxBytesOverride = 12 * 1024;
    final write = await ShelfRecoveryPack.write(
      snapshot: _snapshotWithLocal(newer),
      memoryJson: '{}',
      uiPrefsJson: '{}',
    );
    expect(write.wrote, isTrue);
    expect(write.mediaTruncated, isTrue);
    expect(write.mediaCount, 1);

    final loaded = await ShelfRecoveryPack.tryLoad();
    expect(loaded, isNotNull);
    expect(loaded!.manifest.mediaTruncated, isTrue);
    expect(loaded.mediaIds, [newerId]);
    expect(loaded.mediaIds, isNot(contains(olderId)));
  });

  test('expired pack is deleted and tryLoad returns null', () async {
    ShelfRecoveryPack.testNowUtc = DateTime.utc(2026, 1, 1);
    await ShelfRecoveryPack.write(
      snapshot: _snapshotWithLocal(null),
      memoryJson: '{}',
      uiPrefsJson: '{}',
    );
    expect(await ShelfRecoveryPack.tryLoad(), isNotNull);

    ShelfRecoveryPack.testNowUtc = DateTime.utc(2026, 2, 5);
    expect(await ShelfRecoveryPack.tryLoad(), isNull);

    final pack = Directory(
      '${tempSupport.path}${Platform.pathSeparator}'
      '${ShelfRecoveryPack.folderName}${Platform.pathSeparator}'
      '${ShelfRecoveryPack.packDirName}',
    );
    expect(await pack.exists(), isFalse);
  });

  test('corrupt pack and unknown schemaVersion return null safely', () async {
    await ShelfRecoveryPack.write(
      snapshot: _snapshotWithLocal(null),
      memoryJson: '{}',
      uiPrefsJson: '{}',
    );
    final pack = Directory(
      '${tempSupport.path}${Platform.pathSeparator}'
      '${ShelfRecoveryPack.folderName}${Platform.pathSeparator}'
      '${ShelfRecoveryPack.packDirName}',
    );
    final manifest = File(
      '${pack.path}${Platform.pathSeparator}${ShelfRecoveryPack.manifestFileName}',
    );

    await manifest.writeAsString('{not-json', flush: true);
    expect(await ShelfRecoveryPack.tryLoad(), isNull);

    await ShelfRecoveryPack.write(
      snapshot: _snapshotWithLocal(null),
      memoryJson: '{}',
      uiPrefsJson: '{}',
    );
    final map = jsonDecode(await manifest.readAsString()) as Map<String, dynamic>;
    map['schemaVersion'] = 99;
    await manifest.writeAsString(jsonEncode(map), flush: true);
    expect(await ShelfRecoveryPack.tryLoad(), isNull);
  });

  test('empty shelf and missing thumbs still write a valid pack', () async {
    final ref = await _importJpeg(tempSupport, 'ghost.jpg');
    final entries = await ShelfMediaVault.entriesByRecentAccess();
    final thumb = File(entries.single.thumbPath!);
    await thumb.delete();

    final empty = CollectionSnapshot(
      shelfSeries: const [],
      figureStates: const {},
    );
    final write = await ShelfRecoveryPack.write(
      snapshot: empty,
      memoryJson: '{}',
      uiPrefsJson: '{}',
    );
    expect(write.wrote, isTrue);

    final loaded = await ShelfRecoveryPack.tryLoad();
    expect(loaded, isNotNull);
    expect(loaded!.snapshot.shelfSeries, isEmpty);
    expect(loaded.manifest.mediaCount, 0);
    // Missing thumb is skipped; not a size truncation.
    expect(loaded.manifest.mediaTruncated, isFalse);
    expect(loaded.mediaIds, isEmpty);

    // Snapshot without custom photos also fine.
    final noPhoto = await ShelfRecoveryPack.write(
      snapshot: _snapshotWithLocal(null),
      memoryJson: '{}',
      uiPrefsJson: '{}',
    );
    expect(noPhoto.wrote, isTrue);
    final again = await ShelfRecoveryPack.tryLoad();
    expect(again!.snapshot.shelfSeries.single.figures.single.localImageUri, isNull);
    expect(ref, isNotEmpty);
  });

  test('failed commit leaves previous pack intact', () async {
    await ShelfRecoveryPack.write(
      snapshot: _snapshotWithLocal(null),
      memoryJson: '{"marker":"v1"}',
      uiPrefsJson: '{}',
      appVersion: 'v1',
    );
    final first = await ShelfRecoveryPack.tryLoad();
    expect(first!.memoryJson, contains('"marker":"v1"'));

    ShelfRecoveryPack.testBeforeCommitHook = () async {
      throw StateError('simulated crash before commit');
    };
    await expectLater(
      () => ShelfRecoveryPack.write(
        snapshot: _snapshotWithLocal(null),
        memoryJson: '{"marker":"v2"}',
        uiPrefsJson: '{}',
        appVersion: 'v2',
      ),
      throwsA(isA<StateError>()),
    );

    final still = await ShelfRecoveryPack.tryLoad();
    expect(still, isNotNull);
    expect(still!.manifest.appVersion, 'v1');
    expect(still.memoryJson, contains('"marker":"v1"'));
  });

  test('Android backup XML includes recovery and excludes shared_prefs', () async {
    final backupRules = File('android/app/src/main/res/xml/backup_rules.xml');
    final extraction = File(
      'android/app/src/main/res/xml/data_extraction_rules.xml',
    );
    final manifest = File('android/app/src/main/AndroidManifest.xml');

    expect(await backupRules.exists(), isTrue);
    expect(await extraction.exists(), isTrue);

    final backupText = await backupRules.readAsString();
    expect(backupText, contains('path="recovery/"'));
    expect(backupText, contains('domain="sharedpref"'));
    expect(backupText, contains('path="."'));

    final extractionText = await extraction.readAsString();
    expect(extractionText, contains('<cloud-backup>'));
    expect(extractionText, contains('<device-transfer>'));
    expect(extractionText, contains('path="recovery/"'));
    expect(extractionText, contains('domain="sharedpref"'));

    final manifestText = await manifest.readAsString();
    expect(manifestText, contains('android:allowBackup="true"'));
    expect(manifestText, contains('@xml/backup_rules'));
    expect(manifestText, contains('@xml/data_extraction_rules'));
  });
}

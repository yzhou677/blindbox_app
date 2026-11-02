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

CollectionSnapshot _snapshotWithLocal(String? localRef, {String name = 'Figure'}) {
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
            name: name,
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

class _BackupRule {
  const _BackupRule({
    required this.kind,
    required this.domain,
    required this.path,
  });

  final String kind;
  final String domain;
  final String path;
}

List<_BackupRule> _parseBackupRules(String xml) {
  final re = RegExp(
    r'<(include|exclude)\s+domain="([^"]+)"\s+path="([^"]+)"\s*/>',
  );
  return [
    for (final m in re.allMatches(xml))
      _BackupRule(kind: m.group(1)!, domain: m.group(2)!, path: m.group(3)!),
  ];
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
    expect(loaded.manifest.mediaTruncated, isFalse);
    expect(loaded.mediaIds, isEmpty);

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

  test('concurrent write coalesces to latest snapshot', () async {
    ShelfRecoveryPack.testBeforeCommitHook = () async {
      await Future<void>.delayed(const Duration(milliseconds: 40));
    };

    final first = ShelfRecoveryPack.write(
      snapshot: _snapshotWithLocal(null, name: 'first'),
      memoryJson: '{"n":1}',
      uiPrefsJson: '{}',
      appVersion: 'first',
    );
    await Future<void>.delayed(const Duration(milliseconds: 5));
    final second = ShelfRecoveryPack.write(
      snapshot: _snapshotWithLocal(null, name: 'second'),
      memoryJson: '{"n":2}',
      uiPrefsJson: '{}',
      appVersion: 'second',
    );
    await Future<void>.delayed(const Duration(milliseconds: 5));
    final third = ShelfRecoveryPack.write(
      snapshot: _snapshotWithLocal(null, name: 'third'),
      memoryJson: '{"n":3}',
      uiPrefsJson: '{}',
      appVersion: 'third',
    );

    await Future.wait([first, second, third]);
    final loaded = await ShelfRecoveryPack.tryLoad();
    expect(loaded, isNotNull);
    expect(loaded!.manifest.appVersion, 'third');
    expect(loaded.snapshot.shelfSeries.single.figures.single.name, 'third');
    expect(loaded.memoryJson, contains('"n":3'));
  });

  test('tryLoad recovers pack.old when pack is missing', () async {
    await ShelfRecoveryPack.write(
      snapshot: _snapshotWithLocal(null, name: 'from-old'),
      memoryJson: '{"from":"old"}',
      uiPrefsJson: '{}',
      appVersion: 'old-pack',
    );
    final root = Directory(
      '${tempSupport.path}${Platform.pathSeparator}${ShelfRecoveryPack.folderName}',
    );
    final pack = Directory(
      '${root.path}${Platform.pathSeparator}${ShelfRecoveryPack.packDirName}',
    );
    final old = Directory(
      '${root.path}${Platform.pathSeparator}${ShelfRecoveryPack.oldDirName}',
    );
    expect(await pack.exists(), isTrue);
    await pack.rename(old.path);
    expect(await pack.exists(), isFalse);
    expect(await old.exists(), isTrue);

    final loaded = await ShelfRecoveryPack.tryLoad();
    expect(loaded, isNotNull);
    expect(loaded!.manifest.appVersion, 'old-pack');
    expect(loaded.snapshot.shelfSeries.single.figures.single.name, 'from-old');
    expect(await pack.exists(), isTrue);
    expect(await old.exists(), isFalse);
  });

  test('incremental thumb reuse matches full copy content', () async {
    final ref = await _importJpeg(tempSupport, 'reuse.jpg');
    await ShelfRecoveryPack.write(
      snapshot: _snapshotWithLocal(ref),
      memoryJson: '{}',
      uiPrefsJson: '{}',
    );
    final first = await ShelfRecoveryPack.tryLoad();
    expect(first, isNotNull);
    final firstMedia = File(
      '${first!.packPath}${Platform.pathSeparator}'
      '${ShelfRecoveryPack.mediaDirName}${Platform.pathSeparator}'
      '${ShelfMediaVault.idFromRef(ref)}.jpg',
    );
    final firstBytes = await firstMedia.readAsBytes();

    ShelfRecoveryPack.testThumbCopiedFromVault = 0;
    ShelfRecoveryPack.testThumbReusedFromPack = 0;
    await ShelfRecoveryPack.write(
      snapshot: _snapshotWithLocal(ref),
      memoryJson: '{}',
      uiPrefsJson: '{}',
    );
    expect(ShelfRecoveryPack.testThumbReusedFromPack, greaterThan(0));
    expect(ShelfRecoveryPack.testThumbCopiedFromVault, 0);

    final second = await ShelfRecoveryPack.tryLoad();
    expect(second, isNotNull);
    final secondMedia = File(
      '${second!.packPath}${Platform.pathSeparator}'
      '${ShelfRecoveryPack.mediaDirName}${Platform.pathSeparator}'
      '${ShelfMediaVault.idFromRef(ref)}.jpg',
    );
    expect(await secondMedia.readAsBytes(), firstBytes);
    expect(second.mediaIds, first.mediaIds);
  });

  test('Android backup XML only includes recovery and excludes sharedpref', () async {
    final backupRules = File('android/app/src/main/res/xml/backup_rules.xml');
    final extraction = File(
      'android/app/src/main/res/xml/data_extraction_rules.xml',
    );
    final manifest = File('android/app/src/main/AndroidManifest.xml');

    final backupParsed = _parseBackupRules(await backupRules.readAsString());
    expect(
      backupParsed.where((r) => r.kind == 'include').toList(),
      [
        isA<_BackupRule>()
            .having((r) => r.domain, 'domain', 'file')
            .having((r) => r.path, 'path', 'recovery/'),
      ],
    );
    expect(
      backupParsed.where((r) => r.kind == 'exclude').toList(),
      [
        isA<_BackupRule>()
            .having((r) => r.domain, 'domain', 'sharedpref')
            .having((r) => r.path, 'path', '.'),
      ],
    );
    expect(backupParsed.any((r) => r.domain == 'root'), isFalse);

    final extractionText = await extraction.readAsString();
    expect(extractionText, contains('<cloud-backup>'));
    expect(extractionText, contains('<device-transfer>'));

    for (final section in ['cloud-backup', 'device-transfer']) {
      final sectionMatch = RegExp(
        '<$section>([\\s\\S]*?)</$section>',
      ).firstMatch(extractionText);
      expect(sectionMatch, isNotNull, reason: section);
      final rules = _parseBackupRules(sectionMatch!.group(1)!);
      expect(
        rules.where((r) => r.kind == 'include').toList(),
        [
          isA<_BackupRule>()
              .having((r) => r.domain, 'domain', 'file')
              .having((r) => r.path, 'path', 'recovery/'),
        ],
      );
      expect(
        rules.where((r) => r.kind == 'exclude').toList(),
        [
          isA<_BackupRule>()
              .having((r) => r.domain, 'domain', 'sharedpref')
              .having((r) => r.path, 'path', '.'),
        ],
      );
      expect(rules.any((r) => r.domain == 'root'), isFalse);
    }

    final manifestText = await manifest.readAsString();
    expect(manifestText, contains('android:allowBackup="true"'));
    expect(manifestText, contains('@xml/backup_rules'));
    expect(manifestText, contains('@xml/data_extraction_rules'));
  });
}

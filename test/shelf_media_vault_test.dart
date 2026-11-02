import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:blindbox_app/features/collection/bootstrap/collection_recovery_gate.dart';
import 'package:blindbox_app/features/collection/data/shelf_media_vault.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

Uint8List _jpegBytes({int width = 800, int height = 600}) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(40, 120, 200));
  return Uint8List.fromList(img.encodeJpg(image, quality: 90));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempSupport;

  setUp(() async {
    tempSupport = await Directory.systemTemp.createTemp('shelf_media_support_');
    CollectionRecoveryGate.resetForTest();
    ShelfMediaVault.resetForTest();
    ShelfMediaVault.testSupportOverride = tempSupport;
    await ShelfMediaVault.ensureReady();
  });

  tearDown(() async {
    CollectionRecoveryGate.resetForTest();
    ShelfMediaVault.resetForTest();
    if (await tempSupport.exists()) {
      await tempSupport.delete(recursive: true);
    }
  });

  test('importFromPath returns relative vault ref and writes thumb', () async {
    final source = File('${tempSupport.path}${Platform.pathSeparator}picker.jpg');
    await source.writeAsBytes(_jpegBytes());

    final ref = await ShelfMediaVault.importFromPath(source.path);
    expect(ref, isNotNull);
    expect(ShelfMediaVault.isVaultRef(ref), isTrue);
    expect(ref, startsWith('shelf_media/originals/'));

    final abs = ShelfMediaVault.resolveToFilePathSync(ref);
    expect(abs, isNotNull);
    expect(File(abs!).existsSync(), isTrue);

    final entries = await ShelfMediaVault.entriesByRecentAccess();
    expect(entries, hasLength(1));
    expect(entries.single.vaultRef, ref);
    expect(File(entries.single.thumbPath!).existsSync(), isTrue);

    final decoded = img.decodeImage(
      await File(entries.single.thumbPath!).readAsBytes(),
    );
    expect(decoded, isNotNull);
    final longest = decoded!.width > decoded.height
        ? decoded.width
        : decoded.height;
    expect(longest, lessThanOrEqualTo(ShelfMediaVault.thumbLongestEdge));
  });

  test('resolveToFilePathSync reads relative vault refs', () async {
    final source = File('${tempSupport.path}${Platform.pathSeparator}a.jpg');
    await source.writeAsBytes(_jpegBytes(width: 200, height: 200));
    final ref = await ShelfMediaVault.importFromPath(source.path);
    final path = ShelfMediaVault.resolveToFilePathSync(ref);
    expect(path, isNotNull);
    expect(await File(path!).exists(), isTrue);
  });

  test('second migrate does not change lastAccessedAt', () async {
    final source = File('${tempSupport.path}${Platform.pathSeparator}m.jpg');
    await source.writeAsBytes(_jpegBytes(width: 120, height: 120));
    final ref = await ShelfMediaVault.importFromPath(source.path);
    final firstAccess = await ShelfMediaVault.lastAccessedAtForTest(ref!);
    expect(firstAccess, isNotNull);

    await Future<void>.delayed(const Duration(milliseconds: 20));

    final snapshot = CollectionSnapshot(
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

    final migrated = await ShelfMediaVault.migrateSnapshot(snapshot);
    expect(migrated.changed, isFalse);
    final secondAccess = await ShelfMediaVault.lastAccessedAtForTest(ref);
    expect(secondAccess, firstAccess);
  });

  test('migrate rewrites absolute vault paths to relative refs', () async {
    final source = File('${tempSupport.path}${Platform.pathSeparator}abs.jpg');
    await source.writeAsBytes(_jpegBytes(width: 160, height: 160));
    final relative = await ShelfMediaVault.importFromPath(source.path);
    final absolute = ShelfMediaVault.resolveToFilePathSync(relative)!;

    final snapshot = CollectionSnapshot(
      shelfSeries: [
        ShelfSeries(
          id: 's1',
          name: 'S',
          brand: 'B',
          ipName: 'I',
          figures: const [],
          shelfAccent: const Color(0xFFE8F5E9),
          customCoverImageUri: absolute,
        ),
      ],
      figureStates: const {},
    );

    final beforeAccess = await ShelfMediaVault.lastAccessedAtForTest(relative!);
    final migrated = await ShelfMediaVault.migrateSnapshot(snapshot);
    expect(migrated.changed, isTrue);
    expect(
      migrated.snapshot.shelfSeries.single.customCoverImageUri,
      relative,
    );
    expect(
      await ShelfMediaVault.lastAccessedAtForTest(relative),
      beforeAccess,
    );
  });

  test('GC deletes replaced photo and keeps referenced one', () async {
    final a = File('${tempSupport.path}${Platform.pathSeparator}old.jpg');
    final b = File('${tempSupport.path}${Platform.pathSeparator}new.jpg');
    await a.writeAsBytes(_jpegBytes(width: 100, height: 100));
    await b.writeAsBytes(_jpegBytes(width: 110, height: 110));

    final oldRef = await ShelfMediaVault.importFromPath(a.path);
    final newRef = await ShelfMediaVault.importFromPath(b.path);
    final oldAbs = ShelfMediaVault.resolveToFilePathSync(oldRef)!;
    final newAbs = ShelfMediaVault.resolveToFilePathSync(newRef)!;
    expect(File(oldAbs).existsSync(), isTrue);
    expect(File(newAbs).existsSync(), isTrue);

    await ShelfMediaVault.backdateCreatedAtForTest(
      oldRef!,
      DateTime.now().toUtc().subtract(ShelfMediaVault.gcGracePeriod),
    );

    final snapshot = CollectionSnapshot(
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
              localImageUri: newRef,
              rarity: 'Regular',
              isSecret: false,
            ),
          ],
          shelfAccent: const Color(0xFFE8F5E9),
        ),
      ],
      figureStates: const {},
    );

    final gc = await ShelfMediaVault.collectGarbage(snapshot);
    expect(gc.removedIds, contains(ShelfMediaVault.idFromRef(oldRef)));
    expect(File(oldAbs).existsSync(), isFalse);
    expect(File(newAbs).existsSync(), isTrue);
    expect(await ShelfMediaVault.entriesByRecentAccess(), hasLength(1));
  });

  test('GC keeps fresh import not yet in snapshot', () async {
    final source = File('${tempSupport.path}${Platform.pathSeparator}pending.jpg');
    await source.writeAsBytes(_jpegBytes(width: 130, height: 130));
    final pendingRef = await ShelfMediaVault.importFromPath(source.path);
    final abs = ShelfMediaVault.resolveToFilePathSync(pendingRef)!;

    final emptySnapshot = CollectionSnapshot(
      shelfSeries: const [],
      figureStates: const {},
    );
    final gc = await ShelfMediaVault.collectGarbage(emptySnapshot);

    expect(gc.removedIds, isEmpty);
    expect(File(abs).existsSync(), isTrue);
    expect(await ShelfMediaVault.entriesByRecentAccess(), hasLength(1));
  });

  test('GC deletes unreferenced entry older than grace', () async {
    final source = File('${tempSupport.path}${Platform.pathSeparator}stale.jpg');
    await source.writeAsBytes(_jpegBytes(width: 140, height: 140));
    final staleRef = await ShelfMediaVault.importFromPath(source.path);
    final abs = ShelfMediaVault.resolveToFilePathSync(staleRef)!;

    await ShelfMediaVault.backdateCreatedAtForTest(
      staleRef!,
      DateTime.now().toUtc().subtract(
        ShelfMediaVault.gcGracePeriod + const Duration(minutes: 1),
      ),
    );

    final emptySnapshot = CollectionSnapshot(
      shelfSeries: const [],
      figureStates: const {},
    );
    final gc = await ShelfMediaVault.collectGarbage(emptySnapshot);

    expect(gc.removedIds, contains(ShelfMediaVault.idFromRef(staleRef)));
    expect(File(abs).existsSync(), isFalse);
    expect(await ShelfMediaVault.entriesByRecentAccess(), isEmpty);
  });

  test('constants match recovery budget contract', () {
    expect(ShelfMediaVault.thumbLongestEdge, 512);
    expect(ShelfMediaVault.thumbJpegQuality, 75);
    expect(ShelfMediaVault.autoBackupMaxBytes, 20 * 1024 * 1024);
    expect(ShelfMediaVault.gcGracePeriod, const Duration(hours: 24));
  });
}

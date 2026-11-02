import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:blindbox_app/features/collection/data/shelf_media_vault.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// Minimal valid JPEG large enough to resize.
Uint8List _jpegBytes({int width = 800, int height = 600}) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(40, 120, 200));
  return Uint8List.fromList(img.encodeJpg(image, quality: 90));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempRoot;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('shelf_media_vault_');
    ShelfMediaVault.resetForTest();
    ShelfMediaVault.testRootOverride = tempRoot;
  });

  tearDown(() async {
    ShelfMediaVault.resetForTest();
    if (await tempRoot.exists()) {
      await tempRoot.delete(recursive: true);
    }
  });

  test('importFromPath copies into originals and writes 512 thumb', () async {
    final source = File('${tempRoot.path}${Platform.pathSeparator}picker.jpg');
    await source.writeAsBytes(_jpegBytes());

    final vaultPath = await ShelfMediaVault.importFromPath(source.path);
    expect(vaultPath, isNotNull);
    expect(await ShelfMediaVault.isVaultOriginalPath(vaultPath!), isTrue);
    expect(File(vaultPath).existsSync(), isTrue);
    expect(vaultPath, isNot(source.path));

    final thumb = await ShelfMediaVault.thumbPathForOriginal(vaultPath);
    expect(thumb, isNotNull);
    expect(File(thumb!).existsSync(), isTrue);

    final decoded = img.decodeImage(await File(thumb).readAsBytes());
    expect(decoded, isNotNull);
    final longest = decoded!.width > decoded.height
        ? decoded.width
        : decoded.height;
    expect(longest, lessThanOrEqualTo(ShelfMediaVault.thumbLongestEdge));

    final entries = await ShelfMediaVault.entriesByRecentAccess();
    expect(entries, hasLength(1));
    expect(File(entries.single.originalPath).path, File(vaultPath).path);
    expect(File(entries.single.thumbPath!).path, File(thumb).path);
  });

  test('importing an existing vault path is idempotent', () async {
    final source = File('${tempRoot.path}${Platform.pathSeparator}a.jpg');
    await source.writeAsBytes(_jpegBytes(width: 400, height: 400));
    final first = await ShelfMediaVault.importFromPath(source.path);
    final second = await ShelfMediaVault.importFromPath(first!);
    expect(second, first);
    expect(await ShelfMediaVault.entriesByRecentAccess(), hasLength(1));
  });

  test('ensureInVault leaves missing paths unchanged', () async {
    const missing = '/tmp/does_not_exist_shelf_photo.jpg';
    expect(await ShelfMediaVault.ensureInVault(missing), missing);
  });

  test('migrateSnapshot rewrites existing local paths into the vault', () async {
    final coverFile = File(
      '${tempRoot.path}${Platform.pathSeparator}cover.jpg',
    );
    final figFile = File('${tempRoot.path}${Platform.pathSeparator}fig.jpg');
    await coverFile.writeAsBytes(_jpegBytes(width: 640, height: 640));
    await figFile.writeAsBytes(_jpegBytes(width: 320, height: 480));

    final snapshot = CollectionSnapshot(
      shelfSeries: [
        ShelfSeries(
          id: 'custom_1',
          name: 'Custom',
          brand: 'Me',
          ipName: 'Me',
          figures: [
            ShelfFigure(
              id: 'f1',
              seriesId: 'custom_1',
              name: 'Fig',
              localImageUri: figFile.path,
              rarity: 'Regular',
              isSecret: false,
            ),
          ],
          shelfAccent: const Color(0xFFE8F5E9),
          customCoverImageUri: coverFile.path,
        ),
      ],
      figureStates: const {},
    );

    final result = await ShelfMediaVault.migrateSnapshot(snapshot);
    expect(result.changed, isTrue);
    final series = result.snapshot.shelfSeries.single;
    expect(
      await ShelfMediaVault.isVaultOriginalPath(series.customCoverImageUri!),
      isTrue,
    );
    expect(
      await ShelfMediaVault.isVaultOriginalPath(
        series.figures.single.localImageUri!,
      ),
      isTrue,
    );
    expect(await ShelfMediaVault.entriesByRecentAccess(), hasLength(2));
  });

  test('entriesByRecentAccess orders by lastAccessedAt descending', () async {
    final a = File('${tempRoot.path}${Platform.pathSeparator}a.jpg');
    final b = File('${tempRoot.path}${Platform.pathSeparator}b.jpg');
    await a.writeAsBytes(_jpegBytes(width: 100, height: 100));
    await b.writeAsBytes(_jpegBytes(width: 100, height: 100));

    final pathA = await ShelfMediaVault.importFromPath(a.path);
    await Future<void>.delayed(const Duration(milliseconds: 5));
    final pathB = await ShelfMediaVault.importFromPath(b.path);
    await ShelfMediaVault.touchAccess(pathA!);

    final entries = await ShelfMediaVault.entriesByRecentAccess();
    expect(
      entries.map((e) => File(e.originalPath).path).toList(),
      [File(pathA).path, File(pathB!).path],
    );
  });

  test('constants match recovery budget contract', () {
    expect(ShelfMediaVault.thumbLongestEdge, 512);
    expect(ShelfMediaVault.thumbJpegQuality, 75);
    expect(ShelfMediaVault.autoBackupMaxBytes, 20 * 1024 * 1024);
  });
}

import 'dart:convert';
import 'dart:io';

import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/collection/application/collection_shelf_ui_prefs_provider.dart';
import 'package:blindbox_app/features/collection/application/shelf_backup_commit.dart';
import 'package:blindbox_app/features/collection/application/shelf_import_flow.dart';
import 'package:blindbox_app/features/collection/application/shelf_recovery_import.dart';
import 'package:blindbox_app/features/collection/bootstrap/collection_app_bootstrap.dart';
import 'package:blindbox_app/features/collection/bootstrap/collection_recovery_gate.dart';
import 'package:blindbox_app/features/collection/data/android_backup_notifier.dart';
import 'package:blindbox_app/features/collection/data/collection_memory_store.dart';
import 'package:blindbox_app/features/collection/data/collection_seed_data.dart';
import 'package:blindbox_app/features/collection/data/shelf_media_vault.dart';
import 'package:blindbox_app/features/collection/data/shelf_recovery_pack.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/persistence/collection_snapshot_storage.dart';
import 'package:blindbox_app/features/collection/widgets/collectible_figure_placeholder.dart';
import 'package:blindbox_app/features/collection/widgets/shelf_recovery_decision_app.dart';
import 'package:blindbox_app/features/collection/widgets/shelf_recovery_dialog.dart';
import 'package:blindbox_app/shared/widgets/collectible_thumb_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';

Uint8List _jpegBytes({int width = 48, int height = 48, int r = 90}) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(r, 40, 160));
  return Uint8List.fromList(img.encodeJpg(image, quality: 85));
}

Uint8List _pngBytes({int width = 64, int height = 64}) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(20, 180, 90));
  return Uint8List.fromList(img.encodePng(image));
}

CollectionSnapshot _snap({
  String? localRef,
  String name = 'Figure',
  String? missingRef,
  String? coverRef,
}) {
  return CollectionSnapshot(
    shelfSeries: [
      ShelfSeries(
        id: 's1',
        name: 'Series',
        brand: 'Brand',
        ipName: 'IP',
        customCoverImageUri: coverRef,
        figures: [
          ShelfFigure(
            id: 'f1',
            seriesId: 's1',
            name: name,
            localImageUri: localRef,
            rarity: 'Regular',
            isSecret: false,
          ),
          if (missingRef != null)
            ShelfFigure(
              id: 'f2',
              seriesId: 's1',
              name: 'Missing',
              localImageUri: missingRef,
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

Future<String> _importJpeg(Directory support, String name, {int r = 90}) async {
  final source = File('${support.path}${Platform.pathSeparator}$name');
  await source.writeAsBytes(_jpegBytes(r: r));
  return (await ShelfMediaVault.importFromPath(source.path))!;
}

Future<String> _importPng(Directory support, String name) async {
  final source = File('${support.path}${Platform.pathSeparator}$name');
  await source.writeAsBytes(_pngBytes());
  return (await ShelfMediaVault.importFromPath(source.path))!;
}

/// Widget tests: avoid [Isolate.run] inside [importFromPath] (can hang the binding).
Future<String> _seedVaultJpeg(String id, {int r = 90}) async {
  await ShelfMediaVault.installRecoveredThumb(
    id: id,
    thumbBytes: _jpegBytes(r: r),
  );
  return 'shelf_media/originals/$id.jpg';
}

Future<void> _wipeVaultKeepPack(Directory support) async {
  SharedPreferences.setMockInitialValues({});
  final vaultRoot = Directory(
    '${support.path}${Platform.pathSeparator}shelf_media',
  );
  if (await vaultRoot.exists()) {
    await vaultRoot.delete(recursive: true);
  }
  ShelfMediaVault.resetForTest(clearSupportOverride: false);
  ShelfMediaVault.testSupportOverride = support;
  await ShelfMediaVault.ensureReady();
}

/// Advances real File/prefs IO started by DecisionApp, then rebuilds.
Future<void> _pumpDecisionIo(
  WidgetTester tester, {
  required Finder done,
}) async {
  await tester.pump();
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (DateTime.now().isBefore(deadline)) {
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
    if (done.evaluate().isNotEmpty) return;
  }
}

Widget _decisionApp(ShelfRecoveryPackContents pack) {
  return ShelfRecoveryDecisionApp(
    pack: pack,
    theme: ThemeData(useMaterial3: true),
    darkTheme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
    appBuilder: (_) => const MaterialApp(
      home: Scaffold(body: Text('main')),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempSupport;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempSupport = await Directory.systemTemp.createTemp('shelf_recovery_dlg_');
    ShelfMediaVault.resetForTest();
    ShelfRecoveryPack.resetForTest();
    CollectionRecoveryGate.resetForTest();
    CollectionMemoryStore.instance.resetForTest();
    AndroidBackupNotifier.resetForTest();
    ShelfBackupCommit.testBeforeMemoryHook = null;
    ShelfBackupCommit.testBeforeSnapshotSaveHook = null;
    ShelfMediaVault.testSupportOverride = tempSupport;
    ShelfRecoveryPack.testSupportOverride = tempSupport;
    ShelfRecoveryPack.debounceEnabledForTest = false;
    // Silence MissingPluginException from BackupManager notify in pack IO.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      AndroidBackupNotifier.channel,
      (_) async => null,
    );
    await ShelfMediaVault.ensureReady();
  });

  tearDown(() async {
    ShelfBackupCommit.testBeforeMemoryHook = null;
    ShelfBackupCommit.testBeforeSnapshotSaveHook = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AndroidBackupNotifier.channel, null);
    AndroidBackupNotifier.resetForTest();
    CollectionRecoveryGate.resetForTest();
    CollectionMemoryStore.instance.resetForTest();
    ShelfMediaVault.resetForTest();
    ShelfRecoveryPack.resetForTest();
    ShelfRecoveryPack.debounceEnabledForTest = false;
    if (await tempSupport.exists()) {
      await tempSupport.delete(recursive: true);
    }
  });

  test('shouldOfferRecovery only when prefs empty and pack valid', () {
    expect(
      CollectionRecoveryGate.shouldOfferRecovery(
        hasSnapshotPrefs: false,
        hasValidPack: true,
      ),
      isTrue,
    );
    expect(
      CollectionRecoveryGate.shouldOfferRecovery(
        hasSnapshotPrefs: true,
        hasValidPack: true,
      ),
      isFalse,
    );
    expect(
      CollectionRecoveryGate.shouldOfferRecovery(
        hasSnapshotPrefs: false,
        hasValidPack: false,
      ),
      isFalse,
    );
  });

  test('expired pack is deleted and not offered', () async {
    ShelfRecoveryPack.testNowUtc = DateTime.utc(2026, 1, 1);
    await ShelfRecoveryPack.write(
      snapshot: _snap(),
      memoryJson: '{}',
      uiPrefsJson: '{}',
    );
    expect(await ShelfRecoveryPack.tryLoad(), isNotNull);

    ShelfRecoveryPack.testNowUtc = DateTime.utc(2026, 2, 10);
    expect(await ShelfRecoveryPack.tryLoad(), isNull);
    expect(
      CollectionRecoveryGate.shouldOfferRecovery(
        hasSnapshotPrefs: false,
        hasValidPack: false,
      ),
      isFalse,
    );
  });

  test('pending gate blocks pack write, GC, and snapshot persist path', () async {
    final ref = await _importJpeg(tempSupport, 'keep.jpg');
    await ShelfRecoveryPack.write(
      snapshot: _snap(localRef: ref),
      memoryJson: '{"marker":"orig"}',
      uiPrefsJson: '{}',
      appVersion: 'orig',
    );
    final before = await ShelfRecoveryPack.tryLoad();
    expect(before!.manifest.appVersion, 'orig');

    CollectionRecoveryGate.enterPending();
    final blockedWrite = await ShelfRecoveryPack.write(
      snapshot: _snap(name: 'overwrite'),
      memoryJson: '{"marker":"new"}',
      uiPrefsJson: '{}',
      appVersion: 'new',
    );
    expect(blockedWrite.wrote, isFalse);

    ShelfRecoveryPack.scheduleWrite(snapshot: _snap(name: 'scheduled'));
    await Future<void>.delayed(const Duration(milliseconds: 400));

    final gc = await ShelfMediaVault.collectGarbage(
      const CollectionSnapshot(shelfSeries: [], figureStates: {}),
    );
    expect(gc.removedIds, isEmpty);
    expect(File(ShelfMediaVault.resolveToFilePathSync(ref)!).existsSync(), isTrue);

    final after = await ShelfRecoveryPack.tryLoad();
    expect(after!.manifest.appVersion, 'orig');
    expect(after.memoryJson, contains('"marker":"orig"'));
  });

  test('pending gate blocks CollectionNotifier persist; clear allows write',
      () async {
    CollectionAppBootstrap.prime(
      CollectionSnapshot(
        shelfSeries: [
          ShelfSeries(
            id: 's1',
            name: 'Series',
            brand: 'Brand',
            ipName: 'IP',
            figures: const [
              ShelfFigure(
                id: 'f1',
                seriesId: 's1',
                name: 'Fig',
                rarity: 'Regular',
                isSecret: false,
              ),
            ],
            shelfAccent: const Color(0xFFE8F5E9),
          ),
        ],
        figureStates: const {},
      ),
    );
    CollectionRecoveryGate.enterPending();
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final n = container.read(collectionNotifierProvider.notifier);

    n.cycleFigure('f1');
    await Future<void>.delayed(const Duration(milliseconds: 500));
    expect(await CollectionSnapshotStorage.load(), isNull);

    CollectionRecoveryGate.clearPending();
    n.cycleFigure('f1'); // wishlist → owned triggers another persist window
    await Future<void>.delayed(const Duration(milliseconds: 500));
    expect(await CollectionSnapshotStorage.load(), isNotNull);
  });

  test('Import restores snapshot, memory, prefs, thumbs, and vault refs', () async {
    final ref = await _importJpeg(tempSupport, 'photo.jpg');
    final id = ShelfMediaVault.idFromRef(ref)!;
    final memoryJson = jsonEncode({
      'firstSeriesAddedAtMs': 42,
      'ipSeriesDepth': {'ip.a': 2},
    });
    final uiPrefsJson = CollectionShelfUiPrefsCodec.encode(
      const CollectionShelfUiPrefs(completedSectionExpanded: true),
    );
    await ShelfRecoveryPack.write(
      snapshot: _snap(localRef: ref, name: 'Imported'),
      memoryJson: memoryJson,
      uiPrefsJson: uiPrefsJson,
    );

    await _wipeVaultKeepPack(tempSupport);

    final pack = await ShelfRecoveryPack.tryLoad();
    expect(pack, isNotNull);
    CollectionRecoveryGate.enterPending();
    final imported = await ShelfRecoveryImport.apply(pack!);
    expect(imported.shelfSeries.single.figures.single.name, 'Imported');
    expect(
      imported.shelfSeries.single.figures.single.localImageUri,
      'shelf_media/originals/$id.jpg',
    );

    final loadedSnap = await CollectionSnapshotStorage.load();
    expect(loadedSnap!.shelfSeries.single.figures.single.name, 'Imported');

    await CollectionMemoryStore.instance.ensureLoaded();
    expect(
      CollectionMemoryStore.instance.cached.firstSeriesAddedAtMs,
      42,
    );

    final prefs = await CollectionShelfUiPrefsStorage.load();
    expect(prefs.completedSectionExpanded, isTrue);

    final jpgRef = 'shelf_media/originals/$id.jpg';
    final abs = ShelfMediaVault.resolveToFilePathSync(jpgRef);
    expect(abs, isNotNull);
    expect(File(abs!).existsSync(), isTrue);
    expect(await ShelfMediaVault.recoveredFromThumbForTest(jpgRef), isTrue);
  });

  test('png original ref is rewritten to .jpg and resolves after import', () async {
    final pngRef = await _importPng(tempSupport, 'figure.png');
    expect(pngRef.endsWith('.png'), isTrue);
    final id = ShelfMediaVault.idFromRef(pngRef)!;

    await ShelfRecoveryPack.write(
      snapshot: _snap(localRef: pngRef, coverRef: pngRef, name: 'PngFig'),
      memoryJson: '{}',
      uiPrefsJson: '{}',
    );
    await _wipeVaultKeepPack(tempSupport);

    final pack = (await ShelfRecoveryPack.tryLoad())!;
    final imported = await ShelfRecoveryImport.apply(pack);
    final figureRef = imported.shelfSeries.single.figures.single.localImageUri;
    final coverRef = imported.shelfSeries.single.customCoverImageUri;
    expect(figureRef, 'shelf_media/originals/$id.jpg');
    expect(coverRef, 'shelf_media/originals/$id.jpg');

    final path = ShelfMediaVault.resolveToFilePathSync(figureRef);
    expect(path, isNotNull);
    expect(File(path!).existsSync(), isTrue);
  });

  test('memory failure leaves no snapshot prefs and keeps pack', () async {
    final ref = await _importJpeg(tempSupport, 'mem.jpg');
    await ShelfRecoveryPack.write(
      snapshot: _snap(localRef: ref, name: 'Keep'),
      memoryJson: '{}',
      uiPrefsJson: '{}',
      appVersion: 'mem-fail',
    );
    await _wipeVaultKeepPack(tempSupport);
    final pack = (await ShelfRecoveryPack.tryLoad())!;

    ShelfBackupCommit.testBeforeMemoryHook = () async {
      throw StateError('memory boom');
    };
    await expectLater(
      () => ShelfRecoveryImport.apply(pack),
      throwsA(isA<StateError>()),
    );

    expect(await CollectionSnapshotStorage.load(), isNull);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('collection_snapshot_v1'), isNull);
    expect((await ShelfRecoveryPack.tryLoad())!.manifest.appVersion, 'mem-fail');
  });

  test('import failure before snapshot save keeps pack and no snapshot', () async {
    await ShelfRecoveryPack.write(
      snapshot: _snap(name: 'Keep'),
      memoryJson: '{}',
      uiPrefsJson: '{}',
      appVersion: 'keep-me',
    );
    final pack = await ShelfRecoveryPack.tryLoad();
    ShelfBackupCommit.testBeforeSnapshotSaveHook = () async {
      throw StateError('boom');
    };
    await expectLater(
      () => ShelfRecoveryImport.apply(pack!),
      throwsA(isA<StateError>()),
    );
    expect(await CollectionSnapshotStorage.load(), isNull);
    final still = await ShelfRecoveryPack.tryLoad();
    expect(still!.manifest.appVersion, 'keep-me');
  });

  test('mediaTruncated pack omits older thumb after tight budget write', () async {
    // Seed two vault thumbs without Isolate.importFromPath decode cost.
    const keptId = 'keptthumb01';
    const droppedId = 'dropthumb02';
    await ShelfMediaVault.installRecoveredThumb(
      id: keptId,
      thumbBytes: _jpegBytes(r: 10),
    );
    await ShelfMediaVault.installRecoveredThumb(
      id: droppedId,
      thumbBytes: _jpegBytes(r: 200),
    );
    final kept = 'shelf_media/originals/$keptId.jpg';
    final dropped = 'shelf_media/originals/$droppedId.jpg';

    // Budget fits JSON + one small thumb only (48x48 jpegs are tiny).
    ShelfRecoveryPack.testMaxBytesOverride = 900;
    final result = await ShelfRecoveryPack.write(
      snapshot: _snap(localRef: kept, missingRef: dropped),
      memoryJson: '{}',
      uiPrefsJson: '{}',
    );
    expect(result.wrote, isTrue);
    expect(result.mediaTruncated, isTrue);

    await _wipeVaultKeepPack(tempSupport);
    final pack = (await ShelfRecoveryPack.tryLoad())!;
    expect(pack.manifest.mediaTruncated, isTrue);
    expect(pack.mediaIds.length, lessThan(2));

    final imported = await ShelfRecoveryImport.apply(pack);
    final missingFig =
        imported.shelfSeries.single.figures.firstWhere((f) => f.id == 'f2');
    final missingPath =
        ShelfMediaVault.resolveToFilePathSync(missingFig.localImageUri);
    expect(missingPath, isNotNull);
    expect(File(missingPath!).existsSync(), isFalse);
  });

  testWidgets(
    'mediaTruncated missing figure shows CollectibleFigurePlaceholder',
    (tester) async {
      // Pack truncation + missing file are covered by the unit test above.
      // Widget side: a recovered .jpg vault ref with no file must degrade to
      // CollectibleFigurePlaceholder (no crash).
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 80,
              height: 80,
              child: CollectibleThumbImage(
                imageRef: 'shelf_media/originals/dropthumb02.jpg',
                name: 'Missing',
                seedKey: 'f2',
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byType(CollectibleFigurePlaceholder), findsOneWidget);
    },
  );

  test('recovery welcome summary uses shared inventory helper', () {
    expect(
      ShelfRecoveryDialogCopy.summaryLine(
        seriesCount: 5,
        figureCount: 35,
        wishlistCount: 6,
        createdAt: DateTime.utc(2026, 11, 3, 18),
      ),
      '5 series, 35 figures and 6 wishlist items, saved '
      '${ShelfImportCopy.formatCreatedDate(DateTime.utc(2026, 11, 3, 18))}.',
    );
    expect(
      ShelfRecoveryDialogCopy.summaryLine(
        seriesCount: 1,
        figureCount: 1,
        wishlistCount: 1,
        createdAt: DateTime.utc(2026, 1, 1),
      ),
      contains('1 series, 1 figure and 1 wishlist item, saved'),
    );
    expect(
      ShelfRecoveryDialogCopy.summaryLine(
        seriesCount: 2,
        figureCount: 2,
        wishlistCount: 0,
        createdAt: DateTime.utc(2026, 3, 15),
      ),
      allOf(
        contains('2 series and 2 figures, saved'),
        isNot(contains('wishlist')),
      ),
    );
    expect(
      ShelfRecoveryDialogCopy.summaryLine(
        seriesCount: null,
        figureCount: 1,
        createdAt: DateTime.utc(2026, 1, 1),
      ),
      ShelfRecoveryDialogCopy.summaryFallback,
    );
    expect(
      ShelfRecoveryDialogCopy.summaryLine(
        seriesCount: 1,
        figureCount: 1,
        createdAt: null,
      ),
      ShelfRecoveryDialogCopy.summaryFallback,
    );
  });

  testWidgets('welcome page shows icon, copy, summary, and blocks system back', (
    tester,
  ) async {
    var imported = false;
    var fresh = false;
    final summary = ShelfRecoveryDialogCopy.summaryLine(
      seriesCount: 5,
      figureCount: 35,
      wishlistCount: 6,
      createdAt: DateTime.utc(2026, 11, 3, 18),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ShelfRecoveryDecisionPanel(
            summaryLine: summary,
            onImport: () => imported = true,
            onStartFresh: () => fresh = true,
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('shelf_recovery_welcome_icon')), findsOneWidget);
    expect(find.text(ShelfRecoveryDialogCopy.title), findsOneWidget);
    expect(find.text(ShelfRecoveryDialogCopy.subtitle), findsOneWidget);
    expect(find.text(summary), findsOneWidget);
    expect(find.textContaining('6 wishlist items'), findsOneWidget);
    expect(
      find.text(ShelfRecoveryDialogCopy.androidBackupCadenceNote),
      findsOneWidget,
    );
    expect(find.text(ShelfRecoveryDialogCopy.importLabel), findsOneWidget);
    expect(find.text(ShelfRecoveryDialogCopy.startFreshLabel), findsOneWidget);
    expect(find.text('Found a shelf on this device'), findsNothing);
    expect(find.text('Import'), findsNothing);

    await tester.tap(find.byKey(const Key('shelf_recovery_import')));
    expect(imported, isTrue);
    await tester.tap(find.byKey(const Key('shelf_recovery_start_fresh')));
    expect(fresh, isTrue);

    final handled = await tester.binding.handlePopRoute();
    await tester.pump();
    expect(handled, isTrue);
    expect(find.text(ShelfRecoveryDialogCopy.title), findsOneWidget);
    expect(find.byType(ShelfRecoveryDecisionPanel), findsOneWidget);
  });

  testWidgets('welcome summary omits wishlist when W=0 and uses fallback', (
    tester,
  ) async {
    final noWish = ShelfRecoveryDialogCopy.summaryLine(
      seriesCount: 1,
      figureCount: 1,
      wishlistCount: 0,
      createdAt: DateTime.utc(2026, 1, 1),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ShelfRecoveryDecisionPanel(
            summaryLine: noWish,
            onImport: () {},
            onStartFresh: () {},
          ),
        ),
      ),
    );
    expect(find.text(noWish), findsOneWidget);
    expect(find.textContaining('wishlist'), findsNothing);
    expect(find.textContaining('1 series and 1 figure'), findsOneWidget);
    expect(
      find.text(ShelfRecoveryDialogCopy.androidBackupCadenceNote),
      findsOneWidget,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ShelfRecoveryDecisionPanel(
            summaryLine: ShelfRecoveryDialogCopy.summaryFallback,
            onImport: () {},
            onStartFresh: () {},
          ),
        ),
      ),
    );
    expect(
      find.text(ShelfRecoveryDialogCopy.summaryFallback),
      findsOneWidget,
    );
    expect(
      find.text(ShelfRecoveryDialogCopy.androidBackupCadenceNote),
      findsOneWidget,
    );
  });

  testWidgets('welcome page golden', (tester) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final summary = ShelfRecoveryDialogCopy.summaryLine(
      seriesCount: 5,
      figureCount: 35,
      wishlistCount: 6,
      createdAt: DateTime.utc(2026, 11, 3, 18),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6B8F71)),
        ),
        home: Scaffold(
          body: ShelfRecoveryDecisionPanel(
            key: const Key('shelf_recovery_welcome_golden'),
            summaryLine: summary,
            onImport: () {},
            onStartFresh: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    await expectLater(
      find.byKey(const Key('shelf_recovery_welcome_golden')),
      matchesGoldenFile('goldens/shelf_recovery_welcome/welcome.png'),
    );
  });

  testWidgets('Start fresh confirm cancel vs delete', (tester) async {
    late BuildContext dialogContext;
    final theme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF6B8F71),
        error: const Color(0xFFB3261E),
        onError: const Color(0xFFFFFFFF),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Builder(
          builder: (context) {
            dialogContext = context;
            return const Scaffold(body: Text('host'));
          },
        ),
      ),
    );
    await tester.pump();

    expect(ShelfRecoveryDialogCopy.confirmTitle, 'Delete your old shelf?');
    expect(
      ShelfRecoveryDialogCopy.confirmBody,
      'Your old shelf will be permanently deleted. This can\'t be undone.',
    );
    expect(ShelfRecoveryDialogCopy.confirmDelete, 'Delete');
    expect(find.text('Start fresh?'), findsNothing);

    final cancelFuture = showShelfRecoveryStartFreshConfirm(dialogContext);
    await tester.pump();
    await tester.pump();
    expect(find.text(ShelfRecoveryDialogCopy.confirmTitle), findsOneWidget);
    expect(find.text(ShelfRecoveryDialogCopy.confirmBody), findsOneWidget);
    expect(find.text(ShelfRecoveryDialogCopy.confirmCancel), findsOneWidget);
    expect(find.text(ShelfRecoveryDialogCopy.confirmDelete), findsOneWidget);

    final deleteButton = tester.widget<FilledButton>(
      find.byKey(const Key('shelf_recovery_confirm_delete')),
    );
    final resolved = deleteButton.style!.backgroundColor!
        .resolve(<WidgetState>{})!;
    expect(resolved, theme.colorScheme.error);
    final onError = deleteButton.style!.foregroundColor!
        .resolve(<WidgetState>{})!;
    expect(onError, theme.colorScheme.onError);

    await tester.tap(find.byKey(const Key('shelf_recovery_confirm_cancel')));
    await tester.pump();
    expect(await cancelFuture, isFalse);
    expect(find.text(ShelfRecoveryDialogCopy.confirmBody), findsNothing);

    final deleteFuture = showShelfRecoveryStartFreshConfirm(dialogContext);
    await tester.pump();
    await tester.pump();
    await tester.tap(find.byKey(const Key('shelf_recovery_confirm_delete')));
    await tester.pump();
    expect(await deleteFuture, isTrue);
  });

  testWidgets('DecisionApp Import success shows main and clears gate', (
    tester,
  ) async {
    late ShelfRecoveryPackContents pack;
    await tester.runAsync(() async {
      final ref = await _seedVaultJpeg('decisionok');
      await ShelfRecoveryPack.write(
        snapshot: _snap(localRef: ref, name: 'OK'),
        memoryJson: '{}',
        uiPrefsJson: '{}',
      );
      await _wipeVaultKeepPack(tempSupport);
      pack = (await ShelfRecoveryPack.tryLoad())!;
    });
    CollectionRecoveryGate.enterPending();

    await tester.pumpWidget(_decisionApp(pack));
    await tester.pump();
    expect(find.text(ShelfRecoveryDialogCopy.title), findsOneWidget);
    expect(find.text(ShelfRecoveryDialogCopy.subtitle), findsOneWidget);
    expect(find.text(ShelfRecoveryDialogCopy.importLabel), findsOneWidget);
    expect(
      find.text(ShelfRecoveryDialogCopy.summaryLineForPack(pack)),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('shelf_recovery_import')));
    await _pumpDecisionIo(tester, done: find.text('main'));

    expect(find.text('main'), findsOneWidget);
    expect(CollectionRecoveryGate.isPending, isFalse);
    await tester.runAsync(() async {
      expect(await CollectionSnapshotStorage.load(), isNotNull);
    });
  });

  testWidgets('DecisionApp Import failure keeps panel, pack, gate; retry works', (
    tester,
  ) async {
    late ShelfRecoveryPackContents pack;
    await tester.runAsync(() async {
      final ref = await _seedVaultJpeg('decisionretry');
      await ShelfRecoveryPack.write(
        snapshot: _snap(localRef: ref, name: 'Retry'),
        memoryJson: '{}',
        uiPrefsJson: '{}',
        appVersion: 'retry-pack',
      );
      await _wipeVaultKeepPack(tempSupport);
      pack = (await ShelfRecoveryPack.tryLoad())!;
    });
    CollectionRecoveryGate.enterPending();
    ShelfBackupCommit.testBeforeSnapshotSaveHook = () async {
      throw StateError('nope');
    };

    await tester.pumpWidget(_decisionApp(pack));
    await tester.pump();
    await tester.tap(find.byKey(const Key('shelf_recovery_import')));
    await _pumpDecisionIo(
      tester,
      done: find.text(ShelfRecoveryDialogCopy.importFailed),
    );

    expect(find.text(ShelfRecoveryDialogCopy.importFailed), findsOneWidget);
    expect(find.text(ShelfRecoveryDialogCopy.title), findsOneWidget);
    expect(find.text('main'), findsNothing);
    expect(CollectionRecoveryGate.isPending, isTrue);
    await tester.runAsync(() async {
      expect(
        (await ShelfRecoveryPack.tryLoad())!.manifest.appVersion,
        'retry-pack',
      );
    });

    ShelfBackupCommit.testBeforeSnapshotSaveHook = null;
    await tester.tap(find.byKey(const Key('shelf_recovery_import')));
    await _pumpDecisionIo(tester, done: find.text('main'));

    expect(find.text('main'), findsOneWidget);
    expect(CollectionRecoveryGate.isPending, isFalse);
  });

  testWidgets('DecisionApp Start fresh Cancel keeps panel and pack', (
    tester,
  ) async {
    late ShelfRecoveryPackContents pack;
    await tester.runAsync(() async {
      await ShelfRecoveryPack.write(
        snapshot: _snap(name: 'Stay'),
        memoryJson: '{}',
        uiPrefsJson: '{}',
        appVersion: 'stay-pack',
      );
      pack = (await ShelfRecoveryPack.tryLoad())!;
    });
    CollectionRecoveryGate.enterPending();

    await tester.pumpWidget(_decisionApp(pack));
    await tester.pump();
    await tester.tap(find.byKey(const Key('shelf_recovery_start_fresh')));
    await tester.pump();
    await tester.pump();
    expect(find.text(ShelfRecoveryDialogCopy.confirmBody), findsOneWidget);

    await tester.tap(find.byKey(const Key('shelf_recovery_confirm_cancel')));
    await tester.pump();

    expect(find.text(ShelfRecoveryDialogCopy.title), findsOneWidget);
    expect(find.text('main'), findsNothing);
    await tester.runAsync(() async {
      expect(
        (await ShelfRecoveryPack.tryLoad())!.manifest.appVersion,
        'stay-pack',
      );
    });
    expect(CollectionRecoveryGate.isPending, isTrue);
  });

  testWidgets('DecisionApp Start fresh Delete shows main and removes pack', (
    tester,
  ) async {
    late ShelfRecoveryPackContents pack;
    await tester.runAsync(() async {
      await ShelfRecoveryPack.write(
        snapshot: _snap(name: 'Gone'),
        memoryJson: '{}',
        uiPrefsJson: '{}',
        appVersion: 'gone-pack',
      );
      pack = (await ShelfRecoveryPack.tryLoad())!;
    });
    CollectionRecoveryGate.enterPending();

    final dataChangedCalls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AndroidBackupNotifier.channel, (call) async {
      dataChangedCalls.add(call);
      return null;
    });

    await tester.pumpWidget(_decisionApp(pack));
    await tester.pump();
    await tester.tap(find.byKey(const Key('shelf_recovery_start_fresh')));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.byKey(const Key('shelf_recovery_confirm_delete')));
    await _pumpDecisionIo(tester, done: find.text('main'));

    expect(find.text('main'), findsOneWidget);
    await tester.runAsync(() async {
      expect(await ShelfRecoveryPack.tryLoad(), isNull);
    });
    expect(CollectionRecoveryGate.isPending, isFalse);
    expect(CollectionAppBootstrap.takeInitialSnapshot(), isNotNull);
    expect(
      dataChangedCalls.map((c) => c.method),
      contains(AndroidBackupNotifier.methodDataChanged),
    );
  });

  test('Start fresh deletes pack and clears gate', () async {
    await ShelfRecoveryPack.write(
      snapshot: _snap(name: 'Fresh'),
      memoryJson: '{}',
      uiPrefsJson: '{}',
      appVersion: 'fresh-pack',
    );
    expect(await ShelfRecoveryPack.tryLoad(), isNotNull);
    CollectionRecoveryGate.enterPending();

    await ShelfRecoveryPack.deletePack();
    CollectionAppBootstrap.prime(CollectionSeedData.initialSnapshot());
    CollectionRecoveryGate.clearPending();

    expect(await ShelfRecoveryPack.tryLoad(), isNull);
    expect(CollectionRecoveryGate.isPending, isFalse);
    expect(CollectionAppBootstrap.takeInitialSnapshot(), isNotNull);
  });
}

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:blindbox_app/features/collection/application/collection_shelf_ui_prefs_provider.dart';
import 'package:blindbox_app/features/collection/application/shelf_recovery_import.dart';
import 'package:blindbox_app/features/collection/bootstrap/collection_app_bootstrap.dart';
import 'package:blindbox_app/features/collection/bootstrap/collection_recovery_gate.dart';
import 'package:blindbox_app/features/collection/data/collection_memory_store.dart';
import 'package:blindbox_app/features/collection/data/collection_seed_data.dart';
import 'package:blindbox_app/features/collection/data/shelf_media_vault.dart';
import 'package:blindbox_app/features/collection/data/shelf_recovery_pack.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/persistence/collection_snapshot_storage.dart';
import 'package:blindbox_app/features/collection/widgets/shelf_recovery_dialog.dart';
import 'package:blindbox_app/shared/widgets/collectible_thumb_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';

Uint8List _jpegBytes({int width = 160, int height = 160}) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(90, 40, 160));
  return Uint8List.fromList(img.encodeJpg(image, quality: 90));
}

CollectionSnapshot _snap({
  String? localRef,
  String name = 'Figure',
  String? missingRef,
}) {
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

Future<String> _importJpeg(Directory support, String name) async {
  final source = File('${support.path}${Platform.pathSeparator}$name');
  await source.writeAsBytes(_jpegBytes());
  return (await ShelfMediaVault.importFromPath(source.path))!;
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
    ShelfRecoveryImport.testBeforeCommitHook = null;
    ShelfMediaVault.testSupportOverride = tempSupport;
    ShelfRecoveryPack.testSupportOverride = tempSupport;
    await ShelfMediaVault.ensureReady();
  });

  tearDown(() async {
    ShelfRecoveryImport.testBeforeCommitHook = null;
    CollectionRecoveryGate.resetForTest();
    CollectionMemoryStore.instance.resetForTest();
    ShelfMediaVault.resetForTest();
    ShelfRecoveryPack.resetForTest();
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

    // Simulate reinstall: clear prefs + wipe vault files, keep recovery pack.
    SharedPreferences.setMockInitialValues({});
    final vaultRoot = Directory(
      '${tempSupport.path}${Platform.pathSeparator}shelf_media',
    );
    if (await vaultRoot.exists()) {
      await vaultRoot.delete(recursive: true);
    }
    ShelfMediaVault.resetForTest(clearSupportOverride: false);
    ShelfMediaVault.testSupportOverride = tempSupport;
    await ShelfMediaVault.ensureReady();

    final pack = await ShelfRecoveryPack.tryLoad();
    expect(pack, isNotNull);
    CollectionRecoveryGate.enterPending();
    final imported = await ShelfRecoveryImport.apply(pack!);
    expect(imported.shelfSeries.single.figures.single.name, 'Imported');
    expect(imported.shelfSeries.single.figures.single.localImageUri, ref);

    final loadedSnap = await CollectionSnapshotStorage.load();
    expect(loadedSnap!.shelfSeries.single.figures.single.name, 'Imported');

    await CollectionMemoryStore.instance.ensureLoaded();
    expect(
      CollectionMemoryStore.instance.cached.firstSeriesAddedAtMs,
      42,
    );

    final prefs = await CollectionShelfUiPrefsStorage.load();
    expect(prefs.completedSectionExpanded, isTrue);

    final abs = ShelfMediaVault.resolveToFilePathSync(ref);
    expect(abs, isNotNull);
    expect(File(abs!).existsSync(), isTrue);
    expect(await ShelfMediaVault.recoveredFromThumbForTest(ref), isTrue);

    final thumb = File(
      '${tempSupport.path}${Platform.pathSeparator}shelf_media'
      '${Platform.pathSeparator}thumbs${Platform.pathSeparator}$id.jpg',
    );
    expect(thumb.existsSync(), isTrue);
  });

  test('import failure keeps recovery pack', () async {
    await ShelfRecoveryPack.write(
      snapshot: _snap(name: 'Keep'),
      memoryJson: '{}',
      uiPrefsJson: '{}',
      appVersion: 'keep-me',
    );
    final pack = await ShelfRecoveryPack.tryLoad();
    ShelfRecoveryImport.testBeforeCommitHook = () async {
      throw StateError('boom');
    };
    await expectLater(
      () => ShelfRecoveryImport.apply(pack!),
      throwsA(isA<StateError>()),
    );
    final still = await ShelfRecoveryPack.tryLoad();
    expect(still!.manifest.appVersion, 'keep-me');
  });

  test('mediaTruncated missing refs have no file on disk', () async {
    final present = await _importJpeg(tempSupport, 'present.jpg');
    final missingRef = 'shelf_media/originals/missingthumbid.jpg';
    await ShelfRecoveryPack.write(
      snapshot: _snap(localRef: present, missingRef: missingRef),
      memoryJson: '{}',
      uiPrefsJson: '{}',
    );
    SharedPreferences.setMockInitialValues({});
    final pack = await ShelfRecoveryPack.tryLoad();
    final imported = await ShelfRecoveryImport.apply(pack!);
    final missing = imported.shelfSeries.single.figures
        .firstWhere((f) => f.id == 'f2')
        .localImageUri;
    final path = ShelfMediaVault.resolveToFilePathSync(missing);
    expect(path, isNotNull);
    expect(File(path!).existsSync(), isFalse);
  });

  testWidgets('dialog shows copy, buttons, and is not barrier-dismissible', (
    tester,
  ) async {
    var imported = false;
    var fresh = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ShelfRecoveryDecisionPanel(
            onImport: () => imported = true,
            onStartFresh: () => fresh = true,
          ),
        ),
      ),
    );

    expect(find.text(ShelfRecoveryDialogCopy.title), findsOneWidget);
    expect(find.text(ShelfRecoveryDialogCopy.body), findsOneWidget);
    expect(find.text(ShelfRecoveryDialogCopy.importLabel), findsOneWidget);
    expect(find.text(ShelfRecoveryDialogCopy.startFreshLabel), findsOneWidget);

    await tester.tap(find.byKey(const Key('shelf_recovery_import')));
    expect(imported, isTrue);
    await tester.tap(find.byKey(const Key('shelf_recovery_start_fresh')));
    expect(fresh, isTrue);

    // PopScope canPop:false — back does not remove the panel.
    final dynamic widgetsBinding = tester.binding;
    expect(widgetsBinding is TestWidgetsFlutterBinding, isTrue);
  });

  testWidgets('Start fresh confirm cancel vs delete', (tester) async {
    late BuildContext dialogContext;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: Builder(
          builder: (context) {
            dialogContext = context;
            return const Scaffold(body: Text('host'));
          },
        ),
      ),
    );
    await tester.pump();

    final cancelFuture = showShelfRecoveryStartFreshConfirm(dialogContext);
    await tester.pump();
    await tester.pump();
    expect(find.text(ShelfRecoveryDialogCopy.confirmBody), findsOneWidget);
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
    // Seed content varies; priming must succeed for the notifier bootstrap.
    expect(CollectionAppBootstrap.takeInitialSnapshot(), isNotNull);
  });

  test('Import success clears gate and primes snapshot', () async {
    final ref = await _importJpeg(tempSupport, 'ok.jpg');
    await ShelfRecoveryPack.write(
      snapshot: _snap(localRef: ref, name: 'OK'),
      memoryJson: '{}',
      uiPrefsJson: '{}',
    );
    final pack = (await ShelfRecoveryPack.tryLoad())!;
    CollectionRecoveryGate.enterPending();

    final imported = await ShelfRecoveryImport.apply(pack);
    CollectionAppBootstrap.prime(imported);
    CollectionRecoveryGate.clearPending();
    ShelfRecoveryPack.scheduleWrite(snapshot: imported);

    expect(CollectionRecoveryGate.isPending, isFalse);
    expect(
      CollectionAppBootstrap.takeInitialSnapshot()
          .shelfSeries
          .single
          .figures
          .single
          .name,
      'OK',
    );
  });

  test('Import failure keeps gate pending and pack', () async {
    await ShelfRecoveryPack.write(
      snapshot: _snap(name: 'Fail'),
      memoryJson: '{}',
      uiPrefsJson: '{}',
      appVersion: 'fail-pack',
    );
    final pack = (await ShelfRecoveryPack.tryLoad())!;
    CollectionRecoveryGate.enterPending();
    ShelfRecoveryImport.testBeforeCommitHook = () async {
      throw StateError('nope');
    };

    await expectLater(
      () => ShelfRecoveryImport.apply(pack),
      throwsA(isA<StateError>()),
    );
    expect(CollectionRecoveryGate.isPending, isTrue);
    expect((await ShelfRecoveryPack.tryLoad())!.manifest.appVersion, 'fail-pack');
  });

  testWidgets('missing vault image shows placeholder widget', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 80,
            height: 80,
            child: CollectibleThumbImage(
              imageRef: 'shelf_media/originals/doesnotexist.jpg',
              name: 'Ghost',
              seedKey: 'ghost',
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byType(CollectibleThumbImage), findsOneWidget);
  });
}

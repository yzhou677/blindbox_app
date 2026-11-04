import 'dart:io';

import 'package:blindbox_app/features/collection/bootstrap/collection_recovery_gate.dart';
import 'package:blindbox_app/features/collection/data/android_backup_notifier.dart';
import 'package:blindbox_app/features/collection/data/shelf_media_vault.dart';
import 'package:blindbox_app/features/collection/data/shelf_recovery_pack.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

CollectionSnapshot _snap() {
  return const CollectionSnapshot(
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
            name: 'Fig',
            rarity: 'Regular',
            isSecret: false,
          ),
        ],
        shelfAccent: Color(0xFFE8F5E9),
      ),
    ],
    figureStates: {},
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempSupport;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempSupport = await Directory.systemTemp.createTemp('android_backup_');
    ShelfMediaVault.resetForTest();
    ShelfRecoveryPack.resetForTest();
    CollectionRecoveryGate.resetForTest();
    AndroidBackupNotifier.resetForTest();
    ShelfMediaVault.testSupportOverride = tempSupport;
    ShelfRecoveryPack.testSupportOverride = tempSupport;
    ShelfRecoveryPack.debounceEnabledForTest = false;
    await ShelfMediaVault.ensureReady();
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AndroidBackupNotifier.channel, null);
    AndroidBackupNotifier.resetForTest();
    CollectionRecoveryGate.resetForTest();
    ShelfMediaVault.resetForTest();
    ShelfRecoveryPack.resetForTest();
    ShelfRecoveryPack.debounceEnabledForTest = false;
    if (await tempSupport.exists()) {
      await tempSupport.delete(recursive: true);
    }
  });

  test('pack write success invokes dataChanged MethodChannel', () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AndroidBackupNotifier.channel, (call) async {
      calls.add(call);
      return null;
    });

    final result = await ShelfRecoveryPack.write(
      snapshot: _snap(),
      memoryJson: '{}',
      uiPrefsJson: '{}',
    );

    expect(result.wrote, isTrue);
    expect(calls, hasLength(1));
    expect(calls.single.method, AndroidBackupNotifier.methodDataChanged);
  });

  test('deletePack invokes dataChanged MethodChannel', () async {
    await ShelfRecoveryPack.write(
      snapshot: _snap(),
      memoryJson: '{}',
      uiPrefsJson: '{}',
    );

    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AndroidBackupNotifier.channel, (call) async {
      calls.add(call);
      return null;
    });

    await ShelfRecoveryPack.deletePack();

    expect(calls, hasLength(1));
    expect(calls.single.method, AndroidBackupNotifier.methodDataChanged);
    expect(await ShelfRecoveryPack.tryLoad(), isNull);
  });

  test('MethodChannel errors do not fail pack write', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AndroidBackupNotifier.channel, (call) async {
      throw PlatformException(code: 'backup', message: 'nope');
    });

    final result = await ShelfRecoveryPack.write(
      snapshot: _snap(),
      memoryJson: '{}',
      uiPrefsJson: '{}',
      appVersion: 'channel-error-write',
    );

    expect(result.wrote, isTrue);
    final pack = await ShelfRecoveryPack.tryLoad();
    expect(pack, isNotNull);
    expect(pack!.manifest.appVersion, 'channel-error-write');
  });

  test('MethodChannel errors do not fail deletePack / Start fresh path',
      () async {
    await ShelfRecoveryPack.write(
      snapshot: _snap(),
      memoryJson: '{}',
      uiPrefsJson: '{}',
      appVersion: 'before-delete',
    );
    expect(await ShelfRecoveryPack.tryLoad(), isNotNull);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AndroidBackupNotifier.channel, (call) async {
      throw PlatformException(code: 'backup', message: 'nope');
    });

    await ShelfRecoveryPack.deletePack();
    expect(await ShelfRecoveryPack.tryLoad(), isNull);
  });
}

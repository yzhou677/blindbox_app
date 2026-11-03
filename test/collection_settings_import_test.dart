import 'dart:io';

import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/collection/application/shelf_export_flow.dart';
import 'package:blindbox_app/features/collection/application/shelf_import_flow.dart';
import 'package:blindbox_app/features/collection/bootstrap/collection_recovery_gate.dart';
import 'package:blindbox_app/features/collection/data/collection_memory_store.dart';
import 'package:blindbox_app/features/collection/data/shelf_export_archive.dart';
import 'package:blindbox_app/features/collection/data/shelf_media_vault.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/widgets/collection_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

final class _FixedNotifier extends CollectionNotifier {
  _FixedNotifier(this._snap);
  final CollectionSnapshot _snap;

  @override
  CollectionSnapshot build() => _snap;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    CollectionMemoryStore.instance.resetForTest();
    CollectionRecoveryGate.resetForTest();
    ShelfMediaVault.resetForTest();
    ShelfExportArchive.resetForTest();
  });

  tearDown(() {
    CollectionRecoveryGate.resetForTest();
    ShelfMediaVault.resetForTest();
    ShelfExportArchive.resetForTest();
  });

  testWidgets('Settings shows Import shelf copy under Export', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          collectionNotifierProvider.overrideWith(
            () => _FixedNotifier(CollectionSnapshot.emptyTest()),
          ),
        ],
        child: const MaterialApp(home: CollectionSettingsScreen()),
      ),
    );
    expect(find.text(ShelfImportCopy.importTitle), findsOneWidget);
    expect(find.text(ShelfImportCopy.importSubtitle), findsOneWidget);
    expect(find.text('Export shelf'), findsOneWidget);
  });

  testWidgets('pick cancel does nothing', (tester) async {
    var unpackCalls = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          collectionNotifierProvider.overrideWith(
            () => _FixedNotifier(CollectionSnapshot.emptyTest()),
          ),
        ],
        child: MaterialApp(
          home: CollectionSettingsScreen(
            importDeps: ShelfImportFlowDeps(
              pickZipPath: () async => null,
              unpack: (_) async {
                unpackCalls++;
                throw StateError('no');
              },
              clearPickerTemp: () async {},
            ),
            flowDeps: const ShelfExportFlowDeps(
              cleanupStale: _noop,
              loadMemoryJson: _emptyJson,
              loadUiPrefsJson: _emptyJson,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('collection_settings_import_tile')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(unpackCalls, 0);
    expect(find.text(ShelfImportCopy.successSnack), findsNothing);
  });

  testWidgets('confirm Cancel does nothing', (tester) async {
    var unpackCalls = 0;
    final zip = File(
      '${Directory.systemTemp.path}${Platform.pathSeparator}imp_cancel.zip',
    )..writeAsBytesSync([1]);
    addTearDown(() {
      if (zip.existsSync()) zip.deleteSync();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          collectionNotifierProvider.overrideWith(
            () => _FixedNotifier(CollectionSnapshot.emptyTest()),
          ),
        ],
        child: MaterialApp(
          home: CollectionSettingsScreen(
            confirmReplaceOverride: () async => false,
            importDeps: ShelfImportFlowDeps(
              pickZipPath: () async => zip.path,
              unpack: (_) async {
                unpackCalls++;
                throw StateError('no');
              },
              clearPickerTemp: () async {},
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('collection_settings_import_tile')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(unpackCalls, 0);
    expect(find.text(ShelfImportCopy.confirmTitle), findsNothing);
  });

  testWidgets('success shows English SnackBar', (tester) async {
    final staging = _FakeStaging();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          collectionNotifierProvider.overrideWith(
            () => _FixedNotifier(CollectionSnapshot.emptyTest()),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: CollectionSettingsScreen(
              confirmReplaceOverride: () async => true,
              importDeps: ShelfImportFlowDeps(
                pickZipPath: () async => 'fake.zip',
                unpack: (_) async => staging,
                writeSafetyZip: ({
                  required snapshot,
                  required memoryJson,
                  required uiPrefsJson,
                }) async {},
                commitStaging: (_) async => CollectionSnapshot.emptyTest(),
                clearPickerTemp: () async {},
                collectGarbage: (_) async {},
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('collection_settings_import_tile')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text(ShelfImportCopy.successSnack), findsOneWidget);
    expect(find.text(ShelfImportCopy.importing), findsNothing);
  });

  testWidgets('failure SnackBar is English', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          collectionNotifierProvider.overrideWith(
            () => _FixedNotifier(CollectionSnapshot.emptyTest()),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: CollectionSettingsScreen(
              confirmReplaceOverride: () async => true,
              importDeps: ShelfImportFlowDeps(
                pickZipPath: () async => 'x.zip',
                unpack: (_) async {
                  throw ShelfExportException('bad');
                },
                clearPickerTemp: () async {},
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('collection_settings_import_tile')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text(ShelfImportCopy.failedSnack), findsOneWidget);
  });

  testWidgets('too large SnackBar is English', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          collectionNotifierProvider.overrideWith(
            () => _FixedNotifier(CollectionSnapshot.emptyTest()),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: CollectionSettingsScreen(
              confirmReplaceOverride: () async => true,
              importDeps: ShelfImportFlowDeps(
                pickZipPath: () async => 'x.zip',
                unpack: (_) async {
                  throw ShelfExportException('extracted size exceeds limit');
                },
                clearPickerTemp: () async {},
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('collection_settings_import_tile')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text(ShelfImportCopy.tooLargeSnack), findsOneWidget);
  });
}

Future<void> _noop() async {}
Future<String> _emptyJson() async => '{}';

class _FakeStaging extends ShelfExportStaging {
  _FakeStaging()
      : super(
          stagingDir: Directory.systemTemp,
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

  @override
  Future<void> delete() async {}
}

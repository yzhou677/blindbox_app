import 'dart:async';
import 'dart:io';

import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/collection/application/shelf_export_flow.dart';
import 'package:blindbox_app/features/collection/application/shelf_import_flow.dart';
import 'package:blindbox_app/features/collection/bootstrap/collection_app_bootstrap.dart';
import 'package:blindbox_app/features/collection/bootstrap/collection_recovery_gate.dart';
import 'package:blindbox_app/features/collection/data/collection_memory_store.dart';
import 'package:blindbox_app/features/collection/data/shelf_export_archive.dart';
import 'package:blindbox_app/features/collection/data/shelf_media_vault.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/persistence/collection_snapshot_storage.dart';
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

CollectionSnapshot _oneSeriesOneFigure() {
  return CollectionSnapshot(
    shelfSeries: [
      ShelfSeries(
        id: 's1',
        name: 'Series One',
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
        shelfAccent: const Color(0xFFE8F5E9),
      ),
    ],
    figureStates: const {},
  );
}

CollectionSnapshot _twoSeriesTwoFigures() {
  return CollectionSnapshot(
    shelfSeries: [
      ShelfSeries(
        id: 's1',
        name: 'A',
        brand: 'Brand',
        ipName: 'IP',
        figures: [
          ShelfFigure(
            id: 'f1',
            seriesId: 's1',
            name: 'One',
            rarity: 'Regular',
            isSecret: false,
          ),
        ],
        shelfAccent: const Color(0xFFE8F5E9),
      ),
      ShelfSeries(
        id: 's2',
        name: 'B',
        brand: 'Brand',
        ipName: 'IP',
        figures: [
          ShelfFigure(
            id: 'f2',
            seriesId: 's2',
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

  testWidgets('confirm dialog shows singular summary counts and date',
      (tester) async {
    final staging = _FakeStaging(
      snapshot: _oneSeriesOneFigure(),
      createdAt: DateTime.utc(2026, 1, 1),
      seriesCountManifest: 99,
      figureCountManifest: 99,
    );
    final expectedDate =
        ShelfImportCopy.formatCreatedDate(DateTime.utc(2026, 1, 1));
    final expectedSummary = ShelfImportCopy.confirmSummary(
      seriesCount: 1,
      figureCount: 1,
      createdDate: expectedDate,
    );

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
              pickZipPath: () async => 'fake.zip',
              unpack: (_) async => staging,
              clearPickerTemp: () async {},
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('collection_settings_import_tile')));
    await tester.pump();
    await tester.pump();
    expect(find.text(ShelfImportCopy.confirmTitle), findsOneWidget);
    expect(find.textContaining(expectedSummary), findsOneWidget);
    expect(find.textContaining('1 series'), findsOneWidget);
    expect(find.textContaining('1 figure,'), findsOneWidget);
    expect(find.textContaining('99'), findsNothing);
  });

  testWidgets('confirm dialog shows plural summary counts', (tester) async {
    final staging = _FakeStaging(
      snapshot: _twoSeriesTwoFigures(),
      createdAt: DateTime.utc(2026, 3, 15),
    );
    final expectedDate =
        ShelfImportCopy.formatCreatedDate(DateTime.utc(2026, 3, 15));
    final expectedSummary = ShelfImportCopy.confirmSummary(
      seriesCount: 2,
      figureCount: 2,
      createdDate: expectedDate,
    );

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
              pickZipPath: () async => 'fake.zip',
              unpack: (_) async => staging,
              clearPickerTemp: () async {},
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('collection_settings_import_tile')));
    await tester.pump();
    await tester.pump();
    expect(find.textContaining(expectedSummary), findsOneWidget);
    expect(find.textContaining('2 series'), findsOneWidget);
    expect(find.textContaining('2 figures'), findsOneWidget);
  });

  testWidgets('confirm Cancel deletes staging and leaves shelf unchanged',
      (tester) async {
    final old = _oneSeriesOneFigure();
    await CollectionSnapshotStorage.save(old);
    CollectionAppBootstrap.prime(old);

    var stagingDeleted = false;
    final staging = _FakeStaging(
      snapshot: _twoSeriesTwoFigures(),
      createdAt: DateTime.utc(2026, 2, 2),
      onDelete: () => stagingDeleted = true,
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: CollectionSettingsScreen(
            importDeps: ShelfImportFlowDeps(
              pickZipPath: () async => 'fake.zip',
              unpack: (_) async => staging,
              commitStaging: (_) async => fail('should not commit'),
              clearPickerTemp: () async {},
            ),
          ),
        ),
      ),
    );

    final container = ProviderScope.containerOf(
      tester.element(find.byType(CollectionSettingsScreen)),
    );
    final notifier = container.read(collectionNotifierProvider.notifier);

    await tester.tap(find.byKey(const Key('collection_settings_import_tile')));
    await tester.pump();
    await tester.pump();
    expect(find.text(ShelfImportCopy.confirmTitle), findsOneWidget);

    await tester.tap(find.byKey(const Key('collection_settings_import_cancel')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(stagingDeleted, isTrue);
    expect(find.text(ShelfImportCopy.confirmTitle), findsNothing);
    expect(find.text(ShelfImportCopy.successSnack), findsNothing);
    expect(notifier.persistenceSuspendedForTest, isFalse);
    expect(
      container.read(collectionNotifierProvider).shelfSeries.single.name,
      'Series One',
    );
    final prefs = await CollectionSnapshotStorage.load();
    expect(prefs!.shelfSeries.single.name, 'Series One');
  });

  testWidgets('bad zip skips confirm and shows English failure', (tester) async {
    var confirmShown = false;
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
              confirmReplaceOverride: (_) async {
                confirmShown = true;
                return true;
              },
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
    expect(confirmShown, isFalse);
    expect(find.text(ShelfImportCopy.confirmTitle), findsNothing);
    expect(find.text(ShelfImportCopy.failedSnack), findsOneWidget);
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
              confirmReplaceOverride: (_) async => true,
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
    expect(find.text(ShelfImportCopy.checking), findsNothing);
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
              confirmReplaceOverride: (_) async => true,
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
    expect(find.text(ShelfImportCopy.confirmTitle), findsNothing);
  });

  testWidgets('system back during checking is blocked', (tester) async {
    final unpackGate = Completer<ShelfExportStaging>();
    addTearDown(() {
      if (!unpackGate.isCompleted) {
        unpackGate.complete(_FakeStaging());
      }
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          collectionNotifierProvider.overrideWith(
            () => _FixedNotifier(CollectionSnapshot.emptyTest()),
          ),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: TextButton(
                  key: const Key('open_settings'),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => CollectionSettingsScreen(
                          confirmReplaceOverride: (_) async => false,
                          importDeps: ShelfImportFlowDeps(
                            pickZipPath: () async => 'fake.zip',
                            unpack: (_) => unpackGate.future,
                            clearPickerTemp: () async {},
                          ),
                        ),
                      ),
                    );
                  },
                  child: const Text('Open'),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('open_settings')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('collection_settings_import_tile')));
    await tester.pump();
    await tester.pump();
    expect(find.text(ShelfImportCopy.checking), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.byType(CollectionSettingsScreen), findsOneWidget);
    expect(find.text(ShelfImportCopy.checking), findsOneWidget);

    unpackGate.complete(_FakeStaging());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  });

  testWidgets('system back during import is blocked', (tester) async {
    final gate = Completer<CollectionSnapshot>();
    final staging = _FakeStaging();
    addTearDown(() {
      if (!gate.isCompleted) {
        gate.complete(CollectionSnapshot.emptyTest());
      }
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          collectionNotifierProvider.overrideWith(
            () => _FixedNotifier(CollectionSnapshot.emptyTest()),
          ),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: TextButton(
                  key: const Key('open_settings'),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => CollectionSettingsScreen(
                          confirmReplaceOverride: (_) async => true,
                          importDeps: ShelfImportFlowDeps(
                            pickZipPath: () async => 'fake.zip',
                            unpack: (_) async => staging,
                            writeSafetyZip: ({
                              required snapshot,
                              required memoryJson,
                              required uiPrefsJson,
                            }) async {},
                            commitStaging: (_) => gate.future,
                            clearPickerTemp: () async {},
                            collectGarbage: (_) async {},
                          ),
                        ),
                      ),
                    );
                  },
                  child: const Text('Open'),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('open_settings')));
    await tester.pumpAndSettle();
    expect(find.byType(CollectionSettingsScreen), findsOneWidget);

    await tester.tap(find.byKey(const Key('collection_settings_import_tile')));
    await tester.pump();
    await tester.pump();
    expect(find.text(ShelfImportCopy.importing), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.byType(CollectionSettingsScreen), findsOneWidget);
    expect(find.text(ShelfImportCopy.importing), findsOneWidget);
    expect(find.text('Open'), findsNothing);

    gate.complete(CollectionSnapshot.emptyTest());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text(ShelfImportCopy.importing), findsNothing);
  });
}

Future<void> _noop() async {}
Future<String> _emptyJson() async => '{}';

class _FakeStaging extends ShelfExportStaging {
  _FakeStaging({
    CollectionSnapshot? snapshot,
    DateTime? createdAt,
    int seriesCountManifest = 0,
    int figureCountManifest = 0,
    this.onDelete,
  }) : super(
          stagingDir: Directory.systemTemp,
          manifest: ShelfExportManifest(
            kind: ShelfExportArchive.kind,
            schemaVersion: 1,
            createdAt: createdAt ?? DateTime.utc(2026, 1, 1),
            appVersion: '1',
            seriesCount: seriesCountManifest,
            figureCount: figureCountManifest,
            originalCount: 0,
            thumbCount: 0,
            mediaIncomplete: false,
          ),
          snapshot: snapshot ?? CollectionSnapshot.emptyTest(),
          memoryJson: '{}',
          uiPrefsJson: '{}',
          originalFiles: const {},
          thumbFiles: const {},
          extractedBytes: 0,
        );

  final void Function()? onDelete;

  @override
  Future<void> delete() async {
    onDelete?.call();
  }
}

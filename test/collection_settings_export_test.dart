import 'dart:io';

import 'package:blindbox_app/core/router/app_router.dart';
import 'package:blindbox_app/features/catalog/application/catalog_bundle_cache.dart';
import 'package:blindbox_app/features/catalog/application/catalog_bundle_provider.dart';
import 'package:blindbox_app/features/catalog/catalog_bundle.dart';
import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/collection/application/collection_shelf_ui_prefs_provider.dart';
import 'package:blindbox_app/features/collection/application/shelf_export_flow.dart';
import 'package:blindbox_app/features/collection/bootstrap/collection_recovery_gate.dart';
import 'package:blindbox_app/features/collection/data/collection_memory_store.dart';
import 'package:blindbox_app/features/collection/data/series_release_lookup.dart';
import 'package:blindbox_app/features/collection/data/shelf_export_archive.dart';
import 'package:blindbox_app/features/collection/data/shelf_media_vault.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/widgets/collection_settings_screen.dart';
import 'package:blindbox_app/features/home/application/home_feed_provider.dart';
import 'package:blindbox_app/features/home/data/mock_latest_drops.dart';
import 'package:blindbox_app/features/official_feed/application/official_feed_providers.dart';
import 'package:blindbox_app/features/official_feed/domain/official_feed_catalog.dart';
import 'package:blindbox_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

List<Override> _testOverrides() => [
  catalogBundleProvider.overrideWith(
    (_) async =>
        const CatalogSeedBundle(brands: [], ips: [], series: [], figures: []),
  ),
  homeFeedSnapshotProvider.overrideWith(
    (_) async => HomeFeedSnapshot(
      latest: mockSeriesReleases,
      trending: mockSeriesReleases.skip(1).take(4).toList(growable: false),
    ),
  ),
  officialFeedCatalogProvider.overrideWith(
    (_) async => OfficialFeedCatalog.empty,
  ),
  seriesReleaseLookupProvider.overrideWithValue(mockSeriesReleaseByDropId),
  collectionNotifierProvider.overrideWith(_EmptyCollectionNotifier.new),
];

final class _EmptyCollectionNotifier extends CollectionNotifier {
  @override
  CollectionSnapshot build() => CollectionSnapshot.emptyTest();
}

/// Sync delete — async dart:io can hang under widget-test fake async.
Future<void> _syncDelete(String path) async {
  final f = File(path);
  if (f.existsSync()) f.deleteSync();
}

ShelfExportWriteResult _writtenZip(
  String path, {
  int uncompressedBytes = 10,
  bool mediaIncomplete = false,
  bool exceedsWarnThreshold = false,
}) {
  return ShelfExportWriteResult.written(
    zipPath: path,
    uncompressedBytes: uncompressedBytes,
    zipBytes: 1,
    mediaIncomplete: mediaIncomplete,
    exceedsWarnThreshold: exceedsWarnThreshold,
    originalCount: 0,
    thumbCount: 0,
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
    CatalogBundleCache.resetForTest();
    CatalogBundleCache.prime(
      const CatalogSeedBundle(brands: [], ips: [], series: [], figures: []),
    );
    appRouter.go('/collection');
  });

  tearDown(() {
    CollectionRecoveryGate.resetForTest();
    ShelfMediaVault.resetForTest();
    ShelfExportArchive.resetForTest();
    CatalogBundleCache.resetForTest();
  });

  testWidgets('Collection AppBar gear opens Settings', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: _testOverrides(),
        child: const BlindboxApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byKey(const Key('collection_settings_button')), findsOneWidget);
    await tester.tap(find.byKey(const Key('collection_settings_button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Shelf backup'), findsOneWidget);
    expect(find.text('Export shelf'), findsOneWidget);
    expect(
      find.text('Share a full backup with original photos'),
      findsOneWidget,
    );
    expect(find.text('Import shelf'), findsOneWidget);
    expect(
      find.text('Replace your shelf with a backup file'),
      findsOneWidget,
    );
  });

  testWidgets('Export shows progress, disables repeat taps, shares once',
      (tester) async {
    var exportCalls = 0;
    var shareCalls = 0;
    final temp = Directory.systemTemp.createTempSync('settings_export_');
    addTearDown(() {
      if (temp.existsSync()) temp.deleteSync(recursive: true);
    });
    final zip = File('${temp.path}${Platform.pathSeparator}bak.zip')
      ..writeAsBytesSync([1], flush: true);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          collectionNotifierProvider.overrideWith(_EmptyCollectionNotifier.new),
        ],
        child: MaterialApp(
          home: CollectionSettingsScreen(
            flowDeps: ShelfExportFlowDeps(
              cleanupStale: () async {},
              loadMemoryJson: () async => '{}',
              loadUiPrefsJson: () async => '{}',
              estimate: ({
                required snapshot,
                required memoryJson,
                required uiPrefsJson,
              }) async =>
                  const ShelfExportSizeEstimate(
                    uncompressedBytes: 10,
                    mediaIncomplete: false,
                  ),
              export: ({
                required snapshot,
                required memoryJson,
                required uiPrefsJson,
                onProgress,
              }) async {
                exportCalls++;
                onProgress?.call(1, 2);
                // Stay "exporting" until fake-async advances past this delay.
                await Future<void>.delayed(const Duration(milliseconds: 100));
                onProgress?.call(2, 2);
                return _writtenZip(zip.path);
              },
              shareZip: (_) async {
                shareCalls++;
                return null;
              },
              deleteFile: _syncDelete,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('collection_settings_export_tile')));
    // Flush microtasks into the delayed wait (still exporting).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));

    expect(exportCalls, 1);
    expect(find.textContaining('Preparing backup'), findsOneWidget);
    expect(
      find.byKey(const Key('collection_settings_export_bar')),
      findsOneWidget,
    );

    // Second tap while exporting must not start another run.
    await tester.tap(find.byKey(const Key('collection_settings_export_tile')));
    await tester.pump();
    expect(exportCalls, 1);

    // Finish the delayed export + share (zip kept for receivers).
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();

    expect(shareCalls, 1);
    expect(zip.existsSync(), isTrue);
  });

  testWidgets('share dismiss keeps zip', (tester) async {
    final temp = Directory.systemTemp.createTempSync('settings_share_');
    addTearDown(() {
      if (temp.existsSync()) temp.deleteSync(recursive: true);
    });
    final zip = File('${temp.path}${Platform.pathSeparator}bak.zip')
      ..writeAsBytesSync([1], flush: true);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          collectionNotifierProvider.overrideWith(_EmptyCollectionNotifier.new),
        ],
        child: MaterialApp(
          home: CollectionSettingsScreen(
            flowDeps: ShelfExportFlowDeps(
              cleanupStale: () async {},
              loadMemoryJson: () async => '{}',
              loadUiPrefsJson: () async => '{}',
              estimate: ({
                required snapshot,
                required memoryJson,
                required uiPrefsJson,
              }) async =>
                  const ShelfExportSizeEstimate(
                    uncompressedBytes: 10,
                    mediaIncomplete: false,
                  ),
              export: ({
                required snapshot,
                required memoryJson,
                required uiPrefsJson,
                onProgress,
              }) async =>
                  _writtenZip(zip.path),
              shareZip: (_) async => null,
              deleteFile: _syncDelete,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('collection_settings_export_tile')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(zip.existsSync(), isTrue);
  });

  testWidgets('share exception deletes zip', (tester) async {
    final temp = Directory.systemTemp.createTempSync('settings_share_fail_');
    addTearDown(() {
      if (temp.existsSync()) temp.deleteSync(recursive: true);
    });
    final zip = File('${temp.path}${Platform.pathSeparator}bak.zip')
      ..writeAsBytesSync([1], flush: true);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          collectionNotifierProvider.overrideWith(_EmptyCollectionNotifier.new),
        ],
        child: MaterialApp(
          home: CollectionSettingsScreen(
            flowDeps: ShelfExportFlowDeps(
              cleanupStale: () async {},
              loadMemoryJson: () async => '{}',
              loadUiPrefsJson: () async => '{}',
              estimate: ({
                required snapshot,
                required memoryJson,
                required uiPrefsJson,
              }) async =>
                  const ShelfExportSizeEstimate(
                    uncompressedBytes: 10,
                    mediaIncomplete: false,
                  ),
              export: ({
                required snapshot,
                required memoryJson,
                required uiPrefsJson,
                onProgress,
              }) async =>
                  _writtenZip(zip.path),
              shareZip: (_) async {
                throw StateError('share failed');
              },
              deleteFile: _syncDelete,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('collection_settings_export_tile')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(zip.existsSync(), isFalse);
    expect(
      find.text('Couldn\'t create a backup. Try again.'),
      findsOneWidget,
    );
  });

  testWidgets('over 500MB Cancel does not export; Continue does', (tester) async {
    var exportCalls = 0;
    var shareCalls = 0;
    final temp = Directory.systemTemp.createTempSync('settings_warn_');
    addTearDown(() {
      if (temp.existsSync()) temp.deleteSync(recursive: true);
    });

    Future<void> pumpWithConfirm(Future<bool> Function(String) confirm) {
      return tester.pumpWidget(
        ProviderScope(
          overrides: [
            collectionNotifierProvider.overrideWith(
              _EmptyCollectionNotifier.new,
            ),
          ],
          child: MaterialApp(
            home: CollectionSettingsScreen(
              confirmLargeBackupOverride: confirm,
              flowDeps: ShelfExportFlowDeps(
                cleanupStale: () async {},
                loadMemoryJson: () async => '{}',
                loadUiPrefsJson: () async => '{}',
                estimate: ({
                  required snapshot,
                  required memoryJson,
                  required uiPrefsJson,
                }) async {
                  ShelfExportArchive.testWarnBytesOverride = 50;
                  return const ShelfExportSizeEstimate(
                    uncompressedBytes: 80,
                    mediaIncomplete: false,
                  );
                },
                export: ({
                  required snapshot,
                  required memoryJson,
                  required uiPrefsJson,
                  onProgress,
                }) async {
                  exportCalls++;
                  final zip = File(
                    '${temp.path}${Platform.pathSeparator}w$exportCalls.zip',
                  )..writeAsBytesSync([1], flush: true);
                  return _writtenZip(
                    zip.path,
                    uncompressedBytes: 80,
                    exceedsWarnThreshold: true,
                  );
                },
                shareZip: (_) async {
                  shareCalls++;
                  return null;
                },
                deleteFile: _syncDelete,
              ),
            ),
          ),
        ),
      );
    }

    await pumpWithConfirm((_) async => false);
    await tester.tap(find.byKey(const Key('collection_settings_export_tile')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(exportCalls, 0);
    expect(shareCalls, 0);

    await pumpWithConfirm((_) async => true);
    await tester.tap(find.byKey(const Key('collection_settings_export_tile')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(exportCalls, 1);
    expect(shareCalls, 1);
  });

  testWidgets('over 2GB shows reject copy and does not share', (tester) async {
    var shareCalls = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          collectionNotifierProvider.overrideWith(_EmptyCollectionNotifier.new),
        ],
        child: MaterialApp(
          home: CollectionSettingsScreen(
            flowDeps: ShelfExportFlowDeps(
              cleanupStale: () async {},
              loadMemoryJson: () async => '{}',
              loadUiPrefsJson: () async => '{}',
              estimate: ({
                required snapshot,
                required memoryJson,
                required uiPrefsJson,
              }) async {
                ShelfExportArchive.testRejectBytesOverride = 100;
                return const ShelfExportSizeEstimate(
                  uncompressedBytes: 200,
                  mediaIncomplete: false,
                );
              },
              export: ({
                required snapshot,
                required memoryJson,
                required uiPrefsJson,
                onProgress,
              }) async {
                fail('export should not run');
              },
              shareZip: (_) async {
                shareCalls++;
                return null;
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('collection_settings_export_tile')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(
      find.text('This shelf is too large to export (over 2 GB).'),
      findsOneWidget,
    );
    expect(shareCalls, 0);
  });

  testWidgets('failure shows error and re-enables export', (tester) async {
    var exportCalls = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          collectionNotifierProvider.overrideWith(_EmptyCollectionNotifier.new),
        ],
        child: MaterialApp(
          home: CollectionSettingsScreen(
            flowDeps: ShelfExportFlowDeps(
              cleanupStale: () async {},
              loadMemoryJson: () async => '{}',
              loadUiPrefsJson: () async => '{}',
              estimate: ({
                required snapshot,
                required memoryJson,
                required uiPrefsJson,
              }) async =>
                  const ShelfExportSizeEstimate(
                    uncompressedBytes: 10,
                    mediaIncomplete: false,
                  ),
              export: ({
                required snapshot,
                required memoryJson,
                required uiPrefsJson,
                onProgress,
              }) async {
                exportCalls++;
                throw StateError('nope');
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('collection_settings_export_tile')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(
      find.text('Couldn\'t create a backup. Try again.'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('collection_settings_export_tile')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(exportCalls, 2);
  });

  testWidgets('mediaIncomplete success shows missing photos note', (tester) async {
    final temp = Directory.systemTemp.createTempSync('settings_incomplete_');
    addTearDown(() {
      if (temp.existsSync()) temp.deleteSync(recursive: true);
    });
    final zip = File('${temp.path}${Platform.pathSeparator}bak.zip')
      ..writeAsBytesSync([1], flush: true);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          collectionNotifierProvider.overrideWith(_EmptyCollectionNotifier.new),
        ],
        child: MaterialApp(
          home: CollectionSettingsScreen(
            flowDeps: ShelfExportFlowDeps(
              cleanupStale: () async {},
              loadMemoryJson: () async => '{}',
              loadUiPrefsJson: () async => '{}',
              estimate: ({
                required snapshot,
                required memoryJson,
                required uiPrefsJson,
              }) async =>
                  const ShelfExportSizeEstimate(
                    uncompressedBytes: 10,
                    mediaIncomplete: true,
                  ),
              export: ({
                required snapshot,
                required memoryJson,
                required uiPrefsJson,
                onProgress,
              }) async =>
                  _writtenZip(zip.path, mediaIncomplete: true),
              shareZip: (_) async => null,
              deleteFile: _syncDelete,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('collection_settings_export_tile')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(
      find.text('Some photos were missing and weren\'t included.'),
      findsOneWidget,
    );
  });

  testWidgets('export does not change prefs, vault, or gate', (tester) async {
    CollectionRecoveryGate.clearPending();
    final beforePrefs = await CollectionShelfUiPrefsStorage.load();
    await CollectionMemoryStore.instance.replaceFromRecoveryJson(
      '{"firstSeriesAddedAtMs":11}',
    );

    final temp = Directory.systemTemp.createTempSync('settings_readonly_');
    addTearDown(() {
      if (temp.existsSync()) temp.deleteSync(recursive: true);
    });
    final zip = File('${temp.path}${Platform.pathSeparator}bak.zip')
      ..writeAsBytesSync([1], flush: true);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          collectionNotifierProvider.overrideWith(_EmptyCollectionNotifier.new),
        ],
        child: MaterialApp(
          home: CollectionSettingsScreen(
            flowDeps: ShelfExportFlowDeps(
              cleanupStale: () async {},
              loadMemoryJson: () async => '{"firstSeriesAddedAtMs":11}',
              loadUiPrefsJson: () async => '{}',
              estimate: ({
                required snapshot,
                required memoryJson,
                required uiPrefsJson,
              }) async =>
                  const ShelfExportSizeEstimate(
                    uncompressedBytes: 10,
                    mediaIncomplete: false,
                  ),
              export: ({
                required snapshot,
                required memoryJson,
                required uiPrefsJson,
                onProgress,
              }) async =>
                  _writtenZip(zip.path),
              shareZip: (_) async => null,
              deleteFile: _syncDelete,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('collection_settings_export_tile')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(CollectionRecoveryGate.isPending, isFalse);
    final afterPrefs = await CollectionShelfUiPrefsStorage.load();
    expect(afterPrefs, beforePrefs);
    await CollectionMemoryStore.instance.ensureLoaded();
    expect(CollectionMemoryStore.instance.cached.firstSeriesAddedAtMs, 11);
  });
}

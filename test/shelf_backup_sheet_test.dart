import 'dart:async';
import 'dart:io';

import 'package:blindbox_app/core/router/app_router.dart';
import 'package:blindbox_app/features/catalog/application/catalog_bundle_cache.dart';
import 'package:blindbox_app/features/catalog/application/catalog_bundle_provider.dart';
import 'package:blindbox_app/features/catalog/catalog_bundle.dart';
import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/collection/application/shelf_export_flow.dart';
import 'package:blindbox_app/features/collection/application/shelf_import_flow.dart';
import 'package:blindbox_app/features/collection/bootstrap/collection_recovery_gate.dart';
import 'package:blindbox_app/features/collection/data/collection_memory_store.dart';
import 'package:blindbox_app/features/collection/data/series_release_lookup.dart';
import 'package:blindbox_app/features/collection/data/shelf_export_archive.dart';
import 'package:blindbox_app/features/collection/data/shelf_media_vault.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/widgets/shelf_backup_sheet.dart';
import 'package:blindbox_app/features/home/application/home_feed_provider.dart';
import 'package:blindbox_app/features/home/data/mock_latest_drops.dart';
import 'package:blindbox_app/features/official_feed/application/official_feed_providers.dart';
import 'package:blindbox_app/features/official_feed/domain/official_feed_catalog.dart';
import 'package:blindbox_app/main.dart';
import 'package:blindbox_app/shared/widgets/collectible_sheet_chrome.dart';
import 'package:blindbox_app/shared/widgets/shelfy_progress_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:shared_preferences/shared_preferences.dart';

final class _FixedNotifier extends CollectionNotifier {
  _FixedNotifier(this._snap);
  CollectionSnapshot _snap;

  @override
  CollectionSnapshot build() => _snap;

  void replaceForTest(CollectionSnapshot next) {
    _snap = next;
    state = next;
  }
}

CollectionSnapshot _populatedSnap() {
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

CollectionSnapshot _wishlistOnlySnap() {
  return CollectionSnapshot(
    shelfSeries: const [],
    figureStates: const {},
    seriesWishlist: [
      WishlistedCatalogSeries(
        catalogSeriesId: 'wish-1',
        name: 'Wish',
        brand: 'B',
        ipName: 'I',
        imageKey: 'k',
        addedAtMicros: 1,
      ),
    ],
  );
}

ShelfExportWriteResult _writtenZip(String path) {
  return ShelfExportWriteResult.written(
    zipPath: path,
    uncompressedBytes: 10,
    zipBytes: 1,
    mediaIncomplete: false,
    exceedsWarnThreshold: false,
    originalCount: 0,
    thumbCount: 0,
  );
}

List<Override> _appOverrides({CollectionNotifier Function()? notifier}) => [
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
      collectionNotifierProvider.overrideWith(
        notifier ?? () => _FixedNotifier(_populatedSnap()),
      ),
    ];

const Key _backupHostPageKey = Key('shelf_backup_host_page');

Future<void> _pumpBackupHost(
  WidgetTester tester, {
  required CollectionSnapshot snapshot,
  ShelfExportFlowDeps exportDeps = const ShelfExportFlowDeps(),
  ShelfImportFlowDeps importDeps = const ShelfImportFlowDeps(),
  Future<bool> Function(String humanSize)? confirmLarge,
  Future<bool> Function(ShelfImportBackupSummary summary)? confirmReplace,
  _FixedNotifier? notifierOut,
}) async {
  final notifier = notifierOut ?? _FixedNotifier(snapshot);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        collectionNotifierProvider.overrideWith(() => notifier),
      ],
      child: MaterialApp(
        home: Scaffold(
          key: _backupHostPageKey,
          appBar: AppBar(
            actions: [
              ShelfBackupButton(
                exportDeps: exportDeps,
                importDeps: importDeps,
                confirmLargeBackupOverride: confirmLarge,
                confirmReplaceOverride: confirmReplace,
              ),
            ],
          ),
          body: const SizedBox.expand(),
        ),
      ),
    ),
  );
}

NavigatorState _rootNavigator(WidgetTester tester) {
  return tester.state<NavigatorState>(find.byType(Navigator).first);
}

Future<void> _expectProgressBlocksPop(
  WidgetTester tester, {
  required String expectedLabel,
}) async {
  expect(find.byKey(const Key('shelf_backup_progress_label')), findsOneWidget);
  expect(find.text(expectedLabel), findsOneWidget);
  expect(find.byKey(_backupHostPageKey), findsOneWidget);

  final handled = await tester.binding.handlePopRoute();
  await tester.pump();

  expect(handled, isTrue);
  expect(find.byKey(const Key('shelf_backup_progress_label')), findsOneWidget);
  expect(find.text(expectedLabel), findsOneWidget);
  expect(find.byKey(_backupHostPageKey), findsOneWidget);
}

final List<Directory> _ownedStagingDirs = [];

Directory _ownedStagingDir() {
  final dir = Directory.systemTemp.createTempSync('shelfy_staging_');
  _ownedStagingDirs.add(dir);
  return dir;
}

void _deleteOwnedStagingDirs() {
  for (final dir in _ownedStagingDirs) {
    if (!dir.existsSync()) continue;
    try {
      dir.deleteSync(recursive: true);
    } on Object {
      // ignore
    }
  }
  _ownedStagingDirs.clear();
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
    _deleteOwnedStagingDirs();
  });

  testWidgets('AppBar backup icon opens sheet with English rows and icons',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: _appOverrides(),
        child: const BlindboxApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byKey(const Key('collection_backup_button')), findsOneWidget);
    expect(find.byTooltip('Shelf backup'), findsOneWidget);

    await tester.tap(find.byKey(const Key('collection_backup_button')));
    await tester.pumpAndSettle();

    expect(find.text(ShelfBackupCopy.sheetTitle), findsOneWidget);
    expect(find.text(ShelfBackupCopy.exportTitle), findsOneWidget);
    expect(find.text(ShelfBackupCopy.exportSubtitle), findsOneWidget);
    expect(find.text(ShelfBackupCopy.importTitle), findsOneWidget);
    expect(find.text(ShelfBackupCopy.importSubtitle), findsOneWidget);
    expect(find.byIcon(Symbols.upload_rounded), findsOneWidget);
    expect(find.byIcon(Symbols.download_rounded), findsOneWidget);
    expect(find.byType(CollectibleSheetDragHandle), findsOneWidget);
  });

  testWidgets('settings route removed; Insights segment still opens',
      (tester) async {
    bool hasSettingsRoute = false;
    void walk(List<RouteBase> routes) {
      for (final route in routes) {
        if (route is GoRoute) {
          if (route.path == 'settings' || route.path == '/collection/settings') {
            hasSettingsRoute = true;
          }
          walk(route.routes);
        } else if (route is ShellRoute) {
          walk(route.routes);
        } else if (route is StatefulShellRoute) {
          for (final branch in route.branches) {
            walk(branch.routes);
          }
        }
      }
    }

    walk(appRouter.configuration.routes);
    expect(hasSettingsRoute, isFalse);

    await tester.pumpWidget(
      ProviderScope(
        overrides: _appOverrides(),
        child: const BlindboxApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('collection_backup_button')), findsOneWidget);

    final insightsTab = find.text('Insights');
    expect(insightsTab, findsOneWidget);
    await tester.tap(insightsTab);
    await tester.pumpAndSettle();
    // Insights segment remains reachable (reveal menu lives on this tab).
    expect(find.text('Insights'), findsWidgets);
  });

  testWidgets('Export closes sheet, shows progress, then shares', (tester) async {
    var exportCalls = 0;
    var shareCalls = 0;
    final temp = Directory.systemTemp.createTempSync('backup_export_');
    addTearDown(() {
      if (temp.existsSync()) temp.deleteSync(recursive: true);
    });
    final zip = File('${temp.path}${Platform.pathSeparator}bak.zip')
      ..writeAsBytesSync([1], flush: true);

    final exportGate = Completer<ShelfExportWriteResult>();
    await _pumpBackupHost(
      tester,
      snapshot: _populatedSnap(),
      exportDeps: ShelfExportFlowDeps(
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
          return exportGate.future;
        },
        shareZip: (_) async {
          shareCalls++;
          return null;
        },
      ),
    );

    await tester.tap(find.byKey(const Key('collection_backup_button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('shelf_backup_sheet')), findsOneWidget);

    await tester.tap(find.byKey(const Key('shelf_backup_export_row')));
    // Avoid pumpAndSettle — indeterminate progress never settles.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text(ShelfBackupCopy.preparing), findsOneWidget);
    expect(find.byKey(const Key('shelf_backup_progress_label')), findsOneWidget);
    expect(find.byKey(const Key('shelf_backup_sheet')), findsNothing);

    exportGate.complete(_writtenZip(zip.path));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(exportCalls, 1);
    expect(shareCalls, 1);
    expect(find.byKey(const Key('shelf_backup_progress_label')), findsNothing);
    expect(_rootNavigator(tester).canPop(), isFalse);
    expect(find.text('Backup ready to share.'), findsOneWidget);
    expect(find.text(ShelfBackupCopy.exportReadySnack), findsOneWidget);
    expect(find.text(ShelfBackupCopy.exportMediaIncomplete), findsNothing);
    expect(find.text(ShelfBackupCopy.exportFailed), findsNothing);
  });

  testWidgets('Large backup Continue is FilledButton and resumes export',
      (tester) async {
    const estimatedBytes = 250 * 1024 * 1024;
    ShelfExportArchive.testWarnBytesOverride = 100 * 1024 * 1024;
    addTearDown(() {
      ShelfExportArchive.testWarnBytesOverride = null;
    });
    final temp = Directory.systemTemp.createTempSync('backup_large_cont_');
    addTearDown(() {
      if (temp.existsSync()) temp.deleteSync(recursive: true);
    });
    final zip = File('${temp.path}${Platform.pathSeparator}bak.zip')
      ..writeAsBytesSync([1], flush: true);
    var exportCalls = 0;

    await _pumpBackupHost(
      tester,
      snapshot: _populatedSnap(),
      exportDeps: ShelfExportFlowDeps(
        cleanupStale: () async {},
        loadMemoryJson: () async => '{}',
        loadUiPrefsJson: () async => '{}',
        estimate: ({
          required snapshot,
          required memoryJson,
          required uiPrefsJson,
        }) async =>
            const ShelfExportSizeEstimate(
              uncompressedBytes: estimatedBytes,
              mediaIncomplete: false,
            ),
        export: ({
          required snapshot,
          required memoryJson,
          required uiPrefsJson,
          onProgress,
        }) async {
          exportCalls++;
          return _writtenZip(zip.path);
        },
        shareZip: (_) async => null,
      ),
    );

    await tester.tap(find.byKey(const Key('collection_backup_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('shelf_backup_export_row')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(FilledButton), findsOneWidget);
    expect(
      find.widgetWithText(FilledButton, ShelfBackupCopy.largeBackupContinue),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(TextButton, ShelfBackupCopy.largeBackupCancel),
      findsOneWidget,
    );

    await tester.tap(find.text(ShelfBackupCopy.largeBackupContinue));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(exportCalls, 1);
    expect(find.text(ShelfBackupCopy.exportReadySnack), findsOneWidget);
  });

  testWidgets('Large backup Cancel skips export', (tester) async {
    const estimatedBytes = 250 * 1024 * 1024;
    ShelfExportArchive.testWarnBytesOverride = 100 * 1024 * 1024;
    addTearDown(() {
      ShelfExportArchive.testWarnBytesOverride = null;
    });

    await _pumpBackupHost(
      tester,
      snapshot: _populatedSnap(),
      exportDeps: ShelfExportFlowDeps(
        cleanupStale: () async {},
        loadMemoryJson: () async => '{}',
        loadUiPrefsJson: () async => '{}',
        estimate: ({
          required snapshot,
          required memoryJson,
          required uiPrefsJson,
        }) async =>
            const ShelfExportSizeEstimate(
              uncompressedBytes: estimatedBytes,
              mediaIncomplete: false,
            ),
        export: ({
          required snapshot,
          required memoryJson,
          required uiPrefsJson,
          onProgress,
        }) async {
          fail('Cancel must skip export');
        },
        shareZip: (_) async => fail('Cancel must skip share'),
      ),
    );

    await tester.tap(find.byKey(const Key('collection_backup_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('shelf_backup_export_row')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text(ShelfBackupCopy.largeBackupTitle), findsOneWidget);
    expect(find.text(ShelfBackupCopy.largeBackupBody('250 MB')), findsOneWidget);

    await tester.tap(find.text(ShelfBackupCopy.largeBackupCancel));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text(ShelfBackupCopy.exportReadySnack), findsNothing);
  });

  testWidgets('Export mediaIncomplete shows missing-photos SnackBar only',
      (tester) async {
    final temp = Directory.systemTemp.createTempSync('backup_export_inc_');
    addTearDown(() {
      if (temp.existsSync()) temp.deleteSync(recursive: true);
    });
    final zip = File('${temp.path}${Platform.pathSeparator}bak.zip')
      ..writeAsBytesSync([1], flush: true);

    await _pumpBackupHost(
      tester,
      snapshot: _populatedSnap(),
      exportDeps: ShelfExportFlowDeps(
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
        }) async {
          return ShelfExportWriteResult.written(
            zipPath: zip.path,
            uncompressedBytes: 10,
            zipBytes: 1,
            mediaIncomplete: true,
            exceedsWarnThreshold: false,
            originalCount: 0,
            thumbCount: 0,
          );
        },
        shareZip: (_) async => null,
      ),
    );

    await tester.tap(find.byKey(const Key('collection_backup_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('shelf_backup_export_row')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text(ShelfBackupCopy.exportMediaIncomplete), findsOneWidget);
    expect(find.text(ShelfBackupCopy.exportReadySnack), findsNothing);
    expect(find.text(ShelfBackupCopy.exportRestoredThumbSnack), findsNothing);
  });

  testWidgets('Export restoredThumb SnackBar uses low-res copy copy',
      (tester) async {
    final temp = Directory.systemTemp.createTempSync('backup_export_rt_');
    addTearDown(() {
      if (temp.existsSync()) temp.deleteSync(recursive: true);
    });
    final zip = File('${temp.path}${Platform.pathSeparator}bak.zip')
      ..writeAsBytesSync([1], flush: true);

    await _pumpBackupHost(
      tester,
      snapshot: _populatedSnap(),
      exportDeps: ShelfExportFlowDeps(
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
          return ShelfExportWriteResult.written(
            zipPath: zip.path,
            uncompressedBytes: 10,
            zipBytes: 1,
            mediaIncomplete: false,
            hasRestoredThumb: true,
            exceedsWarnThreshold: false,
            originalCount: 0,
            thumbCount: 0,
          );
        },
        shareZip: (_) async => null,
      ),
    );

    await tester.tap(find.byKey(const Key('collection_backup_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('shelf_backup_export_row')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text(ShelfBackupCopy.exportRestoredThumbSnack), findsOneWidget);
    expect(find.text(ShelfBackupCopy.exportReadySnack), findsNothing);
  });

  testWidgets('Export merges missing + restoredThumb into one SnackBar',
      (tester) async {
    final temp = Directory.systemTemp.createTempSync('backup_export_merge_');
    addTearDown(() {
      if (temp.existsSync()) temp.deleteSync(recursive: true);
    });
    final zip = File('${temp.path}${Platform.pathSeparator}bak.zip')
      ..writeAsBytesSync([1], flush: true);

    await _pumpBackupHost(
      tester,
      snapshot: _populatedSnap(),
      exportDeps: ShelfExportFlowDeps(
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
        }) async {
          return ShelfExportWriteResult.written(
            zipPath: zip.path,
            uncompressedBytes: 10,
            zipBytes: 1,
            mediaIncomplete: true,
            hasRestoredThumb: true,
            exceedsWarnThreshold: false,
            originalCount: 0,
            thumbCount: 0,
          );
        },
        shareZip: (_) async => null,
      ),
    );

    await tester.tap(find.byKey(const Key('collection_backup_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('shelf_backup_export_row')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.text(ShelfBackupCopy.exportMediaIncompleteWithRestoredThumb),
      findsOneWidget,
    );
    expect(find.text(ShelfBackupCopy.exportMediaIncomplete), findsNothing);
    expect(find.text(ShelfBackupCopy.exportRestoredThumbSnack), findsNothing);
  });

  testWidgets('Export failed shows failure SnackBar without ready SnackBar',
      (tester) async {
    await _pumpBackupHost(
      tester,
      snapshot: _populatedSnap(),
      exportDeps: ShelfExportFlowDeps(
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
          throw StateError('export boom');
        },
        shareZip: (_) async => fail('must not share'),
      ),
    );

    await tester.tap(find.byKey(const Key('collection_backup_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('shelf_backup_export_row')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text(ShelfBackupCopy.exportFailed), findsOneWidget);
    expect(find.text(ShelfBackupCopy.exportReadySnack), findsNothing);
  });

  testWidgets('empty shelf disables Export and does not share', (tester) async {
    var shareCalls = 0;
    var exportCalls = 0;
    await _pumpBackupHost(
      tester,
      snapshot: CollectionSnapshot.emptyTest(),
      exportDeps: ShelfExportFlowDeps(
        cleanupStale: () async {},
        loadMemoryJson: () async => '{}',
        loadUiPrefsJson: () async => '{}',
        export: ({
          required snapshot,
          required memoryJson,
          required uiPrefsJson,
          onProgress,
        }) async {
          exportCalls++;
          fail('must not export');
        },
        shareZip: (_) async {
          shareCalls++;
          return null;
        },
      ),
    );

    await tester.tap(find.byKey(const Key('collection_backup_button')));
    await tester.pumpAndSettle();
    expect(find.text(ShelfBackupCopy.exportDisabledSubtitle), findsOneWidget);

    await tester.tap(find.byKey(const Key('shelf_backup_export_row')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const Key('shelf_backup_sheet')), findsOneWidget);
    expect(find.text(ShelfBackupCopy.preparing), findsNothing);
    expect(exportCalls, 0);
    expect(shareCalls, 0);
  });

  testWidgets('wishlist-only shelf enables Export', (tester) async {
    await _pumpBackupHost(
      tester,
      snapshot: _wishlistOnlySnap(),
      exportDeps: const ShelfExportFlowDeps(
        cleanupStale: _noop,
        loadMemoryJson: _emptyJson,
        loadUiPrefsJson: _emptyJson,
      ),
    );
    await tester.tap(find.byKey(const Key('collection_backup_button')));
    await tester.pumpAndSettle();
    expect(find.text(ShelfBackupCopy.exportSubtitle), findsOneWidget);
    expect(find.text(ShelfBackupCopy.exportDisabledSubtitle), findsNothing);
  });

  testWidgets('Import pick cancel leaves no progress residue', (tester) async {
    await _pumpBackupHost(
      tester,
      snapshot: _populatedSnap(),
      importDeps: ShelfImportFlowDeps(
        pickZipPath: () async => null,
        unpack: (_) async => fail('no'),
        clearPickerTemp: () async {},
      ),
    );

    await tester.tap(find.byKey(const Key('collection_backup_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('shelf_backup_import_row')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const Key('shelf_backup_progress_label')), findsNothing);
    expect(find.text(ShelfBackupCopy.checking), findsNothing);
    expect(find.text(ShelfImportCopy.successSnack), findsNothing);
  });

  testWidgets('non-zip pick shows choose-zip SnackBar without Checking',
      (tester) async {
    var unpackCalls = 0;
    await _pumpBackupHost(
      tester,
      snapshot: _populatedSnap(),
      importDeps: ShelfImportFlowDeps(
        pickBackupFile: () async => const ShelfImportPickedFile(
          path: '/tmp/notes.pdf',
          name: 'notes.pdf',
        ),
        unpack: (_) async {
          unpackCalls++;
          fail('should not unpack');
        },
        clearPickerTemp: () async {},
      ),
    );

    await tester.tap(find.byKey(const Key('collection_backup_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('shelf_backup_import_row')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text(ShelfImportCopy.chooseZipSnack), findsOneWidget);
    expect(find.text(ShelfBackupCopy.checking), findsNothing);
    expect(find.byKey(const Key('shelf_backup_progress_label')), findsNothing);
    expect(unpackCalls, 0);
  });

  testWidgets('Import success SnackBar is English', (tester) async {
    final staging = _FakeStaging(snapshot: _populatedSnap());

    await _pumpBackupHost(
      tester,
      snapshot: CollectionSnapshot.emptyTest(),
      confirmReplace: (_) async => true,
      importDeps: ShelfImportFlowDeps(
        pickZipPath: () async => 'ok.zip',
        unpack: (_) async => staging,
        writeSafetyZip: ({
          required snapshot,
          required memoryJson,
          required uiPrefsJson,
        }) async {},
        commitStaging: (_) async => _populatedSnap(),
        clearPickerTemp: () async {},
        collectGarbage: (_) async {},
        scheduleRecoveryPack: (_) {},
      ),
    );

    await tester.tap(find.byKey(const Key('collection_backup_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('shelf_backup_import_row')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Shelf imported.'), findsOneWidget);
    expect(find.text(ShelfImportCopy.successSnack), findsOneWidget);
  });

  testWidgets('Import pickBackupFile reaches Checking', (tester) async {
    final unpackGate = Completer<ShelfExportStaging>();
    addTearDown(() {
      if (!unpackGate.isCompleted) {
        unpackGate.complete(_FakeStaging(snapshot: _populatedSnap()));
      }
    });

    await _pumpBackupHost(
      tester,
      snapshot: CollectionSnapshot.emptyTest(),
      confirmReplace: (_) async => false,
      importDeps: ShelfImportFlowDeps(
        pickBackupFile: () async => const ShelfImportPickedFile(
          path: '/cache/content.tmp',
          name: 'backup.zip',
        ),
        unpack: (_) => unpackGate.future,
        clearPickerTemp: () async {},
      ),
    );

    await tester.tap(find.byKey(const Key('collection_backup_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('shelf_backup_import_row')));
    await tester.pump();
    await tester.pump();

    expect(find.text(ShelfBackupCopy.checking), findsOneWidget);

    unpackGate.complete(_FakeStaging(snapshot: _populatedSnap()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  });

  testWidgets('Import pickZipPath reaches Checking', (tester) async {
    final unpackGate = Completer<ShelfExportStaging>();
    addTearDown(() {
      if (!unpackGate.isCompleted) {
        unpackGate.complete(_FakeStaging(snapshot: _populatedSnap()));
      }
    });

    await _pumpBackupHost(
      tester,
      snapshot: CollectionSnapshot.emptyTest(),
      confirmReplace: (_) async => false,
      importDeps: ShelfImportFlowDeps(
        pickZipPath: () async => 'from_zip_path.zip',
        unpack: (_) => unpackGate.future,
        clearPickerTemp: () async {},
      ),
    );

    await tester.tap(find.byKey(const Key('collection_backup_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('shelf_backup_import_row')));
    await tester.pump();
    await tester.pump();

    expect(find.text(ShelfBackupCopy.checking), findsOneWidget);

    unpackGate.complete(_FakeStaging(snapshot: _populatedSnap()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  });

  testWidgets('Import failure SnackBar is English without confirm',
      (tester) async {
    await _pumpBackupHost(
      tester,
      snapshot: CollectionSnapshot.emptyTest(),
      confirmReplace: (_) async => true,
      importDeps: ShelfImportFlowDeps(
        pickZipPath: () async => 'bad.zip',
        unpack: (_) async {
          throw ShelfExportException('bad');
        },
        clearPickerTemp: () async {},
      ),
    );
    await tester.tap(find.byKey(const Key('collection_backup_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('shelf_backup_import_row')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text(ShelfImportCopy.failedSnack), findsOneWidget);
    expect(find.text(ShelfImportCopy.confirmTitle), findsNothing);
  });

  testWidgets('after successful import Export becomes enabled', (tester) async {
    final notifier = _FixedNotifier(CollectionSnapshot.emptyTest());
    final staging = _FakeStaging(snapshot: _populatedSnap());

    await _pumpBackupHost(
      tester,
      snapshot: CollectionSnapshot.emptyTest(),
      notifierOut: notifier,
      confirmReplace: (_) async => true,
      importDeps: ShelfImportFlowDeps(
        pickZipPath: () async => 'ok.zip',
        unpack: (_) async => staging,
        writeSafetyZip: ({
          required snapshot,
          required memoryJson,
          required uiPrefsJson,
        }) async {},
        commitStaging: (_) async => _populatedSnap(),
        clearPickerTemp: () async {},
        collectGarbage: (_) async {},
        scheduleRecoveryPack: (_) {},
      ),
    );

    await tester.tap(find.byKey(const Key('collection_backup_button')));
    await tester.pumpAndSettle();
    expect(find.text(ShelfBackupCopy.exportDisabledSubtitle), findsOneWidget);
    await tester.tap(find.byKey(const Key('shelf_backup_import_row')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text(ShelfImportCopy.successSnack), findsOneWidget);

    // Ensure sheet sees the post-import snapshot (replaceStateFromImport).
    if (notifier.state.isEmptyShelf) {
      notifier.replaceForTest(_populatedSnap());
    }

    await tester.tap(find.byKey(const Key('collection_backup_button')));
    await tester.pumpAndSettle();
    expect(find.text(ShelfBackupCopy.exportSubtitle), findsOneWidget);
    expect(find.text(ShelfBackupCopy.exportDisabledSubtitle), findsNothing);
  });

  testWidgets('Replace confirm dialog shows new body without restore language',
      (tester) async {
    final staging = _FakeStaging(
      snapshot: _populatedSnap(),
      createdAt: DateTime.utc(2026, 6, 15, 12),
    );

    // No confirmReplaceOverride — drive the real AlertDialog.
    await _pumpBackupHost(
      tester,
      snapshot: CollectionSnapshot.emptyTest(),
      importDeps: ShelfImportFlowDeps(
        pickZipPath: () async => 'confirm.zip',
        unpack: (_) async => staging,
        clearPickerTemp: () async {},
      ),
    );

    await tester.tap(find.byKey(const Key('collection_backup_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('shelf_backup_import_row')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text(ShelfImportCopy.confirmTitle), findsOneWidget);
    expect(find.text(ShelfImportCopy.confirmCancel), findsOneWidget);
    expect(find.text(ShelfImportCopy.confirmReplace), findsOneWidget);

    // Body paragraphs are concatenated into one content Text with the summary.
    expect(find.textContaining(ShelfImportCopy.confirmBody), findsOneWidget);
    expect(
      find.textContaining(ShelfImportCopy.confirmSafetyNote),
      findsOneWidget,
    );

    final dialogText = tester
        .widgetList<Text>(find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(Text),
        ))
        .map((t) => t.data ?? '')
        .join('\n');
    expect(dialogText, contains(ShelfImportCopy.confirmBody));
    expect(dialogText, contains(ShelfImportCopy.confirmSafetyNote));
    expect(dialogText.toLowerCase(), isNot(contains('restore')));
    expect(dialogText, isNot(contains("can't be restored")));
    expect(
      dialogText,
      isNot(contains('This replaces your current collection with the backup.')),
    );
    // Summary line still present (W=0 omit wishlist for this populated snap).
    expect(dialogText, contains('This backup has'));
    expect(dialogText, contains('created'));

    final replaceButton = tester.widget<FilledButton>(
      find.byKey(const Key('collection_backup_import_confirm')),
    );
    expect(replaceButton.style?.backgroundColor, isNull);

    await tester.tap(find.byKey(const Key('collection_backup_import_cancel')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text(ShelfImportCopy.confirmTitle), findsNothing);
  });

  testWidgets('confirm summary includes wishlist counts with plural forms',
      (tester) async {
    final withWish = CollectionSnapshot(
      shelfSeries: [
        ShelfSeries(
          id: 's1',
          name: 'A',
          brand: 'B',
          ipName: 'I',
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
      ],
      figureStates: const {},
      seriesWishlist: [
        WishlistedCatalogSeries(
          catalogSeriesId: 'w1',
          name: 'Wish',
          brand: 'B',
          ipName: 'I',
          imageKey: 'k',
          addedAtMicros: 1,
        ),
      ],
    );
    final staging = _FakeStaging(
      snapshot: withWish,
      createdAt: DateTime.utc(2026, 6, 15, 12),
    );
    ShelfImportBackupSummary? seen;
    await _pumpBackupHost(
      tester,
      snapshot: CollectionSnapshot.emptyTest(),
      confirmReplace: (summary) async {
        seen = summary;
        return false;
      },
      importDeps: ShelfImportFlowDeps(
        pickZipPath: () async => 'x.zip',
        unpack: (_) async => staging,
        clearPickerTemp: () async {},
      ),
    );

    await tester.tap(find.byKey(const Key('collection_backup_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('shelf_backup_import_row')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(seen, isNotNull);
    expect(seen!.seriesCount, 1);
    expect(seen!.figureCount, 1);
    expect(seen!.wishlistCount, 1);
    expect(
      ShelfImportCopy.confirmSummary(
        seriesCount: seen!.seriesCount,
        figureCount: seen!.figureCount,
        wishlistCount: seen!.wishlistCount,
        createdDate: ShelfImportCopy.formatCreatedDate(seen!.createdAt),
      ),
      contains('1 wishlist item'),
    );
    expect(
      ShelfImportCopy.confirmSummary(
        seriesCount: 2,
        figureCount: 2,
        wishlistCount: 2,
        createdDate: 'Jun 15, 2026',
      ),
      contains('2 wishlist items'),
    );
  });

  testWidgets('Preparing progress dialog consumes system back', (tester) async {
    final exportGate = Completer<ShelfExportWriteResult>();
    final temp = Directory.systemTemp.createTempSync('backup_pop_prep_');
    final zipPath = '${temp.path}${Platform.pathSeparator}z.zip';
    File(zipPath).writeAsBytesSync([1]);
    addTearDown(() {
      if (temp.existsSync()) temp.deleteSync(recursive: true);
      if (!exportGate.isCompleted) {
        exportGate.complete(_writtenZip(zipPath));
      }
    });

    await _pumpBackupHost(
      tester,
      snapshot: _populatedSnap(),
      exportDeps: ShelfExportFlowDeps(
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
        }) =>
            exportGate.future,
        shareZip: (_) async => null,
      ),
    );

    final nav = _rootNavigator(tester);
    expect(nav.canPop(), isFalse);

    await tester.tap(find.byKey(const Key('collection_backup_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('shelf_backup_export_row')));
    await tester.pump();
    await tester.pump();

    await _expectProgressBlocksPop(
      tester,
      expectedLabel: ShelfBackupCopy.preparing,
    );

    exportGate.complete(_writtenZip(zipPath));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byKey(const Key('shelf_backup_progress_label')), findsNothing);
    expect(find.byKey(_backupHostPageKey), findsOneWidget);
    expect(nav.canPop(), isFalse);
  });

  testWidgets('Checking progress dialog consumes system back', (tester) async {
    final unpackGate = Completer<ShelfExportStaging>();
    addTearDown(() {
      if (!unpackGate.isCompleted) {
        unpackGate.complete(_FakeStaging(snapshot: _populatedSnap()));
      }
    });

    await _pumpBackupHost(
      tester,
      snapshot: CollectionSnapshot.emptyTest(),
      confirmReplace: (_) async => false,
      importDeps: ShelfImportFlowDeps(
        pickZipPath: () async => 'checking.zip',
        unpack: (_) => unpackGate.future,
        clearPickerTemp: () async {},
      ),
    );

    final nav = _rootNavigator(tester);
    expect(nav.canPop(), isFalse);

    await tester.tap(find.byKey(const Key('collection_backup_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('shelf_backup_import_row')));
    await tester.pump();
    await tester.pump();

    expect(find.byType(ShelfyProgressDialogContent), findsOneWidget);
    await _expectProgressBlocksPop(
      tester,
      expectedLabel: ShelfBackupCopy.checking,
    );

    unpackGate.complete(_FakeStaging(snapshot: _populatedSnap()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byKey(const Key('shelf_backup_progress_label')), findsNothing);
    expect(find.byKey(_backupHostPageKey), findsOneWidget);
    expect(nav.canPop(), isFalse);
  });

  testWidgets('Importing progress dialog consumes system back', (tester) async {
    final commitGate = Completer<CollectionSnapshot>();
    addTearDown(() {
      if (!commitGate.isCompleted) {
        commitGate.complete(_populatedSnap());
      }
    });

    await _pumpBackupHost(
      tester,
      snapshot: CollectionSnapshot.emptyTest(),
      confirmReplace: (_) async => true,
      importDeps: ShelfImportFlowDeps(
        pickZipPath: () async => 'importing.zip',
        unpack: (_) async => _FakeStaging(snapshot: _populatedSnap()),
        writeSafetyZip: ({
          required snapshot,
          required memoryJson,
          required uiPrefsJson,
        }) async {},
        commitStaging: (_) => commitGate.future,
        clearPickerTemp: () async {},
        collectGarbage: (_) async {},
        scheduleRecoveryPack: (_) {},
      ),
    );

    final nav = _rootNavigator(tester);
    expect(nav.canPop(), isFalse);

    await tester.tap(find.byKey(const Key('collection_backup_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('shelf_backup_import_row')));
    // pick → Checking → unpack → hide → confirm → Importing → gated commit
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 20));
      if (find.text(ShelfBackupCopy.importing).evaluate().isNotEmpty) break;
    }

    await _expectProgressBlocksPop(
      tester,
      expectedLabel: ShelfBackupCopy.importing,
    );

    commitGate.complete(_populatedSnap());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byKey(const Key('shelf_backup_progress_label')), findsNothing);
    expect(find.byKey(_backupHostPageKey), findsOneWidget);
    expect(nav.canPop(), isFalse);
  });

  testWidgets('Replace Cancel leaves no residual progress dialog', (tester) async {
    await _pumpBackupHost(
      tester,
      snapshot: CollectionSnapshot.emptyTest(),
      confirmReplace: (_) async => false,
      importDeps: ShelfImportFlowDeps(
        pickZipPath: () async => 'cancel.zip',
        unpack: (_) async => _FakeStaging(snapshot: _populatedSnap()),
        clearPickerTemp: () async {},
      ),
    );

    final nav = _rootNavigator(tester);
    expect(nav.canPop(), isFalse);

    await tester.tap(find.byKey(const Key('collection_backup_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('shelf_backup_import_row')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byKey(const Key('shelf_backup_progress_label')), findsNothing);
    expect(find.text(ShelfBackupCopy.checking), findsNothing);
    expect(find.text(ShelfBackupCopy.importing), findsNothing);
    expect(find.byKey(_backupHostPageKey), findsOneWidget);
    expect(nav.canPop(), isFalse);
  });

  testWidgets('busy blocks starting a second flow from the icon', (tester) async {
    final exportGate = Completer<ShelfExportWriteResult>();
    var exportCalls = 0;
    final temp = Directory.systemTemp.createTempSync('backup_busy_');
    final zipPath = '${temp.path}${Platform.pathSeparator}z.zip';
    File(zipPath).writeAsBytesSync([1]);
    addTearDown(() {
      if (temp.existsSync()) temp.deleteSync(recursive: true);
      if (!exportGate.isCompleted) {
        exportGate.complete(_writtenZip(zipPath));
      }
    });

    await _pumpBackupHost(
      tester,
      snapshot: _populatedSnap(),
      exportDeps: ShelfExportFlowDeps(
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
          return exportGate.future;
        },
        shareZip: (_) async => null,
      ),
    );

    await tester.tap(find.byKey(const Key('collection_backup_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('shelf_backup_export_row')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(exportCalls, 1);
    expect(find.byKey(const Key('shelf_backup_progress_label')), findsOneWidget);

    final button = tester.widget<IconButton>(
      find.byKey(const Key('collection_backup_button')),
    );
    expect(button.onPressed, isNull);
    expect(exportCalls, 1);

    exportGate.complete(_writtenZip(zipPath));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  });

  test('backup copy strings are English', () {
    final all = [
      ShelfBackupCopy.sheetTitle,
      ShelfBackupCopy.exportTitle,
      ShelfBackupCopy.exportSubtitle,
      ShelfBackupCopy.exportDisabledSubtitle,
      ShelfBackupCopy.importTitle,
      ShelfBackupCopy.importSubtitle,
      ShelfBackupCopy.preparing,
      ShelfBackupCopy.checking,
      ShelfBackupCopy.importing,
      ShelfBackupCopy.exportMediaIncomplete,
      ShelfBackupCopy.exportReadySnack,
      ShelfBackupCopy.exportTooLarge,
      ShelfBackupCopy.exportFailed,
      ShelfBackupCopy.largeBackupTitle,
      ShelfBackupCopy.largeBackupBody('250 MB'),
      ShelfBackupCopy.largeBackupCancel,
      ShelfBackupCopy.largeBackupContinue,
    ].join();
    expect(RegExp(r'[\u4e00-\u9fff]').hasMatch(all), isFalse);
    expect(ShelfBackupCopy.exportReadySnack, 'Backup ready to share.');
    expect(
      ShelfBackupCopy.exportRestoredThumbSnack,
      'Backup ready to share. Some photos are low-resolution copies restored from Android backup.',
    );
    expect(
      ShelfBackupCopy.exportSuccessSnack(
        mediaIncomplete: true,
        hasRestoredThumb: true,
      ),
      ShelfBackupCopy.exportMediaIncompleteWithRestoredThumb,
    );
    expect(ShelfBackupCopy.largeBackupTitle, 'Large backup');
    expect(
      ShelfBackupCopy.largeBackupBody('250 MB'),
      'This backup is about 250 MB. Sharing it may take a while.',
    );
    expect(ShelfBackupCopy.largeBackupCancel, 'Cancel');
    expect(ShelfBackupCopy.largeBackupContinue, 'Continue');
  });
}

Future<void> _noop() async {}
Future<String> _emptyJson() async => '{}';

class _FakeStaging extends ShelfExportStaging {
  _FakeStaging({
    CollectionSnapshot? snapshot,
    DateTime? createdAt,
  }) : super(
          stagingDir: _ownedStagingDir(),
          manifest: ShelfExportManifest(
            kind: ShelfExportArchive.kind,
            schemaVersion: 1,
            createdAt: createdAt ?? DateTime.utc(2026, 1, 1),
            appVersion: '1',
            seriesCount: 0,
            figureCount: 0,
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

  @override
  Future<void> delete() async {}
}

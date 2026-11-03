import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/core/theme/app_spacing.dart';
import 'package:blindbox_app/core/theme/app_typography.dart';
import 'package:blindbox_app/core/theme/shelfy_symbols.dart';
import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/collection/application/collection_shelf_ui_prefs_provider.dart';
import 'package:blindbox_app/features/collection/application/shelf_export_flow.dart';
import 'package:blindbox_app/features/collection/application/shelf_import_flow.dart';
import 'package:blindbox_app/features/collection/data/collection_memory_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

/// Collection → Settings (`/collection/settings`). Export + Import (Replace).
class CollectionSettingsScreen extends ConsumerStatefulWidget {
  const CollectionSettingsScreen({
    super.key,
    this.flowDeps = const ShelfExportFlowDeps(),
    this.importDeps = const ShelfImportFlowDeps(),
    this.confirmLargeBackupOverride,
    this.confirmReplaceOverride,
  });

  static const routePath = '/collection/settings';

  /// Injectable export / share / estimate hooks for tests.
  @visibleForTesting
  final ShelfExportFlowDeps flowDeps;

  /// Injectable import hooks for tests.
  @visibleForTesting
  final ShelfImportFlowDeps importDeps;

  /// When set, skips the Large backup dialog (tests).
  @visibleForTesting
  final Future<bool> Function(String humanSize)? confirmLargeBackupOverride;

  /// When set, skips the Replace shelf dialog (tests).
  @visibleForTesting
  final Future<bool> Function()? confirmReplaceOverride;

  @override
  ConsumerState<CollectionSettingsScreen> createState() =>
      _CollectionSettingsScreenState();
}

class _CollectionSettingsScreenState
    extends ConsumerState<CollectionSettingsScreen> {
  bool _exporting = false;
  bool _importing = false;
  int _progressDone = 0;
  int _progressTotal = 0;
  String? _statusMessage;
  bool _statusIsError = false;

  bool get _busy => _exporting || _importing;

  Future<void> _onExportPressed() async {
    if (_busy) return;
    setState(() {
      _exporting = true;
      _progressDone = 0;
      _progressTotal = 0;
      _statusMessage = null;
      _statusIsError = false;
    });

    final snapshot = ref.read(collectionNotifierProvider);
    final uiPrefs = ref.read(collectionShelfUiPrefsProvider);
    final memoryJson = widget.flowDeps.loadMemoryJson != null
        ? await widget.flowDeps.loadMemoryJson!()
        : await CollectionMemoryStore.instance.encodeJson();
    final uiPrefsJson = widget.flowDeps.loadUiPrefsJson != null
        ? await widget.flowDeps.loadUiPrefsJson!()
        : CollectionShelfUiPrefsCodec.encode(uiPrefs);

    final result = await ShelfExportFlow.run(
      snapshot: snapshot,
      memoryJson: memoryJson,
      uiPrefsJson: uiPrefsJson,
      deps: widget.flowDeps,
      onProgress: (done, total) {
        if (!mounted) return;
        setState(() {
          _progressDone = done;
          _progressTotal = total;
        });
      },
      confirmLargeBackup: (humanSize) async {
        final override = widget.confirmLargeBackupOverride;
        if (override != null) return override(humanSize);
        if (!mounted) return false;
        final choice = await showDialog<bool>(
          context: context,
          builder: (ctx) {
            return AlertDialog(
              title: const Text('Large backup'),
              content: Text(
                'This backup is about $humanSize. Sharing it may take a while.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('Continue'),
                ),
              ],
            );
          },
        );
        return choice == true;
      },
    );

    if (!mounted) return;

    setState(() {
      _exporting = false;
      switch (result.status) {
        case ShelfExportFlowStatus.success:
          _statusIsError = false;
          _statusMessage = result.mediaIncomplete
              ? 'Some photos were missing and weren\'t included.'
              : null;
        case ShelfExportFlowStatus.cancelled:
          _statusMessage = null;
          _statusIsError = false;
        case ShelfExportFlowStatus.rejectedTooLarge:
          _statusIsError = true;
          _statusMessage =
              'This shelf is too large to export (over 2 GB).';
        case ShelfExportFlowStatus.failed:
          _statusIsError = true;
          _statusMessage = 'Couldn\'t create a backup. Try again.';
      }
    });
  }

  Future<bool> _confirmReplaceDialog() async {
    final override = widget.confirmReplaceOverride;
    if (override != null) return override();
    if (!mounted) return false;
    final choice = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;
        return AlertDialog(
          title: const Text(ShelfImportCopy.confirmTitle),
          content: const Text(
            '${ShelfImportCopy.confirmBody}\n\n'
            '${ShelfImportCopy.confirmSafetyNote}',
          ),
          actions: [
            TextButton(
              key: const Key('collection_settings_import_cancel'),
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text(ShelfImportCopy.confirmCancel),
            ),
            FilledButton(
              key: const Key('collection_settings_import_confirm'),
              style: FilledButton.styleFrom(
                backgroundColor: scheme.error,
                foregroundColor: scheme.onError,
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text(ShelfImportCopy.confirmReplace),
            ),
          ],
        );
      },
    );
    return choice == true;
  }

  Future<void> _onImportPressed() async {
    if (_busy) return;
    setState(() {
      _statusMessage = null;
      _statusIsError = false;
    });

    final snapshot = ref.read(collectionNotifierProvider);
    final uiPrefs = ref.read(collectionShelfUiPrefsProvider);
    final memoryJson = await CollectionMemoryStore.instance.encodeJson();
    final uiPrefsJson = CollectionShelfUiPrefsCodec.encode(uiPrefs);
    final notifier = ref.read(collectionNotifierProvider.notifier);
    final prefsNotifier = ref.read(collectionShelfUiPrefsProvider.notifier);

    final result = await ShelfImportFlow.run(
      currentSnapshot: snapshot,
      currentMemoryJson: memoryJson,
      currentUiPrefsJson: uiPrefsJson,
      suspendPersistence: notifier.suspendPersistenceForImport,
      replaceNotifierState: notifier.replaceStateFromImport,
      resumePersistence: notifier.resumePersistence,
      reloadUiPrefs: prefsNotifier.reloadFromStorage,
      deps: ShelfImportFlowDeps(
        // Pick → confirm → then show busy. Returning null = cancelled.
        pickZipPath: () async {
          final pick = widget.importDeps.pickZipPath;
          final resolved =
              pick != null ? await pick() : await ShelfImportFlow.pickZipPath();
          if (resolved == null || resolved.isEmpty) return null;
          final ok = await _confirmReplaceDialog();
          if (!ok) return null;
          if (mounted) {
            setState(() {
              _importing = true;
            });
          }
          return resolved;
        },
        confirmReplace: () async => true,
        unpack: widget.importDeps.unpack,
        writeSafetyZip: widget.importDeps.writeSafetyZip,
        commitStaging: widget.importDeps.commitStaging,
        clearPickerTemp: widget.importDeps.clearPickerTemp,
        collectGarbage: widget.importDeps.collectGarbage,
      ),
    );

    if (!mounted) return;

    setState(() {
      _importing = false;
    });

    final messenger = ScaffoldMessenger.of(context);
    switch (result.status) {
      case ShelfImportFlowStatus.success:
        messenger.showSnackBar(
          const SnackBar(content: Text(ShelfImportCopy.successSnack)),
        );
      case ShelfImportFlowStatus.cancelled:
        break;
      case ShelfImportFlowStatus.rejectedTooLarge:
        messenger.showSnackBar(
          const SnackBar(content: Text(ShelfImportCopy.tooLargeSnack)),
        );
      case ShelfImportFlowStatus.safetyCopyFailed:
        messenger.showSnackBar(
          const SnackBar(content: Text(ShelfImportCopy.safetyFailedSnack)),
        );
      case ShelfImportFlowStatus.failed:
        messenger.showSnackBar(
          const SnackBar(content: Text(ShelfImportCopy.failedSnack)),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            pinned: true,
            elevation: 0,
            scrolledUnderElevation: 0,
            toolbarHeight: FeedRhythm.mainTabAppBarToolbarHeight,
            backgroundColor: scheme.surface,
            centerTitle: false,
            titleSpacing: AppSpacing.pageHorizontal,
            leading: IconButton(
              key: const Key('collection_settings_back'),
              tooltip: 'Back',
              onPressed: _busy
                  ? null
                  : () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/collection');
                      }
                    },
              icon: Icon(
                Symbols.arrow_back_rounded,
                size: AppIconSizes.navigation,
                fill: ShelfySymbols.fillOutline,
                weight: ShelfySymbols.weight,
                grade: ShelfySymbols.grade,
                opticalSize: ShelfySymbols.opticalSize,
              ),
            ),
            title: Text(
              'Settings',
              style: AppTypography.tabTitle(textTheme, scheme),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pageHorizontal,
              FeedRhythm.belowMainTabAppBar,
              AppSpacing.pageHorizontal,
              32,
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Text(
                  'Shelf backup',
                  style: AppTypography.sectionLabel(textTheme, scheme),
                ),
                const SizedBox(height: 12),
                Material(
                  color: scheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(16),
                  child: Column(
                    children: [
                      InkWell(
                        key: const Key('collection_settings_export_tile'),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(16),
                        ),
                        onTap: _busy ? null : _onExportPressed,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                key: const Key(
                                  'collection_settings_export_button',
                                ),
                                'Export shelf',
                                style:
                                    AppTypography.cardTitle(textTheme, scheme)
                                        .copyWith(
                                  color: _busy
                                      ? scheme.onSurface.withValues(alpha: 0.38)
                                      : null,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Share a full backup with original photos',
                                style:
                                    AppTypography.cardMeta(textTheme, scheme),
                              ),
                              if (_exporting) ...[
                                const SizedBox(height: 12),
                                Text(
                                  key: const Key(
                                    'collection_settings_export_progress',
                                  ),
                                  _progressTotal <= 0
                                      ? 'Preparing backup…'
                                      : 'Preparing backup… $_progressDone / $_progressTotal',
                                  style: AppTypography.cardMeta(
                                    textTheme,
                                    scheme,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                LinearProgressIndicator(
                                  key: const Key(
                                    'collection_settings_export_bar',
                                  ),
                                  value: _progressTotal <= 0
                                      ? 0
                                      : (_progressDone / _progressTotal)
                                          .clamp(0.0, 1.0),
                                ),
                              ],
                              if (_statusMessage != null) ...[
                                const SizedBox(height: 12),
                                Text(
                                  key: const Key(
                                    'collection_settings_export_status',
                                  ),
                                  _statusMessage!,
                                  style: AppTypography.cardMeta(
                                    textTheme,
                                    scheme,
                                  ).copyWith(
                                    color: _statusIsError
                                        ? scheme.error
                                        : scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      Divider(
                        height: 1,
                        thickness: 1,
                        color: scheme.outlineVariant.withValues(alpha: 0.4),
                      ),
                      InkWell(
                        key: const Key('collection_settings_import_tile'),
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(16),
                        ),
                        onTap: _busy ? null : _onImportPressed,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                key: const Key(
                                  'collection_settings_import_button',
                                ),
                                ShelfImportCopy.importTitle,
                                style:
                                    AppTypography.cardTitle(textTheme, scheme)
                                        .copyWith(
                                  color: _busy
                                      ? scheme.onSurface.withValues(alpha: 0.38)
                                      : null,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                ShelfImportCopy.importSubtitle,
                                style:
                                    AppTypography.cardMeta(textTheme, scheme),
                              ),
                              if (_importing) ...[
                                const SizedBox(height: 12),
                                Text(
                                  key: const Key(
                                    'collection_settings_import_progress',
                                  ),
                                  ShelfImportCopy.importing,
                                  style: AppTypography.cardMeta(
                                    textTheme,
                                    scheme,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const LinearProgressIndicator(
                                  key: Key(
                                    'collection_settings_import_bar',
                                  ),
                                  value: 0,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:blindbox_app/core/layout/feed_rhythm.dart';
import 'package:blindbox_app/core/theme/app_spacing.dart';
import 'package:blindbox_app/core/theme/app_typography.dart';
import 'package:blindbox_app/core/theme/shelfy_symbols.dart';
import 'package:blindbox_app/features/collection/application/collection_notifier.dart';
import 'package:blindbox_app/features/collection/application/collection_shelf_ui_prefs_provider.dart';
import 'package:blindbox_app/features/collection/application/shelf_export_flow.dart';
import 'package:blindbox_app/features/collection/application/shelf_import_flow.dart';
import 'package:blindbox_app/features/collection/data/collection_memory_store.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:blindbox_app/features/collection/presentation/collection_modal_overlays.dart';
import 'package:blindbox_app/shared/widgets/collectible_bottom_sheet.dart';
import 'package:blindbox_app/shared/widgets/collectible_sheet_chrome.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

/// English copy for Collection → Shelf backup sheet / progress.
abstract final class ShelfBackupCopy {
  ShelfBackupCopy._();

  static const sheetTitle = 'Shelf backup';
  static const exportTitle = 'Export shelf';
  static const exportSubtitle = 'Share a full backup with original photos';
  static const exportDisabledSubtitle = 'Add a figure to back up your shelf';
  static const importTitle = ShelfImportCopy.importTitle;
  static const importSubtitle = ShelfImportCopy.importSubtitle;

  static const preparing = 'Preparing backup…';
  static const checking = ShelfImportCopy.checking;
  static const importing = ShelfImportCopy.importing;

  static const exportMediaIncomplete =
      'Some photos were missing and weren\'t included.';
  static const exportTooLarge =
      'This shelf is too large to export (over 2 GB).';
  static const exportFailed = 'Couldn\'t create a backup. Try again.';
}

enum _ShelfBackupSheetAction { export, import }

/// Collection AppBar backup action: sheet → progress dialog → export/import.
class ShelfBackupButton extends ConsumerStatefulWidget {
  const ShelfBackupButton({
    super.key,
    this.exportDeps = const ShelfExportFlowDeps(),
    this.importDeps = const ShelfImportFlowDeps(),
    this.confirmLargeBackupOverride,
    this.confirmReplaceOverride,
  });

  @visibleForTesting
  final ShelfExportFlowDeps exportDeps;

  @visibleForTesting
  final ShelfImportFlowDeps importDeps;

  @visibleForTesting
  final Future<bool> Function(String humanSize)? confirmLargeBackupOverride;

  @visibleForTesting
  final Future<bool> Function(ShelfImportBackupSummary summary)?
      confirmReplaceOverride;

  @override
  ConsumerState<ShelfBackupButton> createState() => _ShelfBackupButtonState();
}

class _ShelfBackupButtonState extends ConsumerState<ShelfBackupButton> {
  bool _busy = false;
  final ValueNotifier<String> _progressLabel =
      ValueNotifier<String>(ShelfBackupCopy.preparing);
  OverlayEntry? _progressEntry;

  @override
  void dispose() {
    _removeProgressEntry();
    _progressLabel.dispose();
    super.dispose();
  }

  Future<_ShelfBackupSheetAction?> _openSheet(CollectionSnapshot snapshot) {
    return showCollectionModalBottomSheet<_ShelfBackupSheetAction>(
      context: context,
      wrapContentHeight: true,
      builder: (ctx, scrollController) {
        return _ShelfBackupSheetBody(
          snapshot: snapshot,
          scrollController: scrollController,
        );
      },
    );
  }

  void _ensureProgress(String label) {
    _progressLabel.value = label;
    if (_progressEntry != null) return;
    final entry = OverlayEntry(
      builder: (ctx) {
        return PopScope(
          canPop: false,
          child: Stack(
            children: [
              ModalBarrier(
                dismissible: false,
                color: Theme.of(ctx).colorScheme.scrim.withValues(alpha: 0.32),
              ),
              Center(
                child: Material(
                  color: Theme.of(ctx).colorScheme.surfaceContainerHigh,
                  elevation: 6,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: ValueListenableBuilder<String>(
                      valueListenable: _progressLabel,
                      builder: (context, value, _) {
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(strokeWidth: 3),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Flexible(
                              child: Text(
                                key: const Key('shelf_backup_progress_label'),
                                value,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
    _progressEntry = entry;
    Overlay.of(context, rootOverlay: true).insert(entry);
  }

  void _removeProgressEntry() {
    _progressEntry?.remove();
    _progressEntry = null;
  }

  Future<void> _hideProgress() async {
    _removeProgressEntry();
    await Future<void>.delayed(Duration.zero);
  }

  Future<void> _onPressed() async {
    if (_busy) return;
    final snapshot = ref.read(collectionNotifierProvider);
    final action = await _openSheet(snapshot);
    if (!mounted || action == null) return;
    if (_busy) return;

    switch (action) {
      case _ShelfBackupSheetAction.export:
        await _runExport();
      case _ShelfBackupSheetAction.import:
        await _runImport();
    }
  }

  Future<void> _runExport() async {
    if (_busy) return;
    final snapshot = ref.read(collectionNotifierProvider);
    if (snapshot.isEmptyShelf) return;

    setState(() => _busy = true);
    _ensureProgress(ShelfBackupCopy.preparing);

    try {
      final uiPrefs = ref.read(collectionShelfUiPrefsProvider);
      final memoryJson = widget.exportDeps.loadMemoryJson != null
          ? await widget.exportDeps.loadMemoryJson!()
          : await CollectionMemoryStore.instance.encodeJson();
      final uiPrefsJson = widget.exportDeps.loadUiPrefsJson != null
          ? await widget.exportDeps.loadUiPrefsJson!()
          : CollectionShelfUiPrefsCodec.encode(uiPrefs);

      final result = await ShelfExportFlow.run(
        snapshot: snapshot,
        memoryJson: memoryJson,
        uiPrefsJson: uiPrefsJson,
        deps: widget.exportDeps,
        onProgress: (completed, total) {},
        confirmLargeBackup: (humanSize) async {
          await _hideProgress();
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
          if (choice == true && mounted) {
            _ensureProgress(ShelfBackupCopy.preparing);
          }
          return choice == true;
        },
      );

      await _hideProgress();
      if (!mounted) return;

      final messenger = ScaffoldMessenger.of(context);
      switch (result.status) {
        case ShelfExportFlowStatus.success:
          if (result.mediaIncomplete) {
            messenger.showSnackBar(
              const SnackBar(
                content: Text(ShelfBackupCopy.exportMediaIncomplete),
              ),
            );
          }
        case ShelfExportFlowStatus.cancelled:
          break;
        case ShelfExportFlowStatus.rejectedTooLarge:
          messenger.showSnackBar(
            const SnackBar(content: Text(ShelfBackupCopy.exportTooLarge)),
          );
        case ShelfExportFlowStatus.failed:
          messenger.showSnackBar(
            const SnackBar(content: Text(ShelfBackupCopy.exportFailed)),
          );
      }
    } finally {
      await _hideProgress();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _runImport() async {
    if (_busy) return;
    setState(() => _busy = true);

    try {
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
          pickZipPath: () async {
            final pick = widget.importDeps.pickZipPath;
            final resolved = pick != null
                ? await pick()
                : await ShelfImportFlow.pickZipPath();
            if (resolved == null || resolved.isEmpty) return null;
            if (mounted) _ensureProgress(ShelfBackupCopy.checking);
            return resolved;
          },
          confirmReplace: (summary) async {
            await _hideProgress();
            final override = widget.confirmReplaceOverride;
            final ok = override != null
                ? await override(summary)
                : await _confirmReplaceDialog(summary);
            if (ok && mounted) {
              _ensureProgress(ShelfBackupCopy.importing);
            }
            return ok;
          },
          unpack: widget.importDeps.unpack,
          writeSafetyZip: widget.importDeps.writeSafetyZip,
          commitStaging: widget.importDeps.commitStaging,
          clearPickerTemp: widget.importDeps.clearPickerTemp,
          collectGarbage: widget.importDeps.collectGarbage,
          scheduleRecoveryPack: widget.importDeps.scheduleRecoveryPack,
        ),
      );

      await _hideProgress();
      if (!mounted) return;

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
    } finally {
      await _hideProgress();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirmReplaceDialog(ShelfImportBackupSummary summary) async {
    if (!mounted) return false;
    final summaryLine = ShelfImportCopy.confirmSummary(
      seriesCount: summary.seriesCount,
      figureCount: summary.figureCount,
      wishlistCount: summary.wishlistCount,
      createdDate: ShelfImportCopy.formatCreatedDate(summary.createdAt),
    );
    final choice = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;
        return AlertDialog(
          title: const Text(ShelfImportCopy.confirmTitle),
          content: Text(
            '$summaryLine\n\n'
            '${ShelfImportCopy.confirmBody}\n\n'
            '${ShelfImportCopy.confirmSafetyNote}',
          ),
          actions: [
            TextButton(
              key: const Key('collection_backup_import_cancel'),
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text(ShelfImportCopy.confirmCancel),
            ),
            FilledButton(
              key: const Key('collection_backup_import_confirm'),
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

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: const Key('collection_backup_button'),
      tooltip: 'Backup',
      onPressed: _busy ? null : _onPressed,
      icon: Icon(
        Symbols.settings_backup_restore_rounded,
        size: AppIconSizes.navigation,
        fill: ShelfySymbols.fillOutline,
        weight: ShelfySymbols.weight,
        grade: ShelfySymbols.grade,
        opticalSize: ShelfySymbols.opticalSize,
      ),
    );
  }
}

class _ShelfBackupSheetBody extends StatelessWidget {
  const _ShelfBackupSheetBody({
    required this.snapshot,
    required this.scrollController,
  });

  final CollectionSnapshot snapshot;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final exportEnabled = !snapshot.isEmptyShelf;

    return CollectibleSheetInsets(
      key: const Key('shelf_backup_sheet'),
      child: CustomScrollView(
        controller: scrollController,
        shrinkWrap: true,
        physics: const ClampingScrollPhysics(),
        slivers: [
          const SliverToBoxAdapter(
            child: CollectibleSheetChrome(
              editorialTitle: ShelfBackupCopy.sheetTitle,
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(
                top: FeedRhythm.sheetTitleToBody,
                bottom: FeedRhythm.sheetBodyBottomInset,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ShelfBackupActionRow(
                    key: const Key('shelf_backup_export_row'),
                    icon: Symbols.upload_rounded,
                    title: ShelfBackupCopy.exportTitle,
                    subtitle: exportEnabled
                        ? ShelfBackupCopy.exportSubtitle
                        : ShelfBackupCopy.exportDisabledSubtitle,
                    enabled: exportEnabled,
                    scheme: scheme,
                    textTheme: textTheme,
                    onTap: exportEnabled
                        ? () => Navigator.of(context)
                            .pop(_ShelfBackupSheetAction.export)
                        : null,
                  ),
                  _ShelfBackupActionRow(
                    key: const Key('shelf_backup_import_row'),
                    icon: Symbols.download_rounded,
                    title: ShelfBackupCopy.importTitle,
                    subtitle: ShelfBackupCopy.importSubtitle,
                    enabled: true,
                    scheme: scheme,
                    textTheme: textTheme,
                    onTap: () => Navigator.of(context)
                        .pop(_ShelfBackupSheetAction.import),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShelfBackupActionRow extends StatelessWidget {
  const _ShelfBackupActionRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.scheme,
    required this.textTheme,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool enabled;
  final ColorScheme scheme;
  final TextTheme textTheme;
  final VoidCallback? onTap;

  static const double _rowMinHeight = 72;
  static const double _iconSlot = 40;

  @override
  Widget build(BuildContext context) {
    final titleColor =
        enabled ? null : scheme.onSurface.withValues(alpha: 0.38);
    final subtitleColor =
        enabled ? null : scheme.onSurfaceVariant.withValues(alpha: 0.38);
    final iconColor = enabled
        ? scheme.onSurfaceVariant
        : scheme.onSurface.withValues(alpha: 0.38);

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: _rowMinHeight),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: _iconSlot,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Icon(
                      icon,
                      size: AppIconSizes.navigation,
                      color: iconColor,
                      fill: ShelfySymbols.fillOutline,
                      weight: ShelfySymbols.weight,
                      grade: ShelfySymbols.grade,
                      opticalSize: ShelfySymbols.opticalSize,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: AppTypography.cardTitle(textTheme, scheme)
                            .copyWith(color: titleColor),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: AppTypography.cardMeta(textTheme, scheme)
                            .copyWith(color: subtitleColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

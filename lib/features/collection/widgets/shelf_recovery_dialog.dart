import 'package:blindbox_app/core/theme/app_spacing.dart';
import 'package:blindbox_app/core/theme/app_typography.dart';
import 'package:blindbox_app/core/theme/shelfy_symbols.dart';
import 'package:blindbox_app/features/collection/application/shelf_import_flow.dart';
import 'package:blindbox_app/features/collection/data/shelf_recovery_pack.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

/// Copy + keys for the cold-start recovery welcome screen.
abstract final class ShelfRecoveryDialogCopy {
  ShelfRecoveryDialogCopy._();

  static const title = 'Welcome back';
  static const subtitle = 'We found a shelf on this device.';
  static const summaryFallback =
      'Restore your shelf from the last 30 days.';
  static const androidBackupCadenceNote =
      'Android backs up about once a day, so your latest changes may not be included.';
  static const importLabel = 'Restore my shelf';
  static const startFreshLabel = 'Start fresh';
  static const confirmTitle = 'Delete your old shelf?';
  static const confirmBody =
      'Your old shelf will be permanently deleted. This can\'t be undone.';
  static const confirmCancel = 'Cancel';
  static const confirmDelete = 'Delete';
  static const importFailed =
      'Couldn\'t restore your shelf. Try again or start fresh.';
  static const startFreshFailed = 'Couldn\'t start fresh. Try again.';

  /// Summary under the subtitle. Uses [ShelfImportCopy.shelfInventorySummary].
  ///
  /// Prefers snapshot tallies; falls back to [summaryFallback] when counts or
  /// created date are unavailable.
  static String summaryLine({
    int? seriesCount,
    int? figureCount,
    int? wishlistCount,
    DateTime? createdAt,
  }) {
    if (seriesCount == null || figureCount == null || createdAt == null) {
      return summaryFallback;
    }
    return ShelfImportCopy.shelfInventorySummary(
      seriesCount: seriesCount,
      figureCount: figureCount,
      wishlistCount: wishlistCount ?? 0,
      dateVerb: 'saved',
      createdDate: ShelfImportCopy.formatCreatedDate(createdAt),
    );
  }

  /// Snapshot-first tallies from a loaded recovery pack.
  static String summaryLineForPack(ShelfRecoveryPackContents pack) {
    return summaryLine(
      seriesCount: pack.snapshot.shelfSeries.length,
      figureCount: pack.snapshot.totalShelfFigures,
      wishlistCount: pack.snapshot.totalWishlistItems,
      createdAt: pack.manifest.createdAt,
    );
  }
}

/// Full-screen, non-dismissible recovery welcome shown before the main shell.
class ShelfRecoveryDecisionPanel extends StatelessWidget {
  const ShelfRecoveryDecisionPanel({
    super.key,
    required this.onImport,
    required this.onStartFresh,
    this.summaryLine = ShelfRecoveryDialogCopy.summaryFallback,
    this.busy = false,
    this.errorMessage,
  });

  final VoidCallback onImport;
  final VoidCallback onStartFresh;

  /// Preformatted inventory line (or [ShelfRecoveryDialogCopy.summaryFallback]).
  final String summaryLine;

  final bool busy;
  final String? errorMessage;

  static const double _heroIconSize = 80;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return PopScope(
      canPop: false,
      child: ColoredBox(
        color: scheme.surface,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.pageHorizontal,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Align(
                    alignment: const Alignment(0, -0.35),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Symbols.settings_backup_restore_rounded,
                          key: const Key('shelf_recovery_welcome_icon'),
                          size: _heroIconSize,
                          color: scheme.primary,
                          fill: ShelfySymbols.fillOutline,
                          weight: ShelfySymbols.weight,
                          grade: ShelfySymbols.grade,
                          opticalSize: ShelfySymbols.opticalSize,
                        ),
                        const SizedBox(height: AppSpacing.xxl),
                        Text(
                          ShelfRecoveryDialogCopy.title,
                          textAlign: TextAlign.center,
                          style: AppTypography.screenTitle(textTheme, scheme),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          ShelfRecoveryDialogCopy.subtitle,
                          textAlign: TextAlign.center,
                          style: AppTypography.deckText(textTheme, scheme),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          key: const Key('shelf_recovery_summary'),
                          summaryLine,
                          textAlign: TextAlign.center,
                          style: AppTypography.supportive(textTheme, scheme),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          key: const Key('shelf_recovery_android_backup_note'),
                          ShelfRecoveryDialogCopy.androidBackupCadenceNote,
                          textAlign: TextAlign.center,
                          style: textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        if (errorMessage != null &&
                            errorMessage!.trim().isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.lg),
                          Text(
                            errorMessage!,
                            textAlign: TextAlign.center,
                            style: textTheme.bodySmall?.copyWith(
                              color: scheme.error,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                FilledButton(
                  key: const Key('shelf_recovery_import'),
                  style: ShelfyButtonStyles.stickySheetCta().copyWith(
                    minimumSize: const WidgetStatePropertyAll(
                      Size(double.infinity, ShelfyButtonStyles.stickyMinHeight),
                    ),
                  ),
                  onPressed: busy ? null : onImport,
                  child: busy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(ShelfRecoveryDialogCopy.importLabel),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextButton(
                  key: const Key('shelf_recovery_start_fresh'),
                  onPressed: busy ? null : onStartFresh,
                  child: const Text(ShelfRecoveryDialogCopy.startFreshLabel),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Second confirm before deleting a recovery pack.
Future<bool> showShelfRecoveryStartFreshConfirm(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      final scheme = Theme.of(ctx).colorScheme;
      return AlertDialog(
        title: const Text(ShelfRecoveryDialogCopy.confirmTitle),
        content: const Text(ShelfRecoveryDialogCopy.confirmBody),
        actions: [
          TextButton(
            key: const Key('shelf_recovery_confirm_cancel'),
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(ShelfRecoveryDialogCopy.confirmCancel),
          ),
          FilledButton(
            key: const Key('shelf_recovery_confirm_delete'),
            style: FilledButton.styleFrom(
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(ShelfRecoveryDialogCopy.confirmDelete),
          ),
        ],
      );
    },
  );
  return result == true;
}

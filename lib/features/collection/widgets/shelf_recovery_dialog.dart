import 'package:blindbox_app/core/theme/shelfy_symbols.dart';
import 'package:flutter/material.dart';

/// Copy + keys for the cold-start recovery decision dialog (option A).
abstract final class ShelfRecoveryDialogCopy {
  ShelfRecoveryDialogCopy._();

  static const title = 'Found a shelf on this device';
  static const body =
      'Import your collection from the last 30 days, or start fresh.';
  static const importLabel = 'Import';
  static const startFreshLabel = 'Start fresh';
  static const confirmTitle = 'Start fresh?';
  static const confirmBody = '旧数据会被删除，无法找回';
  static const confirmCancel = 'Cancel';
  static const confirmDelete = 'Delete';
  static const importFailed = 'Couldn’t import this shelf. Try again or start fresh.';
}

/// Non-dismissible recovery choice sheet shown before the main shell.
class ShelfRecoveryDecisionPanel extends StatelessWidget {
  const ShelfRecoveryDecisionPanel({
    super.key,
    required this.onImport,
    required this.onStartFresh,
    this.busy = false,
    this.errorMessage,
  });

  final VoidCallback onImport;
  final VoidCallback onStartFresh;
  final bool busy;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PopScope(
      canPop: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Material(
            color: scheme.surface,
            elevation: 6,
            shadowColor: scheme.shadow.withValues(alpha: 0.24),
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    ShelfRecoveryDialogCopy.title,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    ShelfRecoveryDialogCopy.body,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  if (errorMessage != null && errorMessage!.trim().isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      errorMessage!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),
                  FilledButton(
                    key: const Key('shelf_recovery_import'),
                    style: ShelfyButtonStyles.stickySheetCta(),
                    onPressed: busy ? null : onImport,
                    child: busy
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(ShelfRecoveryDialogCopy.importLabel),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    key: const Key('shelf_recovery_start_fresh'),
                    onPressed: busy ? null : onStartFresh,
                    child: const Text(ShelfRecoveryDialogCopy.startFreshLabel),
                  ),
                ],
              ),
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
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(ShelfRecoveryDialogCopy.confirmDelete),
          ),
        ],
      );
    },
  );
  return result == true;
}

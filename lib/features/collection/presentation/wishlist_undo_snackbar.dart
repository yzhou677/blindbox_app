import 'package:flutter/material.dart';

const Duration wishlistUndoSnackBarDuration = Duration(seconds: 4);

SnackBar wishlistUndoSnackBar({
  required BuildContext context,
  required String message,
  required VoidCallback onUndo,
}) {
  return SnackBar(
    content: Text(message),
    duration: wishlistUndoSnackBarDuration,
    behavior: SnackBarBehavior.floating,
    margin: const EdgeInsets.fromLTRB(20, 0, 20, 18),
    backgroundColor: Theme.of(
      context,
    ).colorScheme.inverseSurface.withValues(alpha: 0.9),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    action: SnackBarAction(label: 'UNDO', onPressed: onUndo),
  );
}

void showWishlistUndoSnackBar(
  BuildContext context, {
  required String message,
  required VoidCallback onUndo,
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.clearSnackBars();
  final controller = messenger.showSnackBar(
    wishlistUndoSnackBar(context: context, message: message, onUndo: onUndo),
  );
  var closed = false;
  controller.closed.whenComplete(() => closed = true);
  Future<void>.delayed(wishlistUndoSnackBarDuration, () {
    if (!closed) controller.close();
  });
}

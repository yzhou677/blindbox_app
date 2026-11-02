import 'package:blindbox_app/features/collection/data/shelf_media_vault.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Single gallery pick for private shelf art (no camera / no crop).
///
/// Returns a durable [ShelfMediaVault] original path (not the picker cache).
Future<String?> pickShelfGalleryImage(BuildContext context) async {
  try {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2400,
      imageQuality: 88,
    );
    final picked = file?.path;
    if (picked == null || picked.trim().isEmpty) return null;
    final vaultPath = await ShelfMediaVault.importFromPath(picked);
    if (vaultPath != null) return vaultPath;
    // Import failed — fall back to picker path so the user still keeps the photo
    // for this session (may not survive reinstall).
    return picked;
  } catch (e, st) {
    debugPrint('pickShelfGalleryImage failed: $e\n$st');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Couldn’t open photos ($e)'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    return null;
  }
}

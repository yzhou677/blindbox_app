import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Single gallery pick for private shelf art (no camera / no crop).
Future<String?> pickShelfGalleryImage(BuildContext context) async {
  try {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2400,
      imageQuality: 88,
    );
    return file?.path;
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

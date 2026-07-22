import 'package:blindbox_app/shared/image/catalog_photo_acquisition.dart';
import 'package:flutter/material.dart';

void showCatalogPhotoPlaceholder(
  BuildContext context,
  CatalogPhotoSelection selection,
) {
  debugPrint('Catalog photo selected (${selection.source.name}); recognition is not enabled.');
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Photo selected. Recognition is coming next.')),
  );
}

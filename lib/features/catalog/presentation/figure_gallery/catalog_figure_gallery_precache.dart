import 'dart:async';
import 'dart:io';

import 'package:blindbox_app/core/media/device_local_ref.dart';
import 'package:blindbox_app/features/catalog/catalog_image_resolver.dart';
import 'package:blindbox_app/features/catalog/presentation/figure_gallery/catalog_figure_gallery_item.dart';
import 'package:flutter/material.dart';

/// Warms bundled assets / cached Storage URLs for adjacent gallery pages (non-blocking).
abstract final class CatalogFigureGalleryPrecache {
  CatalogFigureGalleryPrecache._();

  /// Schedules precache — never blocks gallery open or page transitions.
  static void schedule(
    BuildContext context,
    List<CatalogFigureGalleryItem> items,
    int centerIndex,
  ) {
    if (items.isEmpty) return;
    final indices = <int>{centerIndex};
    if (centerIndex > 0) indices.add(centerIndex - 1);
    if (centerIndex + 1 < items.length) indices.add(centerIndex + 1);

    unawaited(
      Future<void>(() async {
        for (final i in indices) {
          if (!context.mounted) return;
          await precacheItem(context, items[i]);
        }
      }),
    );
  }

  static Future<void> precacheItem(
    BuildContext context,
    CatalogFigureGalleryItem item,
  ) async {
    if (!context.mounted) return;

    final local = item.localImageUri?.trim();
    if (local != null && local.isNotEmpty) {
      await _precacheLocalUri(context, local);
      return;
    }

    final seriesCover = item.seriesCoverImageUri?.trim();
    if (seriesCover != null && seriesCover.isNotEmpty) {
      await _precacheLocalUri(context, seriesCover);
      return;
    }

    final key = item.catalogImageKey?.trim();
    if (key != null && key.isNotEmpty) {
      final bundled = await CatalogImageResolver.resolveFigureAsset(key);
      if (!context.mounted) return;
      if (bundled != null && bundled.isNotEmpty) {
        await precacheImage(AssetImage(bundled), context);
        return;
      }
      final remote = CatalogImageResolver.storageFallbackEnabled
          ? await CatalogImageResolver.resolveFigureStorageRef(key)
          : null;
      if (!context.mounted) return;
      if (remote == null || remote.isEmpty) return;
      if (_isNetworkUrl(remote)) {
        await precacheImage(NetworkImage(remote), context);
        return;
      }
      if (DeviceLocalImageRef.looksLikeDevicePath(remote)) {
        final path = DeviceLocalImageRef.normalizeToFilePath(remote);
        final file = File(path);
        if (await file.exists() && context.mounted) {
          await precacheImage(FileImage(file), context);
        }
      }
      return;
    }
  }

  static bool _isNetworkUrl(String ref) {
    final lower = ref.toLowerCase();
    return lower.startsWith('http://') || lower.startsWith('https://');
  }

  static Future<void> _precacheLocalUri(
    BuildContext context,
    String uri,
  ) async {
    final path = uri.startsWith('file:') ? Uri.parse(uri).toFilePath() : uri;
    final file = File(path);
    if (await file.exists() && context.mounted) {
      await precacheImage(FileImage(file), context);
    }
  }
}

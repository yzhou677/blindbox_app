import 'dart:async';
import 'dart:io';

import 'package:blindbox_app/core/media/device_local_ref.dart';
import 'package:blindbox_app/core/theme/app_image_styles.dart';
import 'package:blindbox_app/features/catalog/catalog_image_resolver.dart';
import 'package:blindbox_app/features/catalog/presentation/catalog_image_display.dart';
import 'package:blindbox_app/features/collection/domain/collection_domain.dart';
import 'package:flutter/material.dart';

/// Post-frame warmup for series preview — cover + first visible figures only.
abstract final class CatalogSeriesPreviewWarm {
  CatalogSeriesPreviewWarm._();

  static const _visibleFigureWarmCount = 4;

  /// Never blocks sheet open; runs after the first frame.
  static void schedule(BuildContext context, CatalogSeries series) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      unawaited(_warm(context, series));
    });
  }

  static Future<void> _warm(BuildContext context, CatalogSeries series) async {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final thumbSpec = CatalogImageDisplaySpec.forMode(
      CatalogImageDisplayMode.figureThumb,
    );
    final figureDecode = thumbSpec.memCacheDecodeExtent(
      BoxConstraints.tightFor(
        width: AppImageStyles.figureThumbExtent,
        height: AppImageStyles.figureThumbExtent,
      ),
      dpr,
    );

    final coverKey = series.catalogCoverImageKey?.trim();
    if (coverKey != null && coverKey.isNotEmpty) {
      if (!context.mounted) return;
      await _warmSeriesKey(context, coverKey, figureDecode);
    }

    var warmed = 0;
    for (final figure in series.figures) {
      if (warmed >= _visibleFigureWarmCount) break;
      final key = figure.catalogImageKey?.trim();
      if (key == null || key.isEmpty) continue;
      if (!context.mounted) return;
      await _warmFigureKey(context, key, figureDecode);
      warmed++;
    }
  }

  static Future<void> _warmSeriesKey(
    BuildContext context,
    String imageKey,
    int? decodeExtent,
  ) async {
    final bundled = await CatalogImageResolver.resolveSeriesAsset(imageKey);
    if (!context.mounted) return;
    if (bundled != null && bundled.isNotEmpty) {
      await _precache(context, AssetImage(bundled), decodeExtent);
      return;
    }
    if (!CatalogImageResolver.storageFallbackEnabled) return;
    final ref = await CatalogImageResolver.resolveSeriesStorageRef(imageKey);
    if (!context.mounted) return;
    await _precacheResolvedRef(context, ref, decodeExtent);
  }

  static Future<void> _warmFigureKey(
    BuildContext context,
    String imageKey,
    int? decodeExtent,
  ) async {
    final bundled = await CatalogImageResolver.resolveFigureAsset(imageKey);
    if (!context.mounted) return;
    if (bundled != null && bundled.isNotEmpty) {
      await _precache(context, AssetImage(bundled), decodeExtent);
      return;
    }
    if (!CatalogImageResolver.storageFallbackEnabled) return;
    final ref = await CatalogImageResolver.resolveFigureStorageRef(imageKey);
    if (!context.mounted) return;
    await _precacheResolvedRef(context, ref, decodeExtent);
  }

  static Future<void> _precacheResolvedRef(
    BuildContext context,
    String? ref,
    int? decodeExtent,
  ) async {
    if (ref == null || ref.isEmpty) return;
    if (ref.startsWith('assets/')) {
      await _precache(context, AssetImage(ref), decodeExtent);
      return;
    }
    if (DeviceLocalImageRef.looksLikeDevicePath(ref)) {
      final path = DeviceLocalImageRef.normalizeToFilePath(ref);
      final file = File(path);
      if (await file.exists() && context.mounted) {
        await _precache(context, FileImage(file), decodeExtent);
      }
      return;
    }
    final lower = ref.toLowerCase();
    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      await _precache(context, NetworkImage(ref), decodeExtent);
    }
  }

  static Future<void> _precache(
    BuildContext context,
    ImageProvider provider,
    int? decodeExtent,
  ) async {
    if (decodeExtent != null) {
      provider = ResizeImage.resizeIfNeeded(decodeExtent, null, provider);
    }
    await precacheImage(provider, context);
  }
}

import 'dart:io';

import 'package:blindbox_app/features/catalog/presentation/catalog_image_display.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// App-wide rule: **crop when needed, never stretch**. Aspect ratio is always preserved.
abstract final class CatalogAspectImage {
  CatalogAspectImage._();

  static bool isAspectPreservingFit(BoxFit fit) =>
      fit == BoxFit.cover ||
      fit == BoxFit.contain ||
      fit == BoxFit.scaleDown ||
      fit == BoxFit.none;

  static void assertAspectPreservingFit(BoxFit fit) {
    assert(
      isAspectPreservingFit(fit),
      'CatalogAspectImage: $fit can distort artwork; use cover or contain.',
    );
  }

  static Widget presentAsset({
    required String asset,
    Key? key,
    Alignment alignment = Alignment.center,
    FilterQuality filterQuality = FilterQuality.high,
    BoxFit fit = BoxFit.cover,
    bool fillBounds = true,
    int? decodeExtent,
    ImageErrorWidgetBuilder? errorBuilder,
  }) {
    assertAspectPreservingFit(fit);
    final image = Image.asset(
      asset,
      key: key,
      fit: fit,
      alignment: alignment,
      filterQuality: filterQuality,
      cacheWidth: decodeExtent,
      errorBuilder: errorBuilder,
    );
    if (fillBounds) {
      return SizedBox.expand(child: image);
    }
    return Center(child: image);
  }

  static Widget presentNetwork({
    required String imageUrl,
    Key? key,
    String? cacheKey,
    Alignment alignment = Alignment.center,
    FilterQuality filterQuality = FilterQuality.high,
    BoxFit fit = BoxFit.cover,
    bool fillBounds = true,
    int? decodeExtent,
    Duration fadeInDuration = const Duration(milliseconds: 220),
    Duration fadeOutDuration = const Duration(milliseconds: 120),
    Widget Function(BuildContext, String)? placeholder,
    Widget Function(BuildContext, String, Object)? errorWidget,
  }) {
    assertAspectPreservingFit(fit);
    final image = CachedNetworkImage(
      key: key,
      imageUrl: imageUrl,
      cacheKey: cacheKey ?? imageUrl,
      fit: fit,
      alignment: alignment,
      filterQuality: filterQuality,
      memCacheWidth: decodeExtent,
      fadeInDuration: fadeInDuration,
      fadeOutDuration: fadeOutDuration,
      placeholder: placeholder,
      errorWidget: errorWidget,
    );
    if (fillBounds) {
      return SizedBox.expand(child: image);
    }
    return Center(child: image);
  }

  @Deprecated('Use presentAsset(fillBounds: true)')
  static Widget coverAsset({
    required String asset,
    Key? key,
    Alignment alignment = Alignment.center,
    FilterQuality filterQuality = FilterQuality.high,
    BoxFit fit = BoxFit.cover,
    ImageErrorWidgetBuilder? errorBuilder,
  }) => presentAsset(
    asset: asset,
    key: key,
    alignment: alignment,
    filterQuality: filterQuality,
    fit: fit,
    fillBounds: true,
    errorBuilder: errorBuilder,
  );

  @Deprecated('Use presentNetwork(fillBounds: true)')
  static Widget coverNetwork({
    required String imageUrl,
    Key? key,
    String? cacheKey,
    Alignment alignment = Alignment.center,
    FilterQuality filterQuality = FilterQuality.high,
    BoxFit fit = BoxFit.cover,
    int? decodeExtent,
    Duration fadeInDuration = const Duration(milliseconds: 220),
    Duration fadeOutDuration = const Duration(milliseconds: 120),
    Widget Function(BuildContext, String)? placeholder,
    Widget Function(BuildContext, String, Object)? errorWidget,
  }) => presentNetwork(
    key: key,
    imageUrl: imageUrl,
    cacheKey: cacheKey,
    alignment: alignment,
    filterQuality: filterQuality,
    fit: fit,
    fillBounds: true,
    decodeExtent: decodeExtent,
    fadeInDuration: fadeInDuration,
    fadeOutDuration: fadeOutDuration,
    placeholder: placeholder,
    errorWidget: errorWidget,
  );

  static Widget coverFile({
    required File file,
    Alignment alignment = Alignment.center,
    FilterQuality filterQuality = FilterQuality.high,
    BoxFit fit = BoxFit.cover,
    bool fillBounds = true,
    int? decodeExtent,
    ImageErrorWidgetBuilder? errorBuilder,
  }) {
    assertAspectPreservingFit(fit);
    final image = Image.file(
      file,
      fit: fit,
      alignment: alignment,
      filterQuality: filterQuality,
      cacheWidth: decodeExtent,
      errorBuilder: errorBuilder,
    );
    if (fillBounds) {
      return SizedBox.expand(child: image);
    }
    return Center(child: image);
  }
}

int? catalogDecodeExtentFromLayout(
  BoxConstraints constraints,
  double devicePixelRatio, {
  CatalogImageDisplaySpec spec = const CatalogImageDisplaySpec(
    presentationMode: CatalogImageMode.thumbnail,
    framing: CatalogImageFraming.coverFill,
    fit: BoxFit.cover,
    alignment: Alignment.center,
    filterQuality: FilterQuality.high,
    fadeInDuration: Duration(milliseconds: 220),
    fadeOutDuration: Duration(milliseconds: 120),
    contentPadding: EdgeInsets.zero,
    matOpacity: 0.36,
    memCacheLogicalExtent: 136,
    memCacheDevicePixelScale: 1.75,
  ),
}) {
  return spec.memCacheDecodeExtent(constraints, devicePixelRatio);
}

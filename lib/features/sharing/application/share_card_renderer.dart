import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class ShareCardRenderer {
  const ShareCardRenderer();

  Future<Uint8List> capturePng(
    GlobalKey repaintBoundaryKey, {
    double pixelRatio = 3,
  }) async {
    final context = repaintBoundaryKey.currentContext;
    if (context == null) {
      throw StateError('Share card boundary is not mounted.');
    }
    final boundary = context.findRenderObject();
    if (boundary is! RenderRepaintBoundary) {
      throw StateError('Share card key must point to a RepaintBoundary.');
    }
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (bytes == null) {
      throw StateError('Unable to encode share card PNG.');
    }
    return bytes.buffer.asUint8List();
  }
}

class ShareCardCaptureBoundary extends StatelessWidget {
  const ShareCardCaptureBoundary({
    super.key,
    required this.captureKey,
    required this.child,
  });

  final GlobalKey captureKey;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(key: captureKey, child: child);
  }
}

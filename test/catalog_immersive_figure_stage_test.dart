import 'dart:convert';
import 'dart:typed_data';

import 'package:blindbox_app/features/catalog/presentation/catalog_image_display.dart';
import 'package:blindbox_app/features/catalog/presentation/figure_gallery/catalog_immersive_edge_feather.dart';
import 'package:blindbox_app/features/catalog/presentation/figure_gallery/catalog_immersive_feathered_subject.dart';
import 'package:blindbox_app/features/catalog/presentation/figure_gallery/catalog_immersive_figure_stage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 1×1 PNG — valid decode for [MemoryImage] in widget tests.
final Uint8List kTest1x1Png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

void main() {
  testWidgets('CatalogImmersiveEdgeFeather nests horizontal and vertical masks', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CatalogImmersiveEdgeFeather(
            child: SizedBox(width: 100, height: 200),
          ),
        ),
      ),
    );

    expect(find.byType(ShaderMask), findsNWidgets(2));
  });

  test('fittedDestinationSize letterboxes wide art with shorter fitted height', () {
    const slotW = 300.0;
    const slotH = 400.0;
    const wide = Size(800, 400);

    final fitted = CatalogImmersiveFeatheredSubject.fittedDestinationSize(
      sourceSize: wide,
      slotWidth: slotW,
      slotHeight: slotH,
    );

    expect(fitted.width, slotW);
    expect(fitted.height, lessThan(slotH));
    expect(fitted.height, greaterThan(0));
  });

  test('fittedDestinationSize letterboxes tall art with narrower fitted width', () {
    const slotW = 300.0;
    const slotH = 400.0;
    const tall = Size(400, 800);

    final fitted = CatalogImmersiveFeatheredSubject.fittedDestinationSize(
      sourceSize: tall,
      slotWidth: slotW,
      slotHeight: slotH,
    );

    expect(fitted.height, slotH);
    expect(fitted.width, lessThan(slotW));
    expect(fitted.width, greaterThan(0));
  });

  testWidgets('CatalogImmersiveFigureStage composes backdrop blur and foreground', (
    tester,
  ) async {
    const spec = CatalogImageDisplaySpec(
      presentationMode: CatalogImageMode.figure,
      framing: CatalogImageFraming.subjectContain,
      fit: BoxFit.contain,
      alignment: Alignment.center,
      filterQuality: FilterQuality.high,
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      contentPadding: EdgeInsets.all(6),
      matOpacity: 0.5,
      subjectZoom: 1.04,
      memCacheLogicalExtent: 720,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            height: 400,
            child: CatalogImmersiveFigureStage(
              constraints: const BoxConstraints(maxWidth: 320, maxHeight: 400),
              borderRadius: BorderRadius.circular(16),
              spec: spec,
              backdrop: Container(color: Colors.blue),
              foregroundSubject: CatalogImmersiveFeatheredSubject(
                imageProvider: MemoryImage(kTest1x1Png),
                slotWidth: 308,
                slotHeight: 388,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(ImageFiltered), findsOneWidget);
    expect(find.byType(CatalogImmersiveFeatheredSubject), findsOneWidget);
  });

  test('subjectContainLayer preserves gallery padding without extra slot box', () {
    const spec = CatalogImageDisplaySpec(
      presentationMode: CatalogImageMode.figure,
      framing: CatalogImageFraming.subjectContain,
      fit: BoxFit.contain,
      alignment: Alignment.center,
      filterQuality: FilterQuality.high,
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      contentPadding: EdgeInsets.all(8),
      matOpacity: 0.5,
      subjectZoom: 1.04,
    );

    final widget = CatalogImmersiveFigureStage.subjectContainLayer(
      constraints: const BoxConstraints(maxWidth: 200, maxHeight: 300),
      spec: spec,
      child: const SizedBox(),
    );

    expect(widget, isA<Padding>());
  });
}

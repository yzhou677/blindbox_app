import 'dart:typed_data';

import 'package:blindbox_app/shared/image/catalog_photo_acquisition.dart';
import 'package:blindbox_app/shared/image/catalog_subject_selection.dart';
import 'package:blindbox_app/shared/widgets/catalog_subject_selection_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:image_picker/image_picker.dart';

void main() {
  testWidgets('uses shared Shelfy typography without local text overrides', (
    tester,
  ) async {
    await _pumpScreen(tester, width: 200, height: 100);

    expect(
      tester.widget<Text>(find.text('Frame your collectible')).style,
      equals(
        Theme.of(
          tester.element(find.text('Frame your collectible')),
        ).textTheme.titleLarge,
      ),
    );
    expect(tester.widget<Text>(find.text('Continue')).style, isNull);
    expect(tester.widget<Text>(find.text('Reset Selection')).style, isNull);
    expect(tester.widget<Icon>(find.byIcon(Icons.refresh_rounded)).size, 17);
  });

  testWidgets('AI suggestion status appears only until suggestion is edited', (
    tester,
  ) async {
    const suggestion = NormalizedSubjectRect(
      left: 0.15,
      top: 0.15,
      right: 0.75,
      bottom: 0.75,
    );
    await _pumpScreen(
      tester,
      width: 200,
      height: 100,
      initialSelection: suggestion,
      initialOrigin: SubjectSelectionOrigin.suggestedBox,
    );

    expect(
      find.text('AI suggested this frame. Adjust if needed.'),
      findsOneWidget,
    );
    final box = find.byKey(const Key('subject-selection-box'));
    await tester.ensureVisible(box);
    await tester.drag(box, const Offset(20, 0));
    await tester.pump();
    expect(
      find.text('AI suggested this frame. Adjust if needed.'),
      findsNothing,
    );
  });

  testWidgets('deterministic default never claims to be AI suggested', (
    tester,
  ) async {
    await _pumpScreen(tester, width: 200, height: 100);

    expect(
      find.byKey(const Key('subject-selection-ai-suggestion')),
      findsNothing,
    );
  });

  testWidgets('default box appears inside the displayed image', (tester) async {
    await _pumpScreen(tester, width: 200, height: 100);

    final box = tester.getRect(find.byKey(const Key('subject-selection-box')));
    final displayedImage = tester.getRect(
      find.byKey(const Key('subject-selection-image')),
    );

    expect(find.byKey(const Key('subject-selection-overlay')), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
    expect(box.left, greaterThanOrEqualTo(displayedImage.left));
    expect(box.top, greaterThanOrEqualTo(displayedImage.top));
    expect(box.right, lessThanOrEqualTo(displayedImage.right));
    expect(box.bottom, lessThanOrEqualTo(displayedImage.bottom));
    expect(box.width / displayedImage.width, closeTo(0.6, 0.01));
    expect(box.height / displayedImage.height, closeTo(0.6, 0.01));
  });

  testWidgets('dragging moves the box and clamps it to image bounds', (
    tester,
  ) async {
    await _pumpScreen(tester, width: 200, height: 100);
    final finder = find.byKey(const Key('subject-selection-box'));
    await tester.ensureVisible(finder);
    await tester.pump();
    final before = tester.getRect(finder);

    await tester.drag(finder, const Offset(30, 8));
    await tester.pump();
    final moved = tester.getRect(finder);
    expect(moved.left, greaterThan(before.left));
    expect(moved.top, greaterThan(before.top));

    await tester.drag(finder, const Offset(2000, 2000));
    await tester.pump();
    final clamped = tester.getRect(finder);
    final currentImageRect = tester.getRect(
      find.byKey(const Key('subject-selection-image')),
    );
    expect(clamped.right, lessThanOrEqualTo(currentImageRect.right + 0.01));
    expect(clamped.bottom, lessThanOrEqualTo(currentImageRect.bottom + 0.01));
  });

  testWidgets('corner drag resizes and cannot leave image bounds', (
    tester,
  ) async {
    await _pumpScreen(tester, width: 100, height: 200);
    final boxFinder = find.byKey(const Key('subject-selection-box'));
    final handle = find.byKey(
      const Key('subject-selection-handle-bottomRight'),
    );
    await tester.ensureVisible(handle);
    await tester.pump();
    final before = tester.getRect(boxFinder);

    await tester.drag(handle, const Offset(25, 25));
    await tester.pump();
    final resized = tester.getRect(boxFinder);
    expect(resized.width, greaterThan(before.width));
    expect(resized.height, greaterThan(before.height));

    await tester.drag(handle, const Offset(2000, 2000));
    await tester.pump();
    final clamped = tester.getRect(boxFinder);
    final currentImageRect = tester.getRect(
      find.byKey(const Key('subject-selection-image')),
    );
    expect(clamped.right, lessThanOrEqualTo(currentImageRect.right + 0.01));
    expect(clamped.bottom, lessThanOrEqualTo(currentImageRect.bottom + 0.01));
  });

  testWidgets('letterboxed padding is excluded from selection coordinates', (
    tester,
  ) async {
    await _pumpScreen(tester, width: 300, height: 100);
    final viewport = tester.getRect(
      find.byKey(const Key('subject-selection-viewport')),
    );
    final displayedImage = tester.getRect(
      find.byKey(const Key('subject-selection-image')),
    );
    final box = tester.getRect(find.byKey(const Key('subject-selection-box')));

    expect(displayedImage.top, greaterThan(viewport.top));
    expect(displayedImage.bottom, lessThan(viewport.bottom));
    expect(box.top, greaterThan(displayedImage.top));
    expect(box.bottom, lessThan(displayedImage.bottom));
  });

  testWidgets('reset restores deterministic default box', (tester) async {
    await _pumpScreen(tester, width: 200, height: 100);
    final boxFinder = find.byKey(const Key('subject-selection-box'));
    await tester.ensureVisible(boxFinder);
    await tester.pump();
    final initial = _relativeSelectionRect(tester);
    await tester.drag(boxFinder, const Offset(30, 5));
    await tester.pump();
    expect(_relativeSelectionRect(tester), isNot(initial));

    await tester.ensureVisible(find.text('Reset Selection'));
    await tester.pump();
    await tester.tap(find.text('Reset Selection'));
    await tester.pump();
    await tester.ensureVisible(boxFinder);
    await tester.pump();
    expect(_relativeSelectionRect(tester), initial);
  });

  testWidgets('dragging outside the box redraws a bounded selection', (
    tester,
  ) async {
    await _pumpScreen(tester, width: 200, height: 200);
    final imageRect = tester.getRect(
      find.byKey(const Key('subject-selection-image')),
    );
    final start = imageRect.topLeft + const Offset(12, 12);
    await tester.dragFrom(start, const Offset(90, 10));
    await tester.pump();

    final redrawn = _relativeSelectionRect(tester);
    expect(redrawn.left, greaterThanOrEqualTo(0));
    expect(redrawn.top, greaterThanOrEqualTo(0));
    expect(redrawn.right, lessThanOrEqualTo(1));
    expect(redrawn.bottom, lessThanOrEqualTo(1));
    expect(redrawn, isNot(const Rect.fromLTWH(0.2, 0.2, 0.6, 0.6)));
  });

  for (final dimensions in [(200, 100), (100, 200)]) {
    testWidgets(
      'confirm maps normalized selection to ${dimensions.$1}x${dimensions.$2} source',
      (tester) async {
        final result = await _pumpAndConfirm(
          tester,
          width: dimensions.$1,
          height: dimensions.$2,
        );

        expect(result.normalizedRect.left, closeTo(0.2, 0.0001));
        expect(result.normalizedRect.top, closeTo(0.2, 0.0001));
        expect(result.normalizedRect.right, closeTo(0.8, 0.0001));
        expect(result.normalizedRect.bottom, closeTo(0.8, 0.0001));
        expect(
          result.sourceImageRect,
          Rect.fromLTRB(
            dimensions.$1 * 0.2,
            dimensions.$2 * 0.2,
            dimensions.$1 * 0.8,
            dimensions.$2 * 0.8,
          ),
        );
        expect(result.origin, SubjectSelectionOrigin.defaultBox);
      },
    );
  }

  testWidgets('small screen and large text do not overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 560);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpScreen(
      tester,
      width: 100,
      height: 200,
      textScaler: const TextScaler.linear(2),
    );

    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  required int width,
  required int height,
  TextScaler textScaler = TextScaler.noScaling,
  NormalizedSubjectRect? initialSelection,
  SubjectSelectionOrigin initialOrigin = SubjectSelectionOrigin.defaultBox,
}) async {
  final selection = _selection(width, height);
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: child!,
      ),
      home: CatalogSubjectSelectionScreen(
        selection: selection,
        initialSelection: initialSelection,
        initialOrigin: initialOrigin,
      ),
    ),
  );
  await _settleImageDecode(tester);
}

Future<CatalogSubjectSelectionResult> _pumpAndConfirm(
  WidgetTester tester, {
  required int width,
  required int height,
}) async {
  final selection = _selection(width, height);
  CatalogSubjectSelectionResult? result;
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => FilledButton(
          onPressed: () async {
            result = await showCatalogSubjectSelectionSheet(context, selection);
          },
          child: const Text('Open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pump();
  await _settleImageDecode(tester);
  await tester.ensureVisible(find.text('Continue'));
  await tester.pump();
  await tester.tap(find.text('Continue'));
  await tester.pumpAndSettle();
  return result!;
}

Rect _relativeSelectionRect(WidgetTester tester) {
  final imageRect = tester.getRect(
    find.byKey(const Key('subject-selection-image')),
  );
  final box = tester.getRect(find.byKey(const Key('subject-selection-box')));
  return Rect.fromLTRB(
    (box.left - imageRect.left) / imageRect.width,
    (box.top - imageRect.top) / imageRect.height,
    (box.right - imageRect.left) / imageRect.width,
    (box.bottom - imageRect.top) / imageRect.height,
  );
}

Future<void> _settleImageDecode(WidgetTester tester) async {
  for (var attempt = 0; attempt < 20; attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
    if (find
        .byKey(const Key('subject-selection-image'))
        .evaluate()
        .isNotEmpty) {
      await tester.pump(const Duration(milliseconds: 200));
      return;
    }
  }
  fail('Subject image did not finish decoding.');
}

CatalogPhotoSelection _selection(int width, int height) {
  final source = image.Image(width: width, height: height);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final light = ((x ~/ 10) + (y ~/ 10)).isEven;
      source.setPixelRgb(x, y, light ? 210 : 60, light ? 180 : 45, 140);
    }
  }
  return CatalogPhotoSelection(
    file: XFile.fromData(
      Uint8List.fromList(image.encodePng(source)),
      name: 'subject.png',
      mimeType: 'image/png',
    ),
    source: CatalogPhotoSource.gallery,
  );
}

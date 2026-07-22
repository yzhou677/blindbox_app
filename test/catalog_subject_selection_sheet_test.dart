import 'dart:typed_data';

import 'package:blindbox_app/shared/image/catalog_photo_acquisition.dart';
import 'package:blindbox_app/shared/image/catalog_subject_selection.dart';
import 'package:blindbox_app/shared/widgets/catalog_subject_selection_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:image_picker/image_picker.dart';

void main() {
  testWidgets('opens as a bottom-anchored sheet over stationary content', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pumpHost(tester);
    final before = tester.getRect(find.byKey(const Key('underlying-page')));

    await _openSheet(tester);

    final whileOpen = tester.getRect(find.byKey(const Key('underlying-page')));
    final sheet = tester.getRect(
      find.byKey(const Key('subject-selection-sheet')),
    );
    expect(find.byType(AppBar), findsNothing);
    expect(whileOpen, before);
    expect(sheet.bottom, closeTo(800, 0.01));
    expect(sheet.height / 800, closeTo(0.9, 0.01));

    await tester.tap(find.byKey(const Key('subject-selection-close')));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byKey(const Key('underlying-page'))), before);
  });

  testWidgets('short handle drag snaps the sheet back into place', (
    tester,
  ) async {
    await _pumpHost(tester);
    await _openSheet(tester);
    final sheetFinder = find.byKey(const Key('subject-selection-sheet'));
    final before = tester.getRect(sheetFinder);

    await tester.drag(
      find.byKey(const Key('subject-selection-drag-handle')),
      const Offset(0, 36),
    );
    await tester.pumpAndSettle();

    expect(sheetFinder, findsOneWidget);
    expect(tester.getRect(sheetFinder), before);
  });

  testWidgets('downward handle fling dismisses without a selection', (
    tester,
  ) async {
    CatalogSubjectSelectionResult? result;
    await _pumpHost(tester, onResult: (value) => result = value);
    await _openSheet(tester);

    await tester.fling(
      find.byKey(const Key('subject-selection-drag-handle')),
      const Offset(0, 500),
      1800,
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('subject-selection-sheet')), findsNothing);
    expect(result, isNull);
  });

  testWidgets('system back dismisses without confirming', (tester) async {
    CatalogSubjectSelectionResult? result;
    await _pumpHost(tester, onResult: (value) => result = value);
    await _openSheet(tester);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('subject-selection-sheet')), findsNothing);
    expect(result, isNull);
  });

  testWidgets('Continue returns the unchanged selection result contract', (
    tester,
  ) async {
    CatalogSubjectSelectionResult? result;
    await _pumpHost(tester, onResult: (value) => result = value);
    await _openSheet(tester);

    await tester.ensureVisible(
      find.byKey(const Key('subject-selection-confirm')),
    );
    await tester.tap(find.byKey(const Key('subject-selection-confirm')));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(
      result!.normalizedRect.rect,
      const Rect.fromLTWH(0.2, 0.2, 0.6, 0.6),
    );
    expect(result!.sourceImageRect, const Rect.fromLTRB(40, 20, 160, 80));
    expect(result!.orientedSourceSize, const Size(200, 100));
    expect(result!.origin, SubjectSelectionOrigin.defaultBox);
  });

  testWidgets('AI suggestion status is honest and origin-dependent', (
    tester,
  ) async {
    await _pumpHost(tester);
    await _openSheet(tester);
    expect(
      find.text('AI suggested this frame. Adjust if needed.'),
      findsNothing,
    );
    await tester.tap(find.byKey(const Key('subject-selection-close')));
    await tester.pumpAndSettle();

    await _pumpHost(
      tester,
      suggestion: const NormalizedSubjectRect(
        left: 0.1,
        top: 0.1,
        right: 0.7,
        bottom: 0.7,
      ),
    );
    await _openSheet(tester);
    expect(
      find.text('AI suggested this frame. Adjust if needed.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'small screen with large text remains scrollable without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(320, 560);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _pumpHost(tester, textScaler: const TextScaler.linear(2));

      await _openSheet(tester);

      expect(find.byType(SingleChildScrollView), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _pumpHost(
  WidgetTester tester, {
  ValueChanged<CatalogSubjectSelectionResult?>? onResult,
  NormalizedSubjectRect? suggestion,
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  final selection = _selection();
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: child!,
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => SizedBox.expand(
            key: const Key('underlying-page'),
            child: Center(
              child: FilledButton(
                onPressed: () async {
                  final result = await showCatalogSubjectSelectionSheet(
                    context,
                    selection,
                    suggestedSelection: suggestion,
                  );
                  onResult?.call(result);
                },
                child: const Text('Open framing'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> _openSheet(WidgetTester tester) async {
  await tester.tap(find.text('Open framing'));
  await tester.pump();
  for (var attempt = 0; attempt < 20; attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 25)),
    );
    await tester.pump();
    if (find
        .byKey(const Key('subject-selection-image'))
        .evaluate()
        .isNotEmpty) {
      await tester.pumpAndSettle();
      return;
    }
  }
  fail('Subject image did not finish decoding.');
}

CatalogPhotoSelection _selection() {
  final source = image.Image(width: 200, height: 100);
  for (var y = 0; y < source.height; y++) {
    for (var x = 0; x < source.width; x++) {
      final light = ((x ~/ 10) + (y ~/ 10)).isEven;
      source.setPixelRgb(x, y, light ? 220 : 40, light ? 190 : 50, 130);
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

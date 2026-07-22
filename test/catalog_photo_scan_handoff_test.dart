import 'dart:typed_data';

import 'package:blindbox_app/shared/image/catalog_photo_acquisition.dart';
import 'package:blindbox_app/shared/image/whole_image_quality.dart';
import 'package:blindbox_app/shared/widgets/catalog_photo_verification_page.dart';
import 'package:blindbox_app/shared/widgets/catalog_subject_selection_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:image_picker/image_picker.dart';

final class _AlwaysUsableEvaluator implements WholeImageQualityEvaluator {
  const _AlwaysUsableEvaluator();

  @override
  Future<WholeImageQualityResult> evaluate(
    CatalogPhotoSelection selection,
  ) async => const WholeImageQualityResult(
    outcome: WholeImageQualityOutcome.usable,
    evaluatorVersion: 'handoff-test',
  );
}

void main() {
  testWidgets('Use This Photo navigates confirmed image to subject selection', (
    tester,
  ) async {
    final selection = _validSelection(CatalogPhotoSource.camera);
    await _pumpEntryHost(tester, {'Discover': selection});

    await tester.tap(find.text('Discover'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use This Photo'));
    await _settleSubjectImage(tester);

    final screen = tester.widget<CatalogSubjectSelectionScreen>(
      find.byType(CatalogSubjectSelectionScreen),
    );
    expect(screen.selection, same(selection));
    expect(find.text('Select the collectible'), findsOneWidget);
    expect(
      find.text('Adjust the box around the collectible you want to identify.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('subject-selection-image')), findsOneWidget);
    expect(find.byKey(const Key('subject-selection-source')), findsNothing);
    expect(find.text('Camera photo'), findsNothing);
    expect(
      find.text('Photo selected. Recognition is coming next.'),
      findsNothing,
    );
    expect(find.byType(SnackBar), findsNothing);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(CatalogSubjectSelectionScreen), findsNothing);
    expect(find.text('Discover'), findsOneWidget);
  });

  testWidgets('Discover and Add a Series use the same local handoff', (
    tester,
  ) async {
    final entries = {
      'Discover': _validSelection(CatalogPhotoSource.camera),
      'Add a Series': _validSelection(CatalogPhotoSource.gallery),
    };
    await _pumpEntryHost(tester, entries);

    for (final entry in entries.entries) {
      await tester.tap(find.text(entry.key));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Use This Photo'));
      await _settleSubjectImage(tester);

      final screen = tester.widget<CatalogSubjectSelectionScreen>(
        find.byType(CatalogSubjectSelectionScreen),
      );
      expect(screen.selection, same(entry.value));
      expect(find.byKey(const Key('subject-selection-source')), findsNothing);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
    }
  });
}

Future<void> _settleSubjectImage(WidgetTester tester) async {
  for (var attempt = 0; attempt < 20; attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
    if (find.byKey(const Key('subject-selection-image')).evaluate().isNotEmpty) {
      return;
    }
  }
  fail('Subject image did not finish decoding.');
}

Future<void> _pumpEntryHost(
  WidgetTester tester,
  Map<String, CatalogPhotoSelection> entries,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Column(
            children: [
              for (final entry in entries.entries)
                FilledButton(
                  onPressed: () => showCatalogPhotoVerification(
                    context,
                    entry.value,
                    evaluator: const _AlwaysUsableEvaluator(),
                  ),
                  child: Text(entry.key),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

CatalogPhotoSelection _validSelection(CatalogPhotoSource source) {
  final preview = image.Image(width: 160, height: 120);
  for (var y = 0; y < preview.height; y++) {
    for (var x = 0; x < preview.width; x++) {
      final light = ((x ~/ 8) + (y ~/ 8)).isEven;
      preview.setPixelRgb(
        x,
        y,
        light ? 230 : 30,
        light ? 210 : 40,
        light ? 190 : 50,
      );
    }
  }
  return CatalogPhotoSelection(
    file: XFile.fromData(
      Uint8List.fromList(image.encodePng(preview)),
      name: 'photo.png',
      mimeType: 'image/png',
    ),
    source: source,
  );
}

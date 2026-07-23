import 'dart:typed_data';

import 'package:blindbox_app/shared/image/catalog_photo_acquisition.dart';
import 'package:blindbox_app/shared/image/catalog_subject_locator_gateway.dart';
import 'package:blindbox_app/shared/image/whole_image_quality.dart';
import 'package:blindbox_app/shared/widgets/catalog_photo_verification_page.dart';
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

final class _NoSuggestionLocator implements CatalogSubjectLocator {
  const _NoSuggestionLocator();

  @override
  Future<CatalogSubjectLocatorResult> locate(
    CatalogPhotoSelection originalPhoto,
  ) async => const CatalogSubjectLocatorNoSuggestion();

  @override
  void cancelPending() {}
}

void main() {
  testWidgets('Use This Photo navigates confirmed image to subject selection', (
    tester,
  ) async {
    final selection = _validSelection(CatalogPhotoSource.camera);
    await _pumpEntryHost(tester, {'Discover': selection});

    await tester.tap(find.text('Discover'));
    await _settleReviewImage(tester);
    await tester.tap(find.text('Use This Photo'));
    await _settleSubjectImage(tester);

    final sheet = tester.widget<CatalogPhotoVerificationPage>(
      find.byType(CatalogPhotoVerificationPage),
    );
    expect(sheet.selection, same(selection));
    expect(find.text('Frame your collectible'), findsOneWidget);
    expect(
      find.text('Fit the frame to your collectible.'),
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
    expect(find.byType(CatalogPhotoVerificationPage), findsNothing);
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
      await _settleReviewImage(tester);
      await tester.tap(find.text('Use This Photo'));
      await _settleSubjectImage(tester);

      final sheet = tester.widget<CatalogPhotoVerificationPage>(
        find.byType(CatalogPhotoVerificationPage),
      );
      expect(sheet.selection, same(entry.value));
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
    if (find.text('Frame your collectible').evaluate().isNotEmpty) {
      await tester.pump(const Duration(milliseconds: 200));
      return;
    }
  }
  fail('Subject image did not finish decoding.');
}

Future<void> _settleReviewImage(WidgetTester tester) async {
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
  fail('Review image did not finish decoding.');
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
                    locatorGateway: const _NoSuggestionLocator(),
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

import 'dart:async';
import 'dart:typed_data';

import 'package:blindbox_app/shared/image/catalog_photo_acquisition.dart';
import 'package:blindbox_app/shared/image/catalog_subject_locator_gateway.dart';
import 'package:blindbox_app/shared/image/catalog_subject_selection.dart';
import 'package:blindbox_app/shared/image/whole_image_quality.dart';
import 'package:blindbox_app/shared/widgets/catalog_photo_verification_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:image_picker/image_picker.dart';

final class _FakeEvaluator implements WholeImageQualityEvaluator {
  _FakeEvaluator(this.outcome);

  WholeImageQualityOutcome outcome;
  var calls = 0;

  @override
  Future<WholeImageQualityResult> evaluate(
    CatalogPhotoSelection selection,
  ) async {
    calls++;
    return WholeImageQualityResult(
      outcome: outcome,
      evaluatorVersion: 'test-v1',
    );
  }
}

final class _FakePhotoAcquirer implements CatalogPhotoAcquirer {
  _FakePhotoAcquirer(List<CatalogPhotoSelection?> results)
    : _results = List.of(results);

  final List<CatalogPhotoSelection?> _results;
  final requested = <CatalogPhotoSource>[];

  @override
  Future<CatalogPhotoSelection?> acquire(CatalogPhotoSource source) async {
    requested.add(source);
    return _results.removeAt(0);
  }
}

final class _ControlledEvaluator implements WholeImageQualityEvaluator {
  final pending = <Completer<WholeImageQualityResult>>[];
  final selections = <CatalogPhotoSelection>[];

  @override
  Future<WholeImageQualityResult> evaluate(CatalogPhotoSelection selection) {
    selections.add(selection);
    final completer = Completer<WholeImageQualityResult>();
    pending.add(completer);
    return completer.future;
  }
}

final class _FakeSubjectLocator implements CatalogSubjectLocator {
  _FakeSubjectLocator([CatalogSubjectLocatorResult? result])
    : result = result ?? const CatalogSubjectLocatorNoSuggestion();

  CatalogSubjectLocatorResult result;
  final photos = <CatalogPhotoSelection>[];
  var calls = 0;
  var cancellations = 0;

  @override
  Future<CatalogSubjectLocatorResult> locate(
    CatalogPhotoSelection originalPhoto,
  ) async {
    calls++;
    photos.add(originalPhoto);
    return result;
  }

  @override
  void cancelPending() => cancellations++;
}

final class _ControlledSubjectLocator implements CatalogSubjectLocator {
  final pending = <Completer<CatalogSubjectLocatorResult>>[];
  final photos = <CatalogPhotoSelection>[];
  var cancellations = 0;

  @override
  Future<CatalogSubjectLocatorResult> locate(
    CatalogPhotoSelection originalPhoto,
  ) {
    photos.add(originalPhoto);
    final completer = Completer<CatalogSubjectLocatorResult>();
    pending.add(completer);
    return completer.future;
  }

  @override
  void cancelPending() => cancellations++;
}

void main() {
  testWidgets('acquired photo opens a floating confirmation over stable page', (
    tester,
  ) async {
    final hostKey = GlobalKey();
    final evaluator = _FakeEvaluator(WholeImageQualityOutcome.usable);
    await _pumpHost(tester, hostKey: hostKey, evaluator: evaluator);
    final before = tester.getRect(find.byKey(const Key('underlying-page')));

    await tester.tap(find.text('Acquire'));
    await _settlePhotoLoad(tester);

    expect(find.byKey(const Key('catalog-photo-confirmation')), findsOneWidget);
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byType(AppBar), findsNothing);
    expect(find.text('Review photo'), findsOneWidget);
    expect(find.text(catalogPhotoGuidance), findsOneWidget);
    expect(tester.getRect(find.byKey(const Key('underlying-page'))), before);
    expect(evaluator.calls, 0);
  });

  testWidgets('Use This Photo confirms the existing local selection', (
    tester,
  ) async {
    final selection = _selection();
    CatalogPhotoSelection? accepted;
    await _pumpHost(
      tester,
      selection: selection,
      onAccepted: (value) => accepted = value,
    );

    await tester.tap(find.text('Acquire'));
    await _settlePhotoLoad(tester);
    await _useAndConfirm(tester);

    expect(accepted, same(selection));
  });

  testWidgets('review transitions to framing in one sheet with one image', (
    tester,
  ) async {
    await _pumpHost(tester);
    await tester.tap(find.text('Acquire'));
    await _settlePhotoLoad(tester);
    final imageElement = tester.element(
      find.byKey(const Key('subject-selection-image')),
    );

    await tester.tap(find.text('Use This Photo'));
    await _settleFraming(tester);

    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('Review photo'), findsNothing);
    expect(find.text('Frame your collectible'), findsOneWidget);
    expect(
      identical(
        tester.element(find.byKey(const Key('subject-selection-image'))),
        imageElement,
      ),
      isTrue,
    );
    expect(find.byKey(const Key('subject-selection-overlay')), findsOneWidget);
  });

  testWidgets('retake replaces the preview selection', (tester) async {
    final replacement = _selection(
      source: CatalogPhotoSource.camera,
      color: image.ColorRgb8(20, 160, 100),
    );
    final acquirer = _FakePhotoAcquirer([replacement]);
    CatalogPhotoSelection? accepted;
    await _pumpHost(
      tester,
      acquirer: acquirer,
      onAccepted: (value) => accepted = value,
    );

    await tester.tap(find.text('Acquire'));
    await _settlePhotoLoad(tester);
    await tester.tap(find.text('Retake Photo'));
    await _settlePhotoLoad(tester);
    await _useAndConfirm(tester);

    expect(acquirer.requested, [CatalogPhotoSource.camera]);
    expect(accepted, same(replacement));
  });

  testWidgets('cancelled retake preserves the current preview', (tester) async {
    final initial = _selection();
    final acquirer = _FakePhotoAcquirer([null]);
    CatalogPhotoSelection? accepted;
    await _pumpHost(
      tester,
      selection: initial,
      acquirer: acquirer,
      onAccepted: (value) => accepted = value,
    );

    await tester.tap(find.text('Acquire'));
    await _settlePhotoLoad(tester);
    await tester.tap(find.text('Retake Photo'));
    await tester.pumpAndSettle();
    await _useAndConfirm(tester);

    expect(accepted, same(initial));
  });

  testWidgets('Choose Another replaces through gallery', (tester) async {
    final replacement = _selection(color: image.ColorRgb8(30, 80, 200));
    final acquirer = _FakePhotoAcquirer([replacement]);
    CatalogPhotoSelection? accepted;
    await _pumpHost(
      tester,
      acquirer: acquirer,
      onAccepted: (value) => accepted = value,
    );

    await tester.tap(find.text('Acquire'));
    await _settlePhotoLoad(tester);
    await tester.tap(find.text('Choose Another Photo'));
    await _settlePhotoLoad(tester);
    await _useAndConfirm(tester);

    expect(acquirer.requested, [CatalogPhotoSource.gallery]);
    expect(accepted, same(replacement));
  });

  testWidgets('cancelled gallery picker preserves the current preview', (
    tester,
  ) async {
    final initial = _selection();
    final acquirer = _FakePhotoAcquirer([null]);
    CatalogPhotoSelection? accepted;
    await _pumpHost(
      tester,
      selection: initial,
      acquirer: acquirer,
      onAccepted: (value) => accepted = value,
    );

    await tester.tap(find.text('Acquire'));
    await _settlePhotoLoad(tester);
    await tester.tap(find.text('Choose Another Photo'));
    await tester.pumpAndSettle();
    await _useAndConfirm(tester);

    expect(accepted, same(initial));
  });

  testWidgets('system back dismisses without confirmation', (tester) async {
    CatalogPhotoSelection? accepted;
    await _pumpHost(tester, onAccepted: (value) => accepted = value);

    await tester.tap(find.text('Acquire'));
    await _settlePhotoLoad(tester);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(accepted, isNull);
    expect(find.byKey(const Key('catalog-photo-confirmation')), findsNothing);
  });

  testWidgets('actions use filled, outlined, and dismiss hierarchy', (
    tester,
  ) async {
    CatalogPhotoSelection? accepted;
    await _pumpHost(tester, onAccepted: (value) => accepted = value);

    await tester.tap(find.text('Acquire'));
    await _settlePhotoLoad(tester);

    expect(
      find.ancestor(
        of: find.text('Use This Photo'),
        matching: find.byType(FilledButton),
      ),
      findsOneWidget,
    );
    expect(
      find.ancestor(
        of: find.text('Retake Photo'),
        matching: find.byType(OutlinedButton),
      ),
      findsOneWidget,
    );
    expect(
      find.ancestor(
        of: find.text('Choose Another Photo'),
        matching: find.byType(OutlinedButton),
      ),
      findsOneWidget,
    );
    expect(
      find.ancestor(of: find.text('Cancel'), matching: find.byType(TextButton)),
      findsOneWidget,
    );
    expect(
      tester.getSize(find.byKey(const Key('catalog-photo-use'))).height,
      52,
    );
    expect(
      tester.getSize(find.byKey(const Key('catalog-photo-retake'))).height,
      52,
    );
    expect(
      tester
          .getSize(find.byKey(const Key('catalog-photo-choose-another')))
          .height,
      52,
    );
    expect(
      tester.getSize(find.byKey(const Key('catalog-photo-cancel'))).height,
      48,
    );

    await tester.ensureVisible(find.text('Cancel'));
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(accepted, isNull);
    expect(find.byKey(const Key('catalog-photo-confirmation')), findsNothing);
  });

  testWidgets('validation failures stay on review with safe recovery UI', (
    tester,
  ) async {
    final evaluator = _FakeEvaluator(
      WholeImageQualityOutcome.obviouslyTooBlurry,
    );
    await _pumpHost(tester, evaluator: evaluator);

    await tester.tap(find.text('Acquire'));
    await _settlePhotoLoad(tester);
    expect(evaluator.calls, 0);
    await tester.tap(find.text('Use This Photo'));
    await tester.pumpAndSettle();

    expect(evaluator.calls, 1);
    expect(
      find.byKey(const Key('catalog-photo-validation-error')),
      findsOneWidget,
    );
    expect(find.text('This photo is too blurry'), findsOneWidget);
    expect(
      find.text(
        'Hold your phone steady and keep the collectible in focus before '
        'trying again.',
      ),
      findsOneWidget,
    );
    expect(find.text('Retake Photo'), findsOneWidget);
    expect(find.text('Choose Another Photo'), findsOneWidget);
    expect(find.text('Use This Photo'), findsNothing);
    expect(find.textContaining('Laplacian'), findsNothing);
    expect(find.textContaining('threshold'), findsNothing);

    await tester.tap(find.byKey(const Key('catalog-photo-close')));
    await tester.pumpAndSettle();
  });

  testWidgets('evaluation unavailable fails open', (tester) async {
    final evaluator = _FakeEvaluator(
      WholeImageQualityOutcome.evaluationUnavailable,
    );
    CatalogPhotoSelection? accepted;
    await _pumpHost(
      tester,
      evaluator: evaluator,
      onAccepted: (value) => accepted = value,
    );

    await tester.tap(find.text('Acquire'));
    await _settlePhotoLoad(tester);
    await _useAndConfirm(tester);

    expect(accepted, isNotNull);
    expect(
      find.byKey(const Key('catalog-photo-validation-error')),
      findsNothing,
    );
  });

  testWidgets(
    'Use This Photo keeps one sheet mounted through locating and applies suggestion',
    (tester) async {
      final photo = _selection();
      final locator = _ControlledSubjectLocator();
      CatalogSubjectSelectionResult? confirmed;
      await _pumpHost(
        tester,
        selection: photo,
        locatorGateway: locator,
        onResult: (result) => confirmed = result,
      );

      await tester.tap(find.text('Acquire'));
      await _settlePhotoLoad(tester);
      final sheetElement = tester.element(
        find.byType(CatalogPhotoVerificationPage),
      );
      await tester.tap(find.text('Use This Photo'));
      await tester.pump();

      expect(locator.photos, [same(photo)]);
      expect(find.text('Finding the collectible…'), findsOneWidget);
      expect(find.byKey(const Key('subject-locator-progress')), findsOneWidget);
      expect(
        tester.element(find.byType(CatalogPhotoVerificationPage)),
        same(sheetElement),
      );

      locator.pending.single.complete(
        const CatalogSubjectLocatorSuggestion(
          rect: NormalizedSubjectRect(
            left: 0.1,
            top: 0.2,
            right: 0.7,
            bottom: 0.8,
          ),
          orientedSize: Size(16, 16),
        ),
      );
      await _settleFraming(tester);

      expect(find.text('AI suggested this frame. Adjust if needed.'), findsOneWidget);
      expect(
        tester.element(find.byType(CatalogPhotoVerificationPage)),
        same(sheetElement),
      );
      final box = tester.getRect(find.byKey(const Key('subject-selection-box')));
      final imageRect = tester.getRect(find.byKey(const Key('subject-selection-image')));
      expect((box.left - imageRect.left) / imageRect.width, closeTo(0.1, 0.02));
      expect((box.top - imageRect.top) / imageRect.height, closeTo(0.2, 0.02));
      await tester.ensureVisible(find.text('Continue'));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(confirmed!.photo, same(photo));
      expect(confirmed!.origin, SubjectSelectionOrigin.suggestedBox);
      expect(confirmed!.normalizedRect.left, 0.1);
      expect(confirmed!.normalizedRect.top, 0.2);
    },
  );

  testWidgets('editing hides AI copy and reset restores genuine suggestion', (
    tester,
  ) async {
    final locator = _FakeSubjectLocator(
      const CatalogSubjectLocatorSuggestion(
        rect: NormalizedSubjectRect(
          left: 0.15,
          top: 0.15,
          right: 0.75,
          bottom: 0.75,
        ),
        orientedSize: Size(16, 16),
      ),
    );
    await _pumpHost(tester, locatorGateway: locator);
    await tester.tap(find.text('Acquire'));
    await _settlePhotoLoad(tester);
    await tester.tap(find.text('Use This Photo'));
    await _settleFraming(tester);

    final selectionBox = find.byKey(const Key('subject-selection-box'));
    await tester.ensureVisible(selectionBox);
    await tester.pump(const Duration(milliseconds: 220));
    final before = tester.getRect(selectionBox);
    await tester.drag(
      selectionBox,
      const Offset(30, 8),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));
    expect(tester.getRect(selectionBox).left, greaterThan(before.left));
    expect(find.text('AI suggested this frame. Adjust if needed.'), findsNothing);

    await tester.ensureVisible(find.text('Reset Selection'));
    await tester.tap(find.text('Reset Selection'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));
    expect(find.text('AI suggested this frame. Adjust if needed.'), findsOneWidget);

    final imageRect = tester.getRect(
      find.byKey(const Key('subject-selection-image')),
    );
    await tester.dragFrom(
      imageRect.topLeft + const Offset(12, 12),
      const Offset(90, 10),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));
    expect(find.text('AI suggested this frame. Adjust if needed.'), findsNothing);
    expect(locator.calls, 1);
  });

  testWidgets('no suggestion, unavailable, and inconsistent dimensions fall back silently', (
    tester,
  ) async {
    final results = <CatalogSubjectLocatorResult>[
      const CatalogSubjectLocatorNoSuggestion(),
      const CatalogSubjectLocatorUnavailable(reason: 'locator_timeout'),
      const CatalogSubjectLocatorSuggestion(
        rect: NormalizedSubjectRect(
          left: 0.1,
          top: 0.1,
          right: 0.8,
          bottom: 0.8,
        ),
        orientedSize: Size(40, 10),
      ),
    ];
    for (final result in results) {
      await _pumpHost(tester, locatorGateway: _FakeSubjectLocator(result));
      await tester.tap(find.text('Acquire'));
      await _settlePhotoLoad(tester);
      await tester.tap(find.text('Use This Photo'));
      await _settleFraming(tester);

      expect(find.text('AI suggested this frame. Adjust if needed.'), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      final box = tester.getRect(find.byKey(const Key('subject-selection-box')));
      final imageRect = tester.getRect(find.byKey(const Key('subject-selection-image')));
      expect(box.width / imageRect.width, closeTo(0.6, 0.02));
      expect(box.height / imageRect.height, closeTo(0.6, 0.02));
      await tester.tap(find.byKey(const Key('catalog-photo-close')));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('duplicate submissions call locator once and close ignores completion', (
    tester,
  ) async {
    final locator = _ControlledSubjectLocator();
    await _pumpHost(tester, locatorGateway: locator);
    await tester.tap(find.text('Acquire'));
    await _settlePhotoLoad(tester);

    await tester.tap(find.text('Use This Photo'));
    await tester.tap(find.text('Use This Photo'));
    await tester.pump();
    expect(locator.photos, hasLength(1));

    await tester.tap(find.byKey(const Key('catalog-photo-close')));
    await tester.pumpAndSettle();
    locator.pending.single.complete(
      const CatalogSubjectLocatorNoSuggestion(),
    );
    await tester.pump();
    expect(find.byType(CatalogPhotoVerificationPage), findsNothing);
    expect(tester.takeException(), isNull);
    expect(locator.cancellations, greaterThan(0));
  });

  testWidgets('recovery replacement reruns evaluation and continues', (
    tester,
  ) async {
    final replacement = _selection(color: image.ColorRgb8(20, 160, 100));
    final evaluator = _FakeEvaluator(
      WholeImageQualityOutcome.obviouslyTooBlurry,
    );
    final acquirer = _FakePhotoAcquirer([replacement]);
    CatalogPhotoSelection? accepted;
    await _pumpHost(
      tester,
      evaluator: evaluator,
      acquirer: acquirer,
      onAccepted: (value) => accepted = value,
    );

    await tester.tap(find.text('Acquire'));
    await _settlePhotoLoad(tester);
    await tester.tap(find.text('Use This Photo'));
    await tester.pumpAndSettle();
    evaluator.outcome = WholeImageQualityOutcome.usable;
    await tester.tap(find.text('Choose Another Photo'));
    await _settleFraming(tester);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(evaluator.calls, 2);
    expect(accepted, same(replacement));
  });

  testWidgets('cancelled recovery replacement preserves recovery state', (
    tester,
  ) async {
    final evaluator = _FakeEvaluator(
      WholeImageQualityOutcome.obviouslyTooBlurry,
    );
    await _pumpHost(
      tester,
      evaluator: evaluator,
      acquirer: _FakePhotoAcquirer([null]),
    );

    await tester.tap(find.text('Acquire'));
    await _settlePhotoLoad(tester);
    await tester.tap(find.text('Use This Photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retake Photo'));
    await tester.pumpAndSettle();

    expect(evaluator.calls, 1);
    expect(find.text('This photo is too blurry'), findsOneWidget);
  });

  testWidgets('stale evaluation cannot overwrite a replacement result', (
    tester,
  ) async {
    final initial = _selection();
    final replacement = _selection(color: image.ColorRgb8(20, 160, 100));
    final evaluator = _ControlledEvaluator();
    CatalogPhotoSelection? accepted;
    await _pumpHost(
      tester,
      selection: initial,
      evaluator: evaluator,
      acquirer: _FakePhotoAcquirer([replacement]),
      onAccepted: (value) => accepted = value,
    );

    await tester.tap(find.text('Acquire'));
    await _settlePhotoLoad(tester);
    await tester.tap(find.text('Use This Photo'));
    await tester.pump();
    await tester.tap(find.text('Choose Another Photo'));
    for (
      var attempt = 0;
      attempt < 20 && evaluator.pending.length < 2;
      attempt++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 25)),
      );
      await tester.pump();
    }
    expect(evaluator.selections, [initial, replacement]);

    evaluator.pending[0].complete(
      const WholeImageQualityResult(
        outcome: WholeImageQualityOutcome.obviouslyTooBlurry,
        evaluatorVersion: 'stale',
      ),
    );
    await tester.pump();
    expect(find.text('This photo is too blurry'), findsNothing);

    evaluator.pending[1].complete(
      const WholeImageQualityResult(
        outcome: WholeImageQualityOutcome.usable,
        evaluatorVersion: 'current',
      ),
    );
    await _settleFraming(tester);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(accepted, same(replacement));
  });

  testWidgets('portrait and landscape previews do not stretch', (tester) async {
    for (final size in [(120, 240), (240, 120)]) {
      await _pumpHost(
        tester,
        selection: _selection(width: size.$1, height: size.$2),
      );
      await tester.tap(find.text('Acquire'));
      await _settlePhotoLoad(tester);

      final previewRect = tester.getRect(
        find.byKey(const Key('subject-selection-image')),
      );
      final viewportRect = tester.getRect(
        find.byKey(const Key('subject-selection-viewport')),
      );
      expect(previewRect.left, greaterThanOrEqualTo(viewportRect.left));
      expect(previewRect.top, greaterThanOrEqualTo(viewportRect.top));
      expect(previewRect.right, lessThanOrEqualTo(viewportRect.right));
      expect(previewRect.bottom, lessThanOrEqualTo(viewportRect.bottom));
      expect(
        previewRect.width / previewRect.height,
        closeTo(size.$1 / size.$2, 0.01),
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const Key('catalog-photo-close')));
      await tester.pumpAndSettle();
    }
  });

  testWidgets(
    'small screen and large text remain scrollable without overflow',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 520));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await _pumpHost(tester, textScaler: const TextScaler.linear(2));

      await tester.tap(find.text('Acquire'));
      await _settlePhotoLoad(tester);

      expect(find.byType(SingleChildScrollView), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _pumpHost(
  WidgetTester tester, {
  CatalogPhotoSelection? selection,
  WholeImageQualityEvaluator? evaluator,
  CatalogPhotoAcquirer? acquirer,
  CatalogSubjectLocator? locatorGateway,
  ValueChanged<CatalogPhotoSelection>? onAccepted,
  ValueChanged<CatalogSubjectSelectionResult>? onResult,
  GlobalKey? hostKey,
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  final selected = selection ?? _selection();
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: child!,
      ),
      home: Scaffold(
        key: hostKey,
        body: Container(
          key: const Key('underlying-page'),
          color: Colors.white,
          alignment: Alignment.center,
          child: Builder(
            builder: (context) => FilledButton(
              onPressed: () async {
                final accepted = await showCatalogPhotoScanSheet(
                  context,
                  selected,
                  evaluator:
                      evaluator ??
                      _FakeEvaluator(WholeImageQualityOutcome.usable),
                  photoAcquirer: acquirer,
                  locatorGateway:
                      locatorGateway ?? _FakeSubjectLocator(),
                );
                if (accepted != null) {
                  onResult?.call(accepted);
                  onAccepted?.call(accepted.photo);
                }
              },
              child: const Text('Acquire'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _settlePhotoLoad(WidgetTester tester) async {
  for (var attempt = 0; attempt < 20; attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 25)),
    );
    await tester.pump();
    if (find
        .byKey(const Key('subject-selection-image'))
        .evaluate()
        .isNotEmpty) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 250));
      return;
    }
  }
  fail('Photo did not finish decoding.');
}

Future<void> _settleFraming(WidgetTester tester) async {
  for (var attempt = 0; attempt < 20; attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 25)),
    );
    await tester.pump();
    if (find.text('Continue').evaluate().isNotEmpty) {
      await tester.pump(const Duration(milliseconds: 200));
      return;
    }
  }
  fail('Framing state did not appear.');
}

Future<void> _useAndConfirm(WidgetTester tester) async {
  await tester.tap(find.text('Use This Photo'));
  await _settleFraming(tester);
  await tester.ensureVisible(find.text('Continue'));
  await tester.tap(find.text('Continue'));
  await tester.pumpAndSettle();
}

CatalogPhotoSelection _selection({
  CatalogPhotoSource source = CatalogPhotoSource.gallery,
  int width = 16,
  int height = 16,
  image.Color? color,
}) {
  final preview = image.Image(width: width, height: height)
    ..clear(color ?? image.ColorRgb8(120, 90, 180));
  return CatalogPhotoSelection(
    file: XFile.fromData(
      Uint8List.fromList(image.encodePng(preview)),
      name: 'photo.png',
      mimeType: 'image/png',
    ),
    source: source,
  );
}

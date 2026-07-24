import 'dart:async';
import 'dart:typed_data';

import 'package:blindbox_app/core/theme/collectible_motion.dart';
import 'package:blindbox_app/core/theme/collectible_typography.dart';
import 'package:blindbox_app/shared/image/catalog_photo_acquisition.dart';
import 'package:blindbox_app/shared/image/catalog_figure_recognition.dart';
import 'package:blindbox_app/shared/image/catalog_subject_locator_gateway.dart';
import 'package:blindbox_app/shared/image/catalog_subject_selection.dart';
import 'package:blindbox_app/shared/image/whole_image_quality.dart';
import 'package:blindbox_app/shared/widgets/catalog_photo_verification_page.dart';
import 'package:blindbox_app/shared/widgets/collectible_browse_card.dart';
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
    expect(find.text('Looks good'), findsOneWidget);
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
    expect(find.text('Looks good'), findsNothing);
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
        matching: find.byType(TextButton),
      ),
      findsOneWidget,
    );
    expect(
      find.ancestor(of: find.text('Cancel'), matching: find.byType(TextButton)),
      findsOneWidget,
    );
    expect(
      tester.getSize(find.byKey(const Key('catalog-photo-use'))).height,
      greaterThanOrEqualTo(56),
    );
    expect(
      tester.getSize(find.byKey(const Key('catalog-photo-retake'))).height,
      greaterThanOrEqualTo(48),
    );
    expect(
      tester
          .getSize(find.byKey(const Key('catalog-photo-choose-another')))
          .height,
      greaterThanOrEqualTo(44),
    );
    expect(
      tester.getSize(find.byKey(const Key('catalog-photo-cancel'))).height,
      greaterThanOrEqualTo(44),
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
    expect(find.text('This photo is too soft'), findsOneWidget);
    expect(
      find.text(
        'Hold steady and keep the collectible in focus, then try again.',
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
    'Use This Photo shows default framing immediately and applies suggestion',
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
      await _settleFraming(tester);

      expect(locator.photos, [same(photo)]);
      expect(find.text('Frame your collectible'), findsOneWidget);
      expect(
        find.text('Suggested frame — adjust if you like.'),
        findsNothing,
      );
      expect(find.byKey(const Key('subject-locator-progress')), findsNothing);
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

      expect(
        find.text('Suggested frame — adjust if you like.'),
        findsOneWidget,
      );
      expect(
        tester.element(find.byType(CatalogPhotoVerificationPage)),
        same(sheetElement),
      );
      final box = tester.getRect(
        find.byKey(const Key('subject-selection-box')),
      );
      final imageRect = tester.getRect(
        find.byKey(const Key('subject-selection-image')),
      );
      expect((box.left - imageRect.left) / imageRect.width, closeTo(0.1, 0.02));
      expect((box.top - imageRect.top) / imageRect.height, closeTo(0.2, 0.02));
      await tester.ensureVisible(find.text('Continue'));
      await tester.tap(find.text('Continue'));
      await _confirmFirstCandidate(tester);
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
    await tester.pump(CollectibleMotion.crossfade);
    final before = tester.getRect(selectionBox);
    await tester.drag(selectionBox, const Offset(30, 8));
    await tester.pump();
    await tester.pump(CollectibleMotion.crossfade);
    expect(tester.getRect(selectionBox).left, greaterThan(before.left));
    expect(
      find.text('Suggested frame — adjust if you like.'),
      findsNothing,
    );

    await tester.ensureVisible(find.text('Reset Selection'));
    await tester.tap(find.text('Reset Selection'));
    await tester.pump();
    await tester.pump(CollectibleMotion.crossfade);
    expect(
      find.text('Suggested frame — adjust if you like.'),
      findsOneWidget,
    );

    final imageRect = tester.getRect(
      find.byKey(const Key('subject-selection-image')),
    );
    await tester.dragFrom(
      imageRect.topLeft + const Offset(12, 12),
      const Offset(90, 10),
    );
    await tester.pump();
    await tester.pump(CollectibleMotion.crossfade);
    expect(
      find.text('Suggested frame — adjust if you like.'),
      findsNothing,
    );
    expect(locator.calls, 1);
  });

  testWidgets('late suggestion never overwrites a user-edited frame', (
    tester,
  ) async {
    final locator = _ControlledSubjectLocator();
    await _pumpHost(tester, locatorGateway: locator);
    await tester.tap(find.text('Acquire'));
    await _settlePhotoLoad(tester);
    await tester.tap(find.text('Use This Photo'));
    await _settleFraming(tester);

    final selectionBox = find.byKey(const Key('subject-selection-box'));
    final before = tester.getRect(selectionBox);
    await tester.drag(selectionBox, const Offset(24, 0));
    await tester.pump(const Duration(milliseconds: 220));
    final edited = tester.getRect(selectionBox);
    expect(edited.left, greaterThan(before.left));

    locator.pending.single.complete(
      const CatalogSubjectLocatorSuggestion(
        rect: NormalizedSubjectRect(
          left: 0.05,
          top: 0.05,
          right: 0.45,
          bottom: 0.45,
        ),
        orientedSize: Size(16, 16),
      ),
    );
    await tester.pump(const Duration(milliseconds: 250));

    expect(tester.getRect(selectionBox), edited);
    expect(
      find.text('Suggested frame — adjust if you like.'),
      findsNothing,
    );
  });

  testWidgets(
    'no suggestion, unavailable, and inconsistent dimensions fall back silently',
    (tester) async {
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

        expect(
          find.text('Suggested frame — adjust if you like.'),
          findsNothing,
        );
        expect(find.byType(SnackBar), findsNothing);
        final box = tester.getRect(
          find.byKey(const Key('subject-selection-box')),
        );
        final imageRect = tester.getRect(
          find.byKey(const Key('subject-selection-image')),
        );
        expect(box.width / imageRect.width, closeTo(0.6, 0.02));
        expect(box.height / imageRect.height, closeTo(0.6, 0.02));
        await tester.tap(find.byKey(const Key('catalog-photo-close')));
        await tester.pumpAndSettle();
      }
    },
  );

  testWidgets(
    'duplicate submissions call locator once and close ignores completion',
    (tester) async {
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
    },
  );

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
    await tester.ensureVisible(find.text('Choose Another Photo'));
    await tester.tap(find.text('Choose Another Photo'));
    await _settleFraming(tester);
    await tester.tap(find.text('Continue'));
    await _confirmFirstCandidate(tester);

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
    expect(find.text('This photo is too soft'), findsOneWidget);
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
    expect(find.text('This photo is too soft'), findsNothing);

    evaluator.pending[1].complete(
      const WholeImageQualityResult(
        outcome: WholeImageQualityOutcome.usable,
        evaluatorVersion: 'current',
      ),
    );
    await _settleFraming(tester);
    await tester.tap(find.text('Continue'));
    await _confirmFirstCandidate(tester);
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

  testWidgets('scan titles reuse Shelfy sheet typography roles', (tester) async {
    final gateway = _PendingRecognitionGateway();
    await _pumpHost(
      tester,
      recognitionCoordinator: CatalogFigureRecognitionCoordinator(gateway),
    );
    await tester.tap(find.text('Acquire'));
    await _settlePhotoLoad(tester);

    final reviewTitle = tester.widget<Text>(find.text('Looks good'));
    final scheme = Theme.of(
      tester.element(find.byKey(const Key('catalog-photo-confirmation'))),
    ).colorScheme;
    final textTheme = Theme.of(
      tester.element(find.byKey(const Key('catalog-photo-confirmation'))),
    ).textTheme;
    expect(
      reviewTitle.style,
      CollectibleTypography.seriesHeroTitle(textTheme, scheme),
    );
    expect(reviewTitle.style?.fontSize, isNot(32));

    await tester.tap(find.text('Use This Photo'));
    await _settleFraming(tester);
    final frameTitle = tester.widget<Text>(find.text('Frame your collectible'));
    expect(
      frameTitle.style,
      CollectibleTypography.seriesHeroTitle(textTheme, scheme),
    );

    await tester.tap(find.text('Continue'));
    await tester.pump();
    final findingTitle = tester.widget<Text>(
      find.text('Finding your collectible'),
    );
    expect(
      findingTitle.style,
      CollectibleTypography.seriesHeroTitle(textTheme, scheme),
    );
    expect(
      find.byKey(const Key('recognition-finding-progress')),
      findsOneWidget,
    );
    expect(find.textContaining('%'), findsNothing);
    expect(
      tester
          .widget<LinearProgressIndicator>(
            find.byKey(const Key('recognition-finding-progress-bar')),
          )
          .value,
      isNull,
    );

    gateway.pending.complete(
      const CatalogRecognitionCandidates(
        quality: CatalogSubjectQuality.good,
        decision: CatalogRecognitionDecision.highConfidence,
        candidates: [
          CatalogRecognitionCandidate(
            rank: 1,
            figureId: 'figure-a',
            figureName: 'Alpha Figure',
            seriesId: 'series-a',
            seriesName: 'Series A',
            ipId: 'ip-a',
            ipName: 'IP A',
            imageKey: 'figure-a',
          ),
        ],
      ),
    );
    await tester.pump();
    await tester.pump(CollectibleMotion.recognitionFindingMatchedSettle);
    await tester.pump();
    expect(find.text('We found a close match'), findsOneWidget);
    expect(
      find.byKey(const Key('recognition-finding-progress')),
      findsNothing,
    );
    final resultsTitle = tester.widget<Text>(
      find.text('We found a close match'),
    );
    expect(
      resultsTitle.style,
      CollectibleTypography.seriesHeroTitle(textTheme, scheme),
    );
  });

  testWidgets(
    'finding progress uses a static bar when animations are disabled',
    (tester) async {
      final gateway = _PendingRecognitionGateway();
      await _pumpHost(
        tester,
        recognitionCoordinator: CatalogFigureRecognitionCoordinator(gateway),
        disableAnimations: true,
      );
      await tester.tap(find.text('Acquire'));
      await _settlePhotoLoad(tester);
      await tester.tap(find.text('Use This Photo'));
      await _settleFraming(tester);
      await tester.tap(find.text('Continue'));
      await tester.pump();
      // Flush coordinator's Duration.zero phase hop so no timer is left pending.
      await tester.pump(const Duration(milliseconds: 1));
      final bar = find.byKey(const Key('recognition-finding-progress-bar'));
      expect(bar, findsOneWidget);
      expect(tester.widget<LinearProgressIndicator>(bar).value, 0.42);
      expect(find.textContaining('%'), findsNothing);
      expect(
        find.byKey(const Key('recognition-finding-checklist')),
        findsOneWidget,
      );
      expect(find.text('Checking silhouette…'), findsOneWidget);
      // Reduced motion still follows the paced schedule (no pulse only).
      await tester.pump(const Duration(milliseconds: 850));
      expect(find.text('Shape analyzed'), findsNothing);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();
      expect(find.text('Shape analyzed'), findsOneWidget);
      expect(find.text('Checking colors…'), findsOneWidget);
    },
  );

  testWidgets(
    'finding checklist follows the paced schedule and holds Matching',
    (tester) async {
      final gateway = _PendingRecognitionGateway();
      await _pumpHost(
        tester,
        recognitionCoordinator: CatalogFigureRecognitionCoordinator(gateway),
      );
      await tester.tap(find.text('Acquire'));
      await _settlePhotoLoad(tester);
      await tester.tap(find.text('Use This Photo'));
      await _settleFraming(tester);
      await tester.tap(find.text('Continue'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));

      expect(find.text('Checking silhouette…'), findsOneWidget);
      expect(find.text('Checking colors…'), findsNothing);
      expect(find.textContaining('%'), findsNothing);
      expect(find.textContaining('Almost done'), findsNothing);

      await tester.pump(const Duration(milliseconds: 850));
      expect(find.text('Checking colors…'), findsNothing);

      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();
      expect(find.text('Shape analyzed'), findsOneWidget);
      expect(find.text('Checking colors…'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pump();
      expect(find.text('Colors analyzed'), findsOneWidget);
      expect(find.text('Checking accessories…'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 1200));
      await tester.pump();
      expect(find.text('Accessories analyzed'), findsOneWidget);
      expect(find.text('Checking facial details…'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 1300));
      await tester.pump();
      expect(find.text('Facial details analyzed'), findsOneWidget);
      expect(find.text('Matching with the catalog…'), findsOneWidget);
      expect(find.text('Matching'), findsOneWidget);

      // Past the staged window — Matching stays active while pending.
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      expect(find.text('Matching with the catalog…'), findsOneWidget);
      expect(
        find.byKey(const Key('recognition-finding-checklist')),
        findsOneWidget,
      );
      expect(gateway.calls, 1);

      // Ordinary rebuild must not restart the sequence.
      await tester.pump();
      expect(find.text('Checking silhouette…'), findsNothing);
      expect(find.text('Matching with the catalog…'), findsOneWidget);

      gateway.pending.complete(const CatalogRecognitionNoConfidentMatch());
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('recognition-finding-checklist')),
        findsOneWidget,
      );
      expect(find.text('No close match found.'), findsOneWidget);
      expect(find.text('Shape analyzed'), findsOneWidget);
      expect(find.text('Matching with the catalog…'), findsNothing);
      expect(find.text('Matching completed'), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const Key('recognition-finding-step-4')),
          matching: find.byIcon(Icons.remove_rounded),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('recognition-finding-step-4')),
          matching: find.byIcon(Icons.check_rounded),
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    'no-match keeps checklist continuity and finding photo size',
    (tester) async {
      final gateway = _PendingRecognitionGateway();
      await _pumpHost(
        tester,
        recognitionCoordinator: CatalogFigureRecognitionCoordinator(gateway),
      );
      await tester.tap(find.text('Acquire'));
      await _settlePhotoLoad(tester);
      await tester.tap(find.text('Use This Photo'));
      await _settleFraming(tester);
      await tester.tap(find.text('Continue'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));

      final findingCrop = tester.getSize(
        find.byKey(const ValueKey('recognition-crop-slot')),
      );
      expect(find.text('Checking silhouette…'), findsOneWidget);

      gateway.pending.complete(const CatalogRecognitionNoConfidentMatch());
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('recognition-finding-checklist')),
        findsOneWidget,
      );
      expect(find.text('Checking silhouette…'), findsNothing);
      expect(find.text('Shape analyzed'), findsOneWidget);
      expect(find.text('Colors analyzed'), findsOneWidget);
      expect(find.text('Accessories analyzed'), findsOneWidget);
      expect(find.text('Facial details analyzed'), findsOneWidget);
      expect(find.text('No close match found.'), findsOneWidget);
      expect(find.text('Matching with the catalog…'), findsNothing);
      expect(find.text('Matching completed'), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const Key('recognition-finding-step-4')),
          matching: find.byIcon(Icons.remove_rounded),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('recognition-finding-step-4')),
          matching: find.byIcon(Icons.check_rounded),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('recognition-finding-step-4')),
          matching: find.byIcon(Icons.close_rounded),
        ),
        findsNothing,
      );
      expect(
        tester.getSize(find.byKey(const Key('recognition-finding-checklist')))
            .width,
        lessThanOrEqualTo(360),
      );
      expect(
        find.byKey(const Key('recognition-finding-progress')),
        findsNothing,
      );
      expect(find.text('We couldn’t find a close match.'), findsOneWidget);
      expect(
        find.text(
          'We compared your photo with the Shelfy catalog, but couldn’t identify a confident match.',
        ),
        findsOneWidget,
      );
      expect(
        tester.getSize(find.byKey(const ValueKey('recognition-crop-slot'))).height,
        findingCrop.height,
      );
      expect(find.text('Try Another Photo'), findsOneWidget);
      expect(find.text('Adjust Frame'), findsOneWidget);
      expect(find.text('Create Custom Figure'), findsOneWidget);
      expect(find.textContaining('%'), findsNothing);

      // Soften after settle — checklist remains, not removed.
      final faded = tester.widget<AnimatedOpacity>(
        find.ancestor(
          of: find.byKey(const Key('recognition-finding-checklist')),
          matching: find.byType(AnimatedOpacity),
        ),
      );
      expect(
        faded.opacity,
        CollectibleMotion.recognitionFindingNoMatchChecklistOpacity,
      );
      expect(
        find.byKey(const Key('recognition-finding-checklist')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'early recognition result settles Matching as ⊖ with no-match subtitle',
    (tester) async {
      final gateway = _PendingRecognitionGateway();
      await _pumpHost(
        tester,
        recognitionCoordinator: CatalogFigureRecognitionCoordinator(gateway),
      );
      await tester.tap(find.text('Acquire'));
      await _settlePhotoLoad(tester);
      await tester.tap(find.text('Use This Photo'));
      await _settleFraming(tester);
      await tester.tap(find.text('Continue'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.text('Checking silhouette…'), findsOneWidget);

      gateway.pending.complete(const CatalogRecognitionNoConfidentMatch());
      await tester.pumpAndSettle();
      expect(find.text('Checking silhouette…'), findsNothing);
      expect(find.text('Matching with the catalog…'), findsNothing);
      expect(find.text('No close match found.'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('recognition-finding-step-4')),
          matching: find.byIcon(Icons.remove_rounded),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('recognition-finding-step-4')),
          matching: find.byIcon(Icons.check_rounded),
        ),
        findsNothing,
      );
      expect(
        find.byKey(const Key('recognition-finding-checklist')),
        findsOneWidget,
      );
      expect(find.text('We couldn’t find a close match.'), findsOneWidget);
    },
  );

  testWidgets(
    'Continue enters recognition loading immediately with the selected crop and blocks duplicates',
    (tester) async {
      final gateway = _PendingRecognitionGateway();
      await _pumpHost(
        tester,
        recognitionCoordinator: CatalogFigureRecognitionCoordinator(gateway),
      );
      await tester.tap(find.text('Acquire'));
      await _settlePhotoLoad(tester);
      await tester.tap(find.text('Use This Photo'));
      await _settleFraming(tester);

      await tester.tap(find.text('Continue'));
      await tester.pump();

      expect(find.text('Finding your collectible'), findsOneWidget);
      expect(
        find.text('Comparing with the Shelfy catalog.'),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('recognition-finding-progress')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('recognition-finding-checklist')),
        findsOneWidget,
      );
      expect(find.text('Shape'), findsOneWidget);
      expect(find.text('Checking silhouette…'), findsOneWidget);
      expect(find.byType(ListTile), findsNothing);
      expect(find.byIcon(Icons.chevron_right), findsNothing);
      expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
      expect(
        find.byKey(const Key('recognition-selected-crop-preview')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('recognition-finding-crop-shimmer')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('subject-locator-progress')), findsNothing);
      await tester.pump(const Duration(milliseconds: 1));
      expect(gateway.calls, 1);

      await tester.pump(CollectibleMotion.recognitionFindingShapeComplete);
      await tester.pump();
      expect(find.text('Shape analyzed'), findsOneWidget);
      expect(find.text('Checking colors…'), findsOneWidget);
      // Still a single recognition attempt while the checklist advances.
      expect(gateway.calls, 1);

      gateway.pending.complete(const CatalogRecognitionNoConfidentMatch());
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('recognition-finding-progress')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('recognition-finding-checklist')),
        findsOneWidget,
      );
      expect(find.text('No close match found.'), findsOneWidget);
    },
  );

  testWidgets(
    'Matching status reflects outcome: ● pending, ✓ candidates, ⊖ no-match',
    (tester) async {
      final gateway = _PendingRecognitionGateway();
      await _pumpHost(
        tester,
        recognitionCoordinator: CatalogFigureRecognitionCoordinator(gateway),
      );
      await tester.tap(find.text('Acquire'));
      await _settlePhotoLoad(tester);
      await tester.tap(find.text('Use This Photo'));
      await _settleFraming(tester);
      await tester.tap(find.text('Continue'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));

      // Untouched later rows stay pending ○ (outlined, no check/dash).
      expect(find.text('Checking silhouette…'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('recognition-finding-step-0')),
          matching: find.byIcon(Icons.check_rounded),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('recognition-finding-step-4')),
          matching: find.byIcon(Icons.check_rounded),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('recognition-finding-step-4')),
          matching: find.byIcon(Icons.remove_rounded),
        ),
        findsNothing,
      );

      // Advance to Matching ● (active filled primary, no check).
      await tester.pump(CollectibleMotion.recognitionFindingFacialComplete);
      await tester.pump();
      expect(find.text('Matching with the catalog…'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('recognition-finding-step-4')),
          matching: find.byIcon(Icons.check_rounded),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('recognition-finding-step-3')),
          matching: find.byIcon(Icons.check_rounded),
        ),
        findsOneWidget,
      );

      gateway.pending.complete(
        const CatalogRecognitionCandidates(
          quality: CatalogSubjectQuality.good,
          decision: CatalogRecognitionDecision.highConfidence,
          candidates: [
            CatalogRecognitionCandidate(
              rank: 1,
              figureId: 'figure-a',
              figureName: 'Alpha Figure',
              seriesId: 'series-a',
              seriesName: 'Series A',
              ipId: 'ip-a',
              ipName: 'IP A',
              imageKey: 'figure-a',
            ),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(CollectibleMotion.recognitionFindingStatusCrossfade);
      // Successful resolve: Matching becomes ✓ before candidate cards.
      expect(
        find.descendant(
          of: find.byKey(const Key('recognition-finding-step-4')),
          matching: find.byIcon(Icons.check_rounded),
        ),
        findsOneWidget,
      );
      expect(find.text('Matching completed'), findsOneWidget);
      expect(
        find.byKey(const Key('recognition-finding-progress')),
        findsNothing,
      );

      await tester.pump(CollectibleMotion.recognitionFindingMatchedSettle);
      await tester.pump();
      expect(find.text('We found a close match'), findsOneWidget);
      expect(
        find.byKey(const Key('recognition-finding-checklist')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'needs_review settles Matching as ✓ like high_confidence',
    (tester) async {
      final gateway = _PendingRecognitionGateway();
      await _pumpHost(
        tester,
        recognitionCoordinator: CatalogFigureRecognitionCoordinator(gateway),
      );
      await tester.tap(find.text('Acquire'));
      await _settlePhotoLoad(tester);
      await tester.tap(find.text('Use This Photo'));
      await _settleFraming(tester);
      await tester.tap(find.text('Continue'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));

      await tester.pump(CollectibleMotion.recognitionFindingFacialComplete);
      await tester.pump();
      expect(find.text('Matching with the catalog…'), findsOneWidget);

      gateway.pending.complete(
        const CatalogRecognitionCandidates(
          quality: CatalogSubjectQuality.good,
          decision: CatalogRecognitionDecision.needsReview,
          candidates: [
            CatalogRecognitionCandidate(
              rank: 1,
              figureId: 'figure-a',
              figureName: 'Alpha Figure',
              seriesId: 'series-a',
              seriesName: 'Series A',
              ipId: 'ip-a',
              ipName: 'IP A',
              imageKey: 'figure-a',
            ),
            CatalogRecognitionCandidate(
              rank: 2,
              figureId: 'figure-b',
              figureName: 'Beta Figure',
              seriesId: 'series-b',
              seriesName: 'Series B',
              ipId: 'ip-b',
              ipName: 'IP B',
              imageKey: 'figure-b',
            ),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(CollectibleMotion.recognitionFindingStatusCrossfade);
      expect(
        find.descendant(
          of: find.byKey(const Key('recognition-finding-step-4')),
          matching: find.byIcon(Icons.check_rounded),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('recognition-finding-step-4')),
          matching: find.byIcon(Icons.remove_rounded),
        ),
        findsNothing,
      );
      expect(find.text('Matching completed'), findsOneWidget);

      await tester.pump(CollectibleMotion.recognitionFindingMatchedSettle);
      await tester.pump();
      expect(find.text('We found a few close matches'), findsOneWidget);
      expect(find.text('Best Match'), findsOneWidget);
    },
  );

  testWidgets(
    'no_confident_match settles Matching as ⊖ not ✓',
    (tester) async {
      final gateway = _PendingRecognitionGateway();
      await _pumpHost(
        tester,
        recognitionCoordinator: CatalogFigureRecognitionCoordinator(gateway),
      );
      await tester.tap(find.text('Acquire'));
      await _settlePhotoLoad(tester);
      await tester.tap(find.text('Use This Photo'));
      await _settleFraming(tester);
      await tester.tap(find.text('Continue'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));

      await tester.pump(CollectibleMotion.recognitionFindingFacialComplete);
      await tester.pump();
      expect(find.text('Matching with the catalog…'), findsOneWidget);

      gateway.pending.complete(const CatalogRecognitionNoConfidentMatch());
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const Key('recognition-finding-step-4')),
          matching: find.byIcon(Icons.remove_rounded),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('recognition-finding-step-4')),
          matching: find.byIcon(Icons.check_rounded),
        ),
        findsNothing,
      );
      expect(find.text('No close match found.'), findsOneWidget);
      expect(find.text('Matching completed'), findsNothing);
      // Earlier analysis steps remain successfully completed.
      expect(
        find.descendant(
          of: find.byKey(const Key('recognition-finding-step-0')),
          matching: find.byIcon(Icons.check_rounded),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'borderline candidates remain in the single loading and recognition attempt',
    (tester) async {
      final gateway = _PendingRecognitionGateway();
      await _pumpHost(
        tester,
        recognitionCoordinator: CatalogFigureRecognitionCoordinator(gateway),
      );
      await tester.tap(find.text('Acquire'));
      await _settlePhotoLoad(tester);
      await tester.tap(find.text('Use This Photo'));
      await _settleFraming(tester);
      await tester.tap(find.text('Continue'));
      await tester.pump();

      expect(find.text('Finding your collectible'), findsOneWidget);
      expect(find.text('Photo may be a little soft'), findsNothing);
      expect(find.text('Continue Anyway'), findsNothing);
      await tester.pump(const Duration(milliseconds: 1));
      expect(gateway.calls, 1);

      gateway.pending.complete(
        const CatalogRecognitionCandidates(
          quality: CatalogSubjectQuality.borderline,
          candidates: [
            CatalogRecognitionCandidate(
              rank: 1,
              figureId: 'borderline-figure',
              figureName: 'Borderline Figure',
              seriesId: 'series',
              seriesName: 'Series',
              ipId: 'ip',
              ipName: 'IP',
              imageKey: 'borderline-figure',
            ),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(CollectibleMotion.recognitionFindingMatchedSettle);
      await tester.pump();
      expect(find.text('We found a few close matches'), findsOneWidget);
      expect(
        find.text('Choose the collectible that looks most like yours.'),
        findsOneWidget,
      );
      expect(find.text('Create Custom Figure'), findsOneWidget);
      expect(find.text('Not seeing yours?'), findsOneWidget);
      expect(find.text('Photo may be a little soft'), findsNothing);
      expect(find.text('Continue Anyway'), findsNothing);
      expect(gateway.calls, 1);
    },
  );

  testWidgets('candidate card tap confirms without a separate button', (
    tester,
  ) async {
    CatalogRecognitionCandidate? confirmed;
    final gateway = _FakeRecognitionGateway();
    await _pumpHost(
      tester,
      recognitionCoordinator: CatalogFigureRecognitionCoordinator(gateway),
      onCandidateConfirmed: (candidate) => confirmed = candidate,
    );
    await tester.tap(find.text('Acquire'));
    await _settlePhotoLoad(tester);
    await tester.tap(find.text('Use This Photo'));
    await _settleFraming(tester);
    await tester.tap(find.text('Continue'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('We found a few close matches'), findsOneWidget);
    expect(find.text('This Is It'), findsNothing);
    expect(find.byKey(const Key('catalog-photo-confirmation')), findsOneWidget);
    final candidate = find.byKey(const Key('recognition-candidate-figure-test'));
    tester.widget<CollectibleBrowseCard>(candidate).onTap();
    await tester.pump();
    await tester.pump(CollectibleMotion.crossfade);
    expect(confirmed?.figureId, 'figure-test');
    // Scan sheet stays open so Series detail can stack above results.
    expect(find.byKey(const Key('catalog-photo-confirmation')), findsOneWidget);
    expect(find.text('We found a few close matches'), findsOneWidget);
  });

  testWidgets('motion polish: crop persists, Best Match, haptic, cascade', (
    tester,
  ) async {
    var haptics = 0;
    final gateway = _PendingRecognitionGateway();
    await _pumpHost(
      tester,
      recognitionCoordinator: CatalogFigureRecognitionCoordinator(gateway),
      selectionHaptic: () => haptics++,
    );
    await tester.tap(find.text('Acquire'));
    await _settlePhotoLoad(tester);
    await tester.tap(find.text('Use This Photo'));
    await _settleFraming(tester);
    await tester.tap(find.text('Continue'));
    await tester.pump();

    expect(find.text('Finding your collectible'), findsOneWidget);
    expect(
      find.text('Comparing with the Shelfy catalog.'),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('recognition-finding-progress')),
      findsOneWidget,
    );
    final findingCrop = find.byKey(
      const Key('recognition-selected-crop-preview'),
    );
    expect(findingCrop, findsOneWidget);
    expect(
      find.byKey(const Key('recognition-finding-crop-shimmer')),
      findsOneWidget,
    );
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(haptics, 0);

    gateway.pending.complete(
      const CatalogRecognitionCandidates(
        quality: CatalogSubjectQuality.good,
        candidates: [
          CatalogRecognitionCandidate(
            rank: 1,
            figureId: 'figure-a',
            figureName: 'Alpha Figure',
            seriesId: 'series-a',
            seriesName: 'Series A',
            ipId: 'ip-a',
            ipName: 'IP A',
            imageKey: 'figure-a',
          ),
          CatalogRecognitionCandidate(
            rank: 2,
            figureId: 'figure-b',
            figureName: 'Beta Figure',
            seriesId: 'series-b',
            seriesName: 'Series B',
            ipId: 'ip-b',
            ipName: 'IP B',
            imageKey: 'figure-b',
          ),
          CatalogRecognitionCandidate(
            rank: 3,
            figureId: 'figure-c',
            figureName: 'Gamma Figure',
            seriesId: 'series-c',
            seriesName: 'Series C',
            ipId: 'ip-c',
            ipName: 'IP C',
            imageKey: 'figure-c',
          ),
        ],
      ),
    );
    for (var attempt = 0; attempt < 20; attempt++) {
      await tester.pump(const Duration(milliseconds: 20));
      if (find.text('We found a few close matches').evaluate().isNotEmpty) {
        break;
      }
    }
    expect(haptics, 1);
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('We found a few close matches'), findsOneWidget);
    expect(
      find.text('Choose the collectible that looks most like yours.'),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('recognition-selected-crop-preview')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('recognition-finding-crop-shimmer')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('recognition-finding-progress')),
      findsNothing,
    );
    expect(find.textContaining('%'), findsNothing);
    expect(find.text('Best Match'), findsOneWidget);
    expect(find.byKey(const Key('recognition-best-match-label')), findsOneWidget);

    final firstCard = find.byKey(const Key('recognition-candidate-figure-a'));
    final secondCard = find.byKey(const Key('recognition-candidate-figure-b'));
    final thirdCard = find.byKey(const Key('recognition-candidate-figure-c'));
    expect(firstCard, findsOneWidget);
    expect(secondCard, findsOneWidget);
    expect(thirdCard, findsOneWidget);
    expect(
      tester.getTopLeft(firstCard).dy,
      lessThan(tester.getTopLeft(secondCard).dy),
    );
    expect(
      tester.getTopLeft(secondCard).dy,
      lessThan(tester.getTopLeft(thirdCard).dy),
    );
    expect(
      find.descendant(
        of: firstCard,
        matching: find.text('Best Match'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: secondCard,
        matching: find.text('Best Match'),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: thirdCard,
        matching: find.text('Best Match'),
      ),
      findsNothing,
    );

    // Finish cascade; ordinary rebuild must not replay or re-fire haptic.
    await tester.pump(CollectibleMotion.recognitionCascadeThird);
    await tester.pump(CollectibleMotion.crossfade);
    final fadeFinder = find.descendant(
      of: find.byKey(const ValueKey('recognition-cascade-1-0')),
      matching: find.byType(FadeTransition),
    );
    expect(tester.widget<FadeTransition>(fadeFinder).opacity.value, 1.0);
    final view = tester.view;
    final oldSize = view.physicalSize;
    view.physicalSize = Size(oldSize.width, oldSize.height - 20);
    addTearDown(() => view.physicalSize = oldSize);
    await tester.pump();
    expect(tester.widget<FadeTransition>(fadeFinder).opacity.value, 1.0);
    expect(haptics, 1);
    expect(find.text('Create Custom Figure'), findsOneWidget);
  });

  testWidgets('no-match and failure do not fire success haptic', (tester) async {
    var haptics = 0;
    final noMatchGateway = _FakeRecognitionGateway(
      const CatalogRecognitionNoConfidentMatch(),
    );
    await _pumpHost(
      tester,
      recognitionCoordinator: CatalogFigureRecognitionCoordinator(
        noMatchGateway,
      ),
      selectionHaptic: () => haptics++,
    );
    await tester.tap(find.text('Acquire'));
    await _settlePhotoLoad(tester);
    await tester.tap(find.text('Use This Photo'));
    await _settleFraming(tester);
    await tester.tap(find.text('Continue'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(haptics, 0);
    expect(find.text('Best Match'), findsNothing);
    expect(
      find.byKey(const Key('recognition-finding-progress')),
      findsNothing,
    );
    await tester.tap(find.byKey(const Key('catalog-photo-close')));
    await tester.pumpAndSettle();

    final failureGateway = _FakeRecognitionGateway(
      const CatalogRecognitionFailure(
        kind: CatalogRecognitionFailureKind.appCheckRejected,
      ),
    );
    await _pumpHost(
      tester,
      recognitionCoordinator: CatalogFigureRecognitionCoordinator(
        failureGateway,
      ),
      selectionHaptic: () => haptics++,
    );
    await tester.tap(find.text('Acquire'));
    await _settlePhotoLoad(tester);
    await tester.tap(find.text('Use This Photo'));
    await _settleFraming(tester);
    await tester.tap(find.text('Continue'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(haptics, 0);
    expect(
      find.byKey(const Key('recognition-finding-progress')),
      findsNothing,
    );
  });

  testWidgets('no-match copy stays human and offers Create Custom Figure', (
    tester,
  ) async {
    final gateway = _FakeRecognitionGateway(
      const CatalogRecognitionNoConfidentMatch(),
    );
    await _pumpHost(
      tester,
      recognitionCoordinator: CatalogFigureRecognitionCoordinator(gateway),
    );
    await tester.tap(find.text('Acquire'));
    await _settlePhotoLoad(tester);
    await tester.tap(find.text('Use This Photo'));
    await _settleFraming(tester);
    await tester.tap(find.text('Continue'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      find.text('We couldn’t find a close match.'),
      findsOneWidget,
    );
    expect(
      find.text(
        'We compared your photo with the Shelfy catalog, but couldn’t identify a confident match.',
      ),
      findsOneWidget,
    );
    expect(find.text('No close match found.'), findsOneWidget);
    expect(
      find.byKey(const Key('recognition-finding-checklist')),
      findsOneWidget,
    );
    expect(find.text('Create Custom Figure'), findsOneWidget);
    expect(find.text('Try Another Photo'), findsOneWidget);
    expect(find.text('Adjust Frame'), findsOneWidget);
    expect(find.textContaining('%'), findsNothing);
  });

  testWidgets('too blurry still blocks and Adjust Frame preserves selection', (
    tester,
  ) async {
    final gateway = _SequenceRecognitionGateway();
    await _pumpHost(
      tester,
      recognitionCoordinator: CatalogFigureRecognitionCoordinator(gateway),
    );
    await tester.tap(find.text('Acquire'));
    await _settlePhotoLoad(tester);
    await tester.tap(find.text('Use This Photo'));
    await _settleFraming(tester);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('A little too soft'), findsOneWidget);
    expect(gateway.calls, 1);
    await tester.tap(find.text('Adjust Frame'));
    await tester.pumpAndSettle();
    expect(find.text('Continue'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(gateway.calls, 2);
    expect(
      gateway.selections[1].normalizedRect.rect,
      gateway.selections[0].normalizedRect.rect,
    );
  });

  testWidgets(
    'Retry starts a fresh finding checklist sequence',
    (tester) async {
      final gateway = _MultiPendingRecognitionGateway();
      await _pumpHost(
        tester,
        recognitionCoordinator: CatalogFigureRecognitionCoordinator(gateway),
      );
      await tester.tap(find.text('Acquire'));
      await _settlePhotoLoad(tester);
      await tester.tap(find.text('Use This Photo'));
      await _settleFraming(tester);
      await tester.tap(find.text('Continue'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(CollectibleMotion.recognitionFindingShapeComplete);
      await tester.pump();
      expect(find.text('Checking colors…'), findsOneWidget);

      gateway.completeNext(const CatalogRecognitionFailure(
        kind: CatalogRecognitionFailureKind.appCheckRejected,
      ));
      await tester.pumpAndSettle();
      expect(find.text('Scan unavailable'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.text('Checking silhouette…'), findsOneWidget);
      expect(find.text('Checking colors…'), findsNothing);
      expect(gateway.calls, 2);

      gateway.completeNext(const CatalogRecognitionNoConfidentMatch());
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('recognition-finding-checklist')),
        findsOneWidget,
      );
      expect(find.text('No close match found.'), findsOneWidget);
    },
  );

  testWidgets(
    'fatal recognition dependency opens Scan unavailable and Retry reruns only recognition',
    (tester) async {
      final gateway = _FakeRecognitionGateway(
        const CatalogRecognitionFailure(
          kind: CatalogRecognitionFailureKind.appCheckRejected,
        ),
      );
      await _pumpHost(
        tester,
        recognitionCoordinator: CatalogFigureRecognitionCoordinator(gateway),
      );
      await tester.tap(find.text('Acquire'));
      await _settlePhotoLoad(tester);
      await tester.tap(find.text('Use This Photo'));
      await _settleFraming(tester);
      await tester.tap(find.text('Continue'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Scan unavailable'), findsOneWidget);
      expect(gateway.calls, 1);
      await tester.pump(const Duration(milliseconds: 250));
      await tester.tap(find.text('Retry'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(gateway.calls, 2);
    },
  );
}

final class _PendingRecognitionGateway
    implements CatalogFigureRecognitionGateway {
  final pending = Completer<CatalogFigureRecognitionResult>();
  var calls = 0;

  @override
  Future<CatalogFigureRecognitionResult> recognize(
    CatalogSubjectSelectionResult selection, {
    String? seriesId,
  }) {
    calls++;
    return pending.future;
  }

  @override
  void cancelPending() {}
}

final class _MultiPendingRecognitionGateway
    implements CatalogFigureRecognitionGateway {
  final pending = <Completer<CatalogFigureRecognitionResult>>[];
  var calls = 0;

  @override
  Future<CatalogFigureRecognitionResult> recognize(
    CatalogSubjectSelectionResult selection, {
    String? seriesId,
  }) {
    calls++;
    final completer = Completer<CatalogFigureRecognitionResult>();
    pending.add(completer);
    return completer.future;
  }

  void completeNext(CatalogFigureRecognitionResult result) {
    pending.firstWhere((c) => !c.isCompleted).complete(result);
  }

  @override
  void cancelPending() {}
}

final class _SequenceRecognitionGateway
    implements CatalogFigureRecognitionGateway {
  var calls = 0;
  final selections = <CatalogSubjectSelectionResult>[];

  @override
  Future<CatalogFigureRecognitionResult> recognize(
    CatalogSubjectSelectionResult selection, {
    String? seriesId,
  }) async {
    calls++;
    selections.add(selection);
    if (calls == 1) return const CatalogRecognitionTooBlurry();
    return const CatalogRecognitionNoConfidentMatch();
  }

  @override
  void cancelPending() {}
}

final class _FakeRecognitionGateway implements CatalogFigureRecognitionGateway {
  _FakeRecognitionGateway([
    this.result = const CatalogRecognitionCandidates(
      quality: CatalogSubjectQuality.good,
      candidates: [
        CatalogRecognitionCandidate(
          rank: 1,
          figureId: 'figure-test',
          figureName: 'Test Figure',
          seriesId: 'series-test',
          seriesName: 'Test Series',
          ipId: 'ip-test',
          ipName: 'Test IP',
          imageKey: 'test-figure',
        ),
      ],
    ),
  ]);

  final CatalogFigureRecognitionResult result;
  var calls = 0;
  final seriesIds = <String?>[];

  @override
  Future<CatalogFigureRecognitionResult> recognize(
    CatalogSubjectSelectionResult selection, {
    String? seriesId,
  }) async {
    calls++;
    seriesIds.add(seriesId);
    return result;
  }

  @override
  void cancelPending() {}
}

Future<void> _pumpHost(
  WidgetTester tester, {
  CatalogPhotoSelection? selection,
  WholeImageQualityEvaluator? evaluator,
  CatalogPhotoAcquirer? acquirer,
  CatalogSubjectLocator? locatorGateway,
  CatalogFigureRecognitionCoordinator? recognitionCoordinator,
  ValueChanged<CatalogPhotoSelection>? onAccepted,
  ValueChanged<CatalogSubjectSelectionResult>? onResult,
  ValueChanged<CatalogRecognitionCandidate>? onCandidateConfirmed,
  CatalogScanSelectionHaptic? selectionHaptic,
  GlobalKey? hostKey,
  TextScaler textScaler = TextScaler.noScaling,
  bool disableAnimations = false,
}) async {
  final selected = selection ?? _selection();
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: textScaler,
          disableAnimations: disableAnimations,
        ),
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
                  locatorGateway: locatorGateway ?? _FakeSubjectLocator(),
                  recognitionCoordinator:
                      recognitionCoordinator ??
                      CatalogFigureRecognitionCoordinator(
                        _FakeRecognitionGateway(),
                      ),
                  onCandidateConfirmed: onCandidateConfirmed,
                  selectionHaptic: selectionHaptic,
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
      // Finish title/guidance AnimatedSwitcher before assertions.
      await tester.pump(CollectibleMotion.crossfade);
      await tester.pump(CollectibleMotion.sectionReveal);
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
  await _confirmFirstCandidate(tester);
}

Future<void> _confirmFirstCandidate(WidgetTester tester) async {
  for (var attempt = 0; attempt < 40; attempt++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (find.text('We found a few close matches').evaluate().isNotEmpty) {
      break;
    }
  }
  await tester.pump(CollectibleMotion.sectionReveal);
  expect(
    find.byKey(const Key('recognition-candidate-figure-test')),
    findsOneWidget,
  );
  // Candidate tap no longer dismisses the scan sheet — close returns the
  // framed selection for flows that await the sheet result.
  await tester.tap(find.byKey(const Key('catalog-photo-close')));
  await tester.pump();
  await tester.pump(CollectibleMotion.crossfade);
  await tester.pump(CollectibleMotion.sheetDismiss);
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

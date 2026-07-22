import 'dart:async';
import 'dart:typed_data';

import 'package:blindbox_app/shared/image/catalog_photo_acquisition.dart';
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

void main() {
  testWidgets('acquired photo opens a floating confirmation over stable page', (
    tester,
  ) async {
    final hostKey = GlobalKey();
    final evaluator = _FakeEvaluator(WholeImageQualityOutcome.usable);
    await _pumpHost(tester, hostKey: hostKey, evaluator: evaluator);
    final before = tester.getRect(find.byKey(const Key('underlying-page')));

    await tester.tap(find.text('Acquire'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('catalog-photo-confirmation')), findsOneWidget);
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byType(AppBar), findsNothing);
    expect(find.text('Review photo'), findsNothing);
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
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use This Photo'));
    await tester.pumpAndSettle();

    expect(accepted, same(selection));
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
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retake Photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use This Photo'));
    await tester.pumpAndSettle();

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
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retake Photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use This Photo'));
    await tester.pumpAndSettle();

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
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose Another Photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use This Photo'));
    await tester.pumpAndSettle();

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
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose Another Photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use This Photo'));
    await tester.pumpAndSettle();

    expect(accepted, same(initial));
  });

  testWidgets('system back dismisses without confirmation', (tester) async {
    CatalogPhotoSelection? accepted;
    await _pumpHost(tester, onAccepted: (value) => accepted = value);

    await tester.tap(find.text('Acquire'));
    await tester.pumpAndSettle();
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
    await tester.pumpAndSettle();

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
    await tester.pumpAndSettle();
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
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use This Photo'));
    await tester.pumpAndSettle();

    expect(accepted, isNotNull);
    expect(
      find.byKey(const Key('catalog-photo-validation-error')),
      findsNothing,
    );
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
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use This Photo'));
    await tester.pumpAndSettle();
    evaluator.outcome = WholeImageQualityOutcome.usable;
    await tester.tap(find.text('Choose Another Photo'));
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
    await tester.pumpAndSettle();
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
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use This Photo'));
    await tester.pump();
    await tester.tap(find.text('Choose Another Photo'));
    await tester.pump();
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
      await tester.pumpAndSettle();

      final preview = tester.widget<Image>(
        find.byKey(const Key('catalog-photo-preview')),
      );
      expect(preview.fit, BoxFit.contain);
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
      await tester.pumpAndSettle();

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
  ValueChanged<CatalogPhotoSelection>? onAccepted,
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
                final accepted = await showDialog<CatalogPhotoSelection>(
                  context: context,
                  builder: (_) => CatalogPhotoVerificationPage(
                    selection: selected,
                    evaluator:
                        evaluator ??
                        _FakeEvaluator(WholeImageQualityOutcome.usable),
                    photoAcquirer: acquirer,
                  ),
                );
                if (accepted != null) onAccepted?.call(accepted);
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

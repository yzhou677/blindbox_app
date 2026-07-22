import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import 'package:blindbox_app/shared/image/catalog_figure_recognition.dart';
import 'package:blindbox_app/shared/image/catalog_figure_recognition_gateway.dart';
import 'package:blindbox_app/shared/image/catalog_photo_acquisition.dart';
import 'package:blindbox_app/shared/image/catalog_subject_selection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  test(
    'gateway sends original bytes and final normalized oriented rectangle',
    () async {
      final callable = _Callable({'version': 1, 'status': 'borderline'});
      final gateway = FirebaseCatalogFigureRecognitionGateway(
        callable: callable,
      );
      final selection = _selection();
      final result = await gateway.recognize(
        selection,
        continueBorderline: false,
      );
      expect(result, isA<CatalogRecognitionBorderline>());
      final request = callable.requests.single;
      expect(base64Decode((request['image'] as Map)['dataBase64']), [
        1,
        2,
        3,
        4,
      ]);
      final rect = request['selection'] as Map;
      expect(rect['left'], 0.1);
      expect(rect['top'], 0.2);
      expect(rect['width'], closeTo(0.6, 1e-12));
      expect(rect['height'], closeTo(0.6, 1e-12));
      expect(rect['coordinateSpace'], 'normalized_oriented_image');
      expect(request['continueBorderline'], false);
    },
  );

  test(
    'gateway maps safe candidate, no-match, too-blurry and malformed outcomes',
    () async {
      final candidates = await FirebaseCatalogFigureRecognitionGateway(
        callable: _Callable({
          'version': 1,
          'status': 'candidates',
          'subjectQuality': 'good',
          'decision': 'needs_review',
          'candidates': [
            {
              'rank': 1,
              'figureId': 'f',
              'figureName': 'Figure',
              'seriesId': 's',
              'seriesName': 'Series',
              'ipId': 'i',
              'ipName': 'IP',
              'imageKey': 'figure',
            },
          ],
        }),
      ).recognize(_selection(), continueBorderline: false);
      expect(candidates, isA<CatalogRecognitionCandidates>());
      expect(
        (candidates as CatalogRecognitionCandidates).candidates.single.figureId,
        'f',
      );
      expect(
        await FirebaseCatalogFigureRecognitionGateway(
          callable: _Callable({'version': 1, 'status': 'no_confident_match'}),
        ).recognize(_selection(), continueBorderline: false),
        isA<CatalogRecognitionNoConfidentMatch>(),
      );
      expect(
        await FirebaseCatalogFigureRecognitionGateway(
          callable: _Callable({'version': 1, 'status': 'too_blurry'}),
        ).recognize(_selection(), continueBorderline: false),
        isA<CatalogRecognitionTooBlurry>(),
      );
      final malformed = await FirebaseCatalogFigureRecognitionGateway(
        callable: _Callable({
          'version': 1,
          'status': 'candidates',
          'subjectQuality': 'good',
          'decision': 'needs_review',
          'candidates': [],
        }),
      ).recognize(_selection(), continueBorderline: false);
      expect(
        (malformed as CatalogRecognitionFailure).kind,
        CatalogRecognitionFailureKind.invalidResponse,
      );
    },
  );

  test(
    'coordinator prevents duplicate calls and ignores a cancelled completion',
    () async {
      final gateway = _PendingGateway();
      final coordinator = CatalogFigureRecognitionCoordinator(gateway);
      final first = coordinator.recognize(_selection());
      expect(await coordinator.recognize(_selection()), isNull);
      await Future<void>.delayed(Duration.zero);
      expect(gateway.calls, 1);
      coordinator.cancelPending();
      gateway.pending.complete(const CatalogRecognitionNoConfidentMatch());
      expect(await first, isNull);
    },
  );
}

CatalogSubjectSelectionResult _selection() => CatalogSubjectSelectionResult(
  photo: CatalogPhotoSelection(
    file: XFile.fromData(
      Uint8List.fromList([1, 2, 3, 4]),
      name: 'original.png',
      mimeType: 'image/png',
    ),
    source: CatalogPhotoSource.camera,
  ),
  normalizedRect: const NormalizedSubjectRect(
    left: 0.1,
    top: 0.2,
    right: 0.7,
    bottom: 0.8,
  ),
  sourceImageRect: const Rect.fromLTWH(100, 100, 600, 300),
  orientedSourceSize: const Size(1000, 500),
  origin: SubjectSelectionOrigin.userEdited,
);

final class _Callable implements FigureRecognitionCallable {
  _Callable(this.response);
  final Object? response;
  final requests = <Map<String, Object?>>[];
  @override
  Future<Object?> call(Map<String, Object?> data) async {
    requests.add(data);
    return response;
  }
}

final class _PendingGateway implements CatalogFigureRecognitionGateway {
  final pending = Completer<CatalogFigureRecognitionResult>();
  var calls = 0;
  @override
  Future<CatalogFigureRecognitionResult> recognize(
    CatalogSubjectSelectionResult selection, {
    required bool continueBorderline,
  }) {
    calls++;
    return pending.future;
  }

  @override
  void cancelPending() {}
}

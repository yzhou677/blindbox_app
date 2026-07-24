import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import 'package:blindbox_app/shared/image/catalog_figure_recognition.dart';
import 'package:blindbox_app/shared/image/catalog_figure_recognition_gateway.dart';
import 'package:blindbox_app/shared/image/catalog_photo_acquisition.dart';
import 'package:blindbox_app/shared/image/catalog_recognition_image_preparer.dart';
import 'package:blindbox_app/shared/image/catalog_subject_selection.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as image;

void main() {
  test('gateway sends only the bounded selected-subject crop', () async {
    final callable = _Callable({'version': 1, 'status': 'no_confident_match'});
    final gateway = FirebaseCatalogFigureRecognitionGateway(callable: callable);
    final selection = _selection();
    final result = await gateway.recognize(selection);
    expect(result, isA<CatalogRecognitionNoConfidentMatch>());
    final request = callable.requests.single;
    expect(request['version'], 2);
    final sentImage = request['image'] as Map;
    final sentBytes = base64Decode(sentImage['dataBase64']);
    final decoded = image.decodeImage(sentBytes)!;
    expect(decoded.width, 60);
    expect(decoded.height, 30);
    expect(sentImage['role'], 'selected_subject_crop');
    expect(request.containsKey('selection'), isFalse);
    expect(sentBytes.length, lessThan(_sourceBytes().length));
    expect(request.containsKey('continueBorderline'), isFalse);
    expect(request['requestId'], 'scan-recognition-test');
    expect(request.containsKey('seriesId'), isFalse);
  });

  test(
    'gateway includes seriesId only when provided for Series Scan',
    () async {
      final callable = _Callable({
        'version': 1,
        'status': 'no_confident_match',
      });
      final gateway = FirebaseCatalogFigureRecognitionGateway(
        callable: callable,
      );

      await gateway.recognize(_selection());
      final omitted = callable.requests.single;
      expect(omitted.containsKey('seriesId'), isFalse);
      expect(omitted['version'], 2);
      expect(omitted['requestId'], 'scan-recognition-test');
      expect(omitted['image'], isA<Map>());
      expect((omitted['image'] as Map)['role'], 'selected_subject_crop');

      await gateway.recognize(
        _selection(),
        seriesId: '  hirono_mist_walker_series_plush_doll_pendant  ',
      );
      final scoped = callable.requests[1];
      expect(
        scoped['seriesId'],
        'hirono_mist_walker_series_plush_doll_pendant',
      );
      expect(scoped['version'], 2);
      expect(scoped['requestId'], 'scan-recognition-test');
      expect(scoped['image'], isA<Map>());

      await gateway.recognize(_selection(), seriesId: '   ');
      expect(callable.requests[2].containsKey('seriesId'), isFalse);

      await gateway.recognize(_selection(), seriesId: null);
      expect(callable.requests[3].containsKey('seriesId'), isFalse);
    },
  );

  test(
    'gateway maps safe candidate, no-match, too-blurry and malformed outcomes',
    () async {
      Future<CatalogFigureRecognitionResult> map(Object response) =>
          FirebaseCatalogFigureRecognitionGateway(
            callable: _Callable(response),
            imagePreparer: _FakePreparer(),
          ).recognize(_selection());

      final needsReview = await map({
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
      });
      expect(needsReview, isA<CatalogRecognitionCandidates>());
      expect(
        (needsReview as CatalogRecognitionCandidates).decision,
        CatalogRecognitionDecision.needsReview,
      );
      expect(needsReview.candidates.single.figureId, 'f');

      final highConfidence = await map({
        'version': 1,
        'status': 'candidates',
        'subjectQuality': 'good',
        'decision': 'high_confidence',
        'candidates': [
          {
            'rank': 1,
            'figureId': 'f1',
            'figureName': 'Figure',
            'seriesId': 's',
            'seriesName': 'Series',
            'ipId': 'i',
            'ipName': 'IP',
            'imageKey': 'figure',
          },
          {
            'rank': 2,
            'figureId': 'f2',
            'figureName': 'Figure 2',
            'seriesId': 's2',
            'seriesName': 'Series 2',
            'ipId': 'i',
            'ipName': 'IP',
            'imageKey': 'figure-2',
          },
        ],
      });
      expect(highConfidence, isA<CatalogRecognitionCandidates>());
      expect(
        (highConfidence as CatalogRecognitionCandidates).decision,
        CatalogRecognitionDecision.highConfidence,
      );
      expect(highConfidence.candidates.map((c) => c.figureId).toList(), [
        'f1',
        'f2',
      ]);

      expect(
        await map({'version': 1, 'status': 'no_confident_match'}),
        isA<CatalogRecognitionNoConfidentMatch>(),
      );
      expect(
        await map({'version': 1, 'status': 'too_blurry'}),
        isA<CatalogRecognitionTooBlurry>(),
      );
      final malformed = await map({
        'version': 1,
        'status': 'candidates',
        'subjectQuality': 'good',
        'decision': 'needs_review',
        'candidates': [],
      });
      expect(
        (malformed as CatalogRecognitionFailure).kind,
        CatalogRecognitionFailureKind.invalidResponse,
      );
      final rejectedDecision = await map({
        'version': 1,
        'status': 'candidates',
        'subjectQuality': 'good',
        'decision': 'no_confident_match',
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
      });
      expect(
        (rejectedDecision as CatalogRecognitionFailure).kind,
        CatalogRecognitionFailureKind.invalidResponse,
      );
    },
  );

  test('preparer bounds the crop without upscaling', () async {
    final large = image.Image(width: 5000, height: 100)
      ..clear(image.ColorRgb8(90, 130, 170));
    final selection = _selectionWith(
      bytes: Uint8List.fromList(image.encodeJpg(large, quality: 95)),
      width: 5000,
      height: 100,
      rect: const NormalizedSubjectRect(left: 0, top: 0, right: 1, bottom: 1),
    );
    final prepared = await const LocalCatalogRecognitionImagePreparer().prepare(
      selection,
    );
    expect(prepared.width, catalogRecognitionMaxInputDimension);
    expect(prepared.height, 82);

    final small = await const LocalCatalogRecognitionImagePreparer().prepare(
      _selection(),
    );
    expect((small.width, small.height), (60, 30));
  });

  test('retry reuses one prepared crop and one source read/encode', () async {
    var encodes = 0;
    final preparer = LocalCatalogRecognitionImagePreparer(
      base64Encoder: (bytes) {
        encodes++;
        return base64Encode(bytes);
      },
    );
    final callable = _Callable({'version': 1, 'status': 'no_confident_match'});
    final gateway = FirebaseCatalogFigureRecognitionGateway(
      callable: callable,
      imagePreparer: preparer,
    );
    final selection = _selection();
    await gateway.recognize(selection);
    await gateway.recognize(selection);
    expect(encodes, 1);
    expect(
      callable.requests
          .map((request) => (request['image'] as Map)['dataBase64'])
          .toSet(),
      hasLength(1),
    );
  });

  test(
    'a changed selection prepares and encodes a new recognition crop',
    () async {
      var encodes = 0;
      final preparer = LocalCatalogRecognitionImagePreparer(
        base64Encoder: (bytes) {
          encodes++;
          return base64Encode(bytes);
        },
      );
      final gateway = FirebaseCatalogFigureRecognitionGateway(
        callable: _Callable({'version': 1, 'status': 'no_confident_match'}),
        imagePreparer: preparer,
      );
      await gateway.recognize(_selection());
      await gateway.recognize(_selection());
      expect(encodes, 2);
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

  test('App Check rejection remains a fatal scan dependency failure', () async {
    final result = await FirebaseCatalogFigureRecognitionGateway(
      callable: _ThrowingRecognitionCallable(
        FirebaseFunctionsException(
          code: 'unauthenticated',
          message: 'Unauthenticated',
        ),
      ),
      imagePreparer: _FakePreparer(),
    ).recognize(_selection());
    expect(
      (result as CatalogRecognitionFailure).kind,
      CatalogRecognitionFailureKind.appCheckRejected,
    );
  });
}

CatalogSubjectSelectionResult _selection() => CatalogSubjectSelectionResult(
  photo: CatalogPhotoSelection(
    file: XFile.fromData(
      _sourceBytes(),
      name: 'original.png',
      mimeType: 'image/png',
    ),
    source: CatalogPhotoSource.camera,
    correlationId: 'scan-recognition-test',
  ),
  normalizedRect: const NormalizedSubjectRect(
    left: 0.1,
    top: 0.2,
    right: 0.7,
    bottom: 0.8,
  ),
  sourceImageRect: const Rect.fromLTWH(10, 10, 60, 30),
  orientedSourceSize: const Size(100, 50),
  origin: SubjectSelectionOrigin.userEdited,
);

CatalogSubjectSelectionResult _selectionWith({
  required Uint8List bytes,
  required double width,
  required double height,
  required NormalizedSubjectRect rect,
}) => CatalogSubjectSelectionResult(
  photo: CatalogPhotoSelection(
    file: XFile.fromData(bytes, name: 'fixture.jpg', mimeType: 'image/jpeg'),
    source: CatalogPhotoSource.camera,
  ),
  normalizedRect: rect,
  sourceImageRect: Rect.fromLTRB(
    rect.left * width,
    rect.top * height,
    rect.right * width,
    rect.bottom * height,
  ),
  orientedSourceSize: Size(width, height),
  origin: SubjectSelectionOrigin.userEdited,
);

Uint8List _sourceBytes() => Uint8List.fromList(
  image.encodeJpg(
    image.Image(width: 100, height: 50)..clear(image.ColorRgb8(80, 120, 180)),
    quality: 95,
  ),
);

final class _FakePreparer implements CatalogRecognitionImagePreparer {
  var calls = 0;
  final encodedValue = base64Encode([1, 2, 3, 4]);
  @override
  Future<PreparedCatalogRecognitionImage> prepare(
    CatalogSubjectSelectionResult selection,
  ) async {
    calls++;
    return PreparedCatalogRecognitionImage(
      bytes: Uint8List.fromList([1, 2, 3, 4]),
      mimeType: 'image/jpeg',
      width: 60,
      height: 30,
      originalByteSize: 100,
      dataBase64: encodedValue,
    );
  }
}

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
    String? seriesId,
  }) {
    calls++;
    return pending.future;
  }

  @override
  void cancelPending() {}
}

final class _ThrowingRecognitionCallable implements FigureRecognitionCallable {
  _ThrowingRecognitionCallable(this.error);
  final Object error;
  @override
  Future<Object?> call(Map<String, Object?> data) =>
      Future<Object?>.error(error);
}

import 'dart:async';
import 'dart:typed_data';

import 'package:blindbox_app/shared/image/catalog_photo_acquisition.dart';
import 'package:blindbox_app/shared/image/catalog_subject_locator_gateway.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

final class _FakeCallable implements SubjectLocatorCallable {
  _FakeCallable(this.responses);
  final List<Future<Object?>> responses;
  final calls = <Map<String, Object?>>[];
  @override
  Future<Object?> call(Map<String, Object?> data) {
    calls.add(data);
    return responses.removeAt(0);
  }
}

final class _FakeEncoder implements SubjectLocatorTransportEncoder {
  _FakeEncoder(this.transport);
  final SubjectLocatorTransportImage transport;
  CatalogPhotoSelection? received;
  @override
  Future<SubjectLocatorTransportImage> encode(CatalogPhotoSelection photo) async {
    received = photo;
    return transport;
  }
}

final class _ThrowingCallable implements SubjectLocatorCallable {
  @override
  Future<Object?> call(Map<String, Object?> data) =>
      Future<Object?>.error(StateError('offline'));
}

CatalogPhotoSelection _photo([int marker = 1]) => CatalogPhotoSelection(
  file: XFile.fromData(Uint8List.fromList([marker, 2, 3]), mimeType: 'image/jpeg', name: 'photo.jpg'),
  source: CatalogPhotoSource.camera,
  correlationId: 'scan-locator-test-$marker',
);

Map<String, Object?> _suggestion() => {
  'version': 1,
  'status': 'suggestion',
  'rect': {'left': 0.2, 'top': 0.1, 'width': 0.5, 'height': 0.7},
  'coordinateSpace': 'normalized_oriented_image',
  'orientedWidth': 3024,
  'orientedHeight': 4032,
  'locatorVersion': 'primary-subject-v3',
  'selectorVersion': 'primary-subject-selector-v1',
};

void main() {
  test('maps suggestion while keeping the original local photo as source of truth', () async {
    final original = _photo();
    final callable = _FakeCallable([Future.value(_suggestion())]);
    final encoder = _FakeEncoder(SubjectLocatorTransportImage(bytes: Uint8List.fromList([9, 9]), mimeType: 'image/jpeg'));
    final result = await CatalogSubjectLocatorGateway(callable: callable, encoder: encoder).locate(original);
    expect(encoder.received, same(original));
    final suggestion = result as CatalogSubjectLocatorSuggestion;
    expect(suggestion.rect.left, 0.2);
    expect(suggestion.rect.bottom, closeTo(0.8, 1e-12));
    expect(suggestion.orientedSize.width, 3024);
    expect(callable.calls.single['image'], isA<Map>());
    expect(callable.calls.single['requestId'], 'scan-locator-test-1');
    expect(original.file, same(encoder.received!.file));
  });

  test('maps no suggestion and recoverable failure', () async {
    final encoder = _FakeEncoder(SubjectLocatorTransportImage(bytes: Uint8List.fromList([1]), mimeType: 'image/jpeg'));
    final noSuggestion = await CatalogSubjectLocatorGateway(
      callable: _FakeCallable([Future.value({'version': 1, 'status': 'no_suggestion', 'orientedWidth': 1, 'orientedHeight': 1})]),
      encoder: encoder,
    ).locate(_photo());
    expect(noSuggestion, isA<CatalogSubjectLocatorNoSuggestion>());
    final unavailable = await CatalogSubjectLocatorGateway(
      callable: _ThrowingCallable(),
      encoder: encoder,
    ).locate(_photo());
    expect(unavailable, isA<CatalogSubjectLocatorUnavailable>());
  });

  test('invalid response is unavailable', () async {
    final result = await CatalogSubjectLocatorGateway(
      callable: _FakeCallable([Future.value({..._suggestion(), 'rect': {'left': 0.8, 'top': 0.1, 'width': 0.4, 'height': 0.2}})]),
      encoder: _FakeEncoder(SubjectLocatorTransportImage(bytes: Uint8List.fromList([1]), mimeType: 'image/jpeg')),
    ).locate(_photo());
    expect((result as CatalogSubjectLocatorUnavailable).reason, 'invalid_response');
  });

  test('stale response cannot replace a newer photo', () async {
    final first = Completer<Object?>();
    final callable = _FakeCallable([first.future, Future.value(_suggestion())]);
    final gateway = CatalogSubjectLocatorGateway(
      callable: callable,
      encoder: _FakeEncoder(SubjectLocatorTransportImage(bytes: Uint8List.fromList([1]), mimeType: 'image/jpeg')),
    );
    final oldRequest = gateway.locate(_photo(1));
    while (callable.calls.isEmpty) {
      await Future<void>.delayed(Duration.zero);
    }
    final current = await gateway.locate(_photo(2));
    first.complete(_suggestion());
    final stale = await oldRequest;
    expect(current, isA<CatalogSubjectLocatorSuggestion>());
    expect((stale as CatalogSubjectLocatorUnavailable).reason, 'stale_response');
  });

  test('bounded transport preserves allowed full-file bytes when already within limit', () async {
    final photo = _photo();
    final transport = await const BoundedSubjectLocatorTransportEncoder().encode(photo);
    expect(transport.bytes, await photo.file.readAsBytes());
    expect(transport.mimeType, 'image/jpeg');
  });
}

import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:blindbox_app/shared/image/catalog_photo_acquisition.dart';
import 'package:blindbox_app/shared/image/catalog_subject_selection.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as image;

const catalogSubjectLocatorFunctionName = 'subjectLocatorV1';
const catalogSubjectLocatorRegion = 'us-central1';

sealed class CatalogSubjectLocatorResult {
  const CatalogSubjectLocatorResult();
}

final class CatalogSubjectLocatorSuggestion
    extends CatalogSubjectLocatorResult {
  const CatalogSubjectLocatorSuggestion({
    required this.rect,
    required this.orientedSize,
  });
  final NormalizedSubjectRect rect;
  final Size orientedSize;
}

final class CatalogSubjectLocatorNoSuggestion
    extends CatalogSubjectLocatorResult {
  const CatalogSubjectLocatorNoSuggestion();
}

final class CatalogSubjectLocatorUnavailable
    extends CatalogSubjectLocatorResult {
  const CatalogSubjectLocatorUnavailable({this.reason = 'locator_unavailable'});
  final String reason;
}

abstract interface class SubjectLocatorCallable {
  Future<Object?> call(Map<String, Object?> data);
}

final class FirebaseSubjectLocatorCallable implements SubjectLocatorCallable {
  FirebaseSubjectLocatorCallable({FirebaseFunctions? functions})
    : _functions =
          functions ??
          FirebaseFunctions.instanceFor(region: catalogSubjectLocatorRegion);
  final FirebaseFunctions _functions;

  @override
  Future<Object?> call(Map<String, Object?> data) async =>
      (await _functions
              .httpsCallable(catalogSubjectLocatorFunctionName)
              .call<Object?>(data))
          .data;
}

abstract interface class SubjectLocatorTransportEncoder {
  Future<SubjectLocatorTransportImage> encode(CatalogPhotoSelection photo);
}

final class SubjectLocatorTransportImage {
  const SubjectLocatorTransportImage({
    required this.bytes,
    required this.mimeType,
  });
  final Uint8List bytes;
  final String mimeType;
}

/// Creates a bounded full-frame transport copy. It never replaces [photo.file].
final class BoundedSubjectLocatorTransportEncoder
    implements SubjectLocatorTransportEncoder {
  const BoundedSubjectLocatorTransportEncoder();
  static const maxBytes = 6 * 1024 * 1024;
  static const maxDimension = 4096;
  static const allowedMimeTypes = {'image/jpeg', 'image/png', 'image/webp'};

  @override
  Future<SubjectLocatorTransportImage> encode(
    CatalogPhotoSelection photo,
  ) async {
    final bytes = await photo.file.readAsBytes();
    final mime = _normalizedMime(photo);
    if (bytes.isNotEmpty &&
        bytes.length <= maxBytes &&
        allowedMimeTypes.contains(mime)) {
      return SubjectLocatorTransportImage(bytes: bytes, mimeType: mime!);
    }
    final encoded = await compute(_encodeBoundedFullFrame, bytes);
    if (encoded == null || encoded.isEmpty || encoded.length > maxBytes) {
      throw const FormatException(
        'Image cannot be prepared for subject location.',
      );
    }
    return SubjectLocatorTransportImage(bytes: encoded, mimeType: 'image/jpeg');
  }

  String? _normalizedMime(CatalogPhotoSelection photo) {
    final declared = photo.file.mimeType?.toLowerCase();
    if (declared != null) return declared;
    final path = photo.file.path.toLowerCase();
    if (path.endsWith('.jpg') || path.endsWith('.jpeg')) return 'image/jpeg';
    if (path.endsWith('.png')) return 'image/png';
    if (path.endsWith('.webp')) return 'image/webp';
    return null;
  }
}

abstract interface class CatalogSubjectLocator {
  Future<CatalogSubjectLocatorResult> locate(
    CatalogPhotoSelection originalPhoto,
  );
  void cancelPending();
}

final class CatalogSubjectLocatorGateway implements CatalogSubjectLocator {
  CatalogSubjectLocatorGateway({
    SubjectLocatorCallable? callable,
    SubjectLocatorTransportEncoder? encoder,
  }) : _callable = callable ?? FirebaseSubjectLocatorCallable(),
       _encoder = encoder ?? const BoundedSubjectLocatorTransportEncoder();

  final SubjectLocatorCallable _callable;
  final SubjectLocatorTransportEncoder _encoder;
  var _generation = 0;

  @override
  Future<CatalogSubjectLocatorResult> locate(
    CatalogPhotoSelection originalPhoto,
  ) async {
    final generation = ++_generation;
    final requestId = catalogPhotoCorrelationId(originalPhoto);
    final startedAt = DateTime.now();
    final totalTimer = Stopwatch()..start();
    try {
      final preparationTimer = Stopwatch()..start();
      final transport = await _encoder.encode(originalPhoto);
      _debugLocatorLog({
        'event': 'timing',
        'function': catalogSubjectLocatorFunctionName,
        'requestId': requestId,
        'stage': 'image_read_normalize_compress',
        'elapsedMs': preparationTimer.elapsedMicroseconds / 1000,
      });
      final base64Timer = Stopwatch()..start();
      final dataBase64 = base64Encode(transport.bytes);
      final base64EncodingMs = base64Timer.elapsedMicroseconds / 1000;
      final requestPreparationTimer = Stopwatch()..start();
      final data = {
        'version': 1,
        'image': {
          'dataBase64': dataBase64,
          'mimeType': transport.mimeType,
        },
        'requestId': requestId,
      };
      _debugLocatorLog({
        'event': 'request_start',
        'function': catalogSubjectLocatorFunctionName,
        'requestId': requestId,
        'imageByteSize': transport.bytes.length,
        'mimeType': transport.mimeType,
        'requestPreparationMs':
            requestPreparationTimer.elapsedMicroseconds / 1000,
        'base64EncodingMs': base64EncodingMs,
        'base64Bytes': dataBase64.length,
      });
      if (generation != _generation) {
        return const CatalogSubjectLocatorUnavailable(reason: 'stale_response');
      }
      final roundTripTimer = Stopwatch()..start();
      final response = await _callable
          .call(data)
          .timeout(const Duration(seconds: 45));
      if (generation != _generation) {
        return const CatalogSubjectLocatorUnavailable(reason: 'stale_response');
      }
      final roundTripMs = roundTripTimer.elapsedMicroseconds / 1000;
      final parseTimer = Stopwatch()..start();
      final result = _mapResponse(response);
      _debugLocatorLog({
        'event': 'request_complete',
        'function': catalogSubjectLocatorFunctionName,
        'requestId': requestId,
        'elapsedMs': DateTime.now().difference(startedAt).inMilliseconds,
        'callableRoundTripMs': roundTripMs,
        'responseParsingMs': parseTimer.elapsedMicroseconds / 1000,
        'totalClientMs': totalTimer.elapsedMicroseconds / 1000,
        'outcome': _locatorOutcome(result),
      });
      return result;
    } on TimeoutException {
      _debugLocatorLog({
        'event': 'request_failed',
        'function': catalogSubjectLocatorFunctionName,
        'requestId': requestId,
        'elapsedMs': DateTime.now().difference(startedAt).inMilliseconds,
        'outcome': 'timeout',
      });
      return const CatalogSubjectLocatorUnavailable(reason: 'locator_timeout');
    } on FirebaseFunctionsException catch (error) {
      _debugLocatorLog({
        'event': 'request_failed',
        'function': catalogSubjectLocatorFunctionName,
        'requestId': requestId,
        'elapsedMs': DateTime.now().difference(startedAt).inMilliseconds,
        'outcome': 'recoverable_error',
        'callableCode': error.code,
        'callableMessage': error.message,
      });
      return const CatalogSubjectLocatorUnavailable();
    } catch (_) {
      _debugLocatorLog({
        'event': 'request_failed',
        'function': catalogSubjectLocatorFunctionName,
        'requestId': requestId,
        'elapsedMs': DateTime.now().difference(startedAt).inMilliseconds,
        'outcome': 'recoverable_error',
      });
      return const CatalogSubjectLocatorUnavailable();
    }
  }

  @override
  void cancelPending() {
    _generation++;
  }

  CatalogSubjectLocatorResult _mapResponse(Object? value) {
    if (value is! Map) {
      return const CatalogSubjectLocatorUnavailable(reason: 'invalid_response');
    }
    final map = Map<Object?, Object?>.from(value);
    if (map['version'] != 1) {
      return const CatalogSubjectLocatorUnavailable(reason: 'invalid_response');
    }
    if (map['status'] == 'no_suggestion') {
      return const CatalogSubjectLocatorNoSuggestion();
    }
    if (map['status'] != 'suggestion' ||
        map['coordinateSpace'] != 'normalized_oriented_image' ||
        map['rect'] is! Map) {
      return const CatalogSubjectLocatorUnavailable(reason: 'invalid_response');
    }
    final width = _finiteDouble(map['orientedWidth']);
    final height = _finiteDouble(map['orientedHeight']);
    final rectMap = Map<Object?, Object?>.from(map['rect'] as Map);
    final left = _finiteDouble(rectMap['left']);
    final top = _finiteDouble(rectMap['top']);
    final rectWidth = _finiteDouble(rectMap['width']);
    final rectHeight = _finiteDouble(rectMap['height']);
    if ([
          width,
          height,
          left,
          top,
          rectWidth,
          rectHeight,
        ].any((value) => value == null) ||
        width! <= 0 ||
        height! <= 0 ||
        left! < 0 ||
        top! < 0 ||
        rectWidth! <= 0 ||
        rectHeight! <= 0 ||
        left + rectWidth > 1 ||
        top + rectHeight > 1) {
      return const CatalogSubjectLocatorUnavailable(reason: 'invalid_response');
    }
    return CatalogSubjectLocatorSuggestion(
      rect: NormalizedSubjectRect(
        left: left,
        top: top,
        right: left + rectWidth,
        bottom: top + rectHeight,
      ),
      orientedSize: Size(width, height),
    );
  }
}

String _locatorOutcome(CatalogSubjectLocatorResult result) => switch (result) {
  CatalogSubjectLocatorSuggestion() => 'suggestion',
  CatalogSubjectLocatorNoSuggestion() => 'no_suggestion',
  CatalogSubjectLocatorUnavailable() => 'recoverable_error',
};

void _debugLocatorLog(Map<String, Object?> fields) {
  if (kDebugMode) debugPrint('[SubjectLocator] ${jsonEncode(fields)}');
}

double? _finiteDouble(Object? value) {
  if (value is! num) return null;
  final converted = value.toDouble();
  return converted.isFinite ? converted : null;
}

Uint8List? _encodeBoundedFullFrame(Uint8List bytes) {
  final decoded = image.decodeImage(bytes);
  if (decoded == null) return null;
  var oriented = image.bakeOrientation(decoded);
  if (oriented.width > BoundedSubjectLocatorTransportEncoder.maxDimension ||
      oriented.height > BoundedSubjectLocatorTransportEncoder.maxDimension) {
    oriented = image.copyResize(
      oriented,
      width: oriented.width >= oriented.height
          ? BoundedSubjectLocatorTransportEncoder.maxDimension
          : null,
      height: oriented.height > oriented.width
          ? BoundedSubjectLocatorTransportEncoder.maxDimension
          : null,
      interpolation: image.Interpolation.cubic,
    );
  }
  for (final quality in const [88, 80, 72, 64]) {
    final result = Uint8List.fromList(
      image.encodeJpg(oriented, quality: quality),
    );
    if (result.length <= BoundedSubjectLocatorTransportEncoder.maxBytes) {
      return result;
    }
  }
  return null;
}

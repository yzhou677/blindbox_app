import 'dart:async';
import 'dart:convert';

import 'package:blindbox_app/shared/image/catalog_figure_recognition.dart';
import 'package:blindbox_app/shared/image/catalog_photo_acquisition.dart';
import 'package:blindbox_app/shared/image/catalog_recognition_image_preparer.dart';
import 'package:blindbox_app/shared/image/catalog_subject_selection.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

const catalogFigureRecognitionFunctionName = 'recognizeFigureV1';
const catalogFigureRecognitionRegion = 'us-central1';
const catalogRecognitionMaxOriginalBytes = 18 * 1024 * 1024;

abstract interface class FigureRecognitionCallable {
  Future<Object?> call(Map<String, Object?> data);
}

final class FirebaseFigureRecognitionCallable
    implements FigureRecognitionCallable {
  FirebaseFigureRecognitionCallable({FirebaseFunctions? functions})
    : _functions =
          functions ??
          FirebaseFunctions.instanceFor(region: catalogFigureRecognitionRegion);
  final FirebaseFunctions _functions;
  @override
  Future<Object?> call(Map<String, Object?> data) async =>
      (await _functions
              .httpsCallable(catalogFigureRecognitionFunctionName)
              .call<Object?>(data))
          .data;
}

final class FirebaseCatalogFigureRecognitionGateway
    implements CatalogFigureRecognitionGateway {
  FirebaseCatalogFigureRecognitionGateway({
    FigureRecognitionCallable? callable,
    CatalogRecognitionImagePreparer? imagePreparer,
  }) : _callable = callable ?? FirebaseFigureRecognitionCallable(),
       _imagePreparer =
           imagePreparer ?? const LocalCatalogRecognitionImagePreparer();
  final FigureRecognitionCallable _callable;
  final CatalogRecognitionImagePreparer _imagePreparer;
  final Expando<Future<PreparedCatalogRecognitionImage>> _preparedImages =
      Expando<Future<PreparedCatalogRecognitionImage>>();
  var _generation = 0;

  @override
  Future<CatalogFigureRecognitionResult> recognize(
    CatalogSubjectSelectionResult selection,
  ) async {
    final generation = ++_generation;
    final requestId = catalogPhotoCorrelationId(selection.photo);
    final startedAt = DateTime.now();
    final totalTimer = Stopwatch()..start();
    try {
      final preparationTimer = Stopwatch()..start();
      final prepared = await (_preparedImages[selection] ??= _imagePreparer
          .prepare(selection));
      final preparationMs = preparationTimer.elapsedMicroseconds / 1000;
      if (prepared.bytes.isEmpty ||
          prepared.bytes.length > catalogRecognitionMaxOriginalBytes) {
        return const CatalogRecognitionFailure(
          kind: CatalogRecognitionFailureKind.imagePreparation,
        );
      }
      final data = {
        'version': prepared.requestVersion,
        'image': {
          'dataBase64': prepared.dataBase64,
          'mimeType': prepared.mimeType,
          'role': 'selected_subject_crop',
        },
        'requestId': requestId,
      };
      _debugRecognitionLog({
        'event': 'request_start',
        'function': catalogFigureRecognitionFunctionName,
        'requestId': requestId,
        'originalImageByteSize': prepared.originalByteSize,
        'imageByteSize': prepared.bytes.length,
        'mimeType': prepared.mimeType,
        'sourceWidth': prepared.width,
        'sourceHeight': prepared.height,
        'requestPreparationMs': preparationMs,
        'base64EncodingMs': 0,
        'base64Bytes': prepared.dataBase64.length,
      });
      final roundTripTimer = Stopwatch()..start();
      final response = await _callable
          .call(data)
          .timeout(const Duration(seconds: 120));
      if (generation != _generation) {
        return const CatalogRecognitionFailure(
          kind: CatalogRecognitionFailureKind.backendUnavailable,
        );
      }
      final roundTripMs = roundTripTimer.elapsedMicroseconds / 1000;
      final parseTimer = Stopwatch()..start();
      final result = _map(response);
      _debugRecognitionLog({
        'event': 'request_complete',
        'function': catalogFigureRecognitionFunctionName,
        'requestId': requestId,
        'elapsedMs': DateTime.now().difference(startedAt).inMilliseconds,
        'callableRoundTripMs': roundTripMs,
        'responseParsingMs': parseTimer.elapsedMicroseconds / 1000,
        'totalClientMs': totalTimer.elapsedMicroseconds / 1000,
        'resultType': result.runtimeType.toString(),
      });
      return result;
    } on TimeoutException {
      _debugRecognitionLog({
        'event': 'request_failed',
        'function': catalogFigureRecognitionFunctionName,
        'requestId': requestId,
        'elapsedMs': DateTime.now().difference(startedAt).inMilliseconds,
        'outcome': 'timeout',
      });
      return const CatalogRecognitionFailure(
        kind: CatalogRecognitionFailureKind.timeout,
      );
    } on FirebaseFunctionsException catch (error) {
      final details = error.details;
      final reason = details is Map ? details['reason'] : null;
      _debugRecognitionLog({
        'event': 'request_failed',
        'function': catalogFigureRecognitionFunctionName,
        'requestId': requestId,
        'elapsedMs': DateTime.now().difference(startedAt).inMilliseconds,
        'callableCode': error.code,
        'callableMessage': error.message,
        if (reason is String) 'reason': reason,
      });
      return CatalogRecognitionFailure(
        kind:
            error.code == 'unauthenticated' || error.code == 'permission-denied'
            ? CatalogRecognitionFailureKind.appCheckRejected
            : reason == 'quality_unavailable'
            ? CatalogRecognitionFailureKind.qualityUnavailable
            : CatalogRecognitionFailureKind.backendUnavailable,
      );
    } catch (_) {
      _debugRecognitionLog({
        'event': 'request_failed',
        'function': catalogFigureRecognitionFunctionName,
        'requestId': requestId,
        'elapsedMs': DateTime.now().difference(startedAt).inMilliseconds,
        'outcome': 'recoverable_error',
      });
      return const CatalogRecognitionFailure(
        kind: CatalogRecognitionFailureKind.backendUnavailable,
      );
    }
  }

  @override
  void cancelPending() {
    _generation++;
  }

  CatalogFigureRecognitionResult _map(Object? value) {
    if (value is! Map || value['version'] != 1 || value['status'] is! String) {
      return const CatalogRecognitionFailure(
        kind: CatalogRecognitionFailureKind.invalidResponse,
      );
    }
    switch (value['status']) {
      case 'too_blurry':
        return const CatalogRecognitionTooBlurry();
      case 'no_confident_match':
        return const CatalogRecognitionNoConfidentMatch();
      case 'candidates':
        final decision = value['decision'];
        if ((decision != 'needs_review' && decision != 'high_confidence') ||
            value['candidates'] is! List ||
            value['subjectQuality'] is! String) {
          return const CatalogRecognitionFailure(
            kind: CatalogRecognitionFailureKind.invalidResponse,
          );
        }
        final mapped = <CatalogRecognitionCandidate>[];
        for (final item in value['candidates'] as List) {
          if (item is! Map) {
            return const CatalogRecognitionFailure(
              kind: CatalogRecognitionFailureKind.invalidResponse,
            );
          }
          final rank = item['rank'];
          final fields = [
            'figureId',
            'figureName',
            'seriesId',
            'seriesName',
            'ipId',
            'ipName',
            'imageKey',
          ];
          if (rank is! int ||
              rank < 1 ||
              fields.any(
                (field) =>
                    item[field] is! String || (item[field] as String).isEmpty,
              )) {
            return const CatalogRecognitionFailure(
              kind: CatalogRecognitionFailureKind.invalidResponse,
            );
          }
          mapped.add(
            CatalogRecognitionCandidate(
              rank: rank,
              figureId: item['figureId'],
              figureName: item['figureName'],
              seriesId: item['seriesId'],
              seriesName: item['seriesName'],
              ipId: item['ipId'],
              ipName: item['ipName'],
              imageKey: item['imageKey'],
            ),
          );
        }
        if (mapped.isEmpty) {
          return const CatalogRecognitionFailure(
            kind: CatalogRecognitionFailureKind.invalidResponse,
          );
        }
        return CatalogRecognitionCandidates(
          quality: value['subjectQuality'] == 'borderline'
              ? CatalogSubjectQuality.borderline
              : CatalogSubjectQuality.good,
          decision: decision == 'high_confidence'
              ? CatalogRecognitionDecision.highConfidence
              : CatalogRecognitionDecision.needsReview,
          candidates: List.unmodifiable(mapped),
        );
      default:
        return const CatalogRecognitionFailure(
          kind: CatalogRecognitionFailureKind.invalidResponse,
        );
    }
  }
}

void _debugRecognitionLog(Map<String, Object?> fields) {
  if (kDebugMode) debugPrint('[FigureRecognition] ${jsonEncode(fields)}');
}

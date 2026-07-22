import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:blindbox_app/shared/image/catalog_figure_recognition.dart';
import 'package:blindbox_app/shared/image/catalog_subject_selection.dart';
import 'package:cloud_functions/cloud_functions.dart';

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
  FirebaseCatalogFigureRecognitionGateway({FigureRecognitionCallable? callable})
    : _callable = callable ?? FirebaseFigureRecognitionCallable();
  final FigureRecognitionCallable _callable;
  var _generation = 0;

  @override
  Future<CatalogFigureRecognitionResult> recognize(
    CatalogSubjectSelectionResult selection, {
    required bool continueBorderline,
  }) async {
    final generation = ++_generation;
    try {
      final bytes = await selection.photo.file.readAsBytes();
      final mime = _mime(
        selection.photo.file.mimeType,
        selection.photo.file.path,
      );
      if (bytes.isEmpty ||
          bytes.length > catalogRecognitionMaxOriginalBytes ||
          mime == null) {
        return const CatalogRecognitionFailure(
          kind: CatalogRecognitionFailureKind.imagePreparation,
        );
      }
      final rect = selection.normalizedRect;
      final response = await _callable
          .call({
            'version': 1,
            'image': {
              'dataBase64': base64Encode(Uint8List.fromList(bytes)),
              'mimeType': mime,
            },
            'selection': {
              'left': rect.left,
              'top': rect.top,
              'width': rect.right - rect.left,
              'height': rect.bottom - rect.top,
              'coordinateSpace': 'normalized_oriented_image',
            },
            'continueBorderline': continueBorderline,
            'requestId': 'recognition-$generation',
          })
          .timeout(const Duration(seconds: 120));
      if (generation != _generation) {
        return const CatalogRecognitionFailure(
          kind: CatalogRecognitionFailureKind.backendUnavailable,
        );
      }
      return _map(response);
    } on TimeoutException {
      return const CatalogRecognitionFailure(
        kind: CatalogRecognitionFailureKind.timeout,
      );
    } on FirebaseFunctionsException catch (error) {
      final details = error.details;
      final reason = details is Map ? details['reason'] : null;
      return CatalogRecognitionFailure(
        kind: reason == 'quality_unavailable'
            ? CatalogRecognitionFailureKind.qualityUnavailable
            : CatalogRecognitionFailureKind.backendUnavailable,
      );
    } catch (_) {
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
      case 'borderline':
        return const CatalogRecognitionBorderline();
      case 'too_blurry':
        return const CatalogRecognitionTooBlurry();
      case 'no_confident_match':
        return const CatalogRecognitionNoConfidentMatch();
      case 'candidates':
        if (value['decision'] != 'needs_review' ||
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
          candidates: List.unmodifiable(mapped),
        );
      default:
        return const CatalogRecognitionFailure(
          kind: CatalogRecognitionFailureKind.invalidResponse,
        );
    }
  }
}

String? _mime(String? declared, String path) {
  final value = declared?.toLowerCase();
  if (const {'image/jpeg', 'image/png', 'image/webp'}.contains(value)) {
    return value;
  }
  final lower = path.toLowerCase();
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.webp')) return 'image/webp';
  return null;
}

import 'package:blindbox_app/shared/image/catalog_subject_selection.dart';

enum CatalogSubjectQuality { good, borderline }

/// Backend presentation decision for hydrated candidate cards.
enum CatalogRecognitionDecision { needsReview, highConfidence }

class CatalogRecognitionCandidate {
  const CatalogRecognitionCandidate({
    required this.rank,
    required this.figureId,
    required this.figureName,
    required this.seriesId,
    required this.seriesName,
    required this.ipId,
    required this.ipName,
    required this.imageKey,
  });
  final int rank;
  final String figureId;
  final String figureName;
  final String seriesId;
  final String seriesName;
  final String ipId;
  final String ipName;
  final String imageKey;
}

sealed class CatalogFigureRecognitionResult {
  const CatalogFigureRecognitionResult();
}

final class CatalogRecognitionTooBlurry extends CatalogFigureRecognitionResult {
  const CatalogRecognitionTooBlurry();
}

final class CatalogRecognitionCandidates
    extends CatalogFigureRecognitionResult {
  const CatalogRecognitionCandidates({
    required this.quality,
    required this.candidates,
    this.decision = CatalogRecognitionDecision.needsReview,
  });
  final CatalogSubjectQuality quality;
  final List<CatalogRecognitionCandidate> candidates;
  final CatalogRecognitionDecision decision;
}

final class CatalogRecognitionNoConfidentMatch
    extends CatalogFigureRecognitionResult {
  const CatalogRecognitionNoConfidentMatch();
}

final class CatalogRecognitionFailure extends CatalogFigureRecognitionResult {
  const CatalogRecognitionFailure({required this.kind});
  final CatalogRecognitionFailureKind kind;
}

enum CatalogRecognitionFailureKind {
  appCheckRejected,
  qualityUnavailable,
  timeout,
  backendUnavailable,
  invalidResponse,
  imagePreparation,
}

abstract interface class CatalogFigureRecognitionGateway {
  Future<CatalogFigureRecognitionResult> recognize(
    CatalogSubjectSelectionResult selection, {
    String? seriesId,
  });
  void cancelPending();
}

enum CatalogRecognitionPhase { checkingQuality, recognizing }

class CatalogFigureRecognitionCoordinator {
  CatalogFigureRecognitionCoordinator(this.gateway);
  final CatalogFigureRecognitionGateway gateway;
  var _generation = 0;
  var _busy = false;

  Future<CatalogFigureRecognitionResult?> recognize(
    CatalogSubjectSelectionResult selection, {
    String? seriesId,
    void Function(CatalogRecognitionPhase phase)? onPhase,
  }) async {
    if (_busy) return null;
    _busy = true;
    final generation = ++_generation;
    try {
      onPhase?.call(CatalogRecognitionPhase.checkingQuality);
      await Future<void>.delayed(Duration.zero);
      if (generation != _generation) return null;
      onPhase?.call(CatalogRecognitionPhase.recognizing);
      final result = await gateway.recognize(selection, seriesId: seriesId);
      return generation == _generation ? result : null;
    } finally {
      if (generation == _generation) _busy = false;
    }
  }

  void cancelPending() {
    _generation++;
    _busy = false;
    gateway.cancelPending();
  }
}

import 'package:blindbox_app/shared/image/catalog_photo_acquisition.dart';

enum WholeImageQualityOutcome {
  usable,
  obviouslyTooBlurry,
  evaluationUnavailable,
}

class WholeImageQualityResult {
  const WholeImageQualityResult({
    required this.outcome,
    required this.evaluatorVersion,
    this.metricId,
    this.metricValue,
  });

  final WholeImageQualityOutcome outcome;
  final String evaluatorVersion;

  /// Developer diagnostics only. Presentation must not expose these values.
  final String? metricId;
  final double? metricValue;

  bool get canContinue =>
      outcome != WholeImageQualityOutcome.obviouslyTooBlurry;
}

abstract interface class WholeImageQualityEvaluator {
  Future<WholeImageQualityResult> evaluate(CatalogPhotoSelection selection);
}

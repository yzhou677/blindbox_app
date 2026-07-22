import 'package:blindbox_app/shared/image/catalog_photo_acquisition.dart';

enum WholeImageQualityStatus { pass, obviouslyBlurry, invalid }

class WholeImageQualityResult {
  const WholeImageQualityResult({
    required this.status,
    required this.evaluatorVersion,
    this.laplacianVariance,
  });

  final WholeImageQualityStatus status;
  final String evaluatorVersion;

  /// Developer diagnostic only. Flutter presentation must not display it.
  final double? laplacianVariance;

  bool get passed => status == WholeImageQualityStatus.pass;
}

abstract interface class WholeImageQualityEvaluator {
  Future<WholeImageQualityResult> evaluate(CatalogPhotoSelection selection);
}

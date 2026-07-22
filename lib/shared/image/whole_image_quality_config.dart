/// Frozen policy for the local, whole-photograph extreme-blur precheck.
///
/// This policy is intentionally separate from selected-subject quality. It is
/// allowed to false-accept and should reject only an obviously unusable image.
abstract final class WholeImageQualityConfig {
  static const evaluatorVersion = 'whole-image-quality-v1';
  static const analysisMaxDimension = 512;

  /// Variance-of-Laplacian values equal to this boundary pass.
  static const extremeBlurThreshold = 8.0;

  static bool passes(double laplacianVariance) =>
      laplacianVariance >= extremeBlurThreshold;
}

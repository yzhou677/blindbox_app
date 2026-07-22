/// Versioned policy for the device-local whole-image experience precheck.
///
/// This is an intentionally conservative, single-metric extreme-blur heuristic.
/// It is not calibrated to recognition success and is independent of the
/// selected-subject blur policy.
abstract final class WholeImageQualityConfig {
  static const evaluatorVersion = 'whole-image-blur-precheck-v1';
  static const metricId = 'variance_of_laplacian';
  static const analysisMaxDimension = 512;

  /// Values strictly below this extreme-failure floor are rejected.
  /// Equality passes.
  static const varianceOfLaplacianThreshold = 8.0;

  static bool passes(double variance) =>
      variance >= varianceOfLaplacianThreshold;
}

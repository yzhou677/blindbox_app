import 'dart:ui' as ui;

import 'package:blindbox_app/shared/image/catalog_photo_acquisition.dart';
import 'package:blindbox_app/shared/image/whole_image_quality.dart';
import 'package:blindbox_app/shared/image/whole_image_quality_config.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as image;

/// Deterministic, device-local extreme-blur precheck for an entire photograph.
///
/// It does not evaluate a selected collectible and deliberately shares no
/// thresholds or result semantics with the backend selected-subject gate.
final class LocalWholeImageQualityEvaluator
    implements WholeImageQualityEvaluator {
  const LocalWholeImageQualityEvaluator();

  @override
  Future<WholeImageQualityResult> evaluate(
    CatalogPhotoSelection selection,
  ) async {
    try {
      final bytes = await selection.file.readAsBytes();
      if (bytes.isEmpty) return _invalid;
      final variance =
          await compute(_calculateLaplacianVariance, bytes) ??
          await _calculateWithPlatformCodec(bytes);
      if (variance == null || !variance.isFinite) return _invalid;

      return WholeImageQualityResult(
        status: WholeImageQualityConfig.passes(variance)
            ? WholeImageQualityStatus.pass
            : WholeImageQualityStatus.obviouslyBlurry,
        evaluatorVersion: WholeImageQualityConfig.evaluatorVersion,
        laplacianVariance: variance,
      );
    } catch (_) {
      return _invalid;
    }
  }

  WholeImageQualityResult get _invalid => const WholeImageQualityResult(
    status: WholeImageQualityStatus.invalid,
    evaluatorVersion: WholeImageQualityConfig.evaluatorVersion,
  );

  Future<double?> _calculateWithPlatformCodec(Uint8List bytes) async {
    ui.ImmutableBuffer? buffer;
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    ui.Image? decoded;
    try {
      buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      final size = _analysisSize(descriptor.width, descriptor.height);
      codec = await descriptor.instantiateCodec(
        targetWidth: size.$1,
        targetHeight: size.$2,
      );
      decoded = (await codec.getNextFrame()).image;
      final rgba = await decoded.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (rgba == null) return null;
      return compute(_laplacianVarianceFromRgba, (
        bytes: rgba.buffer.asUint8List(),
        width: decoded.width,
        height: decoded.height,
      ));
    } catch (_) {
      return null;
    } finally {
      decoded?.dispose();
      codec?.dispose();
      descriptor?.dispose();
      buffer?.dispose();
    }
  }
}

double? _calculateLaplacianVariance(Uint8List bytes) {
  final decoded = image.decodeImage(bytes);
  if (decoded == null || decoded.width < 3 || decoded.height < 3) return null;

  final oriented = image.bakeOrientation(decoded);
  final normalized = _resizeForAnalysis(oriented);
  final grayscale = image.grayscale(normalized);
  var count = 0;
  var mean = 0.0;
  var squaredDifferenceSum = 0.0;

  for (var y = 1; y < grayscale.height - 1; y++) {
    for (var x = 1; x < grayscale.width - 1; x++) {
      final center = _luminance(grayscale.getPixel(x, y));
      final response =
          _luminance(grayscale.getPixel(x, y - 1)) +
          _luminance(grayscale.getPixel(x - 1, y)) -
          (4 * center) +
          _luminance(grayscale.getPixel(x + 1, y)) +
          _luminance(grayscale.getPixel(x, y + 1));

      count++;
      final delta = response - mean;
      mean += delta / count;
      squaredDifferenceSum += delta * (response - mean);
    }
  }

  return count == 0 ? 0 : squaredDifferenceSum / count;
}

image.Image _resizeForAnalysis(image.Image source) {
  final longest = source.width > source.height ? source.width : source.height;
  if (longest <= WholeImageQualityConfig.analysisMaxDimension) return source;
  if (source.width >= source.height) {
    return image.copyResize(
      source,
      width: WholeImageQualityConfig.analysisMaxDimension,
      interpolation: image.Interpolation.linear,
    );
  }
  return image.copyResize(
    source,
    height: WholeImageQualityConfig.analysisMaxDimension,
    interpolation: image.Interpolation.linear,
  );
}

double _luminance(image.Pixel pixel) => pixel.luminance.toDouble();

(int, int) _analysisSize(int width, int height) {
  final longest = width > height ? width : height;
  if (longest <= WholeImageQualityConfig.analysisMaxDimension) {
    return (width, height);
  }
  if (width >= height) {
    final targetWidth = WholeImageQualityConfig.analysisMaxDimension;
    return (
      targetWidth,
      (height * targetWidth / width).round().clamp(3, targetWidth),
    );
  }
  final targetHeight = WholeImageQualityConfig.analysisMaxDimension;
  return (
    (width * targetHeight / height).round().clamp(3, targetHeight),
    targetHeight,
  );
}

double? _laplacianVarianceFromRgba(
  ({Uint8List bytes, int width, int height}) input,
) {
  if (input.width < 3 || input.height < 3) return null;
  double luminanceAt(int x, int y) {
    final offset = ((y * input.width) + x) * 4;
    return (0.299 * input.bytes[offset]) +
        (0.587 * input.bytes[offset + 1]) +
        (0.114 * input.bytes[offset + 2]);
  }

  var count = 0;
  var mean = 0.0;
  var squaredDifferenceSum = 0.0;
  for (var y = 1; y < input.height - 1; y++) {
    for (var x = 1; x < input.width - 1; x++) {
      final center = luminanceAt(x, y);
      final response =
          luminanceAt(x, y - 1) +
          luminanceAt(x - 1, y) -
          (4 * center) +
          luminanceAt(x + 1, y) +
          luminanceAt(x, y + 1);
      count++;
      final delta = response - mean;
      mean += delta / count;
      squaredDifferenceSum += delta * (response - mean);
    }
  }
  return count == 0 ? null : squaredDifferenceSum / count;
}

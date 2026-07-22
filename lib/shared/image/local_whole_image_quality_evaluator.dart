import 'dart:ui' as ui;

import 'package:blindbox_app/shared/image/catalog_photo_acquisition.dart';
import 'package:blindbox_app/shared/image/whole_image_quality.dart';
import 'package:blindbox_app/shared/image/whole_image_quality_config.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as image;

/// Local, fail-open screening for an obviously blurred entire photograph.
///
/// This evaluator does not assess a selected subject or predict recognition.
final class LocalWholeImageQualityEvaluator
    implements WholeImageQualityEvaluator {
  const LocalWholeImageQualityEvaluator();

  @override
  Future<WholeImageQualityResult> evaluate(
    CatalogPhotoSelection selection,
  ) async {
    try {
      final bytes = await selection.file.readAsBytes();
      if (bytes.isEmpty) return _unavailable;
      final variance =
          await compute(_varianceFromEncodedImage, bytes) ??
          await _varianceFromPlatformCodec(bytes);
      if (variance == null || !variance.isFinite) return _unavailable;
      return WholeImageQualityResult(
        outcome: WholeImageQualityConfig.passes(variance)
            ? WholeImageQualityOutcome.usable
            : WholeImageQualityOutcome.obviouslyTooBlurry,
        metricId: WholeImageQualityConfig.metricId,
        metricValue: variance,
        evaluatorVersion: WholeImageQualityConfig.evaluatorVersion,
      );
    } catch (_) {
      return _unavailable;
    }
  }

  WholeImageQualityResult get _unavailable => const WholeImageQualityResult(
    outcome: WholeImageQualityOutcome.evaluationUnavailable,
    evaluatorVersion: WholeImageQualityConfig.evaluatorVersion,
  );

  Future<double?> _varianceFromPlatformCodec(Uint8List bytes) async {
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
      return compute(_varianceFromRgba, (
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

double? _varianceFromEncodedImage(Uint8List bytes) {
  final decoded = image.decodeImage(bytes);
  if (decoded == null) return null;
  final oriented = image.bakeOrientation(decoded);
  final normalized = _resizeForAnalysis(oriented);
  return _varianceOfLaplacian(
    width: normalized.width,
    height: normalized.height,
    luminanceAt: (x, y) => normalized.getPixel(x, y).luminance.toDouble(),
  );
}

double? _varianceFromRgba(({Uint8List bytes, int width, int height}) input) =>
    _varianceOfLaplacian(
      width: input.width,
      height: input.height,
      luminanceAt: (x, y) {
        final offset = ((y * input.width) + x) * 4;
        return (0.299 * input.bytes[offset]) +
            (0.587 * input.bytes[offset + 1]) +
            (0.114 * input.bytes[offset + 2]);
      },
    );

double? _varianceOfLaplacian({
  required int width,
  required int height,
  required double Function(int x, int y) luminanceAt,
}) {
  if (width < 3 || height < 3) return null;
  var count = 0;
  var mean = 0.0;
  var squaredDifferenceSum = 0.0;
  for (var y = 1; y < height - 1; y++) {
    for (var x = 1; x < width - 1; x++) {
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

(int, int) _analysisSize(int width, int height) {
  final longest = width > height ? width : height;
  if (longest <= WholeImageQualityConfig.analysisMaxDimension) {
    return (width, height);
  }
  if (width >= height) {
    final target = WholeImageQualityConfig.analysisMaxDimension;
    return (target, (height * target / width).round().clamp(3, target));
  }
  final target = WholeImageQualityConfig.analysisMaxDimension;
  return ((width * target / height).round().clamp(3, target), target);
}

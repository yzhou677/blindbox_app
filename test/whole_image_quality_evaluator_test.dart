import 'dart:typed_data';

import 'package:blindbox_app/shared/image/catalog_photo_acquisition.dart';
import 'package:blindbox_app/shared/image/local_whole_image_quality_evaluator.dart';
import 'package:blindbox_app/shared/image/whole_image_quality.dart';
import 'package:blindbox_app/shared/image/whole_image_quality_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:image_picker/image_picker.dart';

void main() {
  const evaluator = LocalWholeImageQualityEvaluator();

  test('normal detailed full photo passes', () async {
    final source = image.Image(width: 160, height: 120);
    for (var y = 0; y < source.height; y++) {
      for (var x = 0; x < source.width; x++) {
        final light = ((x ~/ 8) + (y ~/ 8)).isEven;
        source.setPixelRgb(x, y, light ? 230 : 30, light ? 210 : 40, 80);
      }
    }

    final result = await evaluator.evaluate(
      _selection(image.encodeJpg(source)),
    );

    expect(result.outcome, WholeImageQualityOutcome.usable);
    expect(result.metricId, WholeImageQualityConfig.metricId);
    expect(result.metricValue, isNotNull);
  });

  test('obviously blurred full photo is rejected', () async {
    final source = image.Image(width: 160, height: 120);
    for (var y = 0; y < source.height; y++) {
      for (var x = 0; x < source.width; x++) {
        final value = 60 + ((x / source.width) * 130).round();
        source.setPixelRgb(x, y, value, value, value);
      }
    }

    final result = await evaluator.evaluate(
      _selection(image.encodePng(source)),
    );

    expect(result.outcome, WholeImageQualityOutcome.obviouslyTooBlurry);
    expect(
      result.metricValue,
      lessThan(WholeImageQualityConfig.varianceOfLaplacianThreshold),
    );
  });

  test('threshold equality passes by centralized policy', () {
    expect(
      WholeImageQualityConfig.passes(
        WholeImageQualityConfig.varianceOfLaplacianThreshold,
      ),
      isTrue,
    );
    expect(
      WholeImageQualityConfig.passes(
        WholeImageQualityConfig.varianceOfLaplacianThreshold - 0.000001,
      ),
      isFalse,
    );
  });

  test('decode failure is evaluation unavailable and fails open', () async {
    final result = await evaluator.evaluate(_selection(const [1, 2, 3]));

    expect(result.outcome, WholeImageQualityOutcome.evaluationUnavailable);
    expect(result.canContinue, isTrue);
  });
}

CatalogPhotoSelection _selection(List<int> bytes) => CatalogPhotoSelection(
  file: XFile.fromData(
    Uint8List.fromList(bytes),
    name: 'photo.png',
    mimeType: 'image/png',
  ),
  source: CatalogPhotoSource.gallery,
);

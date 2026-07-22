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

  test(
    'obviously blurry whole image fails the conservative precheck',
    () async {
      final source = image.Image(width: 160, height: 120);
      for (var y = 0; y < source.height; y++) {
        for (var x = 0; x < source.width; x++) {
          final value = ((x / source.width) * 80 + 80).round();
          source.setPixelRgb(x, y, value, value, value);
        }
      }

      final result = await evaluator.evaluate(
        _selection(image.encodePng(source)),
      );

      expect(result.status, WholeImageQualityStatus.obviouslyBlurry);
      expect(
        result.laplacianVariance,
        lessThan(WholeImageQualityConfig.extremeBlurThreshold),
      );
    },
  );

  test('normal detailed whole image passes', () async {
    final source = image.Image(width: 160, height: 120);
    for (var y = 0; y < source.height; y++) {
      for (var x = 0; x < source.width; x++) {
        final light = ((x ~/ 8) + (y ~/ 8)).isEven;
        source.setPixelRgb(
          x,
          y,
          light ? 230 : 30,
          light ? 210 : 40,
          light ? 190 : 50,
        );
      }
    }

    final result = await evaluator.evaluate(
      _selection(image.encodeJpg(source)),
    );

    expect(result.status, WholeImageQualityStatus.pass);
    expect(result.passed, isTrue);
  });

  test('empty and unreadable images fail as invalid', () async {
    final empty = await evaluator.evaluate(_selection(const []));
    final unreadable = await evaluator.evaluate(_selection([1, 2, 3, 4]));

    expect(empty.status, WholeImageQualityStatus.invalid);
    expect(unreadable.status, WholeImageQualityStatus.invalid);
  });

  test(
    'policy threshold and equality behavior are centralized and versioned',
    () {
      expect(
        WholeImageQualityConfig.evaluatorVersion,
        'whole-image-quality-v1',
      );
      expect(
        WholeImageQualityConfig.passes(
          WholeImageQualityConfig.extremeBlurThreshold,
        ),
        isTrue,
      );
      expect(
        WholeImageQualityConfig.passes(
          WholeImageQualityConfig.extremeBlurThreshold - 0.000001,
        ),
        isFalse,
      );
    },
  );
}

CatalogPhotoSelection _selection(List<int> bytes) {
  return CatalogPhotoSelection(
    file: XFile.fromData(
      Uint8List.fromList(bytes),
      name: 'photo.png',
      mimeType: 'image/png',
    ),
    source: CatalogPhotoSource.gallery,
  );
}

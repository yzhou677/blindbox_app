import 'dart:convert';

import 'package:blindbox_app/shared/image/catalog_subject_selection.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as image;

const catalogRecognitionMaxInputDimension = 4096;
const catalogRecognitionJpegQuality = 92;

typedef CatalogRecognitionBase64Encoder = String Function(List<int> bytes);

class PreparedCatalogRecognitionImage {
  const PreparedCatalogRecognitionImage({
    required this.bytes,
    required this.mimeType,
    required this.width,
    required this.height,
    required this.originalByteSize,
    required this.dataBase64,
    this.requestVersion = 2,
  });

  final Uint8List bytes;
  final String mimeType;
  final int width;
  final int height;
  final int originalByteSize;
  final String dataBase64;
  final int requestVersion;
}

abstract interface class CatalogRecognitionImagePreparer {
  Future<PreparedCatalogRecognitionImage> prepare(
    CatalogSubjectSelectionResult selection,
  );
}

final class LocalCatalogRecognitionImagePreparer
    implements CatalogRecognitionImagePreparer {
  const LocalCatalogRecognitionImagePreparer({
    this.base64Encoder = base64Encode,
  });

  final CatalogRecognitionBase64Encoder base64Encoder;

  @override
  Future<PreparedCatalogRecognitionImage> prepare(
    CatalogSubjectSelectionResult selection,
  ) async {
    final source = await selection.photo.file.readAsBytes();
    if (source.isEmpty) throw const FormatException('Empty image');
    final prepared = await compute(_prepareRecognitionCrop, (
      source,
      selection.normalizedRect.left,
      selection.normalizedRect.top,
      selection.normalizedRect.right,
      selection.normalizedRect.bottom,
    ));
    return PreparedCatalogRecognitionImage(
      bytes: prepared.$1,
      mimeType: prepared.$2,
      width: prepared.$3,
      height: prepared.$4,
      originalByteSize: source.length,
      dataBase64: base64Encoder(prepared.$1),
    );
  }
}

(Uint8List, String, int, int) _prepareRecognitionCrop(
  (Uint8List, double, double, double, double) input,
) {
  final decoded = image.decodeImage(input.$1);
  if (decoded == null) throw const FormatException('Unreadable image');
  final oriented = image.bakeOrientation(decoded);
  final left = (input.$2 * oriented.width).floor().clamp(0, oriented.width - 1);
  final top = (input.$3 * oriented.height).floor().clamp(
    0,
    oriented.height - 1,
  );
  final right = (input.$4 * oriented.width).ceil().clamp(
    left + 1,
    oriented.width,
  );
  final bottom = (input.$5 * oriented.height).ceil().clamp(
    top + 1,
    oriented.height,
  );
  var crop = image.copyCrop(
    oriented,
    x: left,
    y: top,
    width: right - left,
    height: bottom - top,
  );
  final longest = crop.width > crop.height ? crop.width : crop.height;
  if (longest > catalogRecognitionMaxInputDimension) {
    final scale = catalogRecognitionMaxInputDimension / longest;
    crop = image.copyResize(
      crop,
      width: (crop.width * scale).round(),
      height: (crop.height * scale).round(),
      interpolation: image.Interpolation.cubic,
    );
  }
  final hasAlpha = crop.numChannels == 4;
  final bytes = hasAlpha
      ? image.encodePng(crop)
      : image.encodeJpg(crop, quality: catalogRecognitionJpegQuality);
  return (
    Uint8List.fromList(bytes),
    hasAlpha ? 'image/png' : 'image/jpeg',
    crop.width,
    crop.height,
  );
}

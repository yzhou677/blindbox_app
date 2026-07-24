import 'dart:ui';

import 'package:blindbox_app/shared/image/catalog_photo_acquisition.dart';

enum SubjectSelectionOrigin {
  defaultBox,
  suggestedBox,
  userEdited,
  userRedrawn,
}

/// A subject rectangle expressed from 0 to 1 in oriented-image coordinates.
class NormalizedSubjectRect {
  const NormalizedSubjectRect({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  }) : assert(left >= 0 && left <= 1),
       assert(top >= 0 && top <= 1),
       assert(right >= 0 && right <= 1),
       assert(bottom >= 0 && bottom <= 1),
       assert(left < right),
       assert(top < bottom);

  factory NormalizedSubjectRect.fromRect(Rect rect) => NormalizedSubjectRect(
    left: rect.left,
    top: rect.top,
    right: rect.right,
    bottom: rect.bottom,
  );

  final double left;
  final double top;
  final double right;
  final double bottom;

  Rect get rect => Rect.fromLTRB(left, top, right, bottom);
}

class CatalogSubjectSelectionResult {
  const CatalogSubjectSelectionResult({
    required this.photo,
    required this.normalizedRect,
    required this.sourceImageRect,
    required this.orientedSourceSize,
    required this.origin,
  });

  final CatalogPhotoSelection photo;
  final NormalizedSubjectRect normalizedRect;

  /// Crop rectangle in pixels in the orientation shown to the collector.
  final Rect sourceImageRect;
  final Size orientedSourceSize;
  final SubjectSelectionOrigin origin;
}

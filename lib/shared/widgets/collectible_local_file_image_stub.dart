import 'package:blindbox_app/features/collection/widgets/collectible_figure_placeholder.dart';
import 'package:flutter/material.dart';

/// Web / unsupported: local file paths are not loaded.
Widget buildCollectibleLocalFileImage({
  required String filePath,
  required String name,
  required String seedKey,
  required bool isSecret,
  required bool compact,
  required BoxFit fit,
  required BorderRadius borderRadius,
}) {
  return CollectibleFigurePlaceholder(
    name: name,
    seedKey: seedKey,
    isSecret: isSecret,
    compact: compact,
  );
}

import 'package:blindbox_app/features/collection/data/collection_input_limits.dart';
import 'package:flutter/services.dart';

/// TextField formatters aligned with [CollectionInputLimits].
abstract final class CollectionInputFormatters {
  static final FilteringTextInputFormatter denyLineBreaks =
      FilteringTextInputFormatter.deny(RegExp(r'[\n\r]'));

  static List<TextInputFormatter> singleLine(int maxLength) => [
        denyLineBreaks,
        LengthLimitingTextInputFormatter(maxLength),
      ];

  static List<TextInputFormatter> seriesName() =>
      singleLine(CollectionInputLimits.seriesNameMaxLength);

  static List<TextInputFormatter> brand() =>
      singleLine(CollectionInputLimits.brandMaxLength);

  static List<TextInputFormatter> ip() =>
      singleLine(CollectionInputLimits.ipMaxLength);

  static List<TextInputFormatter> figureName() =>
      singleLine(CollectionInputLimits.figureNameMaxLength);

  static List<TextInputFormatter> rarityLabel() =>
      singleLine(CollectionInputLimits.rarityLabelMaxLength);

  static List<TextInputFormatter> notes() => [
        LengthLimitingTextInputFormatter(CollectionInputLimits.notesMaxLength),
      ];
}

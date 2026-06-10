import 'package:blindbox_app/features/collection/data/collection_input_limits.dart';

/// Save-time normalization for custom collection metadata (before canonicalization).
abstract final class CollectionInputSanitizer {
  static final RegExp _controlChars = RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]');
  static final RegExp _lineBreaks = RegExp(r'[\n\r]+');
  static final RegExp _repeatedWhitespace = RegExp(r'\s+');

  /// Single-line shelf labels — trim, collapse whitespace, strip controls/newlines.
  static String? singleLine(String? raw, {required int maxLength}) {
    if (raw == null) return null;
    var s = raw.replaceAll(_lineBreaks, ' ');
    s = s.replaceAll(_controlChars, '');
    s = s.trim();
    if (s.isEmpty) return null;
    s = s.replaceAll(_repeatedWhitespace, ' ');
    if (s.length > maxLength) {
      s = s.substring(0, maxLength).trimRight();
    }
    return s.isEmpty ? null : s;
  }

  /// Multi-line notes — trim ends, strip controls, preserve intentional breaks.
  static String? notes(String? raw) {
    if (raw == null) return null;
    var s = raw.replaceAll(_controlChars, '');
    s = s.trim();
    if (s.isEmpty) return null;
    if (s.length > CollectionInputLimits.notesMaxLength) {
      s = s.substring(0, CollectionInputLimits.notesMaxLength).trimRight();
    }
    return s.isEmpty ? null : s;
  }

  static String seriesName(String raw) {
    return singleLine(
          raw,
          maxLength: CollectionInputLimits.seriesNameMaxLength,
        ) ??
        '';
  }

  static String? brand(String? raw) {
    return singleLine(raw, maxLength: CollectionInputLimits.brandMaxLength);
  }

  static String? ip(String? raw) {
    return singleLine(raw, maxLength: CollectionInputLimits.ipMaxLength);
  }

  static String? figureName(String? raw) {
    return singleLine(raw, maxLength: CollectionInputLimits.figureNameMaxLength);
  }

  static String? rarityLabel(String? raw) {
    return singleLine(raw, maxLength: CollectionInputLimits.rarityLabelMaxLength);
  }
}

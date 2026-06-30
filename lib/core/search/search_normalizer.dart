/// Shared normalization for all local Shelfy search surfaces (Search V2).
///
/// Deterministic: trim → lowercase → separator folding → whitespace collapse.
abstract final class SearchNormalizer {
  /// Normalizes [raw] for matching and history storage.
  ///
  /// Separator characters (×, -, _, /, ., ·, |, •) become spaces so titles like
  /// `THE MONSTERS × HELLO KITTY` match queries such as `the monsters hello kitty`.
  static String normalize(String raw) {
    final buf = StringBuffer();
    for (var i = 0; i < raw.length; i++) {
      final c = raw.codeUnitAt(i);
      if (_isSeparator(c)) {
        buf.write(' ');
        continue;
      }
      if (c >= 0x41 && c <= 0x5a) {
        buf.writeCharCode(c + 0x20);
      } else {
        buf.writeCharCode(c);
      }
    }
    return _collapseWhitespace(buf.toString().trim());
  }

  static bool _isSeparator(int c) {
    return c == 0x20 ||
        c == 0x2d || // -
        c == 0x5f || // _
        c == 0x2f || // /
        c == 0x2e || // .
        c == 0x7c || // |
        c == 0xb7 || // ·
        c == 0x2022 || // •
        c == 0x2013 || // –
        c == 0x2014 || // —
        c == 0xd7; // ×
  }

  static String _collapseWhitespace(String s) {
    if (s.isEmpty) return '';
    return s.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).join(' ');
  }
}

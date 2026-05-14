/// Pure, deterministic title normalization for taxonomy substring checks.
///
/// Preserves non-Latin characters (e.g. CJK aliases); only normalizes separators
/// and collapses whitespace. Latin letters are uppercased.
abstract final class TaxonomyTitleNormalizer {
  /// Trim, uppercase Latin, unify common separators to spaces, collapse whitespace.
  static String normalize(String raw) {
    var s = raw.trim();
    if (s.isEmpty) return '';

    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final c = s.codeUnitAt(i);
      // Common marketplace / listing punctuation → space
      if (_isSeparator(c)) {
        buf.write(' ');
        continue;
      }
      // Uppercase ASCII letters only; leave other code units unchanged.
      if (c >= 0x41 && c <= 0x5a) {
        buf.writeCharCode(c);
      } else if (c >= 0x61 && c <= 0x7a) {
        buf.writeCharCode(c - 0x20);
      } else {
        buf.write(String.fromCharCode(c));
      }
    }
    return _collapseWhitespace(buf.toString());
  }

  static bool _isSeparator(int c) {
    return c == 0x20 ||
        c == 0x2d || // -
        c == 0x5f || // _
        c == 0x2f || // /
        c == 0x7c || // |
        c == 0xb7 || // · MIDDLE DOT
        c == 0x2022; // • BULLET (rare in titles)
  }

  static String _collapseWhitespace(String s) {
    final parts = s.split(RegExp(r'\s+')).where((e) => e.isNotEmpty);
    return parts.join(' ');
  }
}

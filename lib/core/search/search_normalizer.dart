/// Shared normalization for all local Shelfy search surfaces (Search V2).
///
/// Deterministic pipeline for matching and history:
/// trim → lowercase → fold separators/symbols → collapse whitespace →
/// optional boilerplate stripping.
///
/// [normalizeForMatch] additionally appends a space-compacted form so queries
/// like `popmart` match catalog text `POP MART` without catalog aliases.
abstract final class SearchNormalizer {
  /// Normalizes [raw] for tokenization, history storage, and exact-name checks.
  static String normalize(String raw) {
    return _finalize(_foldCharacters(raw.trim()));
  }

  /// Spaced [normalize] with spaces removed — e.g. `pop mart` → `popmart`.
  static String compact(String normalized) {
    if (normalized.isEmpty) return '';
    return normalized.replaceAll(' ', '');
  }

  /// Haystack segment for substring matching: spaced form plus compact twin when
  /// they differ (e.g. `pop mart popmart`).
  static String normalizeForMatch(String raw) {
    final spaced = normalize(raw);
    if (spaced.isEmpty) return '';
    final compacted = compact(spaced);
    return compacted == spaced ? spaced : '$spaced $compacted';
  }

  static String _finalize(String folded) {
    var s = _collapseWhitespace(folded);
    s = _stripBoilerplate(s);
    return s;
  }

  static String _foldCharacters(String raw) {
    final buf = StringBuffer();
    for (var i = 0; i < raw.length; i++) {
      final c = raw.codeUnitAt(i);
      if (_isIgnorableSymbol(c)) {
        continue;
      }
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
    return buf.toString();
  }

  /// Decorative / legal marks and punctuation that do not change identity.
  static bool _isIgnorableSymbol(int c) {
    return c == 0xae || // ®
        c == 0xa9 || // ©
        c == 0xb0 || // °
        c == 0x2122 || // ™
        c == 0x21 || // !
        c == 0x3f || // ?
        c == 0x28 || // (
        c == 0x29 || // )
        c == 0x5b || // [
        c == 0x5d || // ]
        c == 0x7b || // {
        c == 0x7d; // }
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

  /// Product-title filler removed from both queries and haystacks (longest first).
  static const List<String> _boilerplatePhrases = [
    'series figures',
    'vinyl plush pendant blind box',
    'vinyl plush blind box',
    'vinyl face blind box',
    'plush pendant blind box',
    'series figure',
    'blind boxes',
    'blind box',
    'vinyl plush pendant',
    'vinyl plush',
    'vinyl face',
    'plush pendant',
    'plush doll',
    'plush blind box',
    'action figure',
    'hanging card',
    'blister pack',
    'earphone case',
    'figures',
    'figure',
    'series',
  ];

  static String _stripBoilerplate(String normalized) {
    var s = normalized;
    var changed = true;
    while (changed) {
      changed = false;
      for (final phrase in _boilerplatePhrases) {
        final next = _removePhrase(s, phrase);
        if (next != s) {
          s = next;
          changed = true;
        }
      }
    }
    return _collapseWhitespace(s);
  }

  static String _removePhrase(String s, String phrase) {
    final pattern = RegExp(
      '(?:^|\\s)${RegExp.escape(phrase)}(?:\\s|\$)',
    );
    return _collapseWhitespace(s.replaceAll(pattern, ' '));
  }
}

import 'package:flutter/material.dart';

/// Normalizes eBay listing description copy for safe UI rendering.
String? sanitizeListingDescription(String? raw) {
  if (raw == null) return null;

  var text = raw.trim();
  if (text.isEmpty) return null;

  text = text.replaceAll(RegExp(r'<[^>]*>', multiLine: true), ' ');
  text = _decodeCommonHtmlEntities(text);
  text = text.replaceAll(RegExp(r'[\u0000-\u0008\u000B\u000C\u000E-\u001F]'), ' ');
  text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (text.isEmpty) return null;

  return text;
}

String _decodeCommonHtmlEntities(String raw) {
  return raw
      .replaceAll(RegExp(r'&nbsp;|&#160;', caseSensitive: false), ' ')
      .replaceAll(RegExp(r'&amp;|&#38;', caseSensitive: false), '&')
      .replaceAll(RegExp(r'&lt;|&#60;', caseSensitive: false), '<')
      .replaceAll(RegExp(r'&gt;|&#62;', caseSensitive: false), '>')
      .replaceAll(RegExp(r'&quot;|&#34;', caseSensitive: false), '"')
      .replaceAll(RegExp(r'&apos;|&#39;', caseSensitive: false), "'")
      .replaceAll(RegExp(r'&mdash;|&#8212;', caseSensitive: false), '—')
      .replaceAll(RegExp(r'&ndash;|&#8211;', caseSensitive: false), '–')
      .replaceAll(RegExp(r'&hellip;|&#8230;', caseSensitive: false), '…')
      .replaceAllMapped(RegExp(r'&#(\d+);'), (match) {
        final code = int.tryParse(match.group(1) ?? '');
        if (code == null || code <= 0 || code > 0x10FFFF) return '';
        return String.fromCharCode(code);
      });
}

/// Whether [text] exceeds [maxLines] at [maxWidth] for [style].
bool listingDescriptionExceedsCollapsedLines({
  required String text,
  required TextStyle style,
  required double maxWidth,
  required int maxLines,
  required TextDirection textDirection,
}) {
  if (maxWidth <= 0 || maxLines < 1) return false;
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    maxLines: maxLines,
    textDirection: textDirection,
  )..layout(maxWidth: maxWidth);
  return painter.didExceedMaxLines;
}

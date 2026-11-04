import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Scans `lib/**/*.dart` user-visible string literals for curly quotes.
///
/// Comments are ignored. Catches ’ “ ” so copy cannot regress to typographic
/// apostrophes/quotes.
void main() {
  test('lib user-visible strings use straight ASCII quotes only', () {
    final lib = Directory('lib');
    expect(lib.existsSync(), isTrue);

    final offenders = <String>[];
    final dartFiles = lib
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));

    for (final file in dartFiles) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        final code = _stripLineComment(line);
        if (!_containsCurlyQuoteInStringLiteral(code)) continue;
        offenders.add('${file.path}:${i + 1}: $line');
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'Curly quotes in user-visible strings:\n${offenders.join('\n')}',
    );
  });
}

String _stripLineComment(String line) {
  var inSingle = false;
  var inDouble = false;
  var inRaw = false;
  for (var i = 0; i < line.length; i++) {
    final c = line[i];
    final prev = i > 0 ? line[i - 1] : '';
    if (!inSingle && !inDouble && c == '/' && i + 1 < line.length && line[i + 1] == '/') {
      // Skip /// and // comments outside strings.
      return line.substring(0, i);
    }
    if (!inDouble && c == "'" && prev != r'\') {
      if (!inSingle && i > 0 && (line[i - 1] == 'r' || line[i - 1] == 'R')) {
        inRaw = true;
      }
      inSingle = !inSingle;
      if (!inSingle) inRaw = false;
      continue;
    }
    if (!inSingle && c == '"' && prev != r'\') {
      if (!inDouble && i > 0 && (line[i - 1] == 'r' || line[i - 1] == 'R')) {
        inRaw = true;
      }
      inDouble = !inDouble;
      if (!inDouble) inRaw = false;
      continue;
    }
    // Keep scanning; inRaw unused beyond tracking for clarity.
    if (inRaw) {
      // no-op
    }
  }
  return line;
}

bool _containsCurlyQuoteInStringLiteral(String line) {
  const curly = {'’', '“', '”'};
  var inSingle = false;
  var inDouble = false;
  for (var i = 0; i < line.length; i++) {
    final c = line[i];
    final prev = i > 0 ? line[i - 1] : '';
    if (!inDouble && c == "'" && prev != r'\') {
      inSingle = !inSingle;
      continue;
    }
    if (!inSingle && c == '"' && prev != r'\') {
      inDouble = !inDouble;
      continue;
    }
    if ((inSingle || inDouble) && curly.contains(c)) return true;
  }
  return false;
}

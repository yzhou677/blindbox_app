import 'package:flutter/foundation.dart';

/// Detects strings that should be loaded with [Image.file] / [dart:io] (not web).
abstract final class DeviceLocalImageRef {
  static bool looksLikeDevicePath(String? ref) {
    final r = ref?.trim() ?? '';
    if (r.isEmpty) return false;
    if (r.startsWith('assets/')) return false;
    final lower = r.toLowerCase();
    if (lower.startsWith('http://') || lower.startsWith('https://')) return false;
    if (r.startsWith('file:')) return true;
    if (kIsWeb) return false;
    if (r.startsWith('/')) return true;
    if (r.length > 2 && r.codeUnitAt(1) == 0x3A && _isAsciiLetter(r.codeUnitAt(0))) {
      return true;
    }
    return false;
  }

  static bool _isAsciiLetter(int c) =>
      (c >= 0x41 && c <= 0x5A) || (c >= 0x61 && c <= 0x7A);

  static String normalizeToFilePath(String ref) {
    final t = ref.trim();
    if (t.startsWith('file:')) {
      return Uri.parse(t).toFilePath();
    }
    return t;
  }
}

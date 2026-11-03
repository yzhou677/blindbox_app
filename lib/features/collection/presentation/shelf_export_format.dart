/// Human-readable backup size labels for Settings export copy.
abstract final class ShelfExportFormat {
  ShelfExportFormat._();

  /// Formats [bytes] as `12 MB` / `1.5 GB` style English labels.
  static String formatBytes(int bytes) {
    if (bytes < 0) bytes = 0;
    const kb = 1024;
    const mb = 1024 * 1024;
    const gb = 1024 * 1024 * 1024;
    if (bytes >= gb) {
      final value = bytes / gb;
      final text = value >= 10
          ? value.round().toString()
          : value.toStringAsFixed(1);
      return '$text GB';
    }
    if (bytes >= mb) {
      final value = bytes / mb;
      final text = value >= 10
          ? value.round().toString()
          : value.toStringAsFixed(1);
      return '$text MB';
    }
    if (bytes >= kb) {
      return '${(bytes / kb).ceil()} KB';
    }
    return '$bytes B';
  }
}

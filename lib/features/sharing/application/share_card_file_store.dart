import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

class ShareCardFileStore {
  const ShareCardFileStore();

  Future<void> cleanupOldTemporaryPngs({
    Duration maxAge = const Duration(days: 2),
  }) async {
    final root = await getTemporaryDirectory();
    final dir = Directory('${root.path}${Platform.pathSeparator}shelfy_share');
    if (!dir.existsSync()) return;

    final cutoff = DateTime.now().subtract(maxAge);
    await for (final entity in dir.list()) {
      if (entity is! File || !entity.path.toLowerCase().endsWith('.png')) {
        continue;
      }
      try {
        final stat = await entity.stat();
        if (stat.modified.isBefore(cutoff)) {
          await entity.delete();
        }
      } catch (_) {
        // Best-effort cache cleanup must never block sharing.
      }
    }
  }

  Future<File> writeTemporaryPng({
    required Uint8List bytes,
    required String basename,
  }) async {
    final root = await getTemporaryDirectory();
    final dir = Directory('${root.path}${Platform.pathSeparator}shelfy_share');
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    final safe = basename
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_-]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    final name = safe.isEmpty ? 'share-card' : safe;
    final file = File(
      '${dir.path}${Platform.pathSeparator}$name-${DateTime.now().millisecondsSinceEpoch}.png',
    );
    return file.writeAsBytes(bytes, flush: true);
  }
}

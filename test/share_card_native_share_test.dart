import 'dart:io';
import 'dart:ui';

import 'package:blindbox_app/features/sharing/application/share_card_native_share.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus/share_plus.dart';

void main() {
  test(
    'sharePng passes exactly one existing PNG file with image/png MIME',
    () async {
      final dir = await Directory.systemTemp.createTemp('shelfy_share_test_');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}${Platform.pathSeparator}card.png');
      await file.writeAsBytes([137, 80, 78, 71, 13, 10, 26, 10], flush: true);

      final calls = <ShareParams>[];
      final nativeShare = ShareCardNativeShare(
        launcher: (params) async {
          calls.add(params);
          return const ShareResult('ok', ShareResultStatus.success);
        },
      );

      final result = await nativeShare.sharePng(
        file: file,
        fileName: 'collector-card.png',
        sharePositionOrigin: const Rect.fromLTWH(1, 2, 3, 4),
      );

      expect(result.status, ShareResultStatus.success);
      expect(calls, hasLength(1));
      final params = calls.single;
      expect(params.files, hasLength(1));
      expect(params.files!.single.path, file.path);
      expect(params.files!.single.mimeType, 'image/png');
      expect(params.files!.single.name, 'card.png');
      expect(params.fileNameOverrides, ['collector-card.png']);
      expect(params.sharePositionOrigin, const Rect.fromLTWH(1, 2, 3, 4));
      expect(File(params.files!.single.path).existsSync(), isTrue);
    },
  );

  test(
    'sharePng propagates launcher failures for preview error handling',
    () async {
      final dir = await Directory.systemTemp.createTemp('shelfy_share_test_');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}${Platform.pathSeparator}card.png');
      await file.writeAsBytes([1, 2, 3], flush: true);
      final nativeShare = ShareCardNativeShare(
        launcher: (_) => throw StateError('share failed'),
      );

      expect(
        nativeShare.sharePng(file: file, fileName: 'collector-card.png'),
        throwsStateError,
      );
    },
  );
}

import 'dart:io';
import 'dart:ui';

import 'package:share_plus/share_plus.dart';

typedef ShareCardShareLauncher =
    Future<ShareResult> Function(ShareParams params);

class ShareCardNativeShare {
  ShareCardNativeShare({SharePlus? sharePlus, ShareCardShareLauncher? launcher})
    : _launcher = launcher ?? (sharePlus ?? SharePlus.instance).share;

  final ShareCardShareLauncher _launcher;

  Future<ShareResult> sharePng({
    required File file,
    required String fileName,
    Rect? sharePositionOrigin,
  }) async {
    return _launcher(
      ShareParams(
        files: [XFile(file.path, mimeType: 'image/png', name: fileName)],
        fileNameOverrides: [fileName],
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
  }
}

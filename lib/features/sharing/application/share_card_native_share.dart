import 'dart:io';
import 'dart:ui';

import 'package:share_plus/share_plus.dart';

class ShareCardNativeShare {
  ShareCardNativeShare({SharePlus? sharePlus})
    : _sharePlus = sharePlus ?? SharePlus.instance;

  final SharePlus _sharePlus;

  Future<ShareResult> sharePng({
    required File file,
    required String fileName,
    Rect? sharePositionOrigin,
  }) {
    return _sharePlus.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'image/png', name: fileName)],
        fileNameOverrides: [fileName],
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
  }
}

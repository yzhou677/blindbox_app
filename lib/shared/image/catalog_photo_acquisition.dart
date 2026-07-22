import 'package:image_picker/image_picker.dart';

enum CatalogPhotoSource { camera, gallery }

class CatalogPhotoSelection {
  const CatalogPhotoSelection({required this.file, required this.source});

  final XFile file;
  final CatalogPhotoSource source;
}

abstract interface class CatalogPhotoAcquirer {
  Future<CatalogPhotoSelection?> acquire(CatalogPhotoSource source);
}

class ImagePickerCatalogPhotoAcquirer implements CatalogPhotoAcquirer {
  ImagePickerCatalogPhotoAcquirer({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<CatalogPhotoSelection?> acquire(CatalogPhotoSource source) async {
    final file = await _picker.pickImage(
      source: source == CatalogPhotoSource.camera
          ? ImageSource.camera
          : ImageSource.gallery,
    );
    if (file == null) return null;
    final length = await file.length();
    if (length <= 0) throw const FormatException('The selected image is empty.');
    final mimeType = file.mimeType?.toLowerCase();
    final path = file.path.toLowerCase();
    final supportedMime = mimeType == null || const {
      'image/jpeg',
      'image/png',
      'image/webp',
      'image/heic',
      'image/heif',
    }.contains(mimeType);
    final supportedExtension = const ['.jpg', '.jpeg', '.png', '.webp', '.heic', '.heif']
        .any(path.endsWith);
    if (!supportedMime || (mimeType == null && !supportedExtension)) {
      throw const FormatException('That image format is not supported.');
    }
    return CatalogPhotoSelection(file: file, source: source);
  }
}

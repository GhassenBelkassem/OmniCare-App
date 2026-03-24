import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

class FilePickerService {
  final ImagePicker _picker;

  FilePickerService({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  Future<XFile?> pickAndCompressImage({
    ImageSource source = ImageSource.gallery,
    int maxWidth = 1024,
    int maxHeight = 1024,
    int quality = 80,
  }) async {
    final picked = await _picker.pickImage(source: source);
    if (picked == null) return null;

    if (kIsWeb) {
      return picked;
    }

    final inputPath = picked.path;

    final tempDir = await getTemporaryDirectory();
    final outPath =
        '${tempDir.path}/img_${DateTime.now().millisecondsSinceEpoch}.jpg';

    final compressed = await FlutterImageCompress.compressAndGetFile(
      inputPath,
      outPath,
      quality: quality,
      minWidth: maxWidth,
      minHeight: maxHeight,
      format: CompressFormat.jpeg,
    );

    if (compressed == null) return picked;
    final path = compressed.path;
    if (path.isEmpty) return picked;
    return XFile(path);
  }
}

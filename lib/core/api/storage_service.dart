import 'dart:io';

import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

abstract class IStorageService {
  Future<String> uploadDocument(File file, String folder);
}

class CloudinaryStorageImpl implements IStorageService {
  CloudinaryStorageImpl();

  CloudinaryPublic _client() {
    final cloudName = dotenv.env['CLOUDINARY_CLOUD_NAME']?.trim();
    final uploadPreset = dotenv.env['CLOUDINARY_UPLOAD_PRESET']?.trim();

    if (cloudName == null || cloudName.isEmpty) {
      throw StateError('CLOUDINARY_CLOUD_NAME is not set.');
    }
    if (uploadPreset == null || uploadPreset.isEmpty) {
      throw StateError('CLOUDINARY_UPLOAD_PRESET is not set.');
    }

    return CloudinaryPublic(cloudName, uploadPreset, cache: false);
  }

  @override
  Future<String> uploadDocument(File file, String folder) async {
    final filePath = file.path;
    if (filePath.isEmpty) {
      throw ArgumentError('File path is empty');
    }

    final cloudinary = _client();

    final response = await cloudinary.uploadFile(
      CloudinaryFile.fromFile(
        filePath,
        folder: folder,
        resourceType: CloudinaryResourceType.Auto,
      ),
    );

    final url = response.secureUrl;
    if (url.isEmpty) {
      throw StateError('Cloudinary upload succeeded but returned empty URL');
    }

    return url;
  }
}

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import 'dio_client.dart';

class FilesApi {
  final Dio _dio;

  FilesApi({Dio? dio}) : _dio = dio ?? DioClient.instance.dio;

  Future<FileUploadResponse> uploadFile({
    required XFile file,
    required String folder,
  }) async {
    debugPrint('[FilesApi] uploadFile() -> POST /api/files/upload');

    final fileName = _filenameFromPath(file.path);

    MultipartFile multipart;
    if (kIsWeb) {
      final bytes = await file.readAsBytes();
      multipart = MultipartFile.fromBytes(bytes, filename: fileName);
    } else {
      multipart = await MultipartFile.fromFile(file.path, filename: fileName);
    }

    final formData = FormData.fromMap({'file': multipart, 'folder': folder});

    final res = await _dio.post('/files/upload', data: formData);
    final data = res.data;

    if (data is Map) {
      final map = data.cast<String, dynamic>();
      return FileUploadResponse.fromJson(map);
    }

    throw StateError('Unexpected POST /files/upload response: $data');
  }
}

String _filenameFromPath(String path) {
  final normalized = path.replaceAll('\\', '/');
  final parts = normalized.split('/');
  return parts.isNotEmpty ? parts.last : 'upload';
}

class FileUploadResponse {
  final String url;
  final String publicId;
  final String provider;

  FileUploadResponse({
    required this.url,
    required this.publicId,
    required this.provider,
  });

  factory FileUploadResponse.fromJson(Map<String, dynamic> json) {
    return FileUploadResponse(
      url: (json['url'] ?? '').toString(),
      publicId: (json['publicId'] ?? '').toString(),
      provider: (json['provider'] ?? '').toString(),
    );
  }
}

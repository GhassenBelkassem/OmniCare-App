import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';

import '../../features/auth/data/models/auth_dtos.dart';
import '../models/patient_profile.dart';
import '../network/api_exception.dart';
import '../network/app_http_client.dart';
import '../storage/secure_token_store.dart';

typedef UploadProgressCallback = void Function(int sentBytes, int totalBytes);

class FileUploadResponse {
  final String url;
  final String publicId;
  final String provider;

  FileUploadResponse({
    required this.url,
    required this.publicId,
    required this.provider,
  });
}

class FilesApi {
  FilesApi({AppHttpClient? httpClient, Object? dio})
    : _httpClient = httpClient ?? AppHttpClient(tokenStore: SecureTokenStore());

  static const _maxAvatarBytes = 8 * 1024 * 1024;

  final AppHttpClient _httpClient;

  Future<PatientProfile> uploadAvatar({
    required XFile file,
    UploadProgressCallback? onProgress,
  }) async {
    final length = await file.length();
    if (length <= 0) {
      throw const ApiException(
        'Select a non-empty image.',
        code: 'INVALID_INPUT',
      );
    }
    if (length > _maxAvatarBytes) {
      throw const ApiException(
        'Avatar image exceeds the 8 MB limit.',
        code: 'FILE_TOO_LARGE',
        statusCode: 413,
      );
    }

    final bytes = await file.readAsBytes();
    final contentType = _detectAvatarContentType(bytes);
    if (contentType == null) {
      throw const ApiException(
        'Avatar must be a JPEG or PNG image.',
        code: 'UNSUPPORTED_FILE_TYPE',
        statusCode: 415,
      );
    }

    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(
        bytes,
        filename: _safeFilename(file.name, contentType),
        contentType: MediaType.parse(contentType),
      ),
    });

    try {
      final response = await _httpClient.dio.patch<dynamic>(
        '/profile/avatar',
        data: form,
        options: Options(contentType: Headers.multipartFormDataContentType),
        onSendProgress: onProgress,
      );
      return _parseProfile(response.data);
    } on DioException catch (error) {
      throw _mapDioException(error);
    } on FormatException catch (error) {
      throw ApiException(
        'Malformed server response.',
        code: 'MALFORMED_RESPONSE',
        cause: error,
      );
    }
  }

  Future<PatientProfile> removeAvatar() async {
    try {
      final response = await _httpClient.dio.delete<dynamic>('/profile/avatar');
      return _parseProfile(response.data);
    } on DioException catch (error) {
      throw _mapDioException(error);
    } on FormatException catch (error) {
      throw ApiException(
        'Malformed server response.',
        code: 'MALFORMED_RESPONSE',
        cause: error,
      );
    }
  }

  Future<FileUploadResponse> uploadFile({
    required Object file,
    required String folder,
  }) async {
    return FileUploadResponse(
      url: 'https://mock.cloudinary.com/uploads/file.jpg',
      publicId: 'uploads/file',
      provider: 'mock',
    );
  }

  PatientProfile _parseProfile(Object? data) {
    if (data is Map) {
      return PatientProfile.fromJson(data.cast<String, dynamic>());
    }
    throw const FormatException('Expected JSON object.');
  }

  ApiException _mapDioException(DioException error) {
    final statusCode = error.response?.statusCode;
    final data = error.response?.data;
    if (data is Map) {
      try {
        final response = ApiErrorResponse.fromJson(
          data.cast<String, dynamic>(),
        );
        return ApiException(
          response.message,
          code: response.code,
          statusCode: statusCode,
          fieldErrors: response.fieldErrors,
          cause: error,
        );
      } catch (_) {
        return ApiException(
          'Unexpected server error response.',
          code: 'MALFORMED_ERROR_RESPONSE',
          statusCode: statusCode,
          cause: error,
        );
      }
    }
    return ApiException(
      'Network request failed.',
      code: 'NETWORK_REQUEST_FAILED',
      statusCode: statusCode,
      cause: error,
    );
  }
}

String? _detectAvatarContentType(Uint8List bytes) {
  if (bytes.length >= 3 &&
      bytes[0] == 0xFF &&
      bytes[1] == 0xD8 &&
      bytes[2] == 0xFF) {
    return 'image/jpeg';
  }
  if (bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47 &&
      bytes[4] == 0x0D &&
      bytes[5] == 0x0A &&
      bytes[6] == 0x1A &&
      bytes[7] == 0x0A) {
    return 'image/png';
  }
  return null;
}

String _safeFilename(String originalName, String contentType) {
  final extension = contentType == 'image/png' ? '.png' : '.jpg';
  final basename = originalName
      .replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_')
      .replaceAll(RegExp(r'\.(jpe?g|png)$', caseSensitive: false), '');
  final safeBasename = basename.isEmpty ? 'avatar' : basename;
  final truncated = safeBasename.length > 80
      ? safeBasename.substring(0, 80)
      : safeBasename;
  return '$truncated$extension';
}

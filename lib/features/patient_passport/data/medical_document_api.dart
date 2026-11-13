import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../core/network/app_http_client.dart';
import '../../../core/network/auth_interceptor.dart';
import '../../../core/network/network_timeout_policy.dart';
import '../../../core/network/request_replay_policy.dart';
import 'medical_document_models.dart';
import 'medical_record_models.dart';
import 'medical_record_write_models.dart';

/// HTTP access to `/api/v1/me/medical-record/documents` (G2-FT-2 §6,
/// G2.1-SB3 §4). Returns raw bodies; the repository maps them. Errors
/// propagate as Dio exceptions.
abstract interface class MedicalDocumentApiContract {
  Future<Object?> list(
    RecordSubject subject, {
    required int size,
    String? cursor,
    CancelToken? cancelToken,
  });

  Future<Object?> status(
    RecordSubject subject,
    String documentId, {
    CancelToken? cancelToken,
  });

  /// `multipart/form-data`: `file` (streamed), `title`, `documentType`,
  /// `documentDate?`; [contentType] is the file part's type.
  Future<Object?> upload(
    RecordSubject subject, {
    required DocumentFileSource source,
    required String contentType,
    required DocumentUploadForm form,
    required String idempotencyKey,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
  });

  Future<void> delete(
    RecordSubject subject,
    String documentId, {
    required String idempotencyKey,
    CancelToken? cancelToken,
  });

  Future<Object?> openViewSession(
    RecordSubject subject,
    String documentId, {
    CancelToken? cancelToken,
  });

  /// One PNG page. An error body arrives as text, so its code can be read.
  Future<Uint8List> page(
    RecordSubject subject,
    String documentId,
    String viewSessionId,
    int pageNumber, {
    CancelToken? cancelToken,
  });
}

class MedicalDocumentApi implements MedicalDocumentApiContract {
  const MedicalDocumentApi(this._httpClient);

  static const path = '/me/medical-record/documents';
  static const _noStore = {'Cache-Control': 'no-store'};

  final AppHttpClient _httpClient;

  Dio get _dio => _httpClient.dio;

  @override
  Future<Object?> list(
    RecordSubject subject, {
    required int size,
    String? cursor,
    CancelToken? cancelToken,
  }) async {
    final response = await _dio.get<Object?>(
      path,
      queryParameters: {
        'subject': subject.queryValue,
        'size': '$size',
        'cursor': ?cursor,
      },
      cancelToken: cancelToken,
      options: Options(headers: _noStore),
    );
    return response.data;
  }

  @override
  Future<Object?> status(
    RecordSubject subject,
    String documentId, {
    CancelToken? cancelToken,
  }) async {
    final response = await _dio.get<Object?>(
      '$path/${Uri.encodeComponent(documentId)}/status',
      queryParameters: {'subject': subject.queryValue},
      cancelToken: cancelToken,
      options: Options(headers: _noStore),
    );
    return response.data;
  }

  @override
  Future<Object?> upload(
    RecordSubject subject, {
    required DocumentFileSource source,
    required String contentType,
    required DocumentUploadForm form,
    required String idempotencyKey,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
  }) => _againOnAuthReplay(() async {
    // A multipart body is a stream: built afresh for every send.
    final data = FormData.fromMap({
      'title': form.title,
      'documentType': form.type.serverValue,
      if (form.documentDate != null)
        'documentDate': calendarDate(form.documentDate!),
      'file': await _filePart(source, contentType),
    });
    final response = await _dio.post<Object?>(
      path,
      queryParameters: {'subject': subject.queryValue},
      data: data,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      options: Options(
        headers: {'Idempotency-Key': idempotencyKey, ..._noStore},
        // Let Dio set the multipart boundary (the client default is JSON).
        contentType: Headers.multipartFormDataContentType,
        sendTimeout: NetworkTimeoutPolicy.medicalUpload.send,
        receiveTimeout: NetworkTimeoutPolicy.medicalUpload.receive,
        extra: requestReplayExtra(RequestReplayPolicy.never),
      ),
    );
    return response.data;
  });

  @override
  Future<void> delete(
    RecordSubject subject,
    String documentId, {
    required String idempotencyKey,
    CancelToken? cancelToken,
  }) async {
    await _dio.delete<Object?>(
      '$path/${Uri.encodeComponent(documentId)}',
      queryParameters: {'subject': subject.queryValue},
      cancelToken: cancelToken,
      options: Options(
        headers: {'Idempotency-Key': idempotencyKey, ..._noStore},
        extra: requestReplayExtra(RequestReplayPolicy.declaredIdempotentWrite),
      ),
    );
  }

  @override
  Future<Object?> openViewSession(
    RecordSubject subject,
    String documentId, {
    CancelToken? cancelToken,
  }) => _againOnAuthReplay(() async {
    final response = await _dio.post<Object?>(
      '$path/${Uri.encodeComponent(documentId)}/view-sessions',
      queryParameters: {'subject': subject.queryValue},
      cancelToken: cancelToken,
      options: Options(headers: _noStore),
    );
    return response.data;
  });

  @override
  Future<Uint8List> page(
    RecordSubject subject,
    String documentId,
    String viewSessionId,
    int pageNumber, {
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get<List<int>>(
        '$path/${Uri.encodeComponent(documentId)}/view-sessions/'
        '${Uri.encodeComponent(viewSessionId)}/pages/$pageNumber',
        queryParameters: {'subject': subject.queryValue},
        cancelToken: cancelToken,
        options: Options(
          responseType: ResponseType.bytes,
          headers: {'Accept': 'image/png', ..._noStore},
        ),
      );
      final bytes = response.data;
      if (bytes == null || bytes.isEmpty) {
        throw const FormatException('The page is empty');
      }
      return bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
    } on DioException catch (error) {
      throw _withTextBody(error);
    }
  }

  static Future<MultipartFile> _filePart(
    DocumentFileSource source,
    String contentType,
  ) async {
    final type = DioMediaType.parse(contentType);
    return switch (source) {
      PathDocumentSource(:final path, :final filename) =>
        await MultipartFile.fromFile(
          path,
          filename: filename,
          contentType: type,
        ),
      StreamDocumentSource(:final open, :final filename, :final sizeBytes) =>
        MultipartFile.fromStream(
          open,
          sizeBytes,
          filename: filename,
          contentType: type,
        ),
    };
  }

  /// A POST the session refresh cannot replay by itself (no key, or a
  /// stream body) is sent once more, rebuilt, after the refresh.
  static Future<T> _againOnAuthReplay<T>(Future<T> Function() send) async {
    try {
      return await send();
    } on DioException catch (error) {
      if (error.error is! AuthReplayRequiredException) rethrow;
      return send();
    }
  }

  /// An error answer to a bytes request: its body as text, so the code
  /// (`VIEW_SESSION_EXPIRED`, `DOCUMENT_NOT_READY`…) can be read.
  static DioException _withTextBody(DioException error) {
    final response = error.response;
    final data = response?.data;
    if (response == null || data is! List<int>) return error;
    return error.copyWith(
      response: Response<Object?>(
        requestOptions: response.requestOptions,
        statusCode: response.statusCode,
        headers: response.headers,
        data: utf8.decode(data, allowMalformed: true),
      ),
    );
  }
}

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../network/api_exception.dart';
import '../network/app_http_client.dart';
import '../network/sse_decoder.dart';
import '../storage/secure_token_store.dart';

class MedicalDocumentRecord {
  const MedicalDocumentRecord({
    required this.id,
    required this.patientId,
    required this.documentType,
    required this.status,
    this.fileMimeType,
    this.fileSizeBytes,
    this.pageCount,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String patientId;
  final String documentType;
  final String status;
  final String? fileMimeType;
  final int? fileSizeBytes;
  final int? pageCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isTerminal =>
      status == 'AVAILABLE' || status == 'SCAN_FAILED' || status == 'DELETED';

  MedicalDocumentRecord withStatus(String nextStatus, DateTime occurredAt) {
    return MedicalDocumentRecord(
      id: id,
      patientId: patientId,
      documentType: documentType,
      status: nextStatus,
      fileMimeType: fileMimeType,
      fileSizeBytes: fileSizeBytes,
      pageCount: pageCount,
      createdAt: createdAt,
      updatedAt: occurredAt.toLocal(),
    );
  }

  factory MedicalDocumentRecord.fromJson(Map<String, dynamic> json) {
    return MedicalDocumentRecord(
      id: _requiredString(json, 'id'),
      patientId: _requiredString(json, 'patientId'),
      documentType: _requiredString(json, 'documentType'),
      status: _requiredString(json, 'status'),
      fileMimeType: json['fileMimeType']?.toString(),
      fileSizeBytes: (json['fileSizeBytes'] as num?)?.toInt(),
      pageCount: (json['pageCount'] as num?)?.toInt(),
      createdAt: _optionalInstant(json['createdAt']),
      updatedAt: _optionalInstant(json['updatedAt']),
    );
  }
}

class MedicalDocumentPage {
  const MedicalDocumentPage({required this.documents, this.nextCursor});

  final List<MedicalDocumentRecord> documents;
  final String? nextCursor;

  factory MedicalDocumentPage.fromJson(Map<String, dynamic> json) {
    final items = json['documents'];

    if (items is! List) {
      throw const FormatException('Invalid documents.');
    }

    return MedicalDocumentPage(
      documents: items
          .map(
            (item) => MedicalDocumentRecord.fromJson(
              (item as Map).cast<String, dynamic>(),
            ),
          )
          .toList(growable: false),
      nextCursor: json['nextCursor']?.toString(),
    );
  }
}

class DocumentStatusEvent {
  static const _allowedStatuses = {
    'UPLOAD_INITIATED',
    'SCAN_PENDING',
    'AVAILABLE',
    'SCAN_FAILED',
    'DELETE_PENDING',
    'DELETED',
  };

  static final _eventIdPattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    caseSensitive: false,
  );

  const DocumentStatusEvent({
    required this.eventId,
    required this.documentId,
    required this.status,
    required this.occurredAt,
    required this.isSnapshot,
    this.reconnectDelay,
  });

  final String? eventId;
  final String documentId;
  final String status;
  final DateTime occurredAt;
  final bool isSnapshot;
  final Duration? reconnectDelay;

  bool get isTerminal =>
      status == 'AVAILABLE' || status == 'SCAN_FAILED' || status == 'DELETED';

  factory DocumentStatusEvent.fromSse(SseMessage message) {
    final isSnapshot = message.event == 'document-snapshot';
    final isStatusEvent = message.event == 'document-status';

    if (!isSnapshot && !isStatusEvent) {
      throw const FormatException('Invalid document event type.');
    }

    final decoded = jsonDecode(message.data);

    if (decoded is! Map) {
      throw const FormatException('Invalid document status event.');
    }

    final json = decoded.cast<String, dynamic>();
    final eventId = message.id?.trim().toLowerCase();

    // Persisted status events must have a replayable event ID.
    if (isStatusEvent &&
        (eventId == null || !_eventIdPattern.hasMatch(eventId))) {
      throw const FormatException('Invalid document event ID.');
    }

    // Bind the SSE frame ID to the ID inside the JSON payload.
    if (isStatusEvent) {
      final payloadEventId = json['event_id']?.toString().trim().toLowerCase();

      if (payloadEventId == null || payloadEventId != eventId) {
        throw const FormatException('Document event ID binding mismatch.');
      }
    }

    final occurredAt = DateTime.tryParse(json['occurred_at']?.toString() ?? '');

    if (occurredAt == null) {
      throw const FormatException('Invalid document status timestamp.');
    }

    final status = _requiredString(json, 'status');

    // SCAN_PENDING is valid for both snapshots and status events.
    if (!_allowedStatuses.contains(status)) {
      throw const FormatException('Invalid document status.');
    }

    return DocumentStatusEvent(
      eventId: eventId,
      documentId: _requiredString(json, 'document_id'),
      status: status,
      occurredAt: occurredAt.toUtc(),
      isSnapshot: isSnapshot,
      reconnectDelay: message.retry,
    );
  }
}

class DocumentUploadOperation {
  DocumentUploadOperation._({
    required this.idempotencyKey,
    required this.patientId,
    required this.bytes,
    required this.filename,
    required this.mimeType,
    required this.displayName,
    required this.documentType,
    required this.documentDate,
  });

  final String idempotencyKey;
  final String patientId;
  final Uint8List bytes;
  final String filename;
  final String mimeType;
  final String displayName;
  final String documentType;
  final DateTime documentDate;
}

class DocumentDeleteOperation {
  const DocumentDeleteOperation._({
    required this.idempotencyKey,
    required this.patientId,
    required this.documentId,
  });

  final String idempotencyKey;
  final String patientId;
  final String documentId;
}

class DocumentsApi {
  DocumentsApi({
    AppHttpClient? httpClient,
    Random? random,
    this.eventStreamSilenceTimeout = const Duration(seconds: 45),
  }) : assert(eventStreamSilenceTimeout > Duration.zero),
       _httpClient =
           httpClient ?? AppHttpClient(tokenStore: SecureTokenStore()),
       _random = random ?? Random.secure();

  final AppHttpClient _httpClient;
  final Random _random;

  /// Maximum time permitted without receiving any SSE bytes.
  ///
  /// The backend heartbeat interval must be shorter than this.
  final Duration eventStreamSilenceTimeout;

  Future<MedicalDocumentPage> listDocuments(String patientId) {
    return _request(
      () => _httpClient.dio.get<dynamic>(
        '/documents',
        queryParameters: {'patientId': patientId, 'limit': 50},
      ),
      MedicalDocumentPage.fromJson,
    );
  }

  DocumentUploadOperation startUpload({
    required String patientId,
    required Uint8List bytes,
    required String filename,
    required String mimeType,
    required String displayName,
    required String documentType,
    required DateTime documentDate,
  }) {
    return DocumentUploadOperation._(
      idempotencyKey: _newIdempotencyKey('upload'),
      patientId: patientId,
      bytes: bytes,
      filename: filename,
      mimeType: mimeType,
      displayName: displayName,
      documentType: documentType,
      documentDate: documentDate,
    );
  }

  Future<MedicalDocumentRecord> upload(DocumentUploadOperation operation) {
    final metadata = jsonEncode({
      'displayName': operation.displayName,
      'documentType': operation.documentType,
      'documentDate': _dateOnly(operation.documentDate),
    });

    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(
        operation.bytes,
        filename: operation.filename,
        contentType: DioMediaType.parse(operation.mimeType),
      ),
      'metadata': MultipartFile.fromString(
        metadata,
        contentType: DioMediaType.parse('application/json'),
      ),
    });

    return _request(
      () => _httpClient.dio.post<dynamic>(
        '/documents',
        queryParameters: {'patientId': operation.patientId},
        data: form,
        options: Options(
          headers: {'Idempotency-Key': operation.idempotencyKey},
          contentType: null,
        ),
      ),
      MedicalDocumentRecord.fromJson,
    );
  }

  Future<MedicalDocumentRecord> getStatus({
    required String patientId,
    required String documentId,
  }) {
    return _request(
      () => _httpClient.dio.get<dynamic>(
        '/documents/$documentId',
        queryParameters: {'patientId': patientId},
      ),
      MedicalDocumentRecord.fromJson,
    );
  }

  /// Opens an authenticated SSE connection for one document.
  ///
  /// Cancelling the returned subscription cancels the HTTP request.
  /// [lastEventId] permits replay after a connection interruption.
  Stream<DocumentStatusEvent> watchDocumentStatus({
    required String patientId,
    required String documentId,
    String? lastEventId,
  }) async* {
    final cancelToken = CancelToken();

    try {
      final response = await _httpClient.dio.get<ResponseBody>(
        '/documents/$documentId/events',
        queryParameters: {'patientId': patientId},
        cancelToken: cancelToken,
        options: Options(
          responseType: ResponseType.stream,
          receiveTimeout: eventStreamSilenceTimeout,
          sendTimeout: const Duration(seconds: 5),
          headers: {
            'Accept': 'text/event-stream',
            'Cache-Control': 'no-cache',
            if (lastEventId != null && lastEventId.isNotEmpty)
              'Last-Event-ID': lastEventId,
          },
        ),
      );

      final contentType = response.headers
          .value(Headers.contentTypeHeader)
          ?.split(';')
          .first
          .trim()
          .toLowerCase();

      if (contentType != 'text/event-stream') {
        throw const FormatException('Expected an SSE response.');
      }

      final body = response.data;

      if (body == null) {
        throw const FormatException('Missing event stream.');
      }

      await for (final message in body.stream.cast<List<int>>().transform(
        const SseDecoder(),
      )) {
        if (message.event != 'document-snapshot' &&
            message.event != 'document-status') {
          continue;
        }

        final event = DocumentStatusEvent.fromSse(message);

        if (event.documentId != documentId) {
          throw const FormatException('Document event binding mismatch.');
        }

        yield event;
      }
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) {
        return;
      }

      throw _safeApiException(error);
    } on FormatException catch (error) {
      throw ApiException(
        'The document event stream returned an unexpected response.',
        code: 'MALFORMED_RESPONSE',
        cause: error,
      );
    } on ApiException {
      rethrow;
    } catch (error) {
      throw ApiException(
        'The document event stream was interrupted.',
        code: 'SSE_CONNECTION_LOST',
        cause: error,
      );
    } finally {
      if (!cancelToken.isCancelled) {
        cancelToken.cancel('document event stream closed');
      }
    }
  }

  DocumentDeleteOperation startDelete({
    required String patientId,
    required String documentId,
  }) {
    return DocumentDeleteOperation._(
      idempotencyKey: _newIdempotencyKey('delete'),
      patientId: patientId,
      documentId: documentId,
    );
  }

  Future<String> delete(DocumentDeleteOperation operation) async {
    final response = await _request(
      () => _httpClient.dio.delete<dynamic>(
        '/documents/${operation.documentId}',
        queryParameters: {'patientId': operation.patientId},
        options: Options(
          headers: {'Idempotency-Key': operation.idempotencyKey},
        ),
      ),
      (json) => json,
    );

    return _requiredString(response, 'status');
  }

  Future<T> _request<T>(
    Future<Response<dynamic>> Function() send,
    T Function(Map<String, dynamic>) parse,
  ) async {
    try {
      final response = await send();

      if (response.data is! Map) {
        throw const FormatException('Expected object.');
      }

      return parse((response.data as Map).cast<String, dynamic>());
    } on DioException catch (error) {
      throw _safeApiException(error);
    } on FormatException catch (error) {
      throw ApiException(
        'The server returned an unexpected response.',
        code: 'MALFORMED_RESPONSE',
        cause: error,
      );
    }
  }

  String _newIdempotencyKey(String operation) {
    final suffix = List<int>.generate(
      16,
      (_) => _random.nextInt(256),
    ).map((value) => value.toRadixString(16).padLeft(2, '0')).join();

    return '$operation:$suffix';
  }

  @Deprecated('Legacy URL-based creation is not supported by Spring.')
  Future<Map<String, dynamic>> createDocument({
    required String title,
    required String type,
    String? issueDate,
    required String fileUrl,
    String? filePublicId,
    String? fileProvider,
  }) {
    return Future.error(
      UnsupportedError(
        'Use the authenticated multipart document upload workflow.',
      ),
    );
  }
}

ApiException _safeApiException(DioException error) {
  final status = error.response?.statusCode;
  final data = error.response?.data;

  final parsedRetryAfterSeconds = int.tryParse(
    error.response?.headers.value('retry-after')?.trim() ?? '',
  );

  final retryAfterSeconds =
      parsedRetryAfterSeconds != null && parsedRetryAfterSeconds >= 0
      ? parsedRetryAfterSeconds
      : null;

  final code = data is Map
      ? (data['code'] ?? data['errorCode'])?.toString()
      : null;

  final message = switch (code) {
    'UNAUTHORIZED' ||
    'AUTH_SESSION_EXPIRED' ||
    'AUTH_SESSION_INVALID' => 'Your session has expired. Please sign in again.',

    'FORBIDDEN' => 'You do not have permission to access these documents.',

    'UNSUPPORTED_FILE_TYPE' => 'Choose a PDF, PNG, JPG, or JPEG file.',

    'FILE_TOO_LARGE' => 'The file is larger than the 20 MB limit.',

    'IDEMPOTENCY_KEY_REUSED' || 'CONFLICT' =>
      'This operation conflicts with an earlier request. '
          'Please refresh and try again.',

    'MRS_UNAVAILABLE' || 'OBJECT_STORAGE_UNAVAILABLE' =>
      'Document processing is temporarily unavailable. '
          'Please try again later.',

    'INVALID_INPUT' || 'VALIDATION_ERROR' =>
      'The document could not be accepted. '
          'Check the file and try again.',

    _
        when error.type == DioExceptionType.connectionTimeout ||
            error.type == DioExceptionType.sendTimeout ||
            error.type == DioExceptionType.receiveTimeout =>
      'The request timed out. Please try again.',

    _ when error.type == DioExceptionType.connectionError =>
      'The document service is unavailable. '
          'Please try again later.',

    _ when status == 401 => 'Your session has expired. Please sign in again.',

    _ when status == 403 =>
      'You do not have permission to access these documents.',

    _ =>
      'The document operation could not be completed. '
          'Please try again.',
  };

  return ApiException(
    message,
    code: code,
    statusCode: status,
    retryAfter: retryAfterSeconds == null
        ? null
        : Duration(seconds: retryAfterSeconds),
    cause: error,
  );
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];

  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Invalid $key.');
  }

  return value.trim();
}

DateTime? _optionalInstant(Object? value) {
  return value is String ? DateTime.tryParse(value)?.toLocal() : null;
}

String _dateOnly(DateTime value) {
  return '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}

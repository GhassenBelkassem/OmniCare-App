import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicare_mobile/core/api/documents_api.dart';
import 'package:omnicare_mobile/core/network/api_exception.dart';
import 'package:omnicare_mobile/core/network/app_http_client.dart';
import 'package:omnicare_mobile/core/network/request_replay_policy.dart';
import 'package:omnicare_mobile/core/network/sse_decoder.dart';
import 'package:omnicare_mobile/core/storage/secure_token_store.dart';
import 'package:omnicare_mobile/features/profile/medical_document_error_message.dart';
import 'package:omnicare_mobile/l10n/omni_localizations.dart';

class _MemorySecureStorage implements SecureTokenStorageBackend {
  final Map<String, String> values = {};

  @override
  Future<void> delete({required String key}) async => values.remove(key);

  @override
  Future<String?> read({required String key}) async => values[key];

  @override
  Future<void> write({required String key, required String value}) async {
    values[key] = value;
  }
}

typedef _Responder =
    FutureOr<ResponseBody> Function(RequestOptions options, int count);

class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this.routes);

  final Map<String, _Responder> routes;
  final Map<String, int> counts = {};
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final key = '${options.method} ${options.uri.path}';
    final count = (counts[key] ?? 0) + 1;
    counts[key] = count;
    requests.add(options);
    return routes[key]!(options, count);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Map<String, dynamic> value, int status) {
  return ResponseBody.fromString(
    jsonEncode(value),
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

Map<String, dynamic> _refreshResponse() {
  final now = DateTime.now().toUtc();
  return {
    'accessToken': 'rotated-access-token',
    'refreshToken': 'rotated-refresh-token',
    'expiresAt': now.add(const Duration(hours: 1)).toIso8601String(),
    'refreshExpiresAt': now.add(const Duration(days: 7)).toIso8601String(),
    'user': {'id': 'user-1', 'role': 'PATIENT'},
  };
}

Map<String, dynamic> _documentResponse() => {
  'id': 'document-1',
  'patientId': 'patient-1',
  'documentType': 'OTHER_MEDICAL_DOCUMENT',
  'status': 'SCAN_PENDING',
};

Map<String, dynamic> _recoveryResponse(String state) => {
  'state': state,
  if (state != 'FAILED') 'document': _documentResponse(),
  if (state == 'FAILED') 'failureCode': 'DOCUMENT_SCAN_FAILED',
};

Future<(DocumentsApi, _RecordingAdapter, SecureTokenStore)> _networkApi(
  Map<String, _Responder> routes,
) async {
  final store = SecureTokenStore(backend: _MemorySecureStorage());
  final now = DateTime.now().toUtc();
  await store.saveSession(
    StoredSession(
      accessToken: 'expired-access-token',
      refreshToken: 'refresh-token',
      accessTokenExpiresAt: now.add(const Duration(hours: 1)),
      refreshTokenExpiresAt: now.add(const Duration(days: 7)),
      userId: 'user-1',
      userRole: 'PATIENT',
      sessionId: 'session-1',
    ),
  );
  final adapter = _RecordingAdapter(routes);
  final client = AppHttpClient(
    tokenStore: store,
    baseUrl: 'https://api.test',
    dio: Dio(),
    refreshDio: Dio(),
  );
  client.dio.httpClientAdapter = adapter;
  client.publicDio.httpClientAdapter = adapter;
  return (DocumentsApi(httpClient: client), adapter, store);
}

void main() {
  group('document upload operation', () {
    test('accepts the backend 20 MB boundary without reading a path', () {
      final operation = DocumentsApi().startUpload(
        patientId: 'patient-1',
        fileSizeBytes: DocumentsApi.maximumUploadBytes,
        filePath: '/tmp/medical-document.pdf',
        filename: 'medical-document.pdf',
        mimeType: 'application/pdf',
        displayName: 'Medical document',
        documentType: 'OTHER_MEDICAL_DOCUMENT',
        documentDate: DateTime.utc(2026, 11, 9),
      );

      expect(operation.fileSizeBytes, DocumentsApi.maximumUploadBytes);
      expect(operation.filePath, '/tmp/medical-document.pdf');
      expect(operation.bytes, isNull);
    });

    test('rejects oversized, empty, and ambiguous file sources', () {
      ApiException apiError(void Function() action) {
        try {
          action();
          fail('Expected ApiException.');
        } on ApiException catch (error) {
          return error;
        }
      }

      DocumentUploadOperation start({
        required int size,
        String? path,
        Uint8List? bytes,
      }) {
        return DocumentsApi().startUpload(
          patientId: 'patient-1',
          fileSizeBytes: size,
          filePath: path,
          bytes: bytes,
          filename: 'medical-document.pdf',
          mimeType: 'application/pdf',
          displayName: 'Medical document',
          documentType: 'OTHER_MEDICAL_DOCUMENT',
          documentDate: DateTime.utc(2026, 11, 9),
        );
      }

      expect(
        apiError(
          () => start(
            size: DocumentsApi.maximumUploadBytes + 1,
            path: '/tmp/too-large.pdf',
          ),
        ).code,
        'FILE_TOO_LARGE',
      );
      expect(
        apiError(() => start(size: 0, path: '/tmp/empty.pdf')).code,
        'EMPTY_FILE',
      );
      expect(
        apiError(
          () => start(
            size: 1,
            path: '/tmp/ambiguous.pdf',
            bytes: Uint8List.fromList([1]),
          ),
        ).code,
        'FILE_SOURCE_INVALID',
      );
      expect(
        apiError(() => start(size: 2, bytes: Uint8List.fromList([1]))).code,
        'FILE_SIZE_MISMATCH',
      );
    });

    test(
      'refresh rebuilds multipart once with the same operation key',
      () async {
        late final _RecordingAdapter adapter;
        final network = await _networkApi({
          'POST /api/v1/documents': (options, count) => count == 1
              ? _json({
                  'code': 'AUTH_SESSION_INVALID',
                  'message': 'expired access token',
                }, 401)
              : _json(_documentResponse(), 201),
          'POST /api/v1/auth/refresh': (_, _) => _json(_refreshResponse(), 200),
        });
        final api = network.$1;
        adapter = network.$2;
        final operation = api.startUpload(
          patientId: 'patient-1',
          fileSizeBytes: 3,
          bytes: Uint8List.fromList([1, 2, 3]),
          filename: 'medical-document.pdf',
          mimeType: 'application/pdf',
          displayName: 'Medical document',
          documentType: 'OTHER_MEDICAL_DOCUMENT',
          documentDate: DateTime.utc(2026, 11, 9),
        );

        final result = await api.upload(operation);
        final uploadRequests = adapter.requests
            .where((request) => request.uri.path == '/api/v1/documents')
            .toList();

        expect(result.id, 'document-1');
        expect(uploadRequests, hasLength(2));
        expect(uploadRequests[0].data, isA<FormData>());
        expect(uploadRequests[1].data, isA<FormData>());
        expect(
          identical(uploadRequests[0].data, uploadRequests[1].data),
          isFalse,
        );
        expect(
          uploadRequests.map((request) => request.headers['Idempotency-Key']),
          everyElement(operation.idempotencyKey),
        );
        expect(
          uploadRequests.map(
            (request) => request.extra[requestReplayPolicyExtraKey],
          ),
          everyElement(RequestReplayPolicy.never.name),
        );
        expect(
          uploadRequests.map((request) => request.sendTimeout),
          everyElement(DocumentsApi.uploadSendTimeout),
        );
        expect(adapter.counts['POST /api/v1/auth/refresh'], 1);
      },
    );

    test(
      'local cancellation reports an unknown server outcome boundary',
      () async {
        final network = await _networkApi({
          'POST /api/v1/documents': (_, _) => _json(_documentResponse(), 201),
        });
        final api = network.$1;
        final operation = api.startUpload(
          patientId: 'patient-1',
          fileSizeBytes: 1,
          bytes: Uint8List.fromList([1]),
          filename: 'medical-document.pdf',
          mimeType: 'application/pdf',
          displayName: 'Medical document',
          documentType: 'OTHER_MEDICAL_DOCUMENT',
          documentDate: DateTime.utc(2026, 11, 9),
        );
        final cancelToken = CancelToken()
          ..cancel('user stopped local transfer');

        await expectLater(
          api.upload(operation, cancelToken: cancelToken),
          throwsA(
            isA<ApiException>()
                .having((error) => error.code, 'code', 'UPLOAD_CANCELLED_LOCAL')
                // G2-1b-2c: French text from the code, never the message.
                .having(
                  (error) => documentErrorMessage(
                    error,
                    lookupOmniLocalizations(const Locale('fr')),
                  ),
                  'text',
                  contains('le résultat est incertain'),
                ),
          ),
        );
        expect(network.$2.counts['POST /api/v1/documents'], isNull);
      },
    );

    test('web bytes are bounded at the same 20 MiB API boundary', () {
      final api = DocumentsApi();
      final oneByte = Uint8List.fromList([1]);

      expect(
        api
            .startUpload(
              patientId: 'patient-1',
              fileSizeBytes: 1,
              bytes: oneByte,
              filename: 'document.pdf',
              mimeType: 'application/pdf',
              displayName: 'Document',
              documentType: 'OTHER_MEDICAL_DOCUMENT',
              documentDate: DateTime.utc(2026, 11, 9),
            )
            .bytes,
        same(oneByte),
      );
      expect(
        () => api.startUpload(
          patientId: 'patient-1',
          fileSizeBytes: DocumentsApi.maximumUploadBytes + 1,
          bytes: oneByte,
          filename: 'document.pdf',
          mimeType: 'application/pdf',
          displayName: 'Document',
          documentType: 'OTHER_MEDICAL_DOCUMENT',
          documentDate: DateTime.utc(2026, 11, 9),
        ),
        throwsA(
          isA<ApiException>().having(
            (error) => error.code,
            'code',
            'FILE_TOO_LARGE',
          ),
        ),
      );
    });

    test(
      'upload timeout, 5xx, and malformed success remain failures',
      () async {
        final cases = <String, _Responder>{
          'timeout': (options, _) => throw DioException(
            requestOptions: options,
            type: DioExceptionType.sendTimeout,
          ),
          '5xx': (_, _) => _json({'code': 'DOCUMENT_SERVICE_UNAVAILABLE'}, 503),
          'malformed': (_, _) => _json({'unexpected': true}, 201),
        };

        for (final entry in cases.entries) {
          final network = await _networkApi({
            'POST /api/v1/documents': entry.value,
          });
          final operation = network.$1.startUpload(
            patientId: 'patient-1',
            fileSizeBytes: 1,
            bytes: Uint8List.fromList([1]),
            filename: 'document.pdf',
            mimeType: 'application/pdf',
            displayName: 'Document',
            documentType: 'OTHER_MEDICAL_DOCUMENT',
            documentDate: DateTime.utc(2026, 11, 9),
          );

          await expectLater(
            network.$1.upload(operation),
            throwsA(isA<ApiException>()),
            reason: entry.key,
          );
          expect(network.$2.counts['POST /api/v1/documents'], 1);
        }
      },
    );

    test(
      'temporary refresh failure preserves session and does not rebuild',
      () async {
        final network = await _networkApi({
          'POST /api/v1/documents': (_, _) => _json({
            'code': 'AUTH_SESSION_INVALID',
            'message': 'expired access token',
          }, 401),
          'POST /api/v1/auth/refresh': (_, _) =>
              _json({'code': 'TEMPORARY'}, 503),
        });
        final operation = network.$1.startUpload(
          patientId: 'patient-1',
          fileSizeBytes: 1,
          bytes: Uint8List.fromList([1]),
          filename: 'document.pdf',
          mimeType: 'application/pdf',
          displayName: 'Document',
          documentType: 'OTHER_MEDICAL_DOCUMENT',
          documentDate: DateTime.utc(2026, 11, 9),
        );

        await expectLater(
          network.$1.upload(operation),
          throwsA(
            isA<ApiException>().having(
              (error) => error.code,
              'code',
              'AUTH_REFRESH_TEMPORARILY_UNAVAILABLE',
            ),
          ),
        );
        expect(network.$2.counts['POST /api/v1/documents'], 1);
        expect(await network.$3.readSession(), isNotNull);
      },
    );

    test(
      'terminal refresh rejection clears session and does not rebuild',
      () async {
        final network = await _networkApi({
          'POST /api/v1/documents': (_, _) => _json({
            'code': 'AUTH_SESSION_INVALID',
            'message': 'expired access token',
          }, 401),
          'POST /api/v1/auth/refresh': (_, _) => _json({
            'code': 'AUTH_REFRESH_TOKEN_INVALID',
            'message': 'terminal',
          }, 401),
        });
        final operation = network.$1.startUpload(
          patientId: 'patient-1',
          fileSizeBytes: 1,
          bytes: Uint8List.fromList([1]),
          filename: 'document.pdf',
          mimeType: 'application/pdf',
          displayName: 'Document',
          documentType: 'OTHER_MEDICAL_DOCUMENT',
          documentDate: DateTime.utc(2026, 11, 9),
        );

        await expectLater(
          network.$1.upload(operation),
          throwsA(isA<ApiException>()),
        );
        expect(network.$2.counts['POST /api/v1/documents'], 1);
        expect(await network.$3.readSession(), isNull);
      },
    );
  });

  group('document upload recovery', () {
    test('uses the original key and parses authoritative success', () async {
      final network = await _networkApi({
        'GET /api/v1/documents/uploads/recovery': (_, _) =>
            _json(_recoveryResponse('SUCCEEDED'), 200),
      });

      final result = await network.$1.recoverUpload(
        patientId: 'patient-1',
        idempotencyKey: 'upload:stable-key',
      );
      final request = network.$2.requests.single;

      expect(result.state, DocumentUploadRecoveryState.succeeded);
      expect(result.document!.id, 'document-1');
      expect(request.uri.queryParameters['patientId'], 'patient-1');
      expect(request.headers['Idempotency-Key'], 'upload:stable-key');
    });

    test('parses in-progress and terminal failed projections', () async {
      for (final state in ['IN_PROGRESS', 'FAILED']) {
        final network = await _networkApi({
          'GET /api/v1/documents/uploads/recovery': (_, _) =>
              _json(_recoveryResponse(state), 200),
        });
        final result = await network.$1.recoverUpload(
          patientId: 'patient-1',
          idempotencyKey: 'upload:stable-key',
        );
        expect(
          result.state,
          state == 'IN_PROGRESS'
              ? DocumentUploadRecoveryState.inProgress
              : DocumentUploadRecoveryState.failed,
        );
        if (state == 'FAILED') {
          expect(result.failureCode, 'DOCUMENT_SCAN_FAILED');
        }
      }
    });

    test(
      'maps non-enumerating not found and rejects malformed success',
      () async {
        final missing = await _networkApi({
          'GET /api/v1/documents/uploads/recovery': (_, _) =>
              _json({'code': 'DOCUMENT_UPLOAD_RECOVERY_NOT_FOUND'}, 404),
        });
        await expectLater(
          missing.$1.recoverUpload(
            patientId: 'patient-1',
            idempotencyKey: 'upload:stable-key',
          ),
          throwsA(
            isA<ApiException>().having(
              (error) => error.code,
              'code',
              'DOCUMENT_UPLOAD_RECOVERY_NOT_FOUND',
            ),
          ),
        );

        final malformed = await _networkApi({
          'GET /api/v1/documents/uploads/recovery': (_, _) =>
              _json({'state': 'SUCCEEDED'}, 200),
        });
        await expectLater(
          malformed.$1.recoverUpload(
            patientId: 'patient-1',
            idempotencyKey: 'upload:stable-key',
          ),
          throwsA(
            isA<ApiException>().having(
              (error) => error.code,
              'code',
              'MALFORMED_RESPONSE',
            ),
          ),
        );
      },
    );
  });

  test('parses a minimal terminal document event with an opaque UUID id', () {
    const message = SseMessage(
      id: '11111111-1111-4111-8111-111111111111',
      event: 'document-status',
      data:
          '{'
          '"event_id":"11111111-1111-4111-8111-111111111111",'
          '"document_id":"22222222-2222-4222-8222-222222222222",'
          '"status":"AVAILABLE",'
          '"occurred_at":"2026-08-29T12:00:00Z"'
          '}',
    );

    final event = DocumentStatusEvent.fromSse(message);
    expect(event.eventId, message.id);
    expect(event.documentId, '22222222-2222-4222-8222-222222222222');
    expect(event.status, 'AVAILABLE');
    expect(event.isTerminal, isTrue);
  });

  test('rejects a numeric database sequence as a public event id', () {
    const message = SseMessage(
      id: '42',
      event: 'document-status',
      data:
          '{'
          '"document_id":"22222222-2222-4222-8222-222222222222",'
          '"status":"AVAILABLE",'
          '"occurred_at":"2026-08-29T12:00:00Z"'
          '}',
    );

    expect(() => DocumentStatusEvent.fromSse(message), throwsFormatException);
  });
}

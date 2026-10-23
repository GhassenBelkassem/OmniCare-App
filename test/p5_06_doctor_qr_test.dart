import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicare_mobile/core/network/api_exception.dart';
import 'package:omnicare_mobile/core/network/app_http_client.dart';
import 'package:omnicare_mobile/core/storage/secure_token_store.dart';
import 'package:omnicare_mobile/features/doctor/medical_access/doctor_medical_access.dart';
import 'package:omnicare_mobile/features/doctor/medical_access/doctor_medical_access_api.dart';
import 'package:omnicare_mobile/features/doctor/medical_access/doctor_medical_access_controller.dart';
import 'package:omnicare_mobile/features/doctor/qr_scanner_screen.dart';

void main() {
  const consultationId = '11111111-1111-4111-8111-111111111111';

  test(
    'consume sends canonical consultation, opaque payload and no Doctor id',
    () async {
      final adapter = _RecordingAdapter(_activationJson(consultationId));
      final api = DoctorMedicalAccessApi(await _client(adapter));

      await api.consumeQr(
        consultationId: consultationId,
        qrPayload: 'opaque-medical-share-token',
        idempotencyKey: 'scan-command-1',
      );

      final request = adapter.request!;
      expect(
        request.uri.path,
        '/api/v1/doctor/consultations/$consultationId/medical-access/qr/consume',
      );
      expect(adapter.body, {'qrPayload': 'opaque-medical-share-token'});
      expect(adapter.body, isNot(contains('doctorId')));
      expect(adapter.body, isNot(contains('patientId')));
      expect(adapter.body, isNot(contains('mrsPatientId')));
      expect(_hasHeader(request, 'Pragma'), isFalse);
      expect(_header(request, 'Authorization'), 'Bearer test-access-token');
      expect(_header(request, 'Content-Type'), Headers.jsonContentType);
      expect(_header(request, 'Cache-Control'), 'no-store');
      expect(_header(request, 'Idempotency-Key'), 'scan-command-1');
    },
  );

  test('duplicate camera frames trigger one in-flight command', () async {
    final api = _FakeAccessApi()..pending = Completer();
    final controller = DoctorMedicalAccessController(
      api: api,
      consultationId: consultationId,
      idempotencyKey: () => 'stable-command',
    );

    final first = controller.consume('opaque-token');
    final duplicate = await controller.consume('opaque-token');
    expect(duplicate, isFalse);
    expect(api.calls, 1);

    api.pending!.complete(_activation(consultationId));
    expect(await first, isTrue);
    expect(controller.status, DoctorMedicalAccessStatus.active);
  });

  test('lost-response retry reuses the same Idempotency-Key', () async {
    final api = _FakeAccessApi()
      ..failure = const ApiException('offline', code: 'MRS_UNAVAILABLE');
    var sequence = 0;
    final controller = DoctorMedicalAccessController(
      api: api,
      consultationId: consultationId,
      idempotencyKey: () => 'scan-${++sequence}',
    );

    expect(await controller.consume('opaque-token'), isFalse);
    api.failure = null;
    expect(await controller.retry(), isTrue);

    expect(api.keys, ['scan-1', 'scan-1']);
    expect(api.payloads, ['opaque-token', 'opaque-token']);
  });

  test('success alone changes local medical access to ACTIVE', () async {
    final api = _FakeAccessApi();
    final controller = DoctorMedicalAccessController(
      api: api,
      consultationId: consultationId,
    );

    expect(controller.status, DoctorMedicalAccessStatus.ready);
    expect(await controller.consume('opaque-token'), isTrue);
    expect(controller.status, DoctorMedicalAccessStatus.active);
    expect(controller.activation?.consultationId, consultationId);
  });

  for (final entry in {
    'MEDICAL_QR_EXPIRED': 'Code expiré',
    'MEDICAL_QR_ALREADY_USED': 'déjà été utilisé',
    'MRS_UNAVAILABLE': 'temporairement indisponible',
    'MRS_CONTEXT_PENDING': 'en préparation',
    'PROFESSIONAL_NOT_ELIGIBLE': 'professionnel',
    'UNAUTHORIZED': 'session a expiré',
    'MEDICAL_QR_INVALID': 'Code invalide',
  }.entries) {
    test('${entry.key} remains non-ACTIVE with safe copy', () async {
      final api = _FakeAccessApi()
        ..failure = ApiException('internal detail', code: entry.key);
      final controller = DoctorMedicalAccessController(
        api: api,
        consultationId: consultationId,
      );

      expect(await controller.consume('random-or-legacy-value'), isFalse);
      expect(controller.status, DoctorMedicalAccessStatus.error);
      expect(controller.activation, isNull);
      expect(controller.errorMessage, contains(entry.value));
      expect(controller.errorMessage, isNot(contains('internal detail')));
    });
  }

  testWidgets(
    'scanner uses opaque debug boundary and shows ACTIVE only on success',
    (tester) async {
      final api = _FakeAccessApi();
      final controller = DoctorMedicalAccessController(
        api: api,
        consultationId: consultationId,
        idempotencyKey: () => 'widget-command',
      );
      await tester.binding.setSurfaceSize(const Size(430, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: QRScannerScreen(
            consultationId: consultationId,
            controller: controller,
            cameraEnabled: false,
          ),
        ),
      );
      await tester.enterText(
        find.byKey(const ValueKey('medical-access-debug-token-input')),
        'opaque-widget-token',
      );
      await tester.tap(
        find.byKey(const ValueKey('medical-access-debug-submit')),
      );
      await tester.pump();
      await tester.pump();

      expect(api.consultationIds.single, consultationId);
      expect(api.payloads.single, 'opaque-widget-token');
      expect(
        find.byKey(const ValueKey('medical-access-active')),
        findsOneWidget,
      );
      expect(find.textContaining('dossier médical'), findsNothing);
    },
  );

  testWidgets('failed random QR never navigates or creates local access', (
    tester,
  ) async {
    final api = _FakeAccessApi()
      ..failure = const ApiException('invalid', code: 'MEDICAL_QR_INVALID');
    final controller = DoctorMedicalAccessController(
      api: api,
      consultationId: consultationId,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: QRScannerScreen(
          consultationId: consultationId,
          controller: controller,
          cameraEnabled: false,
        ),
      ),
    );
    await tester.enterText(
      find.byKey(const ValueKey('medical-access-debug-token-input')),
      'OMNICARE-PATIENT-legacy-id',
    );
    await tester.tap(find.byKey(const ValueKey('medical-access-debug-submit')));
    await tester.pump();
    await tester.pump();

    expect(controller.status, DoctorMedicalAccessStatus.error);
    expect(controller.activation, isNull);
    expect(find.byKey(const ValueKey('medical-access-error')), findsOneWidget);
    expect(find.byKey(const ValueKey('medical-access-active')), findsNothing);
  });
}

Map<String, dynamic> _activationJson(String id) => {
  'consultationId': id,
  'medicalAccessStatus': 'ACTIVE',
  'activatedAt': DateTime.now().toUtc().toIso8601String(),
  'expiresAt': DateTime.now()
      .toUtc()
      .add(const Duration(hours: 8))
      .toIso8601String(),
};

DoctorMedicalAccessActivation _activation(String id) =>
    DoctorMedicalAccessActivation(
      consultationId: id,
      activatedAt: DateTime.now().toUtc(),
      expiresAt: DateTime.now().toUtc().add(const Duration(hours: 8)),
    );

class _FakeAccessApi implements DoctorMedicalAccessApiContract {
  final consultationIds = <String>[];
  final payloads = <String>[];
  final keys = <String>[];
  int calls = 0;
  Object? failure;
  Completer<DoctorMedicalAccessActivation>? pending;

  @override
  Future<DoctorMedicalAccessActivation> consumeQr({
    required String consultationId,
    required String qrPayload,
    required String idempotencyKey,
  }) async {
    calls++;
    consultationIds.add(consultationId);
    payloads.add(qrPayload);
    keys.add(idempotencyKey);
    final currentFailure = failure;
    if (currentFailure != null) throw currentFailure;
    final currentPending = pending;
    if (currentPending != null) return currentPending.future;
    return _activation(consultationId);
  }
}

class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this.response);

  final Map<String, dynamic> response;
  RequestOptions? request;
  Object? body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    body = options.data;
    return ResponseBody.fromString(
      jsonEncode(response),
      201,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Future<AppHttpClient> _client(HttpClientAdapter adapter) async {
  final dio = Dio()..httpClientAdapter = adapter;
  final tokenStore = SecureTokenStore(backend: _MemoryTokenBackend());
  await tokenStore.saveSession(_testSession());
  return AppHttpClient(
    tokenStore: tokenStore,
    baseUrl: 'https://api.test',
    dio: dio,
    refreshDio: Dio(),
  );
}

StoredSession _testSession() => StoredSession(
  accessToken: 'test-access-token',
  refreshToken: 'test-refresh-token',
  accessTokenExpiresAt: DateTime.utc(2099),
  refreshTokenExpiresAt: DateTime.utc(2099, 2),
  userId: 'test-doctor',
  userRole: 'DOCTOR',
);

Object? _header(RequestOptions request, String name) {
  final normalized = name.toLowerCase();
  for (final entry in request.headers.entries) {
    if (entry.key.toLowerCase() == normalized) return entry.value;
  }
  return null;
}

bool _hasHeader(RequestOptions request, String name) {
  final normalized = name.toLowerCase();
  return request.headers.keys.any((key) => key.toLowerCase() == normalized);
}

class _MemoryTokenBackend implements SecureTokenStorageBackend {
  final values = <String, String>{};

  @override
  Future<void> delete({required String key}) async => values.remove(key);

  @override
  Future<String?> read({required String key}) async => values[key];

  @override
  Future<void> write({required String key, required String value}) async {
    values[key] = value;
  }
}

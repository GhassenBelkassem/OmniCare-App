import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicare_mobile/core/network/app_http_client.dart';
import 'package:omnicare_mobile/core/storage/secure_token_store.dart';
import 'package:omnicare_mobile/features/doctor/active_consultation/doctor_active_consultation.dart';
import 'package:omnicare_mobile/features/doctor/active_consultation/doctor_active_consultation_api.dart';
import 'package:omnicare_mobile/features/doctor/active_consultation/doctor_active_consultation_controller.dart';
import 'package:omnicare_mobile/features/scheduled_care/data/patient_scheduled_consultation_api.dart';

void main() {
  test('Flutter emits the canonical scheduled Start contract', () async {
    final adapter = _CaptureAdapter(_consultationJson());
    final api = DoctorActiveConsultationApi(_client(adapter));

    final result = await api.startScheduled(
      appointmentId: 'appointment-9',
      expectedAppointmentVersion: 7,
      idempotencyKey: 'stable-start-key',
    );

    expect(result.sourceId, 'appointment-9');
    expect(adapter.request.path, '/doctor/consultations/start');
    expect(adapter.request.method, 'POST');
    expect(adapter.request.headers['Idempotency-Key'], 'stable-start-key');
    expect(adapter.request.data, <String, Object>{
      'sourceType': 'SCHEDULED_APPOINTMENT',
      'sourceId': 'appointment-9',
      'expectedSourceVersion': 7,
    });
  });

  test('Flutter emits and recovers the exact Urgent CABINET source', () async {
    final adapter = _CaptureAdapter(
      _consultationJson(
        sourceType: 'URGENT_CABINET',
        sourceId: '11111111-1111-4111-8111-111111111111',
      ),
    );
    final api = DoctorActiveConsultationApi(_client(adapter));
    final controller = DoctorActiveConsultationController(api: api);
    addTearDown(controller.dispose);
    await controller.attachDoctor('doctor-1');

    final result = await controller.startUrgentCabinet(
      '11111111-1111-4111-8111-111111111111',
      9,
      idempotencyKeyFactory: () => 'urgent-operation',
    );

    expect(result, DoctorConsultationStartOutcome.started);
    expect(
      controller.active?.sourceType,
      DoctorConsultationSourceType.urgentCabinet,
    );
    expect(adapter.request.data, <String, Object>{
      'sourceType': 'URGENT_CABINET',
      'sourceId': '11111111-1111-4111-8111-111111111111',
      'expectedSourceVersion': 9,
    });
    expect(
      adapter.request.headers['Idempotency-Key'],
      'doctor-start-consultation-urgent-operation',
    );
  });

  test(
    'repeated tap creates one Start and matching authority recovers',
    () async {
      final pending = Completer<DoctorActiveConsultation>();
      final api = _FakeApi(
        active: <DoctorActiveConsultation?>[null],
        onStart: (_, _, _) => pending.future,
      );
      final controller = DoctorActiveConsultationController(api: api);
      addTearDown(controller.dispose);
      await controller.attachDoctor('doctor-1');

      final first = controller.startScheduled(
        'appointment-9',
        7,
        idempotencyKeyFactory: () => 'operation-1',
      );
      final second = controller.startScheduled(
        'appointment-9',
        7,
        idempotencyKeyFactory: () => 'operation-2',
      );
      expect(api.starts, hasLength(1));
      pending.complete(_consultation());

      expect(await first, DoctorConsultationStartOutcome.started);
      expect(await second, DoctorConsultationStartOutcome.started);
      expect(controller.active?.consultationId, 'consultation-1');
    },
  );

  test('ambiguous empty recovery retains the same operation key', () async {
    final api = _FakeApi(
      active: <DoctorActiveConsultation?>[null, null, null],
      onStart: (_, _, _) => throw DioException(
        requestOptions: RequestOptions(path: '/doctor/consultations/start'),
        type: DioExceptionType.connectionError,
      ),
    );
    final controller = DoctorActiveConsultationController(api: api);
    addTearDown(controller.dispose);
    await controller.attachDoctor('doctor-1');

    await controller.startScheduled(
      'appointment-9',
      7,
      idempotencyKeyFactory: () => 'stable',
    );
    await controller.startScheduled(
      'appointment-9',
      7,
      idempotencyKeyFactory: () => 'changed',
    );

    expect(api.starts.map((value) => value.$3), <String>[
      'doctor-start-consultation-stable',
      'doctor-start-consultation-stable',
    ]);
  });

  test(
    'a nonmatching active Consultation is a conflict, not recovery',
    () async {
      final api = _FakeApi(
        active: <DoctorActiveConsultation?>[
          null,
          _consultation(sourceId: 'appointment-other'),
        ],
        onStart: (_, _, _) => throw DioException(
          requestOptions: RequestOptions(path: '/doctor/consultations/start'),
          response: Response<dynamic>(
            requestOptions: RequestOptions(path: '/doctor/consultations/start'),
            statusCode: 409,
            data: const <String, Object>{
              'errorCode': 'CONSULTATION_ALREADY_EXISTS',
            },
          ),
        ),
      );
      final controller = DoctorActiveConsultationController(api: api);
      addTearDown(controller.dispose);
      await controller.attachDoctor('doctor-1');

      expect(
        await controller.startScheduled('appointment-9', 7),
        DoctorConsultationStartOutcome.activeConflict,
      );
      expect(controller.active?.sourceId, 'appointment-other');
      expect(
        controller.startErrorMessage,
        'Une consultation est déjà en cours.',
      );
    },
  );

  test(
    'completed Appointment resolves its canonical Consultation identity',
    () async {
      final adapter = _CaptureAdapter(<String, Object>{
        'consultationId': 'consultation-1',
        'sourceType': 'SCHEDULED_APPOINTMENT',
        'sourceId': 'appointment-9',
        'status': 'COMPLETED',
      });
      final api = PatientScheduledConsultationApi(_client(adapter));

      expect(
        await api.resolveCompletedConsultation('appointment-9'),
        'consultation-1',
      );
      expect(
        adapter.request.path,
        '/patient/appointments/appointment-9/consultation',
      );
      expect(adapter.request.method, 'GET');
    },
  );
}

DoctorActiveConsultation _consultation({String sourceId = 'appointment-9'}) =>
    DoctorActiveConsultation(
      consultationId: 'consultation-1',
      sourceType: DoctorConsultationSourceType.scheduledAppointment,
      sourceId: sourceId,
      status: DoctorConsultationStatus.inProgress,
      medicalAccessStatus: DoctorConsultationMedicalAccessStatus.none,
      version: 0,
      startedAt: DateTime.utc(2026, 10, 27, 10),
    );

Map<String, Object> _consultationJson({
  String sourceType = 'SCHEDULED_APPOINTMENT',
  String sourceId = 'appointment-9',
}) => <String, Object>{
  'consultationId': 'consultation-1',
  'sourceType': sourceType,
  'sourceId': sourceId,
  'status': 'IN_PROGRESS',
  'medicalAccessStatus': 'NONE',
  'version': 0,
  'startedAt': '2026-10-27T10:00:00Z',
};

class _FakeApi implements DoctorActiveConsultationApiContract {
  _FakeApi({required this.active, required this.onStart});

  final List<DoctorActiveConsultation?> active;
  final Future<DoctorActiveConsultation> Function(String, int, String) onStart;
  final starts = <(String, int, String)>[];
  int _activeIndex = 0;

  @override
  Future<DoctorActiveConsultation?> getActive() async {
    final index = _activeIndex++;
    return active[index < active.length ? index : active.length - 1];
  }

  @override
  Future<DoctorActiveConsultation> startScheduled({
    required String appointmentId,
    required int expectedAppointmentVersion,
    required String idempotencyKey,
  }) {
    starts.add((appointmentId, expectedAppointmentVersion, idempotencyKey));
    return onStart(appointmentId, expectedAppointmentVersion, idempotencyKey);
  }
}

AppHttpClient _client(HttpClientAdapter adapter) {
  final dio = Dio()..httpClientAdapter = adapter;
  return AppHttpClient(
    tokenStore: SecureTokenStore(backend: _MemoryTokenBackend()),
    baseUrl: 'https://api.test',
    dio: dio,
    refreshDio: Dio(),
  );
}

class _CaptureAdapter implements HttpClientAdapter {
  _CaptureAdapter(this.response);
  final Object response;
  late RequestOptions request;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    return ResponseBody.fromString(
      jsonEncode(response),
      201,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _MemoryTokenBackend implements SecureTokenStorageBackend {
  final values = <String, String>{};
  @override
  Future<void> delete({required String key}) async => values.remove(key);
  @override
  Future<String?> read({required String key}) async => values[key];
  @override
  Future<void> write({required String key, required String value}) async =>
      values[key] = value;
}

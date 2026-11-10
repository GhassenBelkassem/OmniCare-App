import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicare_mobile/core/network/app_http_client.dart';
import 'package:omnicare_mobile/core/realtime/authenticated_realtime_transport.dart';
import 'package:omnicare_mobile/core/storage/secure_token_store.dart';
import 'package:omnicare_mobile/core/theme/omni_theme.dart';
import 'package:omnicare_mobile/features/doctor/active_consultation/doctor_active_consultation.dart';
import 'package:omnicare_mobile/features/doctor/active_consultation/doctor_active_consultation_api.dart';
import 'package:omnicare_mobile/features/doctor/active_consultation/doctor_active_consultation_controller.dart';
import 'package:omnicare_mobile/features/doctor/clinical_order/clinical_order_card.dart';
import 'package:omnicare_mobile/features/doctor/clinical_record/clinical_authoring_card.dart';
import 'package:omnicare_mobile/features/doctor/consultation_detail_screen.dart';
import 'package:omnicare_mobile/features/doctor/demo/doctor_demo_profile.dart';
import 'package:omnicare_mobile/features/doctor/medical_record/doctor_medical_record_api.dart';
import 'package:omnicare_mobile/features/doctor/medical_record/doctor_medical_record_controller.dart';
import 'package:omnicare_mobile/features/doctor/medical_record/doctor_medical_record_workspace.dart';
import 'package:omnicare_mobile/features/doctor/prescription/prescription_card.dart';
import 'package:omnicare_mobile/features/doctor/scheduled_care/application/doctor_home_controller.dart';
import 'package:omnicare_mobile/features/doctor/scheduled_care/data/doctor_scheduled_care_api.dart';
import 'package:omnicare_mobile/features/doctor/scheduled_care/data/doctor_scheduled_care_repository.dart';
import 'package:omnicare_mobile/features/doctor/shell/doctor_app_shell.dart';
import 'package:omnicare_mobile/features/doctor/workspace/doctor_workspace_config.dart';
import 'package:omnicare_mobile/features/scheduled_care/realtime/scheduled_care_realtime_coordinator.dart';
import 'package:provider/provider.dart';

const _consultationId = 'e97c7a54-e378-4d59-b656-5e15457cdc02';

void main() {
  testWidgets(
    'Finish completion detaches active stores and clears current authority',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      final adapter = _FinishAdapter();
      final client = _client(adapter);
      final transport = _Transport();
      final coordinator = ScheduledCareRealtimeCoordinator(
        transport: transport,
      );
      final activeApi = _ActiveApi(_activeConsultation);
      final active = DoctorActiveConsultationController(api: activeApi);
      addTearDown(() => client.close(force: true));
      addTearDown(coordinator.dispose);
      addTearDown(active.dispose);

      await active.attachDoctor('doctor-a');
      await coordinator.startSession(
        const RealtimeSessionOwner(userId: 'doctor-a', role: 'DOCTOR'),
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<AppHttpClient>.value(value: client),
            Provider<ScheduledCareRealtimeCoordinator>.value(
              value: coordinator,
            ),
          ],
          child: MaterialApp(
            theme: buildOmniTheme(),
            home: ConsultationDetailScreen(
              consultationId: _consultationId,
              activeWorkspace: true,
              consultation: const <String, dynamic>{
                'id': _consultationId,
                'status': 'IN_PROGRESS',
              },
              onCompleted: (consultationId) async {
                activeApi.value = null;
                await active.reconcileCompleted(consultationId);
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(adapter.clinicalGets, greaterThan(0));
      expect(adapter.prescriptionGets, greaterThan(0));
      expect(adapter.orderGets, greaterThan(0));
      expect(adapter.artifactGets, greaterThan(0));
      expect(active.active?.consultationId, _consultationId);

      final finish = find.widgetWithText(ElevatedButton, 'Finish consultation');
      await tester.ensureVisible(finish);
      await tester.tap(finish);
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(FilledButton, 'Finish consultation'),
      );
      await tester.pumpAndSettle();

      expect(adapter.finishPosts, 1);
      expect(find.text('Consultation completed'), findsOneWidget);
      expect(find.byType(ClinicalAuthoringCard), findsNothing);
      expect(find.byType(PrescriptionCard), findsNothing);
      expect(find.byType(ClinicalOrderCard), findsNothing);
      expect(active.active, isNull);
      expect(activeApi.startCalls, 0);

      final countsAfterFinish = adapter.activeGetCounts;
      transport.emit(_completionEvent);
      await tester.pumpAndSettle();
      await coordinator.foregroundResync();
      await tester.pumpAndSettle();

      expect(adapter.activeGetCounts, countsAfterFinish);
      expect(adapter.finishPosts, 1);
      expect(active.active, isNull);
      expect(activeApi.startCalls, 0);
    },
  );

  testWidgets(
    'completed history detail remains reachable without active-care stores',
    (tester) async {
      final adapter = _FinishAdapter();
      final client = _client(adapter);
      addTearDown(() => client.close(force: true));

      await tester.pumpWidget(
        Provider<AppHttpClient>.value(
          value: client,
          child: MaterialApp(
            theme: buildOmniTheme(),
            home: const ConsultationDetailScreen(
              consultationId: _consultationId,
              consultation: <String, dynamic>{
                'id': _consultationId,
                'status': 'COMPLETED',
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Consultation Details'), findsOneWidget);
      expect(find.byType(ClinicalAuthoringCard), findsNothing);
      expect(find.byType(PrescriptionCard), findsNothing);
      expect(find.byType(ClinicalOrderCard), findsNothing);
      expect(find.text('Save'), findsNothing);
      expect(find.text('Complete'), findsNothing);
      expect(adapter.activeGetCounts, const <int>[0, 0, 0, 0]);
    },
  );

  testWidgets(
    'Finish refreshes Doctor Home before navigation returns from workspace',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1024, 768);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      final adapter = _FinishAdapter();
      final client = _client(adapter);
      final activeApi = _ActiveApi(
        _activeConsultation,
        valueProvider: () => adapter.completed ? null : _activeConsultation,
      );
      final active = DoctorActiveConsultationController(api: activeApi);
      final home = DoctorHomeController(
        repository: DoctorScheduledCareRepository(
          DoctorScheduledCareApi(client),
        ),
      );
      final medical = DoctorMedicalRecordController(
        api: _MedicalApi(_medicalWorkspace),
      );
      addTearDown(() => client.close(force: true));
      addTearDown(active.dispose);
      addTearDown(home.dispose);
      addTearDown(medical.dispose);
      await active.attachDoctor('doctor-a');

      await tester.pumpWidget(
        Provider<AppHttpClient>.value(
          value: client,
          child: MaterialApp(
            theme: buildOmniTheme(),
            home: DoctorAppShell(
              profile: DoctorDemoProfile.current,
              onLogout: () async {},
              authoritativeCapabilities: const {
                DoctorCapability.cabinetAppointments,
              },
              homeController: home,
              activeConsultationController: active,
              medicalRecordController: medical,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('doctor-active-consultation-button')),
        findsOneWidget,
      );
      expect(find.text('Rendez-vous à démarrer'), findsNothing);

      await tester.tap(
        find.byKey(const ValueKey('doctor-active-consultation-button')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ouvrir le dossier'));
      await tester.pumpAndSettle();
      final continuation = find.text('Continuer la consultation');
      await tester.scrollUntilVisible(continuation, 180);
      await tester.tap(continuation);
      await tester.pumpAndSettle();

      final finish = find.widgetWithText(ElevatedButton, 'Finish consultation');
      await tester.ensureVisible(finish);
      await tester.tap(finish);
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(FilledButton, 'Finish consultation'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Consultation completed'), findsOneWidget);
      expect(active.active, isNull);

      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Rendez-vous à démarrer'), findsOneWidget);
      expect(find.text('Later Confirmed Patient'), findsOneWidget);
      expect(find.text('Finished Source Patient'), findsNothing);
      expect(adapter.homeGets, greaterThanOrEqualTo(2));
      expect(adapter.finishPosts, 1);
      expect(activeApi.startCalls, 0);
    },
  );
}

final _activeConsultation = DoctorActiveConsultation(
  consultationId: _consultationId,
  sourceType: DoctorConsultationSourceType.scheduledAppointment,
  sourceId: '8eca2732-a477-4b3a-af89-8982afcae325',
  status: DoctorConsultationStatus.inProgress,
  medicalAccessStatus: DoctorConsultationMedicalAccessStatus.active,
  version: 1,
  startedAt: DateTime.utc(2026, 10, 27, 20, 38, 52),
);

class _ActiveApi implements DoctorActiveConsultationApiContract {
  _ActiveApi(this.value, {this.valueProvider});

  DoctorActiveConsultation? value;
  final DoctorActiveConsultation? Function()? valueProvider;
  int startCalls = 0;

  @override
  Future<DoctorActiveConsultation?> getActive() async =>
      valueProvider == null ? value : valueProvider!();

  @override
  Future<DoctorActiveConsultation> startScheduled({
    required String appointmentId,
    required int expectedAppointmentVersion,
    required String idempotencyKey,
  }) async {
    startCalls++;
    return value!;
  }
}

class _FinishAdapter implements HttpClientAdapter {
  int clinicalGets = 0;
  int prescriptionGets = 0;
  int orderGets = 0;
  int artifactGets = 0;
  int finishPosts = 0;
  int homeGets = 0;
  bool completed = false;
  bool laterAppointmentAvailable = true;

  List<int> get activeGetCounts => <int>[
    clinicalGets,
    prescriptionGets,
    orderGets,
    artifactGets,
  ];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.path;
    Object body;
    if (path.endsWith('/scheduled-care/home-summary')) {
      homeGets++;
      body = _homeSummary(
        appointment: completed
            ? (laterAppointmentAvailable ? _laterAppointment : null)
            : _sourceAppointment,
      );
    } else if (path.endsWith('/finish-readiness')) {
      body = const <String, Object>{
        'ready': true,
        'clinicalRecordSaved': true,
        'diagnosisReady': true,
        'medicationDecisionReady': true,
        'followUpReady': true,
        'prescriptionReady': true,
        'ordersReady': true,
        'artifactsReady': true,
        'missing': <Object>[],
      };
    } else if (path.endsWith('/finish') && options.method == 'POST') {
      finishPosts++;
      completed = true;
      body = _consultation(completed: true);
    } else if (path.endsWith('/clinical-record')) {
      clinicalGets++;
      body = _clinicalRecord;
    } else if (path.endsWith('/prescription')) {
      prescriptionGets++;
      body = _prescription;
    } else if (path.endsWith('/clinical-orders')) {
      orderGets++;
      body = const <String, Object>{'orders': <Object>[]};
    } else if (path.endsWith('/artifacts')) {
      artifactGets++;
      body = const <String, Object>{'artifacts': <Object>[]};
    } else if (path.endsWith('/$_consultationId')) {
      body = _consultation(completed: completed);
    } else {
      body = const <String, Object>{'errorCode': 'NOT_FOUND'};
      return _response(body, 404);
    }
    return _response(body, 200);
  }

  Map<String, Object?> _consultation({required bool completed}) =>
      <String, Object?>{
        'consultationId': _consultationId,
        'status': completed ? 'COMPLETED' : 'IN_PROGRESS',
        'medicalAccessStatus': completed ? 'EXPIRED' : 'ACTIVE',
        'version': completed ? 3 : 1,
        if (completed) 'completedAt': '2026-10-27T22:00:00Z',
      };

  ResponseBody _response(Object body, int status) => ResponseBody.fromString(
    jsonEncode(body),
    status,
    headers: const <String, List<String>>{
      Headers.contentTypeHeader: <String>[Headers.jsonContentType],
    },
  );
}

Map<String, Object?> _homeSummary({required Object? appointment}) =>
    <String, Object?>{
      'generatedAt': '2026-10-27T22:59:33Z',
      'pendingRequestCount': 0,
      'nextPendingRequest': null,
      'nextConfirmedAppointment': appointment,
    };

const _sourceAppointment = <String, Object?>{
  'resourceType': 'APPOINTMENT',
  'requestId': null,
  'appointmentId': '8eca2732-a477-4b3a-af89-8982afcae325',
  'sourceBookingRequestId': '11111111-1111-4111-8111-111111111111',
  'version': 0,
  'status': 'CONFIRMED',
  'doctor': <String, Object?>{
    'displayName': 'Dr Test',
    'specialty': 'General medicine',
  },
  'subject': <String, Object?>{
    'subjectType': 'SELF',
    'displayName': 'Finished Source Patient',
    'relationship': null,
  },
  'cabinet': <String, Object?>{
    'name': 'Cabinet Test',
    'address': 'Address',
    'city': 'Tunis',
    'governorate': 'Tunis',
    'timezone': 'Africa/Tunis',
  },
  'start': '2026-10-27T20:00:00Z',
  'end': '2026-10-27T20:30:00Z',
  'timezone': 'Africa/Tunis',
  'responseDeadline': null,
  'cancellation': null,
  'intakeStatus': null,
  'availableActions': <Object>[],
  'sortAt': '2026-10-27T20:00:00Z',
  'updatedAt': '2026-10-27T20:00:00Z',
};

final _laterAppointment = <String, Object?>{
  ..._sourceAppointment,
  'appointmentId': 'a1fabec2-c126-4a44-8edd-2df4c7f1b92e',
  'subject': <String, Object?>{
    'subjectType': 'SELF',
    'displayName': 'Later Confirmed Patient',
    'relationship': null,
  },
  'start': '2026-10-28T08:00:00Z',
  'end': '2026-10-28T08:30:00Z',
  'sortAt': '2026-10-28T08:00:00Z',
};

final _medicalWorkspace = DoctorMedicalRecordWorkspace(
  consultationId: _consultationId,
  accessExpiresAt: DateTime.utc(2026, 10, 28),
  sections: <String, String>{
    'ESSENTIAL_INFORMATION': 'AUTHORIZED',
    'CURRENT_MEDICATIONS': 'AUTHORIZED',
    'CONSULTATION_SUMMARIES': 'AUTHORIZED',
    'DOCUMENTS': 'LOCKED',
  },
  essentialInformation: null,
  currentMedications: <DoctorCurrentMedication>[],
  consultationSummaries: <DoctorConsultationSummary>[],
);

class _MedicalApi implements DoctorMedicalRecordApiContract {
  const _MedicalApi(this.workspace);
  final DoctorMedicalRecordWorkspace workspace;

  @override
  Future<DoctorMedicalRecordWorkspace> read(String consultationId) async =>
      workspace;
}

const _clinicalRecord = <String, Object?>{
  'clinicalRecordVersion': 1,
  'schemaVersion': 2,
  'clinicalRecord': <String, Object?>{
    'chiefComplaint': null,
    'history': <String, Object?>{},
    'clinicalFindings': <Object>[],
    'diagnoses': <Object>[],
    'assessment': null,
    'treatmentPlan': <Object>[],
    'followUp': <String, Object?>{'required': false},
    'notes': null,
    'medicationDecision': 'NO_MEDICATION',
  },
};

const _prescription = <String, Object?>{
  'prescriptionId': null,
  'prescriptionVersion': 1,
  'clinicalRecordVersion': 1,
  'schemaVersion': 2,
  'status': 'DRAFT',
  'finalized': false,
  'medicationDecision': 'NO_MEDICATION',
  'signedAt': null,
  'signatureAlgorithm': null,
  'prescription': <String, Object?>{
    'medications': <Object>[],
    'generalInstructions': null,
  },
};

const _completionEvent =
    '{"eventId":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa",'
    '"eventType":"CONSULTATION_COMPLETED",'
    '"resourceType":"CONSULTATION",'
    '"resourceId":"$_consultationId",'
    '"version":3,"occurredAt":"2026-10-27T22:00:00Z"}';

AppHttpClient _client(HttpClientAdapter adapter) {
  final dio = Dio()..httpClientAdapter = adapter;
  return AppHttpClient(
    tokenStore: SecureTokenStore(backend: _MemoryStorage()),
    baseUrl: 'https://api.test',
    dio: dio,
    refreshDio: Dio()..httpClientAdapter = _FinishAdapter(),
  );
}

class _Transport implements ScheduledCareRealtimeTransport {
  final StreamController<String> _messages = StreamController.broadcast();
  final StreamController<String> _notifications = StreamController.broadcast();
  final StreamController<int> _epochs = StreamController.broadcast();
  RealtimeSessionOwner? _owner;

  void emit(String body) => _messages.add(body);

  @override
  int get connectionEpoch => 0;
  @override
  Stream<int> get connectedEpochs => _epochs.stream;
  @override
  Stream<String> get messages => _messages.stream;
  @override
  Stream<String> get notificationMessages => _notifications.stream;
  @override
  RealtimeSessionOwner? get owner => _owner;
  @override
  RealtimeConnectionState get state => _owner == null
      ? RealtimeConnectionState.disconnected
      : RealtimeConnectionState.connected;
  @override
  Future<void> ensureConnected() async {}
  @override
  Future<void> startSession(RealtimeSessionOwner owner) async => _owner = owner;
  @override
  Future<void> stopSession() async => _owner = null;
}

class _MemoryStorage implements SecureTokenStorageBackend {
  @override
  Future<void> delete({required String key}) async {}
  @override
  Future<String?> read({required String key}) async => null;
  @override
  Future<void> write({required String key, required String value}) async {}
}

import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicare_mobile/core/network/app_http_client.dart';
import 'package:omnicare_mobile/core/storage/secure_token_store.dart';
import 'package:omnicare_mobile/core/theme/omni_theme.dart';
import 'package:omnicare_mobile/features/doctor/active_consultation/doctor_active_consultation.dart';
import 'package:omnicare_mobile/features/doctor/active_consultation/doctor_active_consultation_api.dart';
import 'package:omnicare_mobile/features/doctor/active_consultation/doctor_active_consultation_controller.dart';
import 'package:omnicare_mobile/features/doctor/consultation_detail_screen.dart';
import 'package:omnicare_mobile/features/doctor/demo/doctor_demo_profile.dart';
import 'package:omnicare_mobile/features/doctor/medical_record/doctor_medical_record_access.dart';
import 'package:omnicare_mobile/features/doctor/medical_record/doctor_medical_record_api.dart';
import 'package:omnicare_mobile/features/doctor/medical_record/doctor_medical_record_controller.dart';
import 'package:omnicare_mobile/features/doctor/medical_record/doctor_medical_record_screen.dart';
import 'package:omnicare_mobile/features/doctor/medical_record/doctor_medical_record_workspace.dart';
import 'package:omnicare_mobile/features/doctor/shell/doctor_app_shell.dart';
import 'package:omnicare_mobile/features/doctor/workspace/doctor_workspace_config.dart';
import 'package:provider/provider.dart';

const _consultationId = 'e97c7a54-e378-4d59-b656-5e15457cdc02';
const _appointmentId = '8eca2732-a477-4b3a-af89-8982afcae325';

void main() {
  testWidgets(
    'current Consultation continues into the canonical workspace without Start',
    (tester) async {
      final consultationApi = _ActiveApi(_activeConsultation);
      final active = DoctorActiveConsultationController(api: consultationApi);
      final medical = DoctorMedicalRecordController(
        api: _MedicalRecordApi(_workspace),
      );
      final client = _client();
      addTearDown(active.dispose);
      addTearDown(medical.dispose);
      addTearDown(() => client.close(force: true));
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
              activeConsultationController: active,
              medicalRecordController: medical,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

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

      final workspaceFinder = find.byType(ConsultationDetailScreen);
      expect(workspaceFinder, findsOneWidget);
      expect(
        tester.widget<ConsultationDetailScreen>(workspaceFinder).consultationId,
        _consultationId,
      );
      expect(
        tester
            .widget<ConsultationDetailScreen>(workspaceFinder)
            .activeWorkspace,
        isTrue,
      );
      expect(consultationApi.startCalls, 0);
      expect(
        find.text('La consultation sera ajoutée à l’étape suivante.'),
        findsNothing,
      );
    },
  );

  testWidgets('no active Consultation exposes no continuation workspace', (
    tester,
  ) async {
    final consultationApi = _ActiveApi(null);
    final active = DoctorActiveConsultationController(api: consultationApi);
    addTearDown(active.dispose);
    await active.attachDoctor('doctor-a');

    await tester.pumpWidget(
      MaterialApp(
        theme: buildOmniTheme(),
        home: DoctorAppShell(
          profile: DoctorDemoProfile.current,
          onLogout: () async {},
          authoritativeCapabilities: const {
            DoctorCapability.cabinetAppointments,
          },
          activeConsultationController: active,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('doctor-active-consultation-button')),
      findsNothing,
    );
    expect(find.text('Continuer la consultation'), findsNothing);
    expect(consultationApi.startCalls, 0);
  });

  testWidgets('authorized section does not render LOCKED completed summary', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildOmniTheme(),
        home: DoctorMedicalRecordScreen(
          access: DoctorMedicalRecordAccess.fromWorkspace(_workspace),
        ),
      ),
    );

    await tester.tap(find.text('Historique'));
    await tester.pumpAndSettle();

    expect(find.text('Aucune consultation trouvée.'), findsOneWidget);
    expect(find.text('1f2ab781-16f5-4d91-b465-8c980eb948b5'), findsNothing);
  });
}

final _activeConsultation = DoctorActiveConsultation(
  consultationId: _consultationId,
  sourceType: DoctorConsultationSourceType.scheduledAppointment,
  sourceId: _appointmentId,
  status: DoctorConsultationStatus.inProgress,
  medicalAccessStatus: DoctorConsultationMedicalAccessStatus.active,
  version: 1,
  startedAt: DateTime.utc(2026, 10, 27, 20, 38, 52),
);

final _workspace = DoctorMedicalRecordWorkspace(
  consultationId: _consultationId,
  accessExpiresAt: DateTime.utc(2026, 10, 28, 4, 48),
  sections: const <String, String>{
    'ESSENTIAL_INFORMATION': 'AUTHORIZED',
    'CURRENT_MEDICATIONS': 'AUTHORIZED',
    'CONSULTATION_SUMMARIES': 'AUTHORIZED',
    'DOCUMENTS': 'LOCKED',
  },
  essentialInformation: null,
  currentMedications: const [],
  consultationSummaries: const [],
);

class _ActiveApi implements DoctorActiveConsultationApiContract {
  _ActiveApi(this.value);

  final DoctorActiveConsultation? value;
  int startCalls = 0;

  @override
  Future<DoctorActiveConsultation?> getActive() async => value;

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

class _MedicalRecordApi implements DoctorMedicalRecordApiContract {
  const _MedicalRecordApi(this.value);

  final DoctorMedicalRecordWorkspace value;

  @override
  Future<DoctorMedicalRecordWorkspace> read(String consultationId) async {
    expect(consultationId, _consultationId);
    return value;
  }
}

AppHttpClient _client() {
  final dio = Dio()..httpClientAdapter = _UnavailableAdapter();
  return AppHttpClient(
    tokenStore: SecureTokenStore(backend: _MemoryStorage()),
    baseUrl: 'https://api.test',
    dio: dio,
    refreshDio: Dio()..httpClientAdapter = _UnavailableAdapter(),
  );
}

class _UnavailableAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    '{"errorCode":"UNAVAILABLE"}',
    503,
    headers: const <String, List<String>>{
      Headers.contentTypeHeader: <String>[Headers.jsonContentType],
    },
  );
}

class _MemoryStorage implements SecureTokenStorageBackend {
  @override
  Future<void> delete({required String key}) async {}

  @override
  Future<String?> read({required String key}) async => null;

  @override
  Future<void> write({required String key, required String value}) async {}
}

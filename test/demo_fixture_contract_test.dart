import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicare_mobile/core/api/family_api.dart';
import 'package:omnicare_mobile/core/network/app_http_client.dart';
import 'package:omnicare_mobile/core/storage/secure_token_store.dart';
import 'package:omnicare_mobile/demo/demo_http_adapter.dart';
import 'package:omnicare_mobile/demo/demo_token_storage.dart';
import 'package:omnicare_mobile/features/clinic/data/clinic_api.dart';
import 'package:omnicare_mobile/features/doctor/scheduled_care/data/doctor_scheduled_care_api.dart';
import 'package:omnicare_mobile/features/doctor/workspace/doctor_workspace_bootstrap_api.dart';
import 'package:omnicare_mobile/features/doctor/workspace/doctor_workspace_bootstrap_repository.dart';
import 'package:omnicare_mobile/features/patient_clinic/data/patient_clinic_api.dart';

void main() {
  late AppHttpClient client;

  setUp(() {
    client = AppHttpClient(
      tokenStore: SecureTokenStore(backend: DemoTokenStorage()),
      baseUrl: 'https://static-demo.invalid',
      dio: _dio(),
      refreshDio: _dio(),
    );
  });

  tearDown(() => client.close(force: true));

  test('patient home fixtures satisfy production contracts', () async {
    final family = await FamilyApi(httpClient: client).getFamilyMembers();
    final clinics = await PatientClinicApi(client).listClinics();

    expect(family.single.fullName, 'Youssef Ben Amor');
    expect(clinics.items, isEmpty);
    expect(clinics.contractVersion, '1.0');
  });

  test('doctor bootstrap fixtures satisfy production contracts', () async {
    final workspace = await DoctorWorkspaceBootstrapRepository(
      DoctorWorkspaceBootstrapApi(client),
    ).load('00000000-0000-4000-8000-000000000002');
    final summary = await DoctorScheduledCareApi(client).getHomeSummary();

    expect(workspace.hasUrgentCabinet, isTrue);
    expect(workspace.activeCabinets.single.name, 'Cabinet Lac 2');
    expect(summary.pendingRequestCount, 0);
  });

  test('clinic fixtures satisfy production contracts', () async {
    final api = ClinicApi(client);

    final access = await api.fetchAccess();
    final memberships = await api.fetchMemberships();
    final bootstrap = await api.fetchBootstrap(
      memberships.activeMemberships.single.clinicId,
    );

    expect(access.accessFamily.wireValue, 'CLINIC');
    expect(
      memberships.activeMemberships.single.clinicName,
      contains('OmniCare'),
    );
    expect(bootstrap.membership.professionalRole.wireValue, 'CLINIC_ADMIN');
  });
}

Dio _dio() {
  final dio = Dio();
  dio.httpClientAdapter = DemoHttpAdapter();
  return dio;
}

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:omnicare_mobile/core/storage/secure_token_store.dart';
import 'package:omnicare_mobile/features/doctor/workspace/doctor_workspace_config.dart';
import 'package:omnicare_mobile/features/doctor/workspace/doctor_workspace_controller.dart';
import 'package:omnicare_mobile/features/doctor/workspace/doctor_workspace_repository.dart';

class _MemoryStorageBackend implements SecureTokenStorageBackend {
  final values = <String, String>{};

  @override
  Future<void> delete({required String key}) async {
    values.remove(key);
  }

  @override
  Future<String?> read({required String key}) async => values[key];

  @override
  Future<void> write({required String key, required String value}) async {
    values[key] = value;
  }
}

DoctorWorkspaceConfig _config(String doctorId) => DoctorWorkspaceConfig(
  doctorId: doctorId,
  onboardingCompleted: true,
  practiceModes: {
    DoctorPracticeMode.cabinet,
    DoctorPracticeMode.homeVisit,
    DoctorPracticeMode.urgentHome,
  },
  services: {
    DoctorWorkspaceService.cabinetConsultations,
    DoctorWorkspaceService.patientFollowUp,
    DoctorWorkspaceService.appointments,
    DoctorWorkspaceService.homeVisits,
    DoctorWorkspaceService.urgentHomeVisits,
  },
  cabinet: const DoctorCabinetConfig(
    name: 'Cabinet Mansour',
    governorate: 'Tunis',
    city: 'Carthage',
    address: '12 avenue de la République',
  ),
  clinics: const [],
  homeVisit: const DoctorHomeVisitConfig(
    governorate: 'Tunis',
    maxDistanceKm: 20,
    availableForHomeVisits: true,
  ),
  availability: const DoctorAvailability(
    workingDays: {DoctorWorkingDay.monday, DoctorWorkingDay.tuesday},
    startTime: '08:00',
    endTime: '17:00',
  ),
);

void main() {
  test(
    'workspace capability derivation has one local interpretation point',
    () {
      final capabilities = deriveDoctorCapabilities(_config('doctor-a'));

      expect(
        capabilities,
        containsAll({
          DoctorCapability.agenda,
          DoctorCapability.patientManagement,
          DoctorCapability.cabinetAppointments,
          DoctorCapability.homeVisits,
          DoctorCapability.urgentRequests,
          DoctorCapability.urgentHomeRequests,
          DoctorCapability.urgentWorkspace,
          DoctorCapability.workQueue,
          DoctorCapability.followUp,
        }),
      );
      expect(
        capabilities,
        isNot(contains(DoctorCapability.urgentCabinetRequests)),
      );
      expect(capabilities, isNot(contains(DoctorCapability.clinicWorkspace)));
    },
  );

  test(
    'workspace configuration persists per Doctor and survives controller reload',
    () async {
      final backend = _MemoryStorageBackend();
      final repository = DoctorWorkspaceRepository(backend: backend);
      await repository.save(_config('doctor-a'));
      await repository.save(_config('doctor-b'));

      final controller = DoctorWorkspaceController(repository: repository);
      await controller.load('doctor-a');
      expect(controller.onboardingCompleted, isTrue);
      expect(controller.config?.cabinet?.name, 'Cabinet Mansour');

      await controller.load('doctor-b');
      expect(controller.config?.doctorId, 'doctor-b');

      await controller.resetForDemo();
      expect(await repository.read('doctor-b'), isNull);
      expect(await repository.read('doctor-a'), isNotNull);
    },
  );

  test(
    'a corrupt local workspace record safely returns onboarding state',
    () async {
      final backend = _MemoryStorageBackend()
        ..values['omnicare_doctor_workspace_v1:doctor-a'] = jsonEncode({
          'schemaVersion': 999,
        });
      final repository = DoctorWorkspaceRepository(backend: backend);

      expect(await repository.read('doctor-a'), isNull);
      expect(backend.values, isEmpty);
    },
  );

  test('schema-v1 workspaces keep urgent CABINET disabled by default', () {
    final homeJson = _config('doctor-home').toJson()
      ..['practiceModes'] = ['urgentHome']
      ..['services'] = ['urgentHomeVisits']
      ..['cabinet'] = null;
    final cabinetJson = _config('doctor-cabinet').toJson()
      ..['practiceModes'] = ['cabinet']
      ..['services'] = ['cabinetConsultations'];
    final hybridJson = _config('doctor-hybrid').toJson()
      ..['practiceModes'] = ['cabinet', 'urgentHome']
      ..['services'] = ['cabinetConsultations', 'urgentHomeVisits'];

    final home = DoctorWorkspaceConfig.fromJson(homeJson);
    final cabinet = DoctorWorkspaceConfig.fromJson(cabinetJson);
    final hybrid = DoctorWorkspaceConfig.fromJson(hybridJson);

    expect(
      deriveDoctorCapabilities(home),
      containsAll({
        DoctorCapability.urgentRequests,
        DoctorCapability.urgentHomeRequests,
        DoctorCapability.urgentWorkspace,
      }),
    );
    expect(
      deriveDoctorCapabilities(cabinet),
      isNot(contains(DoctorCapability.urgentWorkspace)),
    );
    expect(
      deriveDoctorCapabilities(hybrid),
      isNot(contains(DoctorCapability.urgentCabinetRequests)),
    );
  });

  test(
    'urgent CABINET service round-trips independently of normal cabinet',
    () {
      final original = _config('doctor-cabinet');
      final urgentCabinet = DoctorWorkspaceConfig(
        doctorId: original.doctorId,
        onboardingCompleted: original.onboardingCompleted,
        practiceModes: const {DoctorPracticeMode.cabinet},
        services: {
          DoctorWorkspaceService.cabinetConsultations,
          DoctorWorkspaceService.urgentCabinetConsultations,
        },
        cabinet: original.cabinet,
        clinics: original.clinics,
        homeVisit: null,
        availability: original.availability,
      );

      final decoded = DoctorWorkspaceConfig.fromJson(urgentCabinet.toJson());
      final capabilities = deriveDoctorCapabilities(decoded);

      expect(
        decoded.services,
        contains(DoctorWorkspaceService.urgentCabinetConsultations),
      );
      expect(capabilities, contains(DoctorCapability.urgentCabinetRequests));
      expect(capabilities, contains(DoctorCapability.urgentWorkspace));
      expect(capabilities, isNot(contains(DoctorCapability.urgentRequests)));
      expect(
        capabilities,
        isNot(contains(DoctorCapability.urgentHomeRequests)),
      );
    },
  );

  test('legacy teleconsultation selections still round-trip', () {
    final original = _config('doctor-teleconsultation');
    final legacyTeleconsultation = DoctorWorkspaceConfig(
      doctorId: original.doctorId,
      onboardingCompleted: original.onboardingCompleted,
      practiceModes: const {DoctorPracticeMode.teleconsultation},
      services: const {DoctorWorkspaceService.teleconsultationPreparation},
      clinics: const [],
      availability: original.availability,
    );

    final decoded = DoctorWorkspaceConfig.fromJson(
      legacyTeleconsultation.toJson(),
    );

    expect(
      decoded.practiceModes,
      contains(DoctorPracticeMode.teleconsultation),
    );
    expect(
      decoded.services,
      contains(DoctorWorkspaceService.teleconsultationPreparation),
    );
  });
}

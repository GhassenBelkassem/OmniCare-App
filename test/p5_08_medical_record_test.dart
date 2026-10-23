import 'package:flutter_test/flutter_test.dart';
import 'package:omnicare_mobile/core/network/api_exception.dart';
import 'package:omnicare_mobile/features/doctor/active_consultation/doctor_active_consultation.dart';
import 'package:omnicare_mobile/features/doctor/medical_record/doctor_medical_record_access.dart';
import 'package:omnicare_mobile/features/doctor/medical_record/doctor_medical_record_api.dart';
import 'package:omnicare_mobile/features/doctor/medical_record/doctor_medical_record_controller.dart';
import 'package:omnicare_mobile/features/doctor/medical_record/doctor_medical_record_workspace.dart';
import 'package:omnicare_mobile/features/scheduled_care/realtime/scheduled_care_event.dart';

void main() {
  group('P5-08 Doctor medical-record workspace', () {
    test('maps canonical essential, medication and history fields', () {
      final workspace = DoctorMedicalRecordWorkspace.fromJson(_workspaceJson());
      final access = DoctorMedicalRecordAccess.fromWorkspace(workspace);

      expect(access.essentialShared, isTrue);
      expect(access.medicationsShared, isTrue);
      expect(access.summariesShared, isTrue);
      expect(access.passport.allergies, contains('canonical allergy'));
      expect(access.passport.medications.single.name, 'canonical medicine');
      expect(
        access.passport.consultations.single.reason,
        'Canonical complaint',
      );
      expect(
        access.passport.consultations.single.assessment,
        'Canonical assessment',
      );
      expect(access.documents, isEmpty);
    });

    test('ACTIVE loads real authority and clear removes all PHI', () async {
      final api = _FakeMedicalRecordApi(<Object>[
        DoctorMedicalRecordWorkspace.fromJson(_workspaceJson()),
      ]);
      final controller = DoctorMedicalRecordController(api: api);

      controller.synchronize(_consultation());
      await _settle();

      expect(controller.state, DoctorMedicalRecordState.ready);
      expect(controller.workspace?.essentialInformation?.bloodType, 'O+');
      expect(api.calls, 1);
      controller.clear();
      expect(controller.state, DoctorMedicalRecordState.detached);
      expect(controller.workspace, isNull);
      controller.dispose();
    });

    test('NONE, expired and revoked never retain historical PHI', () async {
      final controller = DoctorMedicalRecordController(
        api: _FakeMedicalRecordApi(<Object>[
          DoctorMedicalRecordWorkspace.fromJson(_workspaceJson()),
        ]),
      );
      controller.synchronize(_consultation());
      await _settle();
      expect(controller.workspace, isNotNull);

      controller.synchronize(
        _consultation(access: DoctorConsultationMedicalAccessStatus.none),
      );
      expect(controller.state, DoctorMedicalRecordState.accessRequired);
      expect(controller.workspace, isNull);
      controller.synchronize(
        _consultation(access: DoctorConsultationMedicalAccessStatus.expired),
      );
      expect(controller.state, DoctorMedicalRecordState.expired);
      controller.synchronize(
        _consultation(access: DoctorConsultationMedicalAccessStatus.revoked),
      );
      expect(controller.state, DoctorMedicalRecordState.revoked);
      controller.dispose();
    });

    test('authoritative denial and outage have no static fallback', () async {
      for (final entry in <String, DoctorMedicalRecordState>{
        'CLINICAL_ACCESS_REQUIRED': DoctorMedicalRecordState.accessRequired,
        'CLINICAL_ACCESS_EXPIRED': DoctorMedicalRecordState.expired,
        'CLINICAL_ACCESS_REVOKED': DoctorMedicalRecordState.revoked,
        'MRS_UNAVAILABLE': DoctorMedicalRecordState.unavailable,
      }.entries) {
        final controller = DoctorMedicalRecordController(
          api: _FakeMedicalRecordApi(<Object>[
            ApiException('denied', code: entry.key),
          ]),
        );
        controller.synchronize(_consultation());
        await _settle();
        expect(controller.state, entry.value);
        expect(controller.workspace, isNull);
        controller.dispose();
      }
    });

    test(
      'access invalidation clears then refetches and reconnect resyncs',
      () async {
        final api = _FakeMedicalRecordApi(<Object>[
          DoctorMedicalRecordWorkspace.fromJson(_workspaceJson()),
          DoctorMedicalRecordWorkspace.fromJson(_workspaceJson()),
          DoctorMedicalRecordWorkspace.fromJson(_workspaceJson()),
        ]);
        final controller = DoctorMedicalRecordController(api: api);
        final target = DoctorMedicalRecordRealtimeTarget(controller)
          ..activate();
        controller.synchronize(_consultation());
        await _settle();

        final pending = target.invalidate(
          ScheduledCareInvalidationEvent(
            eventId: 'event-1',
            type: ScheduledCareEventType.clinicalAccessChanged,
            rawEventType: 'CLINICAL_ACCESS_CHANGED',
            resourceType: ScheduledCareResourceType.consultation,
            resourceId: 'c123',
            version: 2,
            occurredAt: DateTime.utc(2026, 10, 22, 10),
          ),
        );
        expect(controller.workspace, isNull);
        await pending;
        expect(controller.workspace, isNotNull);
        await target.resync();
        expect(api.calls, 3);
        target.dispose();
        controller.dispose();
      },
    );
  });
}

Future<void> _settle() => Future<void>.delayed(Duration.zero);

DoctorActiveConsultation _consultation({
  DoctorConsultationMedicalAccessStatus access =
      DoctorConsultationMedicalAccessStatus.active,
}) => DoctorActiveConsultation(
  consultationId: 'c123',
  sourceType: DoctorConsultationSourceType.scheduledAppointment,
  sourceId: 'appointment-9',
  status: DoctorConsultationStatus.inProgress,
  medicalAccessStatus: access,
  version: 1,
  startedAt: DateTime.utc(2026, 10, 22, 9),
);

Map<String, dynamic> _workspaceJson() => <String, dynamic>{
  'consultation': <String, dynamic>{'consultationId': 'c123'},
  'access': <String, dynamic>{
    'expiresAt': '2026-10-22T17:00:00Z',
    'sections': <String, dynamic>{
      'ESSENTIAL_INFORMATION': 'AUTHORIZED',
      'CURRENT_MEDICATIONS': 'AUTHORIZED',
      'CONSULTATION_SUMMARIES': 'AUTHORIZED',
      'DOCUMENTS': 'DEFERRED',
    },
  },
  'essentialInformation': <String, dynamic>{
    'bloodType': 'O+',
    'allergies': <String>['canonical allergy'],
    'criticalConditions': <String>['canonical condition'],
  },
  'currentMedications': <Map<String, dynamic>>[
    <String, dynamic>{
      'recordVersion': 1,
      'status': 'ACTIVE',
      'name': 'canonical medicine',
      'code': null,
      'strength': '5 mg',
      'doseAmount': 1,
      'doseUnit': 'tablet',
      'dosageText': null,
      'route': 'ORAL',
      'timesPerDay': 1,
      'frequencyText': null,
    },
  ],
  'consultationSummaries': <String, dynamic>{
    'items': <Map<String, dynamic>>[
      <String, dynamic>{
        'consultationId': 'history-1',
        'occurredAt': '2026-10-01T09:00:00Z',
        'chiefComplaint': 'Canonical complaint',
        'diagnoses': <Map<String, dynamic>>[
          <String, dynamic>{'label': 'Canonical diagnosis', 'code': 'D1'},
        ],
        'clinicalCodes': <Map<String, dynamic>>[],
        'assessment': 'Canonical assessment',
        'treatmentPlan': <String>['Canonical plan'],
        'notes': 'Canonical note',
      },
    ],
  },
};

class _FakeMedicalRecordApi implements DoctorMedicalRecordApiContract {
  _FakeMedicalRecordApi(this.responses);

  final List<Object> responses;
  int calls = 0;

  @override
  Future<DoctorMedicalRecordWorkspace> read(String consultationId) async {
    final value =
        responses[calls < responses.length ? calls++ : responses.length - 1];
    if (value is Exception) throw value;
    return value as DoctorMedicalRecordWorkspace;
  }
}

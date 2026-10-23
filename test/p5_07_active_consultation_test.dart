import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:omnicare_mobile/features/doctor/active_consultation/doctor_active_consultation.dart';
import 'package:omnicare_mobile/features/doctor/active_consultation/doctor_active_consultation_api.dart';
import 'package:omnicare_mobile/features/doctor/active_consultation/doctor_active_consultation_controller.dart';
import 'package:omnicare_mobile/features/scheduled_care/realtime/scheduled_care_event.dart';

void main() {
  group('P5-07 active Consultation', () {
    test(
      'Doctor startup loads the canonical C123 and logout clears it',
      () async {
        final api = _FakeActiveConsultationApi(<DoctorActiveConsultation?>[
          _consultation(version: 1),
        ]);
        final controller = DoctorActiveConsultationController(api: api);

        await controller.attachDoctor('doctor-1');

        expect(controller.active?.consultationId, 'c123');
        expect(controller.active?.sourceId, 'appointment-9');
        expect(controller.active?.status, DoctorConsultationStatus.inProgress);
        expect(
          controller.active?.medicalAccessStatus,
          DoctorConsultationMedicalAccessStatus.none,
        );

        controller.clear();
        expect(controller.active, isNull);
        expect(controller.doctorId, isNull);
        controller.dispose();
      },
    );

    test('204-equivalent null removes active state', () async {
      final api = _FakeActiveConsultationApi(<DoctorActiveConsultation?>[
        _consultation(version: 1),
        null,
      ]);
      final controller = DoctorActiveConsultationController(api: api);
      await controller.attachDoctor('doctor-1');

      await controller.refresh();

      expect(controller.active, isNull);
      expect(controller.state, DoctorActiveConsultationLoadState.ready);
      controller.dispose();
    });

    test(
      'access invalidation refetches NONE to ACTIVE while stale is ignored',
      () async {
        final api = _FakeActiveConsultationApi(<DoctorActiveConsultation?>[
          _consultation(version: 1),
          _consultation(
            version: 2,
            access: DoctorConsultationMedicalAccessStatus.active,
          ),
        ]);
        final controller = DoctorActiveConsultationController(api: api);
        final target = DoctorActiveConsultationRealtimeTarget(controller)
          ..activate();
        await controller.attachDoctor('doctor-1');

        await target.invalidate(_event(version: 1));
        expect(api.calls, 1);

        await target.invalidate(
          _event(
            version: 2,
            type: ScheduledCareEventType.clinicalAccessChanged,
          ),
        );
        expect(api.calls, 2);
        expect(
          controller.active?.medicalAccessStatus,
          DoctorConsultationMedicalAccessStatus.active,
        );

        target.dispose();
        controller.dispose();
      },
    );

    test('reconnect resync restores a missed authoritative update', () async {
      final api = _FakeActiveConsultationApi(<DoctorActiveConsultation?>[
        _consultation(version: 1),
        _consultation(version: 4),
      ]);
      final controller = DoctorActiveConsultationController(api: api);
      final target = DoctorActiveConsultationRealtimeTarget(controller)
        ..activate();
      await controller.attachDoctor('doctor-1');

      await target.resync();

      expect(controller.active?.version, 4);
      target.dispose();
      controller.dispose();
    });

    test(
      'consultation invalidation parser accepts only PHI-free references',
      () {
        final parsed = ScheduledCareInvalidationEvent.tryParse(
          jsonEncode(<String, Object>{
            'eventId': '11111111-1111-4111-8111-111111111111',
            'eventType': 'CONSULTATION_ACTIVATED',
            'resourceType': 'CONSULTATION',
            'resourceId': '22222222-2222-4222-8222-222222222222',
            'version': 0,
            'occurredAt': '2026-10-22T09:00:00Z',
          }),
        );

        expect(parsed?.type, ScheduledCareEventType.consultationActivated);
        expect(parsed?.resourceType, ScheduledCareResourceType.consultation);
        expect(parsed?.resourceId, '22222222-2222-4222-8222-222222222222');
      },
    );
  });
}

DoctorActiveConsultation _consultation({
  required int version,
  DoctorConsultationMedicalAccessStatus access =
      DoctorConsultationMedicalAccessStatus.none,
}) => DoctorActiveConsultation(
  consultationId: 'c123',
  sourceType: DoctorConsultationSourceType.scheduledAppointment,
  sourceId: 'appointment-9',
  status: DoctorConsultationStatus.inProgress,
  medicalAccessStatus: access,
  version: version,
  startedAt: DateTime.utc(2026, 10, 22, 9),
);

ScheduledCareInvalidationEvent _event({
  required int version,
  ScheduledCareEventType type = ScheduledCareEventType.consultationUpdated,
}) => ScheduledCareInvalidationEvent(
  eventId: '11111111-1111-4111-8111-111111111111',
  type: type,
  rawEventType: type.name,
  resourceType: ScheduledCareResourceType.consultation,
  resourceId: 'c123',
  version: version,
  occurredAt: DateTime.utc(2026, 10, 22, 9, 1),
);

class _FakeActiveConsultationApi
    implements DoctorActiveConsultationApiContract {
  _FakeActiveConsultationApi(this._responses);

  final List<DoctorActiveConsultation?> _responses;
  int calls = 0;

  @override
  Future<DoctorActiveConsultation?> getActive() async {
    final index = calls++;
    return _responses[index < _responses.length
        ? index
        : _responses.length - 1];
  }
}

// G-2 1a-1 (C1): the booked slot must be POSTed with the exact server
// instants. Every slot here goes through the REAL availability parser and
// mapper; no slot is built by hand.
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omnicare_mobile/core/network/app_http_client.dart';
import 'package:omnicare_mobile/core/storage/secure_token_store.dart';
import 'package:omnicare_mobile/features/patient_doctor/data/doctor_detail_models.dart';
import 'package:omnicare_mobile/features/patient_doctor/data/doctor_directory_mapper.dart';
import 'package:omnicare_mobile/features/patient_doctor/data/doctor_directory_models.dart';
import 'package:omnicare_mobile/features/patient_doctor/data/doctor_models.dart';
import 'package:omnicare_mobile/features/scheduled_care/application/patient_booking_controller.dart';
import 'package:omnicare_mobile/features/scheduled_care/data/scheduled_care_api.dart';
import 'package:omnicare_mobile/features/scheduled_care/data/scheduled_care_repository.dart';
import 'package:omnicare_mobile/features/scheduled_care/presentation/booking_review_screen.dart';

/// Recorded shape of GET /appointments/availability/slots.
const _recordedSlotsJson = '''
{
  "doctorId": "doctor-1",
  "practiceLocationId": "cabinet-1",
  "timezone": "Africa/Tunis",
  "generatedAt": "2026-11-11T07:00:00Z",
  "slots": [
    {"start": "2026-11-12T08:00:00Z", "end": "2026-11-12T08:30:00Z", "durationMinutes": 30},
    {"start": "2026-11-12T13:30:00Z", "end": "2026-11-12T14:00:00Z", "durationMinutes": 30}
  ]
}
''';

const _serverStart = '2026-11-12T08:00:00Z';
const _serverEnd = '2026-11-12T08:30:00Z';

void main() {
  List<DoctorDayAvailability> parseRecorded() => groupAvailabilitySlots(
    AvailabilitySlotsDto.fromJson(
      jsonDecode(_recordedSlotsJson) as Map<String, dynamic>,
    ).slots,
  );

  group('C1 contract: server slot → mapper → controller → POST body', () {
    test('POSTed start/end equal the server slot instants', () async {
      final adapter = _BookingServerAdapter();
      final controller = PatientBookingController(
        repository: ScheduledCareRepository(
          ScheduledCareApi(_httpClient(adapter)),
        ),
        requestIdFactory: () => '11111111-1111-4111-8111-111111111111',
      );
      final slot = parseRecorded().single.slots.first;

      controller.prepareIntent(
        doctor: _doctorDetail(),
        cabinet: _cabinet,
        slot: slot,
      );
      await controller.submit();

      expect(adapter.postedPaths, [ScheduledCareApi.bookingRequestsPath]);
      final sent = adapter.postedBodies.single['requestedSlot'] as Map;
      expect(
        DateTime.parse(sent['start'] as String),
        DateTime.parse(_serverStart),
      );
      expect(DateTime.parse(sent['end'] as String), DateTime.parse(_serverEnd));
      expect(sent['start'], endsWith('Z'));
      // The server echoes the instant it received; the app accepts it as its
      // own intent (it would reject a shifted echo as a mismatch).
      expect(controller.status, PatientBookingStatus.succeeded);
      expect(controller.result?.originalRequestedSlot.start, slot.start);
      controller.dispose();
    });

    test('mapper keeps the server instants and the verbatim identity', () {
      final slot = parseRecorded().single.slots.first;
      expect(slot.start, DateTime.parse(_serverStart));
      expect(slot.start.isUtc, isTrue);
      expect(slot.end, DateTime.parse(_serverEnd));
      expect(slot.startIso, _serverStart);
      expect(slot.endIso, _serverEnd);
      expect(slot.durationMinutes, 30);
    });

    test('display is Africa/Tunis wall clock, unchanged', () {
      final day = parseRecorded().single;
      expect(day.date, DateTime(2026, 11, 12));
      expect(day.slots.map((s) => s.time), ['09:00', '14:30']);
      expect(day.slots.map((s) => s.timeOfDay), ['Matin', 'Après-midi']);
    });

    test('review screen shows the same time as the chosen slot', () {
      final controller = PatientBookingController(
        repository: ScheduledCareRepository(
          ScheduledCareApi(_httpClient(_BookingServerAdapter())),
        ),
        requestIdFactory: () => 'request-1',
      );
      final slot = parseRecorded().single.slots.first;
      controller.prepareIntent(
        doctor: _doctorDetail(),
        cabinet: _cabinet,
        slot: slot,
      );
      final shown = formatSchedulingDateTime(
        controller.intent!.requestedSlot.start,
        timezone: _cabinet.timezone,
      );
      expect(shown, 'jeudi 12 novembre 2026 · ${slot.time}');
      expect(slot.time, '09:00');
      controller.dispose();
    });
  });

  group('Africa/Tunis day grouping boundaries', () {
    DoctorAvailabilitySlot only(String start, String end) =>
        groupAvailabilitySlots([
          AvailabilitySlotDto(start: start, end: end),
        ]).single.slots.single;

    DateTime dayOf(String start, String end) => groupAvailabilitySlots([
      AvailabilitySlotDto(start: start, end: end),
    ]).single.date;

    test('22:59Z is 23:59 on the same Tunis day', () {
      const start = '2026-11-12T22:59:00Z';
      const end = '2026-11-12T23:29:00Z';
      expect(dayOf(start, end), DateTime(2026, 11, 12));
      expect(only(start, end).time, '23:59');
      expect(only(start, end).timeOfDay, 'Soir');
      expect(only(start, end).start, DateTime.parse(start));
    });

    test('23:00Z is 00:00 on the next Tunis day', () {
      const start = '2026-11-12T23:00:00Z';
      const end = '2026-11-12T23:30:00Z';
      expect(dayOf(start, end), DateTime(2026, 11, 13));
      expect(only(start, end).time, '00:00');
      expect(only(start, end).timeOfDay, 'Matin');
      expect(only(start, end).start, DateTime.parse(start));
    });

    test('23:30Z is 00:30 on the next Tunis day', () {
      const start = '2026-11-12T23:30:00Z';
      const end = '2026-11-13T00:00:00Z';
      expect(dayOf(start, end), DateTime(2026, 11, 13));
      expect(only(start, end).time, '00:30');
      expect(only(start, end).start, DateTime.parse(start));
    });

    test('23:30Z and 08:00Z of the next UTC day share one Tunis day', () {
      final days = groupAvailabilitySlots(const [
        AvailabilitySlotDto(
          start: '2026-11-13T08:00:00Z',
          end: '2026-11-13T08:30:00Z',
        ),
        AvailabilitySlotDto(
          start: '2026-11-12T23:30:00Z',
          end: '2026-11-13T00:00:00Z',
        ),
      ]);
      expect(days.single.date, DateTime(2026, 11, 13));
      expect(days.single.slots.map((s) => s.time), ['00:30', '09:00']);
    });
  });

  group('server instant validation', () {
    test('an instant without UTC offset is a contract failure', () {
      expect(
        () => groupAvailabilitySlots(const [
          AvailabilitySlotDto(
            start: '2026-11-12T08:00:00',
            end: '2026-11-12T08:30:00Z',
          ),
        ]),
        throwsA(isA<DoctorContractException>()),
      );
    });

    test('an explicit +01:00 offset is normalised to the same instant', () {
      final slot = groupAvailabilitySlots(const [
        AvailabilitySlotDto(
          start: '2026-11-12T09:00:00+01:00',
          end: '2026-11-12T09:30:00+01:00',
        ),
      ]).single.slots.single;
      expect(slot.start, DateTime.parse(_serverStart));
      expect(slot.time, '09:00');
    });
  });
}

AppHttpClient _httpClient(HttpClientAdapter adapter) => AppHttpClient(
  tokenStore: SecureTokenStore(backend: _MemoryTokenBackend()),
  baseUrl: 'https://api.test',
  dio: Dio()..httpClientAdapter = adapter,
  refreshDio: Dio(),
);

const _cabinet = PracticeLocation(
  practiceLocationId: 'cabinet-1',
  name: 'Cabinet du Lac',
  address: '10 rue du Lac',
  city: 'Tunis',
  governorate: 'Tunis',
  timezone: doctorSchedulingTimezone,
  primary: true,
);

DoctorDetail _doctorDetail() => const DoctorDetail(
  listItem: DoctorListItem(
    id: 'doctor-1',
    name: 'Dr. Test',
    specialty: 'Médecine générale',
    rating: 0,
    totalReviews: 0,
    officeConsultationFee: 80,
    experienceYears: 10,
    isOnline: false,
    providerId: '',
    acceptingNewPatients: true,
  ),
  practiceLocations: [_cabinet],
  consultationPriceTnd: 80,
);

/// Behaves like the backend for POST /doctor-booking-requests: records the
/// body and echoes the requested slot it received as `originalRequestedSlot`.
class _BookingServerAdapter implements HttpClientAdapter {
  final List<String> postedPaths = [];
  final List<Map<String, dynamic>> postedBodies = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final body = Map<String, dynamic>.from(options.data as Map);
    postedPaths.add(options.path);
    postedBodies.add(body);
    return ResponseBody.fromString(
      jsonEncode(_createdResponse(body)),
      201,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> _createdResponse(Map<String, dynamic> body) => {
  'requestId': body['requestId'],
  'version': 0,
  'status': 'PENDING_DOCTOR',
  'subject': {'subjectType': 'SELF', 'displayName': 'Moi'},
  'doctor': {
    'doctorId': body['doctorId'],
    'displayName': 'Dr. Test',
    'specialty': 'Médecine générale',
  },
  'cabinet': {
    'practiceLocationId': body['practiceLocationId'],
    'name': 'Cabinet du Lac',
    'address': '10 rue du Lac',
    'city': 'Tunis',
    'governorate': 'Tunis',
    'timezone': 'Africa/Tunis',
  },
  'originalRequestedSlot': body['requestedSlot'],
  'createdAt': '2026-11-11T07:00:00Z',
  'responseDeadline': '2026-11-11T19:00:00Z',
  'slotReleased': false,
  'availableActions': const ['CANCEL_REQUEST'],
  'updatedAt': '2026-11-11T07:00:00Z',
};

class _MemoryTokenBackend implements SecureTokenStorageBackend {
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

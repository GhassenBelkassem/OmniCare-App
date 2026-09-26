import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omnicare_mobile/features/patient_doctor/data/doctor_detail_models.dart';
import 'package:omnicare_mobile/features/patient_doctor/data/doctor_directory_api.dart';
import 'package:omnicare_mobile/features/patient_doctor/data/doctor_directory_failure.dart';
import 'package:omnicare_mobile/features/patient_doctor/data/doctor_directory_mapper.dart';
import 'package:omnicare_mobile/features/patient_doctor/data/doctor_directory_models.dart';
import 'package:omnicare_mobile/features/patient_doctor/data/doctor_directory_repository.dart';

const _listItemJson = <String, dynamic>{
  'doctorId': 'doc-1',
  'displayName': 'Dr. Sarah Mansour',
  'specialty': 'Médecin généraliste',
  'photoUrl': null,
  'affiliatedClinicId': null,
  'availableForUrgent': false,
  'consultationPriceTnd': null,
  'phoneNumber': null,
  'isActive': true,
  'experienceYears': 12,
  'distanceKm': null,
};

const _detailJson = <String, dynamic>{
  'doctorId': 'doc-1',
  'displayName': 'Dr. Sarah Mansour',
  'specialty': 'Médecin généraliste',
  'photoUrl': null,
  'affiliatedClinicId': null,
  'availableForUrgent': false,
  'consultationPriceTnd': null,
  'phoneNumber': '+216 98 000 000',
  'isActive': true,
  'experienceYears': 12,
  'distanceKm': null,
  'verified': true,
  'subSpecialties': ['Médecine familiale', 'Prévention'],
  'practiceCity': 'Tunis',
  'languages': ['Français', 'Arabe'],
  'acceptingNewPatients': true,
  'areasOfCare': ['Bilan général', 'Hypertension'],
  'expertise': ['Médecine préventive', 'Coordination des soins'],
  'visitReasons': ['Bilan de santé', 'Suivi de maladie chronique'],
  'patientAgeGroups': ['Adultes', 'Personnes âgées'],
  'consultationTypes': ['En cabinet', 'Téléconsultation'],
  'biography': 'Une brève biographie.',
};

const _appointmentJson = <String, dynamic>{
  'id': 'appt-1',
  'doctorId': 'doc-1',
  'patientId': 'patient-1',
  'patientName': null,
  'startTime': '2026-09-24T15:30:00Z',
  'endTime': '2026-09-24T16:00:00Z',
  'status': 'CONFIRMED',
  'source': 'PATIENT_APP',
  'notes': null,
  'quotedPriceTnd': null,
  'startedAt': null,
  'completedAt': null,
  'createdAt': null,
};

DioException _dio({
  DioExceptionType type = DioExceptionType.badResponse,
  int? statusCode,
}) {
  final requestOptions = RequestOptions(path: '/doctors');
  return DioException(
    requestOptions: requestOptions,
    type: type,
    response: statusCode == null
        ? null
        : Response(
            requestOptions: requestOptions,
            statusCode: statusCode,
            data: const <String, dynamic>{},
          ),
  );
}

DioException _badResponse(int statusCode) => _dio(statusCode: statusCode);

void main() {
  group('DTO parsing — DoctorDirectoryListItem', () {
    test('parses the full contract payload', () {
      final item = DoctorDirectoryListItem.fromJson(_listItemJson);
      expect(item.doctorId, 'doc-1');
      expect(item.displayName, 'Dr. Sarah Mansour');
      expect(item.specialty, 'Médecin généraliste');
      expect(item.availableForUrgent, isFalse);
      expect(item.isActive, isTrue);
      expect(item.experienceYears, 12);
      expect(item.consultationPriceTnd, isNull);
      expect(item.distanceKm, isNull);
    });

    test('accepts a minimal payload', () {
      final item = DoctorDirectoryListItem.fromJson(
        const <String, dynamic>{
          'doctorId': 'doc-2',
          'displayName': 'Dr. Nadia Cherif',
          'availableForUrgent': false,
          'isActive': true,
        },
      );
      expect(item.doctorId, 'doc-2');
      expect(item.specialty, isNull);
    });

    test('rejects a missing required identifier', () {
      expect(
        () => DoctorDirectoryListItem.fromJson(
          const <String, dynamic>{
            'displayName': 'Dr. X',
            'availableForUrgent': false,
            'isActive': true,
          },
        ),
        throwsA(isA<DoctorContractException>()),
      );
    });

    test('rejects a non-boolean availableForUrgent', () {
      expect(
        () => DoctorDirectoryListItem.fromJson(
          const <String, dynamic>{
            'doctorId': 'doc-2',
            'displayName': 'Dr. X',
            'availableForUrgent': 'yes',
            'isActive': true,
          },
        ),
        throwsA(isA<DoctorContractException>()),
      );
    });
  });

  group('DTO parsing — DoctorDirectoryDetail', () {
    test('parses the full contract payload', () {
      final detail = DoctorDirectoryDetail.fromJson(_detailJson);
      expect(detail.doctorId, 'doc-1');
      expect(detail.verified, isTrue);
      expect(detail.experienceYears, 12);
      expect(detail.practiceCity, 'Tunis');
      expect(detail.subSpecialties, ['Médecine familiale', 'Prévention']);
      expect(detail.languages, ['Français', 'Arabe']);
      expect(detail.acceptingNewPatients, isTrue);
      expect(detail.areasOfCare, ['Bilan général', 'Hypertension']);
      expect(detail.expertise, ['Médecine préventive', 'Coordination des soins']);
      expect(detail.visitReasons, ['Bilan de santé', 'Suivi de maladie chronique']);
      expect(detail.patientAgeGroups, ['Adultes', 'Personnes âgées']);
      expect(detail.consultationTypes, ['En cabinet', 'Téléconsultation']);
      expect(detail.biography, 'Une brève biographie.');
    });

    test('defaults acceptingNewPatients to true when absent', () {
      final detail = DoctorDirectoryDetail.fromJson(
        const <String, dynamic>{
          'doctorId': 'doc-1',
          'displayName': 'Dr. X',
          'availableForUrgent': false,
          'isActive': true,
          'verified': false,
        },
      );
      expect(detail.acceptingNewPatients, isTrue);
    });

    test('acceptingNewPatients false is honored', () {
      final detail = DoctorDirectoryDetail.fromJson(
        const <String, dynamic>{
          'doctorId': 'doc-1',
          'displayName': 'Dr. X',
          'availableForUrgent': false,
          'isActive': true,
          'verified': false,
          'acceptingNewPatients': false,
        },
      );
      expect(detail.acceptingNewPatients, isFalse);
    });

    test('rejects a string list carrying a non-string element', () {
      expect(
        () => DoctorDirectoryDetail.fromJson(
          const <String, dynamic>{
            'doctorId': 'doc-1',
            'displayName': 'Dr. X',
            'availableForUrgent': false,
            'isActive': true,
            'verified': false,
            'subSpecialties': ['ok', 42],
          },
        ),
        throwsA(isA<DoctorContractException>()),
      );
    });
  });

  group('DTO parsing — slots and booking', () {
    test('parses an availability slot', () {
      final slot = AvailabilitySlotDto.fromJson(
        const <String, dynamic>{
          'start': '2026-09-24T09:00:00Z',
          'end': '2026-09-24T09:30:00Z',
        },
      );
      expect(slot.start, '2026-09-24T09:00:00Z');
      expect(slot.end, '2026-09-24T09:30:00Z');
    });

    test('rejects a slot missing its window', () {
      expect(
        () => AvailabilitySlotDto.fromJson(
          const <String, dynamic>{'end': '2026-09-24T09:30:00Z'},
        ),
        throwsA(isA<DoctorContractException>()),
      );
    });

    test('parses an appointment response', () {
      final booking = AppointmentBooking.fromJson(_appointmentJson);
      expect(booking.id, 'appt-1');
      expect(booking.doctorId, 'doc-1');
      expect(booking.patientId, 'patient-1');
      expect(booking.status, 'CONFIRMED');
      expect(booking.source, 'PATIENT_APP');
      expect(booking.startTime, '2026-09-24T15:30:00Z');
      expect(booking.endTime, '2026-09-24T16:00:00Z');
    });

    test('rejects an appointment response missing its id', () {
      final json = Map<String, dynamic>.from(_appointmentJson)..remove('id');
      expect(
        () => AppointmentBooking.fromJson(json),
        throwsA(isA<DoctorContractException>()),
      );
    });
  });

  group('Mapper', () {
    test('maps a list DTO onto DoctorListItem', () {
      final item = toDoctorListItem(
        DoctorDirectoryListItem.fromJson(_listItemJson),
      );
      expect(item.id, 'doc-1');
      expect(item.name, 'Dr. Sarah Mansour');
      expect(item.specialty, 'Médecin généraliste');
      expect(item.experienceYears, 12);
      expect(item.officeConsultationFee, 0.0);
      expect(item.acceptingNewPatients, isTrue);
      expect(item.imageAssetPath, isNull);
    });

    test('builds DoctorDetail from the detail DTO', () {
      final detail = buildDoctorDetail(
        DoctorDirectoryDetail.fromJson(_detailJson),
      );
      expect(detail.id, 'doc-1');
      expect(detail.name, 'Dr. Sarah Mansour');
      expect(detail.verified, isTrue);
      expect(detail.experienceYears, 12);
      expect(detail.languages, ['Français', 'Arabe']);
      expect(detail.areasOfCare, ['Bilan général', 'Hypertension']);
      expect(detail.consultationTypes, ['En cabinet', 'Téléconsultation']);
      expect(detail.practiceLocations, isNotEmpty);
      expect(detail.practiceLocations.single.city, 'Tunis');
    });

    test('practice locations are empty when practiceCity is absent', () {
      final json = Map<String, dynamic>.from(_detailJson)
        ..['practiceCity'] = null;
      final detail = buildDoctorDetail(
        DoctorDirectoryDetail.fromJson(json),
      );
      expect(detail.practiceLocations, isEmpty);
    });

    group('groupAvailabilitySlots', () {
      test('groups slots by date and period, sorted', () {
        final slots = [
          _slotUtc(DateTime(2026, 9, 24, 14, 30)),
          _slotUtc(DateTime(2026, 9, 24, 9, 0)),
          _slotUtc(DateTime(2026, 9, 25, 10, 0)),
        ];
        final days = groupAvailabilitySlots(slots);

        expect(days, hasLength(2));
        expect(days.first.slots, hasLength(2));
        expect(days.first.slots.first.time, '09:00');
        expect(days.first.slots.map((s) => s.timeOfDay).toSet(), {
          'Matin',
          'Après-midi',
        });
        expect(days.last.slots.single.timeOfDay, 'Matin');
      });

      test('evening slots are mapped to Soir', () {
        final days = groupAvailabilitySlots([_slotUtc(DateTime(2026, 9, 24, 19, 0))]);
        expect(days.single.slots.single.timeOfDay, 'Soir');
      });

      test('throws on an unparseable instant', () {
        expect(
          () => groupAvailabilitySlots(
            const [
              AvailabilitySlotDto(start: 'nope', end: '2026-09-24T09:30:00Z'),
            ],
          ),
          throwsA(isA<DoctorContractException>()),
        );
      });
    });

    group('nextAvailableLabelFor', () {
      test('today label uses Aujourd\'hui', () {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final days = [
          _day(today, ['09:30', '10:00'], ['Matin', 'Matin']),
        ];
        expect(nextAvailableLabelFor(days), 'Aujourd\'hui · 09:30');
      });

      test('tomorrow label uses Demain', () {
        final now = DateTime.now();
        final tomorrow = DateTime(now.year, now.month, now.day + 1);
        final days = [
          _day(tomorrow, ['10:00'], ['Matin']),
        ];
        expect(nextAvailableLabelFor(days), 'Demain · 10:00');
      });

      test('later days use the French weekday name', () {
        final now = DateTime.now();
        final later = DateTime(now.year, now.month, now.day + 4);
        const names = [
          'Lundi',
          'Mardi',
          'Mercredi',
          'Jeudi',
          'Vendredi',
          'Samedi',
          'Dimanche',
        ];
        final expectedDay = names[later.weekday - 1];
        final days = [
          _day(later, ['14:00'], ['Après-midi']),
        ];
        expect(nextAvailableLabelFor(days), '$expectedDay · 14:00');
      });

      test('returns null when there is no availability', () {
        expect(nextAvailableLabelFor(const []), isNull);
      });
    });
  });

  group('Failure mapping', () {
    test('401 maps to sessionExpired', () {
      final failure = DoctorDirectoryFailure.from(_badResponse(401));
      expect(failure.kind, DoctorDirectoryFailureKind.sessionExpired);
    });

    test('404 maps to notFound and reports it', () {
      final failure = DoctorDirectoryFailure.from(_badResponse(404));
      expect(failure.kind, DoctorDirectoryFailureKind.notFound);
      expect(failure.isNotFound, isTrue);
    });

    test('500 maps to server', () {
      final failure = DoctorDirectoryFailure.from(_badResponse(500));
      expect(failure.kind, DoctorDirectoryFailureKind.server);
    });

    test('bad response 422 maps to contract', () {
      final failure = DoctorDirectoryFailure.from(_badResponse(422));
      expect(failure.kind, DoctorDirectoryFailureKind.contract);
    });

    test('connection error maps to network', () {
      final failure = DoctorDirectoryFailure.from(
        _dio(type: DioExceptionType.connectionError),
      );
      expect(failure.kind, DoctorDirectoryFailureKind.network);
    });

    test('timeout maps to timeout', () {
      final failure = DoctorDirectoryFailure.from(
        _dio(type: DioExceptionType.receiveTimeout),
      );
      expect(failure.kind, DoctorDirectoryFailureKind.timeout);
    });

    test('contract exception maps to invalid response', () {
      final failure = DoctorDirectoryFailure.from(
        const DoctorContractException('broken'),
      );
      expect(failure.kind, DoctorDirectoryFailureKind.contract);
    });

    test('unknown errors map to unexpected', () {
      final failure = DoctorDirectoryFailure.from(Exception('boom'));
      expect(failure.kind, DoctorDirectoryFailureKind.unexpected);
    });

    test('never leaks backend detail strings', () {
      final failure = DoctorDirectoryFailure.from(_badResponse(500));
      expect(failure.message, isNot(contains('detail')));
      expect(failure.message, isNot(contains('traceId')));
      expect(
        DoctorDirectoryFailure.from(
          _dio(type: DioExceptionType.connectionError),
        ).message,
        isNot(contains('SocketException')),
      );
    });
  });

  group('Repository', () {
    test('list, detail and slots failures become DoctorDirectoryFailure', () async {
      final api = _FakeApi(
        listError: _badResponse(401),
        detailError: _badResponse(404),
        slotsError: _dio(type: DioExceptionType.connectionError),
      );
      final repository = DoctorDirectoryRepository(api);

      await expectLater(
        repository.listDoctors(),
        throwsA(
          isA<DoctorDirectoryFailure>().having(
            (f) => f.kind,
            'kind',
            DoctorDirectoryFailureKind.sessionExpired,
          ),
        ),
      );
      await expectLater(
        repository.getDoctor('doc-1'),
        throwsA(
          isA<DoctorDirectoryFailure>().having((f) => f.isNotFound, 'notFound', true),
        ),
      );
      await expectLater(
        repository.getSlots(
          doctorId: 'doc-1',
          from: DateTime.now(),
          to: DateTime.now().add(const Duration(days: 1)),
        ),
        throwsA(
          isA<DoctorDirectoryFailure>().having(
            (f) => f.kind,
            'kind',
            DoctorDirectoryFailureKind.network,
          ),
        ),
      );
    });

    test('successful booking returns a success result', () async {
      final booking = AppointmentBooking.fromJson(_appointmentJson);
      final repository = DoctorDirectoryRepository(
        _FakeApi(bookingResult: booking),
      );

      final result = await repository.bookAppointment(
        doctorId: 'doc-1',
        startTime: '2026-09-24T15:30:00Z',
        endTime: '2026-09-24T16:00:00Z',
      );

      expect(result.succeeded, isTrue);
      expect(result.booking?.id, 'appt-1');
    });

    test('409 becomes a conflict result, not a failure', () async {
      final repository = DoctorDirectoryRepository(
        _FakeApi(bookingError: _badResponse(409)),
      );

      final result = await repository.bookAppointment(
        doctorId: 'doc-1',
        startTime: '2026-09-24T15:30:00Z',
        endTime: '2026-09-24T16:00:00Z',
      );

      expect(result.isConflict, isTrue);
      expect(result.failure, isNull);
      expect(result.conflictMessage, contains('réservé'));
    });

    test('non-conflict booking failure maps to a failure result', () async {
      final repository = DoctorDirectoryRepository(
        _FakeApi(bookingError: _dio(type: DioExceptionType.connectionError)),
      );

      final result = await repository.bookAppointment(
        doctorId: 'doc-1',
        startTime: '2026-09-24T15:30:00Z',
        endTime: '2026-09-24T16:00:00Z',
      );

      expect(result.status, DoctorBookingStatus.failure);
      expect(result.failure?.kind, DoctorDirectoryFailureKind.network);
    });
  });
}

AvailabilitySlotDto _slotUtc(DateTime local) {
  final start = local;
  final end = start.add(const Duration(minutes: 30));
  return AvailabilitySlotDto(
    start: start.toUtc().toIso8601String(),
    end: end.toUtc().toIso8601String(),
  );
}

DoctorDayAvailability _day(DateTime date, List<String> times, List<String> periods) {
  assert(times.length == periods.length);
  return DoctorDayAvailability(
    date: DateTime(date.year, date.month, date.day),
    slots: List.unmodifiable([
      for (var i = 0; i < times.length; i++)
        DoctorAvailabilitySlot(
          time: times[i],
          timeOfDay: periods[i],
          startIso: '2026-09-24T${times[i]}:00Z',
          endIso: '2026-09-24T${times[i]}:30Z',
          start: DateTime(date.year, date.month, date.day, 9),
          end: DateTime(date.year, date.month, date.day, 9, 30),
        ),
    ]),
  );
}

class _FakeApi implements DoctorDirectoryApi {
  _FakeApi({
    this.listError,
    this.detailError,
    this.slotsError,
    this.bookingError,
    this.bookingResult,
  });

  final Object? listError;
  final Object? detailError;
  final Object? slotsError;
  final Object? bookingError;
  final AppointmentBooking? bookingResult;

  @override
  Future<List<DoctorDirectoryListItem>> listDoctors({
    String? query,
    CancelToken? cancelToken,
  }) async {
    final error = listError;
    if (error != null) throw error;
    return const [];
  }

  @override
  Future<DoctorDirectoryDetail> getDoctor(
    String doctorId, {
    CancelToken? cancelToken,
  }) async {
    final error = detailError;
    if (error != null) throw error;
    return DoctorDirectoryDetail.fromJson(_detailJson);
  }

  @override
  Future<List<AvailabilitySlotDto>> getSlots({
    required String doctorId,
    required DateTime from,
    required DateTime to,
    CancelToken? cancelToken,
  }) async {
    final error = slotsError;
    if (error != null) throw error;
    return const [];
  }

  @override
  Future<AppointmentBooking> bookAppointment({
    required String doctorId,
    required String startTime,
    required String endTime,
    String? notes,
    CancelToken? cancelToken,
  }) async {
    final error = bookingError;
    if (error != null) throw error;
    return bookingResult!;
  }
}
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:omnicare_mobile/core/theme/omni_theme.dart';
import 'package:omnicare_mobile/core/network/app_http_client.dart';
import 'package:omnicare_mobile/core/storage/secure_token_store.dart';
import 'package:omnicare_mobile/features/patient_doctor/application/doctor_directory_controller.dart';
import 'package:omnicare_mobile/features/patient_doctor/data/doctor_detail_models.dart';
import 'package:omnicare_mobile/features/patient_doctor/data/doctor_directory_models.dart';
import 'package:omnicare_mobile/features/patient_doctor/data/doctor_directory_api.dart';
import 'package:omnicare_mobile/features/patient_doctor/data/doctor_directory_repository.dart';
import 'package:omnicare_mobile/features/patient_doctor/data/doctor_models.dart';
import 'package:omnicare_mobile/features/scheduled_care/application/patient_booking_controller.dart';
import 'package:omnicare_mobile/features/scheduled_care/data/scheduled_care_api.dart';
import 'package:omnicare_mobile/features/scheduled_care/data/scheduled_care_failure.dart';
import 'package:omnicare_mobile/features/scheduled_care/data/scheduled_care_repository.dart';
import 'package:omnicare_mobile/features/scheduled_care/domain/scheduled_care_models.dart';
import 'package:omnicare_mobile/features/scheduled_care/presentation/booking_review_screen.dart';
import 'package:omnicare_mobile/features/scheduled_care/presentation/pending_booking_request_screen.dart';

void main() {
  group('subject and creation contract', () {
    test('SELF omits familyMemberId', () {
      expect(const CareSubject.self().toCreateJson(), {'subjectType': 'SELF'});
    });

    test('FAMILY_MEMBER sends only the exact family member id', () {
      expect(
        CareSubject.familyMember(
          familyMemberId: 'family-123',
          displayName: 'Private name',
        ).toCreateJson(),
        {'subjectType': 'FAMILY_MEMBER', 'familyMemberId': 'family-123'},
      );
    });

    test('command preserves request, Cabinet and slot identity', () {
      final command = CreateBookingRequestCommand(
        requestId: 'request-1',
        doctorId: 'doctor-1',
        practiceLocationId: 'cabinet-1',
        subject: CareSubject.familyMember(familyMemberId: 'family-1'),
        requestedSlot: RequestedSlot(
          start: DateTime.parse('2026-11-12T08:00:00Z'),
          end: DateTime.parse('2026-11-12T08:30:00Z'),
          durationMinutes: 30,
        ),
      );
      expect(command.toJson(), {
        'requestId': 'request-1',
        'doctorId': 'doctor-1',
        'practiceLocationId': 'cabinet-1',
        'subject': {
          'subjectType': 'FAMILY_MEMBER',
          'familyMemberId': 'family-1',
        },
        'requestedSlot': {
          'start': '2026-11-12T08:00:00.000Z',
          'end': '2026-11-12T08:30:00.000Z',
        },
      });
    });
  });

  group('Africa/Tunis displayed-month ranges', () {
    test('current month begins at the current instant', () {
      final now = DateTime.parse('2026-10-11T12:15:00Z');
      final range = availabilityRangeForMonth(DateTime(2026, 10), now: now);
      expect(range.from, now);
      expect(range.to, DateTime.parse('2026-10-31T23:00:00Z'));
      expect(
        range.to.difference(range.from),
        lessThan(const Duration(days: 31)),
      );
    });

    test('future month uses Tunis boundaries and stays within 31 days', () {
      final range = availabilityRangeForMonth(
        DateTime(2026, 12),
        now: DateTime.parse('2026-10-11T12:15:00Z'),
      );
      expect(range.from, DateTime.parse('2026-11-30T23:00:00Z'));
      expect(range.to, DateTime.parse('2026-12-31T23:00:00Z'));
      expect(range.to.difference(range.from), const Duration(days: 31));
    });
  });

  group('availability transport', () {
    test(
      'always sends doctorId, practiceLocationId and absolute range',
      () async {
        final adapter = _RecordingAdapter(
          responseBody: jsonEncode({
            'doctorId': 'doctor-1',
            'practiceLocationId': 'cabinet-1',
            'timezone': 'Africa/Tunis',
            'generatedAt': '2026-10-11T12:00:00Z',
            'slots': const [],
          }),
        );
        final dio = Dio()..httpClientAdapter = adapter;
        final client = AppHttpClient(
          tokenStore: SecureTokenStore(backend: _MemoryTokenBackend()),
          baseUrl: 'https://api.test',
          dio: dio,
          refreshDio: Dio(),
        );
        await DoctorDirectoryApi(client).getSlots(
          doctorId: 'doctor-1',
          practiceLocationId: 'cabinet-1',
          from: DateTime.parse('2026-10-11T12:00:00Z'),
          to: DateTime.parse('2026-10-31T23:00:00Z'),
        );
        expect(adapter.path, '/appointments/availability/slots');
        expect(adapter.query, {
          'doctorId': 'doctor-1',
          'practiceLocationId': 'cabinet-1',
          'from': '2026-10-11T12:00:00.000Z',
          'to': '2026-10-31T23:00:00.000Z',
        });
      },
    );
  });

  group('ProblemDetail mapping', () {
    for (final entry in const {
      'VALIDATION_FAILED': ScheduledCareFailureKind.validation,
      'SUBJECT_NOT_AVAILABLE': ScheduledCareFailureKind.subjectUnavailable,
      'BOOKING_CONTEXT_NOT_AVAILABLE':
          ScheduledCareFailureKind.bookingContextUnavailable,
      'SLOT_NO_LONGER_AVAILABLE':
          ScheduledCareFailureKind.slotNoLongerAvailable,
      'IDEMPOTENCY_CONFLICT': ScheduledCareFailureKind.idempotencyConflict,
    }.entries) {
      test('${entry.key} is actionable without leaking backend detail', () {
        final options = RequestOptions(path: '/doctor-booking-requests');
        final failure = ScheduledCareFailure.from(
          DioException(
            requestOptions: options,
            type: DioExceptionType.badResponse,
            response: Response(
              requestOptions: options,
              statusCode: entry.key == 'VALIDATION_FAILED' ? 422 : 409,
              data: {
                'errorCode': entry.key,
                'detail': 'PRIVATE_BACKEND_DETAIL',
              },
            ),
          ),
        );
        expect(failure.kind, entry.value);
        expect(failure.message, isNot(contains('PRIVATE_BACKEND_DETAIL')));
      });
    }

    test('legacy 401 and 403 shapes remain supported', () {
      expect(
        ScheduledCareFailure.from(_httpFailure(401)).kind,
        ScheduledCareFailureKind.unauthenticated,
      );
      expect(
        ScheduledCareFailure.from(_httpFailure(403)).kind,
        ScheduledCareFailureKind.forbidden,
      );
    });
  });

  group('unknown-outcome reconciliation', () {
    test('GET result wins after an unknown POST outcome', () async {
      final api = _ScriptedApi(
        createResults: [_connectionFailure()],
        getResults: [_detail()],
      );
      final repository = ScheduledCareRepository(api);
      final result = await repository.createOrReconcile(_command());
      expect(result.requestId, 'request-1');
      expect(api.createIds, ['request-1']);
      expect(api.getIds, ['request-1']);
    });

    test('404 reconciliation replays the exact same requestId', () async {
      final api = _ScriptedApi(
        createResults: [_connectionFailure(), _detail()],
        getResults: [_httpFailure(404)],
      );
      await ScheduledCareRepository(api).createOrReconcile(_command());
      expect(api.createIds, ['request-1', 'request-1']);
      expect(identical(api.commands[0], api.commands[1]), isTrue);
      expect(api.commands[0].toJson(), api.commands[1].toJson());
    });

    for (final status in [401, 403]) {
      test('$status reconciliation response never permits replay', () async {
        final api = _ScriptedApi(
          createResults: [_connectionFailure()],
          getResults: [_httpFailure(status)],
        );

        await expectLater(
          ScheduledCareRepository(api).createOrReconcile(_command()),
          throwsA(
            isA<ScheduledCareFailure>().having(
              (failure) => failure.kind,
              'kind',
              status == 401
                  ? ScheduledCareFailureKind.unauthenticated
                  : ScheduledCareFailureKind.forbidden,
            ),
          ),
        );
        expect(api.createIds, ['request-1']);
        expect(api.getIds, ['request-1']);
      });
    }

    test('malformed reconciliation response never permits replay', () async {
      final api = _ScriptedApi(
        createResults: [_connectionFailure()],
        getResults: [const ScheduledCareContractException('Malformed detail.')],
      );

      await expectLater(
        ScheduledCareRepository(api).createOrReconcile(_command()),
        throwsA(
          isA<ScheduledCareFailure>().having(
            (failure) => failure.kind,
            'kind',
            ScheduledCareFailureKind.contract,
          ),
        ),
      );
      expect(api.createIds, ['request-1']);
    });

    test(
      'network failure during reconciliation never permits replay',
      () async {
        final api = _ScriptedApi(
          createResults: [_connectionFailure()],
          getResults: [_connectionFailure()],
        );

        await expectLater(
          ScheduledCareRepository(api).createOrReconcile(_command()),
          throwsA(
            isA<ScheduledCareFailure>().having(
              (failure) => failure.kind,
              'kind',
              ScheduledCareFailureKind.unknownOutcome,
            ),
          ),
        );
        expect(api.createIds, ['request-1']);
      },
    );

    test('authoritative 404 allows only one replay attempt', () async {
      final api = _ScriptedApi(
        createResults: [_connectionFailure(), _httpFailure(500)],
        getResults: [_httpFailure(404)],
      );

      await expectLater(
        ScheduledCareRepository(api).createOrReconcile(_command()),
        throwsA(
          isA<ScheduledCareFailure>().having(
            (failure) => failure.kind,
            'kind',
            ScheduledCareFailureKind.server,
          ),
        ),
      );
      expect(api.createIds, ['request-1', 'request-1']);
      expect(api.getIds, ['request-1']);
    });
  });

  group('booking controller continuity', () {
    test(
      'retains stable requestId for retry and exact semantic intent',
      () async {
        final repository = _RecordingScheduledRepository(
          failures: [
            const ScheduledCareFailure(
              kind: ScheduledCareFailureKind.unknownOutcome,
              message: 'unknown',
              diagnosticCode: 'UNKNOWN',
              retryable: true,
            ),
          ],
        );
        final controller = PatientBookingController(
          repository: repository,
          requestIdFactory: () => 'stable-request-id',
        );
        controller.selectSubject(
          CareSubject.familyMember(familyMemberId: 'family-1'),
        );
        controller.prepareIntent(
          doctor: _doctorDetail(),
          cabinet: _cabinet,
          slot: _slot,
        );
        await controller.submit();
        await controller.submit();
        expect(repository.commands.map((value) => value.requestId), [
          'stable-request-id',
          'stable-request-id',
        ]);
        expect(repository.commands.last.practiceLocationId, 'cabinet-1');
        expect(repository.commands.last.subject.familyMemberId, 'family-1');
      },
    );

    test('semantic intent changes mint a new requestId', () {
      var sequence = 0;
      final controller = PatientBookingController(
        repository: _RecordingScheduledRepository(),
        requestIdFactory: () => 'request-${++sequence}',
      );

      controller.prepareIntent(
        doctor: _doctorDetail(),
        cabinet: _cabinet,
        slot: _slot,
      );
      expect(controller.intent!.requestId, 'request-1');

      controller.prepareIntent(
        doctor: _doctorDetail(),
        cabinet: _cabinet,
        slot: _slot,
      );
      expect(controller.intent!.requestId, 'request-1');

      controller.prepareIntent(
        doctor: _doctorDetail(id: 'doctor-2'),
        cabinet: _cabinet,
        slot: _slot,
      );
      expect(controller.intent!.requestId, 'request-2');

      controller.prepareIntent(
        doctor: _doctorDetail(id: 'doctor-2'),
        cabinet: _secondCabinet,
        slot: _slot,
      );
      expect(controller.intent!.requestId, 'request-3');

      controller.selectSubject(
        CareSubject.familyMember(familyMemberId: 'family-1'),
      );
      controller.prepareIntent(
        doctor: _doctorDetail(id: 'doctor-2'),
        cabinet: _secondCabinet,
        slot: _slot,
      );
      expect(controller.intent!.requestId, 'request-4');

      controller.selectSubject(
        CareSubject.familyMember(familyMemberId: 'family-2'),
      );
      controller.prepareIntent(
        doctor: _doctorDetail(id: 'doctor-2'),
        cabinet: _secondCabinet,
        slot: _slot,
      );
      expect(controller.intent!.requestId, 'request-5');

      controller.prepareIntent(
        doctor: _doctorDetail(id: 'doctor-2'),
        cabinet: _secondCabinet,
        slot: _secondSlot,
      );
      expect(controller.intent!.requestId, 'request-6');
    });

    test(
      'logout clear prevents a prior-session result from repopulating state',
      () async {
        final repository = _DelayedScheduledRepository();
        final controller = PatientBookingController(
          repository: repository,
          requestIdFactory: () => 'session-request',
        );
        controller.selectSubject(
          CareSubject.familyMember(
            familyMemberId: 'family-1',
            displayName: 'Private patient',
          ),
        );
        controller.prepareIntent(
          doctor: _doctorDetail(),
          cabinet: _cabinet,
          slot: _slot,
        );

        final submission = controller.submit();
        expect(controller.status, PatientBookingStatus.submitting);
        controller.clear();
        expect(controller.status, PatientBookingStatus.idle);
        expect(controller.subject.subjectType, CareSubjectType.self);
        expect(controller.subject.familyMemberId, isNull);
        expect(controller.intent, isNull);
        expect(controller.result, isNull);

        repository.complete(_detail());
        await submission;
        expect(controller.status, PatientBookingStatus.idle);
        expect(controller.intent, isNull);
        expect(controller.result, isNull);
        expect(controller.failure, isNull);
      },
    );

    test('creation response cannot silently change Cabinet timezone', () async {
      final controller = PatientBookingController(
        repository: _RecordingScheduledRepository(
          results: [_detail(timezone: 'Europe/Paris')],
        ),
        requestIdFactory: () => 'request-1',
      );
      controller.prepareIntent(
        doctor: _doctorDetail(),
        cabinet: _cabinet,
        slot: _slot,
      );

      await controller.submit();

      expect(controller.result, isNull);
      expect(controller.failure?.kind, ScheduledCareFailureKind.contract);
    });
  });

  group('availability Cabinet continuity and stale protection', () {
    test('older month response cannot replace the active month', () async {
      final repository = _RacingDoctorRepository();
      final controller = DoctorDirectoryController(repository: repository);

      final initial = controller.fetchDetail('doctor-1');
      await Future<void>.delayed(Duration.zero);
      repository.completeNext(_availability(const []));
      await initial;

      final october = controller.fetchAvailabilityForMonth(
        DateTime(2026, 10),
        now: DateTime.parse('2026-10-01T08:00:00Z'),
      );
      final november = controller.fetchAvailabilityForMonth(
        DateTime(2026, 11),
        now: DateTime.parse('2026-10-01T08:00:00Z'),
      );
      await Future<void>.delayed(Duration.zero);
      repository.completeAt(2, _availability([_novemberSlot]));
      await november;
      repository.completeAt(1, _availability([_octoberSlot]));
      await october;

      expect(controller.availabilityMonth, DateTime(2026, 11));
      expect(controller.detail!.availability.single.date.month, 11);
      expect(repository.practiceLocationIds, everyElement('cabinet-1'));
    });
  });

  group('presentation and direct-booking cutover', () {
    testWidgets(
      'successful creation presents pending request, not confirmation',
      (tester) async {
        final booking =
            PatientBookingController(
              repository: _RecordingScheduledRepository(),
              requestIdFactory: () => 'request-1',
            )..prepareIntent(
              doctor: _doctorDetail(),
              cabinet: _cabinet,
              slot: _slot,
            );
        final directory = DoctorDirectoryController(
          repository: _RacingDoctorRepository(),
        );
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: booking),
              ChangeNotifierProvider.value(value: directory),
            ],
            child: MaterialApp(
              theme: buildOmniTheme(),
              home: const BookingReviewScreen(),
            ),
          ),
        );
        await tester.tap(find.text('Envoyer la demande'));
        await tester.pumpAndSettle();
        expect(find.byType(PendingBookingRequestScreen), findsOneWidget);
        expect(
          find.text('En attente de la réponse du médecin'),
          findsOneWidget,
        );
        expect(find.text('Rendez-vous confirmé'), findsNothing);
      },
    );

    test('normal patient flow has no direct Appointment call', () {
      final source = File(
        'lib/features/patient_doctor/presentation/doctor_availability_sheet.dart',
      ).readAsStringSync();
      expect(source, isNot(contains('bookSlot(')));
      expect(source, isNot(contains("'/appointments'")));
      expect(ScheduledCareApi.bookingRequestsPath, '/doctor-booking-requests');
    });
  });
}

const _cabinet = PracticeLocation(
  practiceLocationId: 'cabinet-1',
  name: 'Cabinet du Lac',
  address: '10 rue du Lac',
  city: 'Tunis',
  governorate: 'Tunis',
  timezone: doctorSchedulingTimezone,
  primary: true,
);

const _secondCabinet = PracticeLocation(
  practiceLocationId: 'cabinet-2',
  name: 'Cabinet Centre',
  address: '20 avenue du Centre',
  city: 'Tunis',
  governorate: 'Tunis',
  timezone: doctorSchedulingTimezone,
);

final _slot = DoctorAvailabilitySlot(
  time: '09:00',
  timeOfDay: 'Matin',
  startIso: '2026-11-12T08:00:00Z',
  endIso: '2026-11-12T08:30:00Z',
  start: DateTime.parse('2026-11-12T08:00:00Z'),
  end: DateTime.parse('2026-11-12T08:30:00Z'),
  durationMinutes: 30,
);

final _secondSlot = DoctorAvailabilitySlot(
  time: '10:00',
  timeOfDay: 'Matin',
  startIso: '2026-11-12T09:00:00Z',
  endIso: '2026-11-12T09:30:00Z',
  start: DateTime.parse('2026-11-12T09:00:00Z'),
  end: DateTime.parse('2026-11-12T09:30:00Z'),
  durationMinutes: 30,
);

DoctorDetail _doctorDetail({String id = 'doctor-1'}) => DoctorDetail(
  listItem: DoctorListItem(
    id: id,
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
  practiceLocations: const [_cabinet],
  consultationPriceTnd: 80,
);

CreateBookingRequestCommand _command() => CreateBookingRequestCommand(
  requestId: 'request-1',
  doctorId: 'doctor-1',
  practiceLocationId: 'cabinet-1',
  subject: const CareSubject.self(),
  requestedSlot: RequestedSlot(
    start: DateTime.parse('2026-11-12T08:00:00Z'),
    end: DateTime.parse('2026-11-12T08:30:00Z'),
    durationMinutes: 30,
  ),
);

PatientBookingRequestDetail _detail({String timezone = 'Africa/Tunis'}) =>
    PatientBookingRequestDetail(
      requestId: 'request-1',
      version: 0,
      status: BookingRequestStatus.pendingDoctor,
      rawStatus: 'PENDING_DOCTOR',
      subject: const CareSubject.self(displayName: 'Moi'),
      doctor: const DoctorProjection(
        doctorId: 'doctor-1',
        displayName: 'Dr. Test',
        specialty: 'Médecine générale',
      ),
      cabinet: BookingCabinetProjection(
        practiceLocationId: 'cabinet-1',
        name: 'Cabinet du Lac',
        address: '10 rue du Lac',
        city: 'Tunis',
        governorate: 'Tunis',
        timezone: timezone,
      ),
      originalRequestedSlot: RequestedSlot(
        start: DateTime.parse('2026-11-12T08:00:00Z'),
        end: DateTime.parse('2026-11-12T08:30:00Z'),
        durationMinutes: 30,
      ),
      activeSlot: ActiveSlot(
        start: DateTime.parse('2026-11-12T08:00:00Z'),
        end: DateTime.parse('2026-11-12T08:30:00Z'),
        durationMinutes: 30,
      ),
      priceQuote: PriceQuote(
        amount: 80,
        currency: 'TND',
        quotedAt: DateTime.parse('2026-10-11T12:00:00Z'),
      ),
      createdAt: DateTime.parse('2026-10-11T12:00:00Z'),
      responseDeadline: DateTime.parse('2026-10-12T12:00:00Z'),
      slotReleased: false,
      availableActions: const [AvailableAction.cancelRequest],
      updatedAt: DateTime.parse('2026-10-11T12:00:00Z'),
    );

class _RecordingScheduledRepository implements ScheduledCareRepositoryContract {
  _RecordingScheduledRepository({
    List<ScheduledCareFailure>? failures,
    List<PatientBookingRequestDetail>? results,
  }) : failures = [...?failures],
       results = [...?results];

  final List<ScheduledCareFailure> failures;
  final List<PatientBookingRequestDetail> results;
  final List<CreateBookingRequestCommand> commands = [];

  @override
  Future<PatientBookingRequestDetail> createOrReconcile(
    CreateBookingRequestCommand command, {
    CancelToken? cancelToken,
  }) async {
    commands.add(command);
    if (failures.isNotEmpty) throw failures.removeAt(0);
    if (results.isNotEmpty) return results.removeAt(0);
    return _detail();
  }
}

class _DelayedScheduledRepository implements ScheduledCareRepositoryContract {
  final Completer<PatientBookingRequestDetail> _result = Completer();

  void complete(PatientBookingRequestDetail detail) => _result.complete(detail);

  @override
  Future<PatientBookingRequestDetail> createOrReconcile(
    CreateBookingRequestCommand command, {
    CancelToken? cancelToken,
  }) => _result.future;
}

class _ScriptedApi implements ScheduledCareApi {
  _ScriptedApi({required this.createResults, required this.getResults});

  final List<Object> createResults;
  final List<Object> getResults;
  final List<String> createIds = [];
  final List<String> getIds = [];
  final List<CreateBookingRequestCommand> commands = [];

  @override
  Future<PatientBookingRequestDetail> createBookingRequest(
    CreateBookingRequestCommand command, {
    CancelToken? cancelToken,
  }) async {
    createIds.add(command.requestId);
    commands.add(command);
    final result = createResults.removeAt(0);
    if (result is Exception) throw result;
    return result as PatientBookingRequestDetail;
  }

  @override
  Future<PatientBookingRequestDetail> getBookingRequest(
    String requestId, {
    CancelToken? cancelToken,
  }) async {
    getIds.add(requestId);
    final result = getResults.removeAt(0);
    if (result is Exception) throw result;
    return result as PatientBookingRequestDetail;
  }

  @override
  Future<PatientBookingRequestDetail> cancelBookingRequest(
    CancelBookingRequestCommand command, {
    CancelToken? cancelToken,
  }) => throw UnimplementedError();

  @override
  Future<ProposalAcceptanceResult> acceptProposal(
    AcceptBookingProposalCommand command, {
    CancelToken? cancelToken,
  }) => throw UnimplementedError();

  @override
  Future<PatientBookingRequestDetail> declineProposal(
    DeclineBookingProposalCommand command, {
    CancelToken? cancelToken,
  }) => throw UnimplementedError();

  @override
  Future<ConfirmedScheduledAppointment> getAppointment(
    String appointmentId, {
    CancelToken? cancelToken,
  }) => throw UnimplementedError();
}

DioException _connectionFailure() => DioException(
  requestOptions: RequestOptions(path: '/doctor-booking-requests'),
  type: DioExceptionType.connectionError,
);

DioException _httpFailure(int status) {
  final options = RequestOptions(path: '/doctor-booking-requests/request-1');
  return DioException(
    requestOptions: options,
    type: DioExceptionType.badResponse,
    response: Response(requestOptions: options, statusCode: status),
  );
}

class _RacingDoctorRepository implements DoctorDirectoryRepository {
  final List<Completer<AvailabilitySlotsDto>> _pending = [];
  final List<String> practiceLocationIds = [];

  void completeNext(AvailabilitySlotsDto value) =>
      _pending.first.complete(value);
  void completeAt(int index, AvailabilitySlotsDto value) =>
      _pending[index].complete(value);

  @override
  Future<List<DoctorDirectoryListItem>> listDoctors({
    String? query,
    CancelToken? cancelToken,
  }) async => const [];

  @override
  Future<DoctorDirectoryDetail> getDoctor(
    String doctorId, {
    CancelToken? cancelToken,
  }) async => const DoctorDirectoryDetail(
    doctorId: 'doctor-1',
    displayName: 'Dr. Test',
    specialty: 'Médecine générale',
    verified: true,
    practiceLocations: [
      DoctorPracticeLocationDto(
        id: 'cabinet-1',
        name: 'Cabinet du Lac',
        governorate: 'Tunis',
        city: 'Tunis',
        address: '10 rue du Lac',
        primary: true,
      ),
    ],
  );

  @override
  Future<AvailabilitySlotsDto> getSlots({
    required String doctorId,
    required String practiceLocationId,
    required DateTime from,
    required DateTime to,
    CancelToken? cancelToken,
  }) {
    practiceLocationIds.add(practiceLocationId);
    final completer = Completer<AvailabilitySlotsDto>();
    _pending.add(completer);
    return completer.future;
  }

  @override
  Future<DoctorBookingResult> bookAppointment({
    required String doctorId,
    required String startTime,
    required String endTime,
    String? notes,
    CancelToken? cancelToken,
  }) => throw UnimplementedError();
}

AvailabilitySlotsDto _availability(List<AvailabilitySlotDto> slots) =>
    AvailabilitySlotsDto(
      doctorId: 'doctor-1',
      practiceLocationId: 'cabinet-1',
      timezone: 'Africa/Tunis',
      generatedAt: '2026-10-01T08:00:00Z',
      slots: slots,
    );

const _octoberSlot = AvailabilitySlotDto(
  start: '2026-10-20T08:00:00Z',
  end: '2026-10-20T08:30:00Z',
  durationMinutes: 30,
);

const _novemberSlot = AvailabilitySlotDto(
  start: '2026-11-20T08:00:00Z',
  end: '2026-11-20T08:30:00Z',
  durationMinutes: 30,
);

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

class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter({required this.responseBody});
  final String responseBody;
  String? path;
  Map<String, dynamic> query = const {};

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    path = options.path;
    query = Map<String, dynamic>.from(options.queryParameters);
    return ResponseBody.fromString(
      responseBody,
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

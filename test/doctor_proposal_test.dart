import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicare_mobile/core/network/app_http_client.dart';
import 'package:omnicare_mobile/core/storage/secure_token_store.dart';
import 'package:omnicare_mobile/features/doctor/scheduled_care/application/doctor_booking_request_controller.dart';
import 'package:omnicare_mobile/features/doctor/scheduled_care/application/doctor_proposal_controller.dart';
import 'package:omnicare_mobile/features/doctor/scheduled_care/data/doctor_proposal_availability_repository.dart';
import 'package:omnicare_mobile/features/doctor/scheduled_care/data/doctor_scheduled_care_api.dart';
import 'package:omnicare_mobile/features/doctor/scheduled_care/data/doctor_scheduled_care_repository.dart';
import 'package:omnicare_mobile/features/doctor/scheduled_care/domain/doctor_scheduled_care_models.dart';
import 'package:omnicare_mobile/features/doctor/scheduled_care/presentation/doctor_booking_request_screen.dart';
import 'package:omnicare_mobile/features/doctor/scheduled_care/presentation/doctor_proposal_screen.dart';
import 'package:omnicare_mobile/features/patient_doctor/data/doctor_directory_failure.dart';
import 'package:omnicare_mobile/features/patient_doctor/data/doctor_directory_models.dart';
import 'package:omnicare_mobile/features/scheduled_care/data/scheduled_care_failure.dart';
import 'package:omnicare_mobile/features/scheduled_care/domain/scheduled_care_models.dart';

void main() {
  group('Doctor proposal contract and transport', () {
    test('serializes exact version, Cabinet, and proposed-slot body', () {
      final command = _command();
      expect(command.toJson(), {
        'expectedVersion': 7,
        'practiceLocationId': 'cabinet-1',
        'proposedSlot': {
          'start': '2026-10-21T09:00:00Z',
          'end': '2026-10-21T09:30:00Z',
        },
      });
      expect(
        () => DoctorProposalCommand(
          requestId: 'request-1',
          expectedVersion: 7,
          practiceLocationId: 'cabinet-1',
          proposedStart: '2026-10-21T09:30:00Z',
          proposedEnd: '2026-10-21T09:00:00Z',
          idempotencyKey: 'key',
        ),
        throwsA(isA<ScheduledCareContractException>()),
      );
    });

    test('POST uses exact route, body, and idempotency header', () async {
      final adapter = _RecordingAdapter(_detailJson(waiting: true));
      final api = DoctorScheduledCareApi(_client(adapter));
      final result = await api.propose(_command());
      expect(
        result.status,
        BookingRequestStatus.pendingPatientTimeConfirmation,
      );
      expect(
        adapter.request?.path,
        '/doctor/booking-requests/request-1/proposals',
      );
      expect(adapter.request?.method, 'POST');
      expect(adapter.request?.headers['Idempotency-Key'], 'proposal-key');
      expect(adapter.body, _command().toJson());
    });

    test('matching wait-state response includes patient deadline', () {
      final request = _detail(waiting: true);
      expect(_command().matches(request), isTrue);
      expect(request.proposedSlot?.proposalId, 'proposal-1');
      expect(request.patientResponseDeadline, isNotNull);
    });
  });

  group('Doctor proposal unknown-outcome reconciliation', () {
    test('matching GET proves success and never reposts', () async {
      final api = _ProposalApi(
        proposalResults: [_connectionFailure()],
        detailResults: [_detail(waiting: true)],
      );
      final result = await DoctorScheduledCareRepository(
        api,
      ).proposeOrReconcile(_command());
      expect(result.intentCompleted, isTrue);
      expect(api.proposalCommands, hasLength(1));
    });

    test(
      'unchanged actionable GET retries once with identical command',
      () async {
        final api = _ProposalApi(
          proposalResults: [_connectionFailure(), _detail(waiting: true)],
          detailResults: [_detail()],
        );
        final result = await DoctorScheduledCareRepository(
          api,
        ).proposeOrReconcile(_command());
        expect(result.intentCompleted, isTrue);
        expect(api.proposalCommands, hasLength(2));
        expect(
          identical(api.proposalCommands[0], api.proposalCommands[1]),
          isTrue,
        );
      },
    );

    test(
      'changed version/action returns authority without a second POST',
      () async {
        final api = _ProposalApi(
          proposalResults: [_connectionFailure()],
          detailResults: [_detail(version: 8, actions: const [])],
        );
        final result = await DoctorScheduledCareRepository(
          api,
        ).proposeOrReconcile(_command());
        expect(result.intentCompleted, isFalse);
        expect(result.request.version, 8);
        expect(api.proposalCommands, hasLength(1));
      },
    );

    test('wrong proposed slot is not treated as completed', () async {
      final json = _detailJson(waiting: true);
      json['proposedSlot'] = {
        'proposalId': 'proposal-other',
        'start': '2026-10-21T10:00:00Z',
        'end': '2026-10-21T10:30:00Z',
        'proposedAt': '2026-10-11T12:00:00Z',
        'patientResponseDeadline': '2026-10-18T08:00:00Z',
      };
      final api = _ProposalApi(
        proposalResults: [_connectionFailure()],
        detailResults: [DoctorBookingRequestDetail.fromJson(json)],
      );
      final result = await DoctorScheduledCareRepository(
        api,
      ).proposeOrReconcile(_command());
      expect(result.intentCompleted, isFalse);
      expect(api.proposalCommands, hasLength(1));
    });

    test('a failed exact retry is never followed by a third POST', () async {
      final api = _ProposalApi(
        proposalResults: [_connectionFailure(), _connectionFailure()],
        detailResults: [_detail()],
      );
      await expectLater(
        DoctorScheduledCareRepository(api).proposeOrReconcile(_command()),
        throwsA(
          isA<ScheduledCareFailure>().having(
            (failure) => failure.kind,
            'kind',
            ScheduledCareFailureKind.unknownOutcome,
          ),
        ),
      );
      expect(api.proposalCommands, hasLength(2));
    });

    test('changed version blocks replay even if action remains', () async {
      final api = _ProposalApi(
        proposalResults: [_connectionFailure()],
        detailResults: [_detail(version: 8)],
      );
      final result = await DoctorScheduledCareRepository(
        api,
      ).proposeOrReconcile(_command());
      expect(result.intentCompleted, isFalse);
      expect(api.proposalCommands, hasLength(1));
    });

    test('missing action blocks replay even if version remains', () async {
      final api = _ProposalApi(
        proposalResults: [_connectionFailure()],
        detailResults: [_detail(actions: const [])],
      );
      final result = await DoctorScheduledCareRepository(
        api,
      ).proposeOrReconcile(_command());
      expect(result.intentCompleted, isFalse);
      expect(api.proposalCommands, hasLength(1));
    });
  });

  group('Doctor proposal availability and controller', () {
    test('uses authenticated Doctor and same Cabinet within 31 days', () async {
      final availability = _AvailabilityRepository(results: [_availability()]);
      final controller = _controller(availability: availability);
      addTearDown(controller.dispose);
      await controller.begin(_detail(), now: DateTime.utc(2026, 10, 11));
      final call = availability.calls.single;
      expect(call.doctorId, 'doctor-session-1');
      expect(call.cabinetId, 'cabinet-1');
      expect(
        call.to.difference(call.from),
        lessThanOrEqualTo(const Duration(days: 31)),
      );
      expect(controller.timezone, 'Africa/Tunis');
    });

    test(
      'filters the exact original slot and keeps real alternatives',
      () async {
        final controller = _controller(
          availability: _AvailabilityRepository(results: [_availability()]),
        );
        addTearDown(controller.dispose);
        await controller.begin(_detail(), now: DateTime.utc(2026, 10, 11));
        final slots = controller.days.expand((day) => day.slots).toList();
        expect(slots, hasLength(2));
        expect(slots.any((slot) => slot.startIso == _originalStart), isFalse);
        expect(slots.first.time, '10:00');
      },
    );

    test('does not fetch when PROPOSE_NEW_TIME is absent', () async {
      final availability = _AvailabilityRepository(results: [_availability()]);
      final controller = _controller(availability: availability);
      addTearDown(controller.dispose);
      await controller.begin(_detail(actions: const []));
      expect(availability.calls, isEmpty);
      expect(controller.canPropose, isFalse);
    });

    test('rejects availability for another Doctor or Cabinet', () async {
      final controller = _controller(
        availability: _AvailabilityRepository(
          results: [_availability(doctorId: 'doctor-other')],
        ),
      );
      addTearDown(controller.dispose);
      await controller.begin(_detail(), now: DateTime.utc(2026, 10, 11));
      expect(
        controller.availabilityState,
        DoctorProposalAvailabilityState.failed,
      );
      expect(
        controller.availabilityFailure?.kind,
        DoctorDirectoryFailureKind.contract,
      );
    });

    test('ignores a stale availability response after a new month', () async {
      final first = Completer<AvailabilitySlotsDto>();
      final availability = _AvailabilityRepository(
        results: [
          first.future,
          _availability(slots: const []),
        ],
      );
      final controller = _controller(availability: availability);
      addTearDown(controller.dispose);
      final initial = controller.begin(
        _detail(),
        now: DateTime.utc(2026, 10, 11),
      );
      await Future<void>.delayed(Duration.zero);
      await controller.loadMonth(
        DateTime(2026, 11),
        now: DateTime.utc(2026, 10, 11),
      );
      first.complete(_availability());
      await initial;
      expect(controller.month, DateTime(2026, 11));
      expect(controller.days, isEmpty);
    });

    test(
      'empty availability is explicit and retry recovers an error',
      () async {
        final availability = _AvailabilityRepository(
          results: [
            DoctorDirectoryFailure.networkUnavailable,
            _availability(slots: const []),
          ],
        );
        final controller = _controller(availability: availability);
        addTearDown(controller.dispose);
        await controller.begin(_detail(), now: DateTime.utc(2026, 10, 11));
        expect(
          controller.availabilityState,
          DoctorProposalAvailabilityState.failed,
        );
        await controller.retryAvailability();
        expect(
          controller.availabilityState,
          DoctorProposalAvailabilityState.ready,
        );
        expect(controller.days, isEmpty);
        expect(availability.calls, hasLength(2));
      },
    );

    test(
      'stable key survives safe retry and changes with selected slot',
      () async {
        final scheduled = _ProposalRepository(
          proposeHandler: (_, _) async => throw const ScheduledCareFailure(
            kind: ScheduledCareFailureKind.network,
            message: 'offline',
            diagnosticCode: 'NETWORK',
          ),
        );
        var keyIndex = 0;
        final controller = _controller(
          scheduled: scheduled,
          availability: _AvailabilityRepository(results: [_availability()]),
          keyFactory: () => 'key-${++keyIndex}',
        );
        addTearDown(controller.dispose);
        await controller.begin(_detail(), now: DateTime.utc(2026, 10, 11));
        final slots = controller.days.expand((day) => day.slots).toList();
        controller.selectSlot(slots.first);
        await controller.submit();
        await controller.submit();
        expect(
          scheduled.proposalCommands[0].idempotencyKey,
          'doctor-proposal-key-1',
        );
        expect(
          scheduled.proposalCommands[1].idempotencyKey,
          'doctor-proposal-key-1',
        );
        controller.selectSlot(slots.last);
        await controller.submit();
        expect(
          scheduled.proposalCommands.last.idempotencyKey,
          'doctor-proposal-key-2',
        );
      },
    );

    test('success publishes authority and refreshes Home once', () async {
      var refreshes = 0;
      DoctorBookingRequestDetail? published;
      final scheduled = _ProposalRepository(
        proposeHandler: (_, _) async => DoctorMutationResult(
          request: _detail(waiting: true),
          intentCompleted: true,
        ),
      );
      final controller = _controller(
        scheduled: scheduled,
        availability: _AvailabilityRepository(results: [_availability()]),
        onChanged: (value) => published = value,
        refreshHome: () async => refreshes++,
      );
      addTearDown(controller.dispose);
      await controller.begin(_detail(), now: DateTime.utc(2026, 10, 11));
      controller.selectSlot(controller.days.first.slots.first);
      expect(await controller.submit(), isTrue);
      expect(controller.proposalCompleted, isTrue);
      expect(
        published?.status,
        BookingRequestStatus.pendingPatientTimeConfirmation,
      );
      expect(refreshes, 1);
    });

    test('an in-flight proposal cannot submit twice', () async {
      final pending = Completer<DoctorMutationResult>();
      final scheduled = _ProposalRepository(
        proposeHandler: (_, _) => pending.future,
      );
      final controller = _controller(
        scheduled: scheduled,
        availability: _AvailabilityRepository(results: [_availability()]),
      );
      addTearDown(controller.dispose);
      await controller.begin(_detail(), now: DateTime.utc(2026, 10, 11));
      controller.selectSlot(controller.days.first.slots.first);
      final first = controller.submit();
      expect(controller.canSubmit, isFalse);
      expect(await controller.submit(), isFalse);
      expect(scheduled.proposalCommands, hasLength(1));
      pending.complete(
        DoctorMutationResult(
          request: _detail(waiting: true),
          intentCompleted: true,
        ),
      );
      expect(await first, isTrue);
    });

    test(
      'slot conflict refreshes availability and forces new selection',
      () async {
        final scheduled = _ProposalRepository(
          proposeHandler: (_, _) async => throw const ScheduledCareFailure(
            kind: ScheduledCareFailureKind.slotNoLongerAvailable,
            message: 'slot lost',
            diagnosticCode: 'SLOT_NO_LONGER_AVAILABLE',
          ),
        );
        final availability = _AvailabilityRepository(
          results: [
            _availability(),
            _availability(slots: const []),
          ],
        );
        final controller = _controller(
          scheduled: scheduled,
          availability: availability,
        );
        addTearDown(controller.dispose);
        await controller.begin(_detail(), now: DateTime.utc(2026, 10, 11));
        controller.selectSlot(controller.days.first.slots.first);
        await controller.submit();
        expect(availability.calls, hasLength(2));
        expect(controller.selectedSlot, isNull);
        expect(controller.pendingIdempotencyKey, isNull);
        expect(
          controller.submissionFailure?.kind,
          ScheduledCareFailureKind.slotNoLongerAvailable,
        );
      },
    );

    test('state conflict GETs authority and removes proposal action', () async {
      final scheduled = _ProposalRepository(
        detailHandler: (_, _) async => _detail(version: 8, actions: const []),
        proposeHandler: (_, _) async => throw const ScheduledCareFailure(
          kind: ScheduledCareFailureKind.versionConflict,
          message: 'changed',
          diagnosticCode: 'VERSION_CONFLICT',
        ),
      );
      final controller = _controller(
        scheduled: scheduled,
        availability: _AvailabilityRepository(results: [_availability()]),
      );
      addTearDown(controller.dispose);
      await controller.begin(_detail(), now: DateTime.utc(2026, 10, 11));
      controller.selectSlot(controller.days.first.slots.first);
      await controller.submit();
      expect(scheduled.proposalCommands, hasLength(1));
      expect(scheduled.detailGets, ['request-1']);
      expect(controller.request?.version, 8);
      expect(controller.canPropose, isFalse);
    });

    for (final kind in const [
      ScheduledCareFailureKind.requestStateConflict,
      ScheduledCareFailureKind.actionNotAllowed,
      ScheduledCareFailureKind.requestExpired,
    ]) {
      test('${kind.name} refetches authority and exits stale action', () async {
        final scheduled = _ProposalRepository(
          detailHandler: (_, _) async => _detail(version: 8, actions: const []),
          proposeHandler: (_, _) async => throw ScheduledCareFailure(
            kind: kind,
            message: 'changed',
            diagnosticCode: kind.name,
          ),
        );
        final controller = _controller(
          scheduled: scheduled,
          availability: _AvailabilityRepository(results: [_availability()]),
        );
        addTearDown(controller.dispose);
        await controller.begin(_detail(), now: DateTime.utc(2026, 10, 11));
        controller.selectSlot(controller.days.first.slots.first);
        await controller.submit();
        expect(scheduled.detailGets, ['request-1']);
        expect(controller.canPropose, isFalse);
      });
    }

    test(
      'idempotency conflict stops without a GET or blind new POST',
      () async {
        final scheduled = _ProposalRepository(
          proposeHandler: (_, _) async => throw const ScheduledCareFailure(
            kind: ScheduledCareFailureKind.idempotencyConflict,
            message: 'fingerprint mismatch',
            diagnosticCode: 'IDEMPOTENCY_CONFLICT',
          ),
        );
        final controller = _controller(
          scheduled: scheduled,
          availability: _AvailabilityRepository(results: [_availability()]),
        );
        addTearDown(controller.dispose);
        await controller.begin(_detail(), now: DateTime.utc(2026, 10, 11));
        controller.selectSlot(controller.days.first.slots.first);
        await controller.submit();
        expect(scheduled.proposalCommands, hasLength(1));
        expect(scheduled.detailGets, isEmpty);
        expect(
          controller.submissionFailure?.kind,
          ScheduledCareFailureKind.idempotencyConflict,
        );
      },
    );

    test('clear drops keys/state and ignores a late submission', () async {
      final pending = Completer<DoctorMutationResult>();
      final scheduled = _ProposalRepository(
        proposeHandler: (_, _) => pending.future,
      );
      final controller = _controller(
        scheduled: scheduled,
        availability: _AvailabilityRepository(results: [_availability()]),
      );
      addTearDown(controller.dispose);
      await controller.begin(_detail(), now: DateTime.utc(2026, 10, 11));
      controller.selectSlot(controller.days.first.slots.first);
      final submit = controller.submit();
      controller.clear();
      pending.complete(
        DoctorMutationResult(
          request: _detail(waiting: true),
          intentCompleted: true,
        ),
      );
      await submit;
      expect(controller.request, isNull);
      expect(controller.selectedSlot, isNull);
      expect(controller.pendingIdempotencyKey, isNull);
      expect(controller.isSubmitting, isFalse);
    });
  });

  group('Doctor proposal presentation', () {
    testWidgets('request detail enables proposal only with an injected flow', (
      tester,
    ) async {
      final repository = _ProposalRepository(
        detailHandler: (_, _) async => _detail(),
      );
      final detailController = DoctorBookingRequestController(
        repository: repository,
        refreshHome: () async {},
      );
      final proposalController = _controller(
        scheduled: repository,
        availability: _AvailabilityRepository(results: [_availability()]),
      );
      addTearDown(detailController.dispose);
      addTearDown(proposalController.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: DoctorBookingRequestScreen(
            requestId: 'request-1',
            controller: detailController,
            proposalController: proposalController,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final finder = find.byKey(const ValueKey('doctor-propose-new-time'));
      expect(finder, findsOneWidget);
      expect(tester.widget<OutlinedButton>(finder).onPressed, isNotNull);
      await tester.tap(finder);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('doctor-proposal-selector')),
        findsOneWidget,
      );
    });

    testWidgets('selector shows context, alternatives, and review', (
      tester,
    ) async {
      final controller = _controller(
        availability: _AvailabilityRepository(results: [_availability()]),
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: DoctorProposalScreen(
            request: _detail(),
            controller: controller,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Cabinet du Lac'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('doctor-proposal-original-slot')),
        findsOneWidget,
      );
      expect(find.text('09:00'), findsNothing);
      expect(find.text('10:00'), findsOneWidget);
      await tester.tap(find.text('10:00'));
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey('doctor-proposal-review-button')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('doctor-proposal-review')),
        findsOneWidget,
      );
      expect(find.text('Nadia Ben Ali'), findsNWidgets(2));
    });

    testWidgets('waiting detail renders original, proposal, and deadline', (
      tester,
    ) async {
      final repository = _ProposalRepository(
        detailHandler: (_, _) async => _detail(waiting: true),
      );
      final detailController = DoctorBookingRequestController(
        repository: repository,
        refreshHome: () async {},
      );
      addTearDown(detailController.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: DoctorBookingRequestScreen(
            requestId: 'request-1',
            controller: detailController,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('En attente de la réponse du patient'), findsOneWidget);
      expect(find.text('Nouvel horaire proposé'), findsOneWidget);
      expect(
        find.textContaining('Réponse du patient avant le'),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('doctor-propose-new-time')),
        findsNothing,
      );
    });
  });
}

const _originalStart = '2026-10-20T08:00:00Z';

DoctorProposalCommand _command() => DoctorProposalCommand(
  requestId: 'request-1',
  expectedVersion: 7,
  practiceLocationId: 'cabinet-1',
  proposedStart: '2026-10-21T09:00:00Z',
  proposedEnd: '2026-10-21T09:30:00Z',
  idempotencyKey: 'proposal-key',
);

DoctorBookingRequestDetail _detail({
  int version = 7,
  List<String> actions = const ['PROPOSE_NEW_TIME'],
  bool waiting = false,
}) => DoctorBookingRequestDetail.fromJson(
  _detailJson(version: version, actions: actions, waiting: waiting),
);

Map<String, dynamic> _detailJson({
  int version = 7,
  List<String> actions = const ['PROPOSE_NEW_TIME'],
  bool waiting = false,
}) => {
  'requestId': 'request-1',
  'version': version,
  'status': waiting ? 'PENDING_PATIENT_TIME_CONFIRMATION' : 'PENDING_DOCTOR',
  'subject': {
    'subjectType': 'SELF',
    'familyMemberId': null,
    'displayName': 'Nadia Ben Ali',
    'relationship': null,
  },
  'cabinet': {
    'practiceLocationId': 'cabinet-1',
    'name': 'Cabinet du Lac',
    'address': '1 rue du Lac',
    'city': 'Tunis',
    'governorate': 'Tunis',
    'timezone': 'Africa/Tunis',
  },
  'originalRequestedSlot': {
    'start': _originalStart,
    'end': '2026-10-20T08:30:00Z',
  },
  'proposedSlot': waiting
      ? {
          'proposalId': 'proposal-1',
          'start': '2026-10-21T09:00:00Z',
          'end': '2026-10-21T09:30:00Z',
          'proposedAt': '2026-10-11T12:00:00Z',
          'patientResponseDeadline': '2026-10-18T08:00:00Z',
        }
      : null,
  'activeSlot': {
    'start': waiting ? '2026-10-21T09:00:00Z' : _originalStart,
    'end': waiting ? '2026-10-21T09:30:00Z' : '2026-10-20T08:30:00Z',
    'durationMinutes': 30,
  },
  'createdAt': '2026-10-11T08:00:00Z',
  'responseDeadline': '2026-10-19T08:00:00Z',
  'patientResponseDeadline': waiting ? '2026-10-18T08:00:00Z' : null,
  'confirmedAppointmentId': null,
  'cancellation': null,
  'expiredAt': null,
  'expiryReason': null,
  'slotReleased': false,
  'availableActions': waiting ? const <String>[] : actions,
  'updatedAt': '2026-10-11T12:00:00Z',
};

AvailabilitySlotsDto _availability({
  String doctorId = 'doctor-session-1',
  String cabinetId = 'cabinet-1',
  List<AvailabilitySlotDto>? slots,
}) => AvailabilitySlotsDto(
  doctorId: doctorId,
  practiceLocationId: cabinetId,
  timezone: 'Africa/Tunis',
  generatedAt: '2026-10-11T12:00:00Z',
  slots:
      slots ??
      const [
        AvailabilitySlotDto(
          start: _originalStart,
          end: '2026-10-20T08:30:00Z',
          durationMinutes: 30,
        ),
        AvailabilitySlotDto(
          start: '2026-10-21T09:00:00Z',
          end: '2026-10-21T09:30:00Z',
          durationMinutes: 30,
        ),
        AvailabilitySlotDto(
          start: '2026-10-21T10:00:00Z',
          end: '2026-10-21T10:30:00Z',
          durationMinutes: 30,
        ),
      ],
);

DoctorProposalController _controller({
  _ProposalRepository? scheduled,
  required _AvailabilityRepository availability,
  void Function(DoctorBookingRequestDetail)? onChanged,
  Future<void> Function()? refreshHome,
  String Function()? keyFactory,
}) => DoctorProposalController(
  authenticatedDoctorId: 'doctor-session-1',
  scheduledCareRepository: scheduled ?? _ProposalRepository(),
  availabilityRepository: availability,
  onRequestChanged: onChanged ?? (_) {},
  refreshHome: refreshHome ?? () async {},
  idempotencyKeyFactory: keyFactory ?? () => 'fixture',
);

class _AvailabilityCall {
  const _AvailabilityCall(this.doctorId, this.cabinetId, this.from, this.to);
  final String doctorId;
  final String cabinetId;
  final DateTime from;
  final DateTime to;
}

class _AvailabilityRepository
    implements DoctorProposalAvailabilityRepositoryContract {
  _AvailabilityRepository({required this.results});
  final List<Object> results;
  final calls = <_AvailabilityCall>[];
  int _index = 0;

  @override
  Future<AvailabilitySlotsDto> getSlots({
    required String doctorId,
    required String practiceLocationId,
    required DateTime from,
    required DateTime to,
    CancelToken? cancelToken,
  }) async {
    calls.add(_AvailabilityCall(doctorId, practiceLocationId, from, to));
    final value = results[_index++];
    if (value is Future<AvailabilitySlotsDto>) return value;
    if (value is AvailabilitySlotsDto) return value;
    throw value;
  }
}

class _ProposalRepository implements DoctorScheduledCareRepositoryContract {
  _ProposalRepository({this.detailHandler, this.proposeHandler});
  final Future<DoctorBookingRequestDetail> Function(String, CancelToken?)?
  detailHandler;
  final Future<DoctorMutationResult> Function(
    DoctorProposalCommand,
    CancelToken?,
  )?
  proposeHandler;
  final proposalCommands = <DoctorProposalCommand>[];
  final detailGets = <String>[];

  @override
  Future<DoctorAgendaSnapshot> getAgenda(
    DoctorAgendaRange range, {
    CancelToken? cancelToken,
  }) => throw UnimplementedError();

  @override
  Future<ConfirmedScheduledAppointment> getAppointment(
    String appointmentId, {
    CancelToken? cancelToken,
  }) => throw UnimplementedError();

  @override
  Future<DoctorAppointmentMutationResult> cancelAppointmentOrReconcile(
    DoctorCancelAppointmentCommand command, {
    CancelToken? cancelToken,
  }) => throw UnimplementedError();

  @override
  Future<DoctorBookingRequestDetail> getBookingRequest(
    String requestId, {
    CancelToken? cancelToken,
  }) {
    detailGets.add(requestId);
    return detailHandler!(requestId, cancelToken);
  }

  @override
  Future<DoctorMutationResult> proposeOrReconcile(
    DoctorProposalCommand command, {
    CancelToken? cancelToken,
  }) {
    proposalCommands.add(command);
    return proposeHandler!(command, cancelToken);
  }

  @override
  Future<DoctorHomeSummary> getHomeSummary({CancelToken? cancelToken}) =>
      throw UnimplementedError();
  @override
  Future<DoctorMutationResult> acceptOrReconcile(
    DoctorAcceptCommand command, {
    CancelToken? cancelToken,
  }) => throw UnimplementedError();
  @override
  Future<DoctorMutationResult> declineOrReconcile(
    DoctorDeclineCommand command, {
    CancelToken? cancelToken,
  }) => throw UnimplementedError();
}

class _ProposalApi implements DoctorScheduledCareApiContract {
  _ProposalApi({required this.proposalResults, required this.detailResults});
  final List<Object> proposalResults;
  final List<Object> detailResults;
  final proposalCommands = <DoctorProposalCommand>[];
  int _proposalIndex = 0;
  int _detailIndex = 0;

  @override
  Future<DoctorAgendaSnapshot> getAgenda(
    DoctorAgendaRange range, {
    CancelToken? cancelToken,
  }) => throw UnimplementedError();

  @override
  Future<ConfirmedScheduledAppointment> cancelAppointment(
    DoctorCancelAppointmentCommand command, {
    CancelToken? cancelToken,
  }) => throw UnimplementedError();

  @override
  Future<DoctorBookingRequestDetail> propose(
    DoctorProposalCommand command, {
    CancelToken? cancelToken,
  }) async {
    proposalCommands.add(command);
    return _result(proposalResults[_proposalIndex++]);
  }

  @override
  Future<DoctorBookingRequestDetail> getBookingRequest(
    String requestId, {
    CancelToken? cancelToken,
  }) async => _result(detailResults[_detailIndex++]);

  @override
  Future<DoctorHomeSummary> getHomeSummary({CancelToken? cancelToken}) =>
      throw UnimplementedError();
  @override
  Future<DoctorAcceptResult> accept(
    DoctorAcceptCommand command, {
    CancelToken? cancelToken,
  }) => throw UnimplementedError();
  @override
  Future<DoctorBookingRequestDetail> decline(
    DoctorDeclineCommand command, {
    CancelToken? cancelToken,
  }) => throw UnimplementedError();
  @override
  Future<ConfirmedScheduledAppointment> getAppointment(
    String appointmentId, {
    CancelToken? cancelToken,
  }) => throw UnimplementedError();
}

T _result<T>(Object value) {
  if (value is T) return value as T;
  throw value;
}

DioException _connectionFailure() => DioException(
  requestOptions: RequestOptions(path: '/doctor/booking-requests/request-1'),
  type: DioExceptionType.connectionError,
);

class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this.response);
  final Object response;
  RequestOptions? request;
  Object? body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    body = options.data;
    return ResponseBody.fromString(
      jsonEncode(response),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
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

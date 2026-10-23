import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:omnicare_mobile/core/network/app_http_client.dart';
import 'package:omnicare_mobile/core/storage/secure_token_store.dart';
import 'package:omnicare_mobile/core/theme/omni_theme.dart';
import 'package:omnicare_mobile/features/scheduled_care/application/patient_booking_controller.dart';
import 'package:omnicare_mobile/features/scheduled_care/data/scheduled_care_api.dart';
import 'package:omnicare_mobile/features/scheduled_care/data/scheduled_care_failure.dart';
import 'package:omnicare_mobile/features/scheduled_care/data/scheduled_care_repository.dart';
import 'package:omnicare_mobile/features/scheduled_care/domain/scheduled_care_models.dart';
import 'package:omnicare_mobile/features/scheduled_care/presentation/confirmed_scheduled_appointment_screen.dart';
import 'package:omnicare_mobile/features/scheduled_care/presentation/pending_booking_request_screen.dart';

void main() {
  group('request and Appointment parsing', () {
    for (final entry in const {
      'PENDING_DOCTOR': BookingRequestStatus.pendingDoctor,
      'PENDING_PATIENT_TIME_CONFIRMATION':
          BookingRequestStatus.pendingPatientTimeConfirmation,
      'FULFILLED': BookingRequestStatus.fulfilled,
      'CANCELLED_BY_PATIENT': BookingRequestStatus.cancelledByPatient,
      'CANCELLED_BY_DOCTOR': BookingRequestStatus.cancelledByDoctor,
      'EXPIRED': BookingRequestStatus.expired,
    }.entries) {
      test('parses ${entry.key} without aliasing', () {
        final json = _requestJson(status: entry.key);
        if (entry.value != BookingRequestStatus.pendingDoctor) {
          json['activeSlot'] = null;
        }
        final result = PatientBookingRequestDetail.fromJson(json);
        expect(result.status, entry.value);
        expect(result.rawStatus, entry.key);
        expect(result.version, 7);
        expect(result.responseDeadline, DateTime.parse('2027-01-10T12:00:00Z'));
      });
    }

    test('unknown request status remains unknown and preserves raw value', () {
      final result = PatientBookingRequestDetail.fromJson(
        _requestJson(status: 'FUTURE_SERVER_STATE'),
      );
      expect(result.status, BookingRequestStatus.unknown);
      expect(result.rawStatus, 'FUTURE_SERVER_STATE');
    });

    test('proposal and exact availableActions are parsed', () {
      final result = PatientBookingRequestDetail.fromJson(
        _requestJson(
          status: 'PENDING_PATIENT_TIME_CONFIRMATION',
          actions: const [
            'ACCEPT_PROPOSED_TIME',
            'DECLINE_PROPOSED_TIME',
            'SERVER_FUTURE_ACTION',
          ],
          proposal: true,
        ),
      );
      expect(result.proposedSlot?.proposalId, 'proposal-1');
      expect(
        result.proposedSlot?.patientResponseDeadline,
        DateTime.parse('2027-01-09T12:00:00Z'),
      );
      expect(result.availableActions, [
        AvailableAction.acceptProposedTime,
        AvailableAction.declineProposedTime,
        AvailableAction.unknown,
      ]);
    });

    test('Appointment parses all current statuses and unknown safely', () {
      for (final entry in const {
        'CONFIRMED': ScheduledAppointmentStatus.confirmed,
        'IN_PROGRESS': ScheduledAppointmentStatus.inProgress,
        'CANCELLED': ScheduledAppointmentStatus.cancelled,
        'COMPLETED': ScheduledAppointmentStatus.completed,
        'NO_SHOW': ScheduledAppointmentStatus.noShow,
        'FUTURE': ScheduledAppointmentStatus.unknown,
      }.entries) {
        final appointment = ConfirmedScheduledAppointment.fromJson(
          _appointmentJson(status: entry.key),
        );
        expect(appointment.status, entry.value);
        expect(appointment.appointmentId, 'appointment-9');
        expect(appointment.sourceBookingRequestId, 'request-1');
      }
    });

    test('acceptance rejects request/Appointment identity collapse', () {
      final request = _requestJson(
        status: 'FULFILLED',
        confirmedAppointmentId: 'request-1',
      )..['activeSlot'] = null;
      final appointment = _appointmentJson(appointmentId: 'request-1');
      expect(
        () => ProposalAcceptanceResult.fromJson({
          'request': request,
          'appointment': appointment,
        }),
        throwsA(isA<ScheduledCareContractException>()),
      );
    });
  });

  group('mutation transport contract', () {
    test(
      'cancel sends exact version, reason, path and stable header',
      () async {
        final adapter = _RecordingAdapter(
          _requestJson(status: 'CANCELLED_BY_PATIENT', actions: const [])
            ..['activeSlot'] = null,
        );
        final api = ScheduledCareApi(_client(adapter));
        await api.cancelBookingRequest(
          const CancelBookingRequestCommand(
            requestId: 'request-1',
            expectedVersion: 7,
            idempotencyKey: 'cancel-stable-key',
            reason: PatientCancellationReason.changeOfPlans,
          ),
        );
        expect(adapter.path, '/doctor-booking-requests/request-1/cancel');
        expect(adapter.headers['Idempotency-Key'], 'cancel-stable-key');
        expect(adapter.body, {
          'expectedVersion': 7,
          'reasonCode': 'CHANGE_OF_PLANS',
        });
      },
    );

    test('accept uses exact request and proposal IDs', () async {
      final adapter = _RecordingAdapter({
        'request': _requestJson(
          status: 'FULFILLED',
          actions: const [],
          confirmedAppointmentId: 'appointment-9',
        )..['activeSlot'] = null,
        'appointment': _appointmentJson(),
      });
      final api = ScheduledCareApi(_client(adapter));
      final result = await api.acceptProposal(
        const AcceptBookingProposalCommand(
          requestId: 'request-1',
          proposalId: 'proposal-1',
          expectedVersion: 7,
          idempotencyKey: 'accept-stable-key',
        ),
      );
      expect(
        adapter.path,
        '/doctor-booking-requests/request-1/proposals/proposal-1/accept',
      );
      expect(adapter.body, {'expectedVersion': 7});
      expect(result.request.requestId, isNot(result.appointment.appointmentId));
      expect(
        result.appointment.sourceBookingRequestId,
        result.request.requestId,
      );
    });

    test('decline sends controlled PROPOSAL_DECLINED reason', () async {
      final adapter = _RecordingAdapter(
        _requestJson(status: 'CANCELLED_BY_PATIENT', actions: const [])
          ..['activeSlot'] = null,
      );
      final api = ScheduledCareApi(_client(adapter));
      await api.declineProposal(
        const DeclineBookingProposalCommand(
          requestId: 'request-1',
          proposalId: 'proposal-1',
          expectedVersion: 7,
          idempotencyKey: 'decline-stable-key',
        ),
      );
      expect(
        adapter.path,
        '/doctor-booking-requests/request-1/proposals/proposal-1/decline',
      );
      expect(adapter.body, {
        'expectedVersion': 7,
        'reasonCode': 'PROPOSAL_DECLINED',
      });
    });
  });

  group('repository mutation recovery', () {
    test('cancel reconciles then retries exact command once', () async {
      final api = _LifecycleApi(
        cancelResults: [
          _connectionFailure(),
          _request(status: BookingRequestStatus.cancelledByPatient, version: 8),
        ],
        getResults: [
          _request(actions: const [AvailableAction.cancelRequest]),
        ],
      );
      final command = CancelBookingRequestCommand(
        requestId: 'request-1',
        expectedVersion: 7,
        idempotencyKey: 'same-key',
        reason: PatientCancellationReason.noLongerNeeded,
      );
      final result = await ScheduledCareRepository(
        api,
      ).cancelOrReconcile(command);
      expect(result.intentCompleted, isTrue);
      expect(api.cancelCommands, hasLength(2));
      expect(
        identical(api.cancelCommands.first, api.cancelCommands.last),
        isTrue,
      );
      expect(api.cancelCommands.map((value) => value.idempotencyKey), [
        'same-key',
        'same-key',
      ]);
    });

    test(
      'accept fulfilled reconciliation fetches Appointment, no replay',
      () async {
        final api = _LifecycleApi(
          acceptResults: [_connectionFailure()],
          getResults: [
            _request(
              status: BookingRequestStatus.fulfilled,
              version: 8,
              confirmedAppointmentId: 'appointment-9',
            ),
          ],
          appointmentResults: [_appointment()],
        );
        final result = await ScheduledCareRepository(api)
            .acceptProposalOrReconcile(
              const AcceptBookingProposalCommand(
                requestId: 'request-1',
                proposalId: 'proposal-1',
                expectedVersion: 7,
                idempotencyKey: 'accept-key',
              ),
            );
        expect(result.intentCompleted, isTrue);
        expect(result.appointment?.appointmentId, 'appointment-9');
        expect(api.acceptCommands, hasLength(1));
        expect(api.appointmentIds, ['appointment-9']);
      },
    );

    test('decline reconciliation produces no Appointment', () async {
      final api = _LifecycleApi(
        declineResults: [_connectionFailure()],
        getResults: [
          _request(status: BookingRequestStatus.cancelledByPatient, version: 8),
        ],
      );
      final result = await ScheduledCareRepository(api)
          .declineProposalOrReconcile(
            const DeclineBookingProposalCommand(
              requestId: 'request-1',
              proposalId: 'proposal-1',
              expectedVersion: 7,
              idempotencyKey: 'decline-key',
            ),
          );
      expect(result.intentCompleted, isTrue);
      expect(result.appointment, isNull);
      expect(api.declineCommands, hasLength(1));
    });

    test(
      'changed version is authoritative and blocks stale auto-replay',
      () async {
        final api = _LifecycleApi(
          cancelResults: [_connectionFailure()],
          getResults: [
            _request(
              version: 8,
              actions: const [AvailableAction.cancelRequest],
            ),
          ],
        );
        final result = await ScheduledCareRepository(api).cancelOrReconcile(
          const CancelBookingRequestCommand(
            requestId: 'request-1',
            expectedVersion: 7,
            idempotencyKey: 'cancel-key',
            reason: PatientCancellationReason.changeOfPlans,
          ),
        );
        expect(result.intentCompleted, isFalse);
        expect(result.request.version, 8);
        expect(api.cancelCommands, hasLength(1));
      },
    );
  });

  group('controller authority, idempotency and session ownership', () {
    test('availableActions, not status alone, gates cancellation', () async {
      final repository = _ControllerRepository(
        getResults: [_request(actions: const [])],
      );
      final controller = _controller(repository);
      await controller.openRequest('request-1');
      expect(controller.result?.status, BookingRequestStatus.pendingDoctor);
      expect(controller.canCancel, isFalse);
      await controller.cancelRequest(PatientCancellationReason.changeOfPlans);
      expect(repository.cancelCommands, isEmpty);
    });

    test(
      'same failed cancel intent retains key; changed reason mints key',
      () async {
        final repository = _ControllerRepository(
          getResults: [
            _request(actions: const [AvailableAction.cancelRequest]),
          ],
          cancelFailures: [_unknownFailure, _unknownFailure, _unknownFailure],
        );
        var sequence = 0;
        final controller = _controller(
          repository,
          keyFactory: () => 'key-${++sequence}',
        );
        await controller.openRequest('request-1');
        await controller.cancelRequest(PatientCancellationReason.changeOfPlans);
        await controller.cancelRequest(PatientCancellationReason.changeOfPlans);
        await controller.cancelRequest(
          PatientCancellationReason.noLongerNeeded,
        );
        expect(repository.cancelCommands.map((value) => value.idempotencyKey), [
          'patient-cancel-key-1',
          'patient-cancel-key-1',
          'patient-cancel-key-2',
        ]);
        expect(
          repository.cancelCommands.every(
            (value) => value.expectedVersion == 7,
          ),
          isTrue,
        );
        expect(
          repository.cancelCommands.every(
            (value) => value.idempotencyKey.length <= 128,
          ),
          isTrue,
        );
      },
    );

    test('accept and decline retain separate stable command keys', () async {
      var sequence = 0;
      final acceptRepository = _ControllerRepository(
        getResults: [
          _request(
            status: BookingRequestStatus.pendingPatientTimeConfirmation,
            proposal: true,
            actions: const [AvailableAction.acceptProposedTime],
          ),
        ],
        acceptFailures: const [_unknownFailure, _unknownFailure],
      );
      final acceptController = _controller(
        acceptRepository,
        keyFactory: () => 'key-${++sequence}',
      );
      await acceptController.openRequest('request-1');
      await acceptController.acceptProposal();
      await acceptController.acceptProposal();
      expect(
        acceptRepository.acceptCommands.map((value) => value.idempotencyKey),
        ['patient-proposal-accept-key-1', 'patient-proposal-accept-key-1'],
      );

      final declineRepository = _ControllerRepository(
        getResults: [
          _request(
            status: BookingRequestStatus.pendingPatientTimeConfirmation,
            proposal: true,
            actions: const [AvailableAction.declineProposedTime],
          ),
        ],
        declineFailures: const [_unknownFailure, _unknownFailure],
      );
      final declineController = _controller(
        declineRepository,
        keyFactory: () => 'key-${++sequence}',
      );
      await declineController.openRequest('request-1');
      await declineController.declineProposal();
      await declineController.declineProposal();
      expect(
        declineRepository.declineCommands.map((value) => value.idempotencyKey),
        ['patient-proposal-decline-key-2', 'patient-proposal-decline-key-2'],
      );
      expect(
        declineRepository.declineCommands.every(
          (value) => value.reason == PatientCancellationReason.proposalDeclined,
        ),
        isTrue,
      );
      expect(
        acceptRepository.acceptCommands.first.idempotencyKey,
        isNot(declineRepository.declineCommands.first.idempotencyKey),
      );
    });

    test('IDEMPOTENCY_CONFLICT blocks blind retries until refresh', () async {
      final repository = _ControllerRepository(
        getResults: [
          _request(actions: const [AvailableAction.cancelRequest]),
          _request(actions: const [AvailableAction.cancelRequest]),
        ],
        cancelFailures: const [
          ScheduledCareFailure(
            kind: ScheduledCareFailureKind.idempotencyConflict,
            message: 'safe',
            diagnosticCode: 'IDEMPOTENCY_CONFLICT',
          ),
        ],
      );
      final controller = _controller(repository);
      await controller.openRequest('request-1');
      await controller.cancelRequest(PatientCancellationReason.changeOfPlans);
      expect(controller.canCancel, isFalse);
      await controller.cancelRequest(PatientCancellationReason.changeOfPlans);
      expect(repository.cancelCommands, hasLength(1));
      await controller.refresh();
      expect(controller.canCancel, isTrue);
    });

    test('clear removes an unresolved mutation key', () async {
      final repository = _ControllerRepository(
        getResults: [
          _request(actions: const [AvailableAction.cancelRequest]),
        ],
        cancelFailures: const [_unknownFailure],
      );
      final controller = _controller(repository);
      await controller.openRequest('request-1');
      await controller.cancelRequest(PatientCancellationReason.changeOfPlans);
      expect(controller.pendingIdempotencyKey, isNotNull);
      controller.clear();
      expect(controller.pendingIdempotencyKey, isNull);
      expect(controller.result, isNull);
      expect(controller.appointment, isNull);
    });

    for (final entry in const {
      ScheduledCareFailureKind.versionConflict: 'VERSION_CONFLICT',
      ScheduledCareFailureKind.requestExpired: 'REQUEST_EXPIRED',
      ScheduledCareFailureKind.actionNotAllowed: 'ACTION_NOT_ALLOWED',
    }.entries) {
      test(
        '${entry.value} refetches and never replays stale command',
        () async {
          final repository = _ControllerRepository(
            getResults: [
              _request(actions: const [AvailableAction.cancelRequest]),
              _request(
                status: BookingRequestStatus.expired,
                version: 8,
                expiryReason: 'DOCTOR_RESPONSE_TIMEOUT',
              ),
            ],
            cancelFailures: [
              ScheduledCareFailure(
                kind: entry.key,
                message: 'safe',
                diagnosticCode: entry.value,
              ),
            ],
          );
          final controller = _controller(repository);
          await controller.openRequest('request-1');
          await controller.cancelRequest(
            PatientCancellationReason.changeOfPlans,
          );
          expect(repository.cancelCommands, hasLength(1));
          expect(repository.getIds, ['request-1', 'request-1']);
          expect(controller.result?.status, BookingRequestStatus.expired);
          expect(controller.canCancel, isFalse);
        },
      );
    }

    test('deadline causes GET but never a local EXPIRED transition', () async {
      final pending = _request(
        actions: const [AvailableAction.cancelRequest],
        responseDeadline: DateTime.parse('2026-01-01T00:00:00Z'),
      );
      final repository = _ControllerRepository(getResults: [pending, pending]);
      final controller = _controller(repository);
      await controller.openRequest('request-1');
      final refreshed = await controller.refreshAtDeadline(
        now: DateTime.parse('2026-01-01T00:00:01Z'),
      );
      expect(refreshed, isTrue);
      expect(repository.getIds, ['request-1', 'request-1']);
      expect(controller.result?.status, BookingRequestStatus.pendingDoctor);
    });

    test(
      'fulfilled request fetches confirmedAppointmentId as Appointment',
      () async {
        final repository = _ControllerRepository(
          getResults: [
            _request(
              status: BookingRequestStatus.fulfilled,
              version: 8,
              confirmedAppointmentId: 'appointment-9',
            ),
          ],
          appointmentResults: [_appointment()],
        );
        final controller = _controller(repository);
        await controller.openRequest('request-1');
        expect(repository.appointmentIds, ['appointment-9']);
        expect(controller.appointment?.appointmentId, 'appointment-9');
        expect(controller.appointment?.appointmentId, isNot('request-1'));
        expect(controller.appointment?.sourceBookingRequestId, 'request-1');
      },
    );

    test(
      'clear drops lifecycle state/key and ignores late prior-session GET',
      () async {
        final completer = Completer<PatientBookingRequestDetail>();
        final repository = _ControllerRepository(getCompleter: completer);
        final controller = _controller(repository);
        final pending = controller.openRequest('request-1');
        controller.clear();
        expect(controller.result, isNull);
        expect(controller.appointment, isNull);
        expect(controller.pendingIdempotencyKey, isNull);
        completer.complete(_request());
        await pending;
        expect(controller.result, isNull);
        expect(
          controller.lifecycleActivity,
          PatientBookingLifecycleActivity.idle,
        );
      },
    );
  });

  group('request lifecycle widgets', () {
    testWidgets('PENDING_DOCTOR exposes refresh and gated cancel', (
      tester,
    ) async {
      await _pumpRequest(
        tester,
        _request(actions: const [AvailableAction.cancelRequest]),
      );
      expect(find.text('En attente de la réponse du médecin'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('scheduled-care-refresh')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('cancel-booking-request')),
        findsOneWidget,
      );
      await _disposeScreen(tester);
    });

    testWidgets(
      'proposal shows original/proposed actions but no extra cancel',
      (tester) async {
        await _pumpRequest(
          tester,
          _request(
            status: BookingRequestStatus.pendingPatientTimeConfirmation,
            proposal: true,
            actions: const [
              AvailableAction.acceptProposedTime,
              AvailableAction.declineProposedTime,
            ],
          ),
        );
        expect(find.text('Créneau demandé'), findsOneWidget);
        expect(find.text('Créneau proposé par le médecin'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('accept-proposed-time')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('decline-proposed-time')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('cancel-booking-request')),
          findsNothing,
        );
        await _disposeScreen(tester);
      },
    );

    for (final entry in const {
      BookingRequestStatus.cancelledByDoctor: 'Le médecin n’a pas pu accepter',
      BookingRequestStatus.cancelledByPatient: 'Demande annulée',
      BookingRequestStatus.expired: 'Le délai de réponse est terminé',
    }.entries) {
      testWidgets('renders terminal ${entry.key.name}', (tester) async {
        await _pumpRequest(tester, _request(status: entry.key));
        expect(find.text(entry.value), findsWidgets);
        expect(
          find.byKey(const ValueKey('cancel-booking-request')),
          findsNothing,
        );
        await _disposeScreen(tester);
      });
    }

    testWidgets('accept transitions using Appointment identity', (
      tester,
    ) async {
      final proposal = _request(
        status: BookingRequestStatus.pendingPatientTimeConfirmation,
        proposal: true,
        actions: const [
          AvailableAction.acceptProposedTime,
          AvailableAction.declineProposedTime,
        ],
      );
      final fulfilled = _request(
        status: BookingRequestStatus.fulfilled,
        version: 8,
        confirmedAppointmentId: 'appointment-9',
      );
      final repository = _ControllerRepository(
        getResults: [proposal],
        acceptResults: [
          BookingMutationResult(
            request: fulfilled,
            appointment: _appointment(),
            intentCompleted: true,
          ),
        ],
      );
      final controller = _controller(repository);
      await controller.openRequest('request-1');
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: controller,
          child: MaterialApp(
            theme: buildOmniTheme(),
            home: const PendingBookingRequestScreen(requestId: 'request-1'),
          ),
        ),
      );
      final accept = find.byKey(const ValueKey('accept-proposed-time'));
      await tester.ensureVisible(accept);
      await tester.tap(accept);
      await tester.pumpAndSettle();
      expect(find.byType(ConfirmedScheduledAppointmentScreen), findsOneWidget);
      expect(find.text('Votre rendez-vous est confirmé'), findsOneWidget);
      expect(repository.acceptCommands.single.requestId, 'request-1');
      expect(repository.acceptCommands.single.proposalId, 'proposal-1');
      expect(controller.appointment?.appointmentId, 'appointment-9');
      await _disposeScreen(tester);
    });
  });

  group('ProblemDetail lifecycle mapping', () {
    for (final entry in const {
      'NOT_FOUND': ScheduledCareFailureKind.notFound,
      'VERSION_CONFLICT': ScheduledCareFailureKind.versionConflict,
      'REQUEST_STATE_CONFLICT': ScheduledCareFailureKind.requestStateConflict,
      'ACTION_NOT_ALLOWED': ScheduledCareFailureKind.actionNotAllowed,
      'REQUEST_EXPIRED': ScheduledCareFailureKind.requestExpired,
      'IDEMPOTENCY_CONFLICT': ScheduledCareFailureKind.idempotencyConflict,
      'VALIDATION_FAILED': ScheduledCareFailureKind.validation,
    }.entries) {
      test('maps ${entry.key}', () {
        final options = RequestOptions(
          path: '/doctor-booking-requests/request-1',
        );
        final failure = ScheduledCareFailure.from(
          DioException(
            requestOptions: options,
            type: DioExceptionType.badResponse,
            response: Response(
              requestOptions: options,
              statusCode: entry.key == 'NOT_FOUND'
                  ? 404
                  : entry.key == 'VALIDATION_FAILED'
                  ? 422
                  : 409,
              data: {'errorCode': entry.key, 'detail': 'internal'},
            ),
          ),
        );
        expect(failure.kind, entry.value);
        expect(failure.message, isNot(contains('internal')));
      });
    }
  });
}

const _unknownFailure = ScheduledCareFailure(
  kind: ScheduledCareFailureKind.unknownOutcome,
  message: 'Résultat incertain.',
  diagnosticCode: 'UNKNOWN_OUTCOME',
  retryable: true,
);

PatientBookingController _controller(
  _ControllerRepository repository, {
  String Function()? keyFactory,
}) => PatientBookingController(
  repository: repository,
  lifecycleRepository: repository,
  idempotencyKeyFactory: keyFactory ?? () => 'stable-key',
);

Future<void> _pumpRequest(
  WidgetTester tester,
  PatientBookingRequestDetail request,
) async {
  final repository = _ControllerRepository(getResults: [request]);
  final controller = _controller(repository);
  await controller.openRequest('request-1');
  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: controller,
      child: MaterialApp(
        theme: buildOmniTheme(),
        home: const PendingBookingRequestScreen(requestId: 'request-1'),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _disposeScreen(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

PatientBookingRequestDetail _request({
  BookingRequestStatus status = BookingRequestStatus.pendingDoctor,
  int version = 7,
  List<AvailableAction> actions = const [],
  bool proposal = false,
  String? confirmedAppointmentId,
  String? expiryReason,
  DateTime? responseDeadline,
}) => PatientBookingRequestDetail(
  requestId: 'request-1',
  version: version,
  status: status,
  rawStatus: status.wireValue,
  subject: const CareSubject.self(displayName: 'Moi'),
  doctor: const DoctorProjection(
    doctorId: 'doctor-1',
    displayName: 'Dr. Test',
    specialty: 'Médecine générale',
  ),
  cabinet: const BookingCabinetProjection(
    practiceLocationId: 'cabinet-1',
    name: 'Cabinet du Lac',
    address: '10 rue du Lac',
    city: 'Tunis',
    governorate: 'Tunis',
    timezone: 'Africa/Tunis',
  ),
  originalRequestedSlot: RequestedSlot(
    start: DateTime.parse('2027-01-12T08:00:00Z'),
    end: DateTime.parse('2027-01-12T08:30:00Z'),
    durationMinutes: 30,
  ),
  proposedSlot: proposal
      ? ProposedSlot(
          proposalId: 'proposal-1',
          start: DateTime.parse('2027-01-12T09:00:00Z'),
          end: DateTime.parse('2027-01-12T09:30:00Z'),
          proposedAt: DateTime.parse('2027-01-08T12:00:00Z'),
          patientResponseDeadline: DateTime.parse('2027-01-09T12:00:00Z'),
        )
      : null,
  activeSlot:
      status == BookingRequestStatus.pendingDoctor ||
          status == BookingRequestStatus.pendingPatientTimeConfirmation
      ? ActiveSlot(
          start: proposal
              ? DateTime.parse('2027-01-12T09:00:00Z')
              : DateTime.parse('2027-01-12T08:00:00Z'),
          end: proposal
              ? DateTime.parse('2027-01-12T09:30:00Z')
              : DateTime.parse('2027-01-12T08:30:00Z'),
          durationMinutes: 30,
        )
      : null,
  priceQuote: PriceQuote(
    amount: 80,
    currency: 'TND',
    quotedAt: DateTime.parse('2027-01-08T10:00:00Z'),
  ),
  createdAt: DateTime.parse('2027-01-08T10:00:00Z'),
  responseDeadline: responseDeadline ?? DateTime.parse('2027-01-10T12:00:00Z'),
  confirmedAppointmentId: confirmedAppointmentId,
  cancellation: status == BookingRequestStatus.cancelledByPatient
      ? CancellationProjection(
          actor: 'PATIENT',
          reasonCode: 'CHANGE_OF_PLANS',
          cancelledAt: DateTime.parse('2027-01-08T13:00:00Z'),
        )
      : status == BookingRequestStatus.cancelledByDoctor
      ? CancellationProjection(
          actor: 'DOCTOR',
          reasonCode: 'UNAVAILABLE',
          cancelledAt: DateTime.parse('2027-01-08T13:00:00Z'),
        )
      : null,
  expiredAt: status == BookingRequestStatus.expired
      ? DateTime.parse('2027-01-10T12:00:00Z')
      : null,
  expiryReason: expiryReason,
  slotReleased:
      status == BookingRequestStatus.expired ||
      status == BookingRequestStatus.cancelledByPatient ||
      status == BookingRequestStatus.cancelledByDoctor,
  availableActions: actions,
  updatedAt: DateTime.parse('2027-01-08T13:00:00Z'),
);

ConfirmedScheduledAppointment _appointment() => ConfirmedScheduledAppointment(
  appointmentId: 'appointment-9',
  sourceBookingRequestId: 'request-1',
  version: 0,
  status: ScheduledAppointmentStatus.confirmed,
  rawStatus: 'CONFIRMED',
  doctor: const DoctorProjection(
    doctorId: 'doctor-1',
    displayName: 'Dr. Test',
    specialty: 'Médecine générale',
  ),
  subject: const CareSubject.self(displayName: 'Moi'),
  cabinet: const BookingCabinetProjection(
    practiceLocationId: 'cabinet-1',
    name: 'Cabinet du Lac',
    address: '10 rue du Lac',
    city: 'Tunis',
    governorate: 'Tunis',
    timezone: 'Africa/Tunis',
  ),
  slot: ConfirmedAppointmentSlot(
    start: DateTime.parse('2027-01-12T09:00:00Z'),
    end: DateTime.parse('2027-01-12T09:30:00Z'),
    timezone: 'Africa/Tunis',
    durationMinutes: 30,
  ),
  quotedPrice: PriceQuote(
    amount: 80,
    currency: 'TND',
    quotedAt: DateTime.parse('2027-01-08T10:00:00Z'),
  ),
  confirmedAt: DateTime.parse('2027-01-08T13:00:00Z'),
  createdAt: DateTime.parse('2027-01-08T13:00:00Z'),
  updatedAt: DateTime.parse('2027-01-08T13:00:00Z'),
  availableActions: const [ScheduledAppointmentAction.cancelAppointment],
);

Map<String, dynamic> _requestJson({
  String status = 'PENDING_DOCTOR',
  List<String> actions = const ['CANCEL_REQUEST'],
  bool proposal = false,
  String? confirmedAppointmentId,
}) => {
  'requestId': 'request-1',
  'version': 7,
  'status': status,
  'subject': {
    'subjectType': 'SELF',
    'familyMemberId': null,
    'displayName': 'Moi',
    'relationship': null,
  },
  'doctor': {
    'doctorId': 'doctor-1',
    'displayName': 'Dr. Test',
    'specialty': 'Médecine générale',
  },
  'cabinet': {
    'practiceLocationId': 'cabinet-1',
    'name': 'Cabinet du Lac',
    'address': '10 rue du Lac',
    'city': 'Tunis',
    'governorate': 'Tunis',
    'timezone': 'Africa/Tunis',
  },
  'originalRequestedSlot': {
    'start': '2027-01-12T08:00:00Z',
    'end': '2027-01-12T08:30:00Z',
  },
  'proposedSlot': proposal
      ? {
          'proposalId': 'proposal-1',
          'start': '2027-01-12T09:00:00Z',
          'end': '2027-01-12T09:30:00Z',
          'proposedAt': '2027-01-08T12:00:00Z',
          'patientResponseDeadline': '2027-01-09T12:00:00Z',
        }
      : null,
  'activeSlot': {
    'start': '2027-01-12T08:00:00Z',
    'end': '2027-01-12T08:30:00Z',
    'durationMinutes': 30,
  },
  'priceQuote': {
    'amount': 80,
    'currency': 'TND',
    'quotedAt': '2027-01-08T10:00:00Z',
  },
  'createdAt': '2027-01-08T10:00:00Z',
  'responseDeadline': '2027-01-10T12:00:00Z',
  'confirmedAppointmentId': confirmedAppointmentId,
  'cancellation': null,
  'expiredAt': null,
  'expiryReason': null,
  'slotReleased': false,
  'availableActions': actions,
  'updatedAt': '2027-01-08T13:00:00Z',
};

Map<String, dynamic> _appointmentJson({
  String status = 'CONFIRMED',
  String appointmentId = 'appointment-9',
}) => {
  'appointmentId': appointmentId,
  'sourceBookingRequestId': 'request-1',
  'version': 0,
  'status': status,
  'doctor': _requestJson()['doctor'],
  'subject': _requestJson()['subject'],
  'cabinet': _requestJson()['cabinet'],
  'slot': {
    'start': '2027-01-12T09:00:00Z',
    'end': '2027-01-12T09:30:00Z',
    'timezone': 'Africa/Tunis',
    'durationMinutes': 30,
  },
  'quotedPrice': {
    'amount': 80,
    'currency': 'TND',
    'quotedAt': '2027-01-08T10:00:00Z',
  },
  'confirmedAt': '2027-01-08T13:00:00Z',
  'createdAt': '2027-01-08T13:00:00Z',
  'updatedAt': '2027-01-08T13:00:00Z',
  'cancellation': null,
  'intakeStatus': null,
  'availableActions': ['CANCEL_APPOINTMENT'],
};

class _CreationRepository implements ScheduledCareRepositoryContract {
  @override
  Future<PatientBookingRequestDetail> createOrReconcile(
    CreateBookingRequestCommand command, {
    CancelToken? cancelToken,
  }) => throw UnimplementedError();
}

class _ControllerRepository extends _CreationRepository
    implements ScheduledCareLifecycleRepositoryContract {
  _ControllerRepository({
    List<PatientBookingRequestDetail>? getResults,
    List<BookingMutationResult>? cancelResults,
    List<BookingMutationResult>? acceptResults,
    List<BookingMutationResult>? declineResults,
    List<ConfirmedScheduledAppointment>? appointmentResults,
    List<ScheduledCareFailure>? cancelFailures,
    List<ScheduledCareFailure>? acceptFailures,
    List<ScheduledCareFailure>? declineFailures,
    this.getCompleter,
  }) : getResults = [...?getResults],
       cancelResults = [...?cancelResults],
       acceptResults = [...?acceptResults],
       declineResults = [...?declineResults],
       appointmentResults = [...?appointmentResults],
       cancelFailures = [...?cancelFailures],
       acceptFailures = [...?acceptFailures],
       declineFailures = [...?declineFailures];

  final List<PatientBookingRequestDetail> getResults;
  final List<BookingMutationResult> cancelResults;
  final List<BookingMutationResult> acceptResults;
  final List<BookingMutationResult> declineResults;
  final List<ConfirmedScheduledAppointment> appointmentResults;
  final List<ScheduledCareFailure> cancelFailures;
  final List<ScheduledCareFailure> acceptFailures;
  final List<ScheduledCareFailure> declineFailures;
  final Completer<PatientBookingRequestDetail>? getCompleter;
  final List<String> getIds = [];
  final List<String> appointmentIds = [];
  final List<CancelBookingRequestCommand> cancelCommands = [];
  final List<AcceptBookingProposalCommand> acceptCommands = [];
  final List<DeclineBookingProposalCommand> declineCommands = [];

  @override
  Future<PatientBookingRequestDetail> getBookingRequest(
    String requestId, {
    CancelToken? cancelToken,
  }) async {
    getIds.add(requestId);
    if (getCompleter != null) return getCompleter!.future;
    return getResults.removeAt(0);
  }

  @override
  Future<BookingMutationResult> cancelOrReconcile(
    CancelBookingRequestCommand command, {
    CancelToken? cancelToken,
  }) async {
    cancelCommands.add(command);
    if (cancelFailures.isNotEmpty) throw cancelFailures.removeAt(0);
    return cancelResults.removeAt(0);
  }

  @override
  Future<BookingMutationResult> acceptProposalOrReconcile(
    AcceptBookingProposalCommand command, {
    CancelToken? cancelToken,
  }) async {
    acceptCommands.add(command);
    if (acceptFailures.isNotEmpty) throw acceptFailures.removeAt(0);
    return acceptResults.removeAt(0);
  }

  @override
  Future<BookingMutationResult> declineProposalOrReconcile(
    DeclineBookingProposalCommand command, {
    CancelToken? cancelToken,
  }) async {
    declineCommands.add(command);
    if (declineFailures.isNotEmpty) throw declineFailures.removeAt(0);
    return declineResults.removeAt(0);
  }

  @override
  Future<ConfirmedScheduledAppointment> getAppointment(
    String appointmentId, {
    CancelToken? cancelToken,
  }) async {
    appointmentIds.add(appointmentId);
    return appointmentResults.removeAt(0);
  }
}

class _LifecycleApi implements ScheduledCareApi {
  _LifecycleApi({
    List<Object>? cancelResults,
    List<Object>? acceptResults,
    List<Object>? declineResults,
    List<Object>? getResults,
    List<Object>? appointmentResults,
  }) : cancelResults = [...?cancelResults],
       acceptResults = [...?acceptResults],
       declineResults = [...?declineResults],
       getResults = [...?getResults],
       appointmentResults = [...?appointmentResults];

  final List<Object> cancelResults;
  final List<Object> acceptResults;
  final List<Object> declineResults;
  final List<Object> getResults;
  final List<Object> appointmentResults;
  final List<CancelBookingRequestCommand> cancelCommands = [];
  final List<AcceptBookingProposalCommand> acceptCommands = [];
  final List<DeclineBookingProposalCommand> declineCommands = [];
  final List<String> appointmentIds = [];

  T _take<T>(List<Object> values) {
    final value = values.removeAt(0);
    if (value is Exception || value is Error) throw value;
    return value as T;
  }

  @override
  Future<PatientBookingRequestDetail> createBookingRequest(
    CreateBookingRequestCommand command, {
    CancelToken? cancelToken,
  }) => throw UnimplementedError();

  @override
  Future<PatientBookingRequestDetail> getBookingRequest(
    String requestId, {
    CancelToken? cancelToken,
  }) async => _take(getResults);

  @override
  Future<PatientBookingRequestDetail> cancelBookingRequest(
    CancelBookingRequestCommand command, {
    CancelToken? cancelToken,
  }) async {
    cancelCommands.add(command);
    return _take(cancelResults);
  }

  @override
  Future<ProposalAcceptanceResult> acceptProposal(
    AcceptBookingProposalCommand command, {
    CancelToken? cancelToken,
  }) async {
    acceptCommands.add(command);
    return _take(acceptResults);
  }

  @override
  Future<PatientBookingRequestDetail> declineProposal(
    DeclineBookingProposalCommand command, {
    CancelToken? cancelToken,
  }) async {
    declineCommands.add(command);
    return _take(declineResults);
  }

  @override
  Future<ConfirmedScheduledAppointment> getAppointment(
    String appointmentId, {
    CancelToken? cancelToken,
  }) async {
    appointmentIds.add(appointmentId);
    return _take(appointmentResults);
  }
}

class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this.responseBody);

  final Object responseBody;
  String? path;
  Object? body;
  Map<String, dynamic> headers = {};

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    path = options.path;
    body = options.data;
    headers = Map<String, dynamic>.from(options.headers);
    return ResponseBody.fromString(
      jsonEncode(responseBody),
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
  final Map<String, String> values = {};

  @override
  Future<void> delete({required String key}) async => values.remove(key);

  @override
  Future<String?> read({required String key}) async => values[key];

  @override
  Future<void> write({required String key, required String value}) async =>
      values[key] = value;
}

DioException _connectionFailure() => DioException(
  requestOptions: RequestOptions(path: '/doctor-booking-requests'),
  type: DioExceptionType.connectionError,
  error: const SocketExceptionForTest(),
);

class SocketExceptionForTest implements Exception {
  const SocketExceptionForTest();
}

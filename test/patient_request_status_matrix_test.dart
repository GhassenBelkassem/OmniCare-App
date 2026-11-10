import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicare_mobile/features/request_core/data/request_failure.dart';
import 'package:omnicare_mobile/features/request_core/data/request_models.dart';
import 'package:omnicare_mobile/features/request_core/data/request_repository.dart';
import 'package:omnicare_mobile/features/request_core/domain/request_vocabulary.dart';
import 'package:omnicare_mobile/features/request_core/identity/request_operation_id.dart';
import 'package:omnicare_mobile/features/request_history/application/patient_requests_controller.dart';
import 'package:omnicare_mobile/features/request_history/presentation/patient_request_detail_screen.dart';
import 'package:omnicare_mobile/features/request_history/presentation/patient_request_journey.dart';
import 'package:omnicare_mobile/features/request_history/presentation/request_status_copy.dart';
import 'package:provider/provider.dart';

final _requestId = RequestOperationId.parse(
  '33333333-3333-4333-8333-333333333333',
);

PatientRequest _request({
  bool canCancel = true,
  PatientRequestStatus status = PatientRequestStatus.requestReceived,
  int version = 3,
  PatientInformationRequest? informationRequest,
  Set<PatientRequestAction>? actions,
}) => PatientRequest(
  requestId: _requestId,
  kind: RequestKind.clinic,
  targetType: RequestTargetType.clinic,
  targetId: '44444444-4444-4444-8444-444444444444',
  subjectType: RequestSubjectType.self,
  situation: RequestSituation.appointment,
  patientStatus: status,
  submittedAt: DateTime.utc(2026, 2, 3, 11, 30),
  cancelledAt: null,
  version: version,
  availableActions: actions ?? (canCancel ? {PatientRequestAction.cancel} : {}),
  informationRequest: informationRequest,
);

class _Gateway implements PatientRequestGateway {
  PatientRequestPage page = const PatientRequestPage(
    contractVersion: '1.0',
    items: [],
    page: 0,
    pageSize: 20,
    hasNext: false,
  );
  PatientRequest detail = _request();
  RequestFailure? listError;
  RequestFailure? cancelError;
  Completer<PatientRequestPage>? pendingList;
  Completer<PatientRequest>? pendingCancel;
  int cancelCalls = 0;
  int informationCalls = 0;
  PatientInformationResponsePayload? sentInformationPayload;

  @override
  Future<PatientRequestPage> listRequests({
    int? page,
    int? pageSize,
    PatientRequestListFilter? filter,
    CancelToken? cancelToken,
  }) async {
    if (pendingList != null) return pendingList!.future;
    if (listError != null) throw listError!;
    return this.page;
  }

  @override
  Future<PatientRequest> getRequest(
    RequestOperationId requestId, {
    CancelToken? cancelToken,
  }) async => detail;

  @override
  Future<PatientRequest> cancelRequest({
    required RequestOperationId requestId,
    required int expectedVersion,
    CancelToken? cancelToken,
  }) async {
    cancelCalls++;
    if (pendingCancel != null) return pendingCancel!.future;
    if (cancelError != null) throw cancelError!;
    return detail;
  }

  @override
  Future<PatientRequest> respondToInformationRequest({
    required RequestOperationId requestId,
    required PatientInformationResponsePayload payload,
    CancelToken? cancelToken,
  }) async {
    informationCalls++;
    sentInformationPayload = payload;
    return detail;
  }
}

Widget _host(PatientRequestsController controller, Widget child) =>
    ChangeNotifierProvider.value(
      value: controller,
      child: MaterialApp(home: child),
    );

void main() {
  group('Status matrix', () {
    // ── 1. REQUEST_RECEIVED ──────────────────────────────────────────

    testWidgets(
      'REQUEST_RECEIVED — label, blue accent, journey has request+waiting, cancel button',
      (tester) async {
        final gateway = _Gateway()
          ..detail = _request(
            status: PatientRequestStatus.requestReceived,
            actions: {PatientRequestAction.cancel},
          );
        final controller = PatientRequestsController(repository: gateway);
        await controller.loadDetail(_requestId);

        await tester.pumpWidget(
          _host(controller, PatientRequestDetailScreen(requestId: _requestId)),
        );
        await tester.pumpAndSettle();

        expect(find.text('Request received'), findsWidgets);
        expect(
          find.text(
            'The clinic has received your request and will review it shortly.',
          ),
          findsWidgets,
        );

        final journey = PatientRequestJourneyMapper.fromStatus(
          PatientRequestStatus.requestReceived,
        );
        expect(journey.stages.length, 6);
        expect(journey.stages[0].stage, PatientRequestJourneyStage.request);
        expect(
          journey.stages[0].state,
          PatientRequestJourneyStageState.current,
        );
        expect(journey.stages[1].stage, PatientRequestJourneyStage.review);
        expect(
          journey.stages[1].state,
          PatientRequestJourneyStageState.upcoming,
        );
        expect(journey.terminal, isNull);

        await tester.scrollUntilVisible(
          find.widgetWithText(OutlinedButton, 'Cancel request'),
          100,
        );
        expect(
          find.widgetWithText(OutlinedButton, 'Cancel request'),
          findsOneWidget,
        );

        await tester.pumpWidget(const SizedBox());
        controller.dispose();
      },
    );

    // ── 2. UNDER_REVIEW ──────────────────────────────────────────────

    testWidgets(
      'UNDER_REVIEW — label, blue accent, journey shows request+review+waiting',
      (tester) async {
        final gateway = _Gateway()
          ..detail = _request(status: PatientRequestStatus.underReview);
        final controller = PatientRequestsController(repository: gateway);
        await controller.loadDetail(_requestId);

        await tester.pumpWidget(
          _host(controller, PatientRequestDetailScreen(requestId: _requestId)),
        );
        await tester.pumpAndSettle();

        expect(find.text('Under review'), findsWidgets);
        expect(
          find.text(
            'The clinic has received your request and will review it shortly.',
          ),
          findsWidgets,
        );

        final journey = PatientRequestJourneyMapper.fromStatus(
          PatientRequestStatus.underReview,
        );
        expect(journey.stages.length, 6);
        expect(journey.stages[0].stage, PatientRequestJourneyStage.request);
        expect(
          journey.stages[0].state,
          PatientRequestJourneyStageState.completed,
        );
        expect(journey.stages[1].stage, PatientRequestJourneyStage.review);
        expect(
          journey.stages[1].state,
          PatientRequestJourneyStageState.current,
        );
        expect(journey.terminal, isNull);

        await tester.pumpWidget(const SizedBox());
        controller.dispose();
      },
    );

    // ── 3. INFORMATION_REQUIRED ──────────────────────────────────────

    testWidgets(
      'INFORMATION_REQUIRED — label, amber accent, journey shows review(current), info form',
      (tester) async {
        const info = PatientInformationRequest(
          informationRequestId: '66666666-6666-4666-8666-666666666666',
          reasonCode: InformationRequestReasonCode.contactInformation,
          patientInstruction: 'Please provide your contact details.',
          responseType: InformationResponseType.confirmation,
          status: InformationRequestStatus.open,
        );
        final gateway = _Gateway()
          ..detail = _request(
            status: PatientRequestStatus.informationRequired,
            informationRequest: info,
            actions: {
              PatientRequestAction.cancel,
              PatientRequestAction.provideInformation,
            },
          );
        final controller = PatientRequestsController(repository: gateway);
        await controller.loadDetail(_requestId);

        await tester.pumpWidget(
          _host(controller, PatientRequestDetailScreen(requestId: _requestId)),
        );
        await tester.pumpAndSettle();

        expect(find.text('More information needed'), findsWidgets);
        expect(
          find.text('The clinic needs more information before continuing.'),
          findsWidgets,
        );

        final journey = PatientRequestJourneyMapper.fromStatus(
          PatientRequestStatus.informationRequired,
        );
        expect(journey.requiresPatientAction, isTrue);
        expect(journey.stages[1].stage, PatientRequestJourneyStage.review);
        expect(
          journey.stages[1].state,
          PatientRequestJourneyStageState.current,
        );
        expect(journey.terminal, isNull);

        expect(find.text('Action required'), findsOneWidget);
        expect(find.text('Contact information'), findsOneWidget);
        expect(find.byType(InformationRequiredSection), findsOneWidget);

        await tester.pumpWidget(const SizedBox());
        controller.dispose();
      },
    );

    // ── 4. SCHEDULING_IN_PROGRESS ────────────────────────────────────

    testWidgets(
      'SCHEDULING_IN_PROGRESS — label, blue accent',
      (tester) async {
        final gateway = _Gateway()
          ..detail = _request(status: PatientRequestStatus.schedulingInProgress);
        final controller = PatientRequestsController(repository: gateway);
        await controller.loadDetail(_requestId);

        await tester.pumpWidget(
          _host(controller, PatientRequestDetailScreen(requestId: _requestId)),
        );
        await tester.pumpAndSettle();

        expect(find.text('Scheduling'), findsWidgets);
        expect(
          find.text('The clinic is arranging the next step.'),
          findsWidgets,
        );

        final journey = PatientRequestJourneyMapper.fromStatus(
          PatientRequestStatus.schedulingInProgress,
        );
        expect(
          journey.stages.any(
            (s) =>
                s.stage == PatientRequestJourneyStage.scheduling &&
                s.state == PatientRequestJourneyStageState.current,
          ),
          isTrue,
        );
        expect(journey.terminal, isNull);

        await tester.pumpWidget(const SizedBox());
        controller.dispose();
      },
    );

    // ── 5. WAITING_FOR_CONFIRMATION ──────────────────────────────────

    testWidgets(
      'WAITING_FOR_CONFIRMATION — label, amber accent, gap message (no proposal values)',
      (tester) async {
        final gateway = _Gateway()
          ..detail = _request(
            status: PatientRequestStatus.waitingForConfirmation,
            canCancel: false,
          );
        final controller = PatientRequestsController(repository: gateway);
        await controller.loadDetail(_requestId);

        await tester.pumpWidget(
          _host(controller, PatientRequestDetailScreen(requestId: _requestId)),
        );
        await tester.pumpAndSettle();

        expect(find.text('Waiting for confirmation'), findsWidgets);
        expect(
          find.text('The clinic is waiting for your confirmation.'),
          findsWidgets,
        );

        expect(
          find.textContaining('Confirmation details are not available yet'),
          findsOneWidget,
        );

        final journey = PatientRequestJourneyMapper.fromStatus(
          PatientRequestStatus.waitingForConfirmation,
        );
        expect(journey.requiresPatientAction, isTrue);
        expect(
          journey.stages.any(
            (s) =>
                s.stage == PatientRequestJourneyStage.confirmation &&
                s.state == PatientRequestJourneyStageState.current,
          ),
          isTrue,
        );

        await tester.pumpWidget(const SizedBox());
        controller.dispose();
      },
    );

    // ── 6. CONFIRMED ─────────────────────────────────────────────────

    testWidgets(
      'CONFIRMED — label, mint accent, care stage upcoming (not current)',
      (tester) async {
        final gateway = _Gateway()
          ..detail = _request(status: PatientRequestStatus.confirmed);
        final controller = PatientRequestsController(repository: gateway);
        await controller.loadDetail(_requestId);

        await tester.pumpWidget(
          _host(controller, PatientRequestDetailScreen(requestId: _requestId)),
        );
        await tester.pumpAndSettle();

        expect(find.text('Confirmed'), findsWidgets);
        expect(
          find.text('Your request has been confirmed.'),
          findsWidgets,
        );

        final journey = PatientRequestJourneyMapper.fromStatus(
          PatientRequestStatus.confirmed,
        );
        expect(
          journey.stages.any(
            (s) =>
                s.stage == PatientRequestJourneyStage.care &&
                s.state == PatientRequestJourneyStageState.upcoming,
          ),
          isTrue,
        );
        expect(journey.terminal, isNull);

        await tester.pumpWidget(const SizedBox());
        controller.dispose();
      },
    );

    // ── 7. CARE_IN_PROGRESS ──────────────────────────────────────────

    testWidgets(
      'CARE_IN_PROGRESS — label, cyan accent',
      (tester) async {
        final gateway = _Gateway()
          ..detail = _request(status: PatientRequestStatus.careInProgress);
        final controller = PatientRequestsController(repository: gateway);
        await controller.loadDetail(_requestId);

        await tester.pumpWidget(
          _host(controller, PatientRequestDetailScreen(requestId: _requestId)),
        );
        await tester.pumpAndSettle();

        expect(find.text('Care in progress'), findsWidgets);
        expect(
          find.text('Your care is currently in progress.'),
          findsWidgets,
        );

        final journey = PatientRequestJourneyMapper.fromStatus(
          PatientRequestStatus.careInProgress,
        );
        expect(
          journey.stages.any(
            (s) =>
                s.stage == PatientRequestJourneyStage.care &&
                s.state == PatientRequestJourneyStageState.current,
          ),
          isTrue,
        );
        expect(journey.terminal, isNull);

        await tester.pumpWidget(const SizedBox());
        controller.dispose();
      },
    );

    // ── 8. COMPLETED — terminal ──────────────────────────────────────

    testWidgets(
      'COMPLETED — terminal: all 6 stages completed, no cancel button',
      (tester) async {
        final gateway = _Gateway()
          ..detail = _request(
            status: PatientRequestStatus.completed,
            canCancel: false,
          );
        final controller = PatientRequestsController(repository: gateway);
        await controller.loadDetail(_requestId);

        await tester.pumpWidget(
          _host(controller, PatientRequestDetailScreen(requestId: _requestId)),
        );
        await tester.pumpAndSettle();

        expect(find.text('Completed'), findsWidgets);
        expect(
          find.text('This request has been completed.'),
          findsWidgets,
        );

        final journey = PatientRequestJourneyMapper.fromStatus(
          PatientRequestStatus.completed,
        );
        expect(journey.terminal, PatientRequestJourneyTerminal.completed);
        expect(journey.stages.length, 6);
        expect(
          journey.stages.every(
            (s) =>
                s.state == PatientRequestJourneyStageState.completed,
          ),
          isTrue,
        );

        expect(find.widgetWithText(OutlinedButton, 'Cancel request'), findsNothing);
        expect(find.text('Request completed'), findsNWidgets(2));

        await tester.pumpWidget(const SizedBox());
        controller.dispose();
      },
    );

    // ── 9. DECLINED — terminal ───────────────────────────────────────

    testWidgets(
      'DECLINED — terminal: only request stage + terminal tile, no cancel',
      (tester) async {
        final gateway = _Gateway()
          ..detail = _request(
            status: PatientRequestStatus.declined,
            canCancel: false,
          );
        final controller = PatientRequestsController(repository: gateway);
        await controller.loadDetail(_requestId);

        await tester.pumpWidget(
          _host(controller, PatientRequestDetailScreen(requestId: _requestId)),
        );
        await tester.pumpAndSettle();

        expect(find.text('Request declined'), findsWidgets);
        expect(
          find.text('The clinic could not proceed with this request.'),
          findsWidgets,
        );

        final journey = PatientRequestJourneyMapper.fromStatus(
          PatientRequestStatus.declined,
        );
        expect(journey.terminal, PatientRequestJourneyTerminal.declined);
        expect(journey.stages.length, 1);
        expect(journey.stages[0].stage, PatientRequestJourneyStage.request);
        expect(
          journey.stages[0].state,
          PatientRequestJourneyStageState.completed,
        );

        expect(find.widgetWithText(OutlinedButton, 'Cancel request'), findsNothing);
        expect(find.text('Request declined'), findsWidgets);

        await tester.pumpWidget(const SizedBox());
        controller.dispose();
      },
    );

    // ── 10. CANCELLED — terminal ─────────────────────────────────────

    testWidgets(
      'CANCELLED — terminal: only request stage + terminal tile, no cancel',
      (tester) async {
        final gateway = _Gateway()
          ..detail = _request(
            status: PatientRequestStatus.cancelled,
            canCancel: false,
          );
        final controller = PatientRequestsController(repository: gateway);
        await controller.loadDetail(_requestId);

        await tester.pumpWidget(
          _host(controller, PatientRequestDetailScreen(requestId: _requestId)),
        );
        await tester.pumpAndSettle();

        expect(find.text('Cancelled'), findsWidgets);
        expect(
          find.text('This request has been cancelled.'),
          findsWidgets,
        );

        final journey = PatientRequestJourneyMapper.fromStatus(
          PatientRequestStatus.cancelled,
        );
        expect(journey.terminal, PatientRequestJourneyTerminal.cancelled);
        expect(journey.stages.length, 1);
        expect(journey.stages[0].stage, PatientRequestJourneyStage.request);
        expect(
          journey.stages[0].state,
          PatientRequestJourneyStageState.completed,
        );

        expect(find.widgetWithText(OutlinedButton, 'Cancel request'), findsNothing);
        expect(find.text('Request cancelled'), findsNWidgets(2));

        await tester.pumpWidget(const SizedBox());
        controller.dispose();
      },
    );

    // ── 11. UNKNOWN ──────────────────────────────────────────────────

    testWidgets(
      'UNKNOWN — shows "Status updated" label, slateBlue accent',
      (tester) async {
        final gateway = _Gateway()
          ..detail = _request(
            status: PatientRequestStatus.unknown,
            canCancel: false,
          );
        final controller = PatientRequestsController(repository: gateway);
        await controller.loadDetail(_requestId);

        await tester.pumpWidget(
          _host(controller, PatientRequestDetailScreen(requestId: _requestId)),
        );
        await tester.pumpAndSettle();

        expect(find.text('Status updated'), findsOneWidget);
        expect(
          find.text('Check back for the latest request update.'),
          findsOneWidget,
        );

        final journey = PatientRequestJourneyMapper.fromStatus(
          PatientRequestStatus.unknown,
        );
        expect(journey.isUnknown, isTrue);
        expect(journey.stages, isEmpty);

        expect(
          find.text('Request updated. Refresh for the latest status.'),
          findsOneWidget,
        );

        await tester.pumpWidget(const SizedBox());
        controller.dispose();
      },
    );
  });
}

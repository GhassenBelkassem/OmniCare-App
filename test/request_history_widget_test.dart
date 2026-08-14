import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicare_mobile/features/request_core/data/request_failure.dart';
import 'package:omnicare_mobile/features/request_core/data/request_models.dart';
import 'package:omnicare_mobile/features/request_core/data/request_repository.dart';
import 'package:omnicare_mobile/features/request_core/domain/request_vocabulary.dart';
import 'package:omnicare_mobile/features/request_core/identity/request_operation_id.dart';
import 'package:omnicare_mobile/features/home/patient_home_feed.dart';
import 'package:omnicare_mobile/features/request_history/application/patient_requests_controller.dart';
import 'package:omnicare_mobile/features/request_history/presentation/my_requests_screen.dart';
import 'package:omnicare_mobile/features/request_history/presentation/patient_request_detail_screen.dart';
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

PatientRequestListItem _listItem() => PatientRequestListItem(
  requestId: _requestId,
  clinicDisplayName: 'Clinic',
  subjectType: RequestSubjectType.self,
  subjectDisplayName: 'Me',
  relationship: null,
  situation: RequestSituation.appointment,
  patientStatus: PatientRequestStatus.requestReceived,
  submittedAt: DateTime.utc(2026, 2, 3, 11, 30),
  requiresPatientAction: false,
  version: 3,
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
  group('MyRequestsScreen', () {
    testWidgets('shows loading, empty, safe error, and populated content', (
      tester,
    ) async {
      final loadingGateway = _Gateway()..pendingList = Completer();
      final loading = PatientRequestsController(repository: loadingGateway);
      final loadingRequest = loading.loadFirst();
      await tester.pumpWidget(_host(loading, const MyRequestsScreen()));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      loadingGateway.pendingList!.complete(loadingGateway.page);
      await loadingRequest;
      await tester.pumpAndSettle();
      expect(find.text('You have no requests yet.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      loading.dispose();

      final errorGateway = _Gateway()..listError = RequestFailure.unexpected;
      final error = PatientRequestsController(repository: errorGateway);
      await error.loadFirst();
      await tester.pumpWidget(_host(error, const MyRequestsScreen()));
      await tester.pumpAndSettle();
      expect(find.text(RequestFailure.unexpected.message), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      error.dispose();

      final populatedGateway = _Gateway()
        ..page = PatientRequestPage(
          contractVersion: '1.0',
          items: [_listItem()],
          page: 0,
          pageSize: 20,
          hasNext: false,
        );
      final populated = PatientRequestsController(repository: populatedGateway);
      await populated.loadFirst();
      await tester.pumpWidget(_host(populated, const MyRequestsScreen()));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Appointment · Request received'),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Text &&
              widget.data != null &&
              widget.data!.contains('Appointment') &&
              widget.data!.contains('\n'),
        ),
        findsOneWidget,
      );
      expect(find.text('44444444-4444-4444-8444-444444444444'), findsNothing);
      expect(find.text('33333333-3333-4333-8333-333333333333'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      populated.dispose();
    });

    testWidgets('request card opens authoritative detail', (tester) async {
      final gateway = _Gateway()
        ..page = PatientRequestPage(
          contractVersion: '1.0',
          items: [_listItem()],
          page: 0,
          pageSize: 20,
          hasNext: false,
        );
      final controller = PatientRequestsController(repository: gateway);
      await controller.loadFirst();
      await tester.pumpWidget(_host(controller, const MyRequestsScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey(_requestId.value)));
      await tester.pumpAndSettle();
      expect(find.byType(PatientRequestDetailScreen), findsOneWidget);
      expect(find.textContaining('Me'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    });
  });

  group('PatientRequestDetailScreen', () {
    testWidgets('shows safe detail and only backend-authorized cancellation', (
      tester,
    ) async {
      final gateway = _Gateway()..detail = _request(canCancel: false);
      final controller = PatientRequestsController(repository: gateway);
      await controller.loadDetail(_requestId);
      await tester.pumpWidget(
        _host(controller, PatientRequestDetailScreen(requestId: _requestId)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Request received'), findsOneWidget);
      expect(find.textContaining('Appointment'), findsOneWidget);
      expect(find.textContaining('Me'), findsOneWidget);
      expect(find.text('Cancel request'), findsNothing);
      expect(find.text('44444444-4444-4444-8444-444444444444'), findsNothing);
      expect(find.text('33333333-3333-4333-8333-333333333333'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    });

    testWidgets('confirms cancellation and prevents duplicate active action', (
      tester,
    ) async {
      final gateway = _Gateway()..pendingCancel = Completer<PatientRequest>();
      final controller = PatientRequestsController(repository: gateway);
      await controller.loadDetail(_requestId);
      await tester.pumpWidget(
        _host(controller, PatientRequestDetailScreen(requestId: _requestId)),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.widgetWithText(FilledButton, 'Cancel request'),
        100,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Cancel request'));
      await tester.pumpAndSettle();
      expect(find.text('Cancel request?'), findsOneWidget);
      await tester.tap(
        find.widgetWithText(FilledButton, 'Cancel request').last,
      );
      await tester.pump();
      expect(gateway.cancelCalls, 1);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Cancel request').first,
            )
            .onPressed,
        isNull,
      );
      gateway.pendingCancel!.complete(_request(canCancel: false));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(FilledButton, 'Cancel request'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    });

    testWidgets('renders refreshed 409 status with safe feedback', (
      tester,
    ) async {
      final gateway = _Gateway()..detail = _request();
      final controller = PatientRequestsController(repository: gateway);
      await controller.loadDetail(_requestId);
      await tester.pumpWidget(
        _host(controller, PatientRequestDetailScreen(requestId: _requestId)),
      );
      await tester.pumpAndSettle();
      gateway.cancelError = RequestFailure.versionConflict;
      gateway.detail = _request(
        canCancel: false,
        version: 4,
        status: PatientRequestStatus.underReview,
      );
      await tester.scrollUntilVisible(
        find.widgetWithText(FilledButton, 'Cancel request'),
        100,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Cancel request'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(FilledButton, 'Cancel request').last,
      );
      await tester.pumpAndSettle();
      expect(find.text('Under review'), findsOneWidget);
      expect(
        find.text(
          "This request was updated. We've refreshed the latest status.",
        ),
        findsOneWidget,
      );
      expect(find.text('Cancelled'), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Cancel request'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    });

    testWidgets(
      'shows contact information controls and submits a typed preference',
      (tester) async {
        const info = PatientInformationRequest(
          informationRequestId: '66666666-6666-4666-8666-666666666666',
          reasonCode: InformationRequestReasonCode.contactInformation,
          patientInstruction: 'Choose how the clinic should contact you.',
          responseType: InformationResponseType.contactPreference,
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

        expect(find.text('Information required'), findsOneWidget);
        expect(find.text('Contact information'), findsOneWidget);
        expect(
          find.text('Choose how the clinic should contact you.'),
          findsOneWidget,
        );
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Submit information'),
              )
              .onPressed,
          isNull,
        );

        await tester.scrollUntilVisible(find.text('Phone'), 100);
        await tester.tap(find.text('Phone'));
        await tester.tap(find.byType(CheckboxListTile));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.widgetWithText(FilledButton, 'Submit information'),
          100,
        );
        await tester.tap(
          find.widgetWithText(FilledButton, 'Submit information'),
        );
        await tester.pumpAndSettle();

        expect(gateway.informationCalls, 1);
        expect(
          gateway.sentInformationPayload,
          isA<ContactPreferenceInformationResponsePayload>(),
        );
        await tester.pumpWidget(const SizedBox());
        controller.dispose();
      },
    );

    testWidgets('shows safe check-status feedback for ambiguous cancellation', (
      tester,
    ) async {
      final gateway = _Gateway()..detail = _request();
      final controller = PatientRequestsController(repository: gateway);
      await controller.loadDetail(_requestId);
      await tester.pumpWidget(
        _host(controller, PatientRequestDetailScreen(requestId: _requestId)),
      );
      await tester.pumpAndSettle();
      gateway.cancelError = RequestFailure.timedOut;
      await tester.scrollUntilVisible(
        find.widgetWithText(FilledButton, 'Cancel request'),
        100,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Cancel request'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(FilledButton, 'Cancel request').last,
      );
      await tester.pumpAndSettle();
      expect(
        find.text(
          'We could not confirm the cancellation. Refresh to check the latest status.',
        ),
        findsOneWidget,
      );
      expect(find.text('Cancelled'), findsNothing);
      expect(gateway.cancelCalls, 1);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    });
  });

  testWidgets('patient home Mes demandes entry opens My Requests', (
    tester,
  ) async {
    final controller = PatientRequestsController(repository: _Gateway());
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: controller,
        child: MaterialApp(
          home: const PatientHomeFeed(displayName: 'Sarah'),
          routes: {'/m05/requests': (_) => const MyRequestsScreen()},
        ),
      ),
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('my-requests-entry')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const ValueKey('my-requests-entry')));
    await tester.pumpAndSettle();
    expect(find.byType(MyRequestsScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });
}

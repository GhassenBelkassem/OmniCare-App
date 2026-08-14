import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicare_mobile/features/request_core/data/request_failure.dart';
import 'package:omnicare_mobile/features/request_core/data/request_models.dart';
import 'package:omnicare_mobile/features/request_core/data/request_repository.dart';
import 'package:omnicare_mobile/features/request_core/domain/request_vocabulary.dart';
import 'package:omnicare_mobile/features/request_core/identity/request_operation_id.dart';
import 'package:omnicare_mobile/features/request_history/application/patient_requests_controller.dart';

final _id = RequestOperationId.parse('33333333-3333-4333-8333-333333333333');
PatientRequest item({
  int version = 3,
  bool canCancel = true,
  PatientRequestStatus status = PatientRequestStatus.requestReceived,
  PatientInformationRequest? informationRequest,
  Set<PatientRequestAction>? actions,
}) => PatientRequest(
  requestId: _id,
  kind: RequestKind.clinic,
  targetType: RequestTargetType.clinic,
  targetId: '44444444-4444-4444-8444-444444444444',
  subjectType: RequestSubjectType.self,
  situation: RequestSituation.appointment,
  patientStatus: status,
  submittedAt: DateTime.utc(2026),
  cancelledAt: null,
  version: version,
  availableActions: actions ?? (canCancel ? {PatientRequestAction.cancel} : {}),
  informationRequest: informationRequest,
);

PatientRequestListItem listItem({
  int version = 3,
  PatientRequestStatus status = PatientRequestStatus.requestReceived,
}) => PatientRequestListItem(
  requestId: _id,
  clinicDisplayName: 'Clinic',
  subjectType: RequestSubjectType.self,
  subjectDisplayName: 'Me',
  relationship: null,
  situation: RequestSituation.appointment,
  patientStatus: status,
  submittedAt: DateTime.utc(2026),
  requiresPatientAction:
      status == PatientRequestStatus.informationRequired ||
      status == PatientRequestStatus.waitingForConfirmation,
  version: version,
);

class FakeGateway implements PatientRequestGateway {
  int listCalls = 0, detailCalls = 0, cancelCalls = 0, informationCalls = 0;
  int? sentVersion;
  PatientInformationResponsePayload? sentInformationPayload;
  Completer<PatientRequest>? informationCompleter;
  PatientRequestPage page = const PatientRequestPage(
    contractVersion: '1.0',
    items: [],
    page: 0,
    pageSize: 20,
    hasNext: false,
  );
  PatientRequest detail = item();
  RequestFailure? listError;
  RequestFailure? detailError;
  RequestFailure? cancelError;
  Future<PatientRequestPage> Function()? onList;
  final List<Completer<PatientRequestPage>> listCompleters = [];
  final List<Completer<PatientRequest>> detailCompleters = [];
  @override
  Future<PatientRequestPage> listRequests({
    int? page,
    int? pageSize,
    PatientRequestListFilter? filter,
    CancelToken? cancelToken,
  }) async {
    listCalls++;
    if (listCompleters.isNotEmpty) return listCompleters.removeAt(0).future;
    if (listError != null) throw listError!;
    return onList?.call() ?? this.page;
  }

  @override
  Future<PatientRequest> getRequest(
    RequestOperationId id, {
    CancelToken? cancelToken,
  }) async {
    detailCalls++;
    if (detailCompleters.isNotEmpty) return detailCompleters.removeAt(0).future;
    if (detailError != null) throw detailError!;
    return detail;
  }

  @override
  Future<PatientRequest> cancelRequest({
    required RequestOperationId requestId,
    required int expectedVersion,
    CancelToken? cancelToken,
  }) async {
    cancelCalls++;
    sentVersion = expectedVersion;
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
    if (informationCompleter != null) return informationCompleter!.future;
    return detail;
  }
}

void main() {
  group('PatientRequestsController', () {
    late FakeGateway gateway;
    late PatientRequestsController controller;
    setUp(() {
      gateway = FakeGateway();
      controller = PatientRequestsController(repository: gateway);
    });
    tearDown(() => controller.dispose());
    test('loads and preserves backend order', () async {
      gateway.page = PatientRequestPage(
        contractVersion: '1.0',
        items: [listItem()],
        page: 0,
        pageSize: 20,
        hasNext: false,
      );
      await controller.loadFirst();
      expect(controller.status, PatientRequestsStatus.populated);
      expect(controller.items.single.requestId, _id);
    });
    test('empty response is empty state', () async {
      await controller.loadFirst();
      expect(controller.status, PatientRequestsStatus.empty);
    });
    test('does not paginate without hasNext', () async {
      await controller.loadFirst();
      await controller.loadMore();
      expect(gateway.listCalls, 1);
    });
    test('uses backend action and exact detail version to cancel', () async {
      gateway.detail = item(version: 8);
      await controller.loadDetail(_id);
      await controller.cancelDetail();
      expect(gateway.cancelCalls, 1);
      expect(gateway.sentVersion, 8);
    });
    test('does not cancel when backend omits CANCEL', () async {
      gateway.detail = item(canCancel: false);
      await controller.loadDetail(_id);
      await controller.cancelDetail();
      expect(gateway.cancelCalls, 0);
    });
    test('stale list result cannot overwrite refresh', () async {
      final old = Completer<PatientRequestPage>();
      final fresh = Completer<PatientRequestPage>();
      gateway.listCompleters.addAll([old, fresh]);
      final first = controller.loadFirst();
      final refresh = controller.loadFirst();
      fresh.complete(
        PatientRequestPage(
          contractVersion: '1.0',
          items: [listItem(version: 2)],
          page: 0,
          pageSize: 20,
          hasNext: false,
        ),
      );
      await refresh;
      old.complete(
        PatientRequestPage(
          contractVersion: '1.0',
          items: [listItem(version: 1)],
          page: 0,
          pageSize: 20,
          hasNext: false,
        ),
      );
      await first;
      expect(controller.items.single.version, 2);
    });
    test('detail A cannot overwrite later detail B', () async {
      final a = Completer<PatientRequest>();
      final b = Completer<PatientRequest>();
      gateway.detailCompleters.addAll([a, b]);
      final first = controller.loadDetail(_id);
      final second = controller.loadDetail(
        RequestOperationId.parse('55555555-5555-4555-8555-555555555555'),
      );
      b.complete(item(version: 2));
      await second;
      a.complete(item(version: 1));
      await first;
      expect(controller.detail!.version, 2);
    });
    test('stale pagination cannot append after refresh', () async {
      gateway.page = PatientRequestPage(
        contractVersion: '1.0',
        items: [listItem(version: 1)],
        page: 0,
        pageSize: 20,
        hasNext: true,
      );
      await controller.loadFirst();
      final oldPage = Completer<PatientRequestPage>();
      final refreshed = Completer<PatientRequestPage>();
      gateway.listCompleters.addAll([oldPage, refreshed]);
      final more = controller.loadMore();
      final refresh = controller.loadFirst();
      refreshed.complete(
        PatientRequestPage(
          contractVersion: '1.0',
          items: [listItem(version: 4)],
          page: 0,
          pageSize: 20,
          hasNext: false,
        ),
      );
      await refresh;
      oldPage.complete(
        PatientRequestPage(
          contractVersion: '1.0',
          items: [listItem(version: 2)],
          page: 1,
          pageSize: 20,
          hasNext: false,
        ),
      );
      await more;
      expect(controller.items, hasLength(1));
      expect(controller.items.single.version, 4);
    });
    test('duplicate load more makes one next-page request', () async {
      gateway.page = PatientRequestPage(
        contractVersion: '1.0',
        items: [listItem()],
        page: 0,
        pageSize: 20,
        hasNext: true,
      );
      await controller.loadFirst();
      final next = Completer<PatientRequestPage>();
      gateway.listCompleters.add(next);
      final first = controller.loadMore();
      final duplicate = controller.loadMore();
      expect(gateway.listCalls, 2);
      next.complete(
        const PatientRequestPage(
          contractVersion: '1.0',
          items: [],
          page: 1,
          pageSize: 20,
          hasNext: false,
        ),
      );
      await Future.wait([first, duplicate]);
    });
    test(
      '409 refreshes authoritative detail and gives safe feedback',
      () async {
        gateway.detail = item(version: 3, canCancel: true);
        await controller.loadDetail(_id);
        gateway.cancelError = RequestFailure.versionConflict;
        gateway.detail = item(
          version: 4,
          canCancel: false,
          status: PatientRequestStatus.underReview,
        );
        await controller.cancelDetail();
        expect(gateway.cancelCalls, 1);
        expect(gateway.detailCalls, 2);
        expect(controller.detail!.version, 4);
        expect(
          controller.detail!.patientStatus,
          PatientRequestStatus.underReview,
        );
        expect(controller.detail!.availableActions, isEmpty);
        expect(
          controller.cancellationNotice,
          "This request was updated. We've refreshed the latest status.",
        );
      },
    );
    test(
      '409 never retries cancellation when CANCEL remains available',
      () async {
        gateway.detail = item(version: 3, canCancel: true);
        await controller.loadDetail(_id);
        gateway.cancelError = RequestFailure.versionConflict;
        gateway.detail = item(version: 4, canCancel: true);
        await controller.cancelDetail();
        expect(gateway.cancelCalls, 1);
        expect(controller.detail!.version, 4);
        expect(
          controller.detail!.availableActions,
          contains(PatientRequestAction.cancel),
        );
      },
    );
    test('ambiguous cancellation does not retry or fake success', () async {
      gateway.detail = item(version: 3, canCancel: true);
      await controller.loadDetail(_id);
      gateway.cancelError = RequestFailure.timedOut;
      await controller.cancelDetail();
      expect(gateway.cancelCalls, 1);
      expect(controller.detail!.version, 3);
      expect(
        controller.cancellationNotice,
        'We could not confirm the cancellation. Refresh to check the latest status.',
      );
    });
    test(
      'information response uses structured payload and blocks duplicate tap',
      () async {
        final info = const PatientInformationRequest(
          informationRequestId: '66666666-6666-4666-8666-666666666666',
          reasonCode: InformationRequestReasonCode.availabilityInformation,
          patientInstruction: 'Please confirm which weekday you are available.',
          responseType: InformationResponseType.availabilityWindows,
          status: InformationRequestStatus.open,
        );
        gateway.detail = item(
          version: 9,
          status: PatientRequestStatus.informationRequired,
          informationRequest: info,
          actions: {
            PatientRequestAction.cancel,
            PatientRequestAction.provideInformation,
          },
        );
        gateway.informationCompleter = Completer<PatientRequest>();
        await controller.loadDetail(_id);

        final first = controller.submitInformationResponse(
          confirmed: true,
          availabilityWeekdays: {OperationalWeekday.monday},
        );
        final duplicate = controller.submitInformationResponse(
          confirmed: true,
          availabilityWeekdays: {OperationalWeekday.tuesday},
        );
        expect(gateway.informationCalls, 1);
        expect(gateway.sentInformationPayload!.expectedVersion, 9);
        expect(gateway.sentInformationPayload!.availabilityWeekdays, {
          OperationalWeekday.monday,
        });

        gateway.detail = item(
          version: 10,
          canCancel: true,
          status: PatientRequestStatus.underReview,
        );
        gateway.informationCompleter!.complete(gateway.detail);
        await Future.wait([first, duplicate]);
        expect(
          controller.detail!.patientStatus,
          PatientRequestStatus.underReview,
        );
      },
    );
    test('user-facing failures redact raw server text', () async {
      gateway.listError = RequestFailure.unexpected;
      await controller.loadFirst();
      expect(controller.listFailure!.message, isNot(contains('urn:')));
      expect(
        controller.listFailure!.message,
        isNot(contains('OptimisticLockException')),
      );
    });
  });
}

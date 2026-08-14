import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omnicare_mobile/features/clinic/application/clinic_operational_controller.dart';
import 'package:omnicare_mobile/features/clinic/data/clinic_failure.dart';
import 'package:omnicare_mobile/features/clinic/data/clinic_models.dart';
import 'package:omnicare_mobile/features/clinic/data/clinic_repository.dart';

class _OperationalRepository implements ClinicRepository {
  ClinicSlice<ClinicTaskSummary> queue = _taskPage();
  ClinicSlice<ClinicTaskSummary> tasks = _taskPage(items: const []);
  ClinicSlice<ClinicHandoverSummary> handovers = _handoverPage();
  Object? queueError;
  int queueCalls = 0;
  int taskCalls = 0;
  int handoverCalls = 0;

  @override
  Future<ClinicAccessFamily> resolveAccessFamily({CancelToken? cancelToken}) =>
      throw UnimplementedError();

  @override
  Future<ClinicMembershipDirectory> loadMemberships({
    CancelToken? cancelToken,
  }) => throw UnimplementedError();

  @override
  Future<ClinicBootstrap> loadBootstrap(
    String clinicId, {
    CancelToken? cancelToken,
  }) => throw UnimplementedError();

  @override
  Future<ClinicSlice<ClinicTaskSummary>> loadPositionQueue(
    String clinicId, {
    int page = 0,
    int pageSize = 20,
    CancelToken? cancelToken,
  }) async {
    queueCalls++;
    if (queueError != null) throw queueError!;
    return queue;
  }

  @override
  Future<ClinicSlice<ClinicTaskSummary>> loadMyTasks(
    String clinicId, {
    int page = 0,
    int pageSize = 20,
    CancelToken? cancelToken,
  }) async {
    taskCalls++;
    return tasks;
  }

  @override
  Future<ClinicTaskDetail> loadTaskDetail(
    String clinicId,
    String taskId, {
    CancelToken? cancelToken,
  }) => throw UnimplementedError();

  @override
  Future<ClinicTaskDetail> acknowledgeTask(
    String clinicId,
    String taskId, {
    required int expectedVersion,
    CancelToken? cancelToken,
  }) => throw UnimplementedError();

  @override
  Future<ClinicTaskDetail> startTask(
    String clinicId,
    String taskId, {
    required int expectedVersion,
    CancelToken? cancelToken,
  }) => throw UnimplementedError();

  @override
  Future<ClinicTaskDetail> blockTask(
    String clinicId,
    String taskId, {
    required ClinicTaskBlockedReason reason,
    required int expectedVersion,
    CancelToken? cancelToken,
  }) => throw UnimplementedError();

  @override
  Future<ClinicTaskDetail> unblockTask(
    String clinicId,
    String taskId, {
    required int expectedVersion,
    CancelToken? cancelToken,
  }) => throw UnimplementedError();

  @override
  Future<ClinicTaskDetail> completeTask(
    String clinicId,
    String taskId, {
    required int expectedVersion,
    CancelToken? cancelToken,
  }) => throw UnimplementedError();

  @override
  Future<ClinicSlice<ClinicHandoverTarget>> loadHandoverTargets(
    String clinicId,
    String taskId, {
    int page = 0,
    int pageSize = 20,
    CancelToken? cancelToken,
  }) => throw UnimplementedError();

  @override
  Future<ClinicHandoverSummary> initiateHandover(
    String clinicId,
    String taskId, {
    required String toMembershipId,
    required ClinicHandoverReason reason,
    required int expectedTaskVersion,
    CancelToken? cancelToken,
  }) => throw UnimplementedError();

  @override
  Future<ClinicHandoverSummary> loadHandoverDetail(
    String clinicId,
    String handoverId, {
    CancelToken? cancelToken,
  }) => throw UnimplementedError();

  @override
  Future<ClinicHandoverSummary> acceptHandover(
    String clinicId,
    String handoverId, {
    CancelToken? cancelToken,
  }) => throw UnimplementedError();

  @override
  Future<ClinicHandoverSummary> declineHandover(
    String clinicId,
    String handoverId, {
    CancelToken? cancelToken,
  }) => throw UnimplementedError();

  @override
  Future<ClinicHandoverSummary> cancelHandover(
    String clinicId,
    String handoverId, {
    CancelToken? cancelToken,
  }) => throw UnimplementedError();

  @override
  Future<ClinicCaseDetail> loadCaseDetail(
    String clinicId,
    String caseId, {
    CancelToken? cancelToken,
  }) => throw UnimplementedError();

  @override
  Future<ClinicCaseDetail> startReview(
    String clinicId,
    String caseId, {
    required int expectedVersion,
    CancelToken? cancelToken,
  }) => throw UnimplementedError();

  @override
  Future<ClinicCaseDetail> requestInformation(
    String clinicId,
    String caseId, {
    required int expectedVersion,
    required ClinicInformationRequestReason reason,
    String? patientInstruction,
    CancelToken? cancelToken,
  }) => throw UnimplementedError();

  @override
  Future<ClinicCaseDetail> readyForPlanning(
    String clinicId,
    String caseId, {
    required int expectedVersion,
    CancelToken? cancelToken,
  }) => throw UnimplementedError();

  @override
  Future<ClinicCaseDetail> declineCase(
    String clinicId,
    String caseId, {
    required int expectedVersion,
    required ClinicCaseDeclineReason reason,
    CancelToken? cancelToken,
  }) => throw UnimplementedError();

  @override
  Future<ClinicSlice<ClinicHandoverSummary>> loadHandovers(
    String clinicId, {
    required bool incoming,
    int page = 0,
    int pageSize = 20,
    CancelToken? cancelToken,
  }) async {
    handoverCalls++;
    return handovers;
  }
}

void main() {
  test(
    'parses bounded task Slice and keeps situation separate from priority',
    () {
      final task = ClinicTaskSummary.fromJson(_taskJson());
      final page = _taskPage();

      expect(page.page, 0);
      expect(page.pageSize, 20);
      expect(page.hasNext, isTrue);
      expect(task.priority, ClinicOperationalPriority.critical);
      expect(task.caseContext.situation, ClinicRequestSituation.appointment);
      expect(task.priority.label, 'Critical');
      expect(task.caseContext.situation.label, 'Appointment');
    },
  );

  test('maps operational labels without exposing raw enum strings', () {
    expect(ClinicTaskStatus.assigned.label, 'Awaiting acknowledgement');
    expect(ClinicTaskStatus.acknowledged.label, 'Ready to start');
    expect(ClinicTaskStatus.inProgress.label, 'In progress');
    expect(ClinicTaskStatus.blocked.label, 'Blocked');
    expect(ClinicOperationalPriority.critical.label, 'Critical');
  });

  test('acknowledgement deadline semantics are deterministic', () {
    final due = DateTime.utc(2026, 8, 13, 10);
    final nowAfterDue = DateTime.utc(2026, 8, 13, 10, 1);

    expect(
      ClinicDeadlineSemantics.isAcknowledgementOverdue(
        acknowledgementDueAt: due,
        acknowledgedAt: null,
        now: nowAfterDue,
      ),
      isTrue,
    );
    expect(
      ClinicDeadlineSemantics.isAcknowledgementOverdue(
        acknowledgementDueAt: due,
        acknowledgedAt: DateTime.utc(2026, 8, 13, 9, 59),
        now: nowAfterDue,
      ),
      isFalse,
    );
    expect(
      ClinicDeadlineSemantics.isAcknowledgementOverdue(
        acknowledgementDueAt: due,
        acknowledgedAt: DateTime.utc(2026, 8, 13, 10, 1),
        now: DateTime.utc(2026, 8, 13, 12),
      ),
      isTrue,
    );
  });

  test(
    'operational controller distinguishes loading, empty, error and refresh',
    () async {
      final repository = _OperationalRepository();
      final controller = ClinicOperationalController(repository: repository);

      final load = controller.loadPositionQueue('clinic-1');
      expect(controller.positionQueue.status, ClinicReadStatus.loading);
      await load;
      expect(controller.positionQueue.status, ClinicReadStatus.content);
      expect(controller.positionQueue.items, hasLength(1));

      await controller.loadMyTasks('clinic-1');
      expect(controller.myTasks.status, ClinicReadStatus.empty);

      repository.queueError = ClinicFailure.networkUnavailable;
      await controller.loadPositionQueue('clinic-1', refresh: true);
      expect(controller.positionQueue.status, ClinicReadStatus.error);
      expect(controller.positionQueue.failure!.message, contains('Connection'));
      expect(
        controller.positionQueue.failure!.message,
        isNot(contains('detail')),
      );

      repository.queueError = null;
      await controller.loadPositionQueue('clinic-1', refresh: true);
      expect(controller.positionQueue.status, ClinicReadStatus.content);
      expect(repository.queueCalls, 3);
    },
  );

  test('handover foundation uses bounded incoming Slice reads', () async {
    final repository = _OperationalRepository();
    final controller = ClinicOperationalController(repository: repository);

    await controller.loadIncomingHandovers('clinic-1');

    expect(controller.incomingHandovers.status, ClinicReadStatus.empty);
    expect(controller.incomingHandovers.hasNext, isFalse);
    expect(repository.handoverCalls, 1);
  });
}

ClinicSlice<ClinicTaskSummary> _taskPage({List<ClinicTaskSummary>? items}) {
  return ClinicSlice<ClinicTaskSummary>(
    items: items ?? [ClinicTaskSummary.fromJson(_taskJson())],
    page: 0,
    pageSize: 20,
    hasNext: items == null,
    generatedAt: DateTime.utc(2026, 8, 13, 10),
    contractVersion: '1.0',
  );
}

ClinicSlice<ClinicHandoverSummary> _handoverPage() {
  return ClinicSlice<ClinicHandoverSummary>(
    items: const [],
    page: 0,
    pageSize: 20,
    hasNext: false,
    generatedAt: DateTime.utc(2026, 8, 13, 10),
  );
}

Map<String, dynamic> _taskJson() {
  return {
    'taskId': 'task-1',
    'caseId': 'case-1',
    'taskType': 'ADMINISTRATIVE_REVIEW',
    'responsibilityType': 'ADMISSIONS',
    'status': 'ASSIGNED',
    'priority': 'CRITICAL',
    'blocking': false,
    'acknowledgementRequired': true,
    'acknowledgementDueAt': '2026-08-13T10:00:00Z',
    'dueAt': '2026-08-13T12:00:00Z',
    'assignedPositionId': 'position-1',
    'assignedMembershipId': null,
    'createdAt': '2026-08-13T09:00:00Z',
    'updatedAt': '2026-08-13T09:01:00Z',
    'version': 4,
    'caseContext': {
      'caseId': 'case-1',
      'sourceRequestId': 'request-1',
      'intakeStatus': 'RECEIVED',
      'situation': 'APPOINTMENT',
      'priority': 'CRITICAL',
      'currentStepKey': 'ADMINISTRATIVE_REVIEW',
      'submittedAt': '2026-08-13T08:59:00Z',
      'hasOpenRoutingIncident': false,
    },
  };
}

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:omnicare_mobile/core/network/app_http_client.dart';
import 'package:omnicare_mobile/core/storage/secure_token_store.dart';
import 'package:omnicare_mobile/features/clinic/application/clinic_context_controller.dart';
import 'package:omnicare_mobile/features/clinic/application/clinic_operational_controller.dart';
import 'package:omnicare_mobile/features/clinic/data/clinic_api.dart';
import 'package:omnicare_mobile/features/clinic/data/clinic_failure.dart';
import 'package:omnicare_mobile/features/clinic/data/clinic_models.dart';
import 'package:omnicare_mobile/features/clinic/data/clinic_repository.dart';
import 'package:omnicare_mobile/features/clinic/screens/clinic_task_detail_screen.dart';
import 'package:omnicare_mobile/features/clinic/storage/clinic_selection_store.dart';

const _clinicA = '11111111-1111-4111-8111-111111111111';
const _clinicB = '22222222-2222-4222-8222-222222222222';
const _membershipId = '33333333-3333-4333-8333-333333333333';
const _taskA = '44444444-4444-4444-8444-444444444444';
const _taskB = '55555555-5555-4555-8555-555555555555';
const _caseId = '66666666-6666-4666-8666-666666666666';
const _requestId = '77777777-7777-4777-8777-777777777777';
const _positionId = '88888888-8888-4888-8888-888888888888';

class _SecureBackend implements SecureTokenStorageBackend {
  final Map<String, String> values = <String, String>{};

  @override
  Future<String?> read({required String key}) async => values[key];

  @override
  Future<void> write({required String key, required String value}) async {
    values[key] = value;
  }

  @override
  Future<void> delete({required String key}) async {
    values.remove(key);
  }
}

class _ExitRepository extends ClinicRepository {
  _ExitRepository()
    : super(
        ClinicApi(
          AppHttpClient(
            tokenStore: SecureTokenStore(backend: _SecureBackend()),
            baseUrl: 'https://api.test',
            dio: Dio(),
            refreshDio: Dio(),
          ),
        ),
      );

  final Map<String, ClinicSlice<ClinicTaskSummary>> queues = {
    _clinicA: _taskPage([_summary(taskId: _taskA)]),
    _clinicB: _taskPage([_summary(taskId: _taskB)], hasNext: false),
  };
  final Map<String, ClinicTaskDetail> details = {
    _taskA: _detail(taskId: _taskA),
    _taskB: _detail(taskId: _taskB),
  };
  final Map<String, ClinicCaseDetail> caseDetails = {_caseId: _caseDetail()};
  ClinicSlice<ClinicTaskSummary> myTasks = _taskPage(const []);
  final List<String> queueRequests = <String>[];
  final List<String> detailRequests = <String>[];
  Completer<ClinicSlice<ClinicTaskSummary>>? nextQueuePage;
  Object? startError;
  int myTaskCalls = 0;
  int handoverCalls = 0;

  @override
  Future<ClinicAccessFamily> resolveAccessFamily({CancelToken? cancelToken}) {
    return Future.value(ClinicAccessFamily.clinic);
  }

  @override
  Future<ClinicMembershipDirectory> loadMemberships({
    CancelToken? cancelToken,
  }) {
    return Future.value(
      ClinicMembershipDirectory(
        activeMemberships: [
          ClinicMembershipSummary.fromJson({
            'clinicId': _clinicA,
            'clinicName': 'OmniCare Clinic',
            'membershipId': _membershipId,
            'professionalRole': 'CLINIC_MEDECIN',
            'membershipStatus': 'ACTIVE',
            'clinicStatus': 'ACTIVE',
            'version': 1,
          }),
        ],
        unavailableMemberships: const [],
      ),
    );
  }

  @override
  Future<ClinicBootstrap> loadBootstrap(
    String clinicId, {
    CancelToken? cancelToken,
  }) {
    return Future.value(_bootstrap(clinicId));
  }

  @override
  Future<ClinicSlice<ClinicTaskSummary>> loadPositionQueue(
    String clinicId, {
    int page = 0,
    int pageSize = 20,
    CancelToken? cancelToken,
  }) {
    queueRequests.add('$clinicId:$page');
    final pending = nextQueuePage;
    if (page == 1 && pending != null) return pending.future;
    return Future.value(queues[clinicId] ?? _taskPage(const []));
  }

  @override
  Future<ClinicSlice<ClinicTaskSummary>> loadMyTasks(
    String clinicId, {
    int page = 0,
    int pageSize = 20,
    CancelToken? cancelToken,
  }) {
    myTaskCalls++;
    return Future.value(myTasks);
  }

  @override
  Future<ClinicTaskDetail> loadTaskDetail(
    String clinicId,
    String taskId, {
    CancelToken? cancelToken,
  }) {
    detailRequests.add('$clinicId:$taskId');
    return Future.value(details[taskId]!);
  }

  @override
  Future<ClinicTaskDetail> startTask(
    String clinicId,
    String taskId, {
    required int expectedVersion,
    CancelToken? cancelToken,
  }) {
    final error = startError;
    if (error != null) return Future.error(error);
    return Future.value(details[taskId]!);
  }

  @override
  Future<ClinicTaskDetail> acknowledgeTask(
    String clinicId,
    String taskId, {
    required int expectedVersion,
    CancelToken? cancelToken,
  }) {
    return Future.value(details[taskId]!);
  }

  @override
  Future<ClinicTaskDetail> completeTask(
    String clinicId,
    String taskId, {
    required int expectedVersion,
    CancelToken? cancelToken,
  }) {
    return Future.value(details[taskId]!);
  }

  @override
  Future<ClinicCaseDetail> loadCaseDetail(
    String clinicId,
    String caseId, {
    CancelToken? cancelToken,
  }) {
    return Future.value(caseDetails[caseId]!);
  }

  @override
  Future<ClinicCaseDetail> startReview(
    String clinicId,
    String caseId, {
    required int expectedVersion,
    CancelToken? cancelToken,
  }) {
    return Future.value(caseDetails[caseId]!);
  }

  @override
  Future<ClinicCaseDetail> readyForPlanning(
    String clinicId,
    String caseId, {
    required int expectedVersion,
    CancelToken? cancelToken,
  }) {
    return Future.value(caseDetails[caseId]!);
  }

  @override
  Future<ClinicSlice<ClinicHandoverSummary>> loadHandovers(
    String clinicId, {
    required bool incoming,
    int page = 0,
    int pageSize = 20,
    CancelToken? cancelToken,
  }) {
    handoverCalls++;
    return Future.value(
      ClinicSlice<ClinicHandoverSummary>(
        items: const [],
        page: page,
        pageSize: pageSize,
        hasNext: false,
        generatedAt: DateTime.utc(2026, 8, 13, 10),
      ),
    );
  }
}

void main() {
  test('case status and workflow step expose safe display labels', () {
    final task = _detail();

    expect(task.caseContext.intakeStatusLabel, 'Received');
    expect(task.caseContext.currentStepLabel, 'Request coordination');
    expect(task.caseContext.intakeStatusLabel, isNot(contains('_')));
    expect(task.caseContext.currentStepLabel, isNot(contains('_')));
  });

  test(
    'foreground refresh drops foreign detail and refreshes only opened lists',
    () async {
      final repository = _ExitRepository();
      final controller = ClinicOperationalController(repository: repository);

      await controller.loadPositionQueue(_clinicA);
      await controller.loadTaskDetail(_clinicA, _taskA);
      await controller.refreshLoaded(_clinicB);

      expect(repository.queueRequests, ['$_clinicA:0', '$_clinicB:0']);
      expect(repository.myTaskCalls, 0);
      expect(repository.handoverCalls, 0);
      expect(repository.detailRequests, ['$_clinicA:$_taskA']);
      expect(controller.taskDetail.task, isNull);
      expect(controller.taskDetail.status, ClinicReadStatus.error);
      expect(
        controller.taskDetail.failure?.diagnosticCode,
        'CLINIC_TASK_UNAVAILABLE',
      );
      expect(controller.positionQueue.items.single.taskId, _taskB);
    },
  );

  test(
    'bounded load-more is single-flight under rapid repeated calls',
    () async {
      final repository = _ExitRepository();
      final controller = ClinicOperationalController(repository: repository);
      await controller.loadPositionQueue(_clinicA);

      final nextPage = Completer<ClinicSlice<ClinicTaskSummary>>();
      repository.nextQueuePage = nextPage;
      final first = controller.loadNextPositionQueue();
      final second = controller.loadNextPositionQueue();

      expect(
        repository.queueRequests.where((call) => call.endsWith(':1')),
        hasLength(1),
      );
      expect(controller.positionQueue.isBusy, isTrue);

      nextPage.complete(
        _taskPage([_summary(taskId: _taskB)], page: 1, hasNext: false),
      );
      await Future.wait([first, second]);
      expect(controller.positionQueue.items, hasLength(2));
    },
  );

  test('network-failed command refetches authoritative task state', () async {
    final repository = _ExitRepository();
    final controller = ClinicOperationalController(repository: repository);
    repository.details[_taskA] = _detail(
      taskId: _taskA,
      status: 'ACKNOWLEDGED',
      startedAt: null,
      version: 4,
    );
    await controller.loadTaskDetail(_clinicA, _taskA);

    repository
      ..startError = ClinicFailure.networkUnavailable
      ..details[_taskA] = _detail(
        taskId: _taskA,
        status: 'IN_PROGRESS',
        startedAt: '2026-08-13T10:10:00Z',
        version: 5,
      );

    final result = await controller.startTask(
      _clinicA,
      controller.taskDetail.task!,
    );

    expect(result.succeeded, isFalse);
    expect(result.failure, ClinicFailure.networkUnavailable);
    expect(repository.detailRequests, [
      '$_clinicA:$_taskA',
      '$_clinicA:$_taskA',
    ]);
    expect(controller.taskDetail.task?.status, ClinicTaskStatus.inProgress);
    expect(controller.taskDetail.task?.version, 5);
  });

  test(
    'connected queue-to-coordination happy path uses backend snapshots',
    () async {
      final repository = _ExitRepository();
      final controller = ClinicOperationalController(repository: repository);
      repository
        ..queues[_clinicA] = _taskPage([
          _summary(
            taskId: _taskA,
            taskType: 'ADMINISTRATIVE_REVIEW',
            status: 'ASSIGNED',
            assignedMembershipId: null,
            acknowledgedAt: null,
            startedAt: null,
            version: 1,
          ),
        ], hasNext: false)
        ..details[_taskA] = _detail(
          taskId: _taskA,
          taskType: 'ADMINISTRATIVE_REVIEW',
          status: 'ASSIGNED',
          assignedMembershipId: null,
          acknowledgedAt: null,
          startedAt: null,
          version: 1,
        )
        ..caseDetails[_caseId] = _caseDetail(
          status: 'RECEIVED',
          actions: const ['START_REVIEW'],
          version: 10,
        );

      await controller.loadPositionQueue(_clinicA);
      await controller.loadTaskDetail(_clinicA, _taskA);

      repository
        ..queues[_clinicA] = _taskPage(const [], hasNext: false)
        ..details[_taskA] = _detail(
          taskId: _taskA,
          taskType: 'ADMINISTRATIVE_REVIEW',
          status: 'ACKNOWLEDGED',
          startedAt: null,
          version: 2,
        )
        ..myTasks = _taskPage([
          _summary(
            taskId: _taskA,
            taskType: 'ADMINISTRATIVE_REVIEW',
            status: 'ACKNOWLEDGED',
            startedAt: null,
            version: 2,
          ),
        ], hasNext: false);
      expect(
        (await controller.acknowledgeTask(
          _clinicA,
          controller.taskDetail.task!,
        )).succeeded,
        isTrue,
      );
      expect(controller.positionQueue.items, isEmpty);
      expect(controller.myTasks.items.single.taskId, _taskA);

      repository
        ..details[_taskA] = _detail(
          taskId: _taskA,
          taskType: 'ADMINISTRATIVE_REVIEW',
          status: 'IN_PROGRESS',
          version: 3,
        )
        ..myTasks = _taskPage([
          _summary(
            taskId: _taskA,
            taskType: 'ADMINISTRATIVE_REVIEW',
            status: 'IN_PROGRESS',
            version: 3,
          ),
        ], hasNext: false);
      expect(
        (await controller.startTask(
          _clinicA,
          controller.taskDetail.task!,
        )).succeeded,
        isTrue,
      );

      repository.caseDetails[_caseId] = _caseDetail(
        status: 'UNDER_ADMIN_REVIEW',
        actions: const ['READY_FOR_PLANNING'],
        version: 11,
      );
      expect(
        (await controller.startReview(
          _clinicA,
          controller.taskDetail.task!,
          controller.taskDetail.caseDetail!,
        )).succeeded,
        isTrue,
      );
      expect(
        controller.taskDetail.caseDetail?.administrativeStatus,
        ClinicCaseStatus.underAdminReview,
      );

      repository
        ..details[_taskA] = _detail(
          taskId: _taskA,
          taskType: 'ADMINISTRATIVE_REVIEW',
          status: 'COMPLETED',
          completedAt: '2026-08-13T10:20:00Z',
          version: 4,
        )
        ..caseDetails[_caseId] = _caseDetail(
          status: 'READY_FOR_PLANNING',
          currentStepKey: 'REQUEST_COORDINATION',
          actions: const [],
          version: 12,
        )
        ..queues[_clinicA] = _taskPage([
          _summary(
            taskId: _taskB,
            status: 'ASSIGNED',
            assignedMembershipId: null,
            acknowledgedAt: null,
            startedAt: null,
            version: 1,
          ),
        ], hasNext: false)
        ..myTasks = _taskPage(const [], hasNext: false);
      expect(
        (await controller.readyForPlanning(
          _clinicA,
          controller.taskDetail.task!,
          controller.taskDetail.caseDetail!,
        )).succeeded,
        isTrue,
      );
      expect(controller.positionQueue.items.single.taskId, _taskB);

      repository.details[_taskB] = _detail(
        taskId: _taskB,
        status: 'ASSIGNED',
        assignedMembershipId: null,
        acknowledgedAt: null,
        startedAt: null,
        version: 1,
      );
      await controller.loadTaskDetail(_clinicA, _taskB);
      repository
        ..queues[_clinicA] = _taskPage(const [], hasNext: false)
        ..details[_taskB] = _detail(
          taskId: _taskB,
          status: 'ACKNOWLEDGED',
          startedAt: null,
          version: 2,
        )
        ..myTasks = _taskPage([
          _summary(
            taskId: _taskB,
            status: 'ACKNOWLEDGED',
            startedAt: null,
            version: 2,
          ),
        ], hasNext: false);
      expect(
        (await controller.acknowledgeTask(
          _clinicA,
          controller.taskDetail.task!,
        )).succeeded,
        isTrue,
      );

      repository
        ..details[_taskB] = _detail(
          taskId: _taskB,
          status: 'IN_PROGRESS',
          version: 3,
        )
        ..myTasks = _taskPage([
          _summary(taskId: _taskB, status: 'IN_PROGRESS', version: 3),
        ], hasNext: false);
      expect(
        (await controller.startTask(
          _clinicA,
          controller.taskDetail.task!,
        )).succeeded,
        isTrue,
      );

      repository
        ..details[_taskB] = _detail(
          taskId: _taskB,
          status: 'COMPLETED',
          completedAt: '2026-08-13T10:40:00Z',
          version: 4,
        )
        ..myTasks = _taskPage(const [], hasNext: false);
      expect(
        (await controller.completeTask(
          _clinicA,
          controller.taskDetail.task!,
        )).succeeded,
        isTrue,
      );
      expect(controller.taskDetail.task?.completedAt, isNotNull);
      expect(controller.myTasks.items, isEmpty);
    },
  );

  testWidgets('task detail humanizes context and renders completedAt', (
    tester,
  ) async {
    final repository = _ExitRepository();
    repository.details[_taskA] = _detail(
      taskId: _taskA,
      status: 'COMPLETED',
      completedAt: '2026-08-13T10:30:00Z',
      version: 8,
    );
    final contextController = ClinicContextController(
      repository: repository,
      selectionStore: ClinicSelectionStore(backend: _SecureBackend()),
    );
    await contextController.initializeForAuthenticatedUser(
      globalRole: 'CLINIC_MEDECIN',
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ClinicContextController>.value(
            value: contextController,
          ),
          ChangeNotifierProvider(
            create: (_) => ClinicOperationalController(repository: repository),
          ),
        ],
        child: MaterialApp(
          initialRoute: '/detail',
          onGenerateRoute: (settings) {
            if (settings.name != '/detail') {
              return MaterialPageRoute<void>(
                settings: settings,
                builder: (_) => const SizedBox.shrink(),
              );
            }
            return MaterialPageRoute<void>(
              settings: const RouteSettings(name: '/detail', arguments: _taskA),
              builder: (_) => const ClinicTaskDetailScreen(),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Timing'),
      220,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('Completed'), findsWidgets);
    await tester.scrollUntilVisible(
      find.text('Case context'),
      220,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('Received'), findsOneWidget);
    expect(find.text('Request coordination'), findsWidgets);
    expect(find.text('RECEIVED'), findsNothing);
    expect(find.text('REQUEST_COORDINATION'), findsNothing);
  });
}

ClinicBootstrap _bootstrap(String clinicId) {
  return ClinicBootstrap.fromJson({
    'clinic': {
      'clinicId': clinicId,
      'clinicName': 'OmniCare Clinic',
      'clinicStatus': 'ACTIVE',
    },
    'membership': {
      'membershipId': _membershipId,
      'membershipStatus': 'ACTIVE',
      'professionalRole': 'CLINIC_MEDECIN',
      'version': 1,
    },
    'capabilities': ['CLINIC_TASK_READ', 'CLINIC_TASK_HANDOVER'],
    'featureFlags': {'CLINIC_MOBILE_TASKS_ENABLED': true},
  });
}

ClinicSlice<ClinicTaskSummary> _taskPage(
  List<ClinicTaskSummary> items, {
  int page = 0,
  bool hasNext = true,
}) {
  return ClinicSlice<ClinicTaskSummary>(
    items: items,
    page: page,
    pageSize: 20,
    hasNext: hasNext,
    generatedAt: DateTime.utc(2026, 8, 13, 10),
    contractVersion: '1.0',
  );
}

ClinicTaskSummary _summary({
  String taskId = _taskA,
  String taskType = 'REQUEST_COORDINATION',
  String status = 'IN_PROGRESS',
  String? assignedMembershipId = _membershipId,
  String? acknowledgedAt = '2026-08-13T09:10:00Z',
  String? startedAt = '2026-08-13T10:00:00Z',
  int version = 3,
}) {
  return ClinicTaskSummary.fromJson(
    _taskJson(
      taskId: taskId,
      taskType: taskType,
      status: status,
      assignedMembershipId: assignedMembershipId,
      acknowledgedAt: acknowledgedAt,
      startedAt: startedAt,
      version: version,
    ),
  );
}

ClinicTaskDetail _detail({
  String taskId = _taskA,
  String taskType = 'REQUEST_COORDINATION',
  String status = 'IN_PROGRESS',
  String? assignedMembershipId = _membershipId,
  String? acknowledgedAt = '2026-08-13T09:10:00Z',
  String? startedAt = '2026-08-13T10:00:00Z',
  String? completedAt,
  int version = 3,
}) {
  return ClinicTaskDetail.fromJson(
    _taskJson(
      taskId: taskId,
      taskType: taskType,
      status: status,
      assignedMembershipId: assignedMembershipId,
      acknowledgedAt: acknowledgedAt,
      startedAt: startedAt,
      completedAt: completedAt,
      version: version,
    ),
  );
}

Map<String, dynamic> _taskJson({
  required String taskId,
  String taskType = 'REQUEST_COORDINATION',
  String status = 'IN_PROGRESS',
  String? assignedMembershipId = _membershipId,
  String? acknowledgedAt = '2026-08-13T09:10:00Z',
  String? startedAt = '2026-08-13T10:00:00Z',
  String? completedAt,
  int version = 3,
}) {
  return {
    'taskId': taskId,
    'caseId': _caseId,
    'taskType': taskType,
    'responsibilityType': taskType == 'ADMINISTRATIVE_REVIEW'
        ? 'ADMISSIONS'
        : 'REQUEST_COORDINATION',
    'status': status,
    'priority': 'HIGH',
    'blocking': true,
    'acknowledgementRequired': true,
    'acknowledgementDueAt': '2026-08-13T09:30:00Z',
    'dueAt': '2026-08-13T12:00:00Z',
    'assignedPositionId': _positionId,
    'assignedMembershipId': assignedMembershipId,
    'createdAt': '2026-08-13T09:00:00Z',
    'updatedAt': '2026-08-13T10:30:00Z',
    'version': version,
    'blockedReasonCode': null,
    'acknowledgedAt': acknowledgedAt,
    'startedAt': startedAt,
    'completedAt': completedAt,
    'caseContext': {
      'caseId': _caseId,
      'sourceRequestId': _requestId,
      'intakeStatus': 'RECEIVED',
      'situation': 'APPOINTMENT',
      'priority': 'NORMAL',
      'currentStepKey': taskType,
      'submittedAt': '2026-08-13T08:30:00Z',
      'hasOpenRoutingIncident': false,
    },
  };
}

ClinicCaseDetail _caseDetail({
  String status = 'RECEIVED',
  String currentStepKey = 'ADMINISTRATIVE_REVIEW',
  List<String> actions = const ['START_REVIEW'],
  int version = 10,
}) {
  return ClinicCaseDetail.fromJson({
    'clinicCaseId': _caseId,
    'patientDisplayName': 'Patient',
    'subjectType': 'SELF',
    'relationship': null,
    'situation': 'APPOINTMENT',
    'administrativeStatus': status,
    'submittedAt': '2026-08-13T08:30:00Z',
    'version': version,
    'priority': 'NORMAL',
    'currentStepKey': currentStepKey,
    'availableActions': actions,
    'informationRequest': null,
  });
}

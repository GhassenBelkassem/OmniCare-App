import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:omnicare_mobile/core/network/app_http_client.dart';
import 'package:omnicare_mobile/core/storage/secure_token_store.dart';
import 'package:omnicare_mobile/features/clinic/application/clinic_context_controller.dart';
import 'package:omnicare_mobile/features/clinic/application/clinic_operational_controller.dart';
import 'package:omnicare_mobile/features/clinic/clinic_routes.dart';
import 'package:omnicare_mobile/features/clinic/data/clinic_api.dart';
import 'package:omnicare_mobile/features/clinic/data/clinic_failure.dart';
import 'package:omnicare_mobile/features/clinic/data/clinic_models.dart';
import 'package:omnicare_mobile/features/clinic/data/clinic_repository.dart';
import 'package:omnicare_mobile/features/clinic/screens/clinic_operational_list_screens.dart';
import 'package:omnicare_mobile/features/clinic/screens/clinic_task_detail_screen.dart';
import 'package:omnicare_mobile/features/clinic/storage/clinic_selection_store.dart';

const String clinicId = '11111111-1111-4111-8111-111111111111';
const String sourceMembershipId = '22222222-2222-4222-8222-222222222222';
const String targetMembershipId = '77777777-7777-4777-8777-777777777777';
const String taskId = '33333333-3333-4333-8333-333333333333';
const String caseId = '44444444-4444-4444-8444-444444444444';
const String requestId = '55555555-5555-4555-8555-555555555555';
const String positionId = '66666666-6666-4666-8666-666666666666';
const String handoverId = '88888888-8888-4888-8888-888888888888';

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

class _RecordingAdapter implements HttpClientAdapter {
  String responseBody = '{}';
  int statusCode = 200;
  String? path;
  String? method;
  String? body;
  Map<String, dynamic> query = const {};

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    path = options.path;
    method = options.method;
    query = Map<String, dynamic>.from(options.queryParameters);
    if (requestStream != null) {
      final chunks = await requestStream.toList();
      body = utf8.decode(chunks.expand((chunk) => chunk).toList());
    } else {
      body = null;
    }
    return ResponseBody.fromString(
      responseBody,
      statusCode,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _ClinicRepositoryFake implements ClinicRepository {
  _ClinicRepositoryFake({this.membershipId = sourceMembershipId});

  final String membershipId;
  ClinicSlice<ClinicTaskSummary> queue = _taskPage(const []);
  ClinicSlice<ClinicTaskSummary> myTasks = _taskPage(const []);
  ClinicSlice<ClinicHandoverTarget> targets = _targetPage([_target()]);
  ClinicSlice<ClinicHandoverSummary> incoming = _handoverPage(const []);
  ClinicSlice<ClinicHandoverSummary> outgoing = _handoverPage(const []);
  final Map<String, ClinicTaskDetail> details = <String, ClinicTaskDetail>{
    taskId: _detail(assignedMembershipId: sourceMembershipId),
  };

  Object? initiateError;
  Object? acceptError;
  Object? cancelError;
  ClinicTaskDetail? afterAcceptDetail;

  int targetCalls = 0;
  int initiateCalls = 0;
  int incomingCalls = 0;
  int outgoingCalls = 0;
  int myTaskCalls = 0;
  int detailCalls = 0;
  int acceptCalls = 0;
  int declineCalls = 0;
  int cancelCalls = 0;
  final List<int> targetPages = <int>[];
  final List<int> targetPageSizes = <int>[];
  final List<String> submittedTargets = <String>[];
  final List<ClinicHandoverReason> submittedReasons = <ClinicHandoverReason>[];
  final List<int> submittedTaskVersions = <int>[];

  @override
  Future<ClinicAccessFamily> resolveAccessFamily({CancelToken? cancelToken}) =>
      Future.value(ClinicAccessFamily.clinic);

  @override
  Future<ClinicMembershipDirectory> loadMemberships({
    CancelToken? cancelToken,
  }) async {
    return ClinicMembershipDirectory(
      activeMemberships: [
        ClinicMembershipSummary.fromJson({
          'clinicId': clinicId,
          'clinicName': 'OmniCare Clinic',
          'membershipId': membershipId,
          'professionalRole': 'CLINIC_MEDECIN',
          'membershipStatus': 'ACTIVE',
          'clinicStatus': 'ACTIVE',
          'version': 1,
        }),
      ],
      unavailableMemberships: const [],
    );
  }

  @override
  Future<ClinicBootstrap> loadBootstrap(
    String clinicId, {
    CancelToken? cancelToken,
  }) => Future.value(_bootstrap(membershipId: membershipId));

  @override
  Future<ClinicSlice<ClinicTaskSummary>> loadPositionQueue(
    String clinicId, {
    int page = 0,
    int pageSize = 20,
    CancelToken? cancelToken,
  }) async {
    return queue;
  }

  @override
  Future<ClinicSlice<ClinicTaskSummary>> loadMyTasks(
    String clinicId, {
    int page = 0,
    int pageSize = 20,
    CancelToken? cancelToken,
  }) async {
    myTaskCalls++;
    return myTasks;
  }

  @override
  Future<ClinicTaskDetail> loadTaskDetail(
    String clinicId,
    String taskId, {
    CancelToken? cancelToken,
  }) async {
    detailCalls++;
    return details[taskId]!;
  }

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
  }) => Future.value(details[taskId]!);

  @override
  Future<ClinicTaskDetail> blockTask(
    String clinicId,
    String taskId, {
    required ClinicTaskBlockedReason reason,
    required int expectedVersion,
    CancelToken? cancelToken,
  }) => Future.value(details[taskId]!);

  @override
  Future<ClinicTaskDetail> unblockTask(
    String clinicId,
    String taskId, {
    required int expectedVersion,
    CancelToken? cancelToken,
  }) => Future.value(details[taskId]!);

  @override
  Future<ClinicTaskDetail> completeTask(
    String clinicId,
    String taskId, {
    required int expectedVersion,
    CancelToken? cancelToken,
  }) => Future.value(details[taskId]!);

  @override
  Future<ClinicSlice<ClinicHandoverTarget>> loadHandoverTargets(
    String clinicId,
    String taskId, {
    int page = 0,
    int pageSize = 20,
    CancelToken? cancelToken,
  }) async {
    targetCalls++;
    targetPages.add(page);
    targetPageSizes.add(pageSize);
    return targets;
  }

  @override
  Future<ClinicHandoverSummary> initiateHandover(
    String clinicId,
    String taskId, {
    required String toMembershipId,
    required ClinicHandoverReason reason,
    required int expectedTaskVersion,
    CancelToken? cancelToken,
  }) async {
    initiateCalls++;
    submittedTargets.add(toMembershipId);
    submittedReasons.add(reason);
    submittedTaskVersions.add(expectedTaskVersion);
    final error = initiateError;
    if (error != null) throw error;
    outgoing = _handoverPage([
      _handover(status: 'PENDING', toMembershipId: toMembershipId),
    ]);
    return outgoing.items.single;
  }

  @override
  Future<ClinicHandoverSummary> loadHandoverDetail(
    String clinicId,
    String handoverId, {
    CancelToken? cancelToken,
  }) => Future.value(_handover());

  @override
  Future<ClinicHandoverSummary> acceptHandover(
    String clinicId,
    String handoverId, {
    CancelToken? cancelToken,
  }) async {
    acceptCalls++;
    final error = acceptError;
    if (error != null) throw error;
    final next = afterAcceptDetail;
    if (next != null) details[next.taskId] = next;
    incoming = _handoverPage([_handover(status: 'ACCEPTED')]);
    return incoming.items.single;
  }

  @override
  Future<ClinicHandoverSummary> declineHandover(
    String clinicId,
    String handoverId, {
    CancelToken? cancelToken,
  }) async {
    declineCalls++;
    incoming = _handoverPage([_handover(status: 'DECLINED')]);
    return incoming.items.single;
  }

  @override
  Future<ClinicHandoverSummary> cancelHandover(
    String clinicId,
    String handoverId, {
    CancelToken? cancelToken,
  }) async {
    cancelCalls++;
    final error = cancelError;
    if (error != null) throw error;
    outgoing = _handoverPage([_handover(status: 'CANCELLED')]);
    return outgoing.items.single;
  }

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
    if (incoming) {
      incomingCalls++;
      return this.incoming;
    }
    outgoingCalls++;
    return outgoing;
  }
}

void main() {
  test(
    'uses exact P3-14D handover endpoints, query names, and DTO fields',
    () async {
      final adapter = _RecordingAdapter();
      final api = ClinicApi(
        AppHttpClient(
          tokenStore: SecureTokenStore(backend: _SecureBackend()),
          baseUrl: 'https://api.test',
          dio: Dio()..httpClientAdapter = adapter,
        ),
      );

      adapter.responseBody = jsonEncode(_targetPageJson());
      await api.fetchHandoverTargets(clinicId, taskId, page: 1, pageSize: 2);
      expect(adapter.method, 'GET');
      expect(adapter.path, '/clinics/$clinicId/tasks/$taskId/handover-targets');
      expect(adapter.query, {'page': 1, 'size': 2});

      adapter.responseBody = jsonEncode(_handoverJson());
      await api.initiateHandover(
        clinicId,
        taskId,
        toMembershipId: targetMembershipId,
        reason: ClinicHandoverReason.shiftChange,
        expectedTaskVersion: 9,
      );
      expect(adapter.method, 'POST');
      expect(adapter.path, '/clinics/$clinicId/tasks/$taskId/handovers');
      expect(jsonDecode(adapter.body!), {
        'toMembershipId': targetMembershipId,
        'reasonCode': 'SHIFT_CHANGE',
        'expectedTaskVersion': 9,
      });

      adapter.responseBody = jsonEncode(_handoverPageJson());
      await api.fetchHandovers(clinicId, incoming: false, page: 3, pageSize: 4);
      expect(adapter.path, '/clinics/$clinicId/task-handovers/outgoing');
      expect(adapter.query, {'page': 3, 'pageSize': 4});

      adapter.responseBody = jsonEncode(_handoverJson(status: 'ACCEPTED'));
      await api.acceptHandover(clinicId, handoverId);
      expect(
        adapter.path,
        '/clinics/$clinicId/task-handovers/$handoverId/accept',
      );
      expect(adapter.body, isNull);

      await api.declineHandover(clinicId, handoverId);
      expect(
        adapter.path,
        '/clinics/$clinicId/task-handovers/$handoverId/decline',
      );
      await api.cancelHandover(clinicId, handoverId);
      expect(
        adapter.path,
        '/clinics/$clinicId/task-handovers/$handoverId/cancel',
      );
    },
  );

  test(
    'controller discovers targets, paginates, initiates with task version, and refetches',
    () async {
      final repo = _ClinicRepositoryFake();
      final controller = ClinicOperationalController(
        repository: repo,
        pageSize: 1,
      );
      final task = _detail(
        status: 'IN_PROGRESS',
        taskType: 'REQUEST_COORDINATION',
        assignedMembershipId: sourceMembershipId,
        version: 12,
      );
      repo.details[taskId] = task;
      repo.targets = _targetPage([_target()], pageSize: 1, hasNext: true);

      await controller.loadHandoverTargets(clinicId, task);
      expect(
        controller.handoverTargets.items.single.displayName,
        'Maya Trabelsi',
      );
      expect(repo.targetPages, [0]);
      expect(repo.targetPageSizes, [1]);

      repo.targets = _targetPage(
        [
          _target(
            membershipId: '99999999-9999-4999-8999-999999999999',
            name: 'Nour',
          ),
        ],
        page: 1,
        pageSize: 1,
      );
      await controller.loadNextHandoverTargets();
      expect(controller.handoverTargets.items, hasLength(2));
      expect(repo.targetPages, [0, 1]);

      await controller.loadTaskDetail(clinicId, taskId);
      final result = await controller.initiateHandover(
        clinicId,
        task,
        target: controller.handoverTargets.items.first,
        reason: ClinicHandoverReason.workloadTransfer,
      );
      expect(result.succeeded, isTrue);
      expect(repo.submittedTargets, [targetMembershipId]);
      expect(repo.submittedReasons, [ClinicHandoverReason.workloadTransfer]);
      expect(repo.submittedTaskVersions, [12]);
      expect(
        controller.taskDetail.task?.assignedMembershipId,
        sourceMembershipId,
      );
      expect(repo.myTaskCalls, greaterThan(0));
      expect(repo.incomingCalls, greaterThan(0));
      expect(repo.outgoingCalls, greaterThan(0));
    },
  );

  testWidgets(
    'source owner sees handover without freezing normal task actions',
    (tester) async {
      final repo = _ClinicRepositoryFake()
        ..details[taskId] = _detail(
          status: 'IN_PROGRESS',
          assignedMembershipId: sourceMembershipId,
          taskType: 'REQUEST_COORDINATION',
        );
      await tester.pumpWidget(
        await _host(
          repo,
          ClinicTaskDetailScreen(key: UniqueKey()),
          routeArguments: taskId,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hand over task'), findsOneWidget);
      expect(find.text('Block task'), findsOneWidget);
      expect(find.text('Complete task'), findsOneWidget);
    },
  );

  testWidgets('non-owner does not see handover initiation', (tester) async {
    final repo = _ClinicRepositoryFake()
      ..details[taskId] = _detail(
        status: 'IN_PROGRESS',
        assignedMembershipId: targetMembershipId,
      );
    await tester.pumpWidget(
      await _host(
        repo,
        ClinicTaskDetailScreen(key: UniqueKey()),
        routeArguments: taskId,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hand over task'), findsNothing);
    expect(find.text('Block task'), findsNothing);
  });

  test(
    'accepting IN_PROGRESS refetches ACKNOWLEDGED owner with original startedAt',
    () async {
      final repo = _ClinicRepositoryFake(membershipId: targetMembershipId)
        ..details[taskId] = _detail(
          status: 'IN_PROGRESS',
          taskType: 'REQUEST_COORDINATION',
          assignedMembershipId: sourceMembershipId,
          startedAt: '2026-08-13T09:20:00Z',
        )
        ..incoming = _handoverPage([_handover(status: 'PENDING')])
        ..afterAcceptDetail = _detail(
          status: 'ACKNOWLEDGED',
          taskType: 'REQUEST_COORDINATION',
          assignedMembershipId: targetMembershipId,
          acknowledgedAt: '2026-08-13T10:00:00Z',
          startedAt: '2026-08-13T09:20:00Z',
        );
      final controller = ClinicOperationalController(repository: repo);

      await controller.loadTaskDetail(clinicId, taskId);
      final result = await controller.acceptHandover(
        clinicId,
        repo.incoming.items.single,
      );

      expect(result.succeeded, isTrue);
      expect(controller.taskDetail.task!.status, ClinicTaskStatus.acknowledged);
      expect(
        controller.taskDetail.task!.assignedMembershipId,
        targetMembershipId,
      );
      expect(
        controller.taskDetail.task!.startedAt,
        DateTime.utc(2026, 8, 13, 9, 20),
      );
    },
  );

  testWidgets('accepted IN_PROGRESS authoritative ACK shows Resume task', (
    tester,
  ) async {
    final repo = _ClinicRepositoryFake(membershipId: targetMembershipId)
      ..details[taskId] = _detail(
        status: 'ACKNOWLEDGED',
        taskType: 'REQUEST_COORDINATION',
        assignedMembershipId: targetMembershipId,
        acknowledgedAt: '2026-08-13T10:00:00Z',
        startedAt: '2026-08-13T09:20:00Z',
      );
    await tester.pumpWidget(
      await _host(
        repo,
        ClinicTaskDetailScreen(key: UniqueKey()),
        routeArguments: taskId,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Resume task'), findsOneWidget);
    expect(find.text('Acknowledge'), findsNothing);
  });

  testWidgets(
    'blocked handover preserves generic unblock and patient-info protection',
    (tester) async {
      final genericRepo = _ClinicRepositoryFake()
        ..details[taskId] = _detail(
          status: 'BLOCKED',
          taskType: 'REQUEST_COORDINATION',
          assignedMembershipId: sourceMembershipId,
          blockedReason: 'WAITING_FOR_INTERNAL_COORDINATION',
        );
      await tester.pumpWidget(
        await _host(
          genericRepo,
          ClinicTaskDetailScreen(key: UniqueKey()),
          routeArguments: taskId,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Unblock task'), findsOneWidget);
      expect(find.text('Hand over task'), findsOneWidget);

      final patientRepo = _ClinicRepositoryFake()
        ..details[taskId] = _detail(
          status: 'BLOCKED',
          taskType: 'REQUEST_COORDINATION',
          assignedMembershipId: sourceMembershipId,
          blockedReason: 'WAITING_FOR_PATIENT_INFORMATION',
        );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        await _host(
          patientRepo,
          ClinicTaskDetailScreen(key: UniqueKey()),
          routeArguments: taskId,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Unblock task'), findsNothing);
      expect(find.text('Hand over task'), findsOneWidget);
    },
  );

  testWidgets(
    'incoming and outgoing handovers show correct pending actions and read-only terminals',
    (tester) async {
      final repo = _ClinicRepositoryFake(membershipId: targetMembershipId)
        ..incoming = _handoverPage([
          _handover(status: 'PENDING'),
          _handover(status: 'INVALIDATED', invalidationReason: 'TASK_TERMINAL'),
        ])
        ..outgoing = _handoverPage([
          _handover(status: 'PENDING'),
          _handover(status: 'ACCEPTED'),
        ]);
      await tester.pumpWidget(
        await _host(
          repo,
          const ClinicOperationalListScreen(
            kind: ClinicOperationalListKind.handovers,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Accept'), findsOneWidget);
      expect(find.text('Decline'), findsOneWidget);
      expect(find.text('Task was completed or cancelled'), findsOneWidget);
      expect(find.text('Cancel'), findsNothing);

      await tester.tap(find.text('Outgoing'));
      await tester.pumpAndSettle();
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Accept'), findsNothing);
      expect(find.text('Decline'), findsNothing);
    },
  );

  test(
    'conflicts return safe messages and refetch authoritative handover state',
    () async {
      final repo = _ClinicRepositoryFake(membershipId: targetMembershipId)
        ..incoming = _handoverPage([_handover(status: 'PENDING')])
        ..acceptError = const ClinicFailure(
          kind: ClinicFailureKind.concurrency,
          message:
              'This handover changed while you were viewing it. The latest information has been loaded.',
          retryable: false,
          diagnosticCode: 'CLINIC_TASK_HANDOVER_INVALID',
        );
      final controller = ClinicOperationalController(repository: repo);
      await controller.loadIncomingHandovers(clinicId);
      repo.incoming = _handoverPage([
        _handover(status: 'INVALIDATED', invalidationReason: 'TASK_TERMINAL'),
      ]);

      final result = await controller.acceptHandover(
        clinicId,
        controller.incomingHandovers.items.single,
      );

      expect(result.succeeded, isFalse);
      expect(result.failure!.message, contains('latest information'));
      expect(
        controller.incomingHandovers.items.single.status,
        ClinicHandoverStatus.invalidated,
      );
      expect(repo.incomingCalls, greaterThan(1));
    },
  );
}

Future<Widget> _host(
  _ClinicRepositoryFake repo,
  Widget child, {
  Object? routeArguments,
}) async {
  final contextController = ClinicContextController(
    repository: repo,
    selectionStore: ClinicSelectionStore(backend: _SecureBackend()),
  );
  await contextController.initializeForAuthenticatedUser(
    globalRole: 'CLINIC_MEDECIN',
  );
  final operational = ClinicOperationalController(repository: repo);
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<ClinicContextController>.value(
        value: contextController,
      ),
      ChangeNotifierProvider<ClinicOperationalController>.value(
        value: operational,
      ),
    ],
    child: routeArguments == null
        ? MaterialApp(routes: ClinicRoutes.builders(), home: child)
        : MaterialApp(
            routes: ClinicRoutes.builders(),
            initialRoute: '/',
            onGenerateRoute: (_) => MaterialPageRoute<void>(
              settings: RouteSettings(arguments: routeArguments),
              builder: (_) => child,
            ),
          ),
  );
}

ClinicBootstrap _bootstrap({required String membershipId}) {
  return ClinicBootstrap.fromJson({
    'clinic': {
      'clinicId': clinicId,
      'clinicName': 'OmniCare Clinic',
      'clinicStatus': 'ACTIVE',
    },
    'membership': {
      'membershipId': membershipId,
      'membershipStatus': 'ACTIVE',
      'professionalRole': 'CLINIC_MEDECIN',
      'version': 1,
    },
    'capabilities': ['CLINIC_TASK_READ', 'CLINIC_TASK_HANDOVER'],
    'featureFlags': {'CLINIC_MOBILE_TASKS_ENABLED': true},
  });
}

ClinicSlice<ClinicTaskSummary> _taskPage(List<ClinicTaskSummary> items) {
  return ClinicSlice<ClinicTaskSummary>(
    items: items,
    page: 0,
    pageSize: 20,
    hasNext: false,
    generatedAt: DateTime.utc(2026, 8, 13, 10),
  );
}

ClinicSlice<ClinicHandoverTarget> _targetPage(
  List<ClinicHandoverTarget> items, {
  int page = 0,
  int pageSize = 20,
  bool hasNext = false,
}) {
  return ClinicSlice<ClinicHandoverTarget>(
    items: items,
    page: page,
    pageSize: pageSize,
    hasNext: hasNext,
    generatedAt: DateTime.utc(2026, 8, 13, 10),
  );
}

ClinicSlice<ClinicHandoverSummary> _handoverPage(
  List<ClinicHandoverSummary> items, {
  int page = 0,
  bool hasNext = false,
}) {
  return ClinicSlice<ClinicHandoverSummary>(
    items: items,
    page: page,
    pageSize: 20,
    hasNext: hasNext,
    generatedAt: DateTime.utc(2026, 8, 13, 10),
  );
}

ClinicHandoverTarget _target({
  String membershipId = targetMembershipId,
  String name = 'Maya Trabelsi',
}) {
  return ClinicHandoverTarget.fromJson({
    'membershipId': membershipId,
    'displayName': name,
    'positionId': positionId,
    'positionName': 'Admissions nurse',
  });
}

ClinicHandoverSummary _handover({
  String status = 'PENDING',
  String toMembershipId = targetMembershipId,
  String? invalidationReason,
}) {
  return ClinicHandoverSummary.fromJson(
    _handoverJson(
      status: status,
      toMembershipId: toMembershipId,
      invalidationReason: invalidationReason,
    ),
  );
}

ClinicTaskDetail _detail({
  String status = 'ACKNOWLEDGED',
  String taskType = 'ADMINISTRATIVE_REVIEW',
  String? assignedMembershipId,
  String? acknowledgedAt = '2026-08-13T09:10:00Z',
  Object? startedAt,
  String? blockedReason,
  int version = 6,
}) {
  return ClinicTaskDetail.fromJson({
    'taskId': taskId,
    'caseId': caseId,
    'taskType': taskType,
    'responsibilityType': taskType == 'REQUEST_COORDINATION'
        ? 'REQUEST_COORDINATION'
        : 'ADMISSIONS',
    'status': status,
    'priority': 'HIGH',
    'blocking': status == 'BLOCKED',
    'blockedReasonCode': blockedReason,
    'acknowledgementRequired': true,
    'acknowledgementDueAt': status == 'ACKNOWLEDGED'
        ? null
        : '2026-08-13T11:00:00Z',
    'dueAt': '2026-08-13T12:00:00Z',
    'assignedPositionId': positionId,
    'assignedMembershipId': assignedMembershipId,
    'createdAt': '2026-08-13T08:50:00Z',
    'updatedAt': '2026-08-13T09:00:00Z',
    'acknowledgedAt': acknowledgedAt,
    'startedAt': startedAt,
    'completedAt': null,
    'version': version,
    'caseContext': {
      'caseId': caseId,
      'sourceRequestId': requestId,
      'intakeStatus': 'RECEIVED',
      'situation': 'APPOINTMENT',
      'priority': 'NORMAL',
      'currentStepKey': 'ADMINISTRATIVE_REVIEW',
      'submittedAt': '2026-08-13T08:45:00Z',
      'hasOpenRoutingIncident': false,
    },
  });
}

Map<String, dynamic> _targetPageJson() => {
  'items': [
    {
      'membershipId': targetMembershipId,
      'displayName': 'Maya Trabelsi',
      'positionId': positionId,
      'positionName': 'Admissions nurse',
    },
  ],
  'page': 1,
  'pageSize': 2,
  'hasNext': false,
  'generatedAt': '2026-08-13T10:00:00Z',
};

Map<String, dynamic> _handoverPageJson() => {
  'items': [_handoverJson()],
  'page': 3,
  'pageSize': 4,
  'hasNext': false,
  'generatedAt': '2026-08-13T10:00:00Z',
};

Map<String, dynamic> _handoverJson({
  String status = 'PENDING',
  String toMembershipId = targetMembershipId,
  String? invalidationReason,
}) => {
  'handoverId': handoverId,
  'taskId': taskId,
  'status': status,
  'reasonCode': 'SHIFT_CHANGE',
  'fromMembershipId': sourceMembershipId,
  'toMembershipId': toMembershipId,
  'taskType': 'REQUEST_COORDINATION',
  'priority': 'HIGH',
  'initiatedAt': '2026-08-13T09:30:00Z',
  'acceptedAt': status == 'ACCEPTED' ? '2026-08-13T09:45:00Z' : null,
  'declinedAt': status == 'DECLINED' ? '2026-08-13T09:45:00Z' : null,
  'cancelledAt': status == 'CANCELLED' ? '2026-08-13T09:45:00Z' : null,
  'invalidatedAt': status == 'INVALIDATED' ? '2026-08-13T09:45:00Z' : null,
  'invalidationReason': invalidationReason,
};

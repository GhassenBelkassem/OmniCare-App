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
import 'package:omnicare_mobile/features/clinic/data/clinic_models.dart';
import 'package:omnicare_mobile/features/clinic/data/clinic_repository.dart';
import 'package:omnicare_mobile/features/clinic/screens/clinic_operational_list_screens.dart';
import 'package:omnicare_mobile/features/clinic/screens/clinic_task_detail_screen.dart';
import 'package:omnicare_mobile/features/clinic/storage/clinic_selection_store.dart';

const String clinicId = '11111111-1111-4111-8111-111111111111';
const String membershipId = '22222222-2222-4222-8222-222222222222';
const String taskId = '33333333-3333-4333-8333-333333333333';
const String caseId = '44444444-4444-4444-8444-444444444444';
const String requestId = '55555555-5555-4555-8555-555555555555';
const String positionId = '66666666-6666-4666-8666-666666666666';

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
  ClinicSlice<ClinicTaskSummary> queue = _page([_summary()]);
  ClinicSlice<ClinicTaskSummary> myTasks = _page(const []);
  final Map<String, ClinicTaskDetail> details = <String, ClinicTaskDetail>{
    taskId: _detail(),
  };
  ClinicCaseDetail caseDetail = _caseDetail();

  Object? queueError;
  Object? detailError;
  Object? acknowledgeError;
  Object? startError;
  Object? caseError;
  Object? blockError;
  Object? unblockError;
  Object? completeError;
  Object? startReviewError;
  Object? requestInformationError;
  Object? readyForPlanningError;
  Object? declineError;
  ClinicTaskDetail? acknowledgeResponse;
  ClinicTaskDetail? startResponse;

  int queueCalls = 0;
  int myTaskCalls = 0;
  int detailCalls = 0;
  int caseDetailCalls = 0;
  int acknowledgeCalls = 0;
  int startCalls = 0;
  int blockCalls = 0;
  int unblockCalls = 0;
  int completeCalls = 0;
  int startReviewCalls = 0;
  int requestInformationCalls = 0;
  int readyForPlanningCalls = 0;
  int declineCalls = 0;
  final List<int> requestedQueuePages = <int>[];
  final List<int> requestedMyTaskPages = <int>[];
  final List<int> acknowledgedVersions = <int>[];
  final List<int> startedVersions = <int>[];
  final List<int> blockedVersions = <int>[];
  final List<ClinicTaskBlockedReason> blockedReasons =
      <ClinicTaskBlockedReason>[];
  final List<int> unblockedVersions = <int>[];
  final List<int> completedVersions = <int>[];
  final List<int> caseCommandVersions = <int>[];
  final List<ClinicInformationRequestReason> informationReasons =
      <ClinicInformationRequestReason>[];
  final List<String?> patientInstructions = <String?>[];
  final List<ClinicCaseDeclineReason> declineReasons =
      <ClinicCaseDeclineReason>[];

  @override
  Future<ClinicAccessFamily> resolveAccessFamily({CancelToken? cancelToken}) =>
      Future.value(ClinicAccessFamily.clinic);

  @override
  Future<ClinicMembershipDirectory> loadMemberships({
    CancelToken? cancelToken,
  }) {
    return Future.value(
      ClinicMembershipDirectory(
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
      ),
    );
  }

  @override
  Future<ClinicBootstrap> loadBootstrap(
    String clinicId, {
    CancelToken? cancelToken,
  }) {
    return Future.value(_bootstrap());
  }

  @override
  Future<ClinicSlice<ClinicTaskSummary>> loadPositionQueue(
    String clinicId, {
    int page = 0,
    int pageSize = 20,
    CancelToken? cancelToken,
  }) async {
    queueCalls++;
    requestedQueuePages.add(page);
    final error = queueError;
    if (error != null) throw error;
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
    requestedMyTaskPages.add(page);
    return myTasks;
  }

  @override
  Future<ClinicTaskDetail> loadTaskDetail(
    String clinicId,
    String taskId, {
    CancelToken? cancelToken,
  }) async {
    detailCalls++;
    final error = detailError;
    if (error != null) throw error;
    return details[taskId]!;
  }

  @override
  Future<ClinicTaskDetail> acknowledgeTask(
    String clinicId,
    String taskId, {
    required int expectedVersion,
    CancelToken? cancelToken,
  }) async {
    acknowledgeCalls++;
    acknowledgedVersions.add(expectedVersion);
    final error = acknowledgeError;
    if (error != null) throw error;
    return acknowledgeResponse ?? details[taskId]!;
  }

  @override
  Future<ClinicTaskDetail> startTask(
    String clinicId,
    String taskId, {
    required int expectedVersion,
    CancelToken? cancelToken,
  }) async {
    startCalls++;
    startedVersions.add(expectedVersion);
    final error = startError;
    if (error != null) throw error;
    return startResponse ?? details[taskId]!;
  }

  @override
  Future<ClinicTaskDetail> blockTask(
    String clinicId,
    String taskId, {
    required ClinicTaskBlockedReason reason,
    required int expectedVersion,
    CancelToken? cancelToken,
  }) async {
    blockCalls++;
    blockedVersions.add(expectedVersion);
    blockedReasons.add(reason);
    final error = blockError;
    if (error != null) throw error;
    return details[taskId]!;
  }

  @override
  Future<ClinicTaskDetail> unblockTask(
    String clinicId,
    String taskId, {
    required int expectedVersion,
    CancelToken? cancelToken,
  }) async {
    unblockCalls++;
    unblockedVersions.add(expectedVersion);
    final error = unblockError;
    if (error != null) throw error;
    return details[taskId]!;
  }

  @override
  Future<ClinicTaskDetail> completeTask(
    String clinicId,
    String taskId, {
    required int expectedVersion,
    CancelToken? cancelToken,
  }) async {
    completeCalls++;
    completedVersions.add(expectedVersion);
    final error = completeError;
    if (error != null) throw error;
    return details[taskId]!;
  }

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
  }) async {
    caseDetailCalls++;
    final error = caseError;
    if (error != null) throw error;
    return caseDetail;
  }

  @override
  Future<ClinicCaseDetail> startReview(
    String clinicId,
    String caseId, {
    required int expectedVersion,
    CancelToken? cancelToken,
  }) async {
    startReviewCalls++;
    caseCommandVersions.add(expectedVersion);
    final error = startReviewError;
    if (error != null) throw error;
    return caseDetail;
  }

  @override
  Future<ClinicCaseDetail> requestInformation(
    String clinicId,
    String caseId, {
    required int expectedVersion,
    required ClinicInformationRequestReason reason,
    String? patientInstruction,
    CancelToken? cancelToken,
  }) async {
    requestInformationCalls++;
    caseCommandVersions.add(expectedVersion);
    informationReasons.add(reason);
    patientInstructions.add(patientInstruction);
    final error = requestInformationError;
    if (error != null) throw error;
    return caseDetail;
  }

  @override
  Future<ClinicCaseDetail> readyForPlanning(
    String clinicId,
    String caseId, {
    required int expectedVersion,
    CancelToken? cancelToken,
  }) async {
    readyForPlanningCalls++;
    caseCommandVersions.add(expectedVersion);
    final error = readyForPlanningError;
    if (error != null) throw error;
    return caseDetail;
  }

  @override
  Future<ClinicCaseDetail> declineCase(
    String clinicId,
    String caseId, {
    required int expectedVersion,
    required ClinicCaseDeclineReason reason,
    CancelToken? cancelToken,
  }) async {
    declineCalls++;
    caseCommandVersions.add(expectedVersion);
    declineReasons.add(reason);
    final error = declineError;
    if (error != null) throw error;
    return caseDetail;
  }

  @override
  Future<ClinicSlice<ClinicHandoverSummary>> loadHandovers(
    String clinicId, {
    required bool incoming,
    int page = 0,
    int pageSize = 20,
    CancelToken? cancelToken,
  }) {
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
  test('uses certified task endpoints and expectedVersion payloads', () async {
    final adapter = _RecordingAdapter()
      ..responseBody = jsonEncode({
        'contractVersion': '1.0',
        'items': [_taskJson()],
        'page': 2,
        'pageSize': 20,
        'hasNext': false,
        'generatedAt': '2026-08-13T10:00:00Z',
      });
    final dio = Dio()..httpClientAdapter = adapter;
    final api = ClinicApi(
      AppHttpClient(
        tokenStore: SecureTokenStore(backend: _SecureBackend()),
        baseUrl: 'https://api.test',
        dio: dio,
        refreshDio: Dio(),
      ),
    );

    await api.fetchPositionQueue(clinicId, page: 2, pageSize: 20);
    expect(adapter.method, 'GET');
    expect(adapter.path, '/clinics/$clinicId/tasks/position-queue');
    expect(adapter.query, containsPair('page', 2));
    expect(adapter.query, containsPair('pageSize', 20));

    adapter.responseBody = jsonEncode(_taskJson(status: 'ACKNOWLEDGED'));
    await api.acknowledgeTask(clinicId, taskId, expectedVersion: 7);
    expect(adapter.method, 'POST');
    expect(adapter.path, '/clinics/$clinicId/tasks/$taskId/acknowledge');
    expect(jsonDecode(adapter.body!), {'expectedVersion': 7});

    await api.startTask(clinicId, taskId, expectedVersion: 8);
    expect(adapter.method, 'POST');
    expect(adapter.path, '/clinics/$clinicId/tasks/$taskId/start');
    expect(jsonDecode(adapter.body!), {'expectedVersion': 8});
  });

  testWidgets('position queue renders operational fields and opens detail', (
    tester,
  ) async {
    final repo = _ClinicRepositoryFake();
    await tester.pumpWidget(
      await _host(
        repo,
        const ClinicOperationalListScreen(
          kind: ClinicOperationalListKind.positionQueue,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Administrative review'), findsOneWidget);
    expect(find.text('Awaiting acknowledgement'), findsOneWidget);
    expect(find.text('Critical'), findsOneWidget);
    expect(find.textContaining('Acknowledgement'), findsOneWidget);
    expect(find.textContaining('Due'), findsOneWidget);
    expect(find.textContaining('Created'), findsOneWidget);

    await tester.tap(find.text('Administrative review'));
    await tester.pumpAndSettle();
    expect(find.text('Task detail'), findsNothing);
    expect(find.text('Operational context'), findsOneWidget);
    expect(repo.detailCalls, 1);
  });

  testWidgets('my tasks renders owned work without manufacturing it locally', (
    tester,
  ) async {
    final repo = _ClinicRepositoryFake()
      ..queue = _page(const [])
      ..myTasks = _page([
        _summary(
          status: 'ACKNOWLEDGED',
          assignedMembershipId: membershipId,
          acknowledgedAt: '2026-08-13T09:10:00Z',
        ),
      ]);
    await tester.pumpWidget(
      await _host(
        repo,
        const ClinicOperationalListScreen(
          kind: ClinicOperationalListKind.myTasks,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(repo.queueCalls, 0);
    expect(repo.myTaskCalls, 1);
    expect(find.text('Ready to start'), findsOneWidget);
    expect(find.textContaining('Assigned position'), findsOneWidget);
  });

  testWidgets(
    'task detail shows safe context and no medical/raw error fields',
    (tester) async {
      final repo = _ClinicRepositoryFake();
      await tester.pumpWidget(
        await _host(
          repo,
          const ClinicTaskDetailScreen(),
          routeArguments: taskId,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Operational context'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Case context'),
        240,
        scrollable: find.byType(Scrollable),
      );
      expect(find.text('Case context'), findsOneWidget);
      expect(find.text('Task priority'), findsOneWidget);
      expect(find.text('Case priority'), findsOneWidget);
      expect(find.text('Case status'), findsOneWidget);
      expect(find.text('Received'), findsOneWidget);
      expect(find.text('Administrative review'), findsWidgets);
      expect(find.text('RECEIVED'), findsNothing);
      expect(find.text('ADMINISTRATIVE_REVIEW'), findsNothing);
      expect(find.textContaining(taskId), findsNothing);
      expect(find.textContaining(caseId), findsNothing);
      expect(find.textContaining('medical'), findsNothing);
      expect(find.textContaining('ProblemDetail'), findsNothing);
    },
  );

  test(
    'acknowledge sends stale-safe version and performs authoritative refetch',
    () async {
      final repo = _ClinicRepositoryFake();
      final controller = ClinicOperationalController(repository: repo);
      await controller.loadPositionQueue(clinicId);
      await controller.loadTaskDetail(clinicId, taskId);

      final acknowledged = _detail(
        status: 'ACKNOWLEDGED',
        assignedMembershipId: membershipId,
        acknowledgedAt: '2026-08-13T09:11:00Z',
        startedAt: null,
        version: 8,
      );
      repo
        ..acknowledgeResponse = acknowledged
        ..queue = _page(const [])
        ..myTasks = _page([acknowledged])
        ..details[taskId] = acknowledged;

      final result = await controller.acknowledgeTask(
        clinicId,
        controller.taskDetail.task!,
      );

      expect(result.succeeded, isTrue);
      expect(repo.acknowledgeCalls, 1);
      expect(repo.acknowledgedVersions, [4]);
      expect(repo.queueCalls, 2);
      expect(repo.myTaskCalls, 1);
      expect(repo.detailCalls, 2);
      expect(controller.positionQueue.items, isEmpty);
      expect(
        controller.myTasks.items.single.assignedMembershipId,
        membershipId,
      );
      expect(controller.taskDetail.task!.acknowledgedAt, isNotNull);
      expect(controller.taskDetail.task!.startedAt, isNull);
      expect(controller.taskDetail.task!.dueAt, DateTime.utc(2026, 8, 13, 12));
    },
  );

  test(
    'acknowledge conflict shows safe copy and refetches latest state',
    () async {
      final repo = _ClinicRepositoryFake();
      final controller = ClinicOperationalController(repository: repo);
      await controller.loadTaskDetail(clinicId, taskId);

      final latest = _detail(
        status: 'ACKNOWLEDGED',
        assignedMembershipId: '77777777-7777-4777-8777-777777777777',
        acknowledgedAt: '2026-08-13T09:12:00Z',
        version: 9,
      );
      repo
        ..acknowledgeError = _problem(409, 'CLINIC_TASK_VERSION_CONFLICT')
        ..queue = _page(const [])
        ..myTasks = _page(const [])
        ..details[taskId] = latest;

      final result = await controller.acknowledgeTask(
        clinicId,
        controller.taskDetail.task!,
      );

      expect(result.succeeded, isFalse);
      expect(
        result.failure!.message,
        contains('changed while you were viewing'),
      );
      expect(result.failure!.message, isNot(contains('CLINIC_TASK')));
      expect(
        controller.taskDetail.task!.assignedMembershipId,
        latest.assignedMembershipId,
      );
      expect(controller.positionQueue.items, isEmpty);
    },
  );

  testWidgets('action matrix exposes only P3-14B commands', (tester) async {
    await _expectAction(tester, _detail(), 'Acknowledge');
    await _expectAction(
      tester,
      _detail(
        status: 'ACKNOWLEDGED',
        assignedMembershipId: membershipId,
        acknowledgedAt: '2026-08-13T09:10:00Z',
        startedAt: null,
      ),
      'Start task',
    );
    await _expectAction(
      tester,
      _detail(
        status: 'ACKNOWLEDGED',
        assignedMembershipId: membershipId,
        acknowledgedAt: '2026-08-13T09:10:00Z',
        startedAt: '2026-08-13T09:15:00Z',
      ),
      'Resume task',
    );
    await _expectNoAction(tester, _detail(status: 'IN_PROGRESS'));
    await _expectNoAction(tester, _detail(status: 'BLOCKED'));
    await _expectNoAction(tester, _detail(status: 'COMPLETED'));
    await _expectNoAction(
      tester,
      _detail(
        status: 'ACKNOWLEDGED',
        assignedMembershipId: '77777777-7777-4777-8777-777777777777',
      ),
    );
  });

  test(
    'start and resume use same backend command and preserve due/startedAt',
    () async {
      final repo = _ClinicRepositoryFake();
      final controller = ClinicOperationalController(repository: repo);
      final acknowledged = _detail(
        status: 'ACKNOWLEDGED',
        assignedMembershipId: membershipId,
        acknowledgedAt: '2026-08-13T09:10:00Z',
        startedAt: null,
        version: 5,
      );
      repo.details[taskId] = acknowledged;
      await controller.loadTaskDetail(clinicId, taskId);

      final inProgress = _detail(
        status: 'IN_PROGRESS',
        assignedMembershipId: membershipId,
        acknowledgedAt: '2026-08-13T09:10:00Z',
        startedAt: '2026-08-13T09:20:00Z',
        version: 6,
      );
      repo
        ..startResponse = inProgress
        ..details[taskId] = inProgress;

      final startResult = await controller.startTask(
        clinicId,
        controller.taskDetail.task!,
      );
      expect(startResult.message, 'Task started.');
      expect(repo.startedVersions, [5]);
      expect(controller.taskDetail.task!.status, ClinicTaskStatus.inProgress);
      expect(controller.taskDetail.task!.dueAt, DateTime.utc(2026, 8, 13, 12));

      final resumeReady = _detail(
        status: 'ACKNOWLEDGED',
        assignedMembershipId: membershipId,
        acknowledgedAt: '2026-08-13T09:10:00Z',
        startedAt: '2026-08-13T09:20:00Z',
        version: 7,
      );
      repo.details[taskId] = resumeReady;
      await controller.loadTaskDetail(clinicId, taskId, refresh: true);

      final resumed = _detail(
        status: 'IN_PROGRESS',
        assignedMembershipId: membershipId,
        acknowledgedAt: '2026-08-13T09:10:00Z',
        startedAt: '2026-08-13T09:20:00Z',
        version: 8,
      );
      repo.details[taskId] = resumed;
      final resumeResult = await controller.startTask(
        clinicId,
        controller.taskDetail.task!,
      );
      expect(resumeResult.message, 'Task resumed.');
      expect(repo.startedVersions, [5, 7]);
      expect(
        controller.taskDetail.task!.startedAt,
        DateTime.utc(2026, 8, 13, 9, 20),
      );
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

Future<void> _expectAction(
  WidgetTester tester,
  ClinicTaskDetail task,
  String label,
) async {
  final repo = _ClinicRepositoryFake()..details[taskId] = task;
  await tester.pumpWidget(const SizedBox());
  await tester.pumpWidget(
    await _host(
      repo,
      ClinicTaskDetailScreen(key: UniqueKey()),
      routeArguments: taskId,
    ),
  );
  await tester.pumpAndSettle();
  expect(find.text(label), findsOneWidget);
  expect(find.text('Complete'), findsNothing);
  expect(find.text('Block'), findsNothing);
}

Future<void> _expectNoAction(WidgetTester tester, ClinicTaskDetail task) async {
  final repo = _ClinicRepositoryFake()..details[taskId] = task;
  await tester.pumpWidget(const SizedBox());
  await tester.pumpWidget(
    await _host(
      repo,
      ClinicTaskDetailScreen(key: UniqueKey()),
      routeArguments: taskId,
    ),
  );
  await tester.pumpAndSettle();
  expect(find.text('Acknowledge'), findsNothing);
  expect(find.text('Start task'), findsNothing);
  expect(find.text('Resume task'), findsNothing);
  expect(find.text('Complete'), findsNothing);
  expect(find.text('Block'), findsNothing);
}

ClinicBootstrap _bootstrap() {
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
    'capabilities': ['CLINIC_TASK_READ'],
    'featureFlags': {'CLINIC_MOBILE_TASKS_ENABLED': true},
  });
}

ClinicSlice<ClinicTaskSummary> _page(List<ClinicTaskSummary> items) {
  return ClinicSlice<ClinicTaskSummary>(
    items: items,
    page: 0,
    pageSize: 20,
    hasNext: false,
    generatedAt: DateTime.utc(2026, 8, 13, 10),
    contractVersion: '1.0',
  );
}

ClinicTaskSummary _summary({
  String status = 'ASSIGNED',
  String? assignedMembershipId,
  String? acknowledgedAt,
}) {
  return ClinicTaskSummary.fromJson(
    _taskJson(
      status: status,
      assignedMembershipId: assignedMembershipId,
      acknowledgedAt: acknowledgedAt,
    ),
  );
}

ClinicTaskDetail _detail({
  String status = 'ASSIGNED',
  String? assignedMembershipId,
  String? acknowledgedAt,
  Object? startedAt = _notProvided,
  int version = 4,
}) {
  return ClinicTaskDetail.fromJson(
    _taskJson(
      status: status,
      assignedMembershipId: assignedMembershipId,
      acknowledgedAt: acknowledgedAt,
      startedAt: startedAt,
      version: version,
    ),
  );
}

ClinicCaseDetail _caseDetail({
  String status = 'RECEIVED',
  List<String> actions = const ['START_REVIEW'],
  int version = 11,
  Map<String, dynamic>? informationRequest,
}) {
  return ClinicCaseDetail.fromJson({
    'clinicCaseId': caseId,
    'patientDisplayName': 'Amina Ben Ali',
    'subjectType': 'SELF',
    'relationship': null,
    'situation': 'APPOINTMENT',
    'administrativeStatus': status,
    'submittedAt': '2026-08-13T08:59:00Z',
    'version': version,
    'priority': 'NORMAL',
    'currentStepKey': status == 'READY_FOR_PLANNING'
        ? 'REQUEST_COORDINATION'
        : 'ADMINISTRATIVE_REVIEW',
    'availableActions': actions,
    'timeline': const [],
    'informationRequest': informationRequest,
    'patientSummary': {
      'displayName': 'Amina Ben Ali',
      'subjectType': 'SELF',
      'relationship': null,
    },
    'openRoutingIncidents': const [],
  });
}

const Object _notProvided = Object();

Map<String, dynamic> _taskJson({
  String status = 'ASSIGNED',
  String? assignedMembershipId,
  String? acknowledgedAt,
  Object? startedAt = _notProvided,
  int version = 4,
}) {
  return {
    'taskId': taskId,
    'caseId': caseId,
    'taskType': 'ADMINISTRATIVE_REVIEW',
    'responsibilityType': 'ADMISSIONS',
    'status': status,
    'priority': 'CRITICAL',
    'blocking': false,
    'acknowledgementRequired': true,
    'acknowledgementDueAt': '2026-08-13T10:00:00Z',
    'dueAt': '2026-08-13T12:00:00Z',
    'assignedPositionId': positionId,
    'assignedMembershipId': assignedMembershipId,
    'createdAt': '2026-08-13T09:00:00Z',
    'updatedAt': '2026-08-13T09:01:00Z',
    'version': version,
    'blockedReasonCode': status == 'BLOCKED'
        ? 'WAITING_FOR_INTERNAL_COORDINATION'
        : null,
    'acknowledgedAt': acknowledgedAt,
    'startedAt': identical(startedAt, _notProvided)
        ? null
        : startedAt as String?,
    'completedAt': status == 'COMPLETED' ? '2026-08-13T11:00:00Z' : null,
    'caseContext': {
      'caseId': caseId,
      'sourceRequestId': requestId,
      'intakeStatus': 'RECEIVED',
      'situation': 'APPOINTMENT',
      'priority': 'NORMAL',
      'currentStepKey': 'ADMINISTRATIVE_REVIEW',
      'submittedAt': '2026-08-13T08:59:00Z',
      'hasOpenRoutingIncident': false,
    },
  };
}

DioException _problem(int status, String errorCode) {
  return DioException(
    requestOptions: RequestOptions(path: '/clinics/$clinicId/tasks/$taskId'),
    response: Response(
      requestOptions: RequestOptions(path: '/clinics/$clinicId/tasks/$taskId'),
      statusCode: status,
      data: {'errorCode': errorCode, 'detail': 'backend detail'},
    ),
    type: DioExceptionType.badResponse,
  );
}

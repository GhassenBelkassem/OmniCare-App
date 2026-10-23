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
import 'package:omnicare_mobile/features/clinic/data/clinic_api.dart';
import 'package:omnicare_mobile/features/clinic/data/clinic_models.dart';
import 'package:omnicare_mobile/features/clinic/data/clinic_repository.dart';
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

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    path = options.path;
    method = options.method;
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
  ClinicSlice<ClinicTaskSummary> queue = _page(const []);
  ClinicSlice<ClinicTaskSummary> myTasks = _page(const []);
  final Map<String, ClinicTaskDetail> details = <String, ClinicTaskDetail>{
    taskId: _detail(),
  };
  ClinicCaseDetail caseDetail = _caseDetail();

  Object? blockError;
  Object? unblockError;
  Object? completeError;
  Object? requestInformationError;
  Object? readyForPlanningError;

  int queueCalls = 0;
  int myTaskCalls = 0;
  int detailCalls = 0;
  int caseDetailCalls = 0;
  int blockCalls = 0;
  int unblockCalls = 0;
  int completeCalls = 0;
  int startReviewCalls = 0;
  int requestInformationCalls = 0;
  int readyForPlanningCalls = 0;
  int declineCalls = 0;
  final List<int> taskVersions = <int>[];
  final List<ClinicTaskBlockedReason> blockReasons =
      <ClinicTaskBlockedReason>[];
  final List<int> caseVersions = <int>[];
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
  }) => Future.value(_bootstrap());

  @override
  Future<ClinicSlice<ClinicTaskSummary>> loadPositionQueue(
    String clinicId, {
    int page = 0,
    int pageSize = 20,
    CancelToken? cancelToken,
  }) async {
    queueCalls++;
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
  }) => throw UnimplementedError();

  @override
  Future<ClinicTaskDetail> blockTask(
    String clinicId,
    String taskId, {
    required ClinicTaskBlockedReason reason,
    required int expectedVersion,
    CancelToken? cancelToken,
  }) async {
    blockCalls++;
    taskVersions.add(expectedVersion);
    blockReasons.add(reason);
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
    taskVersions.add(expectedVersion);
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
    taskVersions.add(expectedVersion);
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
    caseVersions.add(expectedVersion);
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
    caseVersions.add(expectedVersion);
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
    caseVersions.add(expectedVersion);
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
    caseVersions.add(expectedVersion);
    declineReasons.add(reason);
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
  test('uses certified P3-14C endpoints and version payloads', () async {
    final adapter = _RecordingAdapter()
      ..responseBody = jsonEncode(_taskJson(status: 'BLOCKED'));
    final api = ClinicApi(
      AppHttpClient(
        tokenStore: SecureTokenStore(backend: _SecureBackend()),
        baseUrl: 'https://api.test',
        dio: Dio()..httpClientAdapter = adapter,
        refreshDio: Dio(),
      ),
    );

    await api.blockTask(
      clinicId,
      taskId,
      reason: ClinicTaskBlockedReason.waitingForInternalCoordination,
      expectedVersion: 7,
    );
    expect(adapter.method, 'POST');
    expect(adapter.path, '/clinics/$clinicId/tasks/$taskId/block');
    expect(jsonDecode(adapter.body!), {
      'reasonCode': 'WAITING_FOR_INTERNAL_COORDINATION',
      'expectedVersion': 7,
    });

    await api.unblockTask(clinicId, taskId, expectedVersion: 8);
    expect(adapter.path, '/clinics/$clinicId/tasks/$taskId/unblock');
    expect(jsonDecode(adapter.body!), {'expectedVersion': 8});

    await api.completeTask(clinicId, taskId, expectedVersion: 9);
    expect(adapter.path, '/clinics/$clinicId/tasks/$taskId/complete');
    expect(jsonDecode(adapter.body!), {'expectedVersion': 9});

    adapter.responseBody = jsonEncode(_caseJson(status: 'UNDER_ADMIN_REVIEW'));
    await api.startReview(clinicId, caseId, expectedVersion: 11);
    expect(adapter.path, '/clinics/$clinicId/cases/$caseId/review/start');
    expect(jsonDecode(adapter.body!), {'expectedVersion': 11});

    await api.requestInformation(
      clinicId,
      caseId,
      expectedVersion: 12,
      reason: ClinicInformationRequestReason.requestAdministrativeDetails,
      patientInstruction: 'Confirm availability.',
    );
    expect(
      adapter.path,
      '/clinics/$clinicId/cases/$caseId/information-required',
    );
    expect(jsonDecode(adapter.body!), {
      'reasonCode': 'REQUEST_ADMINISTRATIVE_DETAILS',
      'patientInstruction': 'Confirm availability.',
      'expectedVersion': 12,
    });

    await api.readyForPlanning(clinicId, caseId, expectedVersion: 13);
    expect(adapter.path, '/clinics/$clinicId/cases/$caseId/ready-for-planning');

    await api.declineCase(
      clinicId,
      caseId,
      expectedVersion: 14,
      reason: ClinicCaseDeclineReason.noCapacity,
    );
    expect(adapter.path, '/clinics/$clinicId/cases/$caseId/decline');
    expect(jsonDecode(adapter.body!), {
      'declineReasonCode': 'NO_CAPACITY',
      'expectedVersion': 14,
    });
  });

  test('generic block reasons are exactly the backend-authorized three', () {
    expect(
      ClinicTaskBlockedReason.genericReasons.map((reason) => reason.wireValue),
      [
        'WAITING_FOR_INTERNAL_COORDINATION',
        'WAITING_FOR_EXTERNAL_NON_PATIENT_RESPONSE',
        'WAITING_FOR_RESOURCE_AVAILABILITY',
      ],
    );
    expect(
      ClinicTaskBlockedReason.genericReasons,
      isNot(contains(ClinicTaskBlockedReason.waitingForPatientInformation)),
    );
  });

  test(
    'generic block and unblock preserve backend-authoritative fields',
    () async {
      final repo = _ClinicRepositoryFake();
      final controller = ClinicOperationalController(repository: repo);
      final inProgress = _detail(
        status: 'IN_PROGRESS',
        assignedMembershipId: membershipId,
        startedAt: '2026-08-13T09:20:00Z',
        version: 4,
      );
      final blocked = _detail(
        status: 'BLOCKED',
        assignedMembershipId: membershipId,
        blockedReasonCode: 'WAITING_FOR_INTERNAL_COORDINATION',
        startedAt: '2026-08-13T09:20:00Z',
        version: 5,
      );
      repo.details[taskId] = inProgress;
      await controller.loadTaskDetail(clinicId, taskId);
      repo.details[taskId] = blocked;

      final blockResult = await controller.blockTask(
        clinicId,
        controller.taskDetail.task!,
        ClinicTaskBlockedReason.waitingForInternalCoordination,
      );

      expect(blockResult.succeeded, isTrue);
      expect(repo.blockCalls, 1);
      expect(repo.taskVersions, [4]);
      expect(repo.blockReasons, [
        ClinicTaskBlockedReason.waitingForInternalCoordination,
      ]);
      expect(controller.taskDetail.task!.status, ClinicTaskStatus.blocked);
      expect(controller.taskDetail.task!.assignedMembershipId, membershipId);
      expect(
        controller.taskDetail.task!.startedAt,
        DateTime.utc(2026, 8, 13, 9, 20),
      );

      final unblocked = _detail(
        status: 'IN_PROGRESS',
        assignedMembershipId: membershipId,
        startedAt: '2026-08-13T09:20:00Z',
        version: 6,
      );
      repo.details[taskId] = unblocked;
      final unblockResult = await controller.unblockTask(
        clinicId,
        controller.taskDetail.task!,
      );

      expect(unblockResult.succeeded, isTrue);
      expect(repo.unblockCalls, 1);
      expect(repo.taskVersions, [4, 5]);
      expect(controller.taskDetail.task!.status, ClinicTaskStatus.inProgress);
      expect(controller.taskDetail.task!.blockedReasonCode, isNull);
    },
  );

  test(
    'case commands use case version and refetch authoritative task state',
    () async {
      final repo = _ClinicRepositoryFake();
      final controller = ClinicOperationalController(repository: repo);
      repo
        ..details[taskId] = _detail(
          status: 'IN_PROGRESS',
          assignedMembershipId: membershipId,
        )
        ..caseDetail = _caseDetail(
          status: 'UNDER_ADMIN_REVIEW',
          actions: const [
            'REQUEST_INFORMATION',
            'READY_FOR_PLANNING',
            'DECLINE',
          ],
          version: 22,
        );
      await controller.loadTaskDetail(clinicId, taskId);

      repo
        ..details[taskId] = _detail(
          status: 'BLOCKED',
          assignedMembershipId: membershipId,
          blockedReasonCode: 'WAITING_FOR_PATIENT_INFORMATION',
          version: 7,
        )
        ..caseDetail = _caseDetail(
          status: 'INFORMATION_REQUIRED',
          actions: const [],
          version: 23,
          informationRequest: {
            'reasonCode': 'REQUEST_ADMINISTRATIVE_DETAILS',
            'patientInstruction': 'Confirm availability.',
            'responseType': null,
            'status': 'OPEN',
            'responseSummary': null,
          },
        );

      final informationResult = await controller.requestInformation(
        clinicId,
        controller.taskDetail.task!,
        controller.taskDetail.caseDetail!,
        reason: ClinicInformationRequestReason.requestAdministrativeDetails,
        patientInstruction: 'Confirm availability.',
      );

      expect(informationResult.succeeded, isTrue);
      expect(repo.requestInformationCalls, 1);
      expect(repo.caseVersions, [22]);
      expect(repo.informationReasons, [
        ClinicInformationRequestReason.requestAdministrativeDetails,
      ]);
      expect(repo.patientInstructions, ['Confirm availability.']);
      expect(controller.taskDetail.task!.isPatientInformationBlocked, isTrue);
      expect(
        controller.taskDetail.caseDetail!.administrativeStatus,
        ClinicCaseStatus.informationRequired,
      );

      repo
        ..details[taskId] = _detail(
          status: 'IN_PROGRESS',
          assignedMembershipId: membershipId,
          version: 8,
        )
        ..caseDetail = _caseDetail(
          status: 'UNDER_ADMIN_REVIEW',
          actions: const ['READY_FOR_PLANNING'],
          version: 24,
        );
      await controller.loadTaskDetail(clinicId, taskId, refresh: true);
      expect(controller.taskDetail.task!.status, ClinicTaskStatus.inProgress);

      repo
        ..details[taskId] = _detail(
          status: 'COMPLETED',
          assignedMembershipId: membershipId,
          version: 9,
        )
        ..caseDetail = _caseDetail(
          status: 'READY_FOR_PLANNING',
          actions: const [],
          version: 25,
        );
      final readyResult = await controller.readyForPlanning(
        clinicId,
        controller.taskDetail.task!,
        controller.taskDetail.caseDetail!,
      );

      expect(readyResult.succeeded, isTrue);
      expect(repo.readyForPlanningCalls, 1);
      expect(repo.caseVersions, [22, 24]);
      expect(
        controller.taskDetail.caseDetail!.currentStepKey,
        'REQUEST_COORDINATION',
      );
    },
  );

  test(
    'request coordination complete uses generic task complete only',
    () async {
      final repo = _ClinicRepositoryFake();
      final controller = ClinicOperationalController(repository: repo);
      repo.details[taskId] = _detail(
        taskType: 'REQUEST_COORDINATION',
        responsibilityType: 'REQUEST_COORDINATION',
        status: 'IN_PROGRESS',
        assignedMembershipId: membershipId,
        version: 31,
      );
      await controller.loadTaskDetail(clinicId, taskId);
      repo.details[taskId] = _detail(
        taskType: 'REQUEST_COORDINATION',
        responsibilityType: 'REQUEST_COORDINATION',
        status: 'COMPLETED',
        assignedMembershipId: membershipId,
        version: 32,
      );

      final result = await controller.completeTask(
        clinicId,
        controller.taskDetail.task!,
      );

      expect(result.succeeded, isTrue);
      expect(repo.completeCalls, 1);
      expect(repo.taskVersions, [31]);
      expect(repo.readyForPlanningCalls, 0);
      expect(controller.taskDetail.task!.status, ClinicTaskStatus.completed);
    },
  );

  test('conflicts show safe copy and refetch latest state', () async {
    final repo = _ClinicRepositoryFake();
    final controller = ClinicOperationalController(repository: repo);
    repo.details[taskId] = _detail(
      status: 'IN_PROGRESS',
      assignedMembershipId: membershipId,
      version: 4,
    );
    await controller.loadTaskDetail(clinicId, taskId);
    repo
      ..blockError = _problem(409, 'CLINIC_TASK_VERSION_CONFLICT')
      ..details[taskId] = _detail(
        status: 'BLOCKED',
        assignedMembershipId: membershipId,
        version: 5,
      );

    final result = await controller.blockTask(
      clinicId,
      controller.taskDetail.task!,
      ClinicTaskBlockedReason.waitingForInternalCoordination,
    );

    expect(result.succeeded, isFalse);
    expect(result.failure!.message, contains('changed while you were viewing'));
    expect(result.failure!.message, isNot(contains('CLINIC_TASK')));
    expect(controller.taskDetail.task!.status, ClinicTaskStatus.blocked);
  });

  testWidgets('action matrix protects patient-information blocked tasks', (
    tester,
  ) async {
    final patientBlocked = _detail(
      status: 'BLOCKED',
      assignedMembershipId: membershipId,
      blockedReasonCode: 'WAITING_FOR_PATIENT_INFORMATION',
    );
    await _pumpDetail(tester, patientBlocked);
    expect(find.text('Waiting for patient information'), findsOneWidget);
    expect(find.text('Unblock task'), findsNothing);
    expect(find.text('Block task'), findsNothing);
    expect(find.text('Complete task'), findsNothing);
  });

  testWidgets(
    'administrative review shows specialized actions without complete',
    (tester) async {
      final repo = await _pumpDetail(
        tester,
        _detail(status: 'IN_PROGRESS', assignedMembershipId: membershipId),
        caseDetail: _caseDetail(
          status: 'UNDER_ADMIN_REVIEW',
          actions: const [
            'REQUEST_INFORMATION',
            'READY_FOR_PLANNING',
            'DECLINE',
          ],
        ),
      );
      expect(repo.caseDetailCalls, 1);
      expect(find.text('Request information'), findsOneWidget);
      expect(find.text('Ready for planning'), findsOneWidget);
      expect(find.text('Decline request'), findsOneWidget);
      expect(find.text('Block task'), findsOneWidget);
      expect(find.text('Complete task'), findsNothing);
    },
  );

  testWidgets('request coordination shows generic complete', (tester) async {
    await _pumpDetail(
      tester,
      _detail(
        taskType: 'REQUEST_COORDINATION',
        responsibilityType: 'REQUEST_COORDINATION',
        status: 'IN_PROGRESS',
        assignedMembershipId: membershipId,
      ),
    );
    expect(find.text('Complete task'), findsOneWidget);
    expect(find.text('Ready for planning'), findsNothing);
  });
}

Future<_ClinicRepositoryFake> _pumpDetail(
  WidgetTester tester,
  ClinicTaskDetail task, {
  ClinicCaseDetail? caseDetail,
}) async {
  final repo = _ClinicRepositoryFake()
    ..details[taskId] = task
    ..caseDetail = caseDetail ?? _caseDetail();
  final contextController = ClinicContextController(
    repository: repo,
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
        ChangeNotifierProvider<ClinicOperationalController>.value(
          value: ClinicOperationalController(repository: repo),
        ),
      ],
      child: MaterialApp(
        onGenerateRoute: (_) => MaterialPageRoute<void>(
          settings: const RouteSettings(arguments: taskId),
          builder: (_) => const ClinicTaskDetailScreen(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
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
    'capabilities': [
      'CLINIC_TASK_READ',
      'CLINIC_CASE_INTAKE_READ',
      'CLINIC_CASE_INTAKE_REVIEW',
    ],
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

ClinicTaskDetail _detail({
  String taskType = 'ADMINISTRATIVE_REVIEW',
  String responsibilityType = 'ADMISSIONS',
  String status = 'ASSIGNED',
  String? assignedMembershipId,
  String? blockedReasonCode,
  Object? startedAt = _notProvided,
  int version = 4,
}) {
  return ClinicTaskDetail.fromJson(
    _taskJson(
      taskType: taskType,
      responsibilityType: responsibilityType,
      status: status,
      assignedMembershipId: assignedMembershipId,
      blockedReasonCode: blockedReasonCode,
      startedAt: startedAt,
      version: version,
    ),
  );
}

Map<String, dynamic> _taskJson({
  String taskType = 'ADMINISTRATIVE_REVIEW',
  String responsibilityType = 'ADMISSIONS',
  String status = 'ASSIGNED',
  String? assignedMembershipId,
  String? blockedReasonCode,
  Object? startedAt = _notProvided,
  int version = 4,
}) {
  return {
    'taskId': taskId,
    'caseId': caseId,
    'taskType': taskType,
    'responsibilityType': responsibilityType,
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
    'blockedReasonCode':
        blockedReasonCode ??
        (status == 'BLOCKED' ? 'WAITING_FOR_INTERNAL_COORDINATION' : null),
    'acknowledgedAt': assignedMembershipId == null
        ? null
        : '2026-08-13T09:10:00Z',
    'startedAt': identical(startedAt, _notProvided)
        ? (status == 'IN_PROGRESS' || status == 'BLOCKED'
              ? '2026-08-13T09:20:00Z'
              : null)
        : startedAt as String?,
    'completedAt': status == 'COMPLETED' ? '2026-08-13T11:00:00Z' : null,
    'caseContext': {
      'caseId': caseId,
      'sourceRequestId': requestId,
      'intakeStatus':
          status == 'BLOCKED' &&
              (blockedReasonCode == 'WAITING_FOR_PATIENT_INFORMATION')
          ? 'INFORMATION_REQUIRED'
          : 'UNDER_ADMIN_REVIEW',
      'situation': 'APPOINTMENT',
      'priority': 'NORMAL',
      'currentStepKey': taskType == 'REQUEST_COORDINATION'
          ? 'REQUEST_COORDINATION'
          : 'ADMINISTRATIVE_REVIEW',
      'submittedAt': '2026-08-13T08:59:00Z',
      'hasOpenRoutingIncident': false,
    },
  };
}

ClinicCaseDetail _caseDetail({
  String status = 'RECEIVED',
  List<String> actions = const ['START_REVIEW'],
  int version = 11,
  Map<String, dynamic>? informationRequest,
}) {
  return ClinicCaseDetail.fromJson(
    _caseJson(
      status: status,
      actions: actions,
      version: version,
      informationRequest: informationRequest,
    ),
  );
}

Map<String, dynamic> _caseJson({
  String status = 'RECEIVED',
  List<String> actions = const ['START_REVIEW'],
  int version = 11,
  Map<String, dynamic>? informationRequest,
}) {
  return {
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
  };
}

const Object _notProvided = Object();

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

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicare_mobile/core/network/app_http_client.dart';
import 'package:omnicare_mobile/core/storage/secure_token_store.dart';
import 'package:omnicare_mobile/features/doctor/urgent_cabinet/doctor_urgent_cabinet_commitment.dart';
import 'package:omnicare_mobile/features/doctor/urgent_cabinet/doctor_urgent_cabinet_accepted_sheet.dart';
import 'package:omnicare_mobile/features/doctor/urgent_cabinet/doctor_urgent_cabinet_controller.dart';
import 'package:omnicare_mobile/features/doctor/urgent_cabinet/doctor_urgent_cabinet_decision.dart';
import 'package:omnicare_mobile/features/doctor/urgent_cabinet/doctor_urgent_cabinet_decision_source.dart';
import 'package:omnicare_mobile/features/doctor/urgent_cabinet/doctor_urgent_cabinet_repository.dart';
import 'package:omnicare_mobile/features/doctor/urgent_cabinet/doctor_urgent_cabinet_request.dart';
import 'package:omnicare_mobile/features/doctor/urgent_cabinet/doctor_urgent_cabinet_request_source.dart';
import 'package:omnicare_mobile/features/doctor/workspace/doctor_workspace_config.dart';

const _doctorId = '11111111-1111-4111-8111-111111111111';
const _requestId = '22222222-2222-4222-8222-222222222222';
const _secondRequestId = '33333333-3333-4333-8333-333333333333';
const _locationId = '44444444-4444-4444-8444-444444444444';
const _commitmentId = '55555555-5555-4555-8555-555555555555';

class _MemoryStorage implements SecureTokenStorageBackend {
  @override
  Future<void> delete({required String key}) async {}

  @override
  Future<String?> read({required String key}) async => null;

  @override
  Future<void> write({required String key, required String value}) async {}
}

class _NetworkFailure {
  const _NetworkFailure();
}

class _StatusResponse {
  const _StatusResponse(this.statusCode, this.body);

  final int statusCode;
  final Object body;
}

class _QueueAdapter implements HttpClientAdapter {
  final responses = <Object>[];
  final requests = <RequestOptions>[];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final next = responses.removeAt(0);
    if (next is _NetworkFailure) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
      );
    }
    if (next is _StatusResponse) {
      return ResponseBody.fromString(
        jsonEncode(next.body),
        next.statusCode,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
          HttpHeaders.cacheControlHeader: ['no-store'],
        },
      );
    }
    return ResponseBody.fromString(
      jsonEncode(next),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
        HttpHeaders.cacheControlHeader: ['no-store'],
      },
    );
  }
}

class _FakeRepository implements DoctorUrgentCabinetRepositoryContract {
  DoctorUrgentCabinetFeedState feed = const DoctorUrgentCabinetFeedEmpty();
  List<DoctorUrgentCabinetCommitment> commitments = const [];
  int feedCalls = 0;
  int commitmentCalls = 0;
  int clearCalls = 0;
  DoctorUrgentCabinetNotificationTarget? notificationTarget;
  Object? notificationTargetError;

  @override
  bool get isDevelopmentFixture => false;

  @override
  Future<DoctorUrgentCabinetFeedState> load(
    DoctorUrgentCabinetRequestContext context, {
    CancelToken? cancelToken,
  }) async {
    feedCalls++;
    return feed;
  }

  @override
  Future<List<DoctorUrgentCabinetCommitment>> listCommitments({
    int limit = 20,
    CancelToken? cancelToken,
  }) async {
    commitmentCalls++;
    return commitments;
  }

  @override
  Future<DoctorUrgentCabinetNotificationTarget> resolveNotificationTarget(
    String requestId,
    DoctorUrgentCabinetRequestContext context, {
    CancelToken? cancelToken,
  }) async {
    if (notificationTargetError case final error?) throw error;
    final target = notificationTarget;
    if (target == null) {
      throw const DoctorUrgentCabinetFailure(
        kind: DoctorUrgentCabinetFailureKind.notFound,
        message: 'not found',
      );
    }
    return target;
  }

  @override
  void clearSessionState() => clearCalls++;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DeferredRequestSource implements DoctorUrgentCabinetRequestSource {
  final Completer<DoctorUrgentCabinetFeedState> result = Completer();
  int calls = 0;

  @override
  Future<DoctorUrgentCabinetFeedState> load(
    DoctorUrgentCabinetRequestContext context, {
    CancelToken? cancelToken,
  }) {
    calls++;
    return result.future;
  }
}

DoctorWorkspaceConfig _workspace({
  bool urgentCapability = true,
  String doctorId = _doctorId,
}) => DoctorWorkspaceConfig(
  doctorId: doctorId,
  onboardingCompleted: true,
  practiceModes: const {DoctorPracticeMode.cabinet},
  services: {
    if (urgentCapability) DoctorWorkspaceService.urgentCabinetConsultations,
  },
  cabinet: const DoctorCabinetConfig(
    name: 'Cabinet synthétique',
    governorate: 'Tunis',
    city: 'Tunis',
    address: '1, rue Synthétique',
  ),
  clinics: const [],
  availability: const DoctorAvailability(
    workingDays: {DoctorWorkingDay.monday},
    startTime: '08:00',
    endTime: '17:00',
  ),
);

Map<String, Object?> _pendingRequest(String requestId) => {
  'requestId': requestId,
  'practiceLocationId': _locationId,
  'responseStatus': 'PENDING',
  'responseRevision': 0,
  'respondedAt': null,
  'commitmentId': null,
  'commitmentStatus': null,
  'commitmentRevision': null,
  'committedAt': null,
  'state': 'CABINET_PENDING',
  'requestRevision': 1,
  'bodyAreaCodes': ['CHEST', 'UPPER_LIMB'],
  'painScore': 6,
  'shortDescription': 'Douleur aiguë depuis ce matin.',
  'quotedFeeTnd': 75.000,
  'currency': 'TND',
  'createdAt': '2026-10-17T10:00:00Z',
  'responseDeadlineAt': null,
  'allowedActions': ['ACCEPT', 'DECLINE'],
  'evaluatedAt': '2026-10-17T10:00:01Z',
};

Map<String, Object?> _pendingRequestWithActions(
  String requestId,
  List<String> allowedActions,
) => {..._pendingRequest(requestId), 'allowedActions': allowedActions};

Map<String, Object?> _notificationRequestState(
  String responseStatus, {
  String state = 'CABINET_CANCELLED',
}) => {
  ..._pendingRequest(_requestId),
  'responseStatus': responseStatus,
  'responseRevision': 1,
  'respondedAt': '2026-10-17T10:02:00Z',
  'state': state,
  'requestRevision': 2,
  'responseDeadlineAt': '2026-10-17T10:05:00Z',
  'terminalAt': state == 'CABINET_CANCELLED' ? '2026-10-17T10:02:00Z' : null,
  'terminalReason': state == 'CABINET_CANCELLED' ? responseStatus : null,
  'allowedActions': <String>[],
  if (responseStatus == 'ACCEPTED') ...{
    'commitmentId': _commitmentId,
    'commitmentStatus': 'ACTIVE',
    'commitmentRevision': 0,
    'committedAt': '2026-10-17T10:02:00Z',
  },
};

Map<String, Object?> _commitment() => {
  'commitmentId': _commitmentId,
  'requestId': _requestId,
  'practiceLocationId': _locationId,
  'status': 'ACTIVE',
  'revision': 0,
  'quotedFeeTnd': 75.000,
  'currency': 'TND',
  'quoteConfigurationRevision': 7,
  'committedAt': '2026-10-17T10:02:00Z',
  'arrivalVerifiedAt': null,
  'terminalAt': null,
  'updatedAt': '2026-10-17T10:02:00Z',
  'allowedActions': ['VERIFY_ARRIVAL'],
  'evaluatedAt': '2026-10-17T10:02:01Z',
};

Map<String, Object?> _terminalCommitment() => {
  ..._commitment(),
  'status': 'CANCELLED',
  'revision': 1,
  'terminalAt': '2026-10-17T10:05:00Z',
  'updatedAt': '2026-10-17T10:05:00Z',
  'allowedActions': [],
  'evaluatedAt': '2026-10-17T10:05:01Z',
};

Map<String, Object?> _decision({
  required bool accepted,
  bool replayed = false,
}) => {
  'requestId': _requestId,
  'responseStatus': accepted ? 'ACCEPTED' : 'DECLINED',
  'requestState': accepted ? 'CABINET_COMMITTED' : 'CABINET_CANCELLED',
  'requestRevision': 2,
  'commitmentId': accepted ? _commitmentId : null,
  'commitmentStatus': accepted ? 'ACTIVE' : null,
  'commitmentRevision': accepted ? 0 : null,
  'practiceLocationId': _locationId,
  'quotedFeeTnd': 75.000,
  'currency': 'TND',
  'respondedAt': '2026-10-17T10:02:00Z',
  'committedAt': accepted ? '2026-10-17T10:02:00Z' : null,
  'allowedActions': [],
  'replayed': replayed,
  'evaluatedAt': '2026-10-17T10:02:01Z',
};

DoctorUrgentCabinetRepository _repository(
  _QueueAdapter adapter, {
  String Function()? keyFactory,
  void Function()? onSessionRejected,
}) {
  final dio = Dio()..httpClientAdapter = adapter;
  final refreshDio = Dio()..httpClientAdapter = adapter;
  return DoctorUrgentCabinetRepository(
    AppHttpClient(
      tokenStore: SecureTokenStore(backend: _MemoryStorage()),
      baseUrl: 'https://example.test',
      dio: dio,
      refreshDio: refreshDio,
    ),
    idempotencyKeyFactory: keyFactory ?? () => 'fixed-command-key',
    onSessionRejected: onSessionRejected,
  );
}

DoctorUrgentCabinetRequest _serviceRequest(
  String requestId, {
  String doctorId = _doctorId,
}) => DoctorUrgentCabinetRequest(
  developmentFixtureKey: null,
  targetDoctorId: doctorId,
  targetCabinetIdentity: DoctorUrgentCabinetServerTargetIdentity(_locationId),
  cabinet: DoctorUrgentCabinetSnapshot(
    name: 'Cabinet synthétique',
    governorate: 'Tunis',
    city: 'Tunis',
    address: '1, rue Synthétique',
  ),
  patient: const DoctorUrgentCabinetPatientProjection.masked(),
  fee: DoctorUrgentCabinetFeeSnapshot(
    amountMilliTnd: 75000,
    currencyCode: 'TND',
    provenance: DoctorUrgentCabinetFeeProvenance.service,
  ),
  dataProvenance: DoctorUrgentCabinetDataProvenance.service,
  status: DoctorUrgentCabinetRequestStatus.newRequest,
  serverRequestReference: requestId,
  serverRequestRevision: 1,
  bodyAreas: const [DoctorUrgentCabinetBodyArea.chest],
  painScore: 6,
  shortDescription: 'Douleur aiguë depuis ce matin.',
  createdAt: DateTime.utc(2026, 10, 17, 10),
  evaluatedAt: DateTime.utc(2026, 10, 17, 10, 0, 1),
);

void main() {
  test(
    'strict inbox and detail mapping retain only authorized projection',
    () async {
      final adapter = _QueueAdapter()
        ..responses.addAll([
          [
            {..._pendingRequest(_requestId), 'patientName': 'Do not disclose'},
            _pendingRequest(_secondRequestId),
          ],
          _pendingRequest(_requestId),
        ]);
      final repository = _repository(adapter);
      final context = DoctorUrgentCabinetRequestContext.fromWorkspace(
        _workspace(),
      );

      final feed = await repository.load(context);
      expect(feed, isA<DoctorUrgentCabinetFeedLoaded>());
      final requests = (feed as DoctorUrgentCabinetFeedLoaded).requests;
      expect(requests.map((request) => request.stableIdentity), [
        _requestId,
        _secondRequestId,
      ]);
      expect(requests.first.targetDoctorId, _doctorId);
      expect(requests.first.serverRequestRevision, 1);
      expect(requests.first.bodyAreas, [
        DoctorUrgentCabinetBodyArea.chest,
        DoctorUrgentCabinetBodyArea.upperLimb,
      ]);
      expect(requests.first.painScore, 6);
      expect(requests.first.fee.amountMilliTnd, 75000);
      expect(requests.first.patient.label, 'Patient concerné');

      final detail = await repository.getRequest(_requestId, context);
      expect(detail.stableIdentity, _requestId);
      expect(adapter.requests[1].path, endsWith('/$_requestId'));
    },
  );

  test('notification detail maps authoritative terminal outcomes', () async {
    final context = DoctorUrgentCabinetRequestContext.fromWorkspace(
      _workspace(),
    );
    final cases = <String, DoctorUrgentCabinetNotificationTargetState>{
      'DECLINED': DoctorUrgentCabinetNotificationTargetState.declined,
      'CANCELLED': DoctorUrgentCabinetNotificationTargetState.cancelled,
      'EXPIRED': DoctorUrgentCabinetNotificationTargetState.expired,
    };
    for (final entry in cases.entries) {
      final adapter = _QueueAdapter()
        ..responses.add(_notificationRequestState(entry.key));
      final target = await _repository(
        adapter,
      ).resolveNotificationTarget(_requestId, context);
      expect(target.requestId, _requestId);
      expect(target.state, entry.value);
      expect(target.pendingRequest, isNull);
    }
  });

  test(
    'notification detail maps accepted commitment without actions',
    () async {
      final adapter = _QueueAdapter()
        ..responses.add(
          _notificationRequestState('ACCEPTED', state: 'CABINET_COMMITTED'),
        );
      final target = await _repository(adapter).resolveNotificationTarget(
        _requestId,
        DoctorUrgentCabinetRequestContext.fromWorkspace(_workspace()),
      );
      expect(target.state, DoctorUrgentCabinetNotificationTargetState.accepted);
      expect(target.commitmentId, _commitmentId);
      expect(target.pendingRequest, isNull);
    },
  );

  test('authoritative empty inbox does not create fixture requests', () async {
    final adapter = _QueueAdapter()..responses.add(const []);
    final repository = _repository(adapter);
    final context = DoctorUrgentCabinetRequestContext.fromWorkspace(
      _workspace(),
    );

    final feed = await repository.load(context);

    expect(feed, isA<DoctorUrgentCabinetFeedEmpty>());
    expect(adapter.requests.single.queryParameters, {'limit': 20});
  });

  test(
    'pending authority accepts both actions or decline-only and rejects every other shape',
    () async {
      final context = DoctorUrgentCabinetRequestContext.fromWorkspace(
        _workspace(),
      );

      for (final allowedActions in const <List<String>>[
        ['ACCEPT', 'DECLINE'],
        ['DECLINE'],
      ]) {
        final adapter = _QueueAdapter()
          ..responses.add([
            _pendingRequestWithActions(_requestId, allowedActions),
          ]);
        final repository = _repository(adapter);
        final feed = await repository.load(context);

        expect(feed, isA<DoctorUrgentCabinetFeedLoaded>());
        final request = (feed as DoctorUrgentCabinetFeedLoaded).requests.single;
        expect(request.canAccept, allowedActions.contains('ACCEPT'));
        expect(request.canDecline, isTrue);
        if (!request.canAccept) {
          final result = await repository.decide(
            request: request,
            action: DoctorUrgentCabinetDecisionAction.accept,
            context: DoctorUrgentCabinetDecisionContext(
              authenticatedDoctorId: _doctorId,
              workspace: _workspace(),
            ),
          );
          expect(
            result,
            isA<DoctorUrgentCabinetDecisionDefiniteFailureResult>(),
          );
          expect(adapter.requests, hasLength(1));
        }
      }

      for (final invalidActions in const <List<String>>[
        [],
        ['ACCEPT'],
        ['DECLINE', 'DECLINE'],
        ['ACCEPT', 'DECLINE', 'PAUSE'],
      ]) {
        final adapter = _QueueAdapter()
          ..responses.add([
            _pendingRequestWithActions(_requestId, invalidActions),
          ]);
        final feed = await _repository(adapter).load(context);

        expect(feed, isA<DoctorUrgentCabinetFeedError>());
        expect((feed as DoctorUrgentCabinetFeedError).canRetry, isTrue);
      }
    },
  );

  test(
    'runtime-OFF decline-only refresh preserves the request and forbids accept',
    () async {
      final adapter = _QueueAdapter()
        ..responses.addAll([
          [_pendingRequest(_requestId)],
          [
            _pendingRequestWithActions(_requestId, const ['DECLINE']),
          ],
          _decision(accepted: false),
          const <Object?>[],
        ]);
      final repository = _repository(adapter);
      final controller =
          DoctorUrgentCabinetController(developmentSimulationEnabled: false)
            ..configure(
              authenticatedDoctorId: _doctorId,
              workspaceConfig: _workspace(),
              requestSource: repository,
              decisionSource: repository,
            );
      addTearDown(controller.dispose);
      await pumpEventQueue();

      expect(controller.visibleNewRequests.single.canAccept, isTrue);
      expect(controller.canReconcileInForeground, isTrue);

      expect(await controller.refresh(showLoading: false), isTrue);
      final declineOnly = controller.visibleNewRequests.single;
      expect(declineOnly.canAccept, isFalse);
      expect(declineOnly.canDecline, isTrue);
      expect(
        await controller.accept(declineOnly.stableIdentity),
        DoctorUrgentCabinetDecisionTransition.rejected,
      );
      expect(
        adapter.requests.where((request) => request.method == 'POST'),
        isEmpty,
      );

      expect(
        await controller.refuse(declineOnly.stableIdentity),
        DoctorUrgentCabinetDecisionTransition.declined,
      );
      final posts = adapter.requests
          .where((request) => request.method == 'POST')
          .toList();
      expect(posts, hasLength(1));
      expect(posts.single.path, endsWith('/$_requestId/decline'));
      expect(
        controller.stateFor(_requestId),
        isA<DoctorUrgentCabinetDeclined>(),
      );
    },
  );

  test('protected rejection exits the session and exposes no inbox', () async {
    final adapter = _QueueAdapter()
      ..responses.add(const _StatusResponse(403, {'code': 'ACCESS_DENIED'}));
    var sessionRejections = 0;
    final repository = _repository(
      adapter,
      onSessionRejected: () => sessionRejections++,
    );
    final context = DoctorUrgentCabinetRequestContext.fromWorkspace(
      _workspace(),
    );

    final feed = await repository.load(context);

    expect(feed, isA<DoctorUrgentCabinetFeedError>());
    expect((feed as DoctorUrgentCabinetFeedError).canRetry, isFalse);
    expect(sessionRejections, 1);
  });

  test(
    'ambiguous accept reuses its key and recovers the replayed commitment',
    () async {
      final adapter = _QueueAdapter()
        ..responses.addAll([
          _pendingRequest(_requestId),
          const _NetworkFailure(),
          _decision(accepted: true, replayed: true),
          _commitment(),
        ]);
      var keyCalls = 0;
      final repository = _repository(
        adapter,
        keyFactory: () {
          keyCalls++;
          return 'accept-key-$keyCalls';
        },
      );
      final context = DoctorUrgentCabinetDecisionContext(
        authenticatedDoctorId: _doctorId,
        workspace: _workspace(),
      );
      final request = await repository.getRequest(
        _requestId,
        context.requestContext,
      );

      final first = await repository.decide(
        request: request,
        action: DoctorUrgentCabinetDecisionAction.accept,
        context: context,
      );
      final second = await repository.decide(
        request: request,
        action: DoctorUrgentCabinetDecisionAction.accept,
        context: context,
      );

      expect(first, isA<DoctorUrgentCabinetDecisionUnknownResult>());
      expect(second, isA<DoctorUrgentCabinetAcceptedResult>());
      expect(
        (second as DoctorUrgentCabinetAcceptedResult).commitment?.commitmentId,
        _commitmentId,
      );
      final posts = adapter.requests.where(
        (request) => request.method == 'POST',
      );
      expect(posts.length, 2);
      expect(
        posts.map((request) => request.headers['Idempotency-Key']).toSet(),
        {'accept-key-1'},
      );
      expect(posts.last.data, {'expectedRequestRevision': 1});
      expect(keyCalls, 1);
    },
  );

  test(
    'decline replay remains commitment-free and reuses the exact command',
    () async {
      final adapter = _QueueAdapter()
        ..responses.addAll([
          _pendingRequest(_requestId),
          const _NetworkFailure(),
          _decision(accepted: false, replayed: true),
        ]);
      var keyCalls = 0;
      final repository = _repository(
        adapter,
        keyFactory: () {
          keyCalls++;
          return 'decline-key-$keyCalls';
        },
      );
      final context = DoctorUrgentCabinetDecisionContext(
        authenticatedDoctorId: _doctorId,
        workspace: _workspace(),
      );
      final request = await repository.getRequest(
        _requestId,
        context.requestContext,
      );

      final first = await repository.decide(
        request: request,
        action: DoctorUrgentCabinetDecisionAction.refuse,
        context: context,
      );
      final second = await repository.decide(
        request: request,
        action: DoctorUrgentCabinetDecisionAction.refuse,
        context: context,
      );

      expect(first, isA<DoctorUrgentCabinetDecisionUnknownResult>());
      expect(second, isA<DoctorUrgentCabinetDeclinedResult>());
      final posts = adapter.requests.where(
        (candidate) => candidate.method == 'POST',
      );
      expect(posts.length, 2);
      expect(posts.last.path, endsWith('/$_requestId/decline'));
      expect(posts.last.data, {'expectedRequestRevision': 1});
      expect(
        posts.map((request) => request.headers['Idempotency-Key']).toSet(),
        {'decline-key-1'},
      );
      expect(keyCalls, 1);
    },
  );

  test(
    'commitment recovery is independent from current CABINET capability',
    () {
      final context = DoctorUrgentCabinetRequestContext.fromWorkspace(
        _workspace(urgentCapability: false),
      );
      final commitment = parseDoctorUrgentCabinetCommitment(_commitment());

      expect(context.isComplete, isFalse);
      expect(context.hasCommitmentRecoveryContext, isTrue);
      final request = commitment.toRecoveredRequest(context);
      expect(request.status, DoctorUrgentCabinetRequestStatus.committed);
      expect(request.serverCommitmentReference, _commitmentId);
      expect(request.patient.label, 'Patient concerné');
    },
  );

  test(
    'ambiguous arrival retry reuses one key and accepts only non-clinical server truth',
    () async {
      final adapter = _QueueAdapter()
        ..responses.addAll([
          const _NetworkFailure(),
          {
            'commitmentId': _commitmentId,
            'requestId': _requestId,
            'commitmentRevision': 1,
            'arrivalVerifiedAt': '2026-10-17T10:04:00Z',
            'consultationStarted': false,
            'mrsAccessGranted': false,
            'replayed': true,
            'evaluatedAt': '2026-10-17T10:04:01Z',
          },
        ]);
      var keyCalls = 0;
      final repository = _repository(
        adapter,
        keyFactory: () => 'arrival-key-${++keyCalls}',
      );
      final commitment = parseDoctorUrgentCabinetCommitment(_commitment());

      await expectLater(
        repository.verifyArrival(
          commitment: commitment,
          token: 'OCAB1.payload.signature',
        ),
        throwsA(
          isA<DoctorUrgentCabinetFailure>().having(
            (failure) => failure.kind,
            'kind',
            DoctorUrgentCabinetFailureKind.network,
          ),
        ),
      );
      final result = await repository.verifyArrival(
        commitment: commitment,
        token: 'OCAB1.payload.signature',
      );

      expect(result.replayed, isTrue);
      expect(result.commitmentRevision, 1);
      final posts = adapter.requests
          .where((request) => request.method == 'POST')
          .toList();
      expect(posts, hasLength(2));
      expect(
        posts.map((request) => request.headers['Idempotency-Key']).toSet(),
        {'arrival-key-1'},
      );
      expect(
        posts.last.path,
        endsWith('/$_commitmentId/arrival-verifications'),
      );
      expect(posts.last.data, {
        'token': 'OCAB1.payload.signature',
        'expectedCommitmentRevision': 0,
      });
      expect(keyCalls, 1);
    },
  );

  test(
    'capacity conflict is definite and does not invent acceptance',
    () async {
      final failure = DoctorUrgentCabinetFailure.from(
        DioException(
          requestOptions: RequestOptions(path: '/accept'),
          response: Response<dynamic>(
            requestOptions: RequestOptions(path: '/accept'),
            statusCode: 409,
            data: const {'code': 'URGENT_CABINET_RESPONSE_CAPACITY_CONFLICT'},
          ),
          type: DioExceptionType.badResponse,
        ),
      );

      expect(failure.kind, DoctorUrgentCabinetFailureKind.capacityConflict);
      expect(failure.hasAmbiguousCommandOutcome, isFalse);
    },
  );

  test(
    'active commitment recovery blocks but does not terminate competitors',
    () async {
      final repository = _FakeRepository()
        ..feed = DoctorUrgentCabinetFeedLoaded([
          _serviceRequest(_secondRequestId),
        ])
        ..commitments = [parseDoctorUrgentCabinetCommitment(_commitment())];
      final controller =
          DoctorUrgentCabinetController(developmentSimulationEnabled: false)
            ..configure(
              authenticatedDoctorId: _doctorId,
              workspaceConfig: _workspace(),
              requestSource: repository,
              decisionSource: repository,
              commitmentSource: repository,
            );
      addTearDown(controller.dispose);
      await pumpEventQueue();

      expect(controller.hasVisibleResponsibility, isTrue);
      expect(
        controller.stateFor(_requestId),
        isA<DoctorUrgentCabinetAccepted>(),
      );
      expect(
        controller.stateFor(_secondRequestId),
        isA<DoctorUrgentCabinetCapacityBlocked>(),
      );
      expect(
        await controller.accept(_secondRequestId),
        DoctorUrgentCabinetDecisionTransition.rejected,
      );
      expect(
        controller.visibleNewRequests.single.stableIdentity,
        _secondRequestId,
      );
    },
  );

  test(
    'commitment remains recoverable after urgent capability removal',
    () async {
      final repository = _FakeRepository()
        ..commitments = [parseDoctorUrgentCabinetCommitment(_commitment())];
      final controller =
          DoctorUrgentCabinetController(developmentSimulationEnabled: false)
            ..configure(
              authenticatedDoctorId: _doctorId,
              workspaceConfig: _workspace(urgentCapability: false),
              requestSource: repository,
              decisionSource: repository,
              commitmentSource: repository,
            );
      addTearDown(controller.dispose);
      await pumpEventQueue();

      expect(controller.canReconcileInForeground, isTrue);
      expect(repository.feedCalls, 0);
      expect(repository.commitmentCalls, 1);
      expect(controller.hasVisibleResponsibility, isTrue);

      controller.clear();
      expect(controller.entries, isEmpty);
      expect(controller.hasVisibleResponsibility, isFalse);
      expect(repository.clearCalls, 1);
    },
  );

  test(
    'capability removal retains responsibility during revalidation',
    () async {
      final repository = _FakeRepository()
        ..commitments = [parseDoctorUrgentCabinetCommitment(_commitment())];
      final controller =
          DoctorUrgentCabinetController(developmentSimulationEnabled: false)
            ..configure(
              authenticatedDoctorId: _doctorId,
              workspaceConfig: _workspace(),
              requestSource: repository,
              decisionSource: repository,
              commitmentSource: repository,
            );
      addTearDown(controller.dispose);
      await pumpEventQueue();
      expect(controller.hasVisibleResponsibility, isTrue);

      controller.configure(
        authenticatedDoctorId: _doctorId,
        workspaceConfig: _workspace(urgentCapability: false),
        requestSource: repository,
        decisionSource: repository,
        commitmentSource: repository,
      );

      expect(controller.hasVisibleResponsibility, isTrue);
      await pumpEventQueue();
      expect(controller.hasVisibleResponsibility, isTrue);
    },
  );

  test('terminal commitment clears recovered responsibility', () async {
    final repository = _FakeRepository()
      ..commitments = [parseDoctorUrgentCabinetCommitment(_commitment())];
    final controller =
        DoctorUrgentCabinetController(developmentSimulationEnabled: false)
          ..configure(
            authenticatedDoctorId: _doctorId,
            workspaceConfig: _workspace(urgentCapability: false),
            requestSource: repository,
            decisionSource: repository,
            commitmentSource: repository,
          );
    addTearDown(controller.dispose);
    await pumpEventQueue();
    expect(controller.hasVisibleResponsibility, isTrue);

    repository.commitments = [
      parseDoctorUrgentCabinetCommitment(_terminalCommitment()),
    ];
    await controller.refresh();

    expect(controller.hasVisibleResponsibility, isFalse);
    expect(
      controller.stateFor(_requestId),
      isA<DoctorUrgentCabinetUnavailable>(),
    );
  });

  test('foreground refresh discovers a newly submitted request once', () async {
    final repository = _FakeRepository();
    final controller =
        DoctorUrgentCabinetController(developmentSimulationEnabled: false)
          ..configure(
            authenticatedDoctorId: _doctorId,
            workspaceConfig: _workspace(),
            requestSource: repository,
            decisionSource: repository,
            commitmentSource: repository,
          );
    addTearDown(controller.dispose);
    await pumpEventQueue();
    expect(controller.visibleNewRequests, isEmpty);

    repository.feed = DoctorUrgentCabinetFeedLoaded([
      _serviceRequest(_secondRequestId),
    ]);
    final first = controller.refresh(showLoading: false);
    final second = controller.refresh(showLoading: false);

    expect(identical(first, second), isTrue);
    await first;
    expect(
      controller.visibleNewRequests.single.stableIdentity,
      _secondRequestId,
    );
    expect(repository.feedCalls, 2);
  });

  test(
    'notification target is exposed only after authoritative inbox refresh',
    () async {
      final repository = _FakeRepository();
      final controller =
          DoctorUrgentCabinetController(developmentSimulationEnabled: false)
            ..configure(
              authenticatedDoctorId: _doctorId,
              workspaceConfig: _workspace(),
              requestSource: repository,
              decisionSource: repository,
              commitmentSource: repository,
            );
      addTearDown(controller.dispose);
      await pumpEventQueue();

      expect(await controller.openFromNotification(_requestId), isFalse);
      expect(controller.takeNotificationOpenRequestIdentity(), isNull);

      repository.feed = DoctorUrgentCabinetFeedLoaded([
        _serviceRequest(_requestId),
      ]);
      expect(await controller.openFromNotification(_requestId), isTrue);
      expect(controller.takeNotificationOpenRequestIdentity(), _requestId);
      expect(controller.takeNotificationOpenRequestIdentity(), isNull);
    },
  );

  test('accepted notification opens only recovered owned commitment', () async {
    final repository = _FakeRepository()
      ..commitments = [parseDoctorUrgentCabinetCommitment(_commitment())];
    final controller =
        DoctorUrgentCabinetController(developmentSimulationEnabled: false)
          ..configure(
            authenticatedDoctorId: _doctorId,
            workspaceConfig: _workspace(),
            requestSource: repository,
            decisionSource: repository,
            commitmentSource: repository,
          );
    addTearDown(controller.dispose);
    await pumpEventQueue();

    expect(await controller.openFromNotification(_requestId), isTrue);
    final intent = controller.takeNotificationOpenIntent();
    expect(intent?.requestIdentity, _requestId);
    expect(intent?.state, DoctorUrgentCabinetNotificationTargetState.accepted);
    expect(controller.stateFor(_requestId), isA<DoctorUrgentCabinetAccepted>());
  });

  test(
    'expired notification exposes status but never decision authority',
    () async {
      final repository = _FakeRepository()
        ..notificationTarget = const DoctorUrgentCabinetNotificationTarget(
          requestId: _requestId,
          state: DoctorUrgentCabinetNotificationTargetState.expired,
        );
      final controller =
          DoctorUrgentCabinetController(developmentSimulationEnabled: false)
            ..configure(
              authenticatedDoctorId: _doctorId,
              workspaceConfig: _workspace(),
              requestSource: repository,
              decisionSource: repository,
              commitmentSource: repository,
            );
      addTearDown(controller.dispose);
      await pumpEventQueue();

      expect(await controller.openFromNotification(_requestId), isTrue);
      expect(
        controller.takeNotificationOpenIntent()?.state,
        DoctorUrgentCabinetNotificationTargetState.expired,
      );
      expect(controller.containsCurrentRequest(_requestId), isFalse);
    },
  );

  test(
    'foreign notification target fails closed without navigation intent',
    () async {
      final repository = _FakeRepository()
        ..notificationTargetError = const DoctorUrgentCabinetFailure(
          kind: DoctorUrgentCabinetFailureKind.notFound,
          message: 'not found',
        );
      final controller =
          DoctorUrgentCabinetController(developmentSimulationEnabled: false)
            ..configure(
              authenticatedDoctorId: _doctorId,
              workspaceConfig: _workspace(),
              requestSource: repository,
              decisionSource: repository,
              commitmentSource: repository,
            );
      addTearDown(controller.dispose);
      await pumpEventQueue();

      expect(await controller.openFromNotification(_requestId), isFalse);
      expect(controller.takeNotificationOpenIntent(), isNull);
    },
  );

  test(
    'inaccessible Doctor context never starts authoritative reads',
    () async {
      const otherDoctorId = '77777777-7777-4777-8777-777777777777';
      final repository = _FakeRepository();
      final controller =
          DoctorUrgentCabinetController(developmentSimulationEnabled: false)
            ..configure(
              authenticatedDoctorId: otherDoctorId,
              workspaceConfig: _workspace(),
              requestSource: repository,
              commitmentSource: repository,
            );
      addTearDown(controller.dispose);
      await pumpEventQueue();

      expect(controller.canReconcileInForeground, isFalse);
      expect(repository.feedCalls, 0);
      expect(repository.commitmentCalls, 0);
      expect(await controller.refresh(showLoading: false), isFalse);
    },
  );

  test(
    'logout rejects a late inbox response from the cleared session',
    () async {
      final source = _DeferredRequestSource();
      final controller =
          DoctorUrgentCabinetController(developmentSimulationEnabled: false)
            ..configure(
              authenticatedDoctorId: _doctorId,
              workspaceConfig: _workspace(),
              requestSource: source,
            );
      addTearDown(controller.dispose);
      expect(source.calls, 1);

      controller.clear();
      source.result.complete(
        DoctorUrgentCabinetFeedLoaded([_serviceRequest(_requestId)]),
      );
      await pumpEventQueue();

      expect(controller.context, isNull);
      expect(controller.entries, isEmpty);
      expect(await controller.refresh(showLoading: false), isFalse);
    },
  );

  test(
    'account switch rejects the previous account response generation',
    () async {
      const secondDoctorId = '66666666-6666-4666-8666-666666666666';
      final previousSource = _DeferredRequestSource();
      final currentSource = _FakeRepository()
        ..feed = DoctorUrgentCabinetFeedLoaded([
          _serviceRequest(_secondRequestId, doctorId: secondDoctorId),
        ]);
      final controller =
          DoctorUrgentCabinetController(developmentSimulationEnabled: false)
            ..configure(
              authenticatedDoctorId: _doctorId,
              workspaceConfig: _workspace(),
              requestSource: previousSource,
            );
      addTearDown(controller.dispose);
      expect(previousSource.calls, 1);

      controller.configure(
        authenticatedDoctorId: secondDoctorId,
        workspaceConfig: _workspace(doctorId: secondDoctorId),
        requestSource: currentSource,
      );
      await pumpEventQueue();
      previousSource.result.complete(
        DoctorUrgentCabinetFeedLoaded([_serviceRequest(_requestId)]),
      );
      await pumpEventQueue();

      expect(controller.context?.authenticatedDoctorId, secondDoctorId);
      expect(
        controller.visibleNewRequests.map((request) => request.stableIdentity),
        [_secondRequestId],
      );
      expect(controller.stateFor(_requestId), isNull);
    },
  );

  test('authoritative commitments cannot enter arrival verification', () {
    expect(
      canVerifyDoctorUrgentCabinetArrival(_serviceRequest(_requestId)),
      isFalse,
    );
  });
}

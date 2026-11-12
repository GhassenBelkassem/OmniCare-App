import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omnicare_mobile/core/models/family_models.dart';
import 'package:omnicare_mobile/core/network/app_http_client.dart';
import 'package:omnicare_mobile/core/storage/secure_token_store.dart';
import 'package:omnicare_mobile/features/request_core/application/request_submission_controller.dart';
import 'package:omnicare_mobile/features/request_core/data/request_api.dart';
import 'package:omnicare_mobile/features/request_core/data/request_failure.dart';
import 'package:omnicare_mobile/features/request_core/data/request_models.dart';
import 'package:omnicare_mobile/features/request_core/data/request_repository.dart';
import 'package:omnicare_mobile/features/request_core/domain/clinic_request_intent.dart';
import 'package:omnicare_mobile/features/request_core/domain/pickup_location.dart';
import 'package:omnicare_mobile/features/request_core/domain/request_subject.dart';
import 'package:omnicare_mobile/features/request_core/domain/request_vocabulary.dart';
import 'package:omnicare_mobile/features/request_core/identity/in_flight_request_store.dart';
import 'package:omnicare_mobile/features/request_core/identity/request_operation_id.dart';

// ---------------------------------------------------------------------------
// Fixtures. No mocking package, no rewiring of the production HTTP stack.
// ---------------------------------------------------------------------------

const String clinicIdA = '44444444-4444-4444-8444-444444444444';
const String clinicIdB = '55555555-5555-4555-8555-555555555555';
const String serverRequestId = '33333333-3333-4333-8333-333333333333';
const String accountId = '11111111-1111-4111-8111-111111111111';

class FakeSecureBackend implements SecureTokenStorageBackend {
  final Map<String, String> values = <String, String>{};
  bool failWrites = false;
  int writeCount = 0;
  int? failOnWriteCount;

  @override
  Future<String?> read({required String key}) async => values[key];

  @override
  Future<void> write({required String key, required String value}) async {
    writeCount++;
    if (failWrites || failOnWriteCount == writeCount) {
      throw StateError('secure storage unavailable');
    }
    values[key] = value;
  }

  @override
  Future<void> delete({required String key}) async {
    values.remove(key);
  }
}

/// Deterministic operation ids so a test can assert *which* id went out.
class SequentialOperationIdFactory extends RequestOperationIdFactory {
  SequentialOperationIdFactory();

  int _issued = 0;

  @override
  RequestOperationId next() {
    _issued++;
    final suffix = _issued.toRadixString(16).padLeft(12, '0');
    return RequestOperationId.parse('00000000-0000-4000-8000-$suffix');
  }
}

class FakeRequestRepository implements RequestRepository {
  final List<RequestOperationId> submittedIds = [];
  final List<ClinicRequestIntent> submittedIntents = [];

  Object? submitError;
  int submitCalls = 0;
  int getCalls = 0;
  Object? getError;
  PatientRequest? getResult;

  @override
  Future<SubmitClinicRequestResult> submitClinicRequest({
    required RequestOperationId requestId,
    required ClinicRequestIntent intent,
    CancelToken? cancelToken,
  }) async {
    submitCalls++;
    submittedIds.add(requestId);
    submittedIntents.add(intent);
    final error = submitError;
    if (error != null) throw RequestFailure.from(error);
    return SubmitClinicRequestResult(
      requestId: requestId,
      clinicId: intent.clinicId,
      kind: RequestKind.clinic,
      situation: intent.situation,
      patientStatus: PatientRequestStatus.requestReceived,
      submittedAt: DateTime.utc(2026, 8, 7, 9, 15),
      version: 0,
      outcome: RequestSubmissionOutcome.created,
    );
  }

  @override
  Future<PatientRequestPage> listRequests({
    int? page,
    int? pageSize,
    PatientRequestListFilter? filter,
    CancelToken? cancelToken,
  }) async => throw UnimplementedError();

  @override
  Future<PatientRequest> getRequest(
    RequestOperationId requestId, {
    CancelToken? cancelToken,
  }) async {
    getCalls++;
    final error = getError;
    if (error != null) throw RequestFailure.from(error);
    final result = getResult;
    if (result != null) return result;
    throw RequestFailure.notFound;
  }

  @override
  Future<PatientRequest> cancelRequest({
    required RequestOperationId requestId,
    required int expectedVersion,
    CancelToken? cancelToken,
  }) async => throw UnimplementedError();

  @override
  Future<PatientRequest> respondToInformationRequest({
    required RequestOperationId requestId,
    required PatientInformationResponsePayload payload,
    CancelToken? cancelToken,
  }) async => throw UnimplementedError();
}

/// Captures the exact bytes that would go on the wire.
class RecordingAdapter implements HttpClientAdapter {
  RecordingAdapter();

  int statusCode = 200;
  String responseBody = '{}';
  String contentType = 'application/json';
  DioException? throwError;

  String? capturedPath;
  String? capturedMethod;
  String? capturedBody;
  Map<String, dynamic> capturedQuery = const {};

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    capturedPath = options.path;
    capturedMethod = options.method;
    capturedQuery = Map<String, dynamic>.from(options.queryParameters);
    if (requestStream != null) {
      final chunks = await requestStream.toList();
      capturedBody = utf8.decode(chunks.expand((chunk) => chunk).toList());
    } else {
      capturedBody = null;
    }

    final error = throwError;
    if (error != null) {
      throw DioException(requestOptions: options, type: error.type);
    }

    return ResponseBody.fromString(
      responseBody,
      statusCode,
      headers: {
        Headers.contentTypeHeader: [contentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

({RequestApi api, RecordingAdapter adapter}) buildApi() {
  final adapter = RecordingAdapter();
  final dio = Dio()..httpClientAdapter = adapter;
  final client = AppHttpClient(
    tokenStore: SecureTokenStore(backend: FakeSecureBackend()),
    baseUrl: 'https://api.test',
    dio: dio,
    refreshDio: Dio(),
  );
  return (api: RequestApi(client), adapter: adapter);
}

String submissionResponseJson({int version = 0}) => jsonEncode({
  'requestId': serverRequestId,
  'clinicId': clinicIdA,
  'kind': 'CLINIC',
  'situation': 'APPOINTMENT',
  'patientStatus': 'REQUEST_RECEIVED',
  'submittedAt': '2026-08-07T09:15:00Z',
  'version': version,
});

PatientRequest authoritativeRequest([String id = serverRequestId]) =>
    PatientRequest(
      requestId: RequestOperationId.parse(id),
      kind: RequestKind.clinic,
      targetType: RequestTargetType.clinic,
      targetId: clinicIdA,
      subjectType: RequestSubjectType.self,
      situation: RequestSituation.appointment,
      patientStatus: PatientRequestStatus.requestReceived,
      submittedAt: DateTime.utc(2026, 8, 7, 9, 15),
      cancelledAt: null,
      version: 0,
      availableActions: const {PatientRequestAction.cancel},
      informationRequest: null,
    );

String problemJson(String errorCode) => jsonEncode({
  'type': 'https://api.omnicare.tn/problems/request/conflict',
  'title': 'BACKEND_TITLE_MUST_NOT_LEAK',
  'status': 409,
  'detail': 'BACKEND_DETAIL_MUST_NOT_LEAK: constraint chk_fingerprint failed',
  'instance': 'urn:omnicare:request-error:CORRELATION_MUST_NOT_LEAK',
  'errorCode': errorCode,
  'requestId': 'CORRELATION_MUST_NOT_LEAK',
  'timestamp': '2026-08-08T00:00:00Z',
});

FamilyMember buildFamilyMember() => FamilyMember(
  id: '77777777-7777-4777-8777-777777777777',
  accountHolderId: 'ACCOUNT_HOLDER_MUST_NOT_LEAK',
  firstName: 'Amira',
  lastName: 'Ben Salah',
  dateOfBirth: DateTime.utc(2015, 4, 2),
  gender: 'female',
  relationship: FamilyRelationships.enfant,
  graduated: false,
  patientId: 'PATIENT_ID_MUST_NOT_LEAK',
);

RequestSubmissionController buildController({
  required FakeRequestRepository repository,
  required FakeSecureBackend backend,
  SequentialOperationIdFactory? factory,
}) {
  final controller = RequestSubmissionController(
    repository: repository,
    inFlightStore: InFlightRequestStore(backend: backend),
    operationIdFactory: factory ?? SequentialOperationIdFactory(),
  );
  controller.attachAuthenticatedAccount(accountId);
  return controller;
}

void main() {
  // -------------------------------------------------------------- vocabulary

  group('request vocabulary', () {
    test('exposes the exact backend wire values', () {
      expect(
        RequestKind.values.map((kind) => kind.wireValue),
        containsAll(['CLINIC', 'DOCTOR', 'KINE', 'NURSE']),
      );
      expect(RequestKind.clinic.isSubmittable, isTrue);
      expect(RequestKind.doctor.isSubmittable, isFalse);
      expect(RequestKind.kine.isSubmittable, isFalse);
      expect(RequestKind.nurse.isSubmittable, isFalse);

      expect(
        PatientRequestStatus.values
            .where((status) => status != PatientRequestStatus.unknown)
            .map((status) => status.wireValue)
            .toList(),
        equals([
          'REQUEST_RECEIVED',
          'UNDER_REVIEW',
          'INFORMATION_REQUIRED',
          'SCHEDULING_IN_PROGRESS',
          'WAITING_FOR_CONFIRMATION',
          'CONFIRMED',
          'CARE_IN_PROGRESS',
          'COMPLETED',
          'DECLINED',
          'CANCELLED',
          'NO_SHOW',
        ]),
      );

      expect(
        PatientRequestAction.values.map((action) => action.wireValue).toList(),
        equals([
          'CANCEL',
          'PROVIDE_INFORMATION',
          'ACCEPT_SCHEDULE_PROPOSAL',
          'REJECT_SCHEDULE_PROPOSAL',
        ]),
      );
      expect(RequestSubjectType.self.wireValue, 'SELF');
      expect(RequestSubjectType.familyMember.wireValue, 'FAMILY_MEMBER');
      expect(RequestTargetType.clinic.wireValue, 'CLINIC');
      expect(RequestTargetType.professional.wireValue, 'PROFESSIONAL');
    });

    test('terminal statuses match the server projection', () {
      expect(PatientRequestStatus.completed.isTerminal, isTrue);
      expect(PatientRequestStatus.declined.isTerminal, isTrue);
      expect(PatientRequestStatus.cancelled.isTerminal, isTrue);
      expect(PatientRequestStatus.noShow.isTerminal, isTrue);
      expect(PatientRequestStatus.confirmed.isTerminal, isFalse);
      // An unrecognised status must not be assumed final: that would hide a
      // live request from the patient.
      expect(PatientRequestStatus.unknown.isTerminal, isFalse);
    });

    test('an unknown status degrades instead of crashing the app', () {
      expect(
        PatientRequestStatus.parse('AWAITING_TRIAGE_V2'),
        PatientRequestStatus.unknown,
      );
      expect(RequestKind.parse('PHARMACY'), RequestKind.unknown);
      expect(RequestTargetType.parse('ROBOT'), RequestTargetType.unknown);
      expect(RequestSubjectType.parse(null), RequestSubjectType.unknown);

      final request = PatientRequest.fromJson({
        'requestId': serverRequestId,
        'kind': 'CLINIC',
        'targetType': 'CLINIC',
        'targetId': clinicIdA,
        'subjectType': 'SELF',
        'patientStatus': 'AWAITING_TRIAGE_V2',
        'submittedAt': '2026-08-07T09:15:00Z',
        'cancelledAt': null,
        'version': 3,
        'availableActions': ['CANCEL', 'RESCHEDULE_V2'],
      });

      expect(request.patientStatus, PatientRequestStatus.unknown);
      // An unknown action is dropped, never rendered as a mystery button.
      expect(request.availableActions, {PatientRequestAction.cancel});
      expect(request.canCancel, isTrue);
      expect(request.cancelledAt, isNull);
      expect(request.version, 3);
    });
  });

  // ----------------------------------------------------------- subject rules

  group('request subject', () {
    test('SELF emits no familyMemberId value at all', () {
      final json = const RequestSubject.self().toJson();

      expect(json, equals({'type': 'SELF'}));
      expect(json.containsKey('familyMemberId'), isFalse);
    });

    test('FAMILY_MEMBER carries the family member id', () {
      final member = buildFamilyMember();

      final json = RequestSubject.forFamilyMember(member).toJson();

      expect(json['type'], 'FAMILY_MEMBER');
      expect(json['familyMemberId'], member.id);
    });

    test('never renders its identifier', () {
      final subject = RequestSubject.forFamilyMember(buildFamilyMember());

      expect(subject.toString(), 'RequestSubject(FAMILY_MEMBER)');
      expect(subject.toString(), isNot(contains(subject.familyMemberId!)));
    });
  });

  group('submission payload', () {
    test('the serializer can never emit patientId or any other identity', () {
      final member = buildFamilyMember();
      final payload = SubmitClinicRequestPayload(
        requestId: RequestOperationId.parse(serverRequestId),
        intent: ClinicRequestIntent(
          clinicId: clinicIdA,
          subject: RequestSubject.forFamilyMember(member),
          situation: RequestSituation.appointment,
        ),
      );

      final encoded = jsonEncode(payload.toJson());

      expect(encoded, contains(member.id));
      expect(encoded, isNot(contains('PATIENT_ID_MUST_NOT_LEAK')));
      expect(encoded, isNot(contains('ACCOUNT_HOLDER_MUST_NOT_LEAK')));
      for (final forbidden in const [
        'patientId',
        'mrsPatientId',
        'accountHolderId',
        'requesterUserId',
      ]) {
        expect(encoded, isNot(contains(forbidden)));
      }
    });

    test('has no medical or free-text field', () {
      final payload = SubmitClinicRequestPayload(
        requestId: RequestOperationId.parse(serverRequestId),
        intent: const ClinicRequestIntent(
          clinicId: clinicIdA,
          subject: RequestSubject.self(),
          situation: RequestSituation.appointment,
        ),
      );

      final json = payload.toJson();

      // The whole command is four fields: the three from before plus the
      // explicit situation. There is nowhere to put a symptom, a note, a
      // document or a diagnosis.
      expect(json.keys.toSet(), {
        'requestId',
        'clinicId',
        'situation',
        'subject',
      });
      expect((json['subject']! as Map<String, dynamic>).keys.toSet(), {'type'});
      for (final forbidden in const [
        'note',
        'notes',
        'reason',
        'symptoms',
        'description',
        'details',
        'message',
        'comment',
        'diagnosis',
        'documents',
        'attachments',
      ]) {
        expect(json.containsKey(forbidden), isFalse, reason: forbidden);
      }
    });

    test('serializes exact situation and pickup rules for all V1 choices', () {
      SubmitClinicRequestPayload payloadFor(
        RequestSituation situation, {
        PickupLocationSelection? pickup,
      }) => SubmitClinicRequestPayload(
        requestId: RequestOperationId.parse(serverRequestId),
        intent: ClinicRequestIntent(
          clinicId: clinicIdA,
          subject: const RequestSubject.self(),
          situation: situation,
          pickupLocation: pickup,
        ),
      );

      expect(
        payloadFor(
          RequestSituation.appointment,
        ).toJson().containsKey('pickupLocation'),
        isFalse,
      );
      expect(
        payloadFor(
          RequestSituation.urgent,
        ).toJson().containsKey('pickupLocation'),
        isFalse,
      );

      final pickup = PickupLocationSelection(
        source: PickupLocationSource.manualAddress,
        postalAddress: const PostalAddress(
          addressLine: '12 Rue de la Santé',
          city: 'Tunis',
        ),
        capturedAt: DateTime.utc(2026, 8, 8, 10, 30),
      );
      final ambulance = payloadFor(
        RequestSituation.ambulance,
        pickup: pickup,
      ).toJson();

      expect(ambulance['situation'], 'AMBULANCE');
      expect(ambulance['pickupLocation'], {
        'source': 'MANUAL_ADDRESS',
        'postalAddress': {'addressLine': '12 Rue de la Santé', 'city': 'Tunis'},
        'capturedAt': '2026-08-08T10:30:00.000Z',
      });
    });
  });

  // ---------------------------------------------------------------- failures

  group('RequestFailure', () {
    test('maps every Module 05 error code to a typed failure', () {
      RequestFailure map(String code, int status) => RequestFailure.from(
        DioException(
          requestOptions: RequestOptions(path: '/appointment-requests'),
          type: DioExceptionType.badResponse,
          response: Response<dynamic>(
            requestOptions: RequestOptions(path: '/appointment-requests'),
            statusCode: status,
            data: jsonDecode(problemJson(code)),
          ),
        ),
      );

      expect(
        map('REQUEST_SUBJECT_FORBIDDEN', 403).kind,
        RequestFailureKind.subjectForbidden,
      );
      expect(
        map('REQUEST_TARGET_UNAVAILABLE', 422).kind,
        RequestFailureKind.targetUnavailable,
      );
      expect(map('REQUEST_INVALID', 400).kind, RequestFailureKind.invalid);
      expect(
        map('REQUEST_TRANSITION_INVALID', 409).kind,
        RequestFailureKind.transitionInvalid,
      );
      expect(map('REQUEST_NOT_FOUND', 404).kind, RequestFailureKind.notFound);
      expect(
        map('REQUEST_IDEMPOTENCY_CONFLICT', 409).isOperationTerminal,
        isTrue,
      );
    });

    test('a version conflict is typed, non-retryable and needs a refresh', () {
      final failure = RequestFailure.from(
        DioException(
          requestOptions: RequestOptions(path: '/cancel'),
          type: DioExceptionType.badResponse,
          response: Response<dynamic>(
            requestOptions: RequestOptions(path: '/cancel'),
            statusCode: 409,
            data: jsonDecode(problemJson('REQUEST_VERSION_CONFLICT')),
          ),
        ),
      );

      expect(failure.kind, RequestFailureKind.versionConflict);
      expect(failure.retryable, isFalse);
      expect(failure.requiresRefresh, isTrue);
    });

    test('never exposes backend detail, instance or correlation id', () {
      final failure = RequestFailure.from(
        DioException(
          requestOptions: RequestOptions(path: '/appointment-requests/clinic'),
          type: DioExceptionType.badResponse,
          response: Response<dynamic>(
            requestOptions: RequestOptions(
              path: '/appointment-requests/clinic',
            ),
            statusCode: 409,
            data: jsonDecode(problemJson('REQUEST_IDEMPOTENCY_CONFLICT')),
          ),
        ),
      );

      final rendered = '${failure.message} $failure';
      for (final leak in const [
        'BACKEND_DETAIL_MUST_NOT_LEAK',
        'BACKEND_TITLE_MUST_NOT_LEAK',
        'CORRELATION_MUST_NOT_LEAK',
        'urn:omnicare',
        'chk_fingerprint',
        'https://api.omnicare.tn',
      ]) {
        expect(rendered, isNot(contains(leak)), reason: leak);
      }
      // The diagnostic code is ours, not the backend correlation id.
      expect(failure.diagnosticCode, 'REQUEST_IDEMPOTENCY_CONFLICT');
    });

    test('transport problems keep their retry semantics', () {
      RequestFailure ofType(DioExceptionType type) => RequestFailure.from(
        DioException(
          requestOptions: RequestOptions(path: '/x'),
          type: type,
        ),
      );

      expect(ofType(DioExceptionType.connectionTimeout).retryable, isTrue);
      expect(
        ofType(DioExceptionType.receiveTimeout).kind,
        RequestFailureKind.timeout,
      );
      expect(
        ofType(DioExceptionType.connectionError).kind,
        RequestFailureKind.network,
      );
      expect(
        ofType(DioExceptionType.cancel).kind,
        RequestFailureKind.cancelled,
      );
      expect(
        RequestFailure.from(const RequestContractException('bad')).kind,
        RequestFailureKind.contract,
      );
    });
  });

  // --------------------------------------------------------------- transport

  group('RequestApi', () {
    test('201 is accepted as a created submission', () async {
      final harness = buildApi();
      harness.adapter
        ..statusCode = 201
        ..responseBody = submissionResponseJson();

      final result = await harness.api.submitClinicRequest(
        SubmitClinicRequestPayload(
          requestId: RequestOperationId.parse(serverRequestId),
          intent: const ClinicRequestIntent(
            clinicId: clinicIdA,
            subject: RequestSubject.self(),
            situation: RequestSituation.appointment,
          ),
        ),
      );

      expect(result.outcome, RequestSubmissionOutcome.created);
      expect(result.isReplay, isFalse);
      expect(result.requestId.value, serverRequestId);
      expect(result.patientStatus, PatientRequestStatus.requestReceived);
      expect(result.submittedAt, DateTime.utc(2026, 8, 7, 9, 15));
      expect(harness.adapter.capturedPath, '/appointment-requests/clinic');
      expect(harness.adapter.capturedMethod, 'POST');
    });

    test('200 is accepted as a replay of the same durable request', () async {
      final harness = buildApi();
      harness.adapter
        ..statusCode = 200
        ..responseBody = submissionResponseJson(version: 2);

      final result = await harness.api.submitClinicRequest(
        SubmitClinicRequestPayload(
          requestId: RequestOperationId.parse(serverRequestId),
          intent: const ClinicRequestIntent(
            clinicId: clinicIdA,
            subject: RequestSubject.self(),
            situation: RequestSituation.appointment,
          ),
        ),
      );

      expect(result.outcome, RequestSubmissionOutcome.replayed);
      expect(result.isReplay, isTrue);
      expect(result.version, 2);
    });

    test('the submitted body carries only the contract fields', () async {
      final harness = buildApi();
      harness.adapter
        ..statusCode = 201
        ..responseBody = submissionResponseJson();

      await harness.api.submitClinicRequest(
        SubmitClinicRequestPayload(
          requestId: RequestOperationId.parse(serverRequestId),
          intent: const ClinicRequestIntent(
            clinicId: clinicIdA,
            subject: RequestSubject.self(),
            situation: RequestSituation.appointment,
          ),
        ),
      );

      final body =
          jsonDecode(harness.adapter.capturedBody!) as Map<String, dynamic>;
      expect(body.keys.toSet(), {
        'requestId',
        'clinicId',
        'situation',
        'subject',
      });
      expect(body['situation'], 'APPOINTMENT');
      expect(body['subject'], equals({'type': 'SELF'}));
      expect(harness.adapter.capturedBody, isNot(contains('familyMemberId')));
    });

    test('cancel serializes expectedVersion on the wire', () async {
      final harness = buildApi();
      harness.adapter
        ..statusCode = 200
        ..responseBody = jsonEncode({
          'requestId': serverRequestId,
          'kind': 'CLINIC',
          'targetType': 'CLINIC',
          'targetId': clinicIdA,
          'subjectType': 'SELF',
          'patientStatus': 'CANCELLED',
          'submittedAt': '2026-08-07T09:15:00Z',
          'cancelledAt': '2026-08-07T10:00:00Z',
          'version': 1,
          'availableActions': <String>[],
        });

      final cancelled = await harness.api.cancelRequest(
        RequestOperationId.parse(serverRequestId),
        expectedVersion: 7,
      );

      expect(
        harness.adapter.capturedPath,
        '/appointment-requests/$serverRequestId/cancel',
      );
      expect(
        jsonDecode(harness.adapter.capturedBody!),
        equals({'expectedVersion': 7}),
      );
      expect(cancelled.patientStatus, PatientRequestStatus.cancelled);
      expect(cancelled.canCancel, isFalse);
      expect(cancelled.cancelledAt, DateTime.utc(2026, 8, 7, 10));
    });

    test('a bounded list page is parsed without a total count', () async {
      final harness = buildApi();
      harness.adapter
        ..statusCode = 200
        ..responseBody = jsonEncode({
          'contractVersion': '1.0',
          'items': [
            {
              'requestId': serverRequestId,
              'clinicDisplayName': 'Clinique Centre',
              'kind': 'CLINIC',
              'targetType': 'CLINIC',
              'targetId': clinicIdA,
              'subjectType': 'FAMILY_MEMBER',
              'subjectDisplayName': 'Lina Martin',
              'relationship': 'Daughter',
              'situation': 'APPOINTMENT',
              'patientStatus': 'UNDER_REVIEW',
              'submittedAt': '2026-08-07T09:15:00Z',
              'cancelledAt': null,
              'version': 0,
              'availableActions': ['CANCEL'],
              'requiresPatientAction': false,
            },
          ],
          'page': 0,
          'pageSize': 20,
          'hasNext': true,
        });

      final page = await harness.api.listRequests(page: 0, pageSize: 20);

      expect(page.contractVersion, '1.0');
      expect(page.hasNext, isTrue);
      expect(page.items.single.subjectType, RequestSubjectType.familyMember);
      expect(harness.adapter.capturedQuery, {'page': 0, 'pageSize': 20});
    });

    test('omitted paging leaves the server defaults authoritative', () async {
      final harness = buildApi();
      harness.adapter
        ..statusCode = 200
        ..responseBody = jsonEncode({
          'contractVersion': '1.0',
          'items': <dynamic>[],
          'page': 0,
          'pageSize': 20,
          'hasNext': false,
        });

      await harness.api.listRequests();

      expect(harness.adapter.capturedQuery, isEmpty);
    });

    test('a repository call converts a 409 into a typed failure', () async {
      final harness = buildApi();
      harness.adapter
        ..statusCode = 409
        ..contentType = 'application/problem+json'
        ..responseBody = problemJson('REQUEST_VERSION_CONFLICT');
      final repository = RequestRepository(harness.api);

      await expectLater(
        repository.cancelRequest(
          requestId: RequestOperationId.parse(serverRequestId),
          expectedVersion: 1,
        ),
        throwsA(
          isA<RequestFailure>()
              .having((f) => f.kind, 'kind', RequestFailureKind.versionConflict)
              .having((f) => f.retryable, 'retryable', isFalse),
        ),
      );
    });
  });

  // ------------------------------------------------------ operation identity

  group('request operation id', () {
    test('rejects anything that is not a canonical UUID', () {
      expect(RequestOperationId.tryParse('not-a-uuid'), isNull);
      expect(RequestOperationId.tryParse(''), isNull);
      expect(RequestOperationId.tryParse(null), isNull);
      expect(
        RequestOperationId.tryParse(serverRequestId)?.value,
        serverRequestId,
      );
    });

    test('the secure factory yields distinct v4 identifiers', () {
      const factory = SecureRequestOperationIdFactory();

      final ids = List.generate(50, (_) => factory.next().value).toSet();

      expect(ids.length, 50);
      expect(ids.every((id) => id[14] == '4'), isTrue);
    });

    test('does not render its value', () {
      final id = RequestOperationId.parse(serverRequestId);

      expect(id.toString(), isNot(contains(serverRequestId)));
    });
  });

  group('in-flight request store', () {
    test('round-trips only operational retry state', () async {
      final backend = FakeSecureBackend();
      final store = InFlightRequestStore(backend: backend);
      final member = buildFamilyMember();

      await store.save(
        InFlightRequestOperation(
          accountScope: accountId,
          operationId: RequestOperationId.parse(serverRequestId),
          clinicId: clinicIdA,
          subject: RequestSubject.forFamilyMember(member),
          dispatchState: InFlightRequestDispatchState.dispatchAttempted,
          createdAt: DateTime.utc(2026, 11, 9, 10),
        ),
      );

      final raw = backend.values[InFlightRequestStore.storageKey]!;
      expect(jsonDecode(raw), {
        'schemaVersion': 3,
        'accountScope': accountId,
        'requestId': serverRequestId,
        'clinicId': clinicIdA,
        'subjectType': 'FAMILY_MEMBER',
        'familyMemberId': member.id,
        'dispatchState': 'dispatchAttempted',
        'createdAt': '2026-11-09T10:00:00.000Z',
      });
      expect(raw, isNot(contains('PATIENT_ID_MUST_NOT_LEAK')));

      final restored = await store.readForAccount(accountId);
      expect(restored.operation!.operationId.value, serverRequestId);
      expect(restored.operation!.clinicId, clinicIdA);
      expect(restored.operation!.subject.familyMemberId, member.id);
    });

    test('discards a record from an unknown schema version', () async {
      final backend = FakeSecureBackend();
      backend.values[InFlightRequestStore.storageKey] = jsonEncode({
        'schemaVersion': 99,
        'requestId': serverRequestId,
        'kind': 'CLINIC',
        'clinicId': clinicIdA,
        'subjectType': 'SELF',
      });

      final restored = await InFlightRequestStore(
        backend: backend,
      ).readForAccount(accountId);

      expect(restored.status, InFlightRequestReadStatus.absent);
      expect(backend.values, isEmpty);
    });

    test(
      'refuses an inconsistent SELF record instead of repairing it',
      () async {
        final backend = FakeSecureBackend();
        backend.values[InFlightRequestStore.storageKey] = jsonEncode({
          'schemaVersion': 1,
          'requestId': serverRequestId,
          'kind': 'CLINIC',
          'clinicId': clinicIdA,
          'subjectType': 'SELF',
          'familyMemberId': '77777777-7777-4777-8777-777777777777',
        });

        expect(
          (await InFlightRequestStore(
            backend: backend,
          ).readForAccount(accountId)).status,
          InFlightRequestReadStatus.absent,
        );
        expect(backend.values, isEmpty);
      },
    );

    test('migrates v2 by stripping location and business payload', () async {
      final backend = FakeSecureBackend();
      backend.values[InFlightRequestStore.storageKey] = jsonEncode({
        'schemaVersion': 2,
        'requestId': serverRequestId,
        'kind': 'CLINIC',
        'clinicId': clinicIdA,
        'subjectType': 'SELF',
        'familyMemberId': null,
        'situation': 'AMBULANCE',
        'pickup': {
          'source': 'DEVICE_GPS',
          'latitude': 36.8065,
          'longitude': 10.1815,
          'addressLine': 'PHI_ADDRESS_MUST_BE_REMOVED',
          'capturedAt': '2026-11-09T10:00:00Z',
        },
      });
      final store = InFlightRequestStore(
        backend: backend,
        clock: () => DateTime.utc(2026, 11, 9, 11),
      );

      final result = await store.readForAccount(accountId);

      expect(result.status, InFlightRequestReadStatus.available);
      expect(result.operation!.operationId.value, serverRequestId);
      expect(result.operation!.requiresOwnerValidation, isTrue);
      final migrated = backend.values[InFlightRequestStore.storageKey]!;
      expect(migrated, isNot(contains('pickup')));
      expect(migrated, isNot(contains('latitude')));
      expect(migrated, isNot(contains('longitude')));
      expect(migrated, isNot(contains('PHI_ADDRESS_MUST_BE_REMOVED')));
      expect(migrated, isNot(contains('AMBULANCE')));
      expect(migrated, contains(serverRequestId));
    });

    test('does not expose or consume another account receipt', () async {
      final backend = FakeSecureBackend();
      final store = InFlightRequestStore(backend: backend);
      await store.save(
        InFlightRequestOperation(
          accountScope: accountId,
          operationId: RequestOperationId.parse(serverRequestId),
          clinicId: clinicIdA,
          subject: const RequestSubject.self(),
          dispatchState: InFlightRequestDispatchState.dispatchAttempted,
          createdAt: DateTime.utc(2026, 11, 9),
        ),
      );

      final result = await store.readForAccount(
        '22222222-2222-4222-8222-222222222222',
      );

      expect(result.status, InFlightRequestReadStatus.ownerMismatch);
      expect(result.operation, isNull);
      expect(backend.values, isNotEmpty);
    });
  });

  // -------------------------------------------------------------- controller

  group('RequestSubmissionController', () {
    late FakeRequestRepository repository;
    late FakeSecureBackend backend;
    late InFlightRequestStore store;
    late RequestSubmissionController controller;

    setUp(() {
      repository = FakeRequestRepository();
      backend = FakeSecureBackend();
      store = InFlightRequestStore(backend: backend);
      controller = buildController(repository: repository, backend: backend);
    });

    tearDown(() => controller.dispose());

    Future<void> startClinicRequest() async {
      await controller.beginNewRequest();
      controller.selectClinic(clinicIdA);
      controller.selectSituation(RequestSituation.appointment);
    }

    test('a new logical request always gets a new operation id', () async {
      await controller.beginNewRequest();
      final first = controller.operationId;

      await controller.beginNewRequest();
      final second = controller.operationId;

      expect(first, isNotNull);
      expect(second, isNotNull);
      expect(second, isNot(first));
    });

    test('a network failure retries with the same operation id', () async {
      await startClinicRequest();
      repository.submitError = DioException(
        requestOptions: RequestOptions(path: '/x'),
        type: DioExceptionType.connectionError,
      );

      await controller.submit();
      expect(controller.status, RequestSubmissionStatus.failed);
      expect(controller.failure!.kind, RequestFailureKind.network);
      expect(controller.canRetry, isTrue);
      // The record survives a retryable failure, so a process death here still
      // resumes the same operation.
      expect(
        (await store.readForAccount(accountId)).status,
        InFlightRequestReadStatus.available,
      );

      repository.submitError = null;
      await controller.retry();

      expect(repository.submitCalls, 2);
      expect(repository.submittedIds.first, repository.submittedIds.last);
      expect(controller.status, RequestSubmissionStatus.succeeded);
    });

    test('a timeout preserves the operation id', () async {
      await startClinicRequest();
      final issued = controller.operationId;
      repository.submitError = DioException(
        requestOptions: RequestOptions(path: '/x'),
        type: DioExceptionType.receiveTimeout,
      );

      await controller.submit();

      expect(controller.failure!.kind, RequestFailureKind.timeout);
      expect(controller.operationId, issued);
      expect(repository.submittedIds.single, issued);

      repository.submitError = null;
      await controller.retry();

      expect(repository.submittedIds, [issued, issued]);
    });

    test(
      'an idempotency conflict never regenerates the operation id',
      () async {
        await startClinicRequest();
        final issued = controller.operationId;
        repository.submitError = DioException(
          requestOptions: RequestOptions(path: '/x'),
          type: DioExceptionType.badResponse,
          response: Response<dynamic>(
            requestOptions: RequestOptions(path: '/x'),
            statusCode: 409,
            data: jsonDecode(problemJson('REQUEST_IDEMPOTENCY_CONFLICT')),
          ),
        );

        await controller.submit();

        expect(
          controller.failure!.kind,
          RequestFailureKind.idempotencyConflict,
        );
        expect(controller.failure!.retryable, isFalse);
        expect(controller.operationId, issued);
        expect(controller.canRetry, isFalse);

        // Retrying is refused rather than silently restarted under a fresh id.
        await controller.retry();
        expect(repository.submitCalls, 1);
        expect(controller.operationId, issued);

        // The burned id is not left behind for a later resume.
        expect(
          (await store.readForAccount(accountId)).status,
          InFlightRequestReadStatus.absent,
        );

        // Only an explicit new logical request mints a new id.
        await controller.beginNewRequest();
        expect(controller.operationId, isNot(issued));
      },
    );

    test(
      'changing the target cannot abandon an unresolved operation',
      () async {
        await startClinicRequest();
        repository.submitError = DioException(
          requestOptions: RequestOptions(path: '/x'),
          type: DioExceptionType.connectionError,
        );
        await controller.submit();
        final firstId = controller.operationId;

        controller.selectClinic(clinicIdB);

        expect(controller.operationId, firstId);
        expect(controller.intent!.clinicId, clinicIdA);
        expect(controller.hasUnresolvedOperation, isTrue);

        await controller.abandonAndBeginNewRequest(clinicId: clinicIdB);
        expect(controller.operationId, isNot(firstId));
        expect(controller.selectedClinicId, clinicIdB);
      },
    );

    test('changing the target before any attempt keeps the same id', () async {
      await controller.beginNewRequest();
      final issued = controller.operationId;

      controller.selectClinic(clinicIdA);
      controller.selectFamilyMemberSubject(buildFamilyMember());

      expect(controller.operationId, issued);
      expect(controller.subject.familyMemberId, buildFamilyMember().id);
    });

    test(
      'changing intent is refused while an attempted operation is unresolved',
      () async {
        await startClinicRequest();
        controller.selectSituation(RequestSituation.ambulance);
        controller.setPickupLocation(
          PickupLocationSelection(
            source: PickupLocationSource.deviceGps,
            geoPoint: GeoPoint.fromCapturedCoordinates(
              latitude: 36.8065,
              longitude: 10.1815,
              accuracyMeters: 8.2,
            ),
            capturedAt: DateTime.utc(2026, 8, 8, 10, 30),
          ),
        );
        repository.submitError = DioException(
          requestOptions: RequestOptions(path: '/x'),
          type: DioExceptionType.connectionError,
        );
        await controller.submit();
        final first = controller.operationId;

        controller.selectFamilyMemberSubject(buildFamilyMember());
        final second = controller.operationId;
        expect(second, first);
        expect(controller.subject.isSelf, isTrue);
        controller.selectSituation(RequestSituation.urgent);
        final third = controller.operationId;
        expect(third, second);
        expect(controller.selectedSituation, RequestSituation.ambulance);
      },
    );

    test('a successful submission clears the persisted operation', () async {
      await startClinicRequest();

      await controller.submit();

      expect(controller.status, RequestSubmissionStatus.succeeded);
      expect(controller.result!.outcome, RequestSubmissionOutcome.created);
      expect(
        (await store.readForAccount(accountId)).status,
        InFlightRequestReadStatus.absent,
      );
      expect(backend.values, isEmpty);
    });

    test('a settled submission is never silently resubmitted', () async {
      await startClinicRequest();
      await controller.submit();

      await controller.submit();
      controller.selectClinic(clinicIdB);

      expect(repository.submitCalls, 1);
      expect(controller.intent!.clinicId, clinicIdA);
    });

    test('submitting without a clinic never reaches the network', () async {
      await controller.beginNewRequest();

      await controller.submit();

      expect(repository.submitCalls, 0);
      expect(controller.failure, RequestFailure.intentIncomplete);
    });

    test('receipt persistence failure blocks the POST', () async {
      await startClinicRequest();
      backend.failWrites = true;

      await controller.submit();

      expect(repository.submitCalls, 0);
      expect(controller.failure, RequestFailure.recoveryPersistenceUnavailable);
      expect(controller.hasUnresolvedOperation, isFalse);
    });

    test('dispatch marker persistence failure also blocks the POST', () async {
      await startClinicRequest();
      backend.failOnWriteCount = 2;

      await controller.submit();

      expect(repository.submitCalls, 0);
      expect(controller.failure, RequestFailure.recoveryPersistenceUnavailable);
      final raw = backend.values[InFlightRequestStore.storageKey]!;
      expect(jsonDecode(raw)['dispatchState'], 'prepared');
    });

    test(
      'restart recovery performs GET first and never replays the POST',
      () async {
        await startClinicRequest();
        repository.submitError = DioException(
          requestOptions: RequestOptions(path: '/x'),
          type: DioExceptionType.connectionError,
        );
        await controller.submit();
        final persistedId = controller.operationId!;

        final freshRepository = FakeRequestRepository()
          ..getResult = authoritativeRequest(persistedId.value);
        final fresh = buildController(
          repository: freshRepository,
          backend: backend,
        );
        addTearDown(fresh.dispose);

        final recovered = await fresh.recoverAfterAuthentication(
          accountId: accountId,
        );

        expect(recovered, isTrue);
        expect(freshRepository.getCalls, 1);
        expect(freshRepository.submitCalls, 0);
        expect(fresh.recoveredRequestId, persistedId);
      },
    );

    test('temporary GET recovery failure retains the receipt', () async {
      await startClinicRequest();
      repository.submitError = DioException(
        requestOptions: RequestOptions(path: '/x'),
        type: DioExceptionType.connectionError,
      );
      await controller.submit();
      repository.getError = DioException(
        requestOptions: RequestOptions(path: '/x'),
        type: DioExceptionType.connectionTimeout,
      );

      final recovered = await controller.recoverAfterAuthentication(
        accountId: accountId,
      );

      expect(recovered, isFalse);
      expect(controller.failure!.retryable, isTrue);
      expect(controller.hasUnresolvedOperation, isTrue);
      expect(
        (await store.readForAccount(accountId)).status,
        InFlightRequestReadStatus.available,
      );
    });

    test('opening a new flow cannot erase an unresolved operation', () async {
      await startClinicRequest();
      repository.submitError = DioException(
        requestOptions: RequestOptions(path: '/x'),
        type: DioExceptionType.connectionError,
      );
      await controller.submit();
      final unresolvedId = controller.operationId;

      await controller.beginNewRequest();

      expect(controller.operationId, unresolvedId);
      expect(controller.hasUnresolvedOperation, isTrue);
      expect(
        (await store.readForAccount(accountId)).status,
        InFlightRequestReadStatus.available,
      );
    });

    test('logout clears every trace of the patient request', () async {
      await startClinicRequest();
      controller.selectFamilyMemberSubject(buildFamilyMember());
      repository.submitError = DioException(
        requestOptions: RequestOptions(path: '/x'),
        type: DioExceptionType.connectionError,
      );
      await controller.submit();
      expect(
        (await store.readForAccount(accountId)).status,
        InFlightRequestReadStatus.available,
      );

      await controller.clear();

      expect(controller.operationId, isNull);
      expect(controller.selectedClinicId, isNull);
      expect(controller.subject, const RequestSubject.self());
      expect(controller.result, isNull);
      expect(controller.failure, isNull);
      expect(controller.status, RequestSubmissionStatus.idle);
      expect(
        (await store.readForAccount(accountId)).status,
        InFlightRequestReadStatus.absent,
      );
      expect(backend.values, isEmpty);
    });

    test(
      'an interrupted operation can be restored without auto-sending',
      () async {
        await store.save(
          InFlightRequestOperation(
            accountScope: accountId,
            operationId: RequestOperationId.parse(serverRequestId),
            clinicId: clinicIdA,
            subject: const RequestSubject.self(),
            dispatchState: InFlightRequestDispatchState.dispatchAttempted,
            createdAt: DateTime.utc(2026, 11, 9, 10),
          ),
        );
        repository.getResult = authoritativeRequest();

        final restored = await controller.restoreInFlightOperation();

        expect(restored, isTrue);
        expect(controller.operationId!.value, serverRequestId);
        expect(controller.selectedClinicId, clinicIdA);
        expect(repository.submitCalls, 0);
        expect(repository.getCalls, 1);
        expect(controller.status, RequestSubmissionStatus.recovered);
        expect(controller.recoveredRequestId!.value, serverRequestId);
      },
    );
  });

  // ------------------------------------------------------ structural guards

  group('Module 05 source guarantees', () {
    final sources = Directory('lib/features/request_core')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .toList();

    /// Comments describe the forbidden identifiers on purpose; only executable
    /// code is inspected.
    String codeOf(File file) => file
        .readAsLinesSync()
        .where((line) {
          final trimmed = line.trimLeft();
          return !trimmed.startsWith('//') && !trimmed.startsWith('*');
        })
        .join('\n');

    bool containsForbiddenIdentifier(String code, String identifier) =>
        RegExp('\\b${RegExp.escape(identifier)}\\b').hasMatch(code);

    test('finds the module sources', () {
      expect(sources, isNotEmpty);
    });

    test('RequestApi cannot default-construct its own AppHttpClient', () {
      final api = codeOf(
        File('lib/features/request_core/data/request_api.dart'),
      );

      // One required positional dependency; no optional/named client, and no
      // fallback that would build a second Dio, a second AuthInterceptor and a
      // second AuthRefreshCoordinator.
      expect(api, contains('const RequestApi(this._httpClient);'));
      expect(api, isNot(contains('RequestApi({')));
      expect(api, isNot(contains('AppHttpClient(')));
      expect(api, isNot(contains('SecureTokenStore(')));
      expect(api, isNot(contains('??')));
    });

    test('no module source constructs its own HTTP client', () {
      for (final file in sources) {
        final code = codeOf(file);
        expect(code, isNot(contains('AppHttpClient(')), reason: file.path);
        expect(code, isNot(contains('SecureTokenStore(')), reason: file.path);
        expect(code, isNot(contains('LogInterceptor')), reason: file.path);
      }
    });

    test('no module source logs or handles forbidden identifiers', () {
      for (final file in sources) {
        final code = codeOf(file);
        for (final forbidden in const ['print(', 'consoleLog', 'debugPrint']) {
          expect(
            code,
            isNot(contains(forbidden)),
            reason: '$forbidden in ${file.path}',
          );
        }
        for (final forbidden in const [
          'patientId',
          'mrsPatientId',
          'accountHolderId',
        ]) {
          expect(
            containsForbiddenIdentifier(code, forbidden),
            isFalse,
            reason: '$forbidden in ${file.path}',
          );
        }
      }
    });

    test('no module source polls or extends the legacy reservation stack', () {
      for (final file in sources) {
        final code = codeOf(file);
        for (final forbidden in const [
          'Timer.periodic',
          'ReservationProvider',
          'ReservationsApi',
          'ReservationRepository',
          'ConsultationsApi',
          'DoctorsApi',
          'mock_data',
          'useMock',
        ]) {
          expect(
            code,
            isNot(contains(forbidden)),
            reason: '$forbidden in ${file.path}',
          );
        }
      }
    });
  });
}

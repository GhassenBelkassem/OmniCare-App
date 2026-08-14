import 'package:dio/dio.dart';

import '../domain/clinic_request_intent.dart';
import '../domain/request_vocabulary.dart';
import '../identity/request_operation_id.dart';
import 'request_api.dart';
import 'request_failure.dart';
import 'request_models.dart';

/// Repository boundary for Module 05.
///
/// Two responsibilities, and nothing else:
///
/// 1. turn the transport layer into typed domain models;
/// 2. turn every transport, contract or protocol problem into a
///    [RequestFailure], so no controller or screen ever sees a `DioException`,
///    a backend `detail`, an `instance` URI or a correlation id.
///
/// There is no mock mode, no `useMock()` / `useApi()` switch and no fabricated
/// success anywhere below. A care request that did not reach the server must
/// look like a failure, always.
///
/// Note what this class deliberately does *not* do: it never refreshes the
/// request list after a submit. The POST response already describes the
/// created-or-replayed request, so an immediate GET would be a second round
/// trip that tells the caller nothing new.
abstract class PatientRequestGateway {
  Future<PatientRequestPage> listRequests({
    int? page,
    int? pageSize,
    PatientRequestListFilter? filter,
    CancelToken? cancelToken,
  });
  Future<PatientRequest> getRequest(
    RequestOperationId requestId, {
    CancelToken? cancelToken,
  });
  Future<PatientRequest> cancelRequest({
    required RequestOperationId requestId,
    required int expectedVersion,
    CancelToken? cancelToken,
  });
  Future<PatientRequest> respondToInformationRequest({
    required RequestOperationId requestId,
    required PatientInformationResponsePayload payload,
    CancelToken? cancelToken,
  });
}

class RequestRepository implements PatientRequestGateway {
  const RequestRepository(this._api);

  final RequestApi _api;

  /// Submits one CLINIC request under [requestId].
  ///
  /// Reusing the same [requestId] for a retry is the intended behaviour: the
  /// server answers `201` once and `200` for every faithful replay.
  Future<SubmitClinicRequestResult> submitClinicRequest({
    required RequestOperationId requestId,
    required ClinicRequestIntent intent,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _api.submitClinicRequest(
        SubmitClinicRequestPayload(requestId: requestId, intent: intent),
        cancelToken: cancelToken,
      );
    } catch (error) {
      throw RequestFailure.from(error);
    }
  }

  /// One bounded page of the caller's own requests, newest first.
  @override
  Future<PatientRequestPage> listRequests({
    int? page,
    int? pageSize,
    PatientRequestListFilter? filter,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _api.listRequests(
        page: page,
        pageSize: pageSize,
        filter: filter,
        cancelToken: cancelToken,
      );
    } catch (error) {
      throw RequestFailure.from(error);
    }
  }

  @override
  Future<PatientRequest> getRequest(
    RequestOperationId requestId, {
    CancelToken? cancelToken,
  }) async {
    try {
      return await _api.getRequest(requestId, cancelToken: cancelToken);
    } catch (error) {
      throw RequestFailure.from(error);
    }
  }

  /// Withdraws a request.
  ///
  /// [expectedVersion] must be the `version` last observed for this request.
  /// A [RequestFailureKind.versionConflict] means the request moved on: the
  /// caller must re-fetch the current state and let the patient decide again.
  /// It must never be retried blindly with a bumped guess.
  @override
  Future<PatientRequest> cancelRequest({
    required RequestOperationId requestId,
    required int expectedVersion,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _api.cancelRequest(
        requestId,
        expectedVersion: expectedVersion,
        cancelToken: cancelToken,
      );
    } catch (error) {
      throw RequestFailure.from(error);
    }
  }

  @override
  Future<PatientRequest> respondToInformationRequest({
    required RequestOperationId requestId,
    required PatientInformationResponsePayload payload,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _api.respondToInformationRequest(
        requestId,
        payload: payload,
        cancelToken: cancelToken,
      );
    } catch (error) {
      throw RequestFailure.from(error);
    }
  }
}

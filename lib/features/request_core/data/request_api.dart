import 'package:dio/dio.dart';

import '../../../core/network/app_http_client.dart';
import '../domain/request_vocabulary.dart';
import '../identity/request_operation_id.dart';
import 'request_models.dart';

/// Thin transport for the Module 05 patient request contract.
///
/// # Shared client, by construction
///
/// The [AppHttpClient] is a **required positional dependency**. There is no
/// optional parameter and no `?? AppHttpClient(tokenStore: SecureTokenStore())`
/// fallback, because that pattern — still present in some legacy API classes —
/// silently creates a second Dio, a second `AuthInterceptor` and a second
/// `AuthRefreshCoordinator`. Two coordinators means two concurrent refreshes
/// racing for one rotating refresh token, and a session invalidation that only
/// half the app hears about. Module 05 therefore cannot construct its own.
///
/// This class never reads or writes tokens; the shared pipeline owns 401,
/// refresh, retry and session invalidation. A 401 retry replays the *original*
/// request body, so the operation id survives a refresh unchanged.
///
/// No `LogInterceptor` is installed and nothing here logs a request body, a
/// response body or an identifier.
class RequestApi {
  const RequestApi(this._httpClient);

  final AppHttpClient _httpClient;

  /// Base URL already carries `/api/v1`.
  static const String requestsPath = '/appointment-requests';
  static const String clinicSubmissionPath = '/appointment-requests/clinic';

  static String requestPath(String requestId) => '$requestsPath/$requestId';

  static String cancelPath(String requestId) =>
      '${requestPath(requestId)}/cancel';
  static String informationRequestPath(String requestId) =>
      '${requestPath(requestId)}/information-request';
  static String informationResponsePath(String requestId) =>
      '${requestPath(requestId)}/information-response';

  /// `POST /appointment-requests/clinic`.
  ///
  /// `201` means this call created the request, `200` means it replayed one
  /// that already existed. Both are success and both describe the same durable
  /// request; the outcome is taken from the status code because the body is
  /// intentionally identical.
  Future<SubmitClinicRequestResult> submitClinicRequest(
    SubmitClinicRequestPayload payload, {
    CancelToken? cancelToken,
  }) async {
    final response = await _httpClient.dio.post<dynamic>(
      clinicSubmissionPath,
      data: payload.toJson(),
      cancelToken: cancelToken,
    );
    final outcome = switch (response.statusCode) {
      201 => RequestSubmissionOutcome.created,
      200 => RequestSubmissionOutcome.replayed,
      _ => throw const RequestContractException(
        'Clinic submission returned an unsupported success status.',
      ),
    };
    return SubmitClinicRequestResult.fromJson(
      _asJsonObject(response.data),
      outcome: outcome,
    );
  }

  /// `GET /appointment-requests`.
  ///
  /// Bounded by contract: the server clamps `pageSize` to `[1, 50]` and
  /// defaults to 20. Omitted parameters are not sent, so the server default
  /// stays authoritative.
  Future<PatientRequestPage> listRequests({
    int? page,
    int? pageSize,
    PatientRequestListFilter? filter,
    CancelToken? cancelToken,
  }) async {
    final response = await _httpClient.dio.get<dynamic>(
      requestsPath,
      queryParameters: {'page': ?page, 'pageSize': ?pageSize, 'filter': ?filter?.wireValue},
      cancelToken: cancelToken,
    );
    return PatientRequestPage.fromJson(_asJsonObject(response.data));
  }

  /// `GET /appointment-requests/{requestId}`.
  Future<PatientRequest> getRequest(
    RequestOperationId requestId, {
    CancelToken? cancelToken,
  }) async {
    final response = await _httpClient.dio.get<dynamic>(
      requestPath(requestId.value),
      cancelToken: cancelToken,
    );
    return PatientRequest.fromJson(_asJsonObject(response.data));
  }

  /// `POST /appointment-requests/{requestId}/cancel`.
  ///
  /// [expectedVersion] is the optimistic-lock precondition and is mandatory.
  Future<PatientRequest> cancelRequest(
    RequestOperationId requestId, {
    required int expectedVersion,
    CancelToken? cancelToken,
  }) async {
    final response = await _httpClient.dio.post<dynamic>(
      cancelPath(requestId.value),
      data: CancelRequestPayload(expectedVersion: expectedVersion).toJson(),
      cancelToken: cancelToken,
    );
    return PatientRequest.fromJson(_asJsonObject(response.data));
  }

  Future<PatientInformationRequest> getInformationRequest(
    RequestOperationId requestId, {
    CancelToken? cancelToken,
  }) async {
    final response = await _httpClient.dio.get<dynamic>(
      informationRequestPath(requestId.value),
      cancelToken: cancelToken,
    );
    return PatientInformationRequest.fromJson(_asJsonObject(response.data));
  }

  Future<PatientRequest> respondToInformationRequest(
    RequestOperationId requestId, {
    required PatientInformationResponsePayload payload,
    CancelToken? cancelToken,
  }) async {
    final response = await _httpClient.dio.post<dynamic>(
      informationResponsePath(requestId.value),
      data: payload.toJson(),
      cancelToken: cancelToken,
    );
    return PatientRequest.fromJson(_asJsonObject(response.data));
  }

  static Map<String, dynamic> _asJsonObject(Object? data) {
    if (data is! Map) {
      throw const RequestContractException('Expected a JSON object.');
    }
    return data.cast<String, dynamic>();
  }
}

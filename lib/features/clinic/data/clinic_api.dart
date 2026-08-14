import 'package:dio/dio.dart';

import '../../../core/network/app_http_client.dart';
import 'clinic_models.dart';

/// Thin transport layer for the Phase 1 clinic contract.
///
/// It reuses the shared [AppHttpClient] (and therefore the existing auth
/// interceptor, serialized refresh and session-invalidation pipeline). It never
/// reads or writes tokens itself.
class ClinicApi {
  const ClinicApi(this._httpClient);

  final AppHttpClient _httpClient;

  static const String accessPath = '/me/access';
  static const String membershipsPath = '/me/clinics';

  static String bootstrapPath(String clinicId) =>
      '/clinics/$clinicId/bootstrap';

  Future<ClinicAccessResult> fetchAccess({CancelToken? cancelToken}) {
    return _get(accessPath, ClinicAccessResult.fromJson, cancelToken);
  }

  Future<ClinicMembershipDirectory> fetchMemberships({
    CancelToken? cancelToken,
  }) {
    return _get(
      membershipsPath,
      ClinicMembershipDirectory.fromJson,
      cancelToken,
    );
  }

  Future<ClinicBootstrap> fetchBootstrap(
    String clinicId, {
    CancelToken? cancelToken,
  }) {
    final id = clinicId.trim();
    if (id.isEmpty) {
      throw const ClinicContractException('Clinic identifier is required.');
    }
    return _get(bootstrapPath(id), ClinicBootstrap.fromJson, cancelToken);
  }

  static String tasksPath(String clinicId) => '/clinics/$clinicId/tasks';

  static String taskDetailPath(String clinicId, String taskId) =>
      '${tasksPath(clinicId)}/$taskId';

  static String taskAcknowledgePath(String clinicId, String taskId) =>
      '${taskDetailPath(clinicId, taskId)}/acknowledge';

  static String taskStartPath(String clinicId, String taskId) =>
      '${taskDetailPath(clinicId, taskId)}/start';

  static String taskBlockPath(String clinicId, String taskId) =>
      '${taskDetailPath(clinicId, taskId)}/block';

  static String taskUnblockPath(String clinicId, String taskId) =>
      '${taskDetailPath(clinicId, taskId)}/unblock';

  static String taskCompletePath(String clinicId, String taskId) =>
      '${taskDetailPath(clinicId, taskId)}/complete';

  static String taskHandoverTargetsPath(String clinicId, String taskId) =>
      '${taskDetailPath(clinicId, taskId)}/handover-targets';

  static String taskHandoversPath(String clinicId, String taskId) =>
      '${taskDetailPath(clinicId, taskId)}/handovers';

  static String taskHandoverDetailPath(String clinicId, String handoverId) =>
      '/clinics/$clinicId/task-handovers/$handoverId';

  static String taskHandoverAcceptPath(String clinicId, String handoverId) =>
      '${taskHandoverDetailPath(clinicId, handoverId)}/accept';

  static String taskHandoverDeclinePath(String clinicId, String handoverId) =>
      '${taskHandoverDetailPath(clinicId, handoverId)}/decline';

  static String taskHandoverCancelPath(String clinicId, String handoverId) =>
      '${taskHandoverDetailPath(clinicId, handoverId)}/cancel';

  static String casesPath(String clinicId) => '/clinics/$clinicId/cases';

  static String caseDetailPath(String clinicId, String caseId) =>
      '${casesPath(clinicId)}/$caseId';

  static String caseStartReviewPath(String clinicId, String caseId) =>
      '${caseDetailPath(clinicId, caseId)}/review/start';

  static String caseInformationRequiredPath(String clinicId, String caseId) =>
      '${caseDetailPath(clinicId, caseId)}/information-required';

  static String caseReadyForPlanningPath(String clinicId, String caseId) =>
      '${caseDetailPath(clinicId, caseId)}/ready-for-planning';

  static String caseDeclinePath(String clinicId, String caseId) =>
      '${caseDetailPath(clinicId, caseId)}/decline';

  static String handoversPath(String clinicId, {required bool incoming}) =>
      '/clinics/$clinicId/task-handovers/${incoming ? 'incoming' : 'outgoing'}';

  Future<ClinicSlice<ClinicTaskSummary>> fetchPositionQueue(
    String clinicId, {
    int page = 0,
    int pageSize = 20,
    CancelToken? cancelToken,
  }) {
    return _fetchTaskPage(
      '${tasksPath(clinicId)}/position-queue',
      page: page,
      pageSize: pageSize,
      cancelToken: cancelToken,
    );
  }

  Future<ClinicSlice<ClinicTaskSummary>> fetchMyTasks(
    String clinicId, {
    int page = 0,
    int pageSize = 20,
    CancelToken? cancelToken,
  }) {
    return _fetchTaskPage(
      '${tasksPath(clinicId)}/my',
      page: page,
      pageSize: pageSize,
      cancelToken: cancelToken,
    );
  }

  Future<ClinicTaskDetail> fetchTaskDetail(
    String clinicId,
    String taskId, {
    CancelToken? cancelToken,
  }) async {
    final json = await _getJson(taskDetailPath(clinicId, taskId), cancelToken);
    return ClinicTaskDetail.fromJson(json);
  }

  Future<ClinicTaskDetail> acknowledgeTask(
    String clinicId,
    String taskId, {
    required int expectedVersion,
    CancelToken? cancelToken,
  }) {
    return _postTaskCommand(
      taskAcknowledgePath(clinicId, taskId),
      expectedVersion: expectedVersion,
      cancelToken: cancelToken,
    );
  }

  Future<ClinicTaskDetail> startTask(
    String clinicId,
    String taskId, {
    required int expectedVersion,
    CancelToken? cancelToken,
  }) {
    return _postTaskCommand(
      taskStartPath(clinicId, taskId),
      expectedVersion: expectedVersion,
      cancelToken: cancelToken,
    );
  }

  Future<ClinicTaskDetail> blockTask(
    String clinicId,
    String taskId, {
    required ClinicTaskBlockedReason reason,
    required int expectedVersion,
    CancelToken? cancelToken,
  }) {
    return _postTaskCommand(
      taskBlockPath(clinicId, taskId),
      expectedVersion: expectedVersion,
      cancelToken: cancelToken,
      data: <String, dynamic>{'reasonCode': reason.wireValue},
    );
  }

  Future<ClinicTaskDetail> unblockTask(
    String clinicId,
    String taskId, {
    required int expectedVersion,
    CancelToken? cancelToken,
  }) {
    return _postTaskCommand(
      taskUnblockPath(clinicId, taskId),
      expectedVersion: expectedVersion,
      cancelToken: cancelToken,
    );
  }

  Future<ClinicTaskDetail> completeTask(
    String clinicId,
    String taskId, {
    required int expectedVersion,
    CancelToken? cancelToken,
  }) {
    return _postTaskCommand(
      taskCompletePath(clinicId, taskId),
      expectedVersion: expectedVersion,
      cancelToken: cancelToken,
    );
  }

  Future<ClinicSlice<ClinicHandoverTarget>> fetchHandoverTargets(
    String clinicId,
    String taskId, {
    int page = 0,
    int pageSize = 20,
    CancelToken? cancelToken,
  }) async {
    final json = await _getJson(
      taskHandoverTargetsPath(clinicId, taskId),
      cancelToken,
      queryParameters: {'page': page, 'size': pageSize},
    );
    return ClinicSlice<ClinicHandoverTarget>(
      items: _list(json, 'items', ClinicHandoverTarget.fromJson),
      page: _requiredInt(json, 'page'),
      pageSize: _requiredInt(json, 'pageSize'),
      hasNext: json['hasNext'] == true,
      generatedAt: _requiredDateTime(json, 'generatedAt'),
    );
  }

  Future<ClinicHandoverSummary> initiateHandover(
    String clinicId,
    String taskId, {
    required String toMembershipId,
    required ClinicHandoverReason reason,
    required int expectedTaskVersion,
    CancelToken? cancelToken,
  }) {
    return _postHandoverCommand(
      taskHandoversPath(clinicId, taskId),
      cancelToken: cancelToken,
      data: <String, dynamic>{
        'toMembershipId': toMembershipId,
        'reasonCode': reason.wireValue,
        'expectedTaskVersion': expectedTaskVersion,
      },
    );
  }

  Future<ClinicHandoverSummary> fetchHandoverDetail(
    String clinicId,
    String handoverId, {
    CancelToken? cancelToken,
  }) async {
    final json = await _getJson(
      taskHandoverDetailPath(clinicId, handoverId),
      cancelToken,
    );
    return ClinicHandoverSummary.fromJson(json);
  }

  Future<ClinicHandoverSummary> acceptHandover(
    String clinicId,
    String handoverId, {
    CancelToken? cancelToken,
  }) {
    return _postHandoverCommand(
      taskHandoverAcceptPath(clinicId, handoverId),
      cancelToken: cancelToken,
    );
  }

  Future<ClinicHandoverSummary> declineHandover(
    String clinicId,
    String handoverId, {
    CancelToken? cancelToken,
  }) {
    return _postHandoverCommand(
      taskHandoverDeclinePath(clinicId, handoverId),
      cancelToken: cancelToken,
    );
  }

  Future<ClinicHandoverSummary> cancelHandover(
    String clinicId,
    String handoverId, {
    CancelToken? cancelToken,
  }) {
    return _postHandoverCommand(
      taskHandoverCancelPath(clinicId, handoverId),
      cancelToken: cancelToken,
    );
  }

  Future<ClinicCaseDetail> fetchCaseDetail(
    String clinicId,
    String caseId, {
    CancelToken? cancelToken,
  }) async {
    final json = await _getJson(caseDetailPath(clinicId, caseId), cancelToken);
    return ClinicCaseDetail.fromJson(json);
  }

  Future<ClinicCaseDetail> startReview(
    String clinicId,
    String caseId, {
    required int expectedVersion,
    CancelToken? cancelToken,
  }) {
    return _postCaseCommand(
      caseStartReviewPath(clinicId, caseId),
      expectedVersion: expectedVersion,
      cancelToken: cancelToken,
    );
  }

  Future<ClinicCaseDetail> requestInformation(
    String clinicId,
    String caseId, {
    required int expectedVersion,
    required ClinicInformationRequestReason reason,
    String? patientInstruction,
    CancelToken? cancelToken,
  }) {
    final payload = <String, dynamic>{'reasonCode': reason.wireValue};
    if (patientInstruction != null) {
      payload['patientInstruction'] = patientInstruction;
    }
    return _postCaseCommand(
      caseInformationRequiredPath(clinicId, caseId),
      expectedVersion: expectedVersion,
      cancelToken: cancelToken,
      data: payload,
    );
  }

  Future<ClinicCaseDetail> readyForPlanning(
    String clinicId,
    String caseId, {
    required int expectedVersion,
    CancelToken? cancelToken,
  }) {
    return _postCaseCommand(
      caseReadyForPlanningPath(clinicId, caseId),
      expectedVersion: expectedVersion,
      cancelToken: cancelToken,
    );
  }

  Future<ClinicCaseDetail> declineCase(
    String clinicId,
    String caseId, {
    required int expectedVersion,
    required ClinicCaseDeclineReason reason,
    CancelToken? cancelToken,
  }) {
    return _postCaseCommand(
      caseDeclinePath(clinicId, caseId),
      expectedVersion: expectedVersion,
      cancelToken: cancelToken,
      data: <String, dynamic>{'declineReasonCode': reason.wireValue},
    );
  }

  Future<ClinicSlice<ClinicHandoverSummary>> fetchHandovers(
    String clinicId, {
    required bool incoming,
    int page = 0,
    int pageSize = 20,
    CancelToken? cancelToken,
  }) async {
    final json = await _getJson(
      handoversPath(clinicId, incoming: incoming),
      cancelToken,
      queryParameters: {'page': page, 'pageSize': pageSize},
    );
    return ClinicSlice<ClinicHandoverSummary>(
      items: _list(json, 'items', ClinicHandoverSummary.fromJson),
      page: _requiredInt(json, 'page'),
      pageSize: _requiredInt(json, 'pageSize'),
      hasNext: json['hasNext'] == true,
      generatedAt: _requiredDateTime(json, 'generatedAt'),
    );
  }

  Future<ClinicSlice<ClinicTaskSummary>> _fetchTaskPage(
    String path, {
    required int page,
    required int pageSize,
    CancelToken? cancelToken,
  }) async {
    final json = await _getJson(
      path,
      cancelToken,
      queryParameters: {'page': page, 'pageSize': pageSize},
    );
    return ClinicSlice<ClinicTaskSummary>(
      items: _list(json, 'items', ClinicTaskSummary.fromJson),
      page: _requiredInt(json, 'page'),
      pageSize: _requiredInt(json, 'pageSize'),
      hasNext: json['hasNext'] == true,
      generatedAt: _requiredDateTime(json, 'generatedAt'),
      contractVersion: _optionalString(json['contractVersion']),
    );
  }

  Future<T> _get<T>(
    String path,
    T Function(Map<String, dynamic>) fromJson,
    CancelToken? cancelToken,
  ) async {
    final response = await _httpClient.dio.get<dynamic>(
      path,
      cancelToken: cancelToken,
    );
    final data = response.data;
    if (data is! Map) {
      throw const ClinicContractException('Expected a JSON object.');
    }
    return fromJson(data.cast<String, dynamic>());
  }

  Future<Map<String, dynamic>> _getJson(
    String path,
    CancelToken? cancelToken, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final response = await _httpClient.dio.get<dynamic>(
      path,
      cancelToken: cancelToken,
      queryParameters: queryParameters,
    );
    final data = response.data;
    if (data is! Map) {
      throw const ClinicContractException('Expected a JSON object.');
    }
    return data.cast<String, dynamic>();
  }

  Future<ClinicTaskDetail> _postTaskCommand(
    String path, {
    required int expectedVersion,
    CancelToken? cancelToken,
    Map<String, dynamic>? data,
  }) async {
    final payload = <String, dynamic>{
      if (data != null) ...data,
      'expectedVersion': expectedVersion,
    };
    final response = await _httpClient.dio.post<dynamic>(
      path,
      data: payload,
      cancelToken: cancelToken,
    );
    final responseData = response.data;
    if (responseData is! Map) {
      throw const ClinicContractException('Expected a JSON object.');
    }
    return ClinicTaskDetail.fromJson(responseData.cast<String, dynamic>());
  }

  Future<ClinicCaseDetail> _postCaseCommand(
    String path, {
    required int expectedVersion,
    CancelToken? cancelToken,
    Map<String, dynamic>? data,
  }) async {
    final payload = <String, dynamic>{
      if (data != null) ...data,
      'expectedVersion': expectedVersion,
    };
    final response = await _httpClient.dio.post<dynamic>(
      path,
      data: payload,
      cancelToken: cancelToken,
    );
    final responseData = response.data;
    if (responseData is! Map) {
      throw const ClinicContractException('Expected a JSON object.');
    }
    return ClinicCaseDetail.fromJson(responseData.cast<String, dynamic>());
  }

  Future<ClinicHandoverSummary> _postHandoverCommand(
    String path, {
    CancelToken? cancelToken,
    Map<String, dynamic>? data,
  }) async {
    final response = await _httpClient.dio.post<dynamic>(
      path,
      data: data,
      cancelToken: cancelToken,
    );
    final responseData = response.data;
    if (responseData is! Map) {
      throw const ClinicContractException('Expected a JSON object.');
    }
    return ClinicHandoverSummary.fromJson(responseData.cast<String, dynamic>());
  }
}

List<T> _list<T>(
  Map<String, dynamic> json,
  String key,
  T Function(Map<String, dynamic>) fromJson,
) {
  final value = json[key];
  if (value is! List) {
    throw const ClinicContractException('Page items are malformed.');
  }
  return List.unmodifiable(
    value.map((item) {
      if (item is! Map) {
        throw const ClinicContractException('Page item is malformed.');
      }
      return fromJson(item.cast<String, dynamic>());
    }),
  );
}

String? _optionalString(Object? value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int) return value;
  if (value is num) return value.toInt();
  final parsed = int.tryParse(value?.toString().trim() ?? '');
  if (parsed != null) return parsed;
  throw ClinicContractException('Missing required numeric field "$key".');
}

DateTime _requiredDateTime(Map<String, dynamic> json, String key) {
  final value = DateTime.tryParse(json[key]?.toString() ?? '')?.toUtc();
  if (value != null) return value;
  throw ClinicContractException('Missing required timestamp "$key".');
}

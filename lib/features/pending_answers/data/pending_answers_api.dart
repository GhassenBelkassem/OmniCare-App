import 'package:dio/dio.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/network/app_http_client.dart';
import '../../../core/network/request_replay_policy.dart';
import 'pending_answers_models.dart';

/// G-1 D2 / D4 patient endpoints (contracts final on the backend).
abstract interface class PendingAnswersApiContract {
  Future<List<PatientAccessRequest>> accessRequests();

  Future<PatientAccessRequest> accessRequest(String requestId);

  Future<PatientAccessRequest> answerAccessRequest(
    String requestId, {
    required bool accept,
    required int expectedVersion,
    required String idempotencyKey,
  });

  Future<List<FollowUpProposal>> followUpProposals();

  Future<FollowUpProposal> answerFollowUpProposal(
    String appointmentId, {
    required bool accept,
    required int expectedVersion,
    required String idempotencyKey,
  });
}

/// Every failure is thrown as an [ApiFailure] (no server text kept).
class PendingAnswersApi implements PendingAnswersApiContract {
  const PendingAnswersApi(this._httpClient);

  final AppHttpClient _httpClient;
  static const _accessRequests = '/me/access-requests';
  static const _proposals = '/me/follow-up-proposals';
  static const _noStore = {'Cache-Control': 'no-store'};

  @override
  Future<List<PatientAccessRequest>> accessRequests() => _call(() async {
    final response = await _httpClient.dio.get<dynamic>(
      _accessRequests,
      options: Options(headers: _noStore),
    );
    return parseItems(response.data, PatientAccessRequest.fromJson);
  });

  @override
  Future<PatientAccessRequest> accessRequest(String requestId) =>
      _call(() async {
        final response = await _httpClient.dio.get<dynamic>(
          '$_accessRequests/${_segment(requestId)}',
          options: Options(headers: _noStore),
        );
        return PatientAccessRequest.fromJson(parseObject(response.data));
      });

  @override
  Future<PatientAccessRequest> answerAccessRequest(
    String requestId, {
    required bool accept,
    required int expectedVersion,
    required String idempotencyKey,
  }) => _call(() async {
    final response = await _httpClient.dio.post<dynamic>(
      '$_accessRequests/${_segment(requestId)}/${accept ? 'accept' : 'refuse'}',
      data: <String, Object>{'expectedVersion': expectedVersion},
      options: _write(idempotencyKey),
    );
    return PatientAccessRequest.fromJson(parseObject(response.data));
  });

  @override
  Future<List<FollowUpProposal>> followUpProposals() => _call(() async {
    final response = await _httpClient.dio.get<dynamic>(
      _proposals,
      options: Options(headers: _noStore),
    );
    return parseItems(response.data, FollowUpProposal.fromJson);
  });

  @override
  Future<FollowUpProposal> answerFollowUpProposal(
    String appointmentId, {
    required bool accept,
    required int expectedVersion,
    required String idempotencyKey,
  }) => _call(() async {
    final response = await _httpClient.dio.post<dynamic>(
      '$_proposals/${_segment(appointmentId)}/${accept ? 'accept' : 'decline'}',
      data: <String, Object>{'expectedVersion': expectedVersion},
      options: _write(idempotencyKey),
    );
    return FollowUpProposal.fromJson(parseObject(response.data));
  });

  static Options _write(String idempotencyKey) {
    final key = idempotencyKey.trim();
    if (key.isEmpty || key.length > 128) {
      throw const ApiFailure(kind: ApiFailureKind.validation);
    }
    return Options(
      headers: {..._noStore, 'Idempotency-Key': key},
      extra: requestReplayExtra(RequestReplayPolicy.declaredIdempotentWrite),
    );
  }

  static String _segment(String id) {
    final value = id.trim();
    if (value.isEmpty) {
      throw const ApiFailure(kind: ApiFailureKind.notFound);
    }
    return Uri.encodeComponent(value);
  }

  static Future<T> _call<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on PendingAnswersContractException {
      throw const ApiFailure(kind: ApiFailureKind.unknown);
    } catch (error) {
      throw ApiFailure.from(error);
    }
  }
}

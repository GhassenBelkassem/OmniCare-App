import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/app_http_client.dart';
import '../../../core/network/request_replay_policy.dart';
import 'direct_patient_authorization.dart';
import 'medical_sharing_models.dart';

abstract interface class DirectPatientAuthorizationApiContract {
  Future<List<DirectAuthorizationContext>> activeContexts(
    MedicalSharingSubject subject,
  );

  Future<PatientMedicalAccess> readAccess(String consultationId);

  Future<PatientMedicalAccess> approve(
    String consultationId, {
    required String idempotencyKey,
  });

  Future<PatientMedicalAccess> revoke(
    String consultationId, {
    required String idempotencyKey,
  });
}

class DirectPatientAuthorizationApi
    implements DirectPatientAuthorizationApiContract {
  const DirectPatientAuthorizationApi(this._httpClient);

  final AppHttpClient _httpClient;
  static const _base = '/me/consultations';

  @override
  Future<List<DirectAuthorizationContext>> activeContexts(
    MedicalSharingSubject subject,
  ) async {
    try {
      final response = await _httpClient.dio.get<dynamic>(
        '$_base/medical-sharing',
        queryParameters: subject.toQueryParameters(),
        options: Options(headers: const {'Cache-Control': 'no-store'}),
      );
      final data = response.data;
      if (data is! List) throw const FormatException('Expected list.');
      return data
          .map((value) => DirectAuthorizationContext.fromJson(_object(value)))
          .toList(growable: false);
    } on DioException catch (error) {
      throw _map(error);
    } on FormatException catch (error) {
      throw ApiException(
        'Réponse d’autorisation invalide.',
        code: 'MALFORMED_RESPONSE',
        cause: error,
      );
    }
  }

  @override
  Future<PatientMedicalAccess> readAccess(String consultationId) =>
      _read(consultationId, 'access');

  @override
  Future<PatientMedicalAccess> approve(
    String consultationId, {
    required String idempotencyKey,
  }) => _write(consultationId, 'approve', idempotencyKey);

  @override
  Future<PatientMedicalAccess> revoke(
    String consultationId, {
    required String idempotencyKey,
  }) => _write(consultationId, 'revoke', idempotencyKey);

  Future<PatientMedicalAccess> _read(
    String consultationId,
    String command,
  ) async {
    try {
      final response = await _httpClient.dio.get<dynamic>(
        '$_base/${Uri.encodeComponent(_consultation(consultationId))}/medical-sharing/$command',
        options: Options(headers: const {'Cache-Control': 'no-store'}),
      );
      return PatientMedicalAccess.fromJson(_object(response.data));
    } on DioException catch (error) {
      throw _map(error);
    } on FormatException catch (error) {
      throw ApiException(
        'Réponse d’autorisation invalide.',
        code: 'MALFORMED_RESPONSE',
        cause: error,
      );
    }
  }

  Future<PatientMedicalAccess> _write(
    String consultationId,
    String command,
    String idempotencyKey,
  ) async {
    try {
      final response = await _httpClient.dio.post<dynamic>(
        '$_base/${Uri.encodeComponent(_consultation(consultationId))}/medical-sharing/$command',
        options: Options(
          headers: {
            'Cache-Control': 'no-store',
            'Idempotency-Key': _idempotency(idempotencyKey),
          },
          extra: requestReplayExtra(
            RequestReplayPolicy.declaredIdempotentWrite,
          ),
        ),
      );
      return PatientMedicalAccess.fromJson(_object(response.data));
    } on DioException catch (error) {
      throw _map(error);
    } on FormatException catch (error) {
      throw ApiException(
        'Réponse d’autorisation invalide.',
        code: 'MALFORMED_RESPONSE',
        cause: error,
      );
    }
  }

  static String _consultation(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      throw const ApiException(
        'Consultation invalide.',
        code: 'INVALID_CONSULTATION',
      );
    }
    return normalized;
  }

  static String _idempotency(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty || normalized.length > 128) {
      throw const ApiException(
        'Identifiant de requête invalide.',
        code: 'INVALID_IDEMPOTENCY_KEY',
      );
    }
    return normalized;
  }

  static Map<String, dynamic> _object(Object? value) {
    if (value is! Map) throw const FormatException('Expected object.');
    return value.cast<String, dynamic>();
  }

  static ApiException _map(DioException error) {
    final data = error.response?.data;
    final code = data is Map
        ? (data['errorCode'] ?? data['code'])?.toString()
        : null;
    return ApiException(
      'Impossible de mettre à jour l’accès médical.',
      code: code ?? 'MRS_UNAVAILABLE',
      statusCode: error.response?.statusCode,
      cause: error,
    );
  }
}

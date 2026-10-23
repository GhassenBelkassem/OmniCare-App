import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/app_http_client.dart';
import 'medical_sharing_models.dart';

abstract interface class MedicalSharingApiContract {
  Future<MedicalSharingPolicy> readPolicy(MedicalSharingSubject subject);

  Future<MedicalSharingPolicy> updatePolicy(
    MedicalSharingPolicy desired, {
    required String idempotencyKey,
  });

  Future<ConsultationSharingPolicy> readConsultationPolicy(
    MedicalSharingSubject subject,
    String consultationId,
  );

  Future<ConsultationSharingPolicy> updateConsultationPolicy(
    ConsultationSharingPolicy current,
    ConsultationSharingState desired, {
    required String idempotencyKey,
  });
}

class MedicalSharingApi implements MedicalSharingApiContract {
  const MedicalSharingApi(this._httpClient);

  final AppHttpClient _httpClient;
  static const path = '/patient/medical-sharing';

  @override
  Future<MedicalSharingPolicy> readPolicy(MedicalSharingSubject subject) async {
    try {
      final response = await _httpClient.dio.get<dynamic>(
        '$path/policy',
        queryParameters: subject.toQueryParameters(),
        options: Options(headers: const {'Cache-Control': 'no-store'}),
      );
      return MedicalSharingPolicy.fromJson(_object(response.data));
    } on DioException catch (error) {
      throw _mapDio(error);
    } on FormatException catch (error) {
      throw ApiException(
        'Malformed server response.',
        code: 'MALFORMED_RESPONSE',
        cause: error,
      );
    }
  }

  @override
  Future<MedicalSharingPolicy> updatePolicy(
    MedicalSharingPolicy desired, {
    required String idempotencyKey,
  }) async {
    try {
      final response = await _httpClient.dio.put<dynamic>(
        '$path/policy',
        data: desired.toUpdateJson(),
        options: _mutationOptions(idempotencyKey),
      );
      return MedicalSharingPolicy.fromJson(_object(response.data));
    } on DioException catch (error) {
      throw _mapDio(error);
    } on FormatException catch (error) {
      throw ApiException(
        'Malformed server response.',
        code: 'MALFORMED_RESPONSE',
        cause: error,
      );
    }
  }

  @override
  Future<ConsultationSharingPolicy> readConsultationPolicy(
    MedicalSharingSubject subject,
    String consultationId,
  ) async {
    try {
      final response = await _httpClient.dio.get<dynamic>(
        '$path/consultations/${Uri.encodeComponent(consultationId)}',
        queryParameters: subject.toQueryParameters(),
        options: Options(headers: const {'Cache-Control': 'no-store'}),
      );
      return ConsultationSharingPolicy.fromJson(_object(response.data));
    } on DioException catch (error) {
      throw _mapDio(error);
    } on FormatException catch (error) {
      throw ApiException(
        'Malformed server response.',
        code: 'MALFORMED_RESPONSE',
        cause: error,
      );
    }
  }

  @override
  Future<ConsultationSharingPolicy> updateConsultationPolicy(
    ConsultationSharingPolicy current,
    ConsultationSharingState desired, {
    required String idempotencyKey,
  }) async {
    try {
      final response = await _httpClient.dio.put<dynamic>(
        '$path/consultations/${Uri.encodeComponent(current.consultationId)}',
        data: {
          ...current.subject.toJson(),
          'expectedVersion': current.version,
          'sharingState': switch (desired) {
            ConsultationSharingState.locked => 'LOCKED',
            ConsultationSharingState.shareable => 'SHAREABLE',
          },
        },
        options: _mutationOptions(idempotencyKey),
      );
      return ConsultationSharingPolicy.fromJson(_object(response.data));
    } on DioException catch (error) {
      throw _mapDio(error);
    } on FormatException catch (error) {
      throw ApiException(
        'Malformed server response.',
        code: 'MALFORMED_RESPONSE',
        cause: error,
      );
    }
  }

  static Options _mutationOptions(String idempotencyKey) {
    final key = idempotencyKey.trim();
    if (key.isEmpty || key.length > 128) {
      throw const ApiException(
        'Invalid mutation identity.',
        code: 'INVALID_IDEMPOTENCY_KEY',
      );
    }
    return Options(
      contentType: Headers.jsonContentType,
      headers: {'Cache-Control': 'no-store', 'Idempotency-Key': key},
    );
  }

  static Map<String, dynamic> _object(Object? data) {
    if (data is! Map) throw const FormatException('Expected JSON object.');
    return data.cast<String, dynamic>();
  }

  static ApiException _mapDio(DioException error) {
    final status = error.response?.statusCode;
    final data = error.response?.data;
    if (data is Map) {
      final json = data.cast<Object?, Object?>();
      final code = (json['errorCode'] ?? json['code'])?.toString();
      final detail = (json['detail'] ?? json['message'])?.toString();
      return ApiException(
        detail?.trim().isNotEmpty == true
            ? detail!.trim()
            : 'Impossible de mettre à jour les paramètres de partage.',
        code: code,
        statusCode: status,
        cause: error,
      );
    }
    return ApiException(
      'Le service médical est temporairement indisponible.',
      code: 'MRS_UNAVAILABLE',
      statusCode: status,
      cause: error,
    );
  }
}
